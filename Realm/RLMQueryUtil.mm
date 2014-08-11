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
#import "RLMUtil.hpp"
#import "RLMProperty_Private.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObject_Private.h"

#include <tightdb.hpp>
using namespace tightdb;


NSString *const RLMPropertiesComparisonTypeMismatchException = @"RLMPropertiesComparisonTypeMismatchException";
NSString *const RLMUnsupportedTypesFoundInPropertyComparisonException = @"RLMUnsupportedTypesFoundInPropertyComparisonException";

NSString *const RLMPropertiesComparisonTypeMismatchReason = @"Property type mismatch between %@ and %@";
NSString *const RLMUnsupportedTypesFoundInPropertyComparisonReason = @"Comparison between %@ and %@";

// small helper to create the many exceptions thrown when parsing predicates
NSException *RLMPredicateException(NSString *name, NSString *reason) {
    return [NSException exceptionWithName:name reason:reason userInfo:nil];
}

// return the column index for a validated column name
NSUInteger RLMValidatedColumnIndex(RLMObjectSchema *desc, NSString *columnName) {
    RLMProperty *prop = desc[columnName];
    if (!prop) {
        @throw RLMPredicateException(@"Invalid column name",
                                       [NSString stringWithFormat:@"Column name %@ not found in table", columnName]);
    }
    return prop.column;
}

namespace {

// validate that we support the passed in expression type
NSExpressionType validated_expression_type(NSExpression *expression) {
    if (expression.expressionType != NSConstantValueExpressionType &&
        expression.expressionType != NSKeyPathExpressionType) {
        @throw RLMPredicateException(@"Invalid expression type",
                                       @"Only support NSConstantValueExpressionType and NSKeyPathExpressionType");
    }
    return expression.expressionType;
}

//// apply an expression between two columns to a query
//void update_query_with_column_expression(RLMTable *table, tightdb::Query & query,
//                                         NSString *col1, NSString *col2, NSPredicateOperatorType operatorType) {
//    
//    // only support equality for now
//    if (operatorType != NSEqualToPredicateOperatorType) {
//        @throw RLM_predicate_exception(@"Invalid predicate comparison type",
//                                       @"only support equality comparison type");
//    }
//    
//    // validate column names
//    NSUInteger index1 = RLMValidatedColumnIndex(table, col1);
//    NSUInteger index2 = RLMValidatedColumnIndex(table, col2);
//    
//    // make sure they are the same type
//    tightdb::DataType type1 = table->m_table->get_column_type(index1);
//    tightdb::DataType type2 = table->m_table->get_column_type(index2);
//    
//    if (type1 == type2) {
//        @throw RLM_predicate_exception(@"Invalid predicate expression",
//                                       @"Columns must be the same type");
//    }
//    
//    // not suppoting for now - if we changed names for column comparisons so that we could
//    // use templated function for all numeric types this would be much easier
//    @throw RLM_predicate_exception(@"Unsupported predicate",
//                                   @"Not suppoting column comparison for now");
//}

// add a clause for numeric constraints based on operator type
template <typename T>
void add_numeric_constraint_to_query(tightdb::Query & query,
                                     RLMPropertyType datatype,
                                     NSPredicateOperatorType operatorType,
                                     NSUInteger index,
                                     T value) {
    switch (operatorType) {
        case NSLessThanPredicateOperatorType:
            query.less(index, value);
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            query.less_equal(index, value);
            break;
        case NSGreaterThanPredicateOperatorType:
            query.greater(index, value);
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            query.greater_equal(index, value);
            break;
        case NSEqualToPredicateOperatorType:
            query.equal(index, value);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.not_equal(index, value);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                           [NSString stringWithFormat:@"Operator type %lu not supported for type %@", (unsigned long)operatorType, RLMTypeToString(datatype)]);
            break;
    }
}

template <typename T>
void add_numeric_constraint_to_link_query(tightdb::Query& query,
                                          RLMPropertyType datatype,
                                          NSPredicateOperatorType operatorType,
                                          NSUInteger firstIndex,
                                          NSUInteger secondIndex,
                                          T value)
{
    tightdb::TableRef table = query.get_table();

    switch (operatorType) {
        case NSLessThanPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<T>(secondIndex) < value);
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<T>(secondIndex) <= value);
            break;
        case NSGreaterThanPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<T>(secondIndex) > value);
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<T>(secondIndex) >= value);
            break;
        case NSEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<T>(secondIndex) == value);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<T>(secondIndex) != value);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                         [NSString stringWithFormat:@"Operator type %lu not supported for type %@", (unsigned long)operatorType, RLMTypeToString(datatype)]);
            break;
    }
}


