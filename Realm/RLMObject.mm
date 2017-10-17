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
#import "RLMArray.h"
#import "RLMCollection_Private.hpp"
#import "RLMObjectBase_Private.h"
#import "RLMInteger.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMProperty.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"

#import "collection_notifications.hpp"
#import "object.hpp"

@interface RLMPropertyChange ()
@property (nonatomic, readwrite, strong) NSString *name;
@property (nonatomic, readwrite, strong, nullable) id previousValue;
@property (nonatomic, readwrite, strong, nullable) id value;
@end

// We declare things in RLMObject which are actually implemented in RLMObjectBase
// for documentation's sake, which leads to -Wunimplemented-method warnings.
// Other alternatives to this would be to disable -Wunimplemented-method for this
// file (but then we could miss legitimately missing things), or declaring the
// inherited things in a category (but they currently aren't nicely grouped for
// that).
@implementation RLMObject

// synthesized in RLMObjectBase
@dynamic invalidated, realm, objectSchema;

#pragma mark - Designated Initializers

- (instancetype)init {
    return [super init];
}

- (instancetype)initWithValue:(id)value schema:(RLMSchema *)schema {
    return [super initWithValue:value schema:schema];
}

- (instancetype)initWithRealm:(__unsafe_unretained RLMRealm *const)realm schema:(RLMObjectSchema *)schema {
    return [super initWithRealm:realm schema:schema];
}

#pragma mark - Convenience Initializers

- (instancetype)initWithValue:(id)value {
    return [super initWithValue:value schema:RLMSchema.partialPrivateSharedSchema];
}

#pragma mark - Class-based Object Creation

+ (instancetype)createInDefaultRealmWithValue:(id)value {
    return (RLMObject *)RLMCreateObjectInRealmWithValue([RLMRealm defaultRealm], [self className], value, false);
}

+ (instancetype)createInRealm:(RLMRealm *)realm withValue:(id)value {
    return (RLMObject *)RLMCreateObjectInRealmWithValue(realm, [self className], value, false);
}

+ (instancetype)createOrUpdateInDefaultRealmWithValue:(id)value {
    return [self createOrUpdateInRealm:[RLMRealm defaultRealm] withValue:value];
}

+ (instancetype)createOrUpdateInRealm:(RLMRealm *)realm withValue:(id)value {
    // verify primary key
    RLMObjectSchema *schema = [self sharedSchema];
    if (!schema.primaryKeyProperty) {
        NSString *reason = [NSString stringWithFormat:@"'%@' does not have a primary key and can not be updated", schema.className];
        @throw [NSException exceptionWithName:@"RLMExecption" reason:reason userInfo:nil];
    }
    return (RLMObject *)RLMCreateObjectInRealmWithValue(realm, [self className], value, true);
}

#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
    return RLMObjectBaseObjectForKeyedSubscript(self, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {
    RLMObjectBaseSetObjectForKeyedSubscript(self, key, obj);
}

#pragma mark - Getting & Querying

+ (RLMResults *)allObjects {
    return RLMGetObjects(RLMRealm.defaultRealm, self.className, nil);
}

+ (RLMResults *)allObjectsInRealm:(__unsafe_unretained RLMRealm *const)realm {
    return RLMGetObjects(realm, self.className, nil);
}

+ (RLMResults *)objectsWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

+ (RLMResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

+ (RLMResults *)objectsInRealm:(RLMRealm *)realm where:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objectsInRealm:realm where:predicateFormat args:args];
    va_end(args);
    return results;
}

+ (RLMResults *)objectsInRealm:(RLMRealm *)realm where:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsInRealm:realm withPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

+ (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    return RLMGetObjects(RLMRealm.defaultRealm, self.className, predicate);
}

+ (RLMResults *)objectsInRealm:(RLMRealm *)realm withPredicate:(NSPredicate *)predicate {
    return RLMGetObjects(realm, self.className, predicate);
}

+ (instancetype)objectForPrimaryKey:(id)primaryKey {
    return RLMGetObject(RLMRealm.defaultRealm, self.className, primaryKey);
}

+ (instancetype)objectInRealm:(RLMRealm *)realm forPrimaryKey:(id)primaryKey {
    return RLMGetObject(realm, self.className, primaryKey);
}

#pragma mark - Other Instance Methods

