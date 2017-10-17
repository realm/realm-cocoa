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

#import <XCTest/XCTest.h>

#import "RLMMultiProcessTestCase.h"

#import "RLMAccessor.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObject_Private.h"
#import "RLMProperty_Private.h"
#import "RLMRealmConfiguration_Private.hpp"
#import "RLMRealm_Dynamic.h"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.hpp"
#import "RLMUtil.hpp"
#import "schema.hpp"

#import <realm/table.hpp>

#import <algorithm>
#import <objc/runtime.h>

@interface SchemaTestClassBase : RLMObject
@property IntObject *baseCol;
@end
@implementation SchemaTestClassBase
@end

@interface SchemaTestClassFirstChild : SchemaTestClassBase
@property IntObject *firstChildCol;
@end
@implementation SchemaTestClassFirstChild
@end

@interface SchemaTestClassSecondChild : SchemaTestClassBase
@property IntObject *secondChildCol;
@end
@implementation SchemaTestClassSecondChild
@end

RLM_ARRAY_TYPE(SchemaTestClassBase)
RLM_ARRAY_TYPE(SchemaTestClassFirstChild)
RLM_ARRAY_TYPE(SchemaTestClassSecondChild)

@interface SchemaTestClassLink : RLMObject
@property SchemaTestClassBase *base;
@property SchemaTestClassFirstChild *child;
@property SchemaTestClassSecondChild *secondChild;

@property RLM_GENERIC_ARRAY(SchemaTestClassBase) *baseArray;
@property RLM_GENERIC_ARRAY(SchemaTestClassFirstChild) *childArray;
@property RLM_GENERIC_ARRAY(SchemaTestClassSecondChild) *secondChildArray;
@end
@implementation SchemaTestClassLink
@end

@interface NonDefaultObject : RLMObject
@property int intCol;
@end

@implementation NonDefaultObject
+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}
@end

RLM_ARRAY_TYPE(NonDefaultObject);

@interface NonDefaultArrayObject : RLMObject
@property RLM_GENERIC_ARRAY(NonDefaultObject) *array;
@end

@implementation NonDefaultArrayObject
+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}
@end

@class MutualLink2Object;

@interface MutualLink1Object : RLMObject
@property (nullable) MutualLink2Object *object;
@end
@implementation MutualLink1Object
+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}
@end

@interface MutualLink2Object : RLMObject
@property (nullable) MutualLink1Object *object;
@end
@implementation MutualLink2Object
+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}
@end

@interface SchemaTestClassWithSingleDuplicatePropertyBase : FakeObject
@property NSString *string;
@end

@implementation SchemaTestClassWithSingleDuplicatePropertyBase
@end

@interface SchemaTestClassWithSingleDuplicateProperty : SchemaTestClassWithSingleDuplicatePropertyBase
@property NSString *string;
@end

@implementation SchemaTestClassWithSingleDuplicateProperty
@dynamic string;
@end

@interface SchemaTestClassWithMultipleDuplicatePropertiesBase : FakeObject
@property NSString *string;
@property int integer;
@end

@implementation SchemaTestClassWithMultipleDuplicatePropertiesBase
@end

@interface SchemaTestClassWithMultipleDuplicateProperties : SchemaTestClassWithMultipleDuplicatePropertiesBase
@property NSString *string;
@property int integer;
@end

@implementation SchemaTestClassWithMultipleDuplicateProperties
@dynamic string;
@dynamic integer;
@end

@interface UnindexableProperty : FakeObject
@property double unindexable;
@end
@implementation UnindexableProperty
+ (NSArray *)indexedProperties {
    return @[@"unindexable"];
}
@end


@interface InvalidPrimaryKeyType : FakeObject
@property double primaryKey;
@end
@implementation InvalidPrimaryKeyType
+ (NSString *)primaryKey {
    return @"primaryKey";
}
@end

@interface RequiredLinkProperty : FakeObject
@property BoolObject *object;
@end
@implementation RequiredLinkProperty
+ (NSArray *)requiredProperties {
    return @[@"object"];
}
@end

@interface InvalidNSNumberProtocolObject : FakeObject
@property NSNumber<NSFastEnumeration> *number;
@end
@implementation InvalidNSNumberProtocolObject
@end

@interface InvalidNSNumberNoProtocolObject : FakeObject
@property NSNumber *number;
@end
@implementation InvalidNSNumberNoProtocolObject
@end

@class InvalidReadWriteLinkingObjectsProperty;
@class InvalidLinkingObjectsPropertiesMethod;
@class ValidLinkingObjectsPropertyWithProtocol;
@class InvalidLinkingObjectsPropertyProtocol;

@interface SchemaTestsLinkSource : FakeObject
@property InvalidReadWriteLinkingObjectsProperty *irwlop;
@property InvalidLinkingObjectsPropertiesMethod *iloprm;
@property ValidLinkingObjectsPropertyWithProtocol *vlopwp;
@property InvalidLinkingObjectsPropertyProtocol *ilopp;
@end
@implementation SchemaTestsLinkSource
@end

