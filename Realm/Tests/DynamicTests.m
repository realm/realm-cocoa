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

#import "RLMTestCase.h"
#import "RLMRealm_Dynamic.h"
#import "RLMRealm_Private.h"
#import "RLMProperty_Private.h"
#import "RLMObjectSchema_Private.h"
#import "RLMSchema_Private.h"

@interface DynamicTests : RLMTestCase
@end

@implementation DynamicTests

#pragma mark - Tests

- (void)testDynamicRealmExists {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        RLMRealm *realm = [RLMRealm realmWithURL:RLMTestRealmURL()];
        [realm beginWriteTransaction];
        [DynamicObject createInRealm:realm withValue:@[@"column1", @1]];
        [DynamicObject createInRealm:realm withValue:@[@"column2", @2]];
        [realm commitWriteTransaction];
    }

    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:nil];
    XCTAssertNotNil(dyrealm, @"realm should not be nil");

    // verify schema
    RLMObjectSchema *dynSchema = dyrealm.schema[@"DynamicObject"];
    XCTAssertNotNil(dynSchema, @"Should be able to get object schema dynamically");
    XCTAssertEqual(dynSchema.properties.count, (NSUInteger)2, @"DynamicObject should have 2 properties");
    XCTAssertEqualObjects([dynSchema.properties[0] name], @"stringCol", @"Invalid property name");
    XCTAssertEqual([(RLMProperty *)dynSchema.properties[1] type], RLMPropertyTypeInt, @"Invalid type");

    // verify object type
    RLMResults *results = [dyrealm allObjects:@"DynamicObject"];
    XCTAssertEqual(results.count, (NSUInteger)2, @"Array should have 2 elements");
    XCTAssertNotEqual(results.objectClassName, DynamicObject.className,
                      @"Array class should by a dynamic object class");
}

- (void)testDynamicObjectRetrieval {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        RLMRealm *realm = [self realmWithTestPath];
        [realm beginWriteTransaction];
        [PrimaryStringObject createInRealm:realm withValue:@[@"key", @1]];
        [realm commitWriteTransaction];
    }

    RLMRealm *testRealm = [self realmWithTestPath];

    RLMObject *object = [testRealm objectWithClassName:@"PrimaryStringObject" forPrimaryKey:@"key"];

    XCTAssertNotNil(object, @"Should be able to retrieve object by primary key dynamically");
    XCTAssert([[object valueForKey:@"stringCol"] isEqualToString:@"key"],@"stringCol should equal 'key'");
    XCTAssert([[[object class] className] isEqualToString:@"PrimaryStringObject"],@"Object class name should equal 'PrimaryStringObject'");
    XCTAssert([object isKindOfClass:[PrimaryStringObject class]], @"Object should be of class 'PrimaryStringObject'");
}

- (void)testDynamicSchemaMatchesRegularSchema {
    RLMSchema *expectedSchema = nil;
    // Force create and close realm
    @autoreleasepool {
        RLMRealm *realm = self.realmWithTestPath;
        expectedSchema = realm.schema;
    }
    XCTAssertNotNil(expectedSchema);

    RLMRealmConfiguration *config = [RLMRealmConfiguration new];
    config.fileURL = RLMTestRealmURL();
    config.dynamic = YES;

    NSError *error = nil;
    RLMSchema *dynamicSchema = [[RLMRealm realmWithConfiguration:config error:&error] schema];
    XCTAssertNil(error);
    XCTAssertEqual(dynamicSchema.objectSchema.count, expectedSchema.objectSchema.count);
    for (RLMObjectSchema *expectedObjectSchema in expectedSchema.objectSchema) {
        RLMObjectSchema *dynamicObjectSchema = dynamicSchema[expectedObjectSchema.className];
        XCTAssertEqual(dynamicObjectSchema.properties.count, expectedObjectSchema.properties.count);
        for (NSUInteger propertyIndex = 0; propertyIndex < expectedObjectSchema.properties.count; propertyIndex++) {
            RLMProperty *dynamicProperty = dynamicObjectSchema.properties[propertyIndex];
            RLMProperty *expectedProperty = expectedObjectSchema.properties[propertyIndex];
            XCTAssertEqualObjects(dynamicProperty, expectedProperty);
        }
    }
}

