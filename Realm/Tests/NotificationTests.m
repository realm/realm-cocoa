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

#import "RLMRealmConfiguration_Private.h"

@interface NotificationTests : RLMTestCase
@property (nonatomic, strong) RLMNotificationToken *token;
@property (nonatomic) bool called;
@end

@implementation NotificationTests
- (void)setUp {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            for (int i = 0; i < 10; ++i)
                [IntObject createInDefaultRealmWithValue:@[@(i)]];
        }];
    }

    _token = [self.query addNotificationBlock:^(RLMResults *results, __unused RLMCollectionChange *change, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        self.called = true;
        CFRunLoopStop(CFRunLoopGetCurrent());
    }];
    CFRunLoopRun();
}

- (void)tearDown {
    [_token invalidate];
    [super tearDown];
}

- (RLMResults *)query {
    return [IntObject objectsWhere:@"intCol > 0 AND intCol < 5"];
}

- (void)runAndWaitForNotification:(void (^)(RLMRealm *))block {
    _called = false;
    [self waitForNotification:RLMRealmDidChangeNotification realm:RLMRealm.defaultRealm block:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            block(realm);
        }];
    }];
}

- (void)expectNotification:(void (^)(RLMRealm *))block {
    [self runAndWaitForNotification:block];
    XCTAssertTrue(_called);
}

- (void)expectNoNotification:(void (^)(RLMRealm *))block {
    [self runAndWaitForNotification:block];
    XCTAssertFalse(_called);
}

- (void)testInsertObjectMatchingQuery {
    [self expectNotification:^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@3]];
    }];
}

- (void)testInsertObjectNotMatchingQuery {
    [self expectNoNotification:^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@10]];
    }];
}

- (void)testModifyObjectMatchingQuery {
    [self expectNotification:^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@4 forKey:@"intCol"];
    }];
}

- (void)testModifyObjectToNoLongerMatchQuery {
    [self expectNotification:^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@5 forKey:@"intCol"];
    }];
}

- (void)testModifyObjectNotMatchingQuery {
    [self expectNoNotification:^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@6 forKey:@"intCol"];
    }];
}

- (void)testModifyObjectToMatchQuery {
    [self expectNotification:^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@4 forKey:@"intCol"];
    }];
}

- (void)testDeleteObjectMatchingQuery {
    [self expectNotification:^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    }];
}

- (void)testDeleteObjectNotMatchingQuery {
    [self expectNoNotification:^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 5"]];
    }];
    [self expectNoNotification:^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    }];
}

- (void)testNonMatchingObjectMovedToIndexOfMatchingRowAndMadeMatching {
    [self expectNotification:^(RLMRealm *realm) {
        // Make the last object match the query
        [[[IntObject allObjectsInRealm:realm] lastObject] setIntCol:3];
        // Move the now-matching object over a previously matching object
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    }];
}

- (void)testSuppressCollectionNotification {
    _called = false;

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [realm commitWriteTransactionWithoutNotifying:@[_token] error:nil];

    // Add a new callback that we can wait for, as we can't wait for a
    // notification to not be delivered
    RLMNotificationToken *token = [self.query addNotificationBlock:^(__unused RLMResults *results,
                                                                     __unused RLMCollectionChange *change,
                                                                     __unused NSError *error) {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }];
    CFRunLoopRun();
    [token invalidate];

    XCTAssertFalse(_called);
}

- (void)testSuppressRealmNotification {
    RLMRealm *realm = [RLMRealm defaultRealm];
    RLMNotificationToken *token = [realm addNotificationBlock:^(__unused RLMNotification notification, __unused RLMRealm *realm) {
        XCTFail(@"should not have been called");
    }];

    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [realm commitWriteTransactionWithoutNotifying:@[token] error:nil];

    // local realm notifications are called synchronously so no need to wait for anything
    [token invalidate];
}

- (void)testSuppressRealmNotificationInTransactionWithBlock {
    RLMRealm *realm = [RLMRealm defaultRealm];
    RLMNotificationToken *token = [realm addNotificationBlock:^(__unused RLMNotification notification, __unused RLMRealm *realm) {
        XCTFail(@"should not have been called");
    }];

    [realm transactionWithoutNotifying:@[token] block:^{
        [realm deleteAllObjects];
    }];

    // local realm notifications are called synchronously so no need to wait for anything
    [token invalidate];
}

- (void)testSuppressRealmNotificationForWrongRealm {
    RLMRealm *otherRealm = [self realmWithTestPath];
    RLMNotificationToken *token = [otherRealm addNotificationBlock:^(__unused RLMNotification notification, __unused RLMRealm *realm) {
        XCTFail(@"should not have been called");
    }];

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    XCTAssertThrows([realm commitWriteTransactionWithoutNotifying:@[token] error:nil]);
    [realm cancelWriteTransaction];
    [token invalidate];
}

- (void)testSuppressCollectionNotificationForWrongRealm {
    // Test with the token's realm not in a write transaction
    RLMRealm *otherRealm = [self realmWithTestPath];
    [otherRealm beginWriteTransaction];
    XCTAssertThrows([otherRealm commitWriteTransactionWithoutNotifying:@[_token] error:nil]);

    // and in a write transaction
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    XCTAssertThrows([otherRealm commitWriteTransactionWithoutNotifying:@[_token] error:nil]);
    [realm cancelWriteTransaction];
    [otherRealm cancelWriteTransaction];
}
@end

@interface SortedNotificationTests : NotificationTests
@end
@implementation SortedNotificationTests
- (RLMResults *)query {
    return [[IntObject objectsWhere:@"intCol > 0 AND intCol < 5"]
            sortedResultsUsingKeyPath:@"intCol" ascending:NO];
}

- (void)testMoveMatchingObjectDueToDeletionOfNonMatchingObject {
    [self expectNoNotification:^(RLMRealm *realm) {
        // Make a matching object be the last row
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol >= 5"]];
        // Delete a non-last, non-match row so that a matched row is moved
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    }];
}

