////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import <Foundation/Foundation.h>

#import <realm/table_ref.hpp>
#import <realm/util/optional.hpp>

#import <unordered_map>
#import <vector>

namespace realm {
    class ObjectSchema;
    class Schema;
    struct Property;
    struct ColKey;
    struct TableKey;
}

class RLMObservationInfo;
@class RLMRealm, RLMSchema, RLMObjectSchema, RLMProperty;

NS_ASSUME_NONNULL_BEGIN

namespace std {
// Add specializations so that NSString can be used as the key for hash containers
template<> struct hash<NSString *> {
    size_t operator()(__unsafe_unretained NSString *const str) const {
        return [str hash];
    }
};
template<> struct equal_to<NSString *> {
    bool operator()(__unsafe_unretained NSString * lhs, __unsafe_unretained NSString *rhs) const {
        return [lhs isEqualToString:rhs];
    }
};
}

// The per-RLMRealm object schema information which stores the cached table
// reference, handles table column lookups, and tracks observed objects
class RLMClassInfo {
public:
    RLMClassInfo(RLMRealm *, RLMObjectSchema *, const realm::ObjectSchema *);

    RLMClassInfo(RLMRealm *realm, RLMObjectSchema *rlmObjectSchema,
                 std::unique_ptr<realm::ObjectSchema> objectSchema);

    __unsafe_unretained RLMRealm *const realm;
    __unsafe_unretained RLMObjectSchema *const rlmObjectSchema;
    const realm::ObjectSchema *const objectSchema;

    // Storage for the functionality in RLMObservation for handling indirect
    // changes to KVO-observed things
    std::vector<RLMObservationInfo *> observedObjects;

    // Get the table for this object type. Will return nullptr only if it's a
    // read-only Realm that is missing the table entirely.
    realm::TableRef table() const;

    // Get the RLMProperty for a given table column, or `nil` if it is a column
    // not used by the current schema
    RLMProperty *_Nullable propertyForTableColumn(realm::ColKey) const noexcept;

    // Get the RLMProperty that's used as the primary key, or `nil` if there is
    // no primary key for the current schema
    RLMProperty *_Nullable propertyForPrimaryKey() const noexcept;

    // Get the table column for the given property. The property must be a valid
    // persisted property.
    realm::ColKey tableColumn(NSString *propertyName) const;
    realm::ColKey tableColumn(RLMProperty *property) const;
    // Get the table column key for the given computed property. The property must be a valid
    // computed property.
    // Subscripting a `realm::ObjectSchema->computed_properties[property.index]`
    // does not return a valid colKey, unlike subscripting persisted_properties.
    // This method retrieves a valid column key for computed properties by
    // getting the opposite table column of the origin's forward link.
    realm::ColKey computedTableColumn(RLMProperty *property) const;

    // Get the info for the target of the link at the given property index.
    RLMClassInfo &linkTargetType(size_t propertyIndex);

    // Get the info for the target of the given property
    RLMClassInfo &linkTargetType(realm::Property const& property);

    // Get the corresponding ClassInfo for the given Realm
    RLMClassInfo &resolve(RLMRealm *);

    // Return true if the RLMObjectSchema is for a Swift class
    bool isSwiftClass() const noexcept;

    // Returns true if this was a dynamically added type
    bool isDynamic() const noexcept;

private:
    // If the ObjectSchema is not owned by the realm instance
    // we need to manually manage the ownership of the object.
    std::unique_ptr<realm::ObjectSchema> dynamicObjectSchema;
    [[maybe_unused]] RLMObjectSchema *_Nullable dynamicRLMObjectSchema;
};

// A per-RLMRealm object schema map which stores RLMClassInfo keyed on the name
class RLMSchemaInfo {
    using impl = std::unordered_map<NSString *, RLMClassInfo>;
public:
    RLMSchemaInfo() = default;
    RLMSchemaInfo(RLMRealm *realm);

    RLMSchemaInfo clone(realm::Schema const& source_schema, RLMRealm *target_realm);

    // Look up by name, throwing if it's not present
    RLMClassInfo& operator[](NSString *name);
    // Look up by table key, return none if its not present.
    RLMClassInfo* operator[](realm::TableKey const& tableKey);

    // Emplaces a locally derived object schema into RLMSchemaInfo. This is used
    // when creating objects dynamically that are not registered in the Cocoa schema.
    // Note: `RLMClassInfo` assumes ownership of `schema`.
    void appendDynamicObjectSchema(std::unique_ptr<realm::ObjectSchema> schema,
                                   RLMObjectSchema *objectSchema,
                                   RLMRealm *const target_realm);

    impl::iterator begin() noexcept;
    impl::iterator end() noexcept;
    impl::const_iterator begin() const noexcept;
    impl::const_iterator end() const noexcept;
private:
    std::unordered_map<NSString *, RLMClassInfo> m_objects;
};

NS_ASSUME_NONNULL_END
