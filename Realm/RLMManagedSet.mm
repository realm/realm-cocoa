////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

#import "RLMSet_Private.hpp"

#import "RLMAccessor.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMSchema.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

#import <realm/collection.hpp>
#import <realm/object-store/set.hpp>
#import <realm/set.hpp>

#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>

@interface RLMManagedSetHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation RLMManagedSetHandoverMetadata
@end

@interface RLMManagedSet () <RLMThreadConfined_Private>
@end

//
// RLMSet implementation
//
@implementation RLMManagedSet {
@public
    realm::object_store::Set _backingSet;
    RLMRealm *_realm;
    RLMClassInfo *_objectInfo;
    RLMClassInfo *_ownerInfo;
    std::unique_ptr<RLMObservationInfo> _observationInfo;
}

- (RLMManagedSet *)initWithBackingCollection:(realm::object_store::Set)set
                                  parentInfo:(RLMClassInfo *)parentInfo
                                    property:(__unsafe_unretained RLMProperty *const)property {
    if (property.type == RLMPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName];
    else
        self = [self initWithObjectType:property.type
                               optional:property.optional];
    if (self) {
        _realm = parentInfo->realm;
        REALM_ASSERT(set.get_realm() == _realm->_realm);
        _backingSet = std::move(set);
        _ownerInfo = parentInfo;
        if (property.type == RLMPropertyTypeObject)
            _objectInfo = &parentInfo->linkTargetType(property.index);
        else
            _objectInfo = _ownerInfo;
        _key = property.name;
    }
    return self;
}

- (RLMManagedSet *)initWithParent:(__unsafe_unretained RLMObjectBase *const)parentObject
                         property:(__unsafe_unretained RLMProperty *const)property {
    __unsafe_unretained RLMRealm *const realm = parentObject->_realm;
    auto col = parentObject->_info->tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Set(realm->_realm, parentObject->_row, col)
                                parentInfo:parentObject->_info
                                  property:property];
}

- (RLMManagedSet *)initWithParent:(realm::Obj)parent
                         property:(__unsafe_unretained RLMProperty *const)property
                       parentInfo:(RLMClassInfo&)info {
    auto col = info.tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Set(info.realm->_realm, parent, col)
                                parentInfo:&info
                                  property:property];
}

void RLMValidateSetObservationKey(__unsafe_unretained NSString *const keyPath,
                                  __unsafe_unretained RLMSet *const set) {
    if (![keyPath isEqualToString:RLMInvalidatedKey]) {
        @throw RLMException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [set class], set, keyPath);
    }
}

void RLMEnsureSetObservationInfo(std::unique_ptr<RLMObservationInfo>& info,
                                   __unsafe_unretained NSString *const keyPath,
                                   __unsafe_unretained RLMSet *const set,
                                   __unsafe_unretained id const observed) {
    RLMValidateSetObservationKey(keyPath, set);
    if (!info && set.class == [RLMManagedSet class]) {
        auto lv = static_cast<RLMManagedSet *>(set);
        info = std::make_unique<RLMObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingSet.get_parent_object_key(),
                                                    observed);
    }
}

