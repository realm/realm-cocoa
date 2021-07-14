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

#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table_view.hpp>

@interface RLMManagedDictionary () <RLMThreadConfined_Private> {
    @public
    realm::object_store::Dictionary _backingCollection;
}
@end

@interface RLMDictionaryChange ()
- (instancetype)initWithChanges:(realm::DictionaryChangeSet)changes;
@end

namespace {
struct DictionaryCallbackWrapper {
    void (^block)(id, RLMDictionaryChange *, NSError *);
    RLMManagedDictionary *collection;
    realm::TransactionRef previousTransaction;
    std::shared_ptr<realm::Dictionary> previousDictionary;

    DictionaryCallbackWrapper(void (^block)(id, RLMDictionaryChange *, NSError *), RLMManagedDictionary *dictionary)
    : block(block)
    , collection(dictionary)
    {
        previousTransaction = static_cast<realm::Transaction&>(collection.realm.group).duplicate();
        previousDictionary.reset(static_cast<realm::Dictionary*>(previousTransaction->import_copy_of(collection->_backingCollection.get_impl()).release()));

    }

    void operator()(realm::DictionaryChangeSet const& changes, std::exception_ptr err) {
        if (err) {
            previousTransaction->end_read();
            try {
                rethrow_exception(err);
            }
            catch (...) {
                NSError *error = nil;
                RLMRealmTranslateException(&error);
                block(nil, nil, error);
                return;
            }
        }

        if (changes.deletions.empty() &&
            changes.insertions.empty() &&
            changes.modifications.empty()) {
            block(collection, nil, nil);
        }
        else {
            block(collection, [[RLMDictionaryChange alloc] initWithChanges:changes], nil);
        }
        if (collection.isInvalidated) {
            previousTransaction->end_read();
        }
        else {
            previousTransaction->advance_read(static_cast<realm::Transaction&>(collection.realm.group).get_version_of_current_transaction());
        }
    }
};
} //anonymous namespace

@implementation RLMDictionaryChange {
    realm::DictionaryChangeSet _changes;
}

- (instancetype)initWithChanges:(realm::DictionaryChangeSet)changes {
    self = [super init];
    if (self) {
        _changes = std::move(changes);
    }
    return self;
}

static NSArray *toArray(std::vector<realm::Mixed> const& v) {
    NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:v.size()];
    for (auto& mixed : v) {
        [ret addObject:RLMMixedToObjc(mixed)];
    }
    return ret;
}

- (NSArray *)insertions {
    return toArray(_changes.insertions);
}

- (NSArray *)deletions {
    return toArray(_changes.deletions);
}

- (NSArray *)modifications {
    return toArray(_changes.modifications);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RLMDictionaryChange: %p> insertions: %@, deletions: %@, modifications: %@",
            (__bridge void *)self, self.insertions, self.deletions, self.modifications];
}

@end

@interface RLMManagedCollectionHandoverMetadata : NSObject
@property (nonatomic) NSString *parentClassName;
@property (nonatomic) NSString *key;
@end

@implementation RLMManagedCollectionHandoverMetadata
@end

@implementation RLMManagedDictionary {
@public
    RLMRealm *_realm;
    RLMClassInfo *_objectInfo;
    RLMClassInfo *_ownerInfo;
    std::unique_ptr<RLMObservationInfo> _observationInfo;
}

