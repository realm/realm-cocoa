////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMQueryUtil.hpp"

#import "RLMArray.h"
#import "RLMDecimal128_Private.hpp"
#import "RLMObjectId_Private.hpp"
#import "RLMObjectSchema_Private.h"
#import "RLMObject_Private.hpp"
#import "RLMPredicateUtil.hpp"
#import "RLMProperty_Private.h"
#import "RLMSchema.h"
#import "RLMUtil.hpp"

#import <realm/object-store/object_store.hpp>
#import <realm/object-store/results.hpp>
#import <realm/query_engine.hpp>
#import <realm/query_expression.hpp>
#import <realm/util/cf_ptr.hpp>
#import <realm/util/overload.hpp>

using namespace realm;

NSString * const RLMPropertiesComparisonTypeMismatchException = @"RLMPropertiesComparisonTypeMismatchException";
NSString * const RLMUnsupportedTypesFoundInPropertyComparisonException = @"RLMUnsupportedTypesFoundInPropertyComparisonException";

NSString * const RLMPropertiesComparisonTypeMismatchReason = @"Property type mismatch between %@ and %@";
NSString * const RLMUnsupportedTypesFoundInPropertyComparisonReason = @"Comparison between %@ and %@";

namespace {

// small helper to create the many exceptions thrown when parsing predicates
[[gnu::cold]] [[noreturn]]
void throwException(NSString *name, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    @throw [NSException exceptionWithName:name reason:reason userInfo:nil];
}

// check a precondition and throw an exception if it is not met
// this should be used iff the condition being false indicates a bug in the caller
// of the function checking its preconditions
void RLMPrecondition(bool condition, NSString *name, NSString *format, ...) {
    if (__builtin_expect(condition, 1)) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *reason = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    @throw [NSException exceptionWithName:name reason:reason userInfo:nil];
}

BOOL propertyTypeIsNumeric(RLMPropertyType propertyType) {
    switch (propertyType) {
        case RLMPropertyTypeInt:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble:
        case RLMPropertyTypeDecimal128:
            return YES;
        default:
            return NO;
    }
}

// Equal and ContainsSubstring are used by QueryBuilder::add_string_constraint as the comparator
// for performing diacritic-insensitive comparisons.

bool equal(CFStringCompareFlags options, StringData v1, StringData v2)
{
    if (v1.is_null() || v2.is_null()) {
        return v1.is_null() == v2.is_null();
    }

    auto s1 = util::adoptCF(CFStringCreateWithBytesNoCopy(kCFAllocatorSystemDefault, (const UInt8*)v1.data(), v1.size(),
                                                          kCFStringEncodingUTF8, false, kCFAllocatorNull));
    auto s2 = util::adoptCF(CFStringCreateWithBytesNoCopy(kCFAllocatorSystemDefault, (const UInt8*)v2.data(), v2.size(),
                                                          kCFStringEncodingUTF8, false, kCFAllocatorNull));

    return CFStringCompare(s1.get(), s2.get(), options) == kCFCompareEqualTo;
}

template <CFStringCompareFlags options>
struct Equal {
    using CaseSensitive = Equal<options & ~kCFCompareCaseInsensitive>;
    using CaseInsensitive = Equal<options | kCFCompareCaseInsensitive>;

    bool operator()(Mixed v1, Mixed v2) const
    {
        return equal(options, v1.get_string(), v2.get_string());
    }

    static const char* description() { return options & kCFCompareCaseInsensitive ? "==[cd]" : "==[d]"; }
};

bool contains_substring(CFStringCompareFlags options, StringData v1, StringData v2)
{
    if (v2.is_null()) {
        // Everything contains NULL
        return true;
    }

    if (v1.is_null()) {
        // NULL contains nothing (except NULL, handled above)
        return false;
    }

    if (v2.size() == 0) {
        // Everything (except NULL, handled above) contains the empty string
        return true;
    }

    auto s1 = util::adoptCF(CFStringCreateWithBytesNoCopy(kCFAllocatorSystemDefault, (const UInt8*)v1.data(), v1.size(),
                                                          kCFStringEncodingUTF8, false, kCFAllocatorNull));
    auto s2 = util::adoptCF(CFStringCreateWithBytesNoCopy(kCFAllocatorSystemDefault, (const UInt8*)v2.data(), v2.size(),
                                                          kCFStringEncodingUTF8, false, kCFAllocatorNull));

    return CFStringFind(s1.get(), s2.get(), options).location != kCFNotFound;
}

template <CFStringCompareFlags options>
struct ContainsSubstring {
    using CaseSensitive = ContainsSubstring<options & ~kCFCompareCaseInsensitive>;
    using CaseInsensitive = ContainsSubstring<options | kCFCompareCaseInsensitive>;

    bool operator()(Mixed v1, Mixed v2) const
    {
        return contains_substring(options, v1.get_string(), v2.get_string());
    }

    static const char* description() { return options & kCFCompareCaseInsensitive ? "CONTAINS[cd]" : "CONTAINS[d]"; }
};


NSString *operatorName(NSPredicateOperatorType operatorType)
{
    switch (operatorType) {
        case NSLessThanPredicateOperatorType:
            return @"<";
        case NSLessThanOrEqualToPredicateOperatorType:
            return @"<=";
        case NSGreaterThanPredicateOperatorType:
            return @">";
        case NSGreaterThanOrEqualToPredicateOperatorType:
            return @">=";
        case NSEqualToPredicateOperatorType:
            return @"==";
        case NSNotEqualToPredicateOperatorType:
            return @"!=";
        case NSMatchesPredicateOperatorType:
            return @"MATCHES";
        case NSLikePredicateOperatorType:
            return @"LIKE";
        case NSBeginsWithPredicateOperatorType:
            return @"BEGINSWITH";
        case NSEndsWithPredicateOperatorType:
            return @"ENDSWITH";
        case NSInPredicateOperatorType:
            return @"IN";
        case NSContainsPredicateOperatorType:
            return @"CONTAINS";
        case NSBetweenPredicateOperatorType:
            return @"BETWEEN";
        case NSCustomSelectorPredicateOperatorType:
            return @"custom selector";
    }

    return [NSString stringWithFormat:@"unknown operator %lu", (unsigned long)operatorType];
}

[[gnu::cold]] [[noreturn]]
void unsupportedOperator(RLMPropertyType datatype, NSPredicateOperatorType operatorType) {
    throwException(@"Invalid operator type",
                   @"Operator '%@' not supported for type %@",
                   operatorName(operatorType), RLMTypeToString(datatype));
}

Table& get_table(Group& group, RLMObjectSchema *objectSchema)
{
    return *ObjectStore::table_for_object_type(group, objectSchema.objectName.UTF8String);
}

// A reference to a column within a query. Can be resolved to a Columns<T> for use in query expressions.
class ColumnReference {
public:
    ColumnReference(Query& query, Group& group, RLMSchema *schema, RLMProperty* property, const std::vector<RLMProperty*>& links = {})
    : m_links(links), m_property(property), m_schema(schema), m_group(&group), m_query(&query), m_table(query.get_table())
    {
        auto& table = walk_link_chain([](Table const&, ColKey, RLMPropertyType) { });
        m_col = table.get_column_key(m_property.columnName.UTF8String);
    }