@interface MixedProperty : FakeObject
@property id mixed;
@end

@implementation MixedProperty
@end

RLM_ARRAY_TYPE(SchemaTestsLinkSource)

@interface InvalidReadWriteLinkingObjectsProperty : FakeObject
@property RLMLinkingObjects *linkingObjects;
@end

@implementation InvalidReadWriteLinkingObjectsProperty

+ (NSDictionary *)linkingObjectsProperties {
    return @{ @"linkingObjects": [RLMPropertyDescriptor descriptorWithClass:SchemaTestsLinkSource.class propertyName:@"irwlop"] };
}

@end

@interface InvalidLinkingObjectsPropertiesMethod : FakeObject
@property (readonly) RLMLinkingObjects *linkingObjects;
@end

@implementation InvalidLinkingObjectsPropertiesMethod
@end


@interface ValidLinkingObjectsPropertyWithProtocol : FakeObject
@property (readonly) RLMLinkingObjects<SchemaTestsLinkSource> *linkingObjects;
@end

@implementation ValidLinkingObjectsPropertyWithProtocol

+ (NSDictionary *)linkingObjectsProperties {
    return @{ @"linkingObjects": [RLMPropertyDescriptor descriptorWithClass:SchemaTestsLinkSource.class propertyName:@"vlopwp"] };
}

@end

RLM_ARRAY_TYPE(NotARealClass)

@interface InvalidLinkingObjectsPropertyProtocol : FakeObject
@property (readonly) RLMLinkingObjects<NotARealClass> *linkingObjects;
@end

@implementation InvalidLinkingObjectsPropertyProtocol

+ (NSDictionary *)linkingObjectsProperties {
    return @{ @"linkingObjects": [RLMPropertyDescriptor descriptorWithClass:SchemaTestsLinkSource.class propertyName:@"ilopp"] };
}

@end


@interface InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink : FakeObject
@property (readonly) RLMLinkingObjects *linkingObjects;
@property InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink *link;
@end

@implementation InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink

+ (NSDictionary *)linkingObjectsProperties {
    return @{ @"linkingObjects": [RLMPropertyDescriptor descriptorWithClass:InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink.class
                                                               propertyName:@"nosuchproperty"] };
}

@end


@interface InvalidLinkingObjectsPropertySourcePropertyNotALink : FakeObject
@property (readonly) RLMLinkingObjects *linkingObjects;
@property int64_t integer;
@end

@implementation InvalidLinkingObjectsPropertySourcePropertyNotALink

+ (NSDictionary *)linkingObjectsProperties {
    return @{ @"linkingObjects": [RLMPropertyDescriptor descriptorWithClass:InvalidLinkingObjectsPropertySourcePropertyNotALink.class
                                                               propertyName:@"integer"] };
}

@end


@interface InvalidLinkingObjectsPropertySourcePropertyLinksElsewhere : FakeObject
@property (readonly) RLMLinkingObjects *linkingObjects;
@property IntObject *link;
@end

@implementation InvalidLinkingObjectsPropertySourcePropertyLinksElsewhere

+ (NSDictionary *)linkingObjectsProperties {
    return @{ @"linkingObjects": [RLMPropertyDescriptor descriptorWithClass:InvalidLinkingObjectsPropertySourcePropertyLinksElsewhere.class
                                                               propertyName:@"link"] };
}

@end


@interface SchemaTests : RLMMultiProcessTestCase
@end

@implementation SchemaTests

- (void)tearDown {
    RLMSetTreatFakeObjectAsRLMObject(NO);
    [super tearDown];
}

- (void)testNoSchemaForUnmanagedObjectClasses {
    RLMSchema *schema = [RLMSchema sharedSchema];
    XCTAssertNil([schema schemaForClassName:@"RLMObject"]);
    XCTAssertNil([schema schemaForClassName:@"RLMObjectBase"]);
    XCTAssertNil([schema schemaForClassName:@"RLMDynamicObject"]);
}

- (void)testSchemaWithObjectClasses {
    RLMSchema *schema = [RLMSchema schemaWithObjectClasses:@[RLMDynamicObject.class, StringObject.class]];
    XCTAssertEqualObjects((@[@"RLMDynamicObject", @"StringObject"]),
                          [[schema.objectSchema valueForKey:@"className"] sortedArrayUsingSelector:@selector(compare:)]);
    XCTAssertNil([RLMSchema.sharedSchema schemaForClassName:@"RLMDynamicObject"]);
}

