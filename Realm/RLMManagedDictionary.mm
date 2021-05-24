////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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

#import "RLMDictionary_Private.hpp"

#import "RLMAccessor.hpp"
#import "RLMCollection_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMRealmConfiguration_Private.hpp"
#import "RLMSchema.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

//#import <realm/object-store/dictionary.hpp>
#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table_view.hpp>

@interface RLMManagedDictionaryHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation RLMManagedDictionaryHandoverMetadata
@end

@interface RLMManagedDictionary () <RLMThreadConfined_Private>
@end

@implementation RLMManagedDictionary {
@public
    realm::object_store::Dictionary _backingCollection;
    RLMRealm *_realm;
    RLMClassInfo *_objectInfo;
    RLMClassInfo *_ownerInfo;
    std::unique_ptr<RLMObservationInfo> _observationInfo;
}

- (RLMManagedDictionary *)initWithBackingCollection:(realm::object_store::Dictionary)dictionary
                                         parentInfo:(RLMClassInfo *)parentInfo
                                           property:(__unsafe_unretained RLMProperty *const)property {
    if (property.type == RLMPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName];
    else
        self = [self initWithObjectType:property.type optional:property.optional];
    if (self) {
        _realm = parentInfo->realm;
        REALM_ASSERT(dictionary.get_realm() == _realm->_realm);
        _backingCollection = std::move(dictionary);
        _ownerInfo = parentInfo;
        if (property.type == RLMPropertyTypeObject)
            _objectInfo = &parentInfo->linkTargetType(property.index);
        else
            _objectInfo = _ownerInfo;
        _key = property.name;
    }
    return self;
}

- (RLMManagedDictionary *)initWithParent:(__unsafe_unretained RLMObjectBase *const)parentObject
                                property:(__unsafe_unretained RLMProperty *const)property {
    __unsafe_unretained RLMRealm *const realm = parentObject->_realm;
    auto col = parentObject->_info->tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Dictionary(realm->_realm, parentObject->_row, col)
                                parentInfo:parentObject->_info
                                  property:property];
}

template<typename ObjcCollection>
void RLMCollectionValidateObservationKey(__unsafe_unretained NSString *const keyPath,
                                         __unsafe_unretained ObjcCollection *const collection) {
    if (![keyPath isEqualToString:RLMInvalidatedKey]) {
        @throw RLMException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [collection class], collection, keyPath);
    }
}

template<typename ObjcCollection, typename ManagedObjcCollection>
void RLMEnsureCollectionObservationInfo(std::unique_ptr<RLMObservationInfo>& info,
                                        __unsafe_unretained NSString *const keyPath,
                                        __unsafe_unretained ObjcCollection *const collection,
                                        __unsafe_unretained id const observed) {
    RLMCollectionValidateObservationKey<ObjcCollection>(keyPath, collection);
    if (!info && collection.class == [ManagedObjcCollection class]) {
        auto lv = static_cast<ManagedObjcCollection *>(collection);
        info = std::make_unique<RLMObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingCollection.get_parent_object_key(),
                                                    observed);
    }
}

template<typename ObjcCollection>
void RLMCollectionValidateMatchingObjectType(__unsafe_unretained ObjcCollection *const collection,
                                        __unsafe_unretained id const value) {
    if (!value && !collection->_optional) {
        @throw RLMException(@"Invalid nil value for collection of '%@'.",
                            collection->_objectClassName ?: RLMTypeToString(collection->_type));
    }
    if (collection->_type != RLMPropertyTypeObject) {
        if (!RLMValidateValue(value, collection->_type, collection->_optional, false, nil)) {
            @throw RLMException(@"Invalid value '%@' of type '%@' for expected type '%@%s'.",
                                value, [value class], RLMTypeToString(collection->_type),
                                collection->_optional ? "?" : "");
        }
        return;
    }

    auto object = RLMDynamicCast<RLMObjectBase>(value);
    if (!object) {
        return;
    }
    if (!object->_objectSchema) {
        // TODO: Make exception generic
        @throw RLMException(@"Object cannot be inserted unless the schema is initialized. "
                            "This can happen if you try to insert objects into a RLMArray / List from a default value or from an overriden unmanaged initializer (`init()`).");
    }
    if (![collection->_objectClassName isEqualToString:object->_objectSchema.className]) {
        @throw RLMException(@"Object of type '%@' does not match RLMArray type '%@'.",
                            object->_objectSchema.className, collection->_objectClassName);
    }
}

