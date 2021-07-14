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
#import "RLMObject_Private.h"
#import "RLMObjectSchema.h"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMSchema_Private.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

// See -countByEnumeratingWithState:objects:count
@interface RLMDictionaryHolder : NSObject {
@public
    std::unique_ptr<id[]> items;
}
@end
@implementation RLMDictionaryHolder
@end

@interface RLMDictionary () <RLMThreadConfined_Private>
@end

@implementation NSString (RLMDictionaryKey)
@end

@implementation RLMDictionary {
@public
    // Backing dictionary when this instance is unmanaged
    NSMutableDictionary *_backingCollection;
}

#pragma mark Initializers

- (instancetype)initWithObjectClassName:(__unsafe_unretained NSString *const)objectClassName
                                keyType:(RLMPropertyType)keyType {
    REALM_ASSERT([objectClassName length] > 0);
    REALM_ASSERT(RLMValidateKeyType(keyType));
    self = [super init];
    if (self) {
        _objectClassName = objectClassName;
        _type = RLMPropertyTypeObject;
        _keyType = keyType;
        _optional = YES;
    }
    return self;
}

- (instancetype)initWithObjectType:(RLMPropertyType)type optional:(BOOL)optional keyType:(RLMPropertyType)keyType {
    REALM_ASSERT(RLMValidateKeyType(keyType));
    self = [super init];
    if (self) {
        _type = type;
        _keyType = keyType;
        _optional = optional;
    }
    return self;
}

- (void)setParent:(RLMObjectBase *)parentObject property:(RLMProperty *)property {
    _parentObject = parentObject;
    _key = property.name;
    _isLegacyProperty = property.isLegacy;
}

static bool RLMValidateKeyType(RLMPropertyType keyType) {
    switch (keyType) {
        case RLMPropertyTypeString:
            return true;
        default:
            return false;
    }
}

id RLMDictionaryKey(__unsafe_unretained RLMDictionary *const dictionary,
                    __unsafe_unretained id const key) {
    if (!key) {
        @throw RLMException(@"Invalid nil key for dictionary expecting key of type '%@'.",
                            dictionary->_objectClassName ?: RLMTypeToString(dictionary.keyType));
    }
    id validated = RLMValidateValue(key, dictionary.keyType, false, false, nil);
    if (!validated) {
        @throw RLMException(@"Invalid key '%@' of type '%@' for expected type '%@'.",
                            key, [key class], RLMTypeToString(dictionary.keyType));
    }
    return validated;
}

id RLMDictionaryValue(__unsafe_unretained RLMDictionary *const dictionary,
                      __unsafe_unretained id const value) {
    if (!value) {
        return value;
    }
    if (dictionary->_type != RLMPropertyTypeObject) {
        id validated = RLMValidateValue(value, dictionary->_type, dictionary->_optional, false, nil);
        if (!validated) {
            @throw RLMException(@"Invalid value '%@' of type '%@' for expected type '%@%s'.",
                                value, [value class], RLMTypeToString(dictionary->_type),
                                dictionary->_optional ? "?" : "");
        }
        return validated;
    }

    if (auto valueObject = RLMDynamicCast<RLMObjectBase>(value)) {
        if (!valueObject->_objectSchema) {
            @throw RLMException(@"Object cannot be inserted unless the schema is initialized. "
                                "This can happen if you try to insert objects into a RLMDictionary / Map from a default value or from an overridden unmanaged initializer (`init()`) or if the key is uninitialized.");
        }
        if (![dictionary->_objectClassName isEqualToString:valueObject->_objectSchema.className]) {
            @throw RLMException(@"Value of type '%@' does not match RLMDictionary value type '%@'.",
                                valueObject->_objectSchema.className, dictionary->_objectClassName);
        }
    }
    else if (![value isKindOfClass:NSNull.class]) {
        @throw RLMException(@"Value of type '%@' does not match RLMDictionary value type '%@'.",
                            [value className], dictionary->_objectClassName);
    }

    return value;
}

static void changeDictionary(__unsafe_unretained RLMDictionary *const dictionary,
                             dispatch_block_t f) {
    if (!dictionary->_backingCollection) {
        dictionary->_backingCollection = [NSMutableDictionary new];
    }
    if (RLMObjectBase *parent = dictionary->_parentObject) {
        [parent willChangeValueForKey:dictionary->_key];
        f();
        [parent didChangeValueForKey:dictionary->_key];
    }
    else {
        f();
    }
}

#pragma mark - Unmanaged RLMDictionary implementation

- (RLMRealm *)realm {
    return nil;
}

- (NSUInteger)count {
    return _backingCollection.count;
}

- (NSArray *)allKeys {
    return _backingCollection.allKeys ?: @[];
}