- (void)testInheritanceInitialization
{
    Class testClasses[] = {
        [SchemaTestClassBase class],
        [SchemaTestClassFirstChild class],
        [SchemaTestClassSecondChild class],
        [SchemaTestClassLink class],
        [IntObject class]
    };

    auto pred = ^(Class lft, Class rgt) {
        return (uintptr_t)lft < (uintptr_t)rgt;
    };

    auto checkSchema = ^(RLMSchema *schema, NSString *className, NSDictionary *properties) {
        RLMObjectSchema *objectSchema = schema[className];
        XCTAssertEqualObjects(className, objectSchema.className);
        XCTAssertEqualObjects(className, [objectSchema.unmanagedClass className]);
        XCTAssertEqualObjects(className, [objectSchema.accessorClass className]);

        XCTAssertEqual(objectSchema.properties.count, properties.count);
        for (NSString *propName in properties) {
            XCTAssertEqualObjects(properties[propName], [objectSchema[propName] objectClassName]);
        }
    };

    // Test each permutation of loading orders and verify that all properties
    // are initialized correctly
    std::sort(testClasses, std::end(testClasses), pred);
    unsigned long iteration = 0;
    do @autoreleasepool {
        // Clean up any existing overridden things
        for (Class cls : testClasses) {
            // Ensure that the className method isn't used during schema init
            // as it may not be overriden yet
            Class metaClass = object_getClass(cls);
            IMP imp = imp_implementationWithBlock(^{ return nil; });
            class_replaceMethod(metaClass, @selector(className), imp, "@:");
        }

        NSMutableArray *objectSchemas = [NSMutableArray arrayWithCapacity:4U];
        for (Class cls : testClasses) {
            [objectSchemas addObject:[RLMObjectSchema schemaForObjectClass:cls]];
        }

        RLMSchema *schema = [[RLMSchema alloc] init];
        schema.objectSchema = objectSchemas;

        for (RLMObjectSchema *objectSchema in objectSchemas) {
            NSString *name = [NSString stringWithFormat:@"RLMTestAccessor_%lu_%@", iteration, objectSchema.className];
            objectSchema.accessorClass = RLMManagedAccessorClassForObjectClass(objectSchema.objectClass, objectSchema, name.UTF8String);
            objectSchema.unmanagedClass = RLMUnmanagedAccessorClassForObjectClass(objectSchema.objectClass, objectSchema);
        }
        ++iteration;

        for (Class cls : testClasses) {
            NSString *className = NSStringFromClass(cls);

            // Restore the className method
            Class metaClass = object_getClass(cls);
            IMP imp = imp_implementationWithBlock(^{ return className; });
            class_replaceMethod(metaClass, @selector(className), imp, "@:");
        }

        // Verify that each class has the correct properties and className
        // for generated subclasses
        checkSchema(schema, @"SchemaTestClassBase", @{@"baseCol": @"IntObject"});
        checkSchema(schema, @"SchemaTestClassFirstChild", @{@"baseCol": @"IntObject",
                                                            @"firstChildCol": @"IntObject"});
        checkSchema(schema, @"SchemaTestClassSecondChild", @{@"baseCol": @"IntObject",
                                                            @"secondChildCol": @"IntObject"});
        checkSchema(schema, @"SchemaTestClassLink", @{@"base": @"SchemaTestClassBase",
                                                      @"baseArray": @"SchemaTestClassBase",
                                                      @"child": @"SchemaTestClassFirstChild",
                                                      @"childArray": @"SchemaTestClassFirstChild",
                                                      @"secondChild": @"SchemaTestClassSecondChild",
                                                      @"secondChildArray": @"SchemaTestClassSecondChild"});


        // Test creating objects of each class
        [self deleteFiles];
        RLMRealm *realm = [self realmWithTestPathAndSchema:schema];
        [realm beginWriteTransaction];
        [realm createObject:@"SchemaTestClassBase" withValue:@{@"baseCol": @[@0]}];
        [realm createObject:@"SchemaTestClassFirstChild" withValue:@{@"baseCol": @[@0], @"firstChildCol": @[@0]}];
        [realm createObject:@"SchemaTestClassSecondChild" withValue:@{@"baseCol": @[@0], @"secondChildCol": @[@0]}];
        [realm commitWriteTransaction];
    } while (std::next_permutation(testClasses, std::end(testClasses), pred));
}