//
// validation helpers
//
[[gnu::noinline]]
[[noreturn]]
static void throwError(__unsafe_unretained RLMManagedSet *const ar, NSString *aggregateMethod) {
    try {
        throw;
    }
    catch (realm::InvalidTransactionException const&) {
        @throw RLMException(@"Cannot modify managed RLMSet outside of a write transaction.");
    }
    catch (realm::IncorrectThreadException const&) {
        @throw RLMException(@"Realm accessed from incorrect thread.");
    }
    catch (realm::object_store::Set::InvalidatedException const&) {
        @throw RLMException(@"RLMSet has been invalidated or the containing object has been deleted.");
    }
    catch (realm::object_store::Set::InvalidEmbeddedOperationException const&) {
        @throw RLMException(@"Cannot add an embedded object to an RLMSet.");
    }
    catch (realm::Results::UnsupportedColumnTypeException const& e) {
        if (ar->_backingSet.get_type() == realm::PropertyType::Object) {
            @throw RLMException(@"%@: is not supported for %s%s property '%s'.",
                                aggregateMethod,
                                string_for_property_type(e.property_type),
                                is_nullable(e.property_type) ? "?" : "",
                                e.column_name.data());
        }
        @throw RLMException(@"%@: is not supported for %s%s set '%@.%@'.",
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
static auto translateErrors(__unsafe_unretained RLMManagedSet *const set,
                            Function&& f, NSString *aggregateMethod=nil) {
    try {
        return f();
    }
    catch (...) {
        throwError(set, aggregateMethod);
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

static void changeSet(__unsafe_unretained RLMManagedSet *const set,
                      dispatch_block_t f) {
    translateErrors([&] { set->_backingSet.verify_in_transaction(); });

    RLMObservationTracker tracker(set->_realm, false);
    tracker.trackDeletions();
    auto obsInfo = RLMGetObservationInfo(set->_observationInfo.get(),
                                         set->_backingSet.get_parent_object_key(),
                                         *set->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, set->_key);
    }

    translateErrors(f);
}

//
// public method implementations
//
- (RLMRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateErrors([&] { return _backingSet.size(); });
}

- (NSArray<id> *)allObjects {
    NSMutableArray *arr = [NSMutableArray new];
    for (id prop : self) {
        [arr addObject:prop];
    }
    return arr;
}

- (BOOL)isInvalidated {
    return translateErrors([&] { return !_backingSet.is_valid(); });
}

- (RLMClassInfo *)objectInfo {
    return _objectInfo;
}


- (bool)isBackedBySet:(realm::object_store::Set const&)set {
    return _backingSet == set;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedBySet:)] && [object isBackedBySet:_backingSet];
}

- (NSUInteger)hash {
    return std::hash<realm::object_store::Set>()(_backingSet);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return RLMFastEnumerate(state, len, self);
}

static void RLMInsertObject(RLMManagedSet *set, id object) {
    RLMSetValidateMatchingObjectType(set, object);
    changeSet(set, ^{
        RLMAccessorContext context(*set->_objectInfo);
        set->_backingSet.insert(context, object);
    });
}

static void RLMRemoveObject(RLMManagedSet *set, id object) {
    RLMSetValidateMatchingObjectType(set, object);
    changeSet(set, ^{
        RLMAccessorContext context(*set->_objectInfo);
        set->_backingSet.remove(context, object);
    });
}

static void ensureInWriteTransaction(NSString *message, RLMManagedSet *set, RLMManagedSet *otherSet) {
    if (!set.realm.inWriteTransaction && !otherSet.realm.inWriteTransaction) {
        @throw RLMException(@"Can only perform %@ in a Realm in a write transaction - call beginWriteTransaction on an RLMRealm instance first.", message);
    }
}

- (void)addObject:(id)object {
    RLMInsertObject(self, object);
}

- (void)addObjects:(id<NSFastEnumeration>)objects {
    changeSet(self, ^{
        RLMAccessorContext context(*_objectInfo);
        for (id obj in objects) {
            RLMSetValidateMatchingObjectType(self, obj);
            _backingSet.insert(context, obj);
        }
    });
}

- (void)removeObject:(id)object {
    RLMRemoveObject(self, object);
}

- (void)removeAllObjects {
    changeSet(self, ^{
        _backingSet.remove_all();
    });
}

- (void)replaceAllObjectsWithObjects:(NSArray *)objects {
    changeSet(self, ^{
        RLMAccessorContext context(*_objectInfo);
        _backingSet.assign(context, objects);
    });
}

- (RLMManagedSet *)managedObjectFrom:(RLMSet *)set {
    auto managedSet = RLMDynamicCast<RLMManagedSet>(set);
    if (!managedSet) {
        @throw RLMException(@"Right hand side value must be a managed Set.");
    }
    if (_type != managedSet->_type || _objectInfo != managedSet->_objectInfo) {
        @throw RLMException(@"Set must match type of \"self\" '%@'", RLMTypeToString(_type));
    }
    return managedSet;
}

- (BOOL)isSubsetOfSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    return _backingSet.is_subset_of(rhs->_backingSet);
}

- (BOOL)intersectsSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    return _backingSet.intersects(rhs->_backingSet);
}

- (BOOL)containsObject:(id)obj {
    RLMSetValidateMatchingObjectType(self, obj);
    RLMAccessorContext context(*_objectInfo);
    auto r = _backingSet.find(context, obj);
    return r != realm::npos;
}

- (BOOL)isEqualToSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    return [self isEqual:rhs];
}

- (void)setSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[RLMSet setSet:]", self, rhs);
    changeSet(self, ^{
        RLMAccessorContext context(*_objectInfo);
        _backingSet.assign(context, rhs);
    });
}

- (void)intersectSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[RLMSet intersectSet:]", self, rhs);
    changeSet(self, ^{
        _backingSet.assign_intersection(rhs->_backingSet);
    });
}

- (void)unionSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[RLMSet unionSet:]", self, rhs);
    changeSet(self, ^{
        _backingSet.assign_union(rhs->_backingSet);
    });
}

- (void)minusSet:(RLMSet<id> *)set {
    RLMManagedSet *rhs = [self managedObjectFrom:set];
    ensureInWriteTransaction(@"[RLMSet minusSet:]", self, rhs);
    changeSet(self, ^{
        _backingSet.assign_difference(rhs->_backingSet);
    });
}