- (NSArray *)allValues {
    return _backingCollection.allValues ?: @[];
}

- (nullable id)objectForKey:(id)key {
    if (!_backingCollection) {
        _backingCollection = [NSMutableDictionary new];
    }
    return [_backingCollection objectForKey:key];
}

- (nullable id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (BOOL)isInvalidated {
    return NO;
}

- (void)setValue:(nullable id)value forKey:(nonnull NSString *)key {
    [self setObject:value forKeyedSubscript:key];
}

- (void)setDictionary:(id)dictionary {
    if (!dictionary || dictionary == NSNull.null) {
        return [self removeAllObjects];
    }
    if (![dictionary respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
        @throw RLMException(@"Cannot set dictionary to object of class '%@'", [dictionary className]);
    }

    changeDictionary(self, ^{
        [_backingCollection removeAllObjects];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *) {
            [_backingCollection setObject:RLMDictionaryValue(self, value)
                                   forKey:RLMDictionaryKey(self, key)];
        }];
    });
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    if (obj) {
        [self setObject:obj forKey:key];
    }
    else {
        [self removeObjectForKey:key];
    }
}

- (void)setObject:(id)obj forKey:(id)key {
    changeDictionary(self, ^{
        [_backingCollection setObject:RLMDictionaryValue(self, obj)
                               forKey:RLMDictionaryKey(self, key)];
    });
}

- (void)removeAllObjects {
    changeDictionary(self, ^{
        [_backingCollection removeAllObjects];
    });
}

- (void)removeObjectsForKeys:(NSArray *)keyArray {
    changeDictionary(self, ^{
        [_backingCollection removeObjectsForKeys:keyArray];
    });
}

- (void)removeObjectForKey:(id)key {
    changeDictionary(self, ^{
        [_backingCollection removeObjectForKey:key];
    });
}

- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block {
    [_backingCollection enumerateKeysAndObjectsUsingBlock:block];
}

- (nullable id)valueForKey:(nonnull NSString *)key {
    if ([key isEqualToString:RLMInvalidatedKey]) {
        return @NO; // Unmanaged dictionaries are never invalidated
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableDictionary new];
    }
    return [_backingCollection valueForKey:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath characterAtIndex:0] != '@') {
        return _backingCollection ? [_backingCollection valueForKeyPath:keyPath] : [super valueForKeyPath:keyPath];
    }
    if (!_backingCollection) {
        _backingCollection = [NSMutableDictionary new];
    }
    NSUInteger dot = [keyPath rangeOfString:@"."].location;
    if (dot == NSNotFound) {
        return [_backingCollection valueForKeyPath:keyPath];
    }

    NSString *op = [keyPath substringToIndex:dot];
    NSString *key = [keyPath substringFromIndex:dot + 1];
    return [self aggregateProperty:key operation:op method:nil];
}

- (void)addEntriesFromDictionary:(id)otherDictionary {
    if (!otherDictionary) {
        return;
    }
    if (![otherDictionary respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
        @throw RLMException(@"Cannot add entries from object of class '%@'", [otherDictionary className]);
    }

    changeDictionary(self, ^{
        [otherDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *) {
            _backingCollection[RLMDictionaryKey(self, key)] = RLMDictionaryValue(self, value);
        }];
    });
}

- (NSUInteger)countByEnumeratingWithState:(nonnull NSFastEnumerationState *)state
                                  objects:(__unsafe_unretained id  _Nullable * _Nonnull)buffer
                                    count:(NSUInteger)len {
    if (state->state != 0) {
        return 0;
    }

    // We need to enumerate a copy of the backing dictionary so that it doesn't
    // reflect changes made during enumeration. This copy has to be autoreleased
    // (since there's nowhere for us to store a strong reference).
    __autoreleasing RLMDictionaryHolder *copy = [[RLMDictionaryHolder alloc] init];
    copy->items = std::make_unique<id[]>(_backingCollection.allKeys.count);

    NSUInteger i = 0;
    for (id key in _backingCollection.allKeys) {
        copy->items[i++] = key;
    }

    state->itemsPtr = (__unsafe_unretained id *)(void *)copy->items.get();
    // needs to point to something valid, but the whole point of this is so
    // that it can't be changed
    state->mutationsPtr = state->extra;
    state->state = i;

    return i;
}

#pragma mark - Aggregate operations

- (RLMPropertyType)typeForProperty:(NSString *)propertyName {
    if ([propertyName isEqualToString:@"self"]) {
        return _type;
    }

    RLMObjectSchema *objectSchema;
    if (_backingCollection.count) {
        objectSchema = [_backingCollection.allValues[0] objectSchema];
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
        // Just delegate to NSDictionary for all other operators
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
            @throw RLMException(@"%@ is not supported for %@%s dictionary",
                                method, RLMTypeToString(_type), _optional ? "?" : "");
        }
    }

    NSArray *values = [key isEqualToString:@"self"] ? _backingCollection.allValues : [_backingCollection.allValues valueForKey:key];

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

