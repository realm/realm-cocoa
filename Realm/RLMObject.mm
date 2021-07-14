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
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"

#import <realm/object-store/object.hpp>

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

#pragma mark - Convenience Initializers

- (instancetype)initWithValue:(id)value {
    if (!(self = [self init])) {
        return nil;
    }
    RLMInitializeWithValue(self, value, RLMSchema.partialPrivateSharedSchema);
    return self;
}

#pragma mark - Class-based Object Creation

+ (instancetype)createInDefaultRealmWithValue:(id)value {
    return (RLMObject *)RLMCreateObjectInRealmWithValue([RLMRealm defaultRealm], [self className], value, RLMUpdatePolicyError);
}

+ (instancetype)createInRealm:(RLMRealm *)realm withValue:(id)value {
    return (RLMObject *)RLMCreateObjectInRealmWithValue(realm, [self className], value, RLMUpdatePolicyError);
}

+ (instancetype)createOrUpdateInDefaultRealmWithValue:(id)value {
    return [self createOrUpdateInRealm:[RLMRealm defaultRealm] withValue:value];
}

+ (instancetype)createOrUpdateModifiedInDefaultRealmWithValue:(id)value {
    return [self createOrUpdateModifiedInRealm:[RLMRealm defaultRealm] withValue:value];
}

+ (instancetype)createOrUpdateInRealm:(RLMRealm *)realm withValue:(id)value {
    RLMVerifyHasPrimaryKey(self);
    return (RLMObject *)RLMCreateObjectInRealmWithValue(realm, [self className], value, RLMUpdatePolicyUpdateAll);
}

+ (instancetype)createOrUpdateModifiedInRealm:(RLMRealm *)realm withValue:(id)value {
    RLMVerifyHasPrimaryKey(self);
    return (RLMObject *)RLMCreateObjectInRealmWithValue(realm, [self className], value, RLMUpdatePolicyUpdateChanged);
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

- (instancetype)freeze {
    return RLMObjectFreeze(self);
}

- (instancetype)thaw {
    return RLMObjectThaw(self);
}

- (BOOL)isFrozen {
    return _realm.isFrozen;
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block {
    return RLMObjectAddNotificationBlock(self, nil, nil, block);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block
                                         queue:(nonnull dispatch_queue_t)queue {
    return RLMObjectAddNotificationBlock(self, nil, queue, block);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block
                                      keyPaths:(NSArray<NSString *> *)keyPaths {
    return RLMObjectAddNotificationBlock(self, keyPaths, nil, block);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block
                                      keyPaths:(NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return RLMObjectAddNotificationBlock(self, keyPaths, queue, block);

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

+ (bool)_realmIgnoreClass {
    return false;
}

@end

@implementation RLMDynamicObject

+ (bool)_realmIgnoreClass {
    return true;
}

+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}

- (id)valueForUndefinedKey:(NSString *)key {
    return RLMDynamicGetByName(self, key);
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    RLMDynamicValidatedSet(self, key, value);
}

+ (RLMObjectSchema *)sharedSchema {
    return nil;
}

@end

BOOL RLMIsObjectOrSubclass(Class klass) {
    return RLMIsKindOfClass(klass, RLMObjectBase.class);
}

BOOL RLMIsObjectSubclass(Class klass) {
    return RLMIsKindOfClass(class_getSuperclass(class_getSuperclass(klass)), RLMObjectBase.class);
}