- (void)testDynamicSchema {
    RLMSchema *schema = [[RLMSchema alloc] init];
    RLMProperty *prop = [[RLMProperty alloc] initWithName:@"a"
                                                     type:RLMPropertyTypeInt
                                          objectClassName:nil
                                   linkOriginPropertyName:nil
                                                  indexed:NO
                                                 optional:NO];
    RLMObjectSchema *objectSchema = [[RLMObjectSchema alloc] initWithClassName:@"TrulyDynamicObject"
                                                                   objectClass:RLMObject.class
                                                                    properties:@[prop]];
    schema.objectSchema = @[objectSchema];
    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:schema];
    XCTAssertNotNil(dyrealm, @"dynamic realm shouldn't be nil");
}

- (void)testDynamicProperties {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        RLMRealm *realm = [RLMRealm realmWithURL:RLMTestRealmURL()];
        [realm beginWriteTransaction];
        [DynamicObject createInRealm:realm withValue:@[@"column1", @1]];
        [DynamicObject createInRealm:realm withValue:@[@"column2", @2]];
        [realm commitWriteTransaction];
    }

    // verify properties
    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:nil];
    RLMResults *results = [dyrealm allObjects:@"DynamicObject"];

    RLMObject *o1 = results[0], *o2 = results[1];
    XCTAssertEqualObjects(o1[@"intCol"], @1);
    XCTAssertEqualObjects(o2[@"stringCol"], @"column2");
    RLMAssertThrowsWithReason(o1[@"invalid"], @"Invalid property name");
    RLMAssertThrowsWithReason(o1[@"invalid"] = nil, @"Invalid property name");
}

- (void)testDynamicTypes {
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:100000];
    id obj1 = @[@YES, @1, @1.1f, @1.11, @"string", [NSData dataWithBytes:"a" length:1],
                now, @YES, @11, NSNull.null, @82, NSNull.null];

    StringObject *obj = [[StringObject alloc] init];
    obj.stringCol = @"string";
    id obj2 = @[@NO, @2, @2.2f, @2.22, @"string2", [NSData dataWithBytes:"b" length:1],
                now, @NO, @22, obj, @100, @58];
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        RLMRealm *realm = [RLMRealm realmWithURL:RLMTestRealmURL()];
        [realm beginWriteTransaction];
        [AllTypesObject createInRealm:realm withValue:obj1];
        [AllTypesObject createInRealm:realm withValue:obj2];
        [realm commitWriteTransaction];
    }

    // verify properties
    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:nil];
    RLMResults<RLMObject *> *results = [dyrealm allObjects:AllTypesObject.className];
    XCTAssertEqual(results.count, (NSUInteger)2, @"Should have 2 objects");

    RLMObjectSchema *schema = dyrealm.schema[AllTypesObject.className];
    for (int i = 0; i < 9; i++) {
        NSString *propName = [schema.properties[i] name];
        XCTAssertEqualObjects(obj1[i], results[0][propName]);
        XCTAssertEqualObjects(obj2[i], results[1][propName]);
    }

    // check sub object type
    XCTAssertEqualObjects([schema.properties[9] objectClassName], @"StringObject",
                          @"Sub-object type in schema should be 'StringObject'");

    // check object equality
    XCTAssertNil(results[0][@"objectCol"], @"object should be nil");
    XCTAssertEqualObjects(results[1][@"objectCol"][@"stringCol"], @"string",
                          @"Child object should have string value 'string'");

    [dyrealm beginWriteTransaction];
    RLMObject *o = results[0];
    for (int i = 0; i < 9; i++) {
        RLMProperty *prop = schema.properties[i];
        id value = prop.type == RLMPropertyTypeString ? @1 : @"";
        RLMAssertThrowsWithReason(o[prop.name] = value,
                                  @"Invalid value '");
        RLMAssertThrowsWithReason(o[prop.name] = NSNull.null,
                                  @"Invalid value '<null>' of type 'NSNull' for");
        RLMAssertThrowsWithReason(o[prop.name] = nil,
                                  @"Invalid value '(null)' of type '(null)' for");
    }

    RLMProperty *prop = schema.properties[9];
    RLMAssertThrowsWithReason(o[prop.name] = @"str",
                              @"Invalid value 'str' of type '__NSCFConstantString' for 'StringObject?' property 'AllTypesObject.objectCol'.");
    XCTAssertNoThrow(o[prop.name] = nil);
    XCTAssertNoThrow(o[prop.name] = NSNull.null);

    id otherObjectType = [dyrealm createObject:IntObject.className withValue:@[@1]];
    RLMAssertThrowsWithReason(o[prop.name] = otherObjectType,
                              @"Invalid value 'IntObject");

    [dyrealm cancelWriteTransaction];
}

