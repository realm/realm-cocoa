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

#import <mach/mach.h>
#import <objc/runtime.h>

@interface ResultsTests : RLMTestCase
@end

@implementation ResultsTests

- (void)testFastEnumeration
{
    RLMRealm *realm = self.realmWithTestPath;

    // enumerate empty array
    for (__unused id obj in [AggregateObject allObjectsInRealm:realm]) {
        XCTFail(@"Should be empty");
    }

    [realm beginWriteTransaction];
    for (int i = 0; i < 18; ++i) {
        [AggregateObject createInRealm:realm withValue:@[@10, @1.2f, @0.0, @YES, NSDate.date]];
    }
    [realm commitWriteTransaction];

    RLMResults *result = [AggregateObject objectsInRealm:realm where:@"intCol < %i", 100];
    XCTAssertEqual(result.count, 18U);

    __weak id objects[18];
    NSInteger count = 0;
    for (AggregateObject *ao in result) {
        XCTAssertNotNil(ao, @"Object is not nil and accessible");
        if (count > 16) {
            // 16 is the size of blocks fast enumeration happens to ask for at
            // the moment, but of course that's just an implementation detail
            // that may change
            XCTAssertNil(objects[count - 16]);
        }
        objects[count++] = ao;
    }

    XCTAssertEqual(count, 18, @"should have enumerated 18 objects");

    for (int i = 0; i < count; i++) {
        XCTAssertNil(objects[i], @"Object should have been released");
    }

    @autoreleasepool {
        for (AggregateObject *ao in result) {
            objects[0] = ao;
            break;
        }
    }
    XCTAssertNil(objects[0], @"Object should have been released");
}

- (void)testFirst {
    XCTAssertNil(IntObject.allObjects.firstObject);
    XCTAssertNil([IntObject objectsWhere:@"intCol > 5"].firstObject);

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [IntObject createInDefaultRealmWithValue:@[@10]];
    [IntObject createInDefaultRealmWithValue:@[@20]];
    [realm commitWriteTransaction];

    XCTAssertEqual(10, [IntObject.allObjects.firstObject intCol]);
    XCTAssertEqual(10, [[IntObject objectsWhere:@"intCol > 5"].firstObject intCol]);
    XCTAssertEqual(20, [[IntObject objectsWhere:@"intCol > 10"].firstObject intCol]);
}

- (void)testLast {
    XCTAssertNil(IntObject.allObjects.lastObject);
    XCTAssertNil([IntObject objectsWhere:@"intCol > 5"].lastObject);

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [IntObject createInDefaultRealmWithValue:@[@20]];
    [IntObject createInDefaultRealmWithValue:@[@10]];
    [realm commitWriteTransaction];

    XCTAssertEqual(10, [IntObject.allObjects.lastObject intCol]);
    XCTAssertEqual(10, [[IntObject objectsWhere:@"intCol > 5"].lastObject intCol]);
    XCTAssertEqual(20, [[IntObject objectsWhere:@"intCol > 10"].lastObject intCol]);
}

- (void)testSubscript {
    RLMAssertThrowsWithReasonMatching([IntObject allObjects][0], @"0.*less than 0");
    RLMAssertThrowsWithReasonMatching([IntObject objectsWhere:@"intCol > 5"][0], @"0.*less than 0");

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [IntObject createInDefaultRealmWithValue:@[@10]];
    [IntObject createInDefaultRealmWithValue:@[@20]];
    [realm commitWriteTransaction];

    XCTAssertEqual(10, [IntObject.allObjects[0] intCol]);
    XCTAssertEqual(10, [[IntObject objectsWhere:@"intCol > 5"][0] intCol]);
    XCTAssertEqual(20, [[IntObject objectsWhere:@"intCol > 10"][0] intCol]);

    RLMAssertThrowsWithReasonMatching([IntObject allObjects][2], @"2.*less than 2");
    RLMAssertThrowsWithReasonMatching([IntObject objectsWhere:@"intCol > 5"][2], @"2.*less than 2");
}

- (void)testObjectsAtIndexes {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet new];
    [indexSet addIndex:0];
    [indexSet addIndex:1];

    XCTAssertNil([[IntObject allObjects] objectsAtIndexes:indexSet]);
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [IntObject createInDefaultRealmWithValue:@[@10]];
    [IntObject createInDefaultRealmWithValue:@[@20]];
    [realm commitWriteTransaction];

    XCTAssertEqual([[[IntObject allObjects] objectsAtIndexes:indexSet][0] intCol], 10);
    XCTAssertEqual([[[IntObject allObjects] objectsAtIndexes:indexSet][1] intCol], 20);

    [indexSet addIndex:3];
    XCTAssertNil([[IntObject allObjects] objectsAtIndexes:indexSet]);
    XCTAssertNil([[IntObject allObjects] objectsAtIndexes:indexSet]);
}

- (void)testValueForKey {
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];

    XCTAssertEqualObjects([[AggregateObject allObjectsInRealm:realm] valueForKey:@"intCol"], @[]);

    NSDate *dateMinInput = [NSDate date];
    NSDate *dateMaxInput = [dateMinInput dateByAddingTimeInterval:1000];

    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];

    XCTAssertEqualObjects([[AggregateObject allObjectsInRealm:realm] valueForKey:@"intCol"],
                          (@[@0, @1, @0, @1, @0, @1, @0, @1, @0, @0]));
    XCTAssertTrue([[[[AggregateObject allObjectsInRealm:realm] valueForKey:@"self"] firstObject]
                   isEqualToObject:[AggregateObject allObjectsInRealm:realm].firstObject]);
    XCTAssertTrue([[[[AggregateObject allObjectsInRealm:realm] valueForKey:@"self"] lastObject]
                   isEqualToObject:[AggregateObject allObjectsInRealm:realm].lastObject]);

    XCTAssertEqualObjects([[AggregateObject objectsInRealm:realm where:@"intCol != 1"] valueForKey:@"intCol"],
                          (@[@0, @0, @0, @0, @0, @0]));
    XCTAssertTrue([[[[AggregateObject objectsInRealm:realm where:@"intCol != 1"] valueForKey:@"self"] firstObject]
                   isEqualToObject:[AggregateObject objectsInRealm:realm where:@"intCol != 1"].firstObject]);
    XCTAssertTrue([[[[AggregateObject objectsInRealm:realm where:@"intCol != 1"] valueForKey:@"self"] lastObject]
                   isEqualToObject:[AggregateObject objectsInRealm:realm where:@"intCol != 1"].lastObject]);

    [realm commitWriteTransaction];

    XCTAssertEqualObjects([[AggregateObject allObjectsInRealm:realm] valueForKey:@"intCol"],
                          (@[@0, @1, @0, @1, @0, @1, @0, @1, @0, @0]));
    XCTAssertEqualObjects([[AggregateObject objectsInRealm:realm where:@"intCol != 1"] valueForKey:@"intCol"],
                          (@[@0, @0, @0, @0, @0, @0]));

    XCTAssertThrows([[AggregateObject allObjectsInRealm:realm] valueForKey:@"invalid"]);
}

