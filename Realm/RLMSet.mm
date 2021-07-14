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

#import "RLMObjectSchema.h"
#import "RLMObjectStore.h"
#import "RLMObject_Private.h"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMSchema_Private.h"
#import "RLMSwiftSupport.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

// See -countByEnumeratingWithState:objects:count
@interface RLMSetHolder : NSObject {
@public
    std::unique_ptr<id[]> items;
}
@end
@implementation RLMSetHolder
@end

@interface RLMSet () <RLMThreadConfined_Private>
@end

@implementation RLMSet {
@public
    // Backing set when this instance is unmanaged
    NSMutableSet *_backingCollection;
}

#pragma mark - Initializers

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName
                                keyType:(__unused RLMPropertyType)keyType {
    return [self initWithObjectClassName:objectClassName];
}
- (instancetype)initWithObjectType:(RLMPropertyType)type
                          optional:(BOOL)optional
                           keyType:(__unused RLMPropertyType)keyType {
    return [self initWithObjectType:type optional:optional];
}

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName {
    REALM_ASSERT([objectClassName length] > 0);
    self = [super init];
    if (self) {
        _objectClassName = objectClassName;
        _type = RLMPropertyTypeObject;
    }
    return self;
}

- (instancetype)initWithObjectType:(RLMPropertyType)type optional:(BOOL)optional {
    self = [super init];
    if (self) {
        _type = type;
        _optional = optional;
    }
    return self;
}

- (void)setParent:(RLMObjectBase *)parentObject property:(RLMProperty *)property {
    _parentObject = parentObject;
    _key = property.name;
    _isLegacyProperty = property.isLegacy;
}

#pragma mark - Convenience wrappers used for all RLMSet types

- (void)addObjects:(id<NSFastEnumeration>)objects {
    for (id obj in objects) {
        [self addObject:obj];
    }
}

- (void)addObject:(id)object {
    RLMSetValidateMatchingObjectType(self, object);
    changeSet(self, ^{
        [_backingCollection addObject:object];
    });
}

- (void)setObject:(id)newValue atIndexedSubscript:(NSUInteger)index {
    REALM_TERMINATE("Replacing objects at an indexed subscript is not supported on RLMSet");
}

- (void)setSet:(RLMSet<id> *)set {
    for (id obj in set) {
        RLMSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection setSet:set->_backingCollection];
    });
}

- (void)intersectSet:(RLMSet<id> *)set {
    for (id obj in set) {
        RLMSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection intersectSet:set->_backingCollection];
    });
}

- (void)minusSet:(RLMSet<id> *)set {
    for (id obj in set) {
        RLMSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection minusSet:set->_backingCollection];
    });
}

- (void)unionSet:(RLMSet<id> *)set {
    for (id obj in set) {
        RLMSetValidateMatchingObjectType(self, obj);
    }
    changeSet(self, ^{
        [_backingCollection unionSet:set->_backingCollection];
    });
}

- (BOOL)isSubsetOfSet:(RLMSet<id> *)set {
    for (id obj in set) {
        RLMSetValidateMatchingObjectType(self, obj);
    }
    return [_backingCollection isSubsetOfSet:set->_backingCollection];
}

- (BOOL)intersectsSet:(RLMSet<id> *)set {
    for (id obj in set) {
        RLMSetValidateMatchingObjectType(self, obj);
    }
    return [_backingCollection intersectsSet:set->_backingCollection];
}

- (BOOL)containsObject:(id)obj {
    RLMSetValidateMatchingObjectType(self, obj);
    return [_backingCollection containsObject:obj];
}

- (BOOL)isEqualToSet:(RLMSet<id> *)set {
    return [self isEqual:set];
}

// For use with MutableSet subscripting, NSSet does not support
// subscripting while its Swift counterpart `Set` does.
- (id)objectAtIndex:(NSUInteger)index {
    validateSetBounds(self, index);
    return _backingCollection.allObjects[index];
}

- (RLMResults *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:keyPath ascending:ascending]]];
}

#pragma mark - Unmanaged RLMSet implementation

- (RLMRealm *)realm {
    return nil;
}

- (NSUInteger)count {
    return _backingCollection.count;
}

- (NSArray<id> *)allObjects {
    return _backingCollection.allObjects;
}