    template <typename T, typename... SubQuery>
    auto resolve(SubQuery&&... subquery) const
    {
        static_assert(sizeof...(SubQuery) < 2, "resolve() takes at most one subquery");
        LinkChain lc = link_chain();

        if (type() != RLMPropertyTypeLinkingObjects) {
            return lc.column<T>(column(), std::forward<SubQuery>(subquery)...);
        }

        if constexpr (std::is_same_v<T, Link>) {
            auto [table, col] = link_origin(m_property);
            return lc.column<T>(table, col, std::forward<SubQuery>(subquery)...);
        }

        REALM_TERMINATE("LinkingObjects property did not have column type Link");
    }

    RLMProperty *property() const { return m_property; }
    ColKey column() const { return m_col; }
    RLMPropertyType type() const { return property().type; }
    Group& group() const { return *m_group; }

    RLMObjectSchema *link_target_object_schema() const
    {
        switch (type()) {
            case RLMPropertyTypeObject:
            case RLMPropertyTypeLinkingObjects:
                return m_schema[property().objectClassName];
            default:
                REALM_UNREACHABLE();
        }
    }

    bool has_links() const { return m_links.size(); }

    bool has_any_to_many_links() const {
        return std::any_of(begin(m_links), end(m_links),
                           [](RLMProperty *property) { return property.array; });
    }

    ColumnReference last_link_column() const {
        REALM_ASSERT(!m_links.empty());
        return {*m_query, *m_group, m_schema, m_links.back(), {m_links.begin(), m_links.end() - 1}};
    }

    ColumnReference column_ignoring_links(Query& query) const {
        return {query, *m_group, m_schema, m_property};
    }

private:
    template<typename Func>
    Table const& walk_link_chain(Func&& func) const
    {
        auto table = m_query->get_table().unchecked_ptr();
        for (const auto& link : m_links) {
            if (link.type != RLMPropertyTypeLinkingObjects) {
                auto index = table->get_column_key(link.columnName.UTF8String);
                func(*table, index, link.type);
                table = table->get_link_target(index).unchecked_ptr();
            }
            else {
                auto [link_origin_table, link_origin_column] = link_origin(link);
                func(link_origin_table, link_origin_column, link.type);
                table = &link_origin_table;
            }
        }
        return *table;
    }

    std::pair<Table&, ColKey> link_origin(RLMProperty *prop) const
    {
        RLMObjectSchema *link_origin_schema = m_schema[prop.objectClassName];
        Table& link_origin_table = get_table(*m_group, link_origin_schema);
        NSString *column_name = link_origin_schema[prop.linkOriginPropertyName].columnName;
        auto link_origin_column = link_origin_table.get_column_key(column_name.UTF8String);
        return {link_origin_table, link_origin_column};
    }

    LinkChain link_chain() const
    {
        LinkChain lc(m_table);
        walk_link_chain([&](Table const& link_origin, ColKey col, RLMPropertyType type) {
            if (type != RLMPropertyTypeLinkingObjects) {
                lc.link(col);
            }
            else {
                lc.backlink(link_origin, col);
            }
        });
        return lc;
    }

    std::vector<RLMProperty*> m_links;
    RLMProperty *m_property;
    RLMSchema *m_schema;
    Group *m_group;
    Query *m_query;
    ConstTableRef m_table;
    ColKey m_col;
};

class CollectionOperation {
public:
    enum Type {
        Count,
        Minimum,
        Maximum,
        Sum,
        Average,
    };

    CollectionOperation(Type type, ColumnReference link_column, util::Optional<ColumnReference> column)
        : m_type(type)
        , m_link_column(std::move(link_column))
        , m_column(std::move(column))
    {
        RLMPrecondition(m_link_column.property().array,
                        @"Invalid predicate", @"Collection operation can only be applied to a property of type RLMArray.");

        switch (m_type) {
            case Count:
                RLMPrecondition(!m_column, @"Invalid predicate", @"Result of @count does not have any properties.");
                break;
            case Minimum:
            case Maximum:
            case Sum:
            case Average:
                RLMPrecondition(m_column && propertyTypeIsNumeric(m_column->type()), @"Invalid predicate",
                                @"%@ can only be applied to a numeric property.", name_for_type(m_type));
                break;
        }
    }

    CollectionOperation(NSString *operationName, ColumnReference link_column, util::Optional<ColumnReference> column = util::none)
        : CollectionOperation(type_for_name(operationName), std::move(link_column), std::move(column))
    {
    }

    Type type() const { return m_type; }
    const ColumnReference& link_column() const { return m_link_column; }
    const ColumnReference& column() const { return *m_column; }

    void validate_comparison(id value) const {
        switch (m_type) {
            case Count:
            case Average:
                RLMPrecondition([value isKindOfClass:[NSNumber class]], @"Invalid operand",
                                @"%@ can only be compared with a numeric value.", name_for_type(m_type));
                break;
            case Minimum:
            case Maximum:
            case Sum:
                RLMPrecondition(RLMIsObjectValidForProperty(value, m_column->property()), @"Invalid operand",
                                @"%@ on a property of type %@ cannot be compared with '%@'",
                                name_for_type(m_type), RLMTypeToString(m_column->type()), value);
                break;
        }
    }

    void validate_comparison(const ColumnReference& column) const {
        switch (m_type) {
            case Count:
                RLMPrecondition(propertyTypeIsNumeric(column.type()), @"Invalid operand",
                                @"%@ can only be compared with a numeric value.", name_for_type(m_type));
                break;
            case Average:
            case Minimum:
            case Maximum:
            case Sum:
                RLMPrecondition(propertyTypeIsNumeric(column.type()), @"Invalid operand",
                                @"%@ on a property of type %@ cannot be compared with property of type '%@'",
                                name_for_type(m_type), RLMTypeToString(m_column->type()), RLMTypeToString(column.type()));
                break;
        }
    }

private:
    static Type type_for_name(NSString *name) {
        if ([name isEqualToString:@"@count"]) {
            return Count;
        }
        if ([name isEqualToString:@"@min"]) {
            return Minimum;
        }
        if ([name isEqualToString:@"@max"]) {
            return Maximum;
        }
        if ([name isEqualToString:@"@sum"]) {
            return Sum;
        }
        if ([name isEqualToString:@"@avg"]) {
            return Average;
        }
        throwException(@"Invalid predicate", @"Unsupported collection operation '%@'", name);
    }

    static NSString *name_for_type(Type type) {
        switch (type) {
            case Count: return @"@count";
            case Minimum: return @"@min";
            case Maximum: return @"@max";
            case Sum: return @"@sum";
            case Average: return @"@avg";
        }
    }

    Type m_type;
    ColumnReference m_link_column;
    util::Optional<ColumnReference> m_column;
};

class QueryBuilder {
public:
    QueryBuilder(Query& query, Group& group, RLMSchema *schema)
    : m_query(query), m_group(group), m_schema(schema) { }

    void apply_predicate(NSPredicate *predicate, RLMObjectSchema *objectSchema);