- (void)testSetValueForKey {
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];

    NSDate *dateMinInput = [NSDate date];
    NSDate *dateMaxInput = [dateMinInput dateByAddingTimeInterval:1000];

    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput]];

    [[AggregateObject allObjectsInRealm:realm] setValue:@25 forKey:@"intCol"];
    XCTAssertEqualObjects([[AggregateObject allObjectsInRealm:realm] valueForKey:@"intCol"],
                          (@[@25, @25, @25, @25, @25, @25, @25, @25, @25, @25]));

    [[AggregateObject objectsInRealm:realm where:@"floatCol > 1"] setValue:@10 forKey:@"intCol"];
    XCTAssertEqualObjects([[AggregateObject objectsInRealm:realm where:@"floatCol > 1"] valueForKey:@"intCol"],
                          (@[@10, @10, @10, @10, @10, @10]));

    XCTAssertThrows([[AggregateObject allObjectsInRealm:realm] valueForKey:@"invalid"]);

    [[AggregateObject objectsInRealm:realm where:@"intCol != 5"] setValue:@5 forKey:@"intCol"];
    XCTAssertEqualObjects([[AggregateObject allObjectsInRealm:realm] valueForKey:@"intCol"],
                          (@[@5, @5, @5, @5, @5, @5, @5, @5, @5, @5]));

    [realm commitWriteTransaction];

    RLMAssertThrowsWithReasonMatching([[AggregateObject allObjectsInRealm:realm] setValue:@25 forKey:@"intCol"],
                                      @"write transaction");
    RLMAssertThrowsWithReasonMatching([[AggregateObject objectsInRealm:realm where:@"floatCol > 1"] setValue:@10 forKey:@"intCol"],
                                      @"write transaction");
}

- (void)testObjectAggregate
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    RLMResults *noArray = [AggregateObject objectsWhere:@"boolCol == NO"];
    RLMResults *yesArray = [AggregateObject objectsWhere:@"boolCol == YES"];
    RLMResults *allArray = [AggregateObject allObjects];

    XCTAssertEqual(0, [noArray sumOfProperty:@"intCol"].intValue);
    XCTAssertEqual(0, [allArray sumOfProperty:@"intCol"].intValue);

    XCTAssertNil([noArray averageOfProperty:@"intCol"]);
    XCTAssertNil([allArray averageOfProperty:@"intCol"]);
    XCTAssertNil([noArray minOfProperty:@"intCol"]);
    XCTAssertNil([allArray minOfProperty:@"intCol"]);
    XCTAssertNil([noArray maxOfProperty:@"intCol"]);
    XCTAssertNil([allArray maxOfProperty:@"intCol"]);

    [realm beginWriteTransaction];

    NSDate *dateMinInput = [NSDate date];
    NSDate *dateMaxInput = [dateMinInput dateByAddingTimeInterval:1000];

    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput, @0.0]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput, @2.5]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput, @0.0]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput, @2.5]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput, @0.0]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput, @2.5]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput, @0.0]];
    [AggregateObject createInRealm:realm withValue:@[@1, @0.0f, @2.5, @NO, dateMaxInput, @2.5]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput, @0.0]];
    [AggregateObject createInRealm:realm withValue:@[@0, @1.2f, @0.0, @YES, dateMinInput, @0.0]];

    [realm commitWriteTransaction];

    // SUM ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int sum
    XCTAssertEqual([noArray sumOfProperty:@"intCol"].integerValue, 4);
    XCTAssertEqual([yesArray sumOfProperty:@"intCol"].integerValue, 0);
    XCTAssertEqual([allArray sumOfProperty:@"intCol"].integerValue, 4);

    // Test float sum
    XCTAssertEqualWithAccuracy([noArray sumOfProperty:@"floatCol"].floatValue, 0.0f, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray sumOfProperty:@"floatCol"].floatValue, 7.2f, 0.1f);
    XCTAssertEqualWithAccuracy([allArray sumOfProperty:@"floatCol"].floatValue, 7.2f, 0.1f);

    // Test double sum
    XCTAssertEqualWithAccuracy([noArray sumOfProperty:@"doubleCol"].doubleValue, 10.0, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray sumOfProperty:@"doubleCol"].doubleValue, 0.0, 0.1f);
    XCTAssertEqualWithAccuracy([allArray sumOfProperty:@"doubleCol"].doubleValue, 10.0, 0.1f);

    // Test RLMValue sum
    XCTAssertEqualWithAccuracy([noArray sumOfProperty:@"anyCol"].doubleValue, 10.0, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray sumOfProperty:@"anyCol"].doubleValue, 0.0, 0.1f);
    XCTAssertEqualWithAccuracy([allArray sumOfProperty:@"anyCol"].doubleValue, 10.0, 0.1f);

    // Test invalid column name
    RLMAssertThrowsWithReasonMatching([yesArray sumOfProperty:@"foo"], @"foo.*AggregateObject");
    RLMAssertThrowsWithReasonMatching([allArray sumOfProperty:@"foo"], @"foo.*AggregateObject");

    // Test operation not supported
    RLMAssertThrowsWithReasonMatching([yesArray sumOfProperty:@"boolCol"], @"sum.*bool");
    RLMAssertThrowsWithReasonMatching([allArray sumOfProperty:@"boolCol"], @"sum.*bool");


    // Average ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"intCol"].doubleValue, 1.0, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"intCol"].doubleValue, 0.0, 0.1f);
    XCTAssertEqualWithAccuracy([allArray averageOfProperty:@"intCol"].doubleValue, 0.4, 0.1f);

    // Test float average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"floatCol"].doubleValue, 0.0, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"floatCol"].doubleValue, 1.2, 0.1f);
    XCTAssertEqualWithAccuracy([allArray averageOfProperty:@"floatCol"].doubleValue, 0.72, 0.1f);

    // Test double average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"doubleCol"].doubleValue, 2.5, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"doubleCol"].doubleValue, 0.0, 0.1f);
    XCTAssertEqualWithAccuracy([allArray averageOfProperty:@"doubleCol"].doubleValue, 1.0, 0.1f);

    // Test RLMValue average
    XCTAssertEqualWithAccuracy([noArray averageOfProperty:@"anyCol"].doubleValue, 2.5, 0.1f);
    XCTAssertEqualWithAccuracy([yesArray averageOfProperty:@"anyCol"].doubleValue, 0.0, 0.1f);
    XCTAssertEqualWithAccuracy([allArray averageOfProperty:@"anyCol"].doubleValue, 1.0, 0.1f);

    // Test invalid column name
    RLMAssertThrowsWithReasonMatching([yesArray averageOfProperty:@"foo"], @"foo.*AggregateObject");
    RLMAssertThrowsWithReasonMatching([allArray averageOfProperty:@"foo"], @"foo.*AggregateObject");

    // Test operation not supported
    RLMAssertThrowsWithReasonMatching([yesArray averageOfProperty:@"boolCol"], @"average.*bool");
    RLMAssertThrowsWithReasonMatching([allArray averageOfProperty:@"boolCol"], @"average.*bool");

    // MIN ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int min
    XCTAssertEqual(1, [[noArray minOfProperty:@"intCol"] intValue]);
    XCTAssertEqual(0, [[yesArray minOfProperty:@"intCol"] intValue]);
    XCTAssertEqual(0, [[allArray minOfProperty:@"intCol"] intValue]);

    // Test float min
    XCTAssertEqual(0.0f, [[noArray minOfProperty:@"floatCol"] floatValue]);
    XCTAssertEqual(1.2f, [[yesArray minOfProperty:@"floatCol"] floatValue]);
    XCTAssertEqual(0.0f, [[allArray minOfProperty:@"floatCol"] floatValue]);

    // Test double min
    XCTAssertEqual(2.5, [[noArray minOfProperty:@"doubleCol"] doubleValue]);
    XCTAssertEqual(0.0, [[yesArray minOfProperty:@"doubleCol"] doubleValue]);
    XCTAssertEqual(0.0, [[allArray minOfProperty:@"doubleCol"] doubleValue]);

    // Test RLMValue min
    XCTAssertEqual(2.5, [[noArray minOfProperty:@"anyCol"] doubleValue]);
    XCTAssertEqual(0.0, [[yesArray minOfProperty:@"anyCol"] doubleValue]);
    XCTAssertEqual(0.0, [[allArray minOfProperty:@"anyCol"] doubleValue]);

    // Test date min
    XCTAssertEqualObjects(dateMaxInput, [noArray minOfProperty:@"dateCol"]);
    XCTAssertEqualObjects(dateMinInput, [yesArray minOfProperty:@"dateCol"]);
    XCTAssertEqualObjects(dateMinInput, [allArray minOfProperty:@"dateCol"]);

    // Test invalid column name
    RLMAssertThrowsWithReasonMatching([yesArray minOfProperty:@"foo"], @"foo.*AggregateObject");
    RLMAssertThrowsWithReasonMatching([allArray minOfProperty:@"foo"], @"foo.*AggregateObject");

    // Test operation not supported
    RLMAssertThrowsWithReasonMatching([yesArray minOfProperty:@"boolCol"], @"min.*bool");
    RLMAssertThrowsWithReasonMatching([allArray minOfProperty:@"boolCol"], @"min.*bool");

    // MAX ::::::::::::::::::::::::::::::::::::::::::::::
    // Test int max
    XCTAssertEqual(1, [[noArray maxOfProperty:@"intCol"] intValue]);
    XCTAssertEqual(0, [[yesArray maxOfProperty:@"intCol"] intValue]);
    XCTAssertEqual(1, [[allArray maxOfProperty:@"intCol"] intValue]);

    // Test float max
    XCTAssertEqual(0.0f, [[noArray maxOfProperty:@"floatCol"] floatValue]);
    XCTAssertEqual(1.2f, [[yesArray maxOfProperty:@"floatCol"] floatValue]);
    XCTAssertEqual(1.2f, [[allArray maxOfProperty:@"floatCol"] floatValue]);

    // Test double max
    XCTAssertEqual(2.5, [[noArray maxOfProperty:@"doubleCol"] doubleValue]);
    XCTAssertEqual(0.0, [[yesArray maxOfProperty:@"doubleCol"] doubleValue]);
    XCTAssertEqual(2.5, [[allArray maxOfProperty:@"doubleCol"] doubleValue]);

    // Test RLMValue max
    XCTAssertEqual(2.5, [[noArray maxOfProperty:@"anyCol"] doubleValue]);
    XCTAssertEqual(0.0, [[yesArray maxOfProperty:@"anyCol"] doubleValue]);
    XCTAssertEqual(2.5, [[allArray maxOfProperty:@"anyCol"] doubleValue]);

    // Test date max
    XCTAssertEqualObjects(dateMaxInput, [noArray maxOfProperty:@"dateCol"]);
    XCTAssertEqualObjects(dateMinInput, [yesArray maxOfProperty:@"dateCol"]);
    XCTAssertEqualObjects(dateMaxInput, [allArray maxOfProperty:@"dateCol"]);

    // Test invalid column name
    RLMAssertThrowsWithReasonMatching([yesArray maxOfProperty:@"foo"], @"foo.*AggregateObject");
    RLMAssertThrowsWithReasonMatching([allArray maxOfProperty:@"foo"], @"foo.*AggregateObject");

    // Test operation not supported
    RLMAssertThrowsWithReasonMatching([yesArray maxOfProperty:@"boolCol"], @"max.*bool");
    RLMAssertThrowsWithReasonMatching([allArray maxOfProperty:@"boolCol"], @"max.*bool");
}

