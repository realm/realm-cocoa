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

#import "RLMObject_Private.hpp"

#import "RLMAccessor.h"
#import "RLMArray_Private.hpp"
#import "RLMDecimal128.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMSet_Private.hpp"
#import "RLMSwiftCollectionBase.h"
#import "RLMSwiftSupport.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

#import <realm/object-store/object.hpp>
#import <realm/object-store/object_schema.hpp>
#import <realm/object-store/shared_realm.hpp>

using namespace realm;

const NSUInteger RLMDescriptionMaxDepth = 5;


static bool isManagedAccessorClass(Class cls) {
    const char *className = class_getName(cls);
    const char accessorClassPrefix[] = "RLM:Managed";
    return strncmp(className, accessorClassPrefix, sizeof(accessorClassPrefix) - 1) == 0;
}

static void maybeInitObjectSchemaForUnmanaged(RLMObjectBase *obj) {
    Class cls = obj.class;
    if (isManagedAccessorClass(cls)) {
        return;
    }

    obj->_objectSchema = [cls sharedSchema];
    if (!obj->_objectSchema) {
        return;
    }

    // set default values
    if (!obj->_objectSchema.isSwiftClass) {
        NSDictionary *dict = RLMDefaultValuesForObjectSchema(obj->_objectSchema);
        for (NSString *key in dict) {
            [obj setValue:dict[key] forKey:key];
        }
    }

    // set unmanaged accessor class
    object_setClass(obj, obj->_objectSchema.unmanagedClass);
}

@interface RLMObjectBase () <RLMThreadConfined, RLMThreadConfined_Private>
@end

@implementation RLMObjectBase
- (instancetype)init {
    if ((self = [super init])) {
        maybeInitObjectSchemaForUnmanaged(self);
    }
    return self;
}

- (void)dealloc {
    // This can't be a unique_ptr because associated objects are removed
    // *after* c++ members are destroyed and dealloc is called, and we need it
    // to be in a validish state when that happens
    delete _observationInfo;
    _observationInfo = nullptr;
}

static id coerceToObjectType(id obj, Class cls, RLMSchema *schema) {
    if ([obj isKindOfClass:cls] && ![(id)cls isEmbedded]) {
        return obj;
    }
    id value = [[cls alloc] init];
    RLMInitializeWithValue(value, obj, schema);
    return value;
}

static id validatedObjectForProperty(__unsafe_unretained id const obj,
                                     __unsafe_unretained RLMObjectSchema *const objectSchema,
                                     __unsafe_unretained RLMProperty *const prop,
                                     __unsafe_unretained RLMSchema *const schema) {
    RLMValidateValueForProperty(obj, objectSchema, prop);
    if (!obj || obj == NSNull.null) {
        return nil;
    }
    if (prop.type == RLMPropertyTypeObject) {
        Class objectClass = schema[prop.objectClassName].objectClass;
        if (prop.dictionary) {
            NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
            for (id key in obj) {
                id val = coerceToObjectType(obj[key], objectClass, schema);
                [ret setObject:val forKey:key];
            }
            return ret;
        }
        else if (prop.collection) {
            NSMutableArray *ret = [[NSMutableArray alloc] init];
            for (id el in obj) {
                [ret addObject:coerceToObjectType(el, objectClass, schema)];
            }
            return ret;
        }
        return coerceToObjectType(obj, objectClass, schema);
    }
    else if (prop.type == RLMPropertyTypeDecimal128 && !prop.collection) {
        return [[RLMDecimal128 alloc] initWithValue:obj];
    }
    return obj;
}

void RLMInitializeWithValue(RLMObjectBase *self, id value, RLMSchema *schema) {
    if (!value || value == NSNull.null) {
        @throw RLMException(@"Must provide a non-nil value.");
    }

    RLMObjectSchema *objectSchema = self->_objectSchema;
    if (!objectSchema) {
        // Will be nil if we're called during schema init, when we don't want
        // to actually populate the object anyway
        return;
    }

    NSArray *properties = objectSchema.properties;
    if (NSArray *array = RLMDynamicCast<NSArray>(value)) {
        if (array.count > properties.count) {
            @throw RLMException(@"Invalid array input: more values (%llu) than properties (%llu).",
                                (unsigned long long)array.count, (unsigned long long)properties.count);
        }
        NSUInteger i = 0;
        for (id val in array) {
            RLMProperty *prop = properties[i++];
            [self setValue:validatedObjectForProperty(RLMCoerceToNil(val), objectSchema, prop, schema)
                    forKey:prop.name];
        }
    }
    else {
        // assume our object is an NSDictionary or an object with kvc properties
        for (RLMProperty *prop in properties) {
            id obj = RLMValidatedValueForProperty(value, prop.name, objectSchema.className);

            // don't set unspecified properties
            if (!obj) {
                continue;
            }

            [self setValue:validatedObjectForProperty(RLMCoerceToNil(obj), objectSchema, prop, schema)
                    forKey:prop.name];
        }
    }
}