- (RLMManagedDictionary *)initWithBackingCollection:(realm::object_store::Dictionary)dictionary
                                         parentInfo:(RLMClassInfo *)parentInfo
                                           property:(__unsafe_unretained RLMProperty *const)property {
    if (property.type == RLMPropertyTypeObject)
        self = [self initWithObjectClassName:property.objectClassName keyType:property.dictionaryKeyType];
    else
        self = [self initWithObjectType:property.type optional:property.optional keyType:property.dictionaryKeyType];
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

- (RLMManagedDictionary *)initWithParent:(realm::Obj)parent
                                property:(__unsafe_unretained RLMProperty *const)property
                              parentInfo:(RLMClassInfo&)info {
    auto col = info.tableColumn(property);
    return [self initWithBackingCollection:realm::object_store::Dictionary(info.realm->_realm, parent, col)
                                parentInfo:&info
                                  property:property];
}

void RLMDictionaryValidateObservationKey(__unsafe_unretained NSString *const keyPath,
                                         __unsafe_unretained RLMDictionary *const dictionary) {
    if (![keyPath isEqualToString:RLMInvalidatedKey]) {
        @throw RLMException(@"[<%@ %p> addObserver:forKeyPath:options:context:] is not supported. Key path: %@",
                            [dictionary class], dictionary, keyPath);
    }
}

void RLMEnsureDictionaryObservationInfo(std::unique_ptr<RLMObservationInfo>& info,
                                        __unsafe_unretained NSString *const keyPath,
                                        __unsafe_unretained RLMDictionary *const dictionary,
                                        __unsafe_unretained id const observed) {
    RLMDictionaryValidateObservationKey(keyPath, dictionary);
    if (!info && dictionary.class == [RLMManagedDictionary class]) {
        auto lv = static_cast<RLMManagedDictionary *>(dictionary);
        info = std::make_unique<RLMObservationInfo>(*lv->_ownerInfo,
                                                    lv->_backingCollection.get_parent_object_key(),
                                                    observed);
    }
}

//
// validation helpers
//
[[gnu::noinline]]
[[noreturn]]
static void throwError(__unsafe_unretained RLMManagedDictionary *const dict, NSString *aggregateMethod) {
    try {
        throw;
    }
    catch (realm::InvalidTransactionException const&) {
        @throw RLMException(@"Cannot modify managed RLMDictionary outside of a write transaction.");
    }
    catch (realm::IncorrectThreadException const&) {
        @throw RLMException(@"Realm accessed from incorrect thread.");
    }
    catch (realm::Results::UnsupportedColumnTypeException const& e) {
        if (dict->_backingCollection.get_type() == realm::PropertyType::Object) {
            @throw RLMException(@"%@: is not supported for %s%s property '%s'.",
                                aggregateMethod,
                                string_for_property_type(e.property_type),
                                dict->_optional ? "?" : "",
                                e.column_name.data());
        }
        @throw RLMException(@"%@: is not supported for %s%s dictionary '%@.%@'.",
                            aggregateMethod,
                            string_for_property_type(e.property_type),
                            dict->_optional ? "?" : "",
                            dict->_ownerInfo->rlmObjectSchema.className, dict->_key);
    }
    catch (std::logic_error const& e) {
        @throw RLMException(e);
    }
}

template<typename Function>
static auto translateErrors(__unsafe_unretained RLMManagedDictionary *const dictionary,
                            Function&& f, NSString *aggregateMethod=nil) {
    try {
        return f();
    }
    catch (...) {
        throwError(dictionary, aggregateMethod);
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

static void changeDictionary(__unsafe_unretained RLMManagedDictionary *const dict,
                             dispatch_block_t f) {
    translateErrors([&] { dict->_backingCollection.verify_in_transaction(); });

    RLMObservationTracker tracker(dict->_realm);
    tracker.trackDeletions();
    auto obsInfo = RLMGetObservationInfo(dict->_observationInfo.get(),
                                         dict->_backingCollection.get_parent_object_key(),
                                         *dict->_ownerInfo);
    if (obsInfo) {
        tracker.willChange(obsInfo, dict->_key);
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
    return translateErrors([&] {
        return _backingCollection.size();
    });
}

static NSMutableArray *resultsToArray(RLMClassInfo& info, realm::Results r) {
    RLMAccessorContext c(info);
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:r.size()];
    for (size_t i = 0, size = r.size(); i < size; ++i) {
        [array addObject:r.get(c, i)];
    }
    return array;
}

- (NSArray *)allKeys {
    return translateErrors([&] {
        return resultsToArray(*_objectInfo, _backingCollection.get_keys());
    });
}

- (NSArray *)allValues {
    return translateErrors([&] {
        return resultsToArray(*_objectInfo, _backingCollection.get_values());
    });
}

- (BOOL)isInvalidated {
    return translateErrors([&] { return !_backingCollection.is_valid(); });
}

- (RLMClassInfo *)objectInfo {
    return _objectInfo;
}

- (bool)isBackedByDictionary:(realm::object_store::Dictionary const&)dictionary {
    return _backingCollection == dictionary;
}

- (BOOL)isEqual:(id)object {
    return [object respondsToSelector:@selector(isBackedByDictionary:)] &&
           [object isBackedByDictionary:_backingCollection];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return RLMFastEnumerate(state, len, self);
}

#pragma mark - Object Retrieval

- (nullable id)objectForKey:(id)key {
    return translateErrors([&]() -> id {
        [self.realm verifyThread];
        RLMAccessorContext context(*_objectInfo);
        if (auto value = _backingCollection.try_get_any(context.unbox<realm::StringData>(key))) {
            return context.box(*value);
        }
        return nil;
    });
}

- (void)setObject:(id)obj forKey:(id)key {
    changeDictionary(self, ^{
        RLMAccessorContext c(*_objectInfo);
        _backingCollection.insert(c, c.unbox<realm::StringData>(RLMDictionaryKey(self, key)),
                                  RLMDictionaryValue(self, obj));
    });
}

- (void)removeAllObjects {
    changeDictionary(self, ^{
        _backingCollection.remove_all();
    });
}

- (void)removeObjectsForKeys:(NSArray *)keyArray {
    RLMAccessorContext context(*_objectInfo);
    changeDictionary(self, [&] {
        for (id key in keyArray) {
            try {
                _backingCollection.erase(context.unbox<realm::StringData>(key));
            }
            catch (realm::KeyNotFound const&) {
                continue;
            }
        }
    });
}

- (void)removeObjectForKey:(id)key {
    try {
        changeDictionary(self, ^{
            RLMAccessorContext context(*_objectInfo);
            _backingCollection.erase(context.unbox<realm::StringData>(key));
        });
    }
    catch (realm::KeyNotFound const&) {
        return;
    }
    catch (...) {
        throwError(nil, nil);
    }
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    RLMAccessorContext c(*_objectInfo);
    BOOL stop = false;
    @autoreleasepool {
        for (auto&& [key, value] : _backingCollection) {
            block(c.box(key), c.box(value), &stop);
            if (stop) {
                break;
            }
        }
    }
}

- (void)mergeDictionary:(id)dictionary clear:(bool)clear {
    if (!clear && !dictionary) {
        return;
    }
    if (dictionary && ![dictionary respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
        @throw RLMException(@"Cannot %@ object of class '%@'",
                            clear ? @"set dictionary to" : @"add entries from",
                            [dictionary className]);
    }

    changeDictionary(self, ^{
        RLMAccessorContext c(*_objectInfo);
        if (clear) {
            _backingCollection.remove_all();
        }
        [dictionary enumerateKeysAndObjectsUsingBlock:[&](id key, id value, BOOL *) {
            _backingCollection.insert(c, c.unbox<realm::StringData>(RLMDictionaryKey(self, key)),
                                      RLMDictionaryValue(self, value));
        }];
    });
}

- (void)setDictionary:(id)dictionary {
    [self mergeDictionary:RLMCoerceToNil(dictionary) clear:true];
}

- (void)addEntriesFromDictionary:(id)otherDictionary {
    [self mergeDictionary:otherDictionary clear:false];
}

#pragma mark - KVC

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) {
        // Delegate KVC collection operators to RLMResults
        return translateErrors([&] {
            auto results = [RLMResults resultsWithObjectInfo:*_objectInfo
                                                     results:_backingCollection.as_results()];
            return [results valueForKeyPath:keyPath];
        });
    }
    return [super valueForKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:RLMInvalidatedKey]) {
        return @(!_backingCollection.is_valid());
    }
    return [self objectForKey:key];
}

- (void)setValue:(id)value forKey:(nonnull NSString *)key {
    [self setObject:value forKeyedSubscript:key];
}

- (id)minOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, RLMCollectionTypeDictionary);
    auto value = translateErrors(self, [&] {
        return _backingCollection.as_results().min(column);
    }, @"minOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)maxOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, RLMCollectionTypeDictionary);
    auto value = translateErrors(self, [&] {
        return _backingCollection.as_results().max(column);
    }, @"maxOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)sumOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, RLMCollectionTypeDictionary);
    auto value = translateErrors(self, [&] {
        return _backingCollection.as_results().sum(column);
    }, @"sumOfProperty");
    return value ? RLMMixedToObjc(*value) : @0;
}

- (id)averageOfProperty:(NSString *)property {
    auto column = columnForProperty(property, _backingCollection, _objectInfo, _type, RLMCollectionTypeDictionary);
    auto value = translateErrors(self, [&] {
        return _backingCollection.as_results().average(column);
    }, @"averageOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Cannot delete objects from RLMManagedDictionary<RLMString, %@%@>: only RLMObjects can be deleted.", RLMTypeToString(_type), _optional? @"?": @"");
    }
    // delete all target rows from the realm
    RLMObservationTracker tracker(_realm, true);
    translateErrors([&] {
        for (auto&& [key, value] : _backingCollection) {
            _realm.group.get_object(value.get_link()).remove();
        }
        _backingCollection.remove_all();
    });
}

- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    return translateErrors([&] {
        return [RLMResults resultsWithObjectInfo:*_objectInfo
                                         results:_backingCollection.as_results().sort(RLMSortDescriptorsToKeypathArray(properties))];
    });
}

- (RLMResults *)sortedResultsUsingKeyPath:(nonnull NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:keyPath ascending:ascending]]];
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    return translateErrors([&] {
        auto results = [RLMResults resultsWithObjectInfo:*_objectInfo results:_backingCollection.as_results()];
        return [results distinctResultsUsingKeyPaths:keyPaths];
    });
}

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    if (_type != RLMPropertyTypeObject) {
        @throw RLMException(@"Querying is currently only implemented for dictionaries of Realm Objects");
    }
    auto query = RLMPredicateToQuery(predicate, _objectInfo->rlmObjectSchema, _realm.schema, _realm.group);
    auto results = translateErrors([&] {
        return _backingCollection.as_results().filter(std::move(query));
    });
    return [RLMResults resultsWithObjectInfo:*_objectInfo results:std::move(results)];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    RLMEnsureDictionaryObservationInfo(_observationInfo, keyPath, self, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (realm::TableView)tableView {
    return translateErrors([&] {
        return _backingCollection.as_results().get_query();
    }).find_all();
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateErrors([&] {
        return [[RLMFastEnumerator alloc] initWithBackingDictionary:_backingCollection
                                                         dictionary:self
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

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMDictionaryChange *, NSError *))block {
    return RLMAddNotificationBlock(self, block, nil, nil);
}
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMDictionaryChange *, NSError *))block queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, block, nil, queue);
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMDictionaryChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, block, keyPaths, queue);
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMDictionaryChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths {
    return RLMAddNotificationBlock(self, block, keyPaths, nil);
}
#pragma clang diagnostic pop