- (void)testRenamedPropertyAggregate {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RLMResults *results = [RenamedProperties1 allObjectsInRealm:realm];
    XCTAssertEqual(0, [results sumOfProperty:@"propA"].intValue);
    XCTAssertNil([results averageOfProperty:@"propA"]);
    XCTAssertNil([results minOfProperty:@"propA"]);
    XCTAssertNil([results maxOfProperty:@"propA"]);
    XCTAssertThrows([results sumOfProperty:@"prop 1"]);

    [realm transactionWithBlock:^{
        [RenamedProperties1 createInRealm:realm withValue:@[@1, @""]];
        [RenamedProperties1 createInRealm:realm withValue:@[@2, @""]];
        [RenamedProperties1 createInRealm:realm withValue:@[@3, @""]];
    }];

    XCTAssertEqual(6, [results sumOfProperty:@"propA"].intValue);
    XCTAssertEqual(2.0, [results averageOfProperty:@"propA"].doubleValue);
    XCTAssertEqual(1, [[results minOfProperty:@"propA"] intValue]);
    XCTAssertEqual(3, [[results maxOfProperty:@"propA"] intValue]);
}


- (void)testValueForCollectionOperationKeyPath {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    EmployeeObject *c1e1 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @40, @"hired": @YES}];
    EmployeeObject *c1e2 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"John", @"age": @30, @"hired": @NO}];
    EmployeeObject *c1e3 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Jill", @"age": @25, @"hired": @YES}];
    [CompanyObject createInRealm:realm withValue:@{@"name": @"InspiringNames LLC", @"employees": @[c1e1, c1e2, c1e3], @"employeeSet": @[c1e1, c1e2, c1e3]}];

    EmployeeObject *c2e1 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"A", @"age": @20, @"hired": @YES}];
    EmployeeObject *c2e2 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"B", @"age": @30, @"hired": @NO}];
    EmployeeObject *c2e3 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"C", @"age": @40, @"hired": @YES}];
    [CompanyObject createInRealm:realm withValue:@{@"name": @"ABC AG", @"employees": @[c2e1, c2e2, c2e3], @"employeeSet": @[c2e1, c2e2, c2e3]}];

    EmployeeObject *c3e1 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"A", @"age": @21, @"hired": @YES}];
    [CompanyObject createInRealm:realm withValue:@{@"name": @"ABC AG", @"employees": @[c3e1], @"employeeSet": @[c3e1]}];
    [realm commitWriteTransaction];

    RLMResults *allCompanies = [CompanyObject allObjects];
    RLMResults *allEmployees = [EmployeeObject allObjects];

    // count operator
    XCTAssertEqual([[allCompanies valueForKeyPath:@"@count"] integerValue], 3);

    // numeric operators
    XCTAssertEqual([[allEmployees valueForKeyPath:@"@min.age"] intValue], 20);
    XCTAssertEqual([[allEmployees valueForKeyPath:@"@max.age"] intValue], 40);
    XCTAssertEqual([[allEmployees valueForKeyPath:@"@sum.age"] integerValue], 206);
    XCTAssertEqualWithAccuracy([[allEmployees valueForKeyPath:@"@avg.age"] doubleValue], 29.43, 0.1f);

    // collection
    XCTAssertEqualObjects([allCompanies valueForKeyPath:@"@unionOfObjects.name"],
                          (@[@"InspiringNames LLC", @"ABC AG", @"ABC AG"]));
    XCTAssertEqualObjects([allCompanies valueForKeyPath:@"@distinctUnionOfObjects.name"],
                          (@[@"ABC AG", @"InspiringNames LLC"]));
    XCTAssertEqualObjects([allCompanies valueForKeyPath:@"employees.@unionOfArrays.name"],
                          (@[@"Joe", @"John", @"Jill", @"A", @"B", @"C", @"A"]));
    XCTAssertEqualObjects([[allCompanies valueForKeyPath:@"employees.@distinctUnionOfArrays.name"]
                           sortedArrayUsingSelector:@selector(compare:)],
                          (@[@"A", @"B", @"C", @"Jill", @"Joe", @"John"]));

    // invalid key paths
    RLMAssertThrowsWithReasonMatching([allCompanies valueForKeyPath:@"@invalid.name"],
                                      @"Unsupported KVC collection operator found in key path '@invalid.name'");
    RLMAssertThrowsWithReasonMatching([allCompanies valueForKeyPath:@"@sum"],
                                      @"Missing key path for KVC collection operator sum in key path '@sum'");
    RLMAssertThrowsWithReasonMatching([allCompanies valueForKeyPath:@"@sum."],
                                      @"Missing key path for KVC collection operator sum in key path '@sum.'");
    RLMAssertThrowsWithReasonMatching([allCompanies valueForKeyPath:@"@sum.employees.@sum.age"],
                                      @"Nested key paths.*not supported");
}