- (void)testObjectSchema
{
    // Setting up some test data

    // Due to the automatic initialization of a new realm with all visible classes inheriting from
    // RLMObject, it's difficult to define test cases that verify the absolute correctness of a
    // realm's current type catalogue unless its expected configuration is known at compile time
    // (requires that the set of expected types is always up-to-date). Instead, only a partial
    // verification is performed, which only requires the availability of a well-defined subset of
    // types and ignores any other types that may be included in the realm's type catalogue.
    // If a more fine-grained control with the realm's type inclusion mechanism is introduced later
    // on, these tests should be altered to verify all types.

    NSArray *expectedTypes = @[@"AllTypesObject",
                               @"LinkToAllTypesObject",
                               @"StringObject",
                               @"IntObject"];

    NSString *unexpectedType = @"__$ThisTypeShouldNotOccur$__";

    // Getting the test realm
    NSMutableArray *objectSchema = [NSMutableArray array];
    for (NSString *className in expectedTypes) {
        [objectSchema addObject:[RLMObjectSchema schemaForObjectClass:NSClassFromString(className)]];
    }

    RLMSchema *schema = [[RLMSchema alloc] init];
    schema.objectSchema = objectSchema;

    // create realm with schema
    @autoreleasepool { [self realmWithTestPathAndSchema:schema]; }

    // get dynamic realm and extract schema
    RLMRealm *realm = [self realmWithTestPathAndSchema:nil];
    schema = realm.schema;

    // Test 1: Does the objectSchema return the right number of object schemas?
    NSArray *objectSchemas = schema.objectSchema;

    XCTAssertTrue(objectSchemas.count >= expectedTypes.count, @"Expecting %lu object schemas in database found %lu", (unsigned long)expectedTypes.count, (unsigned long)objectSchemas.count);

    // Test 2: Does the object schema array contain the expected schemas?
    NSUInteger identifiedTypesCount = 0;
    for (NSString *expectedType in expectedTypes) {
        NSUInteger occurrenceCount = 0;

        for (RLMObjectSchema *objectSchema in objectSchemas) {
            if ([objectSchema.className isEqualToString:expectedType]) {
                occurrenceCount++;
            }
        }

        XCTAssertEqual(occurrenceCount, (NSUInteger)1, @"Expecting single occurrence of object schema for type %@ found %lu", expectedType, (unsigned long)occurrenceCount);

        if (occurrenceCount > 0) {
            identifiedTypesCount++;
        }
    }

    // Test 3: Does the object schema array contains at least the expected classes
    XCTAssertTrue(identifiedTypesCount >= expectedTypes.count, @"Unexpected object schemas in database. Found %lu out of %lu expected", (unsigned long)identifiedTypesCount, (unsigned long)expectedTypes.count);

    // Test 4: Test querying object schemas using schemaForClassName: for expected types
    for (NSString *expectedType in expectedTypes) {
        XCTAssertNotNil([schema schemaForClassName:expectedType], @"Expecting to find object schema for type %@ in realm using query, found none", expectedType);
    }

    // Test 5: Test querying object schemas using schemaForClassName: for unexpected types
    XCTAssertNil([schema schemaForClassName:unexpectedType], @"Expecting not to find object schema for type %@ in realm using query, did find", unexpectedType);

    // Test 6: Test querying object schemas using subscription for unexpected types
    for (NSString *expectedType in expectedTypes) {
        XCTAssertNotNil(schema[expectedType], @"Expecting to find object schema for type %@ in realm using subscription, found none", expectedType);
    }

    // Test 7: Test querying object schemas using subscription for unexpected types
    XCTAssertThrows(schema[unexpectedType], @"Expecting asking schema for type %@ in realm using subscription to throw", unexpectedType);

    // Test 8: RLMObject should not appear in the shared object schema
    XCTAssertThrows(RLMSchema.sharedSchema[@"RLMObject"]);
}

- (void)testDescription {
    NSArray *expectedTypes = @[@"AllTypesObject",
                               @"StringObject",
                               @"IntObject"];

    NSMutableArray *objectSchema = [NSMutableArray array];
    for (NSString *className in expectedTypes) {
        [objectSchema addObject:[RLMObjectSchema schemaForObjectClass:NSClassFromString(className)]];
    }

    RLMSchema *schema = [[RLMSchema alloc] init];
    schema.objectSchema = objectSchema;

    XCTAssertEqualObjects(schema.description, @"Schema {\n"
                                              @"\tAllTypesObject {\n"
                                              @"\t\tboolCol {\n"
                                              @"\t\t\ttype = bool;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tintCol {\n"
                                              @"\t\t\ttype = int;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tfloatCol {\n"
                                              @"\t\t\ttype = float;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tdoubleCol {\n"
                                              @"\t\t\ttype = double;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tstringCol {\n"
                                              @"\t\t\ttype = string;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tbinaryCol {\n"
                                              @"\t\t\ttype = data;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tdateCol {\n"
                                              @"\t\t\ttype = date;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tcBoolCol {\n"
                                              @"\t\t\ttype = bool;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tlongCol {\n"
                                              @"\t\t\ttype = int;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\tobjectCol {\n"
                                              @"\t\t\ttype = object;\n"
                                              @"\t\t\tobjectClassName = StringObject;\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = YES;\n"
                                              @"\t\t}\n"
                                              @"\t\trealmIntCol {\n"
                                              @"\t\t\ttype = int;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t\trealmNullableIntCol {\n"
                                              @"\t\t\ttype = int;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = YES;\n"
                                              @"\t\t}\n"
                                              @"\t\tlinkingObjectsCol {\n"
                                              @"\t\t\ttype = linking objects;\n"
                                              @"\t\t\tobjectClassName = LinkToAllTypesObject;\n"
                                              @"\t\t\tlinkOriginPropertyName = allTypesCol;\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = YES;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t}\n"
                                              @"\tIntObject {\n"
                                              @"\t\tintCol {\n"
                                              @"\t\t\ttype = int;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = NO;\n"
                                              @"\t\t}\n"
                                              @"\t}\n"
                                              @"\tStringObject {\n"
                                              @"\t\tstringCol {\n"
                                              @"\t\t\ttype = string;\n"
                                              @"\t\t\tobjectClassName = (null);\n"
                                              @"\t\t\tlinkOriginPropertyName = (null);\n"
                                              @"\t\t\tindexed = NO;\n"
                                              @"\t\t\tisPrimary = NO;\n"
                                              @"\t\t\tarray = NO;\n"
                                              @"\t\t\toptional = YES;\n"
                                              @"\t\t}\n"
                                              @"\t}\n"
                                              @"}");

}

