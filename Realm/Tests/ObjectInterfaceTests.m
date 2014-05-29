////////////////////////////////////////////////////////////////////////////
//
// TIGHTDB CONFIDENTIAL
// __________________
//
//  [2011] - [2014] TightDB Inc
//  All Rights Reserved.
//
// NOTICE:  All information contained herein is, and remains
// the property of TightDB Incorporated and its suppliers,
// if any.  The intellectual and technical concepts contained
// herein are proprietary to TightDB Incorporated
// and its suppliers and may be covered by U.S. and Foreign Patents,
// patents in process, and are protected by trade secret or copyright law.
// Dissemination of this information or reproduction of this material
// is strictly forbidden unless prior written permission is obtained
// from TightDB Incorporated.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMTestCase.h"
#import "RLMTestObjects.h"

//
// for custom accessor test
//
@interface CustomAccessors : RLMObject
@property (getter = getThatName) NSString * name;
@property (setter = setTheInt:) int age;
@end

@implementation CustomAccessors
@end


//
// for subclass test
//
@interface InvalidSubclassObject : RLMTestObject
@property NSString *invalid;
@end

@implementation InvalidSubclassObject
@end


//
// for class extension test
//
@interface BaseClassTestObject : RLMObject
@property NSInteger intCol;
@end

// Class extension, adding one more column
@interface BaseClassTestObject ()
@property (nonatomic, copy) NSString *stringCol;
@end

@implementation BaseClassTestObject
@end



@interface ObjectInterfaceTests : RLMTestCase
@end

@implementation ObjectInterfaceTests


- (void)testCustomAccessors
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    CustomAccessors *ca = [CustomAccessors createInRealm:realm withObject:@[@"name", @2]];
    XCTAssertEqualObjects([ca getThatName], @"name", @"name property should be name.");
    
    [ca setTheInt:99];
    XCTAssertEqual((int)ca.age, (int)99, @"age property should be 99");
    [realm commitWriteTransaction];
}

- (void)testObjectSubclass
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    NSArray *obj = @[@1, @"throw"];
    XCTAssertThrows([InvalidSubclassObject createInRealm:realm withObject:obj],
                    @"Adding invalid object should throw");
    [realm commitWriteTransaction];
}

- (void)testClassExtension
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    BaseClassTestObject *bObject = [[BaseClassTestObject alloc ] init];
    bObject.intCol = 1;
    bObject.stringCol = @"stringVal";
    [realm addObject:bObject];
    [realm commitWriteTransaction];
    
    
    BaseClassTestObject *objectFromRealm = [BaseClassTestObject allObjects][0];
    XCTAssertEqual(1, objectFromRealm.intCol, @"Should be 1");
    XCTAssertEqualObjects(@"stringVal", objectFromRealm.stringCol, @"Should be stringVal");
}

@end