    void apply_collection_operator_expression(RLMObjectSchema *desc, NSString *keyPath, id value, NSComparisonPredicate *pred);
    void apply_value_expression(RLMObjectSchema *desc, NSString *keyPath, id value, NSComparisonPredicate *pred);
    void apply_column_expression(RLMObjectSchema *desc, NSString *leftKeyPath, NSString *rightKeyPath, NSComparisonPredicate *predicate);
    void apply_function_expression(RLMObjectSchema *objectSchema, NSExpression *functionExpression,
                                   NSPredicateOperatorType operatorType, NSExpression *right);


    template <typename A, typename B>
    void add_numeric_constraint(RLMPropertyType datatype,
                                NSPredicateOperatorType operatorType,
                                A&& lhs, B&& rhs);

    template <typename A, typename B>
    void add_bool_constraint(RLMPropertyType, NSPredicateOperatorType operatorType, A&& lhs, B&& rhs);

    void add_substring_constraint(null, Query condition);
    template<typename T>
    void add_substring_constraint(const T& value, Query condition);
    template<typename T>
    void add_substring_constraint(const Columns<T>& value, Query condition);

    template <typename T>
    void add_string_constraint(NSPredicateOperatorType operatorType,
                               NSComparisonPredicateOptions predicateOptions,
                               Columns<String> &&column,
                               T value);

    template <typename R>
    void add_constraint(RLMPropertyType type,
                        NSPredicateOperatorType operatorType,
                        NSComparisonPredicateOptions predicateOptions,
                        ColumnReference const& column, R const& rhs);
    template <typename... T>
    void do_add_constraint(RLMPropertyType type, NSPredicateOperatorType operatorType,
                           NSComparisonPredicateOptions predicateOptions, T&&... values);
    void do_add_constraint(RLMPropertyType, NSPredicateOperatorType, NSComparisonPredicateOptions, id, realm::null);

    void add_between_constraint(const ColumnReference& column, id value);

    void add_binary_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, BinaryData value);
    void add_binary_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, id value);
    void add_binary_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, null);
    void add_binary_constraint(NSPredicateOperatorType, const ColumnReference&, const ColumnReference&);

    void add_link_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, RLMObjectBase *obj);
    void add_link_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, realm::null);
    void add_link_constraint(NSPredicateOperatorType, const ColumnReference&, const ColumnReference&);

    template <CollectionOperation::Type Operation, typename R>
    void add_collection_operation_constraint(RLMPropertyType propertyType, NSPredicateOperatorType operatorType,
                                             const CollectionOperation& collectionOperation, R rhs);
    template <typename R>
    void add_collection_operation_constraint(NSPredicateOperatorType operatorType,
                                             const CollectionOperation& collectionOperation, R rhs);


    CollectionOperation collection_operation_from_key_path(RLMObjectSchema *desc, NSString *keyPath);
    ColumnReference column_reference_from_key_path(RLMObjectSchema *objectSchema, NSString *keyPath, bool isAggregate);

private:
    Query& m_query;
    Group& m_group;
    RLMSchema *m_schema;
};

// add a clause for numeric constraints based on operator type
template <typename A, typename B>
void QueryBuilder::add_numeric_constraint(RLMPropertyType datatype,
                                          NSPredicateOperatorType operatorType,
                                          A&& lhs, B&& rhs)
{
    switch (operatorType) {
        case NSLessThanPredicateOperatorType:
            m_query.and_query(lhs < rhs);
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            m_query.and_query(lhs <= rhs);
            break;
        case NSGreaterThanPredicateOperatorType:
            m_query.and_query(lhs > rhs);
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            m_query.and_query(lhs >= rhs);
            break;
        case NSEqualToPredicateOperatorType:
            m_query.and_query(lhs == rhs);
            break;
        case NSNotEqualToPredicateOperatorType:
            m_query.and_query(lhs != rhs);
            break;
        default:
            unsupportedOperator(datatype, operatorType);
    }
}

template <typename A, typename B>
void QueryBuilder::add_bool_constraint(RLMPropertyType datatype,
                                       NSPredicateOperatorType operatorType,
                                       A&& lhs, B&& rhs) {
    switch (operatorType) {
        case NSEqualToPredicateOperatorType:
            m_query.and_query(lhs == rhs);
            break;
        case NSNotEqualToPredicateOperatorType:
            m_query.and_query(lhs != rhs);
            break;
        default:
            unsupportedOperator(datatype, operatorType);
    }
}

void QueryBuilder::add_substring_constraint(null, Query) {
    // Foundation always returns false for substring operations with a RHS of null or "".
    m_query.and_query(std::unique_ptr<Expression>(new FalseExpression));
}

template<typename T>
void QueryBuilder::add_substring_constraint(const T& value, Query condition) {
    // Foundation always returns false for substring operations with a RHS of null or "".
    m_query.and_query(value.size()
                      ? std::move(condition)
                      : std::unique_ptr<Expression>(new FalseExpression));
}

template<typename T>
void QueryBuilder::add_substring_constraint(const Columns<T>& value, Query condition) {
    // Foundation always returns false for substring operations with a RHS of null or "".
    // We don't need to concern ourselves with the possibility of value traversing a link list
    // and producing multiple values per row as such expressions will have been rejected.
    m_query.and_query(const_cast<Columns<String>&>(value).size() != 0 && std::move(condition));
}


template<typename Comparator>
Query make_diacritic_insensitive_constraint(bool caseSensitive, std::unique_ptr<Subexpr> left, std::unique_ptr<Subexpr> right) {
    using CompareCS = Compare<typename Comparator::CaseSensitive>;
    using CompareCI = Compare<typename Comparator::CaseInsensitive>;
    if (caseSensitive) {
        return make_expression<CompareCS>(std::move(left), std::move(right));
    }
    else {
        return make_expression<CompareCI>(std::move(left), std::move(right));
    }
};

Query make_diacritic_insensitive_constraint(NSPredicateOperatorType operatorType, bool caseSensitive,
                                            std::unique_ptr<Subexpr> left, std::unique_ptr<Subexpr> right) {
    switch (operatorType) {
        case NSBeginsWithPredicateOperatorType: {
            constexpr auto flags = kCFCompareDiacriticInsensitive | kCFCompareAnchored;
            return make_diacritic_insensitive_constraint<ContainsSubstring<flags>>(caseSensitive, std::move(left), std::move(right));
        }
        case NSEndsWithPredicateOperatorType: {
            constexpr auto flags = kCFCompareDiacriticInsensitive | kCFCompareAnchored | kCFCompareBackwards;
            return make_diacritic_insensitive_constraint<ContainsSubstring<flags>>(caseSensitive, std::move(left), std::move(right));
        }
        case NSContainsPredicateOperatorType: {
            constexpr auto flags = kCFCompareDiacriticInsensitive;
            return make_diacritic_insensitive_constraint<ContainsSubstring<flags>>(caseSensitive, std::move(left), std::move(right));
        }
        default:
            REALM_COMPILER_HINT_UNREACHABLE();
    }
}