- (void)testArrayDescription
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    for (NSInteger i = 0; i < 1012; ++i) {
        EmployeeObject *person = [[EmployeeObject alloc] init];
        person.name = @"Mary";
        person.age = 24;
        person.hired = YES;
        [realm addObject:person];
    }
    [realm commitWriteTransaction];

    NSString *description = [[EmployeeObject allObjects] description];

    XCTAssertTrue([description rangeOfString:@"name"].location != NSNotFound);
    XCTAssertTrue([description rangeOfString:@"Mary"].location != NSNotFound);

    XCTAssertTrue([description rangeOfString:@"age"].location != NSNotFound);
    XCTAssertTrue([description rangeOfString:@"24"].location != NSNotFound);

    XCTAssertTrue([description rangeOfString:@"912 objects skipped"].location != NSNotFound);
}

- (void)testIndexOfObject
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    EmployeeObject *po1 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @40, @"hired": @YES}];
    EmployeeObject *po2 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"John", @"age": @30, @"hired": @NO}];
    EmployeeObject *po3 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Jill", @"age": @25, @"hired": @YES}];
    StringObject *so = [StringObject createInRealm:realm withValue:@[@""]];
    StringObject *deletedObject = [StringObject createInRealm:realm withValue:@[@""]];
    [realm deleteObject:deletedObject];
    [realm commitWriteTransaction];

    EmployeeObject *unmanaged = [[EmployeeObject alloc] init];

    RLMResults *results = [EmployeeObject objectsWhere:@"hired = YES"];
    XCTAssertEqual(0U, [results indexOfObject:po1]);
    XCTAssertEqual(1U, [results indexOfObject:po3]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:po2]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:unmanaged]);
    RLMAssertThrowsWithReasonMatching([results indexOfObject:so], @"StringObject.*EmployeeObject");
    RLMAssertThrowsWithReasonMatching([results indexOfObject:deletedObject], @"Object has been deleted or invalidated");

    [results lastObject]; // Force to tableview mode
    XCTAssertEqual(0U, [results indexOfObject:po1]);
    XCTAssertEqual(1U, [results indexOfObject:po3]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:po2]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:unmanaged]);
    RLMAssertThrowsWithReasonMatching([results indexOfObject:so], @"StringObject.*EmployeeObject");
    RLMAssertThrowsWithReasonMatching([results indexOfObject:deletedObject], @"Object has been deleted or invalidated");

    // reverse order from sort
    results = [[EmployeeObject objectsWhere:@"hired = YES"] sortedResultsUsingKeyPath:@"age" ascending:YES];
    XCTAssertEqual(1U, [results indexOfObject:po1]);
    XCTAssertEqual(0U, [results indexOfObject:po3]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:po2]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:unmanaged]);
    RLMAssertThrowsWithReasonMatching([results indexOfObject:so], @"StringObject.*EmployeeObject");
    RLMAssertThrowsWithReasonMatching([results indexOfObject:deletedObject], @"Object has been deleted or invalidated");

    results = [EmployeeObject allObjects];
    XCTAssertEqual(0U, [results indexOfObject:po1]);
    XCTAssertEqual(1U, [results indexOfObject:po2]);
    XCTAssertEqual(2U, [results indexOfObject:po3]);
    XCTAssertEqual((NSUInteger)NSNotFound, [results indexOfObject:unmanaged]);
    RLMAssertThrowsWithReasonMatching([results indexOfObject:so], @"StringObject.*EmployeeObject");
    RLMAssertThrowsWithReasonMatching([results indexOfObject:deletedObject], @"Object has been deleted or invalidated");
}

- (void)testIndexOfObjectWhere
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @40, @"hired": @YES}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"John", @"age": @30, @"hired": @NO}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Jill", @"age": @25, @"hired": @YES}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Phil", @"age": @38, @"hired": @NO}];
    [realm commitWriteTransaction];

    RLMResults *results = [EmployeeObject objectsWhere:@"hired = YES"];
    XCTAssertEqual(0U, ([results indexOfObjectWhere:@"age = %d", 40]));
    XCTAssertEqual(1U, ([results indexOfObjectWhere:@"age = %d", 25]));
    XCTAssertEqual((NSUInteger)NSNotFound, ([results indexOfObjectWhere:@"age = %d", 30]));

    results = [EmployeeObject allObjects];
    XCTAssertEqual(0U, ([results indexOfObjectWhere:@"age = %d", 40]));
    XCTAssertEqual(1U, ([results indexOfObjectWhere:@"age = %d", 30]));
    XCTAssertEqual(2U, ([results indexOfObjectWhere:@"age = %d", 25]));
    XCTAssertEqual((NSUInteger)NSNotFound, ([results indexOfObjectWhere:@"age = %d", 35]));

    results = [[EmployeeObject allObjects] sortedResultsUsingKeyPath:@"age" ascending:YES];
    NSUInteger youngestHired = [results indexOfObjectWhere:@"hired = YES"];
    XCTAssertEqual(0U, youngestHired);
    XCTAssertEqualObjects(@"Jill", [results[youngestHired] name]);
    NSUInteger youngestNotHired = [results indexOfObjectWhere:@"hired = NO"];
    XCTAssertEqual(1U, youngestNotHired);
    XCTAssertEqualObjects(@"John", [results[youngestNotHired] name]);
}

