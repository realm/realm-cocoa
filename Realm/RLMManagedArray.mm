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

#import "RLMArray_Private.hpp"

#import "RLMAccessor.hpp"
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

#import <realm/object-store/list.hpp>
#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table_view.hpp>

#import <objc/runtime.h>

@interface RLMManagedArrayHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation RLMManagedArrayHandoverMetadata
@end

@interface RLMManagedArray () <RLMThreadConfined_Private>
@end

//
// RLMArray implementation
//
@implementation RLMManagedArray {
@public
    realm::List _backingList;
    RLMRealm *_realm;
    RLMClassInfo *_objectInfo;
    RLMClassInfo *_ownerInfo;
    std::unique_ptr<RLMObservationInfo> _observationInfo;
}

- (RLMManagedArray *)initWithList:(realm::List)list
                       parentInfo:(RLMClassInfo *)parentInfo
                         property:(__unsafe_unretained RLMProperty *const)property {
    if (property.type == RLMPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName];
    else
        self = [self initWithObjectType:property.type optional:property.optional];
    if (self) {
        _realm = parentInfo->realm;
        REALM_ASSERT(list.get_realm() == _realm->_realm);
        _backingList = std::move(list);
        _ownerInfo = parentInfo;
        if (property.type == RLMPropertyTypeObject)
            _objectInfo = &parentInfo->linkTargetType(property.index);
        else
            _objectInfo = _ownerInfo;
        _key = property.name;
    }
    return self;
}

- (RLMManagedArray *)initWithParent:(__unsafe_unretained RLMObjectBase *const)parentObject
                           property:(__unsafe_unretained RLMProperty *const)property {
    __unsafe_unretained RLMRealm *const realm = parentObject->_realm;
    auto col = parentObject->_info->tableColumn(property);
    return [self initWithList:realm::List(realm->_realm, parentObject->_row, col)
                   parentInfo:parentObject->_info
                     property:property];
}

void RLMValidateArrayObservationKey(__unsafe_unretained NSString *const keyPath,
                                    __unsafe_unretained RLMArray *const array) {
    if (![keyPath isEqualToString:RLMInvalidatedKey]) {
        @throw RLMException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [array class], array, keyPath);
    }
}

void RLMEnsureArrayObservationInfo(std::unique_ptr<RLMObservationInfo>& info,
                                   __unsafe_unretained NSString *const keyPath,
                                   __unsafe_unretained RLMArray *const array,
                                   __unsafe_unretained id const observed) {
    RLMValidateArrayObservationKey(keyPath, array);
    if (!info && array.class == [RLMManagedArray class]) {
        auto lv = static_cast<RLMManagedArray *>(array);
        info = std::make_unique<RLMObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingList.get_parent_object_key(),
                                                    observed);
    }
}

//
// validation helpers
//
[[gnu::noinline]]
[[noreturn]]
static void throwError(__unsafe_unretained RLMManagedArray *const ar, NSString *aggregateMethod) {
    try {
        throw;
    }
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
        if (ar->_backingList.get_type() == realm::PropertyType::Object) {
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
                            ar->_ownerInfo->rlmObjectSchema.className, ar->_key);
    }
    catch (std::logic_error const& e) {
        @throw RLMException(e);
    }
}

template<typename Function>
static auto translateErrors(__unsafe_unretained RLMManagedArray *const ar,
                            Function&& f, NSString *aggregateMethod=nil) {
    try {
        return f();
    }
    catch (...) {
        throwError(ar, aggregateMethod);
    }
}

template<typename Function>
static auto translateErrors(Function&& f) {
    try {
        return f();
    }
    catch (...) {
        throwError(nil, nil);
    }
}

template<typename IndexSetFactory>
static void changeArray(__unsafe_unretained RLMManagedArray *const ar,
                        NSKeyValueChange kind, dispatch_block_t f, IndexSetFactory&& is) {
    translateErrors([&] { ar->_backingList.verify_in_transaction(); });

    RLMObservationTracker tracker(ar->_realm);
    tracker.trackDeletions();
    auto obsInfo = RLMGetObservationInfo(ar->_observationInfo.get(),
                                         ar->_backingList.get_parent_object_key(),
                                         *ar->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, ar->_key, kind, is());
    }

    translateErrors(f);
}

static void changeArray(__unsafe_unretained RLMManagedArray *const ar, NSKeyValueChange kind, NSUInteger index, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndex:index]; });
}

static void changeArray(__unsafe_unretained RLMManagedArray *const ar, NSKeyValueChange kind, NSRange range, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return [NSIndexSet indexSetWithIndexesInRange:range]; });
}