template <typename T>
void QueryBuilder::add_string_constraint(NSPredicateOperatorType operatorType,
                                         NSComparisonPredicateOptions predicateOptions,
                                         Columns<String> &&column,
                                         T value) {
    bool caseSensitive = !(predicateOptions & NSCaseInsensitivePredicateOption);
    bool diacriticSensitive = !(predicateOptions & NSDiacriticInsensitivePredicateOption);

    if (diacriticSensitive) {
        switch (operatorType) {
            case NSBeginsWithPredicateOperatorType:
                add_substring_constraint(value, column.begins_with(value, caseSensitive));
                break;
            case NSEndsWithPredicateOperatorType:
                add_substring_constraint(value, column.ends_with(value, caseSensitive));
                break;
            case NSContainsPredicateOperatorType:
                add_substring_constraint(value, column.contains(value, caseSensitive));
                break;
            case NSEqualToPredicateOperatorType:
                m_query.and_query(column.equal(value, caseSensitive));
                break;
            case NSNotEqualToPredicateOperatorType:
                m_query.and_query(column.not_equal(value, caseSensitive));
                break;
            case NSLikePredicateOperatorType:
                m_query.and_query(column.like(value, caseSensitive));
                break;
            default:
                unsupportedOperator(RLMPropertyTypeString, operatorType);
        }
        return;
    }

    auto as_subexpr = util::overload{
        [](StringData value) { return make_subexpr<ConstantStringValue>(value); },
        [](const Columns<String>& c) { return c.clone(); }
    };
    auto left = as_subexpr(column);
    auto right = as_subexpr(value);

    switch (operatorType) {
        case NSBeginsWithPredicateOperatorType:
        case NSEndsWithPredicateOperatorType:
        case NSContainsPredicateOperatorType:
            add_substring_constraint(value, make_diacritic_insensitive_constraint(operatorType, caseSensitive, std::move(left), std::move(right)));
            break;
        case NSNotEqualToPredicateOperatorType:
            m_query.Not();
            REALM_FALLTHROUGH;
        case NSEqualToPredicateOperatorType:
            m_query.and_query(make_diacritic_insensitive_constraint<Equal<kCFCompareDiacriticInsensitive>>(caseSensitive, std::move(left), std::move(right)));
            break;
        case NSLikePredicateOperatorType:
            throwException(@"Invalid operator type",
                           @"Operator 'LIKE' not supported with diacritic-insensitive modifier.");
        default:
            unsupportedOperator(RLMPropertyTypeString, operatorType);
    }
}

id value_from_constant_expression_or_value(id value) {
    if (NSExpression *exp = RLMDynamicCast<NSExpression>(value)) {
        RLMPrecondition(exp.expressionType == NSConstantValueExpressionType,
                        @"Invalid value",
                        @"Expressions within predicate aggregates must be constant values");
        return exp.constantValue;
    }
    return value;
}

void validate_and_extract_between_range(id value, RLMProperty *prop, id *from, id *to) {
    NSArray *array = RLMDynamicCast<NSArray>(value);
    RLMPrecondition(array, @"Invalid value", @"object must be of type NSArray for BETWEEN operations");
    RLMPrecondition(array.count == 2, @"Invalid value", @"NSArray object must contain exactly two objects for BETWEEN operations");

    *from = value_from_constant_expression_or_value(array.firstObject);
    *to = value_from_constant_expression_or_value(array.lastObject);
    RLMPrecondition(RLMIsObjectValidForProperty(*from, prop) && RLMIsObjectValidForProperty(*to, prop),
                    @"Invalid value",
                    @"NSArray objects must be of type %@ for BETWEEN operations", RLMTypeToString(prop.type));
}

void QueryBuilder::add_between_constraint(const ColumnReference& column, id value) {
    if (column.has_any_to_many_links()) {
        auto link_column = column.last_link_column();
        Query subquery = get_table(m_group, link_column.link_target_object_schema()).where();
        QueryBuilder(subquery, m_group, m_schema).add_between_constraint(column.column_ignoring_links(subquery), value);

        m_query.and_query(link_column.resolve<Link>(std::move(subquery)).count() > 0);
        return;
    }

    id from, to;
    validate_and_extract_between_range(value, column.property(), &from, &to);

    RLMPropertyType type = column.type();

    m_query.group();
    add_constraint(type, NSGreaterThanOrEqualToPredicateOperatorType, 0, column, from);
    add_constraint(type, NSLessThanOrEqualToPredicateOperatorType, 0, column, to);
    m_query.end_group();
}

void QueryBuilder::add_binary_constraint(NSPredicateOperatorType operatorType,
                                         const ColumnReference& column,
                                         BinaryData value) {
    RLMPrecondition(!column.has_links(), @"Unsupported operator", @"NSData properties cannot be queried over an object link.");

    auto index = column.column();
    Query query = m_query.get_table()->where();

    switch (operatorType) {
        case NSBeginsWithPredicateOperatorType:
            add_substring_constraint(value, query.begins_with(index, value));
            break;
        case NSEndsWithPredicateOperatorType:
            add_substring_constraint(value, query.ends_with(index, value));
            break;
        case NSContainsPredicateOperatorType:
            add_substring_constraint(value, query.contains(index, value));
            break;
        case NSEqualToPredicateOperatorType:
            m_query.equal(index, value);
            break;
        case NSNotEqualToPredicateOperatorType:
            m_query.not_equal(index, value);
            break;
        default:
            unsupportedOperator(RLMPropertyTypeData, operatorType);
    }
}

void QueryBuilder::add_binary_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, id value) {
    add_binary_constraint(operatorType, column, RLMBinaryDataForNSData(value));
}

void QueryBuilder::add_binary_constraint(NSPredicateOperatorType operatorType, const ColumnReference& column, null) {
    add_binary_constraint(operatorType, column, BinaryData());
}

void QueryBuilder::add_binary_constraint(NSPredicateOperatorType, const ColumnReference&, const ColumnReference&) {
    throwException(@"Invalid predicate", @"Comparisons between two NSData properties are not supported");
}

void QueryBuilder::add_link_constraint(NSPredicateOperatorType operatorType,
                                       const ColumnReference& column, RLMObjectBase *obj) {
    if (!obj->_row.is_valid()) {
        // Unmanaged or deleted objects are not equal to any managed objects.
        // For arrays this effectively checks if there are any objects in the
        // array, while for links it's just always constant true or false
        // (for != and = respectively).
        if (column.property().array) {
            add_bool_constraint(RLMPropertyTypeObject, operatorType, column.resolve<Link>(), null());
        }
        else if (operatorType == NSEqualToPredicateOperatorType) {
            m_query.and_query(std::unique_ptr<Expression>(new FalseExpression));
        }
        else {
            m_query.and_query(std::unique_ptr<Expression>(new TrueExpression));
        }
    }
    else {
        add_bool_constraint(RLMPropertyTypeObject, operatorType, column.resolve<Link>(), obj->_row);
    }
}

void QueryBuilder::add_link_constraint(NSPredicateOperatorType operatorType,
                                       const ColumnReference& column,
                                       realm::null) {
    add_bool_constraint(RLMPropertyTypeObject, operatorType, column.resolve<Link>(), null());
}

void QueryBuilder::add_link_constraint(NSPredicateOperatorType, const ColumnReference&, const ColumnReference&) {
    // This is not actually reachable as this case is caught earlier, but this
    // overload is needed for the code to compile
    REALM_COMPILER_HINT_UNREACHABLE();
}