- (BOOL)isInvalidated {
    return NO;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(__unused NSUInteger)len {
    if (state->state != 0) {
        return 0;
    }

    // We need to enumerate a copy of the backing set so that it doesn't
    // reflect changes made during enumeration. This copy has to be autoreleased
    // (since there's nowhere for us to store a strong reference), and uses
    // RLMSetHolder rather than an NSArray because NSArray doesn't guarantee
    // that it'll use a single contiguous block of memory, and if it doesn't
    // we'd need to forward multiple calls to this method to the same NSArray,
    // which would require holding a reference to it somewhere.
    __autoreleasing RLMSetHolder *copy = [[RLMSetHolder alloc] init];
    copy->items = std::make_unique<id[]>(self.count);

    NSUInteger i = 0;
    for (id object in _backingCollection) {
        copy->items[i++] = object;
    }

    state->itemsPtr = (__unsafe_unretained id *)(void *)copy->items.get();
    // needs to point to something valid, but the whole point of this is so
    // that it can't be changed
    state->mutationsPtr = state->extra;
    state->state = i;

    return i;
}

static void changeSet(__unsafe_unretained RLMSet *const set,
                      dispatch_block_t f) {
    if (!set->_backingCollection) {
        set->_backingCollection = [NSMutableSet new];
    }

    if (RLMObjectBase *parent = set->_parentObject) {
        [parent willChangeValueForKey:set->_key];
        f();
        [parent didChangeValueForKey:set->_key];
    }
    else {
        f();
    }
}

static void validateSetBounds(__unsafe_unretained RLMSet *const set,
                              NSUInteger index,
                              bool allowOnePastEnd=false) {
    NSUInteger max = set->_backingCollection.count + allowOnePastEnd;
    if (index >= max) {
        @throw RLMException(@"Index %llu is out of bounds (must be less than %llu).",
                            (unsigned long long)index, (unsigned long long)max);
    }
}

- (void)removeAllObjects {
    changeSet(self, ^{
        [_backingCollection removeAllObjects];
    });
}

- (void)removeObject:(id)object {
    RLMSetValidateMatchingObjectType(self, object);
    changeSet(self, ^{
        [_backingCollection removeObject:object];
    });
}

- (void)replaceAllObjectsWithObjects:(NSArray *)objects {
    changeSet(self, ^{
        [_backingCollection removeAllObjects];
        if (!objects || (id)objects == NSNull.null) {
            return;
        }
        for (id object in objects) {
            [_backingCollection addObject:object];
        }
    });
}

- (RLMResults *)objectsWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

- (RLMResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (RLMPropertyType)typeForProperty:(NSString *)propertyName {
    if ([propertyName isEqualToString:@"self"]) {
        return _type;
    }

    RLMObjectSchema *objectSchema;
    if (_backingCollection.count) {
        objectSchema = [_backingCollection.allObjects[0] objectSchema];
    }
    else {
        objectSchema = [RLMSchema.partialPrivateSharedSchema schemaForClassName:_objectClassName];
    }

    return RLMValidatedProperty(objectSchema, propertyName).type;
}

- (id)aggregateProperty:(NSString *)key operation:(NSString *)op method:(SEL)sel {
    // Although delegating to valueForKeyPath: here would allow to support
    // nested key paths as well, limiting functionality gives consistency
    // between unmanaged and managed arrays.
    if ([key rangeOfString:@"."].location != NSNotFound) {
        @throw RLMException(@"Nested key paths are not supported yet for KVC collection operators.");
    }

    if ([op isEqualToString:@"@distinctUnionOfObjects"]) {
        @throw RLMException(@"this class does not implement the distinctUnionOfObjects");
    }

    bool allowDate = false;
    bool sum = false;
    if ([op isEqualToString:@"@min"] || [op isEqualToString:@"@max"]) {
        allowDate = true;
    }
    else if ([op isEqualToString:@"@sum"]) {
        sum = true;
    }
    else if (![op isEqualToString:@"@avg"]) {
        // Just delegate to NSSet for all other operators
        return [_backingCollection valueForKeyPath:[op stringByAppendingPathExtension:key]];
    }

    RLMPropertyType type = [self typeForProperty:key];
    if (!canAggregate(type, allowDate)) {
        NSString *method = sel ? NSStringFromSelector(sel) : op;
        if (_type == RLMPropertyTypeObject) {
            @throw RLMException(@"%@: is not supported for %@ property '%@.%@'",
                                method, RLMTypeToString(type), _objectClassName, key);
        }
        else {
            @throw RLMException(@"%@ is not supported for %@%s set",
                                method, RLMTypeToString(_type), _optional ? "?" : "");
        }
    }

    // `valueForKeyPath` on NSSet will only return distinct values, which is an
    // issue as the realm::object_store::Set aggregate methods will calculate
    // the result based on each element of a property regardless of uniqueness.
    // To get around this we will need to use the `array` property of the NSMutableOrderedSet
    NSArray *values = [key isEqualToString:@"self"] ? _backingCollection.allObjects : [_backingCollection.allObjects valueForKey:key];
    if (_optional) {
        // Filter out NSNull values to match our behavior on managed arrays
        NSIndexSet *nonnull = [values indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger, BOOL *) {
            return obj != NSNull.null;
        }];
        if (nonnull.count < values.count) {
            values = [values objectsAtIndexes:nonnull];
        }
    }

    id result = [values valueForKeyPath:[op stringByAppendingString:@".self"]];
    return sum && !result ? @0 : result;
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath characterAtIndex:0] != '@') {
        return _backingCollection ? [_backingCollection valueForKeyPath:keyPath] : [super valueForKeyPath:keyPath];
    }

    if (!_backingCollection) {
        _backingCollection = [NSMutableSet new];
    }

    NSUInteger dot = [keyPath rangeOfString:@"."].location;
    if (dot == NSNotFound) {
        return [_backingCollection valueForKeyPath:keyPath];
    }

    NSString *op = [keyPath substringToIndex:dot];
    NSString *key = [keyPath substringFromIndex:dot + 1];
    return [self aggregateProperty:key operation:op method:nil];
}