void add_bool_constraint_to_query(tightdb::Query & query,
                                  NSPredicateOperatorType operatorType,
                                  NSUInteger index,
                                  bool value) {
    switch (operatorType) {
        case NSEqualToPredicateOperatorType:
            query.equal(index, value);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.not_equal(index, value);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                           [NSString stringWithFormat:@"Operator type %lu not supported for bool type", (unsigned long)operatorType]);
            break;
    }
}

void add_bool_constraint_to_link_query(tightdb::Query& query,
                                       NSPredicateOperatorType operatorType,
                                       NSUInteger firstIndex,
                                       NSUInteger secondIndex,
                                       bool value) {

    tightdb::TableRef table = query.get_table();
    switch (operatorType) {
        case NSEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Bool>(secondIndex) == value);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Bool>(secondIndex) == value);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                         [NSString stringWithFormat:@"Operator type %lu not supported for bool type", (unsigned long)operatorType]);
            break;
    }
}

void add_string_constraint_to_query(tightdb::Query & query,
                                    NSPredicateOperatorType operatorType,
                                    NSComparisonPredicateOptions predicateOptions,
                                    NSUInteger index,
                                    NSString *value) {
    bool caseSensitive = !(predicateOptions & NSCaseInsensitivePredicateOption);
    bool diacriticInsensitive = (predicateOptions & NSDiacriticInsensitivePredicateOption);
    
    if (diacriticInsensitive) {
        @throw RLMPredicateException(@"Invalid predicate option",
                                       @"NSDiacriticInsensitivePredicateOption not supported for string type");
    }
    
    tightdb::StringData sd = RLMStringDataWithNSString(value);
    switch (operatorType) {
        case NSBeginsWithPredicateOperatorType:
            query.begins_with(index, sd, caseSensitive);
            break;
        case NSEndsWithPredicateOperatorType:
            query.ends_with(index, sd, caseSensitive);
            break;
        case NSContainsPredicateOperatorType:
            query.contains(index, sd, caseSensitive);
            break;
        case NSEqualToPredicateOperatorType:
            query.equal(index, sd, caseSensitive);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.not_equal(index, sd, caseSensitive);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                           [NSString stringWithFormat:@"Operator type %lu not supported for string type", (unsigned long)operatorType]);
            break;
    }
}

// FIXME: beginsWith, endsWith, contains missing
// FIXME: not case sensitive
void add_string_constraint_to_link_query(tightdb::Query& query,
                                         NSPredicateOperatorType operatorType,
                                         NSComparisonPredicateOptions predicateOptions,
                                         NSUInteger firstIndex,
                                         NSUInteger secondIndex,
                                         NSString* value) {
    bool diacriticInsensitive = (predicateOptions & NSDiacriticInsensitivePredicateOption);
    if (diacriticInsensitive) {
        @throw RLMPredicateException(@"Invalid predicate option",
                                     @"NSDiacriticInsensitivePredicateOption not supported for string type");
    }

    tightdb::TableRef table = query.get_table();
    tightdb::StringData sd = RLMStringDataWithNSString(value);
    switch (operatorType) {
        case NSBeginsWithPredicateOperatorType:
            @throw RLMPredicateException(@"Invalid type", @"Predicate 'BEGINSWITH' is not supported");
            break;
        case NSEndsWithPredicateOperatorType:
            @throw RLMPredicateException(@"Invalid type", @"Predicate 'ENDSWITH' is not supported");
            break;
        case NSContainsPredicateOperatorType:
            @throw RLMPredicateException(@"Invalid type", @"Predicate 'CONTAINS' is not supported");
            break;
        case NSEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<String>(secondIndex) == sd);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<String>(secondIndex) != sd);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                         [NSString stringWithFormat:@"Operator type %lu not supported for string type", (unsigned long)operatorType]);
            break;
    }
}