realm::object_store::Dictionary& RLMGetBackingCollection(RLMManagedDictionary *self) {
    return self->_backingCollection;
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _backingCollection;
}

- (RLMManagedCollectionHandoverMetadata *)objectiveCMetadata {
    RLMManagedCollectionHandoverMetadata *metadata = [[RLMManagedCollectionHandoverMetadata alloc] init];
    metadata.parentClassName = _ownerInfo->rlmObjectSchema.className;
    metadata.key = _key;
    return metadata;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(RLMManagedCollectionHandoverMetadata *)metadata
                                        realm:(RLMRealm *)realm {
    auto dictionary = reference.resolve<realm::object_store::Dictionary>(realm->_realm);
    if (!dictionary.is_valid()) {
        return nil;
    }
    RLMClassInfo *parentInfo = &realm->_info[metadata.parentClassName];
    return [[RLMManagedDictionary alloc] initWithBackingCollection:std::move(dictionary)
                                                        parentInfo:parentInfo
                                                          property:parentInfo->rlmObjectSchema[metadata.key]];
}

static RLMNotificationToken *RLMAddNotificationBlock(RLMManagedDictionary *collection,
                                                     void (^block)(id, RLMDictionaryChange *, NSError *),
                                                     NSArray<NSString *> *keyPaths,
                                                     dispatch_queue_t queue) {
    RLMRealm *realm = collection.realm;
    auto token = [[RLMCancellationToken alloc] init];

    RLMClassInfo *info = collection.objectInfo;
    realm::KeyPathArray keyPathArray = KeyPathArrayFromStringArray(realm ,realm.schema, info->rlmObjectSchema, info, keyPaths);

    if (!queue) {
        [realm verifyNotificationsAreSupported:true];
        token->_realm = realm;
        token->_token = RLMGetBackingCollection(collection).add_key_based_notification_callback(DictionaryCallbackWrapper{block, collection}, keyPathArray);
        return token;
    }

    RLMThreadSafeReference *tsr = [RLMThreadSafeReference referenceWithThreadConfined:collection];
    token->_realm = realm;
    RLMRealmConfiguration *config = realm.configuration;
    dispatch_async(queue, ^{
        std::lock_guard<std::mutex> lock(token->_mutex);
        if (!token->_realm) {
            return;
        }
        NSError *error;
        RLMRealm *realm = token->_realm = [RLMRealm realmWithConfiguration:config queue:queue error:&error];
        if (!realm) {
            block(nil, nil, error);
            return;
        }
        RLMManagedDictionary *collection = [realm resolveThreadSafeReference:tsr];
        token->_token = RLMGetBackingCollection(collection).add_key_based_notification_callback(DictionaryCallbackWrapper{block, collection}, keyPathArray);
    });
    return token;
}

@end