// iterate over an array of subpredicates, using @func to build a query from each
// one and ORing them together
template<typename Func>
void process_or_group(Query &query, id array, Func&& func) {
    array = RLMAsFastEnumeration(array);
    RLMPrecondition(array, @"Invalid value", @"IN clause requires an array of items");

    query.group();

    bool first = true;
    for (id item in array) {
        if (!first) {
            query.Or();
        }
        first = false;

        func(item);
    }

    if (first) {
        // Queries can't be empty, so if there's zero things in the OR group
        // validation will fail. Work around this by adding an expression which
        // will never find any rows in a table.
        query.and_query(std::unique_ptr<Expression>(new FalseExpression));
    }

    query.end_group();
}

template <typename RequestedType>
RequestedType convert(id value);

template <>
Timestamp convert<Timestamp>(id value) {
    return RLMTimestampForNSDate(value);
}

template <>
bool convert<bool>(id value) {
    return [value boolValue];
}

template <>
Double convert<Double>(id value) {
    return [value doubleValue];
}

template <>
Float convert<Float>(id value) {
    return [value floatValue];
}

template <>
Int convert<Int>(id value) {
    return [value longLongValue];
}

template <>
String convert<String>(id value) {
    return RLMStringDataWithNSString(value);
}

template <>
Decimal128 convert<Decimal128>(id value) {
    return RLMObjcToDecimal128(value);
}

template <>
ObjectId convert<ObjectId>(id value) {
    if (auto objectId = RLMDynamicCast<RLMObjectId>(value)) {
        return objectId.value;
    }
    if (auto string = RLMDynamicCast<NSString>(value)) {
        return ObjectId(string.UTF8String);
    }
    @throw RLMException(@"Cannot convert value '%@' of type '%@' to object id", value, [value class]);
}

template <typename>
realm::null value_of_type(realm::null) {
    return realm::null();
}

template <typename RequestedType>
auto value_of_type(id value) {
    return ::convert<RequestedType>(value);
}

template <typename RequestedType>
auto value_of_type(const ColumnReference& column) {
    return column.resolve<RequestedType>();
}


template <typename... T>
void QueryBuilder::do_add_constraint(RLMPropertyType type, NSPredicateOperatorType operatorType,
                                     NSComparisonPredicateOptions predicateOptions, T&&... values)
{
    static_assert(sizeof...(T) == 2, "do_add_constraint accepts only two values as arguments");

    switch (type) {
        case RLMPropertyTypeBool:
            add_bool_constraint(type, operatorType, value_of_type<bool>(values)...);
            break;
        case RLMPropertyTypeObjectId:
            add_bool_constraint(type, operatorType, value_of_type<realm::ObjectId>(values)...);
            break;
        case RLMPropertyTypeDate:
            add_numeric_constraint(type, operatorType, value_of_type<realm::Timestamp>(values)...);
            break;
        case RLMPropertyTypeDouble:
            add_numeric_constraint(type, operatorType, value_of_type<Double>(values)...);
            break;
        case RLMPropertyTypeFloat:
            add_numeric_constraint(type, operatorType, value_of_type<Float>(values)...);
            break;
        case RLMPropertyTypeInt:
            add_numeric_constraint(type, operatorType, value_of_type<Int>(values)...);
            break;
        case RLMPropertyTypeDecimal128:
            add_numeric_constraint(type, operatorType, value_of_type<realm::Decimal128>(values)...);
            break;
        case RLMPropertyTypeString:
            add_string_constraint(operatorType, predicateOptions, value_of_type<String>(values)...);
            break;
        case RLMPropertyTypeData:
            add_binary_constraint(operatorType, values...);
            break;
        case RLMPropertyTypeObject:
        case RLMPropertyTypeLinkingObjects:
            add_link_constraint(operatorType, values...);
            break;
        default:
            throwException(@"Unsupported predicate value type",
                           @"Object type %@ not supported", RLMTypeToString(type));
    }
}

void QueryBuilder::do_add_constraint(RLMPropertyType, NSPredicateOperatorType, NSComparisonPredicateOptions, id, realm::null)
{
    // This is not actually reachable as this case is caught earlier, but this
    // overload is needed for the code to compile
    throwException(@"Invalid predicate expressions",
                   @"Predicate expressions must compare a keypath and another keypath or a constant value");
}

bool is_nsnull(id value) {
    return !value || value == NSNull.null;
}

template<typename T>
bool is_nsnull(T) {
    return false;
}

template <typename R>
void QueryBuilder::add_constraint(RLMPropertyType type, NSPredicateOperatorType operatorType,
                                  NSComparisonPredicateOptions predicateOptions, ColumnReference const& column, R const& rhs)
{
    if (is_nsnull(rhs)) {
        do_add_constraint(type, operatorType, predicateOptions, column, realm::null());
    }
    else {
        do_add_constraint(type, operatorType, predicateOptions, column, rhs);
    }
}

struct KeyPath {
    std::vector<RLMProperty *> links;
    RLMProperty *property;
    bool containsToManyRelationship;
};

KeyPath key_path_from_string(RLMSchema *schema, RLMObjectSchema *objectSchema, NSString *keyPath)
{
    RLMProperty *property;
    std::vector<RLMProperty *> links;

    bool keyPathContainsToManyRelationship = false;

    NSUInteger start = 0, length = keyPath.length, end = NSNotFound;
    do {
        end = [keyPath rangeOfString:@"." options:0 range:{start, length - start}].location;
        NSString *propertyName = [keyPath substringWithRange:{start, end == NSNotFound ? length - start : end - start}];
        property = objectSchema[propertyName];
        RLMPrecondition(property, @"Invalid property name",
                        @"Property '%@' not found in object of type '%@'",
                        propertyName, objectSchema.className);

        if (property.array)
            keyPathContainsToManyRelationship = true;

        if (end != NSNotFound) {
            RLMPrecondition(property.type == RLMPropertyTypeObject || property.type == RLMPropertyTypeLinkingObjects,
                            @"Invalid value", @"Property '%@' is not a link in object of type '%@'",
                            propertyName, objectSchema.className);

            links.push_back(property);
            REALM_ASSERT(property.objectClassName);
            objectSchema = schema[property.objectClassName];
        }

        start = end + 1;
    } while (end != NSNotFound);

    return {std::move(links), property, keyPathContainsToManyRelationship};
}

ColumnReference QueryBuilder::column_reference_from_key_path(RLMObjectSchema *objectSchema,
                                                             NSString *keyPathString, bool isAggregate)
{
    auto keyPath = key_path_from_string(m_schema, objectSchema, keyPathString);

    if (isAggregate && !keyPath.containsToManyRelationship) {
        throwException(@"Invalid predicate",
                       @"Aggregate operations can only be used on key paths that include an array property");
    } else if (!isAggregate && keyPath.containsToManyRelationship) {
        throwException(@"Invalid predicate",
                       @"Key paths that include an array property must use aggregate operations");
    }

    return ColumnReference(m_query, m_group, m_schema, keyPath.property, std::move(keyPath.links));
}