- (void)testMultipleMovesOfSingleRow {
    [self expectNotification:^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject allObjectsInRealm:realm]];
        [IntObject createInRealm:realm withValue:@[@10]];
        [IntObject createInRealm:realm withValue:@[@10]];
        [IntObject createInRealm:realm withValue:@[@3]];
    }];

    [self expectNoNotification:^(RLMRealm *realm) {
        RLMResults *objects = [IntObject allObjectsInRealm:realm];
        [realm deleteObject:objects[1]];
        [realm deleteObject:objects[0]];
    }];
}
@end

@protocol ChangesetTestCase
- (RLMResults *)query;
- (void)prepare;
@end

@interface NSIndexPath (TableViewHelpers)
@property (nonatomic, readonly) NSInteger section;
@property (nonatomic, readonly) NSInteger row;
@end

@implementation NSIndexPath (TableViewHelpers)
- (NSInteger)section {
    return [self indexAtPosition:0];
}
- (NSInteger)row {
    return [self indexAtPosition:1];
}
@end

static RLMCollectionChange *getChange(RLMTestCase<ChangesetTestCase> *self, void (^block)(RLMRealm *)) {
    [self prepare];

    __block bool first = true;
    RLMResults *query = [self query];
    __block RLMCollectionChange *changes;
    id token = [query addNotificationBlock:^(RLMResults *results, RLMCollectionChange *c, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        changes = c;
        XCTAssertTrue(first == !changes);
        first = false;
        CFRunLoopStop(CFRunLoopGetCurrent());
    }];
    CFRunLoopRun();

    [self waitForNotification:RLMRealmDidChangeNotification realm:RLMRealm.defaultRealm block:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            block(realm);
        }];
    }];

    [(RLMNotificationToken *)token invalidate];
    token = nil;

    return changes;
}

static void ExpectChange(id self, NSArray *deletions, NSArray *insertions,
                         NSArray *modifications, void (^block)(RLMRealm *)) {
    RLMCollectionChange *changes = getChange(self, block);
    XCTAssertNotNil(changes);
    if (!changes) {
        return;
    }

    XCTAssertEqualObjects(deletions, changes.deletions);
    XCTAssertEqualObjects(insertions, changes.insertions);
    XCTAssertEqualObjects(modifications, changes.modifications);

    NSInteger section = __LINE__;
    NSArray *deletionPaths = [changes deletionsInSection:section];
    NSArray *insertionPaths = [changes insertionsInSection:section + 1];
    NSArray *modificationPaths = [changes modificationsInSection:section + 2];
    XCTAssert(deletionPaths.count == 0 || [deletionPaths[0] section] == section);
    XCTAssert(insertionPaths.count == 0 || [insertionPaths[0] section] == section + 1);
    XCTAssert(modificationPaths.count == 0 || [modificationPaths[0] section] == section + 2);
    XCTAssertEqualObjects(deletions, [deletionPaths valueForKey:@"row"]);
    XCTAssertEqualObjects(insertions, [insertionPaths valueForKey:@"row"]);
    XCTAssertEqualObjects(modifications, [modificationPaths valueForKey:@"row"]);
}

#define ExpectNoChange(self, block) XCTAssertNil(getChange((self), (block)))

@interface ChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation ChangesetTests
 - (void)prepare {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteAllObjects];
            for (int i = 0; i < 10; ++i) {
                IntObject *io = [IntObject createInDefaultRealmWithValue:@[@(i)]];
                [ArrayPropertyObject createInDefaultRealmWithValue:@[@"", @[], @[io]]];
            }
        }];
    }
 }

- (RLMResults *)query {
    return [IntObject objectsWhere:@"intCol > 0 AND intCol < 5"];
}

- (void)testDeleteMultiple {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
    });
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
    });
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 5"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });

    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 1"]];
    });
    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 3"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    });
    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 3"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol < 1"]];
    });

    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[[IntObject allObjectsInRealm:realm] valueForKey:@"self"]];
    });
}

- (void)testDeleteNewlyInsertedRowMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@3]];
        [realm deleteObject:[IntObject allObjectsInRealm:realm].lastObject];
    });
}

- (void)testInsertObjectMatchingQuery {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@3]];
    });
}

- (void)testInsertObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@5]];
    });
}

- (void)testInsertBothMatchingAndNonMatching {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@5]];
        [IntObject createInRealm:realm withValue:@[@3]];
    });
}

- (void)testInsertMultipleMatching {
    ExpectChange(self, @[], @[@4, @5], @[], ^(RLMRealm *realm) {
        [IntObject createInRealm:realm withValue:@[@5]];
        [IntObject createInRealm:realm withValue:@[@3]];
        [IntObject createInRealm:realm withValue:@[@5]];
        [IntObject createInRealm:realm withValue:@[@2]];
    });
}

- (void)testModifyObjectMatchingQuery {
    ExpectChange(self, @[], @[], @[@2], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testModifyObjectToNoLongerMatchQuery {
    ExpectChange(self, @[@2], @[], @[], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@5 forKey:@"intCol"];
    });
}

- (void)testModifyObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@6 forKey:@"intCol"];
    });
}

- (void)testModifyObjectToMatchQuery {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testModifyObjectShiftedByDeletion {
    ExpectChange(self, @[@1], @[], @[@2], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testDeleteObjectMatchingQuery {
    ExpectChange(self, @[@0], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 1"]];
    });
    ExpectChange(self, @[@3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    });
}

- (void)testDeleteNonMatchingBeforeMatches {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });
}

- (void)testDeleteNonMatchingAfterMatches {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 5"]];
    });
}

#if 0 // maybe relevant to queries on backlinks?
- (void)testMoveMatchingObjectDueToDeletionOfNonMatchingObject {
    ExpectChange(self, @[@3], @[@0], @[], ^(RLMRealm *realm) {
        // Make a matching object be the last row
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol >= 5"]];
        // Delete a non-last, non-match row so that a matched row is moved
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });
}