- (id)objectAtIndex:(NSUInteger)index {
    return translateErrors([&] {
        RLMAccessorContext context(*_objectInfo);
        return _backingSet.get(context, index);
    });
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to RLMResults
        return translateErrors([&] {
            auto results = [RLMResults resultsWithObjectInfo:*_objectInfo results:_backingSet.as_results()];
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
    // the entire key path), and an RLMManagedSet *can't* have objects where
    // invalidated is true, so we're not losing much.
    return translateErrors([&]() -> id {
        if ([key isEqualToString:RLMInvalidatedKey]) {
            return @(!_backingSet.is_valid());
        }

        _backingSet.verify_attached();
        return  [NSSet setWithArray:RLMCollectionValueForKey(_backingSet, key, *_objectInfo)];
    });
    return nil;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        RLMSetValidateMatchingObjectType(self, value);
        RLMAccessorContext context(*_objectInfo);
        translateErrors([&] {
            _backingSet.remove_all();
            _backingSet.insert(context, value);
            return;
        });
    } else if (_type == RLMPropertyTypeObject) {
        RLMSetValidateMatchingObjectType(self, value);
        translateErrors([&] { _backingSet.verify_in_transaction(); });
        RLMCollectionSetValueForKey(self, key, value);
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

- (id)minOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, RLMCollectionTypeSet);
    auto value = translateErrors(self, [&] { return _backingSet.min(column); }, @"minOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, RLMCollectionTypeSet);
    auto value = translateErrors(self, [&] { return _backingSet.max(column); }, @"maxOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, RLMCollectionTypeSet);
    return RLMMixedToObjc(translateErrors(self, [&] { return _backingSet.sum(column); }, @"sumOfProperty"));
}

- (id)averageOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingSet, _objectInfo, _type, RLMCollectionTypeSet);
    auto value = translateErrors(self, [&] { return _backingSet.average(column); }, @"averageOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Cannot delete objects from RLMSet<%@>: only RLMObjects can be deleted.", RLMTypeToString(_type));
    }
    // delete all target rows from the realm
    RLMObservationTracker tracker(_realm, true);
    translateErrors([&] { _backingSet.delete_all(); });
}

- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    return translateErrors([&] {
        return [RLMResults  resultsWithObjectInfo:*_objectInfo
                                          results:_backingSet.sort(RLMSortDescriptorsToKeypathArray(properties))];
    });
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors([&] {
        auto results = [RLMResults resultsWithObjectInfo:*_objectInfo results:_backingSet.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Querying is currently only implemented for sets of Realm Objects");
    }
    auto query = RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] { return _backingSet.filter(std::move(query)); });
    return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    RLMEnsureSetObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateErrors([&] {
        return [[RLMFastEnumerator alloc] initWithBackingCollection:_backingSet
                                                         collection:self
                                                          classInfo:*_objectInfo];
    });
}

- (realm::TableView)tableView {
    return translateErrors([&] { return _backingSet.get_query(); }).find_all();
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
        return [[self.class alloc] initWithBackingCollection:_backingSet.freeze(frozenRealm->_realm)
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
        return [[self.class alloc] initWithBackingCollection:_backingSet.freeze(liveRealm->_realm)
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
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block {
    return RLMAddNotificationBlock(self, nil, block, nil);
}
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, nil, block, queue);
}
// TODO: need keypaths version
// TODO: ManagedSet addNotificationBlock and RLMAddNotificationBlock should have similar parameter ordering.
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(nullable dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, keyPaths, block, queue);
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths {
    return RLMAddNotificationBlock(self, keyPaths, block, nil);
}
#pragma clang diagnostic pop

realm::object_store::Set& RLMGetBackingCollection(RLMManagedSet *self) {
    return self->_backingSet;
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _backingSet;
}

- (RLMManagedSetHandoverMetadata *)objectiveCMetadata {
    RLMManagedSetHandoverMetadata *metadata = [[RLMManagedSetHandoverMetadata alloc] init];
    metadata.parentClassName = _ownerInfo->rlmObjectSchema.className;
    metadata.key = _key;
    return metadata;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(RLMManagedSetHandoverMetadata *)metadata
                                        realm:(RLMRealm *)realm {
    auto set = reference.resolve<realm::object_store::Set>(realm->_realm);
    if (!set.is_valid()) {
        return nil;
    }
    RLMClassInfo *parentInfo = &realm->_info[metadata.parentClassName];
    return [[RLMManagedSet alloc] initWithBackingCollection:std::move(set)
                                                 parentInfo:parentInfo
                                                   property:parentInfo->rlmObjectSchema[metadata.key]];
}

@end