- (void)testSubqueryLifetime
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"John", @"age": @30, @"hired": @NO}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Jill",  @"age": @50, @"hired": @YES}];
    [realm commitWriteTransaction];

    RLMResults<EmployeeObject *> *subarray = nil;
    {
        __attribute((objc_precise_lifetime)) RLMResults *results = [EmployeeObject objectsWhere:@"hired = YES"];
        subarray = [results objectsWhere:@"age = 40"];
    }

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @40, @"hired": @YES}];
    [realm commitWriteTransaction];

    XCTAssertEqualObjects(@"Joe", subarray[0][@"name"]);
}

- (void)testMultiSortLifetime
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"John", @"age": @30, @"hired": @NO}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Jill",  @"age": @50, @"hired": @YES}];
    [realm commitWriteTransaction];

    RLMResults<EmployeeObject *> *subarray = nil;
    {
        __attribute((objc_precise_lifetime)) RLMResults *results = [[EmployeeObject allObjects] sortedResultsUsingKeyPath:@"age" ascending:YES];
        subarray = [results sortedResultsUsingKeyPath:@"age" ascending:NO];
    }

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @40, @"hired": @YES}];
    [realm commitWriteTransaction];

    XCTAssertEqual(3U, subarray.count);
    XCTAssertEqualObjects(@"Jill", subarray[0][@"name"]);
    XCTAssertEqualObjects(@"Joe", subarray[1][@"name"]);
    XCTAssertEqualObjects(@"John", subarray[2][@"name"]);
}

- (void)testSortingExistingQuery
{
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"A",  @"age": @20, @"hired": @YES}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"B", @"age": @30, @"hired": @NO}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"C", @"age": @40, @"hired": @YES}];
    [realm commitWriteTransaction];

    RLMResults *sortedAge = [[EmployeeObject allObjects] sortedResultsUsingKeyPath:@"age" ascending:YES];
    RLMResults *sortedName = [sortedAge sortedResultsUsingKeyPath:@"name" ascending:NO];

    XCTAssertEqual(20, [(EmployeeObject *)sortedAge[0] age]);
    XCTAssertEqual(40, [(EmployeeObject *)sortedName[0] age]);
}

- (void)testRerunningSortedQuery {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RLMResults *sortedAge = [[EmployeeObject allObjects] sortedResultsUsingKeyPath:@"age" ascending:YES];
    [sortedAge lastObject]; // Force creation of the TableView
    RLMResults *sortedName = [sortedAge sortedResultsUsingKeyPath:@"name" ascending:NO];
    [sortedName lastObject]; // Force creation of the TableView
    RLMResults *filtered = [sortedName objectsWhere:@"age > 20"];
    [filtered lastObject]; // Force creation of the TableView

    [realm beginWriteTransaction];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"A",  @"age": @20, @"hired": @YES}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"B", @"age": @30, @"hired": @NO}];
    [EmployeeObject createInRealm:realm withValue:@{@"name": @"C", @"age": @40, @"hired": @YES}];
    [realm commitWriteTransaction];

    XCTAssertEqual(3U, sortedAge.count);
    XCTAssertEqual(3U, sortedName.count);
    XCTAssertEqual(2U, filtered.count);

    XCTAssertEqual(20, [(EmployeeObject *)sortedAge[0] age]);
    XCTAssertEqual(30, [(EmployeeObject *)sortedAge[1] age]);
    XCTAssertEqual(40, [(EmployeeObject *)sortedAge[2] age]);

    XCTAssertEqual(40, [(EmployeeObject *)sortedName[0] age]);
    XCTAssertEqual(30, [(EmployeeObject *)sortedName[1] age]);
    XCTAssertEqual(20, [(EmployeeObject *)sortedName[2] age]);

    XCTAssertEqual(40, [(EmployeeObject *)filtered[0] age]);
    XCTAssertEqual(30, [(EmployeeObject *)filtered[1] age]);
}

- (void)testLiveUpdateFirst {
    RLMRealm *realm = self.realmWithTestPath;
    [realm beginWriteTransaction];
    [IntObject createInRealm:realm withValue:@[@0]];

    RLMResults *objects = [IntObject objectsInRealm:realm where:@"intCol = 0"];
    XCTAssertNotNil([objects firstObject]);
    [objects.firstObject setIntCol:1];
    XCTAssertNil([objects firstObject]);

    [realm cancelWriteTransaction];
}

- (void)testLiveUpdateLast {
    RLMRealm *realm = self.realmWithTestPath;
    [realm beginWriteTransaction];
    [IntObject createInRealm:realm withValue:@[@0]];

    RLMResults *objects = [IntObject objectsInRealm:realm where:@"intCol = 0"];
    XCTAssertNotNil([objects lastObject]);
    [objects.lastObject setIntCol:1];
    XCTAssertNil([objects lastObject]);

    [realm cancelWriteTransaction];
}

static vm_size_t get_resident_size() {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return info.resident_size;
}

- (void)testQueryMemoryUsage {
    RLMRealm *realm = [self realmWithTestPath];

    [realm beginWriteTransaction];
    StringObject *obj = [[StringObject alloc] init];
    obj.stringCol = @"a";
    [realm addObject:obj];
    [realm commitWriteTransaction];

    NSPredicate *pred = [NSPredicate predicateWithFormat:@"stringCol = 'a'"];

    // Check for memory leaks when creating queries by comparing the memory usage
    // before and after creating a very large number of queries. Anything less
    // than doubling is allowed as there's going to be some natural fluctuation,
    // and failing to clean up 10k queries resulted in far more than doubling.
    vm_size_t size = get_resident_size();
    for (int i = 0; i < 10000; ++i) {
        @autoreleasepool {
            RLMResults *matches = [StringObject objectsInRealm:realm withPredicate:pred];
            XCTAssertEqualObjects([matches[0] stringCol], @"a");
        }
    }
    XCTAssert(get_resident_size() < size * 2);
}

- (void)testDeleteAllObjects
{
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];
    [StringObject createInRealm:realm withValue:@[@"name1"]];
    [StringObject createInRealm:realm withValue:@[@"name2"]];
    [realm commitWriteTransaction];

    RLMResults *results = [StringObject objectsInRealm:realm where:@"stringCol = 'name1'"];
    RLMAssertThrowsWithReasonMatching([realm deleteObjects:results], @"write transaction");
    [realm beginWriteTransaction];
    [realm deleteObjects:results];
    [realm commitWriteTransaction];
    XCTAssertEqual(0U, results.count);
    XCTAssertEqual(1U, [StringObject allObjectsInRealm:realm].count);

    results = [StringObject allObjectsInRealm:realm];
    RLMAssertThrowsWithReasonMatching([realm deleteObjects:results], @"write transaction");
    [realm beginWriteTransaction];
    [realm deleteObjects:results];
    [realm commitWriteTransaction];
    XCTAssertEqual(0U, results.count);
    XCTAssertEqual(0U, [StringObject allObjectsInRealm:realm].count);
}