- (void)testNonMatchingObjectMovedToIndexOfMatchingRowAndMadeMatching {
    ExpectChange(self, @[@1], @[@1], @[], ^(RLMRealm *realm) {
        // Make the last object match the query
        [[[IntObject allObjectsInRealm:realm] lastObject] setIntCol:3];
        // Move the now-matching object over a previously matching object
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    });
}
#endif

- (void)testExcludingChangesFromSkippedTransaction {
    [self prepare];

    __block bool first = true;
    RLMResults *query = [self query];
    __block RLMCollectionChange *changes;
    RLMNotificationToken *token = [query addNotificationBlock:^(RLMResults *results, RLMCollectionChange *c, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        changes = c;
        XCTAssertTrue(first || changes);
        first = false;
        CFRunLoopStop(CFRunLoopGetCurrent());
    }];
    CFRunLoopRun();

    [query.realm beginWriteTransaction];
    [IntObject createInRealm:query.realm withValue:@[@3]];
    [query.realm commitWriteTransactionWithoutNotifying:@[token] error:nil];

    [self waitForNotification:RLMRealmDidChangeNotification realm:RLMRealm.defaultRealm block:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [IntObject createInRealm:realm withValue:@[@3]];
        }];
    }];

    [token invalidate];
    token = nil;

    XCTAssertNotNil(changes);
    // Should only have the row inserted in the background transaction
    XCTAssertEqualObjects(@[@5], changes.insertions);
}

- (void)testMultipleWriteTransactionsWithinNotification {
    [self prepare];

    RLMResults *query1 = [self query];
    __block int calls1 = 0;
    id token1 = [query1 addNotificationBlock:^(RLMResults *results, RLMCollectionChange *c, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        if (calls1++ == 0) {
            XCTAssertNil(c);
            return;
        }
        XCTAssertEqualObjects(c.deletions, @[@(5 - calls1)]);
    }];

    RLMResults *query2 = [self query];
    __block int calls2 = 0;
    id token2 = [query2 addNotificationBlock:^(RLMResults *results, __unused RLMCollectionChange *c, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        ++calls2;
        RLMRealm *realm = results.realm;
        if (realm.inWriteTransaction) {
            return;
        }
        while (results.count) {
            [realm beginWriteTransaction];
            [realm deleteObject:[results lastObject]];
            [realm commitWriteTransaction];
        }
    }];

    id ex = [self expectationWithDescription:@"last query gets final notification"];
    RLMResults *query3 = [self query];
    __block int calls3 = 0;
    id token3 = [query3 addNotificationBlock:^(RLMResults *results, RLMCollectionChange *c, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        if (++calls3 == 1) {
            XCTAssertNil(c);
        }
        else {
            XCTAssertEqualObjects(c.deletions, @[@(5 - calls3)]);
        }
        if (results.count == 0) {
            [ex fulfill];
        }
    }];

    [self waitForExpectations:@[ex] timeout:2.0];

    XCTAssertEqual(calls1, 5);
    XCTAssertEqual(calls2, 5);
    XCTAssertEqual(calls3, 5);

    [token1 invalidate];
    [token2 invalidate];
    [token3 invalidate];
}

@end

@interface LinkViewArrayChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation LinkViewArrayChangesetTests
- (void)prepare {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteAllObjects];
            for (int i = 0; i < 10; ++i) {
                [IntObject createInDefaultRealmWithValue:@[@(i)]];
            }
            [ArrayPropertyObject createInDefaultRealmWithValue:@[@"", @[], [IntObject allObjectsInRealm:realm]]];
        }];
    }
}

- (RLMResults *)query {
    return [[[ArrayPropertyObject.allObjects firstObject] intArray]
            objectsWhere:@"intCol > 0 AND intCol < 5"];
}

- (void)testDeleteMultiple {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
    });
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 5"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });

    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 1"]];
    });
    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 3"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    });
    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 3"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol < 1"]];
    });
}

- (void)testModifyObjectMatchingQuery {
    ExpectChange(self, @[], @[], @[@2], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testModifyObjectToNoLongerMatchQuery {
    ExpectChange(self, @[@2], @[], @[], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@5 forKey:@"intCol"];
    });
}

- (void)testModifyObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@6 forKey:@"intCol"];
    });
}

- (void)testModifyObjectToMatchQuery {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testDeleteObjectMatchingQuery {
    ExpectChange(self, @[@0], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 1"]];
    });
    ExpectChange(self, @[@3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    });
}

- (void)testDeleteNonMatchingBeforeMatches {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });
}

- (void)testDeleteNonMatchingAfterMatches {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 5"]];
    });
}

- (void)testMoveMatchingObjectDueToDeletionOfNonMatchingObject {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        // Make a matching object be the last row
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol >= 5"]];
        // Delete a non-last, non-match row so that a matched row is moved
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });
}

- (void)testNonMatchingObjectMovedToIndexOfMatchingRowAndMadeMatching {
    ExpectChange(self, @[@1], @[@3], @[], ^(RLMRealm *realm) {
        // Make the last object match the query
        [[[IntObject allObjectsInRealm:realm] lastObject] setIntCol:3];
        // Move the now-matching object over a previously matching object
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    });
}

- (void)testDeleteNewlyInsertedRowMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array addObject:[IntObject createInRealm:realm withValue:@[@3]]];
        [realm deleteObject:[IntObject allObjectsInRealm:realm].lastObject];
    });
}

- (void)testInsertObjectMatchingQuery {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array addObject:[IntObject createInRealm:realm withValue:@[@3]]];
    });
}

- (void)testInsertObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array addObject:[IntObject createInRealm:realm withValue:@[@5]]];
    });
}

- (void)testInsertBothMatchingAndNonMatching {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array addObject:[IntObject createInRealm:realm withValue:@[@5]]];
        [array addObject:[IntObject createInRealm:realm withValue:@[@3]]];
    });
}