- (void)testClassWithDuplicateProperties
{
    // If a property is overriden in a child class it should not be picked up more than once.
    RLMObjectSchema *firstSchema = [RLMObjectSchema schemaForObjectClass:SchemaTestClassWithSingleDuplicateProperty.class];
    XCTAssertEqual((int)firstSchema.properties.count, 1);
    RLMObjectSchema *secondSchema = [RLMObjectSchema schemaForObjectClass:SchemaTestClassWithMultipleDuplicateProperties.class];
    XCTAssertEqual((int)secondSchema.properties.count, 2);
}

- (void)testClassWithInvalidPrimaryKey {
    XCTAssertThrows([RLMObjectSchema schemaForObjectClass:InvalidPrimaryKeyType.class]);
}

- (void)testClassWithUnindexableProperty {
    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:UnindexableProperty.class];
    RLMSchema *schema = [[RLMSchema alloc] init];
    schema.objectSchema = @[objectSchema];
    RLMAssertThrowsWithReasonMatching([self realmWithTestPathAndSchema:schema],
                                      @"Property 'UnindexableProperty.unindexable' of type 'double' cannot be indexed");
}

- (void)testClassWithRequiredNullableProperties {
    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:RequiredPropertiesObject.class];
    XCTAssertFalse([objectSchema[@"stringCol"] optional]);
    XCTAssertFalse([objectSchema[@"binaryCol"] optional]);
}

- (void)testClassWithRequiredPrimitiveArrayProperties {
    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:AllPrimitiveArrays.class];
    XCTAssertFalse(objectSchema[@"intObj"].optional);
    XCTAssertFalse(objectSchema[@"boolObj"].optional);
    XCTAssertFalse(objectSchema[@"floatObj"].optional);
    XCTAssertFalse(objectSchema[@"doubleObj"].optional);
    XCTAssertFalse(objectSchema[@"stringObj"].optional);
    XCTAssertFalse(objectSchema[@"dateObj"].optional);
    XCTAssertFalse(objectSchema[@"dataObj"].optional);
}

- (void)testClassWithOptionalPrimitiveArrayProperties {
    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:AllOptionalPrimitiveArrays.class];
    XCTAssertTrue(objectSchema[@"intObj"].optional);
    XCTAssertTrue(objectSchema[@"boolObj"].optional);
    XCTAssertTrue(objectSchema[@"floatObj"].optional);
    XCTAssertTrue(objectSchema[@"doubleObj"].optional);
    XCTAssertTrue(objectSchema[@"stringObj"].optional);
    XCTAssertTrue(objectSchema[@"dateObj"].optional);
    XCTAssertTrue(objectSchema[@"dataObj"].optional);
}

- (void)testClassWithRequiredLinkProperty {
    RLMAssertThrowsWithReasonMatching([RLMObjectSchema schemaForObjectClass:RequiredLinkProperty.class], @"cannot be made required.*'object'");
}

- (void)testClassWithInvalidNSNumberProtocolProperty {
    RLMAssertThrowsWithReasonMatching([RLMObjectSchema schemaForObjectClass:InvalidNSNumberProtocolObject.class],
                                      @"Property 'number' is of type \"NSNumber<NSFastEnumeration>\" which is not a supported NSNumber object type.");
}

- (void)testClassWithInvalidNSNumberNoProtocolProperty {
    RLMAssertThrowsWithReasonMatching([RLMObjectSchema schemaForObjectClass:InvalidNSNumberNoProtocolObject.class], @"Property 'number' requires a protocol defining the contained type");
}

- (void)testClassWithReadWriteLinkingObjectsProperty {
    RLMAssertThrowsWithReasonMatching([RLMObjectSchema schemaForObjectClass:InvalidReadWriteLinkingObjectsProperty.class],
                                      @"Property 'linkingObjects' must be declared as readonly .* linking objects");
}

- (void)testClassWithInvalidLinkingObjectsPropertiesMethod {
    RLMAssertThrowsWithReasonMatching([RLMObjectSchema schemaForObjectClass:InvalidLinkingObjectsPropertiesMethod.class],
                                      @"Property 'linkingObjects' .* but \\+linkingObjectsProperties .* class or property");
}