void validate_property_value(const ColumnReference& column,
                             __unsafe_unretained id const value,
                             __unsafe_unretained NSString *const err,
                             __unsafe_unretained RLMObjectSchema *const objectSchema,
                             __unsafe_unretained NSString *const keyPath) {
    RLMProperty *prop = column.property();
    if (prop.array) {
        RLMPrecondition([RLMObjectBaseObjectSchema(RLMDynamicCast<RLMObjectBase>(value)).className isEqualToString:prop.objectClassName],
                        @"Invalid value", err, prop.objectClassName, keyPath, objectSchema.className, value);
    }
    else {
        RLMPrecondition(RLMIsObjectValidForProperty(value, prop),
                        @"Invalid value", err, RLMTypeToString(prop.type), keyPath, objectSchema.className, value);
    }
    if (RLMObjectBase *obj = RLMDynamicCast<RLMObjectBase>(value)) {
        RLMPrecondition(!obj->_row.is_valid() || &column.group() == &obj->_realm.group,
                        @"Invalid value origin", @"Object must be from the Realm being queried");
    }
}

template <typename Requested, CollectionOperation::Type OperationType>
auto collection_operation_expr(CollectionOperation operation) {
    auto&& resolved = operation.link_column().resolve<Link>();
    auto col = operation.column().column();

    REALM_ASSERT(operation.type() == OperationType);
    if constexpr (OperationType == CollectionOperation::Count) {
        return resolved.count();
    }
    if constexpr (OperationType == CollectionOperation::Minimum) {
        return resolved.template column<Requested>(col).min();
    }
    if constexpr (OperationType == CollectionOperation::Maximum) {
        return resolved.template column<Requested>(col).max();
    }
    if constexpr (OperationType == CollectionOperation::Sum) {
        return resolved.template column<Requested>(col).sum();
    }
    if constexpr (OperationType == CollectionOperation::Average) {
        return resolved.template column<Requested>(col).average();
    }
    REALM_UNREACHABLE();
}

template <CollectionOperation::Type Operation, typename R>
void QueryBuilder::add_collection_operation_constraint(RLMPropertyType propertyType, NSPredicateOperatorType operatorType,
                                                       CollectionOperation const& collectionOperation, R rhs)
{
    switch (propertyType) {
        case RLMPropertyTypeInt:
            add_numeric_constraint(propertyType, operatorType,
                                   collection_operation_expr<Int, Operation>(collectionOperation),
                                   value_of_type<Int>(rhs));
            break;
        case RLMPropertyTypeFloat:
            add_numeric_constraint(propertyType, operatorType,
                                   collection_operation_expr<Float, Operation>(collectionOperation),
                                   value_of_type<Float>(rhs));
            break;
        case RLMPropertyTypeDouble:
            add_numeric_constraint(propertyType, operatorType,
                                   collection_operation_expr<Double, Operation>(collectionOperation),
                                   value_of_type<Double>(rhs));
            break;
        case RLMPropertyTypeDecimal128:
            add_numeric_constraint(propertyType, operatorType,
                                   collection_operation_expr<Decimal128, Operation>(collectionOperation),
                                   value_of_type<Decimal128>(rhs));
            break;
        default:
            REALM_ASSERT(false && "Only numeric property types should hit this path.");
    }
}

template <typename R>
void QueryBuilder::add_collection_operation_constraint(NSPredicateOperatorType operatorType,
                                                       CollectionOperation const& collectionOperation, R rhs)
{
    auto&& resolved = collectionOperation.link_column().resolve<Link>();

    if (collectionOperation.type() == CollectionOperation::Count) {
        add_numeric_constraint(RLMPropertyTypeInt, operatorType,
                               resolved.count(), value_of_type<Int>(rhs));
        return;
    }

    auto col = collectionOperation.column().column();
    auto type = collectionOperation.column().type();
    switch (collectionOperation.type()) {
        case CollectionOperation::Count:
            break;
        case CollectionOperation::Minimum:
            add_collection_operation_constraint<CollectionOperation::Minimum>(type, operatorType, collectionOperation, rhs);
            break;
        case CollectionOperation::Maximum:
            add_collection_operation_constraint<CollectionOperation::Maximum>(type, operatorType, collectionOperation, rhs);
            break;
        case CollectionOperation::Sum:
            add_collection_operation_constraint<CollectionOperation::Sum>(type, operatorType, collectionOperation, rhs);
            break;
        case CollectionOperation::Average:
            add_collection_operation_constraint<CollectionOperation::Average>(type, operatorType, collectionOperation, rhs);
            break;
    }
}

bool key_path_contains_collection_operator(NSString *keyPath) {
    return [keyPath rangeOfString:@"@"].location != NSNotFound;
}

NSString *get_collection_operation_name_from_key_path(NSString *keyPath, NSString **leadingKeyPath,
                                                      NSString **trailingKey) {
    NSRange at  = [keyPath rangeOfString:@"@"];
    if (at.location == NSNotFound || at.location >= keyPath.length - 1) {
        throwException(@"Invalid key path", @"'%@' is not a valid key path'", keyPath);
    }

    if (at.location == 0 || [keyPath characterAtIndex:at.location - 1] != '.') {
        throwException(@"Invalid key path", @"'%@' is not a valid key path'", keyPath);
    }

    NSRange trailingKeyRange = [keyPath rangeOfString:@"." options:0 range:{at.location, keyPath.length - at.location} locale:nil];

    *leadingKeyPath = [keyPath substringToIndex:at.location - 1];
    if (trailingKeyRange.location == NSNotFound) {
        *trailingKey = nil;
        return [keyPath substringFromIndex:at.location];
    } else {
        *trailingKey = [keyPath substringFromIndex:trailingKeyRange.location + 1];
        return [keyPath substringWithRange:{at.location, trailingKeyRange.location - at.location}];
    }
}

CollectionOperation QueryBuilder::collection_operation_from_key_path(RLMObjectSchema *desc, NSString *keyPath) {
    NSString *leadingKeyPath;
    NSString *trailingKey;
    NSString *collectionOperationName = get_collection_operation_name_from_key_path(keyPath, &leadingKeyPath, &trailingKey);

    ColumnReference linkColumn = column_reference_from_key_path(desc, leadingKeyPath, true);
    util::Optional<ColumnReference> column;
    if (trailingKey) {
        RLMPrecondition([trailingKey rangeOfString:@"."].location == NSNotFound, @"Invalid key path",
                        @"Right side of collection operator may only have a single level key");
        NSString *fullKeyPath = [leadingKeyPath stringByAppendingFormat:@".%@", trailingKey];
        column = column_reference_from_key_path(desc, fullKeyPath, true);
    }

    return {collectionOperationName, std::move(linkColumn), std::move(column)};
}

NSPredicateOperatorType invert_comparison_operator(NSPredicateOperatorType type) {
    switch (type) {
        case NSLessThanPredicateOperatorType:
            return NSGreaterThanPredicateOperatorType;
        case NSLessThanOrEqualToPredicateOperatorType:
            return NSGreaterThanOrEqualToPredicateOperatorType;
        case NSGreaterThanPredicateOperatorType:
            return NSLessThanPredicateOperatorType;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            return NSLessThanOrEqualToPredicateOperatorType;
        case NSBeginsWithPredicateOperatorType:
        case NSEndsWithPredicateOperatorType:
        case NSContainsPredicateOperatorType:
        case NSLikePredicateOperatorType:
            throwException(@"Unsupported predicate", @"Operator '%@' requires a keypath on the left side.", operatorName(type));
        default:
            return type;
    }
}