- (void)testInsertMultipleMatching {
    ExpectChange(self, @[], @[@4, @5], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array addObject:[IntObject createInRealm:realm withValue:@[@5]]];
        [array addObject:[IntObject createInRealm:realm withValue:@[@3]]];
        [array addObject:[IntObject createInRealm:realm withValue:@[@5]]];
        [array addObject:[IntObject createInRealm:realm withValue:@[@2]]];
    });
}

- (void)testInsertAtIndex {
    ExpectChange(self, @[], @[@0], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        IntObject *io = [IntObject createInRealm:realm withValue:@[@3]];
        [array insertObject:io atIndex:0];
    });

    ExpectChange(self, @[], @[@0], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        IntObject *io = [IntObject createInRealm:realm withValue:@[@3]];
        [array insertObject:io atIndex:1];
    });

    ExpectChange(self, @[], @[@1], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        IntObject *io = [IntObject createInRealm:realm withValue:@[@3]];
        [array insertObject:io atIndex:2];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        IntObject *io = [IntObject createInRealm:realm withValue:@[@5]];
        [array insertObject:io atIndex:2];
    });
}

- (void)testExchangeObjects {
    // adjacent swap: one move, since second is redundant
//    ExpectChange(self, @[@1, @0], @[], @[], ^(RLMRealm *realm) {
//        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
//        [array exchangeObjectAtIndex:1 withObjectAtIndex:2];
//    });

    // non-adjacent: two moves needed
//    ExpectChange(self, @[@0, @2], ^(RLMRealm *realm) {
//        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
//        [array exchangeObjectAtIndex:1 withObjectAtIndex:3];
//    });
}

- (void)testRemoveFromArray {
    ExpectChange(self, @[@0], @[], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array removeObjectAtIndex:1];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array removeObjectAtIndex:0];
    });
}

- (void)testClearArray {
    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array removeAllObjects];
    });
}

- (void)testDeleteArray {
    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[ArrayPropertyObject allObjectsInRealm:realm]];
    });
}

- (void)testDeleteAlreadyEmptyArray {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm transactionWithBlock:^{
        [ArrayPropertyObject createInRealm:realm withValue:@[]];
    }];
    RLMArray *array = [[ArrayPropertyObject allObjectsInRealm:realm].firstObject intArray];
    __block RLMCollectionChange *changes;
    __block int calls = 0;
    id token = [array addNotificationBlock:^(RLMArray *results, RLMCollectionChange *c, NSError *error) {
        XCTAssertNotNil(results);
        XCTAssertNil(error);
        changes = c;
        ++calls;
        CFRunLoopStop(CFRunLoopGetCurrent());
    }];
    CFRunLoopRun();

    [self waitForNotification:RLMRealmDidChangeNotification realm:realm block:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteObjects:[ArrayPropertyObject allObjectsInRealm:realm]];
        }];
    }];

    [(RLMNotificationToken *)token invalidate];
    XCTAssertEqual(calls, 1);
}

- (void)testModifyObjectShiftedByInsertsAndDeletions {
    ExpectChange(self, @[@1], @[], @[@2], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@4 forKey:@"intCol"];
    });
    ExpectChange(self, @[], @[@0], @[@3], ^(RLMRealm *realm) {
        RLMArray *array = [[[ArrayPropertyObject allObjectsInRealm:realm] firstObject] intArray];
        [array insertObject:[IntObject createInRealm:realm withValue:@[@3]] atIndex:0];
        [[IntObject objectsInRealm:realm where:@"intCol = 4"] setValue:@3 forKey:@"intCol"];
    });
}
@end

@interface LinkViewSetChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation LinkViewSetChangesetTests
- (void)prepare {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteAllObjects];
            for (int i = 0; i < 10; ++i) {
                [IntObject createInDefaultRealmWithValue:@[@(i)]];
            }
            [SetPropertyObject createInDefaultRealmWithValue:@[@"", @[], [IntObject allObjectsInRealm:realm]]];
        }];
    }
}

- (RLMResults *)query {
    return [[[SetPropertyObject.allObjects firstObject] intSet]
            objectsWhere:@"intCol > 0 AND intCol < 5"];
}

- (void)testDeleteMultiple {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
    });
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 5"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });

    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 1"]];
    });
    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 3"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    });
    ExpectChange(self, @[@1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 3"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol > 4"]];
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol < 1"]];
    });
}

- (void)testModifyObjectMatchingQuery {
    ExpectChange(self, @[], @[], @[@2], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testModifyObjectToNoLongerMatchQuery {
    ExpectChange(self, @[@2], @[], @[], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 3"] setValue:@5 forKey:@"intCol"];
    });
}

- (void)testModifyObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@6 forKey:@"intCol"];
    });
}

- (void)testModifyObjectToMatchQuery {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 5"] setValue:@4 forKey:@"intCol"];
    });
}

- (void)testDeleteObjectMatchingQuery {
    ExpectChange(self, @[@0], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 1"]];
    });
    ExpectChange(self, @[@3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 4"]];
    });
}

- (void)testDeleteNonMatchingBeforeMatches {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });
}

- (void)testDeleteNonMatchingAfterMatches {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 5"]];
    });
}

- (void)testMoveMatchingObjectDueToDeletionOfNonMatchingObject {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        // Make a matching object be the last row
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol >= 5"]];
        // Delete a non-last, non-match row so that a matched row is moved
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 0"]];
    });
}

- (void)testNonMatchingObjectMovedToIndexOfMatchingRowAndMadeMatching {
    ExpectChange(self, @[@1], @[@3], @[], ^(RLMRealm *realm) {
        // Make the last object match the query
        [[[IntObject allObjectsInRealm:realm] lastObject] setIntCol:3];
        // Move the now-matching object over a previously matching object
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
    });
}

- (void)testDeleteNewlyInsertedRowMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set addObject:[IntObject createInRealm:realm withValue:@[@3]]];
        [realm deleteObject:[IntObject allObjectsInRealm:realm].lastObject];
    });
}

- (void)testInsertObjectMatchingQuery {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set addObject:[IntObject createInRealm:realm withValue:@[@3]]];
    });
}

- (void)testInsertObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set addObject:[IntObject createInRealm:realm withValue:@[@5]]];
    });
}

- (void)testInsertBothMatchingAndNonMatching {
    ExpectChange(self, @[], @[@4], @[], ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set addObject:[IntObject createInRealm:realm withValue:@[@5]]];
        [set addObject:[IntObject createInRealm:realm withValue:@[@3]]];
    });
}

- (void)testInsertMultipleMatching {
    ExpectChange(self, @[], @[@4, @5], @[], ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set addObject:[IntObject createInRealm:realm withValue:@[@5]]];
        [set addObject:[IntObject createInRealm:realm withValue:@[@3]]];
        [set addObject:[IntObject createInRealm:realm withValue:@[@5]]];
        [set addObject:[IntObject createInRealm:realm withValue:@[@2]]];
    });
}

- (void)testRemoveFromSet {
    ExpectChange(self, @[@0], @[], @[], ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set removeObject:set.allObjects[1]];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set removeObject:set.allObjects[0]];
    });
}

- (void)testClearSet {
    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        RLMSet *set = [[[SetPropertyObject allObjectsInRealm:realm] firstObject] intSet];
        [set removeAllObjects];
    });
}

- (void)testDeleteSet {
    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[SetPropertyObject allObjectsInRealm:realm]];
    });
}

- (void)testModifyObjectShiftedByInsertsAndDeletions {
    ExpectChange(self, @[@0, @1], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[IntObject objectsInRealm:realm where:@"intCol = 2"]];
        [[IntObject objectsInRealm:realm where:@"intCol = 1"] setValue:@10 forKey:@"intCol"];
    });
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [[IntObject objectsInRealm:realm where:@"intCol = 9"] setValue:@11 forKey:@"intCol"];
    });
}
@end

@interface DictionaryChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation DictionaryChangesetTests
- (void)prepare {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            DictionaryPropertyObject *dictObj = [DictionaryPropertyObject new];
            [realm deleteAllObjects];
            for (int i = 0; i < 10; ++i) {
                IntObject *intObject = [IntObject createInDefaultRealmWithValue:@[@(i)]];
                NSString *key = [NSString stringWithFormat:@"key%d", i];
                [dictObj.intObjDictionary setObject:intObject forKey:key];
            }
            [realm addObject:dictObj];
        }];
    }
}

- (RLMResults *)query {
    return [[[DictionaryPropertyObject.allObjects firstObject] intObjDictionary]
            objectsWhere:@"intCol > 0 AND intCol < 5"];
}

- (void)testDeleteNewlyInsertedRowMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        dictionary[@"anotherKey"] = [IntObject createInRealm:realm withValue:@[@3]];
        [realm deleteObject:[IntObject allObjectsInRealm:realm].lastObject];
    });
}

- (void)testInsertObjectMatchingQuery {
    ExpectChange(self, @[], @[@0], @[], ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        dictionary[@"key"] = [IntObject createInRealm:realm withValue:@[@3]];
    });
}

- (void)testInsertObjectNotMatchingQuery {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        dictionary[@"key"] = [IntObject createInRealm:realm withValue:@[@5]];
    });
}

- (void)testInsertBothMatchingAndNonMatching {
    ExpectChange(self, @[], @[@0], @[], ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        dictionary[@"keyA"] = [IntObject createInRealm:realm withValue:@[@5]];
        dictionary[@"keyB"] = [IntObject createInRealm:realm withValue:@[@3]];
    });
}

- (void)testInsertMultipleMatching {
    ExpectChange(self, @[], @[@0, @1], @[], ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        dictionary[@"keyA"] = [IntObject createInRealm:realm withValue:@[@5]];
        dictionary[@"keyB"] = [IntObject createInRealm:realm withValue:@[@3]];
        dictionary[@"keyC"] = [IntObject createInRealm:realm withValue:@[@5]];
        dictionary[@"keyD"] = [IntObject createInRealm:realm withValue:@[@2]];
    });
}

- (void)testRemoveFromDictionary {
    ExpectChange(self, @[@1], @[], @[], ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        [dictionary removeObjectForKey:@"key1"];
    });

    ExpectNoChange(self, ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        [dictionary removeObjectForKey:@"key0"];
    });
}

- (void)testClearDictionary {
    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        RLMDictionary *dictionary = [[[DictionaryPropertyObject allObjectsInRealm:realm] firstObject] intObjDictionary];
        [dictionary removeAllObjects];
    });
}

- (void)testDeleteDictionary {
    ExpectChange(self, @[@0, @1, @2, @3], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[DictionaryPropertyObject allObjectsInRealm:realm]];
    });
}

@end

@interface LinkedObjectChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation LinkedObjectChangesetTests
- (void)prepare {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteAllObjects];
            for (int i = 0; i < 5; ++i) {
                [LinkStringObject createInRealm:realm
                                      withValue:@[[StringObject createInRealm:realm
                                                                    withValue:@[@""]]]];
            }
        }];
    }
}

- (RLMResults *)query {
    return LinkStringObject.allObjects;
}

- (void)testDeleteLinkedObject {
    ExpectChange(self, @[], @[], @[@3], ^(RLMRealm *realm) {
        [realm deleteObject:[StringObject allObjectsInRealm:realm][3]];
    });
}

- (void)testModifyLinkedObject {
    ExpectChange(self, @[], @[], @[@3], ^(RLMRealm *realm) {
        [[StringObject allObjectsInRealm:realm][3] setStringCol:@"a"];
    });
}

- (void)testInsertUnlinkedObject {
    ExpectNoChange(self, ^(RLMRealm *realm) {
        [StringObject createInRealm:realm withValue:@[@""]];
    });
}