- (void)testEnumerateAndDeleteTableResults {
    RLMRealm *realm = self.realmWithTestPath;
    const int count = 40;

    [realm beginWriteTransaction];
    for (int i = 0; i < count; ++i) {
        [IntObject createInRealm:realm withValue:@[@(i)]];
    }

    int enumeratedCount = 0;
    for (IntObject *io in [IntObject allObjectsInRealm:realm]) {
        ++enumeratedCount;
        [realm deleteObject:io];
    }

    XCTAssertEqual(0U, [IntObject allObjectsInRealm:realm].count);
    XCTAssertEqual(count, enumeratedCount);

    [realm cancelWriteTransaction];
}

- (void)testEnumerateAndMutateQueryCondition {
    RLMRealm *realm = self.realmWithTestPath;
    const int count = 40;

    [realm beginWriteTransaction];
    for (int i = 0; i < count; ++i) {
        [IntObject createInRealm:realm withValue:@[@(0)]];
    }

    int enumeratedCount = 0;
    for (IntObject *io in [IntObject objectsInRealm:realm where:@"intCol = 0"]) {
        ++enumeratedCount;
        io.intCol = enumeratedCount;
    }

    XCTAssertEqual(0U, [IntObject objectsInRealm:realm where:@"intCol = 0"].count);
    XCTAssertEqual(count, enumeratedCount);

    [realm cancelWriteTransaction];
}

- (void)testManualRefreshDuringEnumeration {
    RLMRealm *realm = self.realmWithTestPath;
    const int count = 40;

    [realm beginWriteTransaction];
    for (int i = 0; i < count; ++i) {
        [IntObject createInRealm:realm withValue:@[@(0)]];
    }
    [realm commitWriteTransaction];

    realm.autorefresh = NO;
    [self dispatchAsyncAndWait:^{
        RLMRealm *realm = self.realmWithTestPath;
        [realm beginWriteTransaction];
        // FIXME: this is roundabout because `table.clear()` does not update
        // table views correctly
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
        [realm commitWriteTransaction];
    }];

    int enumeratedCount = 0;
    for (IntObject *io in [IntObject allObjectsInRealm:realm]) {
        [realm refresh];
        XCTAssertTrue(io.invalidated);
        ++enumeratedCount;
    }

    XCTAssertEqual(enumeratedCount, count);
}

- (void)testCallInvalidateDuringEnumeration {
    RLMRealm *realm = self.realmWithTestPath;
    const int count = 40;

    [realm beginWriteTransaction];
    for (int i = 0; i < count; ++i) {
        [IntObject createInRealm:realm withValue:@[@(0)]];
    }
    [realm commitWriteTransaction];

    int enumeratedCount = 0;
    @try {
        for (__unused IntObject *io in [IntObject objectsInRealm:realm where:@"intCol = 0"]) {
            ++enumeratedCount;
            [realm invalidate];
        }
        XCTFail(@"Should have thrown an exception");
    }
    @catch (NSException *e) {
        XCTAssertEqualObjects(e.reason, @"Collection is no longer valid");
    }
    XCTAssertEqual(16, enumeratedCount);

    // Also test with the enumeration done within a write transaction
    [realm beginWriteTransaction];
    enumeratedCount = 0;
    @try {
        for (__unused IntObject *io in [IntObject objectsInRealm:realm where:@"intCol = 0"]) {
            ++enumeratedCount;
            [realm invalidate];
        }
        XCTFail(@"Should have thrown an exception");
    }
    @catch (NSException *e) {
        XCTAssertEqualObjects(e.reason, @"Collection is no longer valid");
    }
    XCTAssertEqual(16, enumeratedCount);
}

- (void)testBeginWriteTransactionDuringEnumeration {
    RLMRealm *realm = self.realmWithTestPath;
    const int count = 40;

    [realm beginWriteTransaction];
    for (int i = 0; i < count; ++i) {
        [IntObject createInRealm:realm withValue:@[@(0)]];
    }
    [realm commitWriteTransaction];

    for (IntObject *io in [IntObject objectsInRealm:realm where:@"intCol = 0"]) {
        [realm beginWriteTransaction];
        io.intCol = 1;
        [realm commitWriteTransaction];
    }

    XCTAssertEqual(40U, [IntObject objectsInRealm:realm where:@"intCol = 1"].count);
}