static void changeArray(__unsafe_unretained RLMManagedArray *const ar, NSKeyValueChange kind, NSIndexSet *is, dispatch_block_t f) {
    changeArray(ar, kind, f, [=] { return is; });
}

//
// public method implementations
//
- (RLMRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateErrors([&] { return _backingList.size(); });
}

- (BOOL)isInvalidated {
    return translateErrors([&] { return !_backingList.is_valid(); });
}

- (RLMClassInfo *)objectInfo {
    return _objectInfo;
}


- (bool)isBackedByList:(realm::List const&)list {
    return _backingList == list;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedByList:)] && [object isBackedByList:_backingList];
}

- (NSUInteger)hash {
    return std::hash<realm::List>()(_backingList);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return RLMFastEnumerate(state, len, self);
}

- (id)objectAtIndex:(NSUInteger)index {
    return translateErrors([&] {
        RLMAccessorContext context(*_objectInfo);
        return _backingList.get(context, index);
    });
}

static void RLMInsertObject(RLMManagedArray *ar, id object, NSUInteger index) {
    RLMArrayValidateMatchingObjectType(ar, object);
    if (index == NSUIntegerMax) {
        index = translateErrors([&] { return ar->_backingList.size(); });
    }

    changeArray(ar, NSKeyValueChangeInsertion, index, ^{
        RLMAccessorContext context(*ar->_objectInfo);
        ar->_backingList.insert(context, index, object);
    });
}

- (void)addObject:(id)object {
    RLMInsertObject(self, object, NSUIntegerMax);
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
    RLMInsertObject(self, object, index);
}

- (void)insertObjects:(id<NSFastEnumeration>)objects atIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeInsertion, indexes, ^{
        NSUInteger index = [indexes firstIndex];
        RLMAccessorContext context(*_objectInfo);
        for (id obj in objects) {
            RLMArrayValidateMatchingObjectType(self, obj);
            _backingList.insert(context, index, obj);
            index = [indexes indexGreaterThanIndex:index];
        }
    });
}


- (void)removeObjectAtIndex:(NSUInteger)index {
    changeArray(self, NSKeyValueChangeRemoval, index, ^{
        _backingList.remove(index);
    });
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes {
    changeArray(self, NSKeyValueChangeRemoval, indexes, ^{
        [indexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *) {
            _backingList.remove(idx);
        }];
    });
}

- (void)addObjectsFromArray:(NSArray *)array {
    changeArray(self, NSKeyValueChangeInsertion, NSMakeRange(self.count, array.count), ^{
        RLMAccessorContext context(*_objectInfo);
        for (id obj in array) {
            RLMArrayValidateMatchingObjectType(self, obj);
            _backingList.add(context, obj);
        }
    });
}

- (void)removeAllObjects {
    changeArray(self, NSKeyValueChangeRemoval, NSMakeRange(0, self.count), ^{
        _backingList.remove_all();
    });
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)object {
    RLMArrayValidateMatchingObjectType(self, object);
    changeArray(self, NSKeyValueChangeReplacement, index, ^{
        RLMAccessorContext context(*_objectInfo);
        _backingList.set(context, index, object);
    });
}

- (void)moveObjectAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {
    auto start = std::min(sourceIndex, destinationIndex);
    auto len = std::max(sourceIndex, destinationIndex) - start + 1;
    changeArray(self, NSKeyValueChangeReplacement, {start, len}, ^{
        _backingList.move(sourceIndex, destinationIndex);
    });
}

- (void)exchangeObjectAtIndex:(NSUInteger)index1 withObjectAtIndex:(NSUInteger)index2 {
    changeArray(self, NSKeyValueChangeReplacement, ^{
        _backingList.swap(index1, index2);
    }, [=] {
        NSMutableIndexSet *set = [[NSMutableIndexSet alloc] initWithIndex:index1];
        [set addIndex:index2];
        return set;
    });
}