void QueryBuilder::apply_collection_operator_expression(RLMObjectSchema *desc,
                                                        NSString *keyPath, id value,
                                                        NSComparisonPredicate *pred) {
    CollectionOperation operation = collection_operation_from_key_path(desc, keyPath);
    operation.validate_comparison(value);

    auto type = pred.predicateOperatorType;
    if (pred.leftExpression.expressionType != NSKeyPathExpressionType) {
        // Turn "a > b" into "b < a" so that we can always put the column on the lhs
        type = invert_comparison_operator(type);
    }
    add_collection_operation_constraint(type, operation, value);
}

void QueryBuilder::apply_value_expression(RLMObjectSchema *desc,
                                          NSString *keyPath, id value,
                                          NSComparisonPredicate *pred)
{
    if (key_path_contains_collection_operator(keyPath)) {
        apply_collection_operator_expression(desc, keyPath, value, pred);
        return;
    }

    bool isAny = pred.comparisonPredicateModifier == NSAnyPredicateModifier;
    ColumnReference column = column_reference_from_key_path(desc, keyPath, isAny);

    // check to see if this is a between query
    if (pred.predicateOperatorType == NSBetweenPredicateOperatorType) {
        add_between_constraint(std::move(column), value);
        return;
    }

    // turn "key.path IN collection" into ored together ==. "collection IN key.path" is handled elsewhere.
    if (pred.predicateOperatorType == NSInPredicateOperatorType) {
        process_or_group(m_query, value, [&](id item) {
            id normalized = value_from_constant_expression_or_value(item);
            validate_property_value(column, normalized,
                                    @"Expected object of type %@ in IN clause for property '%@' on object of type '%@', but received: %@", desc, keyPath);
            add_constraint(column.type(), NSEqualToPredicateOperatorType, pred.options, column, normalized);
        });
        return;
    }

    validate_property_value(column, value, @"Expected object of type %@ for property '%@' on object of type '%@', but received: %@", desc, keyPath);
    if (pred.leftExpression.expressionType == NSKeyPathExpressionType) {
        add_constraint(column.type(), pred.predicateOperatorType, pred.options, std::move(column), value);
    } else {
        add_constraint(column.type(), invert_comparison_operator(pred.predicateOperatorType), pred.options, std::move(column), value);
    }
}

void QueryBuilder::apply_column_expression(RLMObjectSchema *desc,
                                           NSString *leftKeyPath, NSString *rightKeyPath,
                                           NSComparisonPredicate *predicate)
{
    bool left_key_path_contains_collection_operator = key_path_contains_collection_operator(leftKeyPath);
    bool right_key_path_contains_collection_operator = key_path_contains_collection_operator(rightKeyPath);
    if (left_key_path_contains_collection_operator && right_key_path_contains_collection_operator) {
        throwException(@"Unsupported predicate", @"Key paths including aggregate operations cannot be compared with other aggregate operations.");
    }

    if (left_key_path_contains_collection_operator) {
        CollectionOperation left = collection_operation_from_key_path(desc, leftKeyPath);
        ColumnReference right = column_reference_from_key_path(desc, rightKeyPath, false);
        left.validate_comparison(right);
        add_collection_operation_constraint(predicate.predicateOperatorType, left, std::move(right));
        return;
    }
    if (right_key_path_contains_collection_operator) {
        ColumnReference left = column_reference_from_key_path(desc, leftKeyPath, false);
        CollectionOperation right = collection_operation_from_key_path(desc, rightKeyPath);
        right.validate_comparison(left);
        add_collection_operation_constraint(invert_comparison_operator(predicate.predicateOperatorType),
                                            right, std::move(left));
        return;
    }

    bool isAny = false;
    ColumnReference left = column_reference_from_key_path(desc, leftKeyPath, isAny);
    ColumnReference right = column_reference_from_key_path(desc, rightKeyPath, isAny);

    // NOTE: It's assumed that column type must match and no automatic type conversion is supported.
    RLMPrecondition(left.type() == right.type(),
                    RLMPropertiesComparisonTypeMismatchException,
                    RLMPropertiesComparisonTypeMismatchReason,
                    RLMTypeToString(left.type()),
                    RLMTypeToString(right.type()));

    // TODO: Should we handle special case where left row is the same as right row (tautology)
    add_constraint(left.type(), predicate.predicateOperatorType, predicate.options,
                   std::move(left), std::move(right));
}

// Identify expressions of the form [SELF valueForKeyPath:]
bool is_self_value_for_key_path_function_expression(NSExpression *expression)
{
    if (expression.expressionType != NSFunctionExpressionType)
        return false;

    if (expression.operand.expressionType != NSEvaluatedObjectExpressionType)
        return false;

    return [expression.function isEqualToString:@"valueForKeyPath:"];
}

// -[NSPredicate predicateWithSubtitutionVariables:] results in function expressions of the form [SELF valueForKeyPath:]
// that apply_predicate cannot handle. Replace such expressions with equivalent NSKeyPathExpressionType expressions.
NSExpression *simplify_self_value_for_key_path_function_expression(NSExpression *expression) {
    if (is_self_value_for_key_path_function_expression(expression)) {
        if (NSString *keyPath = [expression.arguments.firstObject keyPath]) {
            return [NSExpression expressionForKeyPath:keyPath];
        }
    }
    return expression;
}

void QueryBuilder::apply_function_expression(RLMObjectSchema *objectSchema, NSExpression *functionExpression,
                                             NSPredicateOperatorType operatorType, NSExpression *right) {
    RLMPrecondition(functionExpression.operand.expressionType == NSSubqueryExpressionType,
                    @"Invalid predicate", @"The '%@' function is not supported.", functionExpression.function);
    RLMPrecondition([functionExpression.function isEqualToString:@"valueForKeyPath:"] && functionExpression.arguments.count == 1,
                    @"Invalid predicate", @"The '%@' function is not supported on the result of a SUBQUERY.", functionExpression.function);

    NSExpression *keyPathExpression = functionExpression.arguments.firstObject;
    RLMPrecondition([keyPathExpression.keyPath isEqualToString:@"@count"],
                    @"Invalid predicate", @"SUBQUERY is only supported when immediately followed by .@count that is compared with a constant number.");
    RLMPrecondition(right.expressionType == NSConstantValueExpressionType && [right.constantValue isKindOfClass:[NSNumber class]],
                    @"Invalid predicate expression", @"SUBQUERY(…).@count is only supported when compared with a constant number.");

    NSExpression *subqueryExpression = functionExpression.operand;
    int64_t value = [right.constantValue integerValue];

    ColumnReference collectionColumn = column_reference_from_key_path(objectSchema, [subqueryExpression.collection keyPath], true);
    RLMObjectSchema *collectionMemberObjectSchema = m_schema[collectionColumn.property().objectClassName];

    // Eliminate references to the iteration variable in the subquery.
    NSPredicate *subqueryPredicate = [subqueryExpression.predicate predicateWithSubstitutionVariables:@{subqueryExpression.variable: [NSExpression expressionForEvaluatedObject]}];
    subqueryPredicate = transformPredicate(subqueryPredicate, simplify_self_value_for_key_path_function_expression);

    Query subquery = RLMPredicateToQuery(subqueryPredicate, collectionMemberObjectSchema, m_schema, m_group);
    add_numeric_constraint(RLMPropertyTypeInt, operatorType,
                           collectionColumn.resolve<Link>(std::move(subquery)).count(), value);
}

