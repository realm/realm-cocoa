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

@interface AggregateObject : RLMObject
@property int intCol;
@property float floatCol;
@property double doubleCol;
@property BOOL boolCol;
@property NSDate *dateCol;
@end

@implementation AggregateObject
@end


@interface ArrayTests : RLMTestCase
@end

@implementation ArrayTests


- (void)testObjectAggregate
{
    RLMRealm *realm = [RLMRealm defaultRealm];
    
    [realm beginWriteTransaction];
    
    NSDate *dateMinInput = [NSDate date];
    NSDate *dateMaxInput = [dateMinInput dateByAddingTimeInterval:1000];
    
    [AggregateObject createInRealm:realm withObject:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withObject:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withObject:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withObject:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withObject:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withObject:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withObject:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withObject:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withObject:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withObject:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    
    [realm commitWriteTransaction];
    
    RLMArray *noArray = [AggregateObject objectsWhere:@"boolCol == NO"];
    RLMArray *yesArray = [AggregateObject objectsWhere:@"boolCol == YES"];
    
    // SUM ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int sum
    XCTAssertEqual([noArray sumOfProperty:@"intCol"].integerValue, (NSInteger)4, @"Sum should be 4");
    XCTAssertEqual([yesArray sumOfProperty:@"intCol"].integerValue, (NSInteger)0, @"Sum should be 0");
    
    // Test float sum
    XCTAssertEqualWithAccuracy([noArray sumOfProperty:@"floatCol"].floatValue, (float)0.0f, 0.1f, @"Sum should be 0.0");
    XCTAssertEqualWithAccuracy([yesArray sumOfProperty:@"floatCol"].floatValue, (float)7.2f, 0.1f, @"Sum should be 7.2");
    
    // Test double sum
    XCTAssertEqualWithAccuracy([noArray sumOfProperty:@"doubleCol"].doubleValue, (double)10.0, 0.1f, @"Sum should be 10.0");
    XCTAssertEqualWithAccuracy([yesArray sumOfProperty:@"doubleCol"].doubleValue, (double)0.0, 0.1f, @"Sum should be 0.0");
    
    // Test invalid column name
    XCTAssertThrows([yesArray sumOfProperty:@"foo"], @"Should throw exception");
    
    // Test operation not supported
    XCTAssertThrows([yesArray sumOfProperty:@"boolCol"], @"Should throw exception");
    
    
    // Average ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"intCol"].doubleValue, (double)1.0, 0.1f, @"Average should be 1.0");
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"intCol"].doubleValue, (double)0.0, 0.1f, @"Average should be 0.0");
    
    // Test float average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"floatCol"].doubleValue, (double)0.0f, 0.1f, @"Average should be 0.0");
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"floatCol"].doubleValue, (double)1.2f, 0.1f, @"Average should be 1.2");
    
    // Test double average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"doubleCol"].doubleValue, (double)2.5, 0.1f, @"Average should be 2.5");
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"doubleCol"].doubleValue, (double)0.0, 0.1f, @"Average should be 0.0");
    
    // Test invalid column name
    XCTAssertThrows([yesArray averageOfProperty:@"foo"], @"Should throw exception");
    
    // Test operation not supported
    XCTAssertThrows([yesArray averageOfProperty:@"boolCol"], @"Should throw exception");
    
    // MIN ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int min
    NSNumber *min = [noArray minOfProperty:@"intCol"];
    XCTAssertEqual(min.intValue, (NSInteger)1, @"Minimum should be 1");
    min = [yesArray minOfProperty:@"intCol"];
    XCTAssertEqual(min.intValue, (NSInteger)0, @"Minimum should be 0");
    
    // Test float min
    min = [noArray minOfProperty:@"floatCol"];
    XCTAssertEqualWithAccuracy(min.floatValue, (float)0.0f, 0.1f, @"Minimum should be 0.0f");
    min = [yesArray minOfProperty:@"floatCol"];
    XCTAssertEqualWithAccuracy(min.floatValue, (float)1.2f, 0.1f, @"Minimum should be 1.2f");
    
    // Test double min
    min = [noArray minOfProperty:@"doubleCol"];
    XCTAssertEqualWithAccuracy(min.doubleValue, (double)2.5, 0.1f, @"Minimum should be 1.5");
    min = [yesArray minOfProperty:@"doubleCol"];
    XCTAssertEqualWithAccuracy(min.doubleValue, (double)0.0, 0.1f, @"Minimum should be 0.0");
    
    // Test date min
    NSDate *dateMinOutput = [noArray minOfProperty:@"dateCol"];
    XCTAssertEqualWithAccuracy(dateMinOutput.timeIntervalSince1970, dateMaxInput.timeIntervalSince1970, 1, @"Minimum should be dateMaxInput");
    dateMinOutput = [yesArray minOfProperty:@"dateCol"];
    XCTAssertEqualWithAccuracy(dateMinOutput.timeIntervalSince1970, dateMinInput.timeIntervalSince1970, 1, @"Minimum should be dateMinInput");
    
    // Test invalid column name
    XCTAssertThrows([noArray minOfProperty:@"foo"], @"Should throw exception");
    
    // Test operation not supported
    XCTAssertThrows([noArray minOfProperty:@"boolCol"], @"Should throw exception");
    
    
    // MAX ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int max
    NSNumber *max = [noArray maxOfProperty:@"intCol"];
    XCTAssertEqual(max.integerValue, (NSInteger)1, @"Maximum should be 8");
    max = [yesArray maxOfProperty:@"intCol"];
    XCTAssertEqual(max.integerValue, (NSInteger)0, @"Maximum should be 10");
    
    // Test float max
    max = [noArray maxOfProperty:@"floatCol"];
    XCTAssertEqualWithAccuracy(max.floatValue, (float)0.0f, 0.1f, @"Maximum should be 0.0f");
    max = [yesArray maxOfProperty:@"floatCol"];
    XCTAssertEqualWithAccuracy(max.floatValue, (float)1.2f, 0.1f, @"Maximum should be 1.2f");
    
    // Test double max
    max = [noArray maxOfProperty:@"doubleCol"];
    XCTAssertEqualWithAccuracy(max.doubleValue, (double)2.5, 0.1f, @"Maximum should be 3.5");
    max = [yesArray maxOfProperty:@"doubleCol"];
    XCTAssertEqualWithAccuracy(max.doubleValue, (double)0.0, 0.1f, @"Maximum should be 0.0");
    
    // Test date max
    NSDate *dateMaxOutput = [noArray maxOfProperty:@"dateCol"];
    XCTAssertEqualWithAccuracy(dateMaxOutput.timeIntervalSince1970, dateMaxInput.timeIntervalSince1970, 1, @"Maximum should be dateMaxInput");
    dateMaxOutput = [yesArray maxOfProperty:@"dateCol"];
    XCTAssertEqualWithAccuracy(dateMaxOutput.timeIntervalSince1970, dateMinInput.timeIntervalSince1970, 1, @"Maximum should be dateMinInput");
    
    // Test invalid column name
    XCTAssertThrows([noArray maxOfProperty:@"foo"], @"Should throw exception");
    
    // Test operation not supported
    XCTAssertThrows([noArray maxOfProperty:@"boolCol"], @"Should throw exception");
}

@end