- (void)testDynamicAdd {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        [RLMRealm realmWithURL:RLMTestRealmURL()];
    }

    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:nil];
    [dyrealm beginWriteTransaction];
    RLMObject *stringObject = [dyrealm createObject:StringObject.className withValue:@[@"string"]];
    [dyrealm createObject:AllTypesObject.className withValue:@[@NO, @2, @2.2f, @2.22, @"string2",
                                                               [NSData dataWithBytes:"b" length:1], NSDate.date, @NO, @22, stringObject, @15, @9001]];
    [dyrealm commitWriteTransaction];

    XCTAssertEqual(1U, [dyrealm allObjects:StringObject.className].count);
    XCTAssertEqual(1U, [dyrealm allObjects:AllTypesObject.className].count);
}

- (void)testDynamicArray {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        [RLMRealm realmWithURL:RLMTestRealmURL()];
    }
    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:nil];
    [dyrealm beginWriteTransaction];

    RLMObject *stringObject = [dyrealm createObject:StringObject.className withValue:@[@"string"]];
    RLMObject *stringObject1 = [dyrealm createObject:StringObject.className withValue:@[@"string1"]];
    [dyrealm createObject:ArrayPropertyObject.className withValue:@[@"name", @[stringObject, stringObject1], @[]]];

    RLMResults<RLMObject *> *results = [dyrealm allObjects:ArrayPropertyObject.className];
    XCTAssertEqual(1U, results.count);
    RLMObject *arrayObj = results.firstObject;
    RLMArray<RLMObject *> *array = arrayObj[@"array"];
    XCTAssertEqual(2U, array.count);
    XCTAssertEqualObjects(array[0][@"stringCol"], stringObject[@"stringCol"]);

    [array removeObjectAtIndex:0];
    [array addObject:stringObject];

    XCTAssertEqual(2U, array.count);
    XCTAssertEqualObjects(array[0][@"stringCol"], stringObject1[@"stringCol"]);
    XCTAssertEqualObjects(array[1][@"stringCol"], stringObject[@"stringCol"]);

    arrayObj[@"array"] = NSNull.null;
    XCTAssertEqual(0U, array.count);

    [array addObject:stringObject];
    XCTAssertEqual(1U, array.count);

    arrayObj[@"array"] = nil;
    XCTAssertEqual(0U, array.count);

    arrayObj[@"array"] = @[stringObject, stringObject1];
    XCTAssertEqualObjects(array[0][@"stringCol"], stringObject[@"stringCol"]);
    XCTAssertEqualObjects(array[1][@"stringCol"], stringObject1[@"stringCol"]);

    [dyrealm commitWriteTransaction];
}

