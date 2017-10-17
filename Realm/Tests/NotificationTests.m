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

static void ExpectChange(id self, NSArray *deletions, NSArray *insertions, NSArray *modifications, void (^block)(RLMRealm *)) {
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

    ExpectChange(self, @[@3], @[@0], @[], ^(RLMRealm *realm) {
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

@end

@interface LinkViewChangesetTests : RLMTestCase <ChangesetTestCase>
@end

@implementation LinkViewChangesetTests
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
    ExpectChange(self, @[@5], @[], @[], ^(RLMRealm *realm) {
        [realm deleteObjects:[PersonObject objectsInRealm:realm where:@"age == 30"]];
    });
}

- (void)testDeleteSomeLinkingObjects {
    ExpectChange(self, @[@2, @8, @9], @[], @[], ^(RLMRealm *realm) {
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
    ExpectChange(self, @[@4], @[], @[], ^(RLMRealm *realm) {
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

// clang thinks the tests below have retain cycles because `_obj` could retain
// the block passed to addNotificationBlock (but it doesn't)
#pragma clang diagnostic ignored "-Warc-retain-cycles"

@interface ObjectNotifierTests : RLMTestCase
@end

@implementation ObjectNotifierTests {
    NSArray *_initialValues;
    NSArray *_values;
    NSArray<NSString *> *_propertyNames;
    AllTypesObject *_obj;
}

- (void)setUp {
    NSDate *now = [NSDate date];
    StringObject *so = [[StringObject alloc] init];
    so.stringCol = @"string";
    _initialValues = @[@YES, @1, @1.1f, @1.11, @"string",
                       [NSData dataWithBytes:"a" length:1], now, @YES, @11, NSNull.null, @9001, NSNull.null];
    _values = @[@NO, @2, @2.2f, @2.22, @"string2", [NSData dataWithBytes:"b" length:1],
                [now dateByAddingTimeInterval:1], @NO, @22, so, @1234, @5678];

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

- (void)testDeleteObservedObject {
    XCTestExpectation *expectation = [self expectationWithDescription:@""];
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertTrue(deleted);
        XCTAssertNil(error);
        XCTAssertNil(changes);
        [expectation fulfill];
    }];

    RLMRealm *realm = _obj.realm;
    [realm beginWriteTransaction];
    [realm deleteObject:_obj];
    [realm commitWriteTransaction];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [token invalidate];
}

- (void)testChangeAllPropertyTypes {
    __block NSUInteger i = 0;
    __block XCTestExpectation *expectation = nil;
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, _propertyNames[i]);
        XCTAssertNil(prop.previousValue);
        if ([prop.name isEqualToString:@"objectCol"]) {
            XCTAssertTrue([prop.value isEqualToObject:_values[i]],
                          @"%d: %@ %@", (int)i, prop.value, _values[i]);
        }
        else {
            XCTAssertEqualObjects(prop.value, _values[i]);
        }

        [expectation fulfill];
    }];

    for (i = 0; i < _values.count; ++i) {
        expectation = [self expectationWithDescription:@""];

        [_obj.realm beginWriteTransaction];
        _obj[_propertyNames[i]] = _values[i];
        [_obj.realm commitWriteTransaction];

        [self waitForExpectationsWithTimeout:2.0 handler:nil];
    }
    [token invalidate];
}

- (void)testChangeAllPropertyTypesFromBackground {
    __block NSUInteger i = 0;
    RLMNotificationToken *token = [_obj addNotificationBlock:^(BOOL deleted, NSArray *changes, NSError *error) {
        XCTAssertFalse(deleted);
        XCTAssertNil(error);
        XCTAssertEqual(changes.count, 1U);
        RLMPropertyChange *prop = changes[0];
        XCTAssertEqualObjects(prop.name, _propertyNames[i]);
        if ([prop.name isEqualToString:@"objectCol"]) {
            XCTAssertNil(prop.previousValue);
            XCTAssertNotNil(prop.value);
        }
        else {
            XCTAssertEqualObjects(prop.previousValue ?: NSNull.null, _initialValues[i]);
            XCTAssertEqualObjects(prop.value ?: NSNull.null, _values[i]);
        }
    }];

    for (i = 0; i < _values.count; ++i) {
        [self dispatchAsyncAndWait:^{
            RLMRealm *realm = [RLMRealm defaultRealm];
            AllTypesObject *obj = [[AllTypesObject allObjectsInRealm:realm] firstObject];
            [realm beginWriteTransaction];
            obj[_propertyNames[i]] = _values[i];
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
                XCTAssertTrue([prop.value isEqualToObject:_values[i]]);
            }
            else {
                XCTAssertEqualObjects(prop.value, _values[i]);
            }
            ++i;
        }
        [expectation fulfill];
    }];

    [_obj.realm beginWriteTransaction];
    for (NSUInteger i = 0; i < _values.count; ++i) {
        _obj[_propertyNames[i]] = _values[i];
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

@end