- (void)testClassWithLinkingObjectsPropertyWithProtocol {
    RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:ValidLinkingObjectsPropertyWithProtocol.class];
    XCTAssertEqual(objectSchema[@"linkingObjects"].type, RLMPropertyTypeLinkingObjects);
}

- (void)testClassWithInvalidLinkingObjectsPropertyProtocol {
    RLMAssertThrowsWithReasonMatching([RLMObjectSchema schemaForObjectClass:InvalidLinkingObjectsPropertyProtocol.class],
                                      @"Property 'linkingObjects' .* type RLMLinkingObjects<NotARealClass>.*conflicting class name.*'SchemaTestsLinkSource'");
}

- (void)testClassWithInvalidLinkingObjectsPropertyMissingSourcePropertyOfLink {
    RLMSetTreatFakeObjectAsRLMObject(YES);
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.customSchema = [RLMSchema schemaWithObjectClasses:@[ InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink.class ]];
    RLMAssertThrowsWithReasonMatching([RLMRealm realmWithConfiguration:config error:nil],
                                      @"Property 'InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink.nosuchproperty' declared as origin of linking objects property 'InvalidLinkingObjectsPropertyMissingSourcePropertyOfLink.linkingObjects' does not exist");
}

- (void)testClassWithInvalidLinkingObjectsPropertySourcePropertyNotALink {
    RLMSetTreatFakeObjectAsRLMObject(YES);
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.customSchema = [RLMSchema schemaWithObjectClasses:@[ InvalidLinkingObjectsPropertySourcePropertyNotALink.class ]];
    RLMAssertThrowsWithReasonMatching([RLMRealm realmWithConfiguration:config error:nil],
                                      @"Property 'InvalidLinkingObjectsPropertySourcePropertyNotALink.integer' declared as origin of linking objects property 'InvalidLinkingObjectsPropertySourcePropertyNotALink.linkingObjects' is not a link");
}

- (void)testClassWithInvalidLinkingObjectsPropertySourcePropertysLinkElsewhere {
    RLMSetTreatFakeObjectAsRLMObject(YES);
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.customSchema = [RLMSchema schemaWithObjectClasses:@[ InvalidLinkingObjectsPropertySourcePropertyLinksElsewhere.class, IntObject.class ]];
    RLMAssertThrowsWithReasonMatching([RLMRealm realmWithConfiguration:config error:nil],
                                      @"Property 'InvalidLinkingObjectsPropertySourcePropertyLinksElsewhere.link' declared as origin of linking objects property 'InvalidLinkingObjectsPropertySourcePropertyLinksElsewhere.linkingObjects' links to type 'IntObject'");
}

- (void)testMixedIsRejected {
    RLMSetTreatFakeObjectAsRLMObject(YES);
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    RLMAssertThrowsWithReasonMatching(config.objectClasses = @[[MixedProperty class]],
                                      @"Property 'mixed' is declared as 'id'.*");
}

// Can't spawn child processes on iOS
#if !TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
- (void)testPartialSharedSchemaInit {
    if (self.isParent) {
        RLMRunChildAndWait();
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];

    // Verify that opening with class subsets without the shared schema being
    // initialized works
    config.objectClasses = @[IntObject.class];
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
        XCTAssertEqual(1U, realm.schema.objectSchema.count);
        XCTAssertNoThrow(realm.schema[@"IntObject"]);
    }

    config.objectClasses = @[IntObject.class, StringObject.class];
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
        XCTAssertEqual(2U, realm.schema.objectSchema.count);
        XCTAssertNoThrow(realm.schema[@"IntObject"]);
        XCTAssertNoThrow(realm.schema[@"StringObject"]);
    }

    // Verify that the shared schema generated afterwards is valid
    config.objectClasses = nil;
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];

        // Shared schema shouldn't have accessor classes
        for (RLMObjectSchema *objectSchema in realm.schema.objectSchema) {
            const char *actualClassName = class_getName(objectSchema.objectClass);
            XCTAssertEqual(nullptr, strstr(actualClassName, "RLMAccessor"));
            XCTAssertEqual(nullptr, strstr(actualClassName, "RLMUnmanaged"));
        }

        // Shared schema shouldn't have duplicate entries
        XCTAssertEqual(realm.schema.objectSchema.count,
                       [NSSet setWithArray:[realm.schema.objectSchema valueForKey:@"className"]].count);

        // Shared schema should have the ones that were used in the subsets
        XCTAssertNoThrow(realm.schema[@"IntObject"]);
        XCTAssertNoThrow(realm.schema[@"StringObject"]);
    }
}