- (void)testOptionalProperties {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        [RLMRealm realmWithURL:RLMTestRealmURL()];
    }

    RLMRealm *dyrealm = [self realmWithTestPathAndSchema:nil];
    [dyrealm beginWriteTransaction];
    RLMObject *object = [dyrealm createObject:AllOptionalTypes.className withValue:@[]];

    XCTAssertNil(object[@"intObj"]);
    XCTAssertNil(object[@"floatObj"]);
    XCTAssertNil(object[@"doubleObj"]);
    XCTAssertNil(object[@"boolObj"]);
    XCTAssertNil(object[@"string"]);
    XCTAssertNil(object[@"data"]);
    XCTAssertNil(object[@"date"]);

    NSDate *date = [NSDate date];
    NSData *data = [NSData data];

    object[@"intObj"] = @1;
    object[@"floatObj"] = @2.2f;
    object[@"doubleObj"] = @3.3;
    object[@"boolObj"] = @YES;
    object[@"string"] = @"str";
    object[@"date"] = date;
    object[@"data"] = data;

    XCTAssertEqualObjects(object[@"intObj"], @1);
    XCTAssertEqualObjects(object[@"floatObj"], @2.2f);
    XCTAssertEqualObjects(object[@"doubleObj"], @3.3);
    XCTAssertEqualObjects(object[@"boolObj"], @YES);
    XCTAssertEqualObjects(object[@"string"], @"str");
    XCTAssertEqualObjects(object[@"date"], date);
    XCTAssertEqualObjects(object[@"data"], data);

    object[@"intObj"] = NSNull.null;
    object[@"floatObj"] = NSNull.null;
    object[@"doubleObj"] = NSNull.null;
    object[@"boolObj"] = NSNull.null;
    object[@"string"] = NSNull.null;
    object[@"date"] = NSNull.null;
    object[@"data"] = NSNull.null;

    XCTAssertNil(object[@"intObj"]);
    XCTAssertNil(object[@"floatObj"]);
    XCTAssertNil(object[@"doubleObj"]);
    XCTAssertNil(object[@"boolObj"]);
    XCTAssertNil(object[@"string"]);
    XCTAssertNil(object[@"data"]);
    XCTAssertNil(object[@"date"]);

    object[@"intObj"] = nil;
    object[@"floatObj"] = nil;
    object[@"doubleObj"] = nil;
    object[@"boolObj"] = nil;
    object[@"string"] = nil;
    object[@"date"] = nil;
    object[@"data"] = nil;

    XCTAssertNil(object[@"intObj"]);
    XCTAssertNil(object[@"floatObj"]);
    XCTAssertNil(object[@"doubleObj"]);
    XCTAssertNil(object[@"boolObj"]);
    XCTAssertNil(object[@"string"]);
    XCTAssertNil(object[@"data"]);
    XCTAssertNil(object[@"date"]);

    [dyrealm commitWriteTransaction];
}

- (void)testLinkingObjects {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    RLMObject *person = [realm createObject:PersonObject.className
                                  withValue:@[@"parent", @10, @[@[@"child", @5, @[]]]]];
    XCTAssertEqual([person[@"parents"] count], 0U);
    RLMObject *child = [person[@"children"] firstObject];
    XCTAssertEqual([child[@"parents"] count], 1U);
    XCTAssertTrue([person isEqualToObject:[child[@"parents"] firstObject]]);

    RLMAssertThrowsWithReason(person[@"parents"] = @[],
                              @"Cannot modify read-only property 'PersonObject.parents'");

    [realm commitWriteTransaction];
}

- (void)testDynamicCounterIncrement {
    @autoreleasepool {
        // open realm in autoreleasepool to create tables and then dispose
        RLMRealm *realm = [self realmWithTestPath];
        [realm beginWriteTransaction];
        [RealmIntObject createInRealm:realm withValue:@[@9000]];
        [RealmNullableIntObject createInRealm:realm withValue:@[@500]];
        [realm commitWriteTransaction];
    }

    RLMRealm *testRealm = [self realmWithTestPathAndSchema:nil];

    // Dynamically increment non-nullable integer.
    RLMObject<RLMObjectMigrationProtocol> *intObject = [[RealmIntObject allObjectsInRealm:testRealm] firstObject];
    XCTAssertTrue([intObject conformsToProtocol:@protocol(RLMObjectMigrationProtocol)]);
    XCTAssertEqual([[intObject valueForKey:@"realmInt"] integerValue], 9000);
    [testRealm beginWriteTransaction];
    [intObject incrementValueOfIntegerProperty:@"realmInt" byValue:123];
    [testRealm commitWriteTransaction];
    XCTAssertEqual([[intObject valueForKey:@"realmInt"] integerValue], 9123);

    // Dynamically increment nullable integer.
    RLMObject<RLMObjectMigrationProtocol> *nullableIntObject = [[RealmNullableIntObject allObjectsInRealm:testRealm] firstObject];
    XCTAssertTrue([nullableIntObject conformsToProtocol:@protocol(RLMObjectMigrationProtocol)]);
    XCTAssertEqual([[nullableIntObject valueForKey:@"realmInt"] integerValue], 500);
    [testRealm beginWriteTransaction];
    [nullableIntObject incrementValueOfIntegerProperty:@"realmInt" byValue:-123];
    [testRealm commitWriteTransaction];
    XCTAssertEqual([[nullableIntObject valueForKey:@"realmInt"] integerValue], 377);
    // Null it out
    [testRealm beginWriteTransaction];
    nullableIntObject[@"realmInt"] = [NSNull null];
    RLMAssertThrows([nullableIntObject incrementValueOfIntegerProperty:@"realmInt" byValue:1]);
    [testRealm commitWriteTransaction];
}

@end