- (NSUInteger)indexOfObject:(id)object {
    RLMArrayValidateMatchingObjectType(self, object);
    return translateErrors([&] {
        RLMAccessorContext context(*_objectInfo);
        return RLMConvertNotFound(_backingList.find(context, object));
    });
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to RLMResults
        return translateErrors([&] {
            auto results = [RLMResults resultsWithObjectInfo:*_objectInfo results:_backingList.as_results()];
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
    return translateErrors([&]() -> id {
        if ([key isEqualToString:RLMInvalidatedKey]) {
            return @(!_backingList.is_valid());
        }

        _backingList.verify_attached();
        return RLMCollectionValueForKey(_backingList, key, *_objectInfo);
    });
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        RLMArrayValidateMatchingObjectType(self, value);
        RLMAccessorContext context(*_objectInfo);
        translateErrors([&] {
            for (size_t i = 0, count = _backingList.size(); i < count; ++i) {
                _backingList.set(context, i, value);
            }
        });
        return;
    }
    else if (_type == RLMPropertyTypeObject) {
        RLMArrayValidateMatchingObjectType(self, value);
        translateErrors([&] { _backingList.verify_in_transaction(); });
        RLMCollectionSetValueForKey(self, key, value);
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

- (realm::ColKey)columnForProperty:(NSString *)propertyName {
    if (_backingList.get_type() == realm::PropertyType::Object) {
        return _objectInfo->tableColumn(propertyName);
    }
    if (![propertyName isEqualToString:@"self"]) {
        @throw RLMException(@"Arrays of '%@' can only be aggregated on \"self\"", RLMTypeToString(_type));
    }
    return {};
}

- (id)minOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors(self, [&] { return _backingList.min(column); }, @"minOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors(self, [&] { return _backingList.max(column); }, @"maxOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    return RLMMixedToObjc(translateErrors(self, [&] { return _backingList.sum(column); }, @"sumOfProperty"));
}

- (id)averageOfProperty:(NSString *)property {
    auto column = [self columnForProperty:property];
    auto value = translateErrors(self, [&] { return _backingList.average(column); }, @"averageOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Cannot delete objects from RLMArray<%@>: only RLMObjects can be deleted.", RLMTypeToString(_type));
    }
    // delete all target rows from the realm
    RLMObservationTracker tracker(_realm, true);
    translateErrors([&] { _backingList.delete_all(); });
}

- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    return translateErrors([&] {
        return [RLMResults resultsWithObjectInfo:*_objectInfo
                                         results:_backingList.sort(RLMSortDescriptorsToKeypathArray(properties))];
    });
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors([&] {
        auto results = [RLMResults resultsWithObjectInfo:*_objectInfo results:_backingList.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Querying is currently only implemented for arrays of Realm Objects");
    }
    auto query = RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] { return _backingList.filter(std::move(query)); });
    return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (NSUInteger)indexOfObjectWithPredicate:(NSPredicate *)predicate {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Querying is currently only implemented for arrays of Realm Objects");
    }
    realm::Query query = RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema,
                                             _realm.schema, _realm.group);

    return translateErrors([&] {
        return RLMConvertNotFound(_backingList.find(std::move(query)));
    });
}

- (NSArray *)objectsAtIndexes:(__unused NSIndexSet *)indexes {
    // FIXME: this is called by KVO when array changes are made. It's not clear
    // why, and returning nil seems to work fine.
    return nil;
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    RLMEnsureArrayObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (realm::TableView)tableView {
    return translateErrors([&] { return _backingList.get_query(); }).find_all();
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateErrors([&] {
        return [[RLMFastEnumerator alloc] initWithList:_backingList collection:self
                                             classInfo:*_objectInfo];
    });
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
        return [[RLMManagedArray alloc] initWithList:_backingList.freeze(frozenRealm->_realm)
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
        return [[RLMManagedArray alloc] initWithList:_backingList.freeze(liveRealm->_realm)
                                          parentInfo:&parentInfo
                                            property:parentInfo.rlmObjectSchema[_key]];
    });
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMArray *, RLMCollectionChange *, NSError *))block {
    return RLMAddNotificationBlock(self, block, nil);
}
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMArray *, RLMCollectionChange *, NSError *))block queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, block, queue);
}
#pragma clang diagnostic pop

realm::List& RLMGetBackingCollection(RLMManagedArray *self) {
    return self->_backingList;
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _backingList;
}

- (RLMManagedArrayHandoverMetadata *)objectiveCMetadata {
    RLMManagedArrayHandoverMetadata *metadata = [[RLMManagedArrayHandoverMetadata alloc] init];
    metadata.parentClassName = _ownerInfo->rlmObjectSchema.className;
    metadata.key = _key;
    return metadata;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(RLMManagedArrayHandoverMetadata *)metadata
                                        realm:(RLMRealm *)realm {
    auto list = reference.resolve<realm::List>(realm->_realm);
    if (!list.is_valid()) {
        return nil;
    }
    RLMClassInfo *parentInfo = &realm->_info[metadata.parentClassName];
    return [[RLMManagedArray alloc] initWithList:std::move(list)
                                       parentInfo:parentInfo
                                         property:parentInfo->rlmObjectSchema[metadata.key]];
}

@end