- (BOOL)isEqualToObject:(RLMObject *)object {
    return [object isKindOfClass:RLMObject.class] && RLMObjectBaseAreEqual(self, object);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block {
    return RLMObjectAddNotificationBlock(self, ^(NSArray<NSString *> *propertyNames,
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

+ (NSString *)className {
    return [super className];
}

#pragma mark - Default values for schema definition

+ (NSArray *)indexedProperties {
    return @[];
}

+ (NSDictionary *)linkingObjectsProperties {
    return @{};
}

+ (NSDictionary *)defaultPropertyValues {
    return nil;
}

+ (NSString *)primaryKey {
    return nil;
}

+ (NSArray *)ignoredProperties {
    return nil;
}

+ (NSArray *)requiredProperties {
    return @[];
}

@end

@implementation RLMDynamicObject

+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}

- (id)valueForUndefinedKey:(NSString *)key {
    return RLMDynamicGetByName(self, key, false);
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    RLMDynamicValidatedSet(self, key, value);
}

- (void)incrementValueOfIntegerProperty:(NSString *)propertyName byValue:(NSInteger)delta {
    RLMDynamicIntegerAdd(self, propertyName, delta);
}

@end

@implementation RLMWeakObjectHandle {
    realm::Row _row;
    RLMClassInfo *_info;
    Class _objectClass;
}

- (instancetype)initWithObject:(RLMObjectBase *)object {
    if (!(self = [super init])) {
        return nil;
    }

    _row = object->_row;
    _info = object->_info;
    _objectClass = object.class;

    return self;
}

- (RLMObjectBase *)object {
    RLMObjectBase *object = RLMCreateManagedAccessor(_objectClass, _info->realm, _info);
    object->_row = std::move(_row);
    return object;
}

- (id)copyWithZone:(__unused NSZone *)zone {
    RLMWeakObjectHandle *copy = [[RLMWeakObjectHandle alloc] init];
    copy->_row = _row;
    copy->_info = _info;
    copy->_objectClass = _objectClass;
    return copy;
}

@end

static bool treatFakeObjectAsRLMObject = false;
void RLMSetTreatFakeObjectAsRLMObject(BOOL flag) {
    treatFakeObjectAsRLMObject = flag;
}

BOOL RLMIsObjectOrSubclass(Class klass) {
    if (RLMIsKindOfClass(klass, RLMObjectBase.class)) {
        return YES;
    }

    if (treatFakeObjectAsRLMObject) {
        static Class FakeObjectClass = NSClassFromString(@"FakeObject");
        return RLMIsKindOfClass(klass, FakeObjectClass);
    }
    return NO;
}

BOOL RLMIsObjectSubclass(Class klass) {
    auto isSubclass = [](Class class1, Class class2) {
        class1 = class_getSuperclass(class1);
        return RLMIsKindOfClass(class1, class2);
    };
    if (isSubclass(class_getSuperclass(klass), RLMObjectBase.class)) {
        return YES;
    }

    if (treatFakeObjectAsRLMObject) {
        static Class FakeObjectClass = NSClassFromString(@"FakeObject");
        return isSubclass(klass, FakeObjectClass);
    }
    return NO;
}

@interface RLMObjectNotificationToken : RLMCancellationToken
@end
@implementation RLMObjectNotificationToken {
@public
    realm::Object _object;
}
@end

RLMNotificationToken *RLMObjectAddNotificationBlock(RLMObjectBase *obj, RLMObjectNotificationCallback block) {
    if (!obj->_realm) {
        @throw RLMException(@"Only objects which are managed by a Realm support change notifications");
    }
    [obj->_realm verifyNotificationsAreSupported:true];

    struct {
        void (^block)(NSArray<NSString *> *, NSArray *, NSArray *, NSError *);
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
            for (size_t i = 0; i < c.columns.size(); ++i) {
                if (c.columns[i].empty()) {
                    continue;
                }
                if (auto prop = object->_info->propertyForTableColumn(i)) {
                    [properties addObject:prop.name];
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
                else if (RLMInteger *v = RLMDynamicCast<RLMInteger>(value)) {
                    [values addObject:([v value] ?: NSNull.null)];
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
                    block(nil, nil, nil, nil);
                }
                else if (newValues) {
                    block(propertyNames, oldValues, newValues, nil);
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
                    block(nil, nil, nil, error);
                }
            }
        }
    } callback{block, obj};

    realm::Object object(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row);
    auto token = [[RLMObjectNotificationToken alloc] initWithToken:object.add_notification_callback(callback) realm:obj->_realm];
    token->_object = std::move(object);
    return token;
}

@implementation RLMPropertyChange
@end
