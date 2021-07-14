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

#import "RLMEmbeddedObject.h"

#import "RLMObject_Private.hpp"
#import "RLMSchema_Private.h"

@implementation RLMEmbeddedObject
// synthesized in RLMObjectBase but redeclared here for documentation purposes
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

#pragma mark - Subscripting

- (id)objectForKeyedSubscript:(NSString *)key {
    return RLMObjectBaseObjectForKeyedSubscript(self, key);
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key {
    RLMObjectBaseSetObjectForKeyedSubscript(self, key, obj);
}

#pragma mark - Other Instance Methods

- (BOOL)isEqualToObject:(RLMObjectBase *)object {
    return [object isKindOfClass:RLMObjectBase.class] && RLMObjectBaseAreEqual(self, object);
}

- (instancetype)freeze {
    return RLMObjectFreeze(self);
}

- (instancetype)thaw {
    return RLMObjectThaw(self);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block {
    return RLMObjectAddNotificationBlock(self, nil, nil, block);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block queue:(dispatch_queue_t)queue {
    return RLMObjectAddNotificationBlock(self, nil, queue, block);
}

- (RLMNotificationToken *)addNotificationBlock:(RLMObjectChangeBlock)block keyPaths:(NSArray<NSString *> *)keyPaths {
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

+ (NSString *)primaryKey {
    return nil;
}

+ (NSArray *)indexedProperties {
    return @[];
}

+ (NSDictionary *)linkingObjectsProperties {
    return @{};
}

+ (NSDictionary *)defaultPropertyValues {
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

+ (bool)isEmbedded {
    return true;
}
@end