void QueryBuilder::apply_predicate(NSPredicate *predicate, RLMObjectSchema *objectSchema)
{
    // Compound predicates.
    if ([predicate isMemberOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *comp = (NSCompoundPredicate *)predicate;

        switch ([comp compoundPredicateType]) {
            case NSAndPredicateType:
                if (comp.subpredicates.count) {
                    // Add all of the subpredicates.
                    m_query.group();
                    for (NSPredicate *subp in comp.subpredicates) {
                        apply_predicate(subp, objectSchema);
                    }
                    m_query.end_group();
                } else {
                    // NSCompoundPredicate's documentation states that an AND predicate with no subpredicates evaluates to TRUE.
                    m_query.and_query(std::unique_ptr<Expression>(new TrueExpression));
                }
                break;

            case NSOrPredicateType: {
                // Add all of the subpredicates with ors inbetween.
                process_or_group(m_query, comp.subpredicates, [&](__unsafe_unretained NSPredicate *const subp) {
                    apply_predicate(subp, objectSchema);
                });
                break;
            }

            case NSNotPredicateType:
                // Add the negated subpredicate
                m_query.Not();
                apply_predicate(comp.subpredicates.firstObject, objectSchema);
                break;

            default:
                throwException(@"Invalid compound predicate type",
                               @"Only support AND, OR and NOT predicate types");
        }
    }
    else if ([predicate isMemberOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *compp = (NSComparisonPredicate *)predicate;

        RLMPrecondition(compp.comparisonPredicateModifier != NSAllPredicateModifier,
                        @"Invalid predicate", @"ALL modifier not supported");

        NSExpressionType exp1Type = compp.leftExpression.expressionType;
        NSExpressionType exp2Type = compp.rightExpression.expressionType;

        if (compp.comparisonPredicateModifier == NSAnyPredicateModifier) {
            // for ANY queries
            RLMPrecondition(exp1Type == NSKeyPathExpressionType && exp2Type == NSConstantValueExpressionType,
                            @"Invalid predicate",
                            @"Predicate with ANY modifier must compare a KeyPath with RLMArray with a value");
        }

        if (compp.predicateOperatorType == NSBetweenPredicateOperatorType || compp.predicateOperatorType == NSInPredicateOperatorType) {
            // Inserting an array via %@ gives NSConstantValueExpressionType, but including it directly gives NSAggregateExpressionType
            if (exp1Type == NSKeyPathExpressionType && (exp2Type == NSAggregateExpressionType || exp2Type == NSConstantValueExpressionType)) {
                // "key.path IN %@", "key.path IN {…}", "key.path BETWEEN %@", or "key.path BETWEEN {…}".
                exp2Type = NSConstantValueExpressionType;
            }
            else if (compp.predicateOperatorType == NSInPredicateOperatorType && exp1Type == NSConstantValueExpressionType && exp2Type == NSKeyPathExpressionType) {
                // "%@ IN key.path" is equivalent to "ANY key.path IN %@". Rewrite the former into the latter.
                compp = [NSComparisonPredicate predicateWithLeftExpression:compp.rightExpression rightExpression:compp.leftExpression
                                                                  modifier:NSAnyPredicateModifier type:NSEqualToPredicateOperatorType options:0];
                exp1Type = NSKeyPathExpressionType;
                exp2Type = NSConstantValueExpressionType;
            }
            else {
                if (compp.predicateOperatorType == NSBetweenPredicateOperatorType) {
                    throwException(@"Invalid predicate",
                                   @"Predicate with BETWEEN operator must compare a KeyPath with an aggregate with two values");
                }
                else if (compp.predicateOperatorType == NSInPredicateOperatorType) {
                    throwException(@"Invalid predicate",
                                   @"Predicate with IN operator must compare a KeyPath with an aggregate");
                }
            }
        }

        if (exp1Type == NSKeyPathExpressionType && exp2Type == NSKeyPathExpressionType) {
            // both expression are KeyPaths
            apply_column_expression(objectSchema, compp.leftExpression.keyPath, compp.rightExpression.keyPath, compp);
        }
        else if (exp1Type == NSKeyPathExpressionType && exp2Type == NSConstantValueExpressionType) {
            // comparing keypath to value
            apply_value_expression(objectSchema, compp.leftExpression.keyPath, compp.rightExpression.constantValue, compp);
        }
        else if (exp1Type == NSConstantValueExpressionType && exp2Type == NSKeyPathExpressionType) {
            // comparing value to keypath
            apply_value_expression(objectSchema, compp.rightExpression.keyPath, compp.leftExpression.constantValue, compp);
        }
        else if (exp1Type == NSFunctionExpressionType) {
            apply_function_expression(objectSchema, compp.leftExpression, compp.predicateOperatorType, compp.rightExpression);
        }
        else if (exp1Type == NSSubqueryExpressionType) {
            // The subquery expressions that we support are handled by the NSFunctionExpressionType case above.
            throwException(@"Invalid predicate expression", @"SUBQUERY is only supported when immediately followed by .@count.");
        }
        else {
            throwException(@"Invalid predicate expressions",
                           @"Predicate expressions must compare a keypath and another keypath or a constant value");
        }
    }
    else if ([predicate isEqual:[NSPredicate predicateWithValue:YES]]) {
        m_query.and_query(std::unique_ptr<Expression>(new TrueExpression));
    } else if ([predicate isEqual:[NSPredicate predicateWithValue:NO]]) {
        m_query.and_query(std::unique_ptr<Expression>(new FalseExpression));
    }
    else {
        // invalid predicate type
        throwException(@"Invalid predicate",
                       @"Only support compound, comparison, and constant predicates");
    }
}
} // namespace

realm::Query RLMPredicateToQuery(NSPredicate *predicate, RLMObjectSchema *objectSchema,
                                 RLMSchema *schema, Group &group)
{
    auto query = get_table(group, objectSchema).where();

    // passing a nil predicate is a no-op
    if (!predicate) {
        return query;
    }

    @autoreleasepool {
        QueryBuilder(query, group, schema).apply_predicate(predicate, objectSchema);
    }

    // Test the constructed query in core
    std::string validateMessage = query.validate();
    RLMPrecondition(validateMessage.empty(), @"Invalid query", @"%.*s",
                    (int)validateMessage.size(), validateMessage.c_str());
    return query;
}

// return the property for a validated column name
RLMProperty *RLMValidatedProperty(RLMObjectSchema *desc, NSString *columnName) {
    RLMProperty *prop = desc[columnName];
    RLMPrecondition(prop, @"Invalid property name",
                    @"Property '%@' not found in object of type '%@'", columnName, desc.className);
    return prop;
}