void add_datetime_constraint_to_query(tightdb::Query & query,
                                      NSPredicateOperatorType operatorType,
                                      NSUInteger index,
                                      double value) {
    switch (operatorType) {
        case NSLessThanPredicateOperatorType:
            query.less_datetime(index, value);
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            query.less_equal_datetime(index, value);
            break;
        case NSGreaterThanPredicateOperatorType:
            query.greater_datetime(index, value);
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            query.greater_equal_datetime(index, value);
            break;
        case NSEqualToPredicateOperatorType:
            query.equal_datetime(index, value);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.not_equal_datetime(index, value);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                           [NSString stringWithFormat:@"Operator type %lu not supported for type NSDate", (unsigned long)operatorType]);
            break;
    }
}

void add_datetime_constraint_to_link_query(tightdb::Query& query,
                                           NSPredicateOperatorType operatorType,
                                           NSUInteger firstIndex,
                                           NSUInteger secondIndex,
                                           double value)
{
    tightdb::TableRef table = query.get_table();
    switch (operatorType) {
        case NSLessThanPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Int>(secondIndex) < value);
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Int>(secondIndex) <= value);
            break;
        case NSGreaterThanPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Int>(secondIndex) > value);
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Int>(secondIndex) >= value);
            break;
        case NSEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Int>(secondIndex) == value);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.and_query(table->link(firstIndex).column<Int>(secondIndex) != value);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                         [NSString stringWithFormat:@"Operator type %lu not supported for type NSDate", (unsigned long)operatorType]);
            break;
    }
}

void add_between_constraint_to_query(tightdb::Query & query,
                                     RLMObjectSchema *desc,
                                     NSString *columnName,
                                     NSArray *array) {
    // get prop and index
    RLMProperty *prop = desc[columnName];
    NSUInteger index = RLMValidatedColumnIndex(desc, columnName);
    
    // validate value
    if ([array isKindOfClass:[NSArray class]]) {
        if (array.count == 2) {
            if (!RLMIsObjectValidForProperty(array.firstObject, prop) ||
                !RLMIsObjectValidForProperty(array.lastObject, prop)) {
                @throw RLMPredicateException(@"Invalid value",
                                             [NSString stringWithFormat:@"NSArray objects must be of type %@ for BETWEEN operations", RLMTypeToString(prop.type)]);
            }
        } else {
            @throw RLMPredicateException(@"Invalid value", @"NSArray object must contain exactly two objects for BETWEEN operations");
        }
    } else {
        @throw RLMPredicateException(@"Invalid value", @"object must be of type NSArray for BETWEEN operations");
    }
    
    // add to query
    id from = array.firstObject;
    id to = array.lastObject;
    switch (prop.type) {
        case type_DateTime:
            query.between_datetime(index,
                                   double([(NSDate *)from timeIntervalSince1970]),
                                   double([(NSDate *)to timeIntervalSince1970]));
            break;
        case type_Double:
        {
            double fromDouble = [(NSNumber *)from doubleValue];
            double toDouble = [(NSNumber *)to doubleValue];
            query.between(index, fromDouble, toDouble);
            break;
        }
        case type_Float:
        {
            float fromFloat = [(NSNumber *)from floatValue];
            float toFloat = [(NSNumber *)to floatValue];
            query.between(index, fromFloat, toFloat);
            break;
        }
        case type_Int:
        {
            int fromInt = [(NSNumber *)from intValue];
            int toInt = [(NSNumber *)to intValue];
            query.between(index, fromInt, toInt);
            break;
        }
        default:
        {
            NSString *message = [NSString stringWithFormat:@"Object type %@ not supported for BETWEEN operations",
                                 RLMTypeToString(prop.type)];
            @throw RLMPredicateException(@"Unsupported predicate value type", message);
        }
    }
}

void add_binary_constraint_to_query(tightdb::Query & query,
                                    NSPredicateOperatorType operatorType,
                                    NSUInteger index,
                                    NSData *value) {
    tightdb::BinaryData binData = RLMBinaryDataForNSData(value);
    switch (operatorType) {
        case NSBeginsWithPredicateOperatorType:
            query.begins_with(index, binData);
            break;
        case NSEndsWithPredicateOperatorType:
            query.ends_with(index, binData);
            break;
        case NSContainsPredicateOperatorType:
            query.contains(index, binData);
            break;
        case NSEqualToPredicateOperatorType:
            query.equal(index, binData);
            break;
        case NSNotEqualToPredicateOperatorType:
            query.not_equal(index, binData);
            break;
        default:
            @throw RLMPredicateException(@"Invalid operator type",
                                           [NSString stringWithFormat:@"Operator type %lu not supported for binary type", (unsigned long)operatorType]);
            break;
    }
}
    