- (id)valueForKey:(NSString *)key {
    if ([key isEqualToString:RLMInvalidatedKey]) {
        return @NO; // Unmanaged sets are never invalidated
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableSet new];
    }
    return [_backingCollection valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"self"]) {
        RLMSetValidateMatchingObjectType(self, value);
        [_backingCollection removeAllObjects];
        [_backingCollection addObject:value];
        return;
    }
    else if (_type == RLMPropertyTypeObject) {
        [_backingCollection setValue:value forKey:key];
    }
    else {
        [self setValue:value forUndefinedKey:key];
    }
}

- (id)minOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@min" method:_cmd];
}

- (id)maxOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@max" method:_cmd];
}

- (id)sumOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@sum" method:_cmd];
}

- (id)averageOfProperty:(NSString *)property {
    return [self aggregateProperty:property operation:@"@avg" method:_cmd];
}

- (BOOL)isEqual:(id)object {
    if (auto set = RLMDynamicCast<RLMSet>(object)) {
        return !set.realm
        && ((_backingCollection.count == 0 && set->_backingCollection.count == 0)
            || [_backingCollection isEqual:set->_backingCollection]);
    }
    return NO;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    RLMValidateSetObservationKey(keyPath, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

void RLMSetValidateMatchingObjectType(__unsafe_unretained RLMSet *const set,
                                      __unsafe_unretained id const value) {
    if (!value && !set->_optional) {
        @throw RLMException(@"Invalid nil value for set of '%@'.",
                            set->_objectClassName ?: RLMTypeToString(set->_type));
    }
    if (set->_type != RLMPropertyTypeObject) {
        if (!RLMValidateValue(value, set->_type, set->_optional, false, nil)) {
            @throw RLMException(@"Invalid value '%@' of type '%@' for expected type '%@%s'.",
                                value, [value class], RLMTypeToString(set->_type),
                                set->_optional ? "?" : "");
        }
        return;
    }

    auto object = RLMDynamicCast<RLMObjectBase>(value);
    if (!object) {
        return;
    }
    if (!object->_objectSchema) {
        @throw RLMException(@"Object cannot be inserted unless the schema is initialized. "
                            "This can happen if you try to insert objects into a RLMSet / Set from a default value or from an overriden unmanaged initializer (`init()`).");
    }
    if (![set->_objectClassName isEqualToString:object->_objectSchema.className]
        && (set->_type != RLMPropertyTypeAny)) {
        @throw RLMException(@"Object of type '%@' does not match RLMSet type '%@'.",
                            object->_objectSchema.className, set->_objectClassName);
    }
}

#pragma mark - Key Path Strings

- (NSString *)propertyKey {
    return _key;
}

#pragma mark - Methods unsupported on unmanaged RLMSet instances

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block {
    return [self addNotificationBlock:block queue:nil];
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block
                                         queue:(nullable dispatch_queue_t)queue {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(nullable dispatch_queue_t)queue {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSet *, RLMCollectionChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

- (instancetype)freeze {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

- (instancetype)thaw {
    @throw RLMException(@"This method may only be called on RLMSet instances retrieved from an RLMRealm");
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    REALM_TERMINATE("Unexpected handover of unmanaged `RLMSet`");
}

- (id)objectiveCMetadata {
    REALM_TERMINATE("Unexpected handover of unmanaged `RLMSet`");
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(id)metadata
                                        realm:(RLMRealm *)realm {
    REALM_TERMINATE("Unexpected handover of unmanaged `RLMSet`");
}

#pragma clang diagnostic pop // unused parameter warning

#pragma mark - Superclass Overrides

- (NSString *)description {
    return [self descriptionWithMaxDepth:RLMDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    return RLMDescriptionWithMaxDepth(@"RLMSet", self, depth);
}
@end