- (void)testPartialSharedSchemaInitInheritance {
    if (self.isParent) {
        RLMRunChildAndWait();
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.objectClasses = @[NumberObject.class];

    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    XCTAssertEqual(1U, realm.schema.objectSchema.count);
    XCTAssertEqualObjects(@"NumberObject", [[[[NumberObject alloc] init] objectSchema] className]);
    // Verify that child class doesn't use the parent class's schema
    XCTAssertEqualObjects(@"NumberDefaultsObject", [[[[NumberDefaultsObject alloc] init] objectSchema] className]);
}

- (void)testCreateUnmanagedObjectWithUninitializedSchema {
    if (self.isParent) {
        RLMRunChildAndWait();
        return;
    }
    XCTAssertTrue(RLMSchema.partialSharedSchema.objectSchema.count == 0);
    XCTAssertNoThrow([[IntObject alloc] initWithValue:@[@0]]);
    XCTAssertNoThrow([[NonDefaultObject alloc] initWithValue:@[@0]]);
}

- (void)testCreateUnmanagedObjectWithNestedObjectWithUninitializedSchema {
    if (self.isParent) {
        RLMRunChildAndWait();
        return;
    }
    XCTAssertTrue(RLMSchema.partialSharedSchema.objectSchema.count == 0);
    XCTAssertNoThrow([[IntegerArrayPropertyObject alloc] initWithValue:(@[@0, @[@[@0]]])]);
    XCTAssertNoThrow([[NonDefaultArrayObject alloc] initWithValue:@[@[@[@0]]]]);
    XCTAssertNoThrow([[MutualLink1Object alloc] initWithValue:@[@[@{}]]]);
}

#if !DEBUG
- (void)testMultipleProcessesTryingToInitializeSchema {
    RLMRealm *syncRealm = [self realmWithTestPath];

    if (!self.isParent) {
        RLMSchema *schema = [RLMSchema schemaWithObjectClasses:@[IntObject.class]];
        RLMProperty *prop = ((NSArray *)[schema.objectSchema[0] properties])[0];
        prop.type = RLMPropertyTypeFloat;

        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.customSchema = schema;
        config.schemaVersion = 1;

        [syncRealm transactionWithBlock:^{
            [StringObject createInRealm:syncRealm withValue:@[@""]];
        }];

        [RLMRealm realmWithConfiguration:config error:nil];
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.objectClasses = @[IntObject.class];
    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];

    // Hold a write transaction to prevent the child processes from performing
    // the migration immediately
    [realm beginWriteTransaction];

    // Spawn a bunch of child processes which will all try to perform the migration
    dispatch_group_t group = dispatch_group_create();
    for (int i = 0; i < 5; ++i) {
        dispatch_group_async(group, dispatch_get_global_queue(0, 0), ^{
            RLMRunChildAndWait();
        });
    }

    // Wait for all five to be immediately before the point where they will try
    // to perform the migration. There's inherently a race condition here in
    // as in theory all but one process could be suspended immediately after
    // committing the signalling commit and then not get woken up until after
    // the migration is complete, but in practice it won't happen and we can't
    // wait for someone to be waiting on a mutex.
    XCTestExpectation *notificationFired = [self expectationWithDescription:@"notification fired"];
    RLMNotificationToken *token = [syncRealm addNotificationBlock:^(NSString *, RLMRealm *) {
        if ([StringObject allObjectsInRealm:syncRealm].count == 5) {
            [notificationFired fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    [token invalidate];

    // Release the write transaction and let them run
    [realm cancelWriteTransaction];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}
#endif

- (void)testOpeningFileWithDifferentClassSubsetsInDifferentProcesses {
    if (!self.isParent) {
        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.objectClasses = @[StringObject.class];

        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
        XCTAssertEqual(1U, realm.schema.objectSchema.count);

        // Verify that the StringObject table actually exists
        [realm beginWriteTransaction];
        [StringObject createInRealm:realm withValue:@[@""]];
        [realm commitWriteTransaction];
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.objectClasses = @[IntObject.class];

    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    realm.autorefresh = false;
    XCTAssertEqual(1U, realm.schema.objectSchema.count);

    [realm beginWriteTransaction];
    [IntObject createInRealm:realm withValue:@[@1]];
    [realm commitWriteTransaction];

    RLMRunChildAndWait();

    // Should be able to advance over the transaction creating a new table and
    // inserting a row into it
    XCTAssertNoThrow([realm refresh]);

    // Verify that the IntObject table didn't break
    XCTAssertEqual(1, [[IntObject allObjectsInRealm:realm].firstObject intCol]);
    [realm beginWriteTransaction];
    [IntObject createInRealm:realm withValue:@[@2]];

    // StringObject still isn't usable in this process since it isn't in the
    // class subset
    XCTAssertThrows([StringObject createInRealm:realm withValue:@[@""]]);
    [realm commitWriteTransaction];
}

- (void)testAddingIndexToExistingColumnInBackgroundProcess {
    if (!self.isParent) {
        RLMSchema *schema = [RLMSchema schemaWithObjectClasses:@[IntObject.class]];
        RLMObjectSchema *objectSchema = schema.objectSchema[0];
        RLMProperty *prop = objectSchema.properties[0];
        prop.indexed = YES;

        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.customSchema = schema;
        [RLMRealm realmWithConfiguration:config error:nil];
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.objectClasses = @[IntObject.class];

    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    realm.autorefresh = false;
    XCTAssertEqual(1U, realm.schema.objectSchema.count);

    // Insert a value to ensure stuff actually happens when the index is added/removed
    [realm beginWriteTransaction];
    [IntObject createInRealm:realm withValue:@[@1]];
    [realm commitWriteTransaction];

    RLMRunChildAndWait();

    // Should accept the index change
    XCTAssertNoThrow([realm refresh]);
}

- (void)testRemovingIndexFromExistingColumnInBackgroundProcess {
    if (!self.isParent) {
        RLMSchema *schema = [RLMSchema schemaWithObjectClasses:@[IndexedStringObject.class]];
        RLMObjectSchema *objectSchema = schema.objectSchema[0];
        RLMProperty *prop = objectSchema.properties[0];
        prop.indexed = NO;

        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.customSchema = schema;
        [RLMRealm realmWithConfiguration:config error:nil];
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.objectClasses = @[IndexedStringObject.class];

    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    realm.autorefresh = false;
    XCTAssertEqual(1U, realm.schema.objectSchema.count);

    // Insert a value to ensure stuff actually happens when the index is added/removed
    [realm beginWriteTransaction];
    [IndexedStringObject createInRealm:realm withValue:@[@"1"]];
    [realm commitWriteTransaction];

    RLMRunChildAndWait();

    // Should accept the index change
    XCTAssertNoThrow([realm refresh]);
}

- (void)testMigratingToLaterVersionInBackgroundProcess {
    if (!self.isParent) {
        RLMSchema *schema = [RLMSchema schemaWithObjectClasses:@[IntObject.class]];
        RLMObjectSchema *objectSchema = schema.objectSchema[0];
        RLMProperty *prop = objectSchema.properties[0];
        prop.type = RLMPropertyTypeFloat;

        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.customSchema = schema;
        config.schemaVersion = 1;
        [RLMRealm realmWithConfiguration:config error:nil];
        return;
    }

    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.objectClasses = @[IntObject.class];

    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    realm.autorefresh = false;
    [realm beginWriteTransaction];
    [IntObject createInRealm:realm withValue:@[@1]];
    [realm commitWriteTransaction];

    RLMRunChildAndWait();

    // Should fail to refresh since we can't use later versions of the file due
    // to the schema change
    XCTAssertThrows([realm refresh]);
    XCTAssertThrows([realm beginWriteTransaction]);

    // Should have been left in a sensible state after the errors
    XCTAssertEqual(1, [[IntObject allObjectsInRealm:realm].firstObject intCol]);
}

- (void)testInsertingColumnsInBackgroundProcess {
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.schemaMode = realm::SchemaMode::Additive;
    if (!self.isParent) {
        config.dynamic = true;
        RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
        [realm beginWriteTransaction];
        realm->_info[@"IntObject"].table()->insert_column(0, realm::type_String, "col");
        [realm commitWriteTransaction];
        return;
    }

    RLMRealm *realm = [RLMRealm realmWithConfiguration:config error:nil];
    [realm transactionWithBlock:^{
        [IntObject createInRealm:realm withValue:@[@5]];
    }];

    RLMRunChildAndWait();
    XCTAssertEqual(5, [[IntObject allObjectsInRealm:realm].firstObject intCol]);
    XCTAssertEqual(1U, [IntObject objectsInRealm:realm where:@"intCol = 5"].count);

    __block IntObject *io = [IntObject new];
    io.intCol = 6;
    [realm transactionWithBlock:^{ [realm addObject:io]; }];
    XCTAssertEqual(io.intCol, 6);
    XCTAssertEqualObjects(io[@"intCol"], @6);

    [realm transactionWithBlock:^{ io = [IntObject createInRealm:realm withValue:@[@7]]; }];
    XCTAssertEqual(io.intCol, 7);

    [realm transactionWithBlock:^{ io = [IntObject createInRealm:realm withValue:@{@"intCol": @8}]; }];
    XCTAssertEqual(io.intCol, 8);

    [realm transactionWithBlock:^{ io.intCol = 9; }];
    XCTAssertEqual(io.intCol, 9);

    [realm transactionWithBlock:^{ io[@"intCol"] = @10; }];
    XCTAssertEqual(io.intCol, 10);

    // Create query, add column, run query
    RLMResults *query = [IntObject objectsInRealm:realm where:@"intCol > 5"];
    RLMRunChildAndWait();
    XCTAssertEqual(query.count, 3U);

    // Create query, create TV, add column, reevaluate query
    query = [IntObject objectsInRealm:realm where:@"intCol > 5"];
    (void)[query lastObject];
    RLMRunChildAndWait();
    XCTAssertEqual(query.count, 3U);
}
#endif

@end