- (void)testTableClearFollowedByInsertsAndDeletes {
    ExpectChange(self, @[], @[], @[@0, @1, @2, @3, @4], ^(RLMRealm *realm) {
        [realm deleteObjects:[StringObject allObjectsInRealm:realm]];
        [StringObject createInRealm:realm withValue:@[@""]];
        [realm deleteObject:[StringObject createInRealm:realm withValue:@[@""]]];
    });
}
@end

@interface LinkingObjectsChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation LinkingObjectsChangesetTests
- (void)prepare {
    @autoreleasepool {
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteAllObjects];
            PersonObject *child = [PersonObject createInDefaultRealmWithValue:@[ @"Child", @0 ]];
            for (int i = 0; i < 10; ++i) {
                // It takes a village to raise a child…
                NSString *name = [NSString stringWithFormat:@"Parent %d", i];
                [PersonObject createInDefaultRealmWithValue:@[ name, @(25 + i), @[ child ]]];
            }
        }];
    }
}

- (RLMResults *)query {
    return [[PersonObject.allObjects firstObject] parents];
}

- (void)testDeleteOneLinkingObject {
    ExpectChange(self, @[@5, @9], @[@5], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[PersonObject objectsInRealm:realm where:@"age == 30"]];
    });
}

- (void)testDeleteSomeLinkingObjects {
    ExpectChange(self, @[@2, @7, @8, @9], @[@2], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[PersonObject objectsInRealm:realm where:@"age > 32"]];
        [realm deleteObjects:[PersonObject objectsInRealm:realm where:@"age == 27"]];
    });
}

- (void)testDeleteAllLinkingObjects {
    ExpectChange(self, @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[PersonObject objectsInRealm:realm where:@"age > 20"]];
    });
}

- (void)testDeleteAll {
    ExpectChange(self, @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[PersonObject allObjectsInRealm:realm]];
    });
}

- (void)testUnlinkOne {
    ExpectChange(self, @[@4, @9], @[@4], @[], ^(RLMRealm *realm) {
        PersonObject *parent = [[PersonObject objectsInRealm:realm where:@"age == 29"] firstObject];
        [parent.children removeAllObjects];
    });
}

- (void)testUnlinkAll {
    ExpectChange(self, @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9], @[], @[], ^(RLMRealm *realm) {
        for (PersonObject *parent in [PersonObject objectsInRealm:realm where:@"age > 20"])
            [parent.children removeAllObjects];
    });
}

- (void)testAddNewParent {
    ExpectChange(self, @[], @[@10], @[], ^(RLMRealm *realm) {
        PersonObject *child = [[PersonObject objectsInRealm:realm where:@"children.@count == 0"] firstObject];
        [PersonObject createInDefaultRealmWithValue:@[ @"New parent", @40, @[ child ]]];
    });
}

- (void)testAddDuplicateParent {
    ExpectChange(self, @[], @[@10], @[@7], ^(RLMRealm *realm) {
        PersonObject *parent = [[PersonObject objectsInRealm:realm where:@"age == 32"] firstObject];
        [parent.children addObject:[parent.children firstObject]];
    });
}

- (void)testModifyParent {
    ExpectChange(self, @[], @[], @[@3], ^(RLMRealm *realm) {
        PersonObject *parent = [[PersonObject objectsInRealm:realm where:@"age == 28"] firstObject];
        parent.age = parent.age + 1;
    });
}

@end

@interface AllTypesWithPrimaryKey : RLMObject
@property BOOL          boolCol;
@property int           intCol;
@property float         floatCol;
@property double        doubleCol;
@property NSString     *stringCol;
@property NSData       *binaryCol;
@property NSDate       *dateCol;
@property bool          cBoolCol;
@property int64_t       longCol;
@property RLMObjectId  *objectIdCol;
@property RLMDecimal128 *decimalCol;
@property StringObject *objectCol;
@property NSUUID *uuidCol;
@property id<RLMValue> anyCol;
@property MixedObject *mixedObjectCol;

@property (nonatomic) int pk;
@end
@implementation AllTypesWithPrimaryKey
+ (NSString *)primaryKey { return @"pk"; }
@end

// clang thinks the tests below have retain cycles because `_obj` could retain
// the block passed to addNotificationBlock (but it doesn't)
#pragma clang diagnostic ignored "-Warc-retain-cycles"

@interface ObjectNotifierTests : RLMTestCase
@end

@implementation ObjectNotifierTests {
    NSDictionary *_initialValues;
    NSDictionary *_values;
    NSArray<NSString *> *_propertyNames;
    AllTypesObject *_obj;
}

- (void)setUp {
    StringObject *so = [[StringObject alloc] init];
    so.stringCol = @"string";
    MixedObject *mo = [[MixedObject alloc] init];
    mo.anyCol = @"string";
    _initialValues = [AllTypesObject values:1 stringObject:nil mixedObject:nil];
    _values = [AllTypesObject values:2 stringObject:so mixedObject:mo];

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    _obj = [AllTypesObject createInRealm:realm withValue:_initialValues];
    [realm commitWriteTransaction];

    _propertyNames = [_obj.objectSchema.properties valueForKey:@"name"];
}

- (void)tearDown {
    _values = nil;
    _initialValues = nil;
    _obj = nil;
    [super tearDown];
}

- (void)testObserveUnmanagedObject {
    AllTypesObject *unmanagedObj = [[AllTypesObject alloc] init];
    XCTAssertThrows([unmanagedObj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {}]);
    XCTAssertThrows([unmanagedObj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {} keyPaths:@[@"boolCol"]]);
}

