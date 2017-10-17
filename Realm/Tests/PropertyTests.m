////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

#import "RLMTestCase.h"

#import "RLMObjectSchema_Private.h"
#import "RLMProperty_Private.h"
#import "RLMRealm_Dynamic.h"

#import <objc/runtime.h>

@interface PropertyTests : RLMTestCase
@end

@implementation PropertyTests

- (void)testDescription {
    AllTypesObject *object = [[AllTypesObject alloc] init];
    RLMProperty *property = object.objectSchema[@"objectCol"];

    XCTAssertEqualObjects(property.description, @"objectCol {\n"
                                                @"\ttype = object;\n"
                                                @"\tobjectClassName = StringObject;\n"
                                                @"\tlinkOriginPropertyName = (null);\n"
                                                @"\tindexed = NO;\n"
                                                @"\tisPrimary = NO;\n"
                                                @"\tarray = NO;\n"
                                                @"\toptional = YES;\n"
                                                @"}");
}

- (void)testEqualityFromObjectSchema {
    { // Test non-optional property types
        RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:[AllTypesObject class]];
        NSDictionary *expectedProperties = @{
            @"boolCol":   [[RLMProperty alloc] initWithName:@"boolCol"    type:RLMPropertyTypeBool   objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"intCol":    [[RLMProperty alloc] initWithName:@"intCol"     type:RLMPropertyTypeInt    objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"floatCol":  [[RLMProperty alloc] initWithName:@"floatCol"   type:RLMPropertyTypeFloat  objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"doubleCol": [[RLMProperty alloc] initWithName:@"doubleCol"  type:RLMPropertyTypeDouble objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"stringCol": [[RLMProperty alloc] initWithName:@"stringCol"  type:RLMPropertyTypeString objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"binaryCol": [[RLMProperty alloc] initWithName:@"binaryCol"  type:RLMPropertyTypeData   objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"dateCol":   [[RLMProperty alloc] initWithName:@"dateCol"    type:RLMPropertyTypeDate   objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"cBoolCol":  [[RLMProperty alloc] initWithName:@"cBoolCol"   type:RLMPropertyTypeBool   objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"longCol":   [[RLMProperty alloc] initWithName:@"longCol"    type:RLMPropertyTypeInt    objectClassName:nil             linkOriginPropertyName:nil indexed:NO optional:NO],
            @"objectCol": [[RLMProperty alloc] initWithName:@"objectCol"  type:RLMPropertyTypeObject objectClassName:@"StringObject" linkOriginPropertyName:nil indexed:NO optional:YES],
            @"realmIntCol": [[RLMProperty alloc] initWithName:@"realmIntCol"  type:RLMPropertyTypeInt objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:NO],
            @"realmNullableIntCol": [[RLMProperty alloc] initWithName:@"realmNullableIntCol"  type:RLMPropertyTypeInt objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
        };
        XCTAssertEqual(objectSchema.properties.count, expectedProperties.allKeys.count);
        for (NSString *propertyName in expectedProperties) {
            XCTAssertEqualObjects(objectSchema[propertyName], expectedProperties[propertyName]);
        }
    }
    { // Test optional property types
        RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:[AllOptionalTypes class]];
        NSDictionary *expectedProperties = @{
            @"intObj":    [[RLMProperty alloc] initWithName:@"intObj"    type:RLMPropertyTypeInt    objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
            @"floatObj":  [[RLMProperty alloc] initWithName:@"floatObj"  type:RLMPropertyTypeFloat  objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
            @"doubleObj": [[RLMProperty alloc] initWithName:@"doubleObj" type:RLMPropertyTypeDouble objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
            @"boolObj":   [[RLMProperty alloc] initWithName:@"boolObj"   type:RLMPropertyTypeBool   objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
            @"string":    [[RLMProperty alloc] initWithName:@"string"    type:RLMPropertyTypeString objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
            @"data":      [[RLMProperty alloc] initWithName:@"data"      type:RLMPropertyTypeData   objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
            @"date":      [[RLMProperty alloc] initWithName:@"date"      type:RLMPropertyTypeDate   objectClassName:nil linkOriginPropertyName:nil indexed:NO optional:YES],
        };
        XCTAssertEqual(objectSchema.properties.count, expectedProperties.allKeys.count);
        for (NSString *propertyName in expectedProperties) {
            XCTAssertEqualObjects(objectSchema[propertyName], expectedProperties[propertyName]);
        }
    }
    { // Test indexed property
        RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:[IndexedStringObject class]];
        RLMProperty *stringProperty = objectSchema[@"stringCol"];
        RLMProperty *expectedProperty = [[RLMProperty alloc] initWithName:@"stringCol" type:RLMPropertyTypeString objectClassName:nil linkOriginPropertyName:nil indexed:YES optional:YES];
        XCTAssertEqualObjects(stringProperty, expectedProperty);
    }
    { // Test primary key property
        RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:[PrimaryStringObject class]];
        RLMProperty *stringProperty = objectSchema[@"stringCol"];
        RLMProperty *expectedProperty = [[RLMProperty alloc] initWithName:@"stringCol"
                                                                     type:RLMPropertyTypeString
                                                          objectClassName:nil
                                                   linkOriginPropertyName:nil
                                                                  indexed:YES
                                                                 optional:NO];
        expectedProperty.isPrimary = YES;
        XCTAssertEqualObjects(stringProperty, expectedProperty);
    }
}

- (void)testTwoPropertiesAreEqual {
    Class dummyClass = [self class];
    const char *name = "intCol";
    objc_property_t objcProperty1 = class_getProperty(AllTypesObject.class, name);
    RLMProperty *property1 = [[RLMProperty alloc] initWithName:@(name) objectClass:dummyClass indexed:YES
                                        linkPropertyDescriptor:nil property:objcProperty1];

    objc_property_t objcProperty2 = class_getProperty(IntObject.class, name);
    RLMProperty *property2 = [[RLMProperty alloc] initWithName:@(name) objectClass:dummyClass indexed:YES
                                        linkPropertyDescriptor:nil property:objcProperty2];

    XCTAssertEqualObjects(property1, property2);
}

- (void)testTwoPropertiesAreUnequal {
    Class dummyClass = [self class];
    const char *name = "stringCol";
    objc_property_t objcProperty1 = class_getProperty(AllTypesObject.class, name);
    RLMProperty *property1 = [[RLMProperty alloc] initWithName:@(name) objectClass:dummyClass indexed:YES
                                        linkPropertyDescriptor:nil property:objcProperty1];

    name = "intCol";
    objc_property_t objcProperty2 = class_getProperty(IntObject.class, name);
    RLMProperty *property2 = [[RLMProperty alloc] initWithName:@(name) objectClass:dummyClass indexed:YES
                                        linkPropertyDescriptor:nil property:objcProperty2];

    XCTAssertNotEqualObjects(property1, property2);
}

- (void)testSwiftPropertyNameValidation {
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"alloc"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"_alloc"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"allocOject"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"_allocOject"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"alloc_object"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"_alloc_object"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"new"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"copy"));
    RLMAssertThrows(RLMValidateSwiftPropertyName(@"mutableCopy"));

    // Swift doesn't infer family from `init`
    XCTAssertNoThrow(RLMValidateSwiftPropertyName(@"init"));
    XCTAssertNoThrow(RLMValidateSwiftPropertyName(@"_init"));
    XCTAssertNoThrow(RLMValidateSwiftPropertyName(@"initWithValue"));

    // Lowercase letter after family name
    XCTAssertNoThrow(RLMValidateSwiftPropertyName(@"allocate"));

    XCTAssertNoThrow(RLMValidateSwiftPropertyName(@"__alloc"));
}

- (void)testTypeToString {
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeString),   @"string");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeInt),      @"int");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeBool),     @"bool");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeDate),     @"date");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeData),     @"data");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeDouble),   @"double");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeFloat),    @"float");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeObject),   @"object");
    XCTAssertEqualObjects(RLMTypeToString(RLMPropertyTypeLinkingObjects), @"linking objects");

    XCTAssertEqualObjects(RLMTypeToString((RLMPropertyType)-1),     @"Unknown");
}

@end