//
// validation helpers
//
template<typename ObjcCollection>
[[gnu::noinline]]
[[noreturn]]
static void throwError(__unsafe_unretained ObjcCollection *const col, NSString *aggregateMethod) {
    try {
        throw;
    }
    // TODO: Fix up these exceptions
    catch (realm::InvalidTransactionException const&) {
        @throw RLMException(@"Cannot modify managed RLMArray outside of a write transaction.");
    }
    catch (realm::IncorrectThreadException const&) {
        @throw RLMException(@"Realm accessed from incorrect thread.");
    }
    catch (realm::List::InvalidatedException const&) {
        @throw RLMException(@"RLMArray has been invalidated or the containing object has been deleted.");
    }
    catch (realm::List::OutOfBoundsIndexException const& e) {
        @throw RLMException(@"Index %zu is out of bounds (must be less than %zu).",
                            e.requested, e.valid_count);
    }
    catch (realm::Results::UnsupportedColumnTypeException const& e) {
        if (col->_backingCollection.get_type() == realm::PropertyType::Object) {
            @throw RLMException(@"%@: is not supported for %s%s property '%s'.",
                                aggregateMethod,
                                string_for_property_type(e.property_type),
                                is_nullable(e.property_type) ? "?" : "",
                                e.column_name.data());
        }
        @throw RLMException(@"%@: is not supported for %s%s array '%@.%@'.",
                            aggregateMethod,
                            string_for_property_type(e.property_type),
                            is_nullable(e.property_type) ? "?" : "",
                            col->_ownerInfo->rlmObjectSchema.className, col->_key);
    }
    catch (std::logic_error const& e) {
        @throw RLMException(e);
    }
}

template<typename ObjcCollection, typename Function>
static auto translateErrors(__unsafe_unretained ObjcCollection *const collection,
                            Function&& f, NSString *aggregateMethod=nil) {
    try {
        return f();
    }
    catch (...) {
        throwError<ObjcCollection>(collection, aggregateMethod);
    }
}

template<typename ObjcCollection, typename Function>
static auto translateErrors(Function&& f) {
    try {
        return f();
    }
    catch (...) {
        throwError<ObjcCollection>(nil, nil);
    }
}

static void changeDictionary(__unsafe_unretained RLMManagedDictionary *const dict,
                             dispatch_block_t f) {
    translateErrors<RLMManagedDictionary>([&] { dict->_backingCollection.verify_in_transaction(); });

    RLMObservationTracker tracker(dict->_realm);
    tracker.trackDeletions();
    auto obsInfo = RLMGetObservationInfo(dict->_observationInfo.get(),
                                         dict->_backingCollection.get_parent_object_key(),
                                         *dict->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, dict->_key);
    }

    translateErrors<RLMManagedDictionary>(f);
}

//
// public method implementations
//
- (RLMRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateErrors<RLMManagedDictionary>([&] { return _backingCollection.size(); });
}

- (BOOL)isInvalidated {
    return translateErrors<RLMManagedDictionary>([&] { return !_backingCollection.is_valid(); });
}

- (RLMClassInfo *)objectInfo {
    return _objectInfo;
}

- (bool)isBackedByDictionary:(realm::object_store::Dictionary const&)dictionary {
    return _backingCollection == dictionary;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedByDictionary:)] && [object isBackedByDictionary:_backingCollection];
}

- (NSUInteger)hash {
    // TODO: implement hash
    //return std::hash<realm::object_store::Dictionary>()(_backingCollection);
    return 0;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return RLMFastEnumerate(state, len, self);
}

#pragma mark - KVC


- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to RLMResults
        return translateErrors<RLMManagedDictionary>([&] {
            auto results = [RLMResults resultsWithObjectInfo:*_objectInfo
                                                     results:_backingCollection.as_results()];
            return [results valueForKeyPath:keyPath];
        });
    }
    return [super valueForKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    // Ideally we'd use "@invalidated" for this so that "invalidated" would use
    // normal array KVC semantics, but observing @things works very oddly (when
    // it's part of a key path, it's triggered automatically when array index
    // changes occur, and can't be sent explicitly, but works normally when it's
    // the entire key path), and an RLMManagedArray *can't* have objects where
    // invalidated is true, so we're not losing much.
    return translateErrors<RLMManagedDictionary>([&]() -> id {
        if ([key isEqualToString:RLMInvalidatedKey]) {
            return @(!_backingCollection.is_valid());
        }

        _backingCollection.verify_attached();
        auto results = _backingCollection.as_results();
        return RLMCollectionValueForKey(results, key, *_objectInfo);
    });
    return nil;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        RLMAccessorContext context(*_objectInfo);
        translateErrors<RLMManagedDictionary>([&] {
            _backingCollection.remove_all();
            _backingCollection.insert(context, key.UTF8String, value);
        });
        return;
    }
    else if (_type == RLMPropertyTypeObject) {
        RLMCollectionValidateMatchingObjectType<RLMDictionary>(self, value);
        translateErrors<RLMManagedDictionary>([&] { _backingCollection.verify_in_transaction(); });
        RLMCollectionSetValueForKey(self, key, value);
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

// TODO: this can be a common func
- (realm::ColKey)columnForProperty:(NSString *)propertyName {
    if (_backingCollection.get_type() == realm::PropertyType::Object) {
        return _objectInfo->tableColumn(propertyName);
    }
    if (![propertyName isEqualToString:@"self"]) {
        @throw RLMException(@"Arrays of '%@' can only be aggregated on \"self\"", RLMTypeToString(_type));
    }
    return {};
}

- (id)minOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors<RLMManagedDictionary>(self, [&] {
        return _backingCollection.as_results().min(column);
    }, @"minOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors<RLMManagedDictionary>(self, [&] {
        return _backingCollection.as_results().max(column);
    }, @"maxOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors<RLMManagedDictionary>(self, [&] {
        return _backingCollection.as_results().sum(column);
    }, @"sumOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)averageOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors<RLMManagedDictionary>(self, [&] {
        return _backingCollection.as_results().average(column);
    }, @"averageOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Cannot delete objects from RLMArray<%@>: only RLMObjects can be deleted.", RLMTypeToString(_type));
    }
    // delete all target rows from the realm
    RLMObservationTracker tracker(_realm, true);
    translateErrors<RLMManagedDictionary>([&] { _backingCollection.remove_all(); });
}

- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    return translateErrors<RLMManagedDictionary>([&] {
        return [RLMResults resultsWithObjectInfo:*_objectInfo
                                         results:_backingCollection.as_results().sort(RLMSortDescriptorsToKeypathArray(properties))];
    });
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors<RLMManagedDictionary>([&] {
        auto results = [RLMResults resultsWithObjectInfo:*_objectInfo results:_backingCollection.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Querying is currently only implemented for dictionaries of Realm Objects");
    }
    auto query = RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors<RLMManagedDictionary>([&] {
        return _backingCollection.as_results().filter(std::move(query));
    });
    return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    RLMEnsureCollectionObservationInfo<RLMDictionary, RLMManagedDictionary>(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (realm::TableView)tableView {
//    return translateErrors<RLMManagedDictionary>([&] { return _backingCollection.get_query(); }).find_all();
    return {};
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateErrors<RLMManagedDictionary>([&] {
        return [[RLMFastEnumerator alloc] initWithBackingCollection:_backingCollection
                                                         collection:self
                                                          classInfo:*_objectInfo];
    });
}

realm::object_store::Dictionary& RLMGetBackingCollection(RLMManagedDictionary *self) {
    return self->_backingCollection;
}


- (BOOL)isFrozen {
    return _realm.isFrozen;
}

- (instancetype)freeze {
    if (self.frozen) {
        return self;
    }

    RLMRealm *frozenRealm = [_realm freeze];
    auto& parentInfo = _ownerInfo->resolve(frozenRealm);
    return translateRLMResultsErrors([&] {
        return [[self.class alloc] initWithBackingCollection:_backingCollection.freeze(frozenRealm->_realm)
                                                  parentInfo:&parentInfo
                                                    property:parentInfo.rlmObjectSchema[_key]];
    });
}

- (instancetype)thaw {
    if (!self.frozen) {
        return self;
    }

    RLMRealm *liveRealm = [_realm thaw];
    auto& parentInfo = _ownerInfo->resolve(liveRealm);
    return translateRLMResultsErrors([&] {
        return [[self.class alloc] initWithBackingCollection:_backingCollection.freeze(liveRealm->_realm)
                                                  parentInfo:&parentInfo
                                                    property:parentInfo.rlmObjectSchema[_key]];
    });
}

@end
