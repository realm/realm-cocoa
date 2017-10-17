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

#import "RLMTestObjects.h"
#import <Realm/RLMObject_Private.h>

#pragma mark - Abstract Objects
#pragma mark -

#pragma mark OneTypeObjects

@implementation StringObject
@end

@implementation IntObject
@end

@implementation RealmIntObject

+ (NSArray *)requiredProperties {
    return @[@"realmInt"];
}

@end

@implementation RealmNullableIntObject
@end

@implementation AllIntSizesObject
@end

@implementation FloatObject
@end

@implementation DoubleObject
@end

@implementation BoolObject
@end

@implementation DateObject
@end

@implementation BinaryObject
@end

@implementation UTF8Object
@end

@implementation IndexedStringObject
+ (NSArray *)indexedProperties {
    return @[@"stringCol"];
}
@end

@implementation LinkStringObject
@end

@implementation LinkIndexedStringObject
@end

@implementation RequiredPropertiesObject
+ (NSArray *)requiredProperties {
    return @[@"stringCol", @"binaryCol"];
}
@end

@implementation IgnoredURLObject
+ (NSArray *)ignoredProperties {
    return @[@"url"];
}
@end

#pragma mark AllTypesObject

@implementation AllTypesObject
+ (NSDictionary *)linkingObjectsProperties
{
    return @{ @"linkingObjectsCol": [RLMPropertyDescriptor descriptorWithClass:LinkToAllTypesObject.class propertyName:@"allTypesCol"] };
}
+ (NSArray *)requiredProperties
{
    return @[@"stringCol", @"dateCol", @"binaryCol", @"realmIntCol"];
}
@end

@implementation ArrayOfAllTypesObject
@end

@implementation LinkToAllTypesObject
@end

@implementation AllOptionalTypes
@end
@implementation AllPrimitiveArrays
+ (NSArray *)requiredProperties {
    return @[@"intObj", @"floatObj", @"doubleObj", @"boolObj", @"stringObj", @"dateObj", @"dataObj"];
}
@end
@implementation AllOptionalPrimitiveArrays
@end

@implementation AllOptionalTypesPK
+ (NSString *)primaryKey {
    return @"pk";
}
+ (NSDictionary *)defaultPropertyValues {
    return @{@"pk": NSUUID.UUID.UUIDString};
}
@end

#pragma mark - Real Life Objects
#pragma mark -

#pragma mark EmployeeObject

@implementation EmployeeObject
@end

#pragma mark CompanyObject

@implementation CompanyObject
@end

@implementation PrimaryEmployeeObject
+ (NSString *)primaryKey {
    return @"name";
}
@end

@implementation LinkToPrimaryEmployeeObject
@end

@implementation PrimaryCompanyObject
+ (NSString *)primaryKey {
    return @"name";
}
@end

@implementation ArrayOfPrimaryCompanies
@end

#pragma mark LinkToCompanyObject

@implementation LinkToCompanyObject
@end

#pragma mark DogObject

@class OwnerObject;

@implementation DogObject
+ (NSDictionary *)linkingObjectsProperties
{
    return @{ @"owners": [RLMPropertyDescriptor descriptorWithClass:OwnerObject.class propertyName:@"dog"] };
}
@end

#pragma mark OwnerObject

@implementation OwnerObject

- (BOOL)isEqual:(id)other
{
    return [self isEqualToObject:other];
}

@end

#pragma mark - Specific Use Objects
#pragma mark -

#pragma mark CustomAccessorsObject

@implementation CustomAccessorsObject
@end

#pragma mark BaseClassStringObject

@implementation BaseClassStringObject
@end

#pragma mark CircleObject

@implementation CircleObject
@end

#pragma mark CircleArrayObject

@implementation CircleArrayObject
@end

#pragma mark ArrayPropertyObject

@implementation ArrayPropertyObject
@end

#pragma mark DynamicObject

@implementation DynamicObject
@end

#pragma mark AggregateObject

@implementation AggregateObject
@end
@implementation AggregateArrayObject
@end

#pragma mark PrimaryStringObject

@implementation PrimaryStringObject
+ (NSString *)primaryKey {
    return @"stringCol";
}
+ (NSArray *)requiredProperties {
    return @[@"stringCol"];
}
@end

@implementation PrimaryNullableStringObject
+ (NSString *)primaryKey {
    return @"stringCol";
}
@end

@implementation PrimaryIntObject
+ (NSString *)primaryKey {
    return @"intCol";
}
@end

@implementation PrimaryInt64Object
+ (NSString *)primaryKey {
    return @"int64Col";
}
@end

@implementation PrimaryNullableIntObject
+ (NSString *)primaryKey {
    return @"optIntCol";
}
@end


#pragma mark ReadOnlyPropertyObject

@interface ReadOnlyPropertyObject ()
@property (readwrite) int readOnlyPropertyMadeReadWriteInClassExtension;
@end

@implementation ReadOnlyPropertyObject
- (NSNumber *)readOnlyUnsupportedProperty {
    return nil;
}
@end

#pragma mark IntegerArrayPropertyObject

@implementation IntegerArrayPropertyObject
@end

@implementation NumberObject
@end

@implementation NumberDefaultsObject
+ (NSDictionary *)defaultPropertyValues {
    return @{@"intObj" : @1,
             @"floatObj" : @2.2f,
             @"doubleObj" : @3.3,
             @"boolObj" : @NO};
}
@end

@implementation RequiredNumberObject
+ (NSArray *)requiredProperties {
    return @[@"intObj", @"floatObj", @"doubleObj", @"boolObj"];
}
@end

#pragma mark CustomInitializerObject

@implementation CustomInitializerObject

- (instancetype)init {
    self = [super init];
    if (self) {
        self.stringCol = @"test";
    }
    return self;
}

@end

#pragma mark AbstractObject

@implementation AbstractObject
@end

#pragma mark PersonObject

@implementation PersonObject

+ (NSDictionary *)linkingObjectsProperties
{
    return @{ @"parents": [RLMPropertyDescriptor descriptorWithClass:PersonObject.class propertyName:@"children"] };
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass:[PersonObject class]]) {
        return NO;
    }

    PersonObject *otherPerson = other;
    return [self.name isEqual:otherPerson.name] && self.age == otherPerson.age && [self.children isEqual:otherPerson.children];
}

@end



#pragma mark FakeObject

@implementation FakeObject
+ (Class)objectUtilClass:(BOOL)isSwift { return RLMObjectUtilClass(isSwift); }
+ (NSArray *)ignoredProperties { return nil; }
+ (NSArray *)indexedProperties { return nil; }
+ (NSString *)primaryKey { return nil; }
+ (NSArray *)requiredProperties { return nil; }
+ (NSDictionary *)linkingObjectsProperties { return nil; }
+ (BOOL)shouldIncludeInDefaultSchema { return NO; }
+ (NSString *)_realmObjectName { return nil; }
@end

#pragma mark ComputedPropertyNotExplicitlyIgnoredObject

@implementation ComputedPropertyNotExplicitlyIgnoredObject

- (NSURL *)URL {
    return [NSURL URLWithString:self._URLBacking];
}

- (void)setURL:(NSURL *)URL {
    self._URLBacking = URL.absoluteString;
}

@end