- (void)testDeleteObservedObject {
    XCTestExpectation *expectation0 = [self expectationWithDescription:@"delete observed object"];
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"delete observed object"];

    RLMNotificationToken *token0 = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertTrue(deleted);
        XCTAssertNil(error);
        XCTAssertNil(changes);
        [expectation0 fulfill];
    }];
    RLMNotificationToken *token1 = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertTrue(deleted);
        XCTAssertNil(error);
        XCTAssertNil(changes);
        [expectation1 fulfill];
    } keyPaths:@[@"boolCol"]];

    RLMRealm *realm = _obj.realm;
    [realm beginWriteTransaction];
    [realm deleteObject:_obj];
    [realm commitWriteTransaction];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [token0 invalidate];
}

- (void)testChangeAllPropertyTypes {
    __block NSString *property;
    __block XCTestExpectation *expectation = nil;
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, property);
        XCTAssertNil(prop.previousValue);
        if ([prop.name isEqualToString:@"objectCol"]) {
            XCTAssertTrue([prop.value isEqualToObject:_values[property]],
                          @"%@: %@ %@", property, prop.value, _values[property]);
        }
        else if ([prop.name isEqualToString:@"mixedObjectCol"]) {
            XCTAssertEqualObjects(((MixedObject *)prop.value).anyCol,
                                  ((MixedObject *)_values[property]).anyCol);
        }
        else {
            XCTAssertEqualObjects(prop.value, _values[property]);
        }

        [expectation fulfill];
    }];

    for (property in _propertyNames) {
        expectation = [self expectationWithDescription:@""];

        [_obj.realm beginWriteTransaction];
        _obj[property] = _values[property];
        [_obj.realm commitWriteTransaction];

        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    [token invalidate];
}

- (void)testChangeAllPropertyTypesFromBackground {
    __block NSString *propertyName;
    __block RLMThreadSafeReference *mixedObject;
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, propertyName);
        if ([prop.name isEqualToString:@"objectCol"]) {
            XCTAssertNil(prop.previousValue);
            XCTAssertNotNil(prop.value);
        }
        else if ([prop.name isEqualToString:@"mixedObjectCol"]) {
            XCTAssertNil(prop.previousValue);
            RLMRealm *realm = [RLMRealm defaultRealm];
            MixedObject *mo = [realm resolveThreadSafeReference:mixedObject];
            XCTAssertEqualObjects(((MixedObject *)prop.value).anyCol,
                                  mo.anyCol);
        }
        else {
            XCTAssertEqualObjects(prop.previousValue, _initialValues[prop.name]);
            XCTAssertEqualObjects(prop.value, _values[prop.name]);
        }
    }];

    for (propertyName in _propertyNames) {
        [self dispatchAsyncAndWait:^{
            RLMRealm *realm = [RLMRealm defaultRealm];
            AllTypesObject *obj = [[AllTypesObject allObjectsInRealm:realm] firstObject];
            [realm beginWriteTransaction];
            obj[propertyName] = _values[propertyName];
            if ([propertyName isEqualToString:@"mixedObjectCol"]) {
                mixedObject = [RLMThreadSafeReference referenceWithThreadConfined:_values[@"mixedObjectCol"]];
            }
            [realm commitWriteTransaction];
        }];
        [_obj.realm refresh];
    }
    [token invalidate];
}

- (void)testChangeAllPropertyTypesInSingleTransaction {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, _values.count);

        NSUInteger i = 0;
        for (RLMPropertyChange *prop in changes) {
            XCTAssertEqualObjects(prop.name, _propertyNames[i]);
            if ([prop.name isEqualToString:@"objectCol"]) {
                XCTAssertTrue([prop.value isEqualToObject:_values[prop.name]]);
            }
            else if ([prop.name isEqualToString:@"mixedObjectCol"]) {
                XCTAssertEqualObjects(((MixedObject *)prop.value).anyCol,
                                      ((MixedObject *)_values[prop.name]).anyCol);
            }
            else {
                XCTAssertEqualObjects(prop.value, _values[prop.name]);
            }
            ++i;
        }
        [expectation fulfill];
    }];

    [_obj.realm beginWriteTransaction];
    for (NSString *propertyName in _propertyNames) {
        _obj[propertyName] = _values[propertyName];
    }
    [_obj.realm commitWriteTransaction];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [token invalidate];
}