id RLMCreateManagedAccessor(Class cls, RLMClassInfo *info) {
    RLMObjectBase *obj = [[cls alloc] init];
    obj->_info = info;
    obj->_realm = info->realm;
    obj->_objectSchema = info->rlmObjectSchema;
    return obj;
}

- (id)valueForKey:(NSString *)key {
    if (_observationInfo) {
        return _observationInfo->valueForKey(key);
    }
    return [super valueForKey:key];
}

// Generic Swift properties can't be dynamic, so KVO doesn't work for them by default
- (id)valueForUndefinedKey:(NSString *)key {
    RLMProperty *prop = _objectSchema[key];
    if (Class swiftAccessor = prop.swiftAccessor) {
        return RLMCoerceToNil([swiftAccessor get:prop on:self]);
    }
    return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    value = RLMCoerceToNil(value);
    RLMProperty *property = _objectSchema[key];
    if (property.collection) {
        if (id enumerable = RLMAsFastEnumeration(value)) {
            value = validatedObjectForProperty(value, _objectSchema, property,
                                               RLMSchema.partialPrivateSharedSchema);
        }
    }
    if (auto swiftAccessor = property.swiftAccessor) {
        [swiftAccessor set:property on:self to:value];
    }
    else {
        [super setValue:value forUndefinedKey:key];
    }
}

// overridden at runtime per-class for performance
+ (NSString *)className {
    NSString *className = NSStringFromClass(self);
    if ([RLMSwiftSupport isSwiftClassName:className]) {
        className = [RLMSwiftSupport demangleClassName:className];
    }
    return className;
}

// overridden at runtime per-class for performance
+ (RLMObjectSchema *)sharedSchema {
    return [RLMSchema sharedSchemaForClass:self.class];
}

+ (void)initializeLinkedObjectSchemas {
    for (RLMProperty *prop in self.sharedSchema.properties) {
        if (prop.type == RLMPropertyTypeObject && !RLMSchema.partialPrivateSharedSchema[prop.objectClassName]) {
            [[RLMSchema classForString:prop.objectClassName] initializeLinkedObjectSchemas];
        }
    }
}

+ (nullable NSArray<RLMProperty *> *)_getProperties {
    return nil;
}

- (NSString *)description {
    if (self.isInvalidated) {
        return @"[invalid object]";
    }

    return [self descriptionWithMaxDepth:RLMDescriptionMaxDepth];
}