void add_link_constraint_to_query(tightdb::Query & query,
                                 NSPredicateOperatorType operatorType,
                                 NSUInteger column,
                                 RLMObject *obj) {
    if (operatorType != NSEqualToPredicateOperatorType) {
        @throw RLMPredicateException(@"Invalid operator type", @"Only 'Equal' operator supported for object comparison");
    }
    if (obj) {
        query.links_to(column, obj->_row.get_index());
    }
    else {
        query.and_query(query.get_table()->column<Link>(column).is_null());
    }
}
 
void update_link_query_with_value_expression(RLMSchema *schema,
                                             RLMObjectSchema *desc,
                                             tightdb::Query &query,
                                             NSArray *paths,
                                             id value,
                                             NSComparisonPredicate *pred)
{
    if (pred.predicateOperatorType == NSBetweenPredicateOperatorType) {
        @throw RLMPredicateException(@"Invalid predicate", @"BETWEEN operator not supported for KeyPath queries.");
    }

    // FIXME: when core support multiple levels of link queries
    //        loop through the elements of arr to build up link query
    if (paths.count != 2) {
        @throw RLMPredicateException(@"Invalid predicate", @"Only KeyPaths one level deep are currently supported");
    }
    
    // get the first index and property
    NSUInteger idx1 = RLMValidatedColumnIndex(desc, paths[0]);
    RLMProperty *firstProp = desc[paths[0]];

    // make sure we have a valid property type
    if (firstProp.type != RLMPropertyTypeObject && firstProp.type != RLMPropertyTypeArray) {
        @throw RLMPredicateException(@"Invalid value", [NSString stringWithFormat:@"column name '%@' is not a link", paths[0]]);
    }

    // get the next level index and property
    NSUInteger idx2 = RLMValidatedColumnIndex(schema[firstProp.objectClassName], paths[1]);
    RLMProperty *secondProp = schema[firstProp.objectClassName][paths[1]];

    // validate value
    if (!RLMIsObjectValidForProperty(value, secondProp)) {
        @throw RLMPredicateException(@"Invalid value",
                                     [NSString stringWithFormat:@"object for property '%@' must be of type '%@'",
                                      secondProp.name, RLMTypeToString(secondProp.type)]);
    }

    // finally cast to native types and add query clause
    RLMPropertyType type = secondProp.type;
    NSPredicateOperatorType opType = pred.predicateOperatorType;
    switch (type) {
        case type_Bool:
            add_bool_constraint_to_link_query(query, opType, idx1, idx2, bool([(NSNumber *)value boolValue]));
            break;
        case type_DateTime:
            add_datetime_constraint_to_link_query(query, opType, idx1, idx2, double([(NSDate *)value timeIntervalSince1970]));
            break;
        case type_Double:
            add_numeric_constraint_to_link_query(query, type, opType, idx1, idx2, Double([(NSNumber *)value doubleValue]));
            break;
        case type_Float:
            add_numeric_constraint_to_link_query(query, type, opType, idx1, idx2, Float([(NSNumber *)value floatValue]));
            break;
        case type_Int:
            add_numeric_constraint_to_link_query(query, type, opType, idx1, idx2, Int([(NSNumber *)value intValue]));
            break;
        case type_String:
            add_string_constraint_to_link_query(query, opType, pred.options, idx1, idx2, value);
            break;
        case type_Binary:
            @throw RLMPredicateException(@"Unsupported operator", @"Binary data is not supported.");
        case type_Link:
            add_link_constraint_to_query(query, opType, idx1, value);
            break;
        default:
            @throw RLMPredicateException(@"Unsupported predicate value type",
                                         [NSString stringWithFormat:@"Object type %@ not supported", RLMTypeToString(type)]);
    }
}

