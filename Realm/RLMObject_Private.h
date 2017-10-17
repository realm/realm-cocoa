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

#import <Realm/RLMObjectBase_Dynamic.h>

#import <Realm/RLMMigration.h>

NS_ASSUME_NONNULL_BEGIN

// RLMObject accessor and read/write realm
@interface RLMObjectBase () {
@public
    RLMRealm *_realm;
    __unsafe_unretained RLMObjectSchema *_objectSchema;
}

// unmanaged initializer
- (instancetype)initWithValue:(id)value schema:(RLMSchema *)schema NS_DESIGNATED_INITIALIZER;

// live accessor initializer
- (instancetype)initWithRealm:(__unsafe_unretained RLMRealm *const)realm
                       schema:(RLMObjectSchema *)schema NS_DESIGNATED_INITIALIZER;

// shared schema for this class
+ (nullable RLMObjectSchema *)sharedSchema;

// provide injection point for alternative Swift object util class
+ (Class)objectUtilClass:(BOOL)isSwift;

@end

@interface RLMObject ()

// unmanaged initializer
- (instancetype)initWithValue:(id)value schema:(RLMSchema *)schema NS_DESIGNATED_INITIALIZER;

// live accessor initializer
- (instancetype)initWithRealm:(__unsafe_unretained RLMRealm *const)realm
                       schema:(RLMObjectSchema *)schema NS_DESIGNATED_INITIALIZER;

@end

@interface RLMDynamicObject : RLMObject<RLMObjectMigrationProtocol>

@end

// A reference to an object's row that doesn't keep the object accessor alive.
// Used by some Swift property types, such as LinkingObjects, to avoid retain cycles
// with their containing object.
@interface RLMWeakObjectHandle : NSObject<NSCopying>

- (instancetype)initWithObject:(RLMObjectBase *)object;

// Consumes the row, so can only usefully be called once.
@property (nonatomic, readonly) RLMObjectBase *object;

@end

// Calls valueForKey: and re-raises NSUndefinedKeyExceptions
FOUNDATION_EXTERN id _Nullable RLMValidatedValueForProperty(id object, NSString *key, NSString *className);

// Compare two RLObjectBases
FOUNDATION_EXTERN BOOL RLMObjectBaseAreEqual(RLMObjectBase * _Nullable o1, RLMObjectBase * _Nullable o2);

typedef void (^RLMObjectNotificationCallback)(NSArray<NSString *> *_Nullable propertyNames,
                                              NSArray *_Nullable oldValues,
                                              NSArray *_Nullable newValues,
                                              NSError *_Nullable error);
FOUNDATION_EXTERN RLMNotificationToken *RLMObjectAddNotificationBlock(RLMObjectBase *obj, RLMObjectNotificationCallback block);

// Returns whether the class is a descendent of RLMObjectBase
FOUNDATION_EXTERN BOOL RLMIsObjectOrSubclass(Class klass);

// Returns whether the class is an indirect descendant of RLMObjectBase
FOUNDATION_EXTERN BOOL RLMIsObjectSubclass(Class klass);

// For unit testing purposes, allow an Objective-C class named FakeObject to also be used
// as the base class of managed objects. This allows for testing invalid schemas.
FOUNDATION_EXTERN void RLMSetTreatFakeObjectAsRLMObject(BOOL flag);

// Get ObjectUil class for objc or swift
FOUNDATION_EXTERN Class RLMObjectUtilClass(BOOL isSwift);

FOUNDATION_EXTERN const NSUInteger RLMDescriptionMaxDepth;

@class RLMProperty, RLMArray, RLMGenericPropertyMetadata;
@interface RLMObjectUtil : NSObject

+ (nullable NSArray<NSString *> *)ignoredPropertiesForClass:(Class)cls;
+ (nullable NSArray<NSString *> *)indexedPropertiesForClass:(Class)cls;
+ (nullable NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)linkingObjectsPropertiesForClass:(Class)cls;

// Precondition: these must be returned in ascending order.
+ (nullable NSArray<RLMGenericPropertyMetadata *> *)getSwiftGenericProperties:(id)obj;

+ (nullable NSDictionary<NSString *, NSNumber *> *)getOptionalProperties:(id)obj;
+ (nullable NSArray<NSString *> *)requiredPropertiesForClass:(Class)cls;

@end

typedef NS_ENUM(NSUInteger, RLMGenericPropertyKind) {
    RLMGenericPropertyKindList,
    RLMGenericPropertyKindLinkingObjects,
    RLMGenericPropertyKindOptional,
    RLMGenericPropertyKindNilLiteralOptional,   // For Swift optional properties that reflect as nil
};

// Metadata that describes a Swift generic property.
@interface RLMGenericPropertyMetadata : NSObject

@property (nonatomic, strong) NSString *propertyName;
@property (nullable, nonatomic, strong) NSString *className;
@property (nullable, nonatomic, strong) NSString *linkedPropertyName;
@property (nonatomic) NSInteger index;
@property (nonatomic) NSInteger propertyType;
@property (nonatomic) RLMGenericPropertyKind kind;

+ (instancetype)metadataForListProperty:(NSString *)propertyName index:(NSInteger)index;

+ (instancetype)metadataForLinkingObjectsProperty:(NSString *)propertyName
                                        className:(NSString *)className
                               linkedPropertyName:(NSString *)linkedPropertyName
                                            index:(NSInteger)index;

+ (instancetype)metadataForOptionalProperty:(NSString *)propertyName type:(NSInteger)type index:(NSInteger)index;

+ (instancetype)metadataForNilLiteralOptionalProperty:(NSString *)propertyName index:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