- (nonnull RLMResults *)objectsWhere:(nonnull NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

- (nonnull RLMResults *)objectsWhere:(nonnull NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (BOOL)isEqual:(id)object {
    if (auto dictionary = RLMDynamicCast<RLMDictionary>(object)) {
        return !dictionary.realm
        && ((_backingCollection.count == 0 && dictionary->_backingCollection.count == 0)
            || [_backingCollection isEqual:dictionary->_backingCollection]);
    }
    return NO;
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    RLMDictionaryValidateObservationKey(keyPath, self);
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

#pragma mark - Key Path Strings

- (NSString *)propertyKey {
    return _key;
}

#pragma mark - Methods unsupported on unmanaged RLMDictionary instances

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

- (nonnull RLMResults *)objectsWithPredicate:(nonnull NSPredicate *)predicate {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (RLMResults *)sortedResultsUsingDescriptors:(nonnull NSArray<RLMSortDescriptor *> *)properties {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (RLMResults *)sortedResultsUsingKeyPath:(nonnull NSString *)keyPath ascending:(BOOL)ascending {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (nonnull RLMNotificationToken *)addNotificationBlock:(nonnull void (^)(RLMDictionary *, RLMCollectionChange *, NSError *))block {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMCollectionChange *, NSError *))block
                                         queue:(nullable dispatch_queue_t)queue {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMCollectionChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths
                                         queue:(nullable dispatch_queue_t)queue {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMDictionary *, RLMCollectionChange *, NSError *))block
                                      keyPaths:(nullable NSArray<NSString *> *)keyPaths {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (instancetype)freeze {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (instancetype)thaw {
    @throw RLMException(@"This method may only be called on RLMDictionary instances retrieved from an RLMRealm");
}

- (NSUInteger)indexOfObject:(id)value {
    @throw RLMException(@"This method is not available on RLMDictionary.");
}

- (id)objectAtIndex:(NSUInteger)index {
    @throw RLMException(@"This method is not available on RLMDictionary.");
}

#pragma clang diagnostic pop // unused parameter warning

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    REALM_TERMINATE("Unexpected handover of unmanaged `RLMDictionary`");
}

- (id)objectiveCMetadata {
    REALM_TERMINATE("Unexpected handover of unmanaged `RLMDictionary`");
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(id)metadata
                                        realm:(RLMRealm *)realm {
    REALM_TERMINATE("Unexpected handover of unmanaged `RLMDictionary`");
}

#pragma mark - Superclass Overrides

- (NSString *)description {
    return [self descriptionWithMaxDepth:RLMDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    return RLMDictionaryDescriptionWithMaxDepth(@"RLMDictionary", self, depth);
}

NSString *RLMDictionaryDescriptionWithMaxDepth(NSString *name,
                                               RLMDictionary *dictionary,
                                               NSUInteger depth) {
    if (depth == 0) {
        return @"<Maximum depth exceeded>";
    }

    const NSUInteger maxObjects = 100;
    auto str = [NSMutableString stringWithFormat:@"%@<%@, %@> <%p> (\n", name,
                RLMTypeToString([dictionary keyType]),
                [dictionary objectClassName] ?: RLMTypeToString([dictionary type]),
                (void *)dictionary];
    size_t index = 0, skipped = 0;
    for (id key in dictionary) {
        id value = dictionary[key];
        NSString *keyDesc;
        if ([key respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            keyDesc = [key descriptionWithMaxDepth:depth - 1];
        }
        else {
            keyDesc = [key description];
        }
        NSString *valDesc;
        if ([value respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            valDesc = [value descriptionWithMaxDepth:depth - 1];
        }
        else {
            valDesc = [value description];
        }

        // Indent child objects
        NSString *sub = [NSString stringWithFormat:@"[%@]: %@", keyDesc, valDesc];
        NSString *objDescription = [sub stringByReplacingOccurrencesOfString:@"\n"
                                                                  withString:@"\n\t"];
        [str appendFormat:@"%@,\n", objDescription];
        if (index >= maxObjects) {
            skipped = dictionary.count - maxObjects;
            break;
        }
    }

    // Remove last comma and newline characters
    if (dictionary.count > 0) {
        [str deleteCharactersInRange:NSMakeRange(str.length-2, 2)];
    }
    if (skipped) {
        [str appendFormat:@"\n\t... %zu objects skipped.", skipped];
    }
    [str appendFormat:@"\n)"];
    return str;
}

@end