- (void)testAllMethodsCheckThread {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [IntObject createInDefaultRealmWithValue:@[@0]];
    }];

    RLMResults *results = [IntObject allObjects];
    XCTAssertNoThrow([results isInvalidated]);
    XCTAssertNoThrow([results objectAtIndex:0]);
    XCTAssertNoThrow([results firstObject]);
    XCTAssertNoThrow([results lastObject]);
    XCTAssertNoThrow([results indexOfObject:[IntObject allObjects].firstObject]);
    XCTAssertNoThrow([results indexOfObjectWhere:@"intCol = 0"]);
    XCTAssertNoThrow([results indexOfObjectWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
    XCTAssertNoThrow([results objectsWhere:@"intCol = 0"]);
    XCTAssertNoThrow([results objectsWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
    XCTAssertNoThrow([results sortedResultsUsingKeyPath:@"intCol" ascending:YES]);
    XCTAssertNoThrow([results sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"intCol" ascending:YES]]]);
    XCTAssertNoThrow([results minOfProperty:@"intCol"]);
    XCTAssertNoThrow([results maxOfProperty:@"intCol"]);
    XCTAssertNoThrow([results sumOfProperty:@"intCol"]);
    XCTAssertNoThrow([results averageOfProperty:@"intCol"]);
    XCTAssertNoThrow(results[0]);
    XCTAssertNoThrow([results valueForKey:@"intCol"]);

    [self dispatchAsyncAndWait:^{
        XCTAssertThrows([results isInvalidated]);
        XCTAssertThrows([results objectAtIndex:0]);
        XCTAssertThrows([results firstObject]);
        XCTAssertThrows([results lastObject]);
        XCTAssertThrows([results indexOfObject:[IntObject allObjects].firstObject]);
        XCTAssertThrows([results indexOfObjectWhere:@"intCol = 0"]);
        XCTAssertThrows([results indexOfObjectWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
        XCTAssertThrows([results objectsWhere:@"intCol = 0"]);
        XCTAssertThrows([results objectsWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
        XCTAssertThrows([results sortedResultsUsingKeyPath:@"intCol" ascending:YES]);
        XCTAssertThrows([results sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"intCol" ascending:YES]]]);
        XCTAssertThrows([results minOfProperty:@"intCol"]);
        XCTAssertThrows([results maxOfProperty:@"intCol"]);
        XCTAssertThrows([results sumOfProperty:@"intCol"]);
        XCTAssertThrows([results averageOfProperty:@"intCol"]);
        XCTAssertThrows(results[0]);
        XCTAssertThrows([results valueForKey:@"intCol"]);
    }];
}

- (void)testAllMethodsCheckForInvalidation {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [IntObject createInDefaultRealmWithValue:@[@0]];
    }];

    RLMResults *results = [IntObject allObjects];
    XCTAssertFalse(results.isInvalidated);
    XCTAssertNoThrow([results objectAtIndex:0]);
    XCTAssertNoThrow([results firstObject]);
    XCTAssertNoThrow([results lastObject]);
    XCTAssertNoThrow([results indexOfObject:[IntObject allObjects].firstObject]);
    XCTAssertNoThrow([results indexOfObjectWhere:@"intCol = 0"]);
    XCTAssertNoThrow([results indexOfObjectWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
    XCTAssertNoThrow([results objectsWhere:@"intCol = 0"]);
    XCTAssertNoThrow([results objectsWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
    XCTAssertNoThrow([results sortedResultsUsingKeyPath:@"intCol" ascending:YES]);
    XCTAssertNoThrow([results sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"intCol" ascending:YES]]]);
    XCTAssertNoThrow([results minOfProperty:@"intCol"]);
    XCTAssertNoThrow([results maxOfProperty:@"intCol"]);
    XCTAssertNoThrow([results sumOfProperty:@"intCol"]);
    XCTAssertNoThrow([results averageOfProperty:@"intCol"]);
    XCTAssertNoThrow(results[0]);
    XCTAssertNoThrow([results valueForKey:@"intCol"]);
    XCTAssertNoThrow(({for (__unused id obj in results);}));

    [realm invalidate];

    XCTAssertTrue(results.isInvalidated);
    XCTAssertThrows([results objectAtIndex:0]);
    XCTAssertThrows([results firstObject]);
    XCTAssertThrows([results lastObject]);
    XCTAssertThrows([results indexOfObject:[IntObject allObjects].firstObject]);
    XCTAssertThrows([results indexOfObjectWhere:@"intCol = 0"]);
    XCTAssertThrows([results indexOfObjectWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
    XCTAssertThrows([results objectsWhere:@"intCol = 0"]);
    XCTAssertThrows([results objectsWithPredicate:[NSPredicate predicateWithFormat:@"intCol = 0"]]);
    XCTAssertThrows([results sortedResultsUsingKeyPath:@"intCol" ascending:YES]);
    XCTAssertThrows([results sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"intCol" ascending:YES]]]);
    XCTAssertThrows([results minOfProperty:@"intCol"]);
    XCTAssertThrows([results maxOfProperty:@"intCol"]);
    XCTAssertThrows([results sumOfProperty:@"intCol"]);
    XCTAssertThrows([results averageOfProperty:@"intCol"]);
    XCTAssertThrows(results[0]);
    XCTAssertThrows([results valueForKey:@"intCol"]);
    XCTAssertThrows(({for (__unused id obj in results);}));
}

- (void)testResultsDependingOnDeletedLinkView {
    RLMRealm *realm = [RLMRealm defaultRealm];
    __block IntegerArrayPropertyObject *arrayObject;
    __block IntegerSetPropertyObject *setObject;
    [realm transactionWithBlock:^{
        IntObject* intObject = [IntObject createInDefaultRealmWithValue:@[@0]];
        arrayObject = [IntegerArrayPropertyObject createInDefaultRealmWithValue:@[ @0, @[ intObject ] ]];
        setObject = [IntegerSetPropertyObject createInDefaultRealmWithValue:@[ @0, @[ intObject ] ]];
    }];

    RLMResults *arrayResults = [arrayObject.array sortedResultsUsingKeyPath:@"intCol" ascending:YES];
    [arrayResults firstObject];

    RLMResults *unevaluatedResults = [arrayObject.array sortedResultsUsingKeyPath:@"intCol" ascending:YES];

    [realm transactionWithBlock:^{
        [realm deleteObject:arrayObject];
    }];

    XCTAssertFalse(arrayResults.isInvalidated);
    XCTAssertFalse(unevaluatedResults.isInvalidated);

    XCTAssertEqual(0u, arrayResults.count);
    XCTAssertEqual(0u, unevaluatedResults.count);

    XCTAssertEqualObjects(nil, arrayResults.firstObject);
    XCTAssertEqualObjects(nil, unevaluatedResults.firstObject);

    RLMResults *setResults = [setObject.set sortedResultsUsingKeyPath:@"intCol" ascending:YES];
    [setResults firstObject];

    RLMResults *unevaluatedResults2 = [setObject.set sortedResultsUsingKeyPath:@"intCol" ascending:YES];

    [realm transactionWithBlock:^{
        [realm deleteObject:setObject];
    }];

    XCTAssertFalse(setResults.isInvalidated);
    XCTAssertFalse(unevaluatedResults2.isInvalidated);

    XCTAssertEqual(0u, setResults.count);
    XCTAssertEqual(0u, unevaluatedResults2.count);

    XCTAssertEqualObjects(nil, setResults.firstObject);
    XCTAssertEqualObjects(nil, unevaluatedResults2.firstObject);
}

- (void)testResultsDependingOnDeletedTableView {
    RLMRealm *realm = [RLMRealm defaultRealm];
    __block DogObject *dog;
    [realm transactionWithBlock:^{
        dog = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        [OwnerObject createInDefaultRealmWithValue:@[ @"John", dog ]];
    }];

    RLMResults *results = [dog.owners objectsWhere:@"name != 'Not a real name'"];
    [results firstObject];

    RLMResults *unevaluatedResults = [dog.owners objectsWhere:@"name != 'Not a real name'"];

    [realm transactionWithBlock:^{
        [realm deleteObject:dog];
    }];

    XCTAssertFalse(results.isInvalidated);
    XCTAssertFalse(unevaluatedResults.isInvalidated);

    XCTAssertEqual(0u, results.count);
    XCTAssertEqual(0u, unevaluatedResults.count);

    XCTAssertEqualObjects(nil, results.firstObject);
    XCTAssertEqualObjects(nil, unevaluatedResults.firstObject);
}

- (void)testResultsDependingOnLinkingObjects {
    RLMRealm *realm = [RLMRealm defaultRealm];
    __block DogObject *dog;
    __block OwnerObject *owner;
    [realm transactionWithBlock:^{
        dog = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        owner = [OwnerObject createInDefaultRealmWithValue:@[ @"John", dog ]];
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    RLMResults *results = [DogObject objectsWhere:@"ANY owners.name == 'James'"];
    id token = [results addNotificationBlock:^(__unused RLMResults *results, RLMCollectionChange *change, __unused NSError *error) {
        if (change != nil) {
            [expectation fulfill];
        }
        CFRunLoopStop(CFRunLoopGetCurrent());
    }];
    // Consume the initial notification.
    CFRunLoopRun();

    XCTAssertEqual(0u, results.count);
    XCTAssertNil(results.firstObject);

    [realm transactionWithBlock:^{
        owner.name = @"James";
    }];

    XCTAssertEqual(1u, results.count);
    XCTAssertEqualObjects(dog.dogName, [results.firstObject dogName]);

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    token = nil;
}

- (void)testDistinctQuery {
    RLMRealm *realm = [RLMRealm defaultRealm];
    __block DogObject *fido;
    __block DogObject *cujo;
    __block DogObject *buster;
    [realm transactionWithBlock:^{
        fido = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        cujo = [DogObject createInDefaultRealmWithValue:@[ @"Cujo", @3 ]];
        buster = [DogObject createInDefaultRealmWithValue:@[ @"Buster", @5 ]];
    }];
    
    RLMResults *results = [[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"age"]];
    NSMutableArray *ages = NSMutableArray.new;
    for (id result in results) {
        [ages addObject: result];
    }
    XCTAssertEqual(2u, results.count);
    XCTAssertEqualObjects([ages valueForKey:@"age"], (@[@3, @5]));
}
- (void)testDistinctQueryWithMultipleKeyPaths {
    RLMRealm *realm = [RLMRealm defaultRealm];
    __block DogObject *fido;
    __block DogObject *fido2;
    __block DogObject *fido3;
    __block DogObject *cujo;
    __block DogObject *buster;
    __block DogObject *buster2;
    __block DogObject *rotunda;
    
    [realm transactionWithBlock:^{
        fido = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        fido2 = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        fido3 = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @4 ]];
        cujo = [DogObject createInDefaultRealmWithValue:@[ @"Cujo", @3 ]];
        buster = [DogObject createInDefaultRealmWithValue:@[ @"Buster", @3 ]];
        buster2 = [DogObject createInDefaultRealmWithValue:@[ @"Buster", @3 ]];
        rotunda = [DogObject createInDefaultRealmWithValue:@[ @"Rotunda", @7 ]];
    }];
    
    RLMResults *results = [[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"dogName", @"age"]];
    NSMutableArray *resultsArr = NSMutableArray.new;
    for (DogObject *result in results) {
        [resultsArr addObject:[NSString stringWithFormat:@"%@/%@", result.dogName, @(result.age)]];
    }
    
    XCTAssertEqualObjects(resultsArr, (@[@"Fido/3", @"Fido/4", @"Cujo/3", @"Buster/3", @"Rotunda/7"]));
}
- (void)testDistinctQueryWithMultilevelKeyPath {
    RLMRealm *realm = [RLMRealm defaultRealm];
    __block OwnerObject *owner1;
    __block OwnerObject *owner2;
    __block OwnerObject *owner3;
    __block DogObject *dog1;
    __block DogObject *dog2;
    __block DogObject *dog3;
    
    [realm transactionWithBlock:^{
        dog1 = [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        dog2 = [DogObject createInDefaultRealmWithValue:@[ @"Cujo", @3 ]];
        dog3 = [DogObject createInDefaultRealmWithValue:@[ @"Rotunda", @7 ]];
        
        owner1 = [OwnerObject createInDefaultRealmWithValue:@[ @"Joe", dog1 ]];
        owner2 = [OwnerObject createInDefaultRealmWithValue:@[ @"Marie", dog2 ]];
        owner3 = [OwnerObject createInDefaultRealmWithValue:@[ @"Marie", dog3 ]];
    }];
    
    RLMResults *results = [[OwnerObject allObjects] distinctResultsUsingKeyPaths:@[@"dog.age"]];
    NSMutableArray *resultsArr = NSMutableArray.new;
    for (OwnerObject *result in results) {
        [resultsArr addObject:@(result.dog.age)];
    }
    XCTAssertEqualObjects(resultsArr, (@[@3, @7]));
}

- (void)testDistinctQueryThrowsInvalidKeyPathsSpecified {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        [DogObject createInDefaultRealmWithValue:@[ @"Fido", @3 ]];
        [DogObject createInDefaultRealmWithValue:@[ @"Fido", @5 ]];
        AggregateObject *ao1 = [AggregateObject createInDefaultRealmWithValue:@[ @0 ]];
        AggregateObject *ao2 = [AggregateObject createInDefaultRealmWithValue:@[ @0 ]];
        [AggregateArrayObject createInDefaultRealmWithValue:@[@[ao1, ao2]]];
        [AggregateSetObject createInDefaultRealmWithValue:@[@[ao1, ao2]]];
        [AllTypesObject createInDefaultRealmWithValue:@[]];
    }];
    
    XCTAssertThrows([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@""]]);
    XCTAssertThrows([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@" "]]);
    XCTAssertThrows([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"\n"]]);
    XCTAssertThrows(([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"dogName", @""]]));
    XCTAssertThrows(([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"dogName", @" "]]));
    XCTAssertThrows(([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"dogName", @"\n"]]));
    XCTAssertThrows(([[DogObject allObjects] distinctResultsUsingKeyPaths:@[@"@max.age"]]));
    XCTAssertThrows([[AllTypesObject allObjects] distinctResultsUsingKeyPaths:@[@"linkingObjectsCol"]]);
    XCTAssertThrows([[AllTypesObject allObjects] distinctResultsUsingKeyPaths:@[@"objectCol"]]);
    XCTAssertThrows([[AggregateArrayObject allObjects] distinctResultsUsingKeyPaths:@[@"array"]]);
    XCTAssertThrows([[AggregateSetObject allObjects] distinctResultsUsingKeyPaths:@[@"set"]]);
}