void update_query_with_value_expression(RLMSchema *schema,
                                        RLMObjectSchema *desc,
                                        tightdb::Query &query,
                                        NSString *keyPath,
                                        id value,
                                        NSComparisonPredicate *pred)
{
    // split keypath
    NSArray *paths = [keyPath componentsSeparatedByString:@"."];
    RLMProperty *prop = desc[paths[0]];

    // make sure we are not comparing on RLMArray
    if (prop.type == RLMPropertyTypeArray) {
        @throw RLMPredicateException(@"Invalid predicate",
                                     @"RLMArray predicates must contain the ANY modifier");
    }

    // check to see if this is a link query
    if (paths.count > 1) {
        update_link_query_with_value_expression(schema, desc, query, paths, value, pred);
        return;
    }
    
    // check to see if this is a between query
    if (pred.predicateOperatorType == NSBetweenPredicateOperatorType) {
        add_between_constraint_to_query(query, desc, keyPath, value);
        return;
    }
    
    // get prop and index
    NSUInteger index = RLMValidatedColumnIndex(desc, keyPath);
    
    // validate value
    if (!RLMIsObjectValidForProperty(value, prop)) {
        @throw RLMPredicateException(@"Invalid value", [NSString stringWithFormat:@"object must be of type %@", RLMTypeToString(prop.type)]);
    }
    
    // finally cast to native types and add query clause
    RLMPropertyType type = prop.type;
    switch (type) {
        case type_Bool:
            add_bool_constraint_to_query(query, pred.predicateOperatorType, index, bool([(NSNumber *)value boolValue]));
            break;
        case type_DateTime:
            add_datetime_constraint_to_query(query, pred.predicateOperatorType, index, double([(NSDate *)value timeIntervalSince1970]));
            break;
        case type_Double:
            add_numeric_constraint_to_query(query, type, pred.predicateOperatorType, index, [(NSNumber *)value doubleValue]);
            break;
        case type_Float:
            add_numeric_constraint_to_query(query, type, pred.predicateOperatorType, index, [(NSNumber *)value floatValue]);
            break;
        case type_Int:
            add_numeric_constraint_to_query(query, type, pred.predicateOperatorType, index, [(NSNumber *)value intValue]);
            break;
        case type_String:
            add_string_constraint_to_query(query, pred.predicateOperatorType, pred.options, index, value);
            break;
        case type_Binary:
            add_binary_constraint_to_query(query, pred.predicateOperatorType, index, value);
            break;
        case type_Link:
            add_link_constraint_to_query(query, pred.predicateOperatorType, index, value);
            break;
        default:
            @throw RLMPredicateException(@"Unsupported predicate value type",
                                           [NSString stringWithFormat:@"Object type %@ not supported", RLMTypeToString(type)]);
    }
}

template<typename T>
Query column_expression(NSComparisonPredicateOptions operatorType,
                                            NSUInteger leftColumn,
                                            NSUInteger rightColumn,
                                            Table *table) {

    switch (operatorType) {
        case NSEqualToPredicateOperatorType:
            return table->column<T>(leftColumn) == table->column<T>(rightColumn);
        case NSNotEqualToPredicateOperatorType:
            return table->column<T>(leftColumn) != table->column<T>(rightColumn);
        case NSLessThanPredicateOperatorType:
            return table->column<T>(leftColumn) < table->column<T>(rightColumn);
        case NSGreaterThanPredicateOperatorType:
            return table->column<T>(leftColumn) > table->column<T>(rightColumn);
        case NSLessThanOrEqualToPredicateOperatorType:
            return table->column<T>(leftColumn) <= table->column<T>(rightColumn);
        case NSGreaterThanOrEqualToPredicateOperatorType:
            return table->column<T>(leftColumn) >= table->column<T>(rightColumn);
        default:
            @throw RLMPredicateException(@"Unsupported operator", @"Only ==, !=, <, <=, >, and >= are supported comparison operators");
    }
}
    