- (NSString *)descriptionWithMaxDepth:(NSUInteger)depth {
    if (depth == 0) {
        return @"<Maximum depth exceeded>";
    }

    NSString *baseClassName = _objectSchema.className;
    NSMutableString *mString = [NSMutableString stringWithFormat:@"%@ {\n", baseClassName];

    for (RLMProperty *property in _objectSchema.properties) {
        id object = [(id)self objectForKeyedSubscript:property.name];
        NSString *sub;
        if ([object respondsToSelector:@selector(descriptionWithMaxDepth:)]) {
            sub = [object descriptionWithMaxDepth:depth - 1];
        }
        else if (property.type == RLMPropertyTypeData) {
            static NSUInteger maxPrintedDataLength = 24;
            NSData *data = object;
            NSUInteger length = data.length;
            if (length > maxPrintedDataLength) {
                data = [NSData dataWithBytes:data.bytes length:maxPrintedDataLength];
            }
            NSString *dataDescription = [data description];
            sub = [NSString stringWithFormat:@"<%@ — %lu total bytes>", [dataDescription substringWithRange:NSMakeRange(1, dataDescription.length - 2)], (unsigned long)length];
        }
        else {
            sub = [object description];
        }
        [mString appendFormat:@"\t%@ = %@;\n", property.name, [sub stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    [mString appendString:@"}"];

    return [NSString stringWithString:mString];
}

- (RLMRealm *)realm {
    return _realm;
}

- (RLMObjectSchema *)objectSchema {
    return _objectSchema;
}

- (BOOL)isInvalidated {
    // if not unmanaged and our accessor has been detached, we have been deleted
    return _info && !_row.is_valid();
}

- (BOOL)isEqual:(id)object {
    if (RLMObjectBase *other = RLMDynamicCast<RLMObjectBase>(object)) {
        if (_objectSchema.primaryKeyProperty || _realm.isFrozen) {
            return RLMObjectBaseAreEqual(self, other);
        }
    }
    return [super isEqual:object];
}

- (NSUInteger)hash {
    if (_objectSchema.primaryKeyProperty) {
        // If we have a primary key property, that's an immutable value which we
        // can use as the identity of the object.
        id primaryProperty = [self valueForKey:_objectSchema.primaryKeyProperty.name];

        // modify the hash of our primary key value to avoid potential (although unlikely) collisions
        return [primaryProperty hash] ^ 1;
    }
    else if (_realm.isFrozen) {
        // The object key can never change for frozen objects, so that's usable
        // for objects without primary keys
        return static_cast<NSUInteger>(_row.get_key().value);
    }
    else {
        // Non-frozen objects without primary keys don't have any immutable
        // concept of identity that we can hash so we have to fall back to
        // pointer equality
        return [super hash];
    }
}

+ (BOOL)shouldIncludeInDefaultSchema {
    return RLMIsObjectSubclass(self);
}

+ (NSString *)primaryKey {
    return nil;
}

+ (NSString *)_realmObjectName {
    return nil;
}

+ (NSDictionary *)_realmColumnNames {
    return nil;
}

+ (bool)_realmIgnoreClass {
    return false;
}

+ (bool)isEmbedded {
    return false;
}

- (id)mutableArrayValueForKey:(NSString *)key {
    id obj = [self valueForKey:key];
    if ([obj isKindOfClass:[RLMArray class]]) {
        return obj;
    }
    return [super mutableArrayValueForKey:key];
}

- (id)mutableSetValueForKey:(NSString *)key {
    id obj = [self valueForKey:key];
    if ([obj isKindOfClass:[RLMSet class]]) {
        return obj;
    }
    return [super mutableSetValueForKey:key];
}

- (void)addObserver:(id)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context {
    if (!_observationInfo) {
        _observationInfo = new RLMObservationInfo(self);
    }
    _observationInfo->recordObserver(_row, _info, _objectSchema, keyPath);

    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    [super removeObserver:observer forKeyPath:keyPath];
    if (_observationInfo)
        _observationInfo->removeObserver();
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if (isManagedAccessorClass(self) && [class_getSuperclass(self.class) sharedSchema][key]) {
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:key];
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return Object(_realm->_realm, *_info->objectSchema, _row);
}

- (id)objectiveCMetadata {
    return nil;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(__unused id)metadata
                                        realm:(RLMRealm *)realm {
    Object object = reference.resolve<Object>(realm->_realm);
    if (!object.is_valid()) {
        return nil;
    }
    NSString *objectClassName = @(object.get_object_schema().name.c_str());
    return RLMCreateObjectAccessor(realm->_info[objectClassName], object.obj());
}

@end

RLMRealm *RLMObjectBaseRealm(__unsafe_unretained RLMObjectBase *object) {
    return object ? object->_realm : nil;
}

RLMObjectSchema *RLMObjectBaseObjectSchema(__unsafe_unretained RLMObjectBase *object) {
    return object ? object->_objectSchema : nil;
}

id RLMObjectBaseObjectForKeyedSubscript(RLMObjectBase *object, NSString *key) {
    if (!object) {
        return nil;
    }

    if (object->_realm) {
        return RLMDynamicGetByName(object, key);
    }
    else {
        return [object valueForKey:key];
    }
}

void RLMObjectBaseSetObjectForKeyedSubscript(RLMObjectBase *object, NSString *key, id obj) {
    if (!object) {
        return;
    }

    if (object->_realm || object.class == object->_objectSchema.accessorClass) {
        RLMDynamicValidatedSet(object, key, obj);
    }
    else {
        [object setValue:obj forKey:key];
    }
}


BOOL RLMObjectBaseAreEqual(RLMObjectBase *o1, RLMObjectBase *o2) {
    // if not the correct types throw
    if ((o1 && ![o1 isKindOfClass:RLMObjectBase.class]) || (o2 && ![o2 isKindOfClass:RLMObjectBase.class])) {
        @throw RLMException(@"Can only compare objects of class RLMObjectBase");
    }
    // if identical object (or both are nil)
    if (o1 == o2) {
        return YES;
    }
    // if one is nil
    if (o1 == nil || o2 == nil) {
        return NO;
    }
    // if not in realm or differing realms
    if (o1->_realm == nil || o1->_realm != o2->_realm) {
        return NO;
    }
    // if either are detached
    if (!o1->_row.is_valid() || !o2->_row.is_valid()) {
        return NO;
    }
    // if table and index are the same
    return o1->_row.get_table() == o2->_row.get_table()
        && o1->_row.get_key() == o2->_row.get_key();
}

id RLMObjectFreeze(RLMObjectBase *obj) {
    if (!obj->_realm && !obj.isInvalidated) {
        @throw RLMException(@"Unmanaged objects cannot be frozen.");
    }
    RLMVerifyAttached(obj);
    if (obj->_realm.frozen) {
        return obj;
    }
    RLMRealm *frozenRealm = [obj->_realm freeze];
    RLMObjectBase *frozen = RLMCreateManagedAccessor(obj.class, &frozenRealm->_info[obj->_info->rlmObjectSchema.className]);
    frozen->_row = frozenRealm->_realm->import_copy_of(obj->_row);
    if (!frozen->_row.is_valid()) {
        @throw RLMException(@"Cannot freeze an object in the same write transaction as it was created in.");
    }
    RLMInitializeSwiftAccessorGenerics(frozen);
    return frozen;
}

id RLMObjectThaw(RLMObjectBase *obj) {
    if (!obj->_realm && !obj.isInvalidated) {
        @throw RLMException(@"Unmanaged objects cannot be frozen.");
    }
    RLMVerifyAttached(obj);
    if (!obj->_realm.frozen) {
        return obj;
    }
    RLMRealm *liveRealm = [obj->_realm thaw];
    RLMObjectBase *live = RLMCreateManagedAccessor(obj.class, &liveRealm->_info[obj->_info->rlmObjectSchema.className]);
    live->_row = liveRealm->_realm->import_copy_of(obj->_row);
    if (!live->_row.is_valid()) {
        return nil;
    }
    RLMInitializeSwiftAccessorGenerics(live);
    return live;
}

id RLMValidatedValueForProperty(id object, NSString *key, NSString *className) {
    @try {
        return [object valueForKey:key];
    }
    @catch (NSException *e) {
        if ([e.name isEqualToString:NSUndefinedKeyException]) {
            @throw RLMException(@"Invalid value '%@' to initialize object of type '%@': missing key '%@'",
                                object, className, key);
        }
        @throw;
    }
}

#pragma mark - Notifications

namespace {
struct ObjectChangeCallbackWrapper {
    RLMObjectNotificationCallback block;
    RLMObjectBase *object;

    NSArray<NSString *> *propertyNames = nil;
    NSArray *oldValues = nil;
    bool deleted = false;

    void populateProperties(realm::CollectionChangeSet const& c) {
        if (propertyNames) {
            return;
        }
        if (!c.deletions.empty()) {
            deleted = true;
            return;
        }
        if (c.columns.empty()) {
            return;
        }

        auto properties = [NSMutableArray new];
        for (RLMProperty *property in object->_info->rlmObjectSchema.properties) {
            if (c.columns.count(object->_info->tableColumn(property).value)) {
                [properties addObject:property.name];
            }
        }
        if (properties.count) {
            propertyNames = properties;
        }
    }

    NSArray *readValues(realm::CollectionChangeSet const& c) {
        if (c.empty()) {
            return nil;
        }
        populateProperties(c);
        if (!propertyNames) {
            return nil;
        }

        auto values = [NSMutableArray arrayWithCapacity:propertyNames.count];
        for (NSString *name in propertyNames) {
            id value = [object valueForKey:name];
            if (!value || [value isKindOfClass:[RLMArray class]]) {
                [values addObject:NSNull.null];
            }
            else {
                [values addObject:value];
            }
        }
        return values;
    }

    void before(realm::CollectionChangeSet const& c) {
        @autoreleasepool {
            oldValues = readValues(c);
        }
    }

    void after(realm::CollectionChangeSet const& c) {
        @autoreleasepool {
            auto newValues = readValues(c);
            if (deleted) {
                block(nil, nil, nil, nil, nil);
            }
            else if (newValues) {
                block(object, propertyNames, oldValues, newValues, nil);
            }
            propertyNames = nil;
            oldValues = nil;
        }
    }

    void error(std::exception_ptr err) {
        @autoreleasepool {
            try {
                rethrow_exception(err);
            }
            catch (...) {
                NSError *error = nil;
                RLMRealmTranslateException(&error);
                block(nil, nil, nil, nil, error);
            }
        }
    }
};
} // anonymous namespace

@interface RLMPropertyChange ()
@property (nonatomic, readwrite, strong) NSString *name;
@property (nonatomic, readwrite, strong, nullable) id previousValue;
@property (nonatomic, readwrite, strong, nullable) id value;
@end

@implementation RLMPropertyChange
- (NSString *)description {
    return [NSString stringWithFormat:@"<RLMPropertyChange: %p> %@ %@ -> %@",
            (__bridge void *)self, _name, _previousValue, _value];
}
@end

@interface RLMObjectNotificationToken : RLMNotificationToken
@end

@implementation RLMObjectNotificationToken {
    std::mutex _mutex;
    __unsafe_unretained RLMRealm *_realm;
    realm::Object _object;
    realm::NotificationToken _token;
}

- (RLMRealm *)realm {
    return _realm;
}

- (void)suppressNextNotification {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_object.is_valid()) {
        _token.suppress_next();
    }
}

- (void)invalidate {
    std::lock_guard<std::mutex> lock(_mutex);
    _realm = nil;
    _token = {};
    _object = {};
}

- (void)addNotificationBlock:(RLMObjectNotificationCallback)block
         threadSafeReference:(RLMThreadSafeReference *)tsr
                      config:(RLMRealmConfiguration *)config
                       queue:(dispatch_queue_t)queue {
    std::lock_guard<std::mutex> lock(_mutex);
    if (!_realm) {
        // Token was invalidated before we got this far
        return;
    }

    NSError *error;
    RLMRealm *realm = _realm = [RLMRealm realmWithConfiguration:config queue:queue error:&error];
    if (!realm) {
        block(nil, nil, nil, nil, error);
        return;
    }
    RLMObjectBase *obj = [realm resolveThreadSafeReference:tsr];

    _object = realm::Object(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row);
    _token = _object.add_notification_callback(ObjectChangeCallbackWrapper{block, obj});
}

- (void)addNotificationBlock:(RLMObjectNotificationCallback)block object:(RLMObjectBase *)obj {
    _object = realm::Object(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row);
    _realm = obj->_realm;
    _token = _object.add_notification_callback(ObjectChangeCallbackWrapper{block, obj});
}

RLMNotificationToken *RLMObjectBaseAddNotificationBlock(RLMObjectBase *obj, dispatch_queue_t queue,
                                                        RLMObjectNotificationCallback block) {
    if (!obj->_realm) {
        @throw RLMException(@"Only objects which are managed by a Realm support change notifications");
    }

    if (!queue) {
        [obj->_realm verifyNotificationsAreSupported:true];
        auto token = [[RLMObjectNotificationToken alloc] init];
        token->_realm = obj->_realm;
        [token addNotificationBlock:block object:obj];
        return token;
    }

    RLMThreadSafeReference *tsr = [RLMThreadSafeReference referenceWithThreadConfined:(id)obj];
    auto token = [[RLMObjectNotificationToken alloc] init];
    token->_realm = obj->_realm;
    RLMRealmConfiguration *config = obj->_realm.configuration;
    dispatch_async(queue, ^{
        @autoreleasepool {
            [token addNotificationBlock:block threadSafeReference:tsr config:config queue:queue];
        }
    });
    return token;
}

@end

RLMNotificationToken *RLMObjectAddNotificationBlock(RLMObjectBase *obj, RLMObjectChangeBlock block, dispatch_queue_t queue) {
    return RLMObjectBaseAddNotificationBlock(obj, queue, ^(RLMObjectBase *, NSArray<NSString *> *propertyNames,
                                                           NSArray *oldValues, NSArray *newValues, NSError *error) {
        if (error) {
            block(false, nil, error);
        }
        else if (!propertyNames) {
            block(true, nil, nil);
        }
        else {
            auto properties = [NSMutableArray arrayWithCapacity:propertyNames.count];
            for (NSUInteger i = 0, count = propertyNames.count; i < count; ++i) {
                auto prop = [RLMPropertyChange new];
                prop.name = propertyNames[i];
                prop.previousValue = RLMCoerceToNil(oldValues[i]);
                prop.value = RLMCoerceToNil(newValues[i]);
                [properties addObject:prop];
            }
            block(false, properties, nil);
        }
    });
}

uint64_t RLMObjectBaseGetCombineId(__unsafe_unretained RLMObjectBase *const obj) {
    if (obj.invalidated) {
        RLMVerifyAttached(obj);
    }
    if (obj->_realm) {
        return obj->_row.get_key().value;
    }
    return reinterpret_cast<uint64_t>((__bridge void *)obj);
}

@implementation RealmSwiftObject
@end

@implementation RealmSwiftEmbeddedObject
@end