#pragma mark - Frozen Results

static RLMResults<IntObject *> *testResults() {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [IntObject createInDefaultRealmWithValue:@[@0]];
        [IntObject createInDefaultRealmWithValue:@[@1]];
        [IntObject createInDefaultRealmWithValue:@[@2]];
    }];

    return [IntObject allObjects];
}

- (void)testIsFrozen {
    RLMResults *unfrozen = testResults();
    RLMResults *frozen = [unfrozen freeze];
    XCTAssertFalse(unfrozen.isFrozen);
    XCTAssertTrue(frozen.isFrozen);
}

- (void)testFreezingFrozenObjectReturnsSelf {
    RLMResults *results = testResults();
    RLMResults *frozen = [results freeze];
    XCTAssertNotEqual(results, frozen);
    XCTAssertNotEqual(results.freeze, frozen);
    XCTAssertEqual(frozen, frozen.freeze);
}

- (void)testFreezeFromWrongThread {
    RLMResults *results = testResults();
    [self dispatchAsyncAndWait:^{
        RLMAssertThrowsWithReason([results freeze],
                                  @"Realm accessed from incorrect thread");
    }];
}

- (void)testAccessFrozenResultsFromDifferentThread {
    RLMResults *frozen = [testResults() freeze];
    [self dispatchAsyncAndWait:^{
        XCTAssertEqualObjects([frozen valueForKey:@"intCol"], (@[@0, @1, @2]));
    }];
}

- (void)testObserveFrozenResults {
    RLMResults *frozen = [testResults() freeze];
    id block = ^(__unused BOOL deleted, __unused NSArray *changes, __unused NSError *error) {};
    RLMAssertThrowsWithReason([frozen addNotificationBlock:block],
                              @"Frozen Realms do not change and do not have change notifications.");
}

- (void)testQueryFrozenResults {
    RLMResults *frozen = [testResults() freeze];
    XCTAssertEqualObjects([[frozen objectsWhere:@"intCol > 0"] valueForKey:@"intCol"], (@[@1, @2]));
}

- (void)testFrozenResultsDoNotUpdate {
    RLMResults *frozen = [testResults() freeze];
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [IntObject createInDefaultRealmWithValue:@[@3]];
    }];
    XCTAssertEqual(frozen.count, 3);
    XCTAssertEqual([frozen objectsWhere:@"intCol = 3"].count, 0);
}

- (void)testMultithreadedFrozenResultsEnumeration {
    RLMResults *frozen = [testResults() freeze];
    dispatch_apply(100, DISPATCH_APPLY_AUTO, ^(__unused size_t i) {
        for (__unused id obj in frozen);
    });
}

@end