void update_query_with_column_expression(RLMObjectSchema *scheme, Query &query, NSString *leftColumnName, NSString *rightColumnName, NSComparisonPredicateOptions predicateOptions)
{
    // Validate object types
    NSUInteger leftIndex = RLMValidatedColumnIndex(scheme, leftColumnName);
    RLMPropertyType leftType = [scheme[leftColumnName] type];
    
    NSUInteger rightIndex = RLMValidatedColumnIndex(scheme, rightColumnName);
    RLMPropertyType rightType = [scheme[rightColumnName] type];

    if (leftType == RLMPropertyTypeArray || rightType == RLMPropertyTypeArray) {
        @throw RLMPredicateException(@"Invalid predicate",
                                     @"RLMArray predicates must contain the ANY modifier");
    }

    // TODO: Should we handle special case where left row is the same as right row (tautology)
    // NOTE: It's assumed that column type must match and no automatic type conversion is supported.
    if (leftType == rightType) {
        switch (leftType) {
            case type_Bool:
                query.and_query(column_expression<Bool>(predicateOptions, leftIndex, rightIndex, &(*query.get_table())));
                break;
            case type_Int:
                query.and_query(column_expression<Int>(predicateOptions, leftIndex, rightIndex, &(*query.get_table())));
                break;
            case type_Float:
                query.and_query(column_expression<Float>(predicateOptions, leftIndex, rightIndex, &(*query.get_table())));
                break;
            case type_Double:
                query.and_query(column_expression<Double>(predicateOptions, leftIndex, rightIndex, &(*query.get_table())));
                break;
            case type_DateTime:
                // FIXME: int64_t should be DateTime but that doesn't work on 32 bit
                // FIXME: as time_t(32bit) != time_t(64bit)
                query.and_query(column_expression<int64_t>(predicateOptions, leftIndex, rightIndex, &(*query.get_table())));
                break;
            default:
                @throw RLMPredicateException(RLMUnsupportedTypesFoundInPropertyComparisonException,
                                             [NSString stringWithFormat:RLMUnsupportedTypesFoundInPropertyComparisonReason,
                                              RLMTypeToString(leftType),
                                              RLMTypeToString(rightType)]);
        }
    }
    else {
        @throw RLMPredicateException(RLMPropertiesComparisonTypeMismatchException,
                                     [NSString stringWithFormat:RLMPropertiesComparisonTypeMismatchReason,
                                      RLMTypeToString(leftType),
                                      RLMTypeToString(rightType)]);
    }
}
    