- (void)testMultipleObjectNotifiers {
    [_obj.realm beginWriteTransaction];
    AllTypesObject *obj2 = [AllTypesObject createInRealm:_obj.realm withValue:_obj];
    [_obj.realm commitWriteTransaction];

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    __block NSUInteger calls = 0;
    id block = ^(BOOL deleted, NSArray<RLMPropertyChange *> *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        XCTAssertEqualObjects(changes[0].name, @"intCol");
        XCTAssertEqualObjects(changes[0].previousValue, @1);
        XCTAssertEqualObjects(changes[0].value, @2);
        if (++calls == 2) {
            [expectation fulfill];
        }
    };
    RLMNotificationToken *token1 = [_obj addNotificationBlock:block];
    RLMNotificationToken *token2 = [_obj addNotificationBlock:block];
    RLMNotificationToken *token3 = [obj2 addNotificationBlock:^(__unused BOOL deletd,
                                                                __unused NSArray<RLMPropertyChange *> *changes,
                                                                __unused NSError *error) {
        XCTFail(@"notification block for wrong object called");
    }];

    // Ensure initial notification is processed so that the change can report previousValue
    [_obj.realm transactionWithBlock:^{}];

    [self dispatchAsync:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        AllTypesObject *obj = [[AllTypesObject allObjectsInRealm:realm] firstObject];
        [realm beginWriteTransaction];
        obj.intCol = 2;
        [realm commitWriteTransaction];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [token1 invalidate];
    [token2 invalidate];
    [token3 invalidate];
}

- (void)testArrayPropertiesMerelyReportModification {
    [_obj.realm beginWriteTransaction];
    ArrayOfAllTypesObject *array = [ArrayOfAllTypesObject createInRealm:_obj.realm withValue:@[@[]]];
    [_obj.realm commitWriteTransaction];

    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    RLMNotificationToken *token = [array addNotificationBlock:^(BOOL deleted, NSArray<RLMPropertyChange *> *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);

        XCTAssertEqualObjects(changes[0].name, @"array");
        XCTAssertNil(changes[0].previousValue);
        XCTAssertNil(changes[0].value);
        [expectation fulfill];
    }];

    [self dispatchAsync:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        ArrayOfAllTypesObject *obj = [[ArrayOfAllTypesObject allObjectsInRealm:realm] firstObject];
        [realm beginWriteTransaction];
        [obj.array addObject:[[AllTypesObject allObjectsInRealm:realm] firstObject]];
        [realm commitWriteTransaction];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [token invalidate];
}

- (void)testDiffedUpdatesOnlyNotifyForPropertiesWhichActuallyChanged {
    NSMutableDictionary *values = [_initialValues mutableCopy];
    values[@"pk"] = @1;

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [realm addObject:_values[@"objectCol"]];
    AllTypesWithPrimaryKey *obj = [AllTypesWithPrimaryKey createInRealm:realm withValue:values];
    [realm commitWriteTransaction];

    __block NSString *propertyName;
    __block XCTestExpectation *expectation = nil;
    RLMNotificationToken *token = [obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, propertyName);
        XCTAssertNil(prop.previousValue);
        if ([prop.name isEqualToString:@"objectCol"]) {
            XCTAssertTrue([prop.value isEqualToObject:_values[prop.name]],
                          @"%@: %@ %@", prop.name, prop.value, _values[prop.name]);
        }
        else if ([prop.name isEqualToString:@"mixedObjectCol"]) {
            XCTAssertEqualObjects(((MixedObject *)prop.value).anyCol,
                                  ((MixedObject *)_values[prop.name]).anyCol);
        }
        else {
            XCTAssertEqualObjects(prop.value, _values[prop.name]);
        }

        [expectation fulfill];
    }];


    for (propertyName in _propertyNames) {
        expectation = [self expectationWithDescription:propertyName];

        [realm beginWriteTransaction];
        values[propertyName] = _values[propertyName];
        [AllTypesWithPrimaryKey createOrUpdateModifiedInRealm:realm withValue:values];
        [realm commitWriteTransaction];

        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    [token invalidate];
}

#pragma mark - Object Notification Key Path Filtering

- (void)testModifyObservedKeyPathLocally {
    XCTestExpectation *ex = [self expectationWithDescription:@"change notification"];
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, @"boolCol");
        [ex fulfill];
    } keyPaths:@[@"boolCol"]];

    [_obj.realm beginWriteTransaction];
    XCTAssertNotEqual(_obj.boolCol, [_values[@"boolCol"] boolValue]);
    _obj.boolCol = [_values[@"boolCol"] boolValue];
    [_obj.realm commitWriteTransaction];
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testModifyUnobservedKeyPathLocally {
    XCTestExpectation *ex = [self expectationWithDescription:@"no change notification"];
    ex.inverted = true;
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        [ex fulfill];
    } keyPaths:@[@"boolCol"]];

    [_obj.realm beginWriteTransaction];
    _obj.intCol = _obj.intCol + _obj.intCol;
    [_obj.realm commitWriteTransaction];
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testModifyObservedKeyPathRemotely {
    XCTestExpectation *ex = [self expectationWithDescription:@"change notification"];
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, @"boolCol");
        [ex fulfill];
    } keyPaths:@[@"boolCol"]];

    [self dispatchAsync:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        AllTypesObject *obj = [[AllTypesObject allObjectsInRealm:realm] firstObject];
        [realm beginWriteTransaction];
        XCTAssertNotEqual(obj.boolCol, [_values[@"boolCol"] boolValue]);
        obj.boolCol = [_values[@"boolCol"] boolValue];
        [realm commitWriteTransaction];
    }];
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testModifyUnobservedKeyPathRemotely {
    XCTestExpectation *ex = [self expectationWithDescription:@"no change notification"];
    ex.inverted = true;

    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        [ex fulfill];
    } keyPaths:@[@"boolCol"]];

    [self dispatchAsync:^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        AllTypesObject *obj = [[AllTypesObject allObjectsInRealm:realm] firstObject];
        [realm beginWriteTransaction];
        obj.intCol = obj.intCol + obj.intCol;
        [realm commitWriteTransaction];
    }];
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testModifyObservedKeyPathArrayProperty {
    XCTestExpectation *ex = [self expectationWithDescription:@"change notification"];

    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];
    NSString *name = CompanyObject.className;
    CompanyObject *company = [CompanyObject createInRealm:realm withValue:@{}];
    EmployeeObject *employee = [EmployeeObject createInRealm:realm withValue:@{@"age": @30, @"hired": @NO}];
    [company.employees addObject:employee];
    [realm commitWriteTransaction];

    RLMNotificationToken *token = [company addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);

        for (RLMPropertyChange *prop in changes) {
            XCTAssertEqualObjects(prop.name, @"employees");
            XCTAssertFalse(prop.previousValue);
            XCTAssertFalse(prop.value); // Observing an array will lead to NSNull here.
        }
        [ex fulfill];
    } keyPaths:@[@"employees.hired"]];

    [realm beginWriteTransaction];
    employee.hired = true;
    [realm commitWriteTransaction];
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

- (void)testModifyUnobservedKeyPathArrayProperty {
    XCTestExpectation *ex = [self expectationWithDescription:@"no change notification"];
    ex.inverted = true;

    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];
    NSString *name = CompanyObject.className;
    CompanyObject *company = [CompanyObject createInRealm:realm withValue:@{}];
    EmployeeObject *employee = [EmployeeObject createInRealm:realm withValue:@{@"age": @30, @"hired": @NO}];
    [company.employees addObject:employee];
    [realm commitWriteTransaction];

    RLMNotificationToken *token = [company addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        [ex fulfill];
    } keyPaths:@[@"employees.hired"]];

    [realm beginWriteTransaction];
    employee.age = 42;
    [realm commitWriteTransaction];
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

@end