void update_query_with_predicate(NSPredicate *predicate, RLMSchema *schema,
                                 RLMObjectSchema *objectSchema, tightdb::Query & query)
{
    // Compound predicates.
    if ([predicate isMemberOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *comp = (NSCompoundPredicate *)predicate;
        
        switch ([comp compoundPredicateType]) {
            case NSAndPredicateType:
                // Add all of the subpredicates.
                query.group();
                for (NSPredicate *subp in comp.subpredicates) {
                    update_query_with_predicate(subp, schema, objectSchema, query);
                }
                query.end_group();
                break;
                
            case NSOrPredicateType:
                // Add all of the subpredicates with ors inbetween.
                query.group();
                for (NSUInteger i = 0; i < comp.subpredicates.count; i++) {
                    NSPredicate *subp = comp.subpredicates[i];
                    if (i > 0) {
                        query.Or();
                    }
                    update_query_with_predicate(subp, schema, objectSchema, query);
                }
                query.end_group();
                break;
                
            case NSNotPredicateType:
                // Add the negated subpredicate
                query.Not();
                update_query_with_predicate(comp.subpredicates.firstObject, schema, objectSchema, query);
                break;
                
            default:
                @throw RLMPredicateException(@"Invalid compound predicate type",
                                             @"Only support AND, OR and NOT predicate types");
        }
    }
    else if ([predicate isMemberOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *compp = (NSComparisonPredicate *)predicate;
        
        // validate expressions
        NSExpressionType exp1Type = validated_expression_type(compp.leftExpression);
        NSExpressionType exp2Type = validated_expression_type(compp.rightExpression);

        // check modifier
        if (compp.predicateOperatorType == NSInPredicateOperatorType) {
            @throw RLMPredicateException(@"Invalid operator type", @"Unsupported predicate operator 'IN'");
        }
        else if (compp.comparisonPredicateModifier == NSAllPredicateModifier) {
            // no support for ALL queries
            @throw RLMPredicateException(@"Invalid predicate",
                                         @"ALL modifier not supported");
        }
        else if (compp.comparisonPredicateModifier == NSAnyPredicateModifier) {
            // for ANY queries
            if (exp1Type != NSKeyPathExpressionType || exp2Type != NSConstantValueExpressionType) {
                @throw RLMPredicateException(@"Invalid predicate",
                                             @"Predicate with ANY modifier must compare a KeyPath with RLMArray with a value");
            }

            // split keypath
            NSArray *paths = [compp.leftExpression.keyPath componentsSeparatedByString:@"."];

            // first component of keypath must be RLMArray
            RLMProperty *arrayProp = objectSchema[paths[0]];
            if (arrayProp.type != RLMPropertyTypeArray) {
                @throw RLMPredicateException(@"Invalid predicate",
                                             @"Predicate with ANY modifier must compare a KeyPath with RLMArray with a value");
            }

            if (paths.count == 1) {
                // querying on object identity
                NSUInteger idx = RLMValidatedColumnIndex(objectSchema, arrayProp.name);
                add_link_constraint_to_query(query, compp.predicateOperatorType, idx, compp.rightExpression.constantValue);
            }
            else if (paths.count > 1) {
                // querying on object properties
                update_link_query_with_value_expression(schema, objectSchema, query, paths, compp.rightExpression.constantValue, compp);
            }
            return;
        }
        else if (exp1Type == NSKeyPathExpressionType && exp2Type == NSKeyPathExpressionType) {
            // both expression are KeyPaths
            update_query_with_column_expression(objectSchema, query, compp.leftExpression.keyPath, compp.rightExpression.keyPath,
                                                compp.predicateOperatorType);
        }
        else if (exp1Type == NSKeyPathExpressionType && exp2Type == NSConstantValueExpressionType) {
            // comparing keypath to value
            update_query_with_value_expression(schema, objectSchema, query, compp.leftExpression.keyPath,
                                               compp.rightExpression.constantValue, compp);
        }
        else if (exp1Type == NSConstantValueExpressionType && exp2Type == NSKeyPathExpressionType) {
            // comparing value to keypath
            update_query_with_value_expression(schema, objectSchema, query, compp.rightExpression.keyPath,
                                               compp.leftExpression.constantValue, compp);
        }
        else {
            @throw RLMPredicateException(@"Invalid predicate expressions",
                                         @"Tring to compare two constant values");
        }
    }
    else {
        // invalid predicate type
        @throw RLMPredicateException(@"Invalid predicate",
                                     @"Only support compound and comparison predicates");
    }
}

} // namespace

void RLMUpdateQueryWithPredicate(tightdb::Query *query, id predicate, RLMSchema *schema,
                                 RLMObjectSchema *objectSchema)
{
    // parse and apply predicate tree
    if (predicate) {
        if ([predicate isKindOfClass:[NSString class]]) {
            update_query_with_predicate([NSPredicate predicateWithFormat:predicate],
                                        schema,
                                        objectSchema,
                                        *query);
        }
        else if ([predicate isKindOfClass:[NSPredicate class]]) {
            update_query_with_predicate(predicate, schema, objectSchema, *query);
        }
        else {
            @throw RLMPredicateException(@"Invalid argument",
                                         @"Condition should be predicate as string or NSPredicate object");
        }
        
        // Test the constructed query in core
        std::string validateMessage = query->validate();
        if (validateMessage != "") {
            @throw RLMPredicateException(@"Invalid query",
                                        [NSString stringWithCString:validateMessage.c_str() encoding:[NSString defaultCStringEncoding]]  );
        }
    }
}

void RLMUpdateViewWithOrder(tightdb::TableView &view, RLMObjectSchema *schema, NSString *property, BOOL ascending)
{
    if (!property || property.length == 0) {
        return;
    }
    
    // validate
    RLMProperty *prop = schema[property];
    if (!prop) {
        @throw RLMPredicateException(@"Invalid sort column",
                                     [NSString stringWithFormat:@"Column named '%@' not found.", property]);
    }
    
    switch (prop.type) {
        case RLMPropertyTypeBool:
        case RLMPropertyTypeDate:
        case RLMPropertyTypeDouble:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeInt:
        case RLMPropertyTypeString:
            view.sort(prop.column, ascending);
            break;
            
        default:
            @throw RLMPredicateException(@"Invalid sort column type",
                                         @"Sorting is only supported on Bool, Date, Double, Float, Integer and String columns.");
    }
}
