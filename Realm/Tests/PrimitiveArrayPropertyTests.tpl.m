////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

static NSDate *date(int i) {
    return [NSDate dateWithTimeIntervalSince1970:i];
}
static NSData *data(int i) {
    return [NSData dataWithBytesNoCopy:calloc(i, 1) length:i freeWhenDone:YES];
}
static RLMDecimal128 *decimal128(int i) {
    return [RLMDecimal128 decimalWithNumber:@(i)];
}
static NSMutableArray *objectIds;
static RLMObjectId *objectId(NSUInteger i) {
    if (!objectIds) {
        objectIds = [NSMutableArray new];
    }
    while (i >= objectIds.count) {
        [objectIds addObject:RLMObjectId.objectId];
    }
    return objectIds[i];
}
static NSUUID *uuid(NSString *uuidString) {
    return [[NSUUID alloc] initWithUUIDString:uuidString];
}
static void count(NSArray *values, double *sum, NSUInteger *count) {
    for (id value in values) {
        if (value != NSNull.null) {
            ++*count;
            *sum += [value doubleValue];
        }
    }
}
static double sum(NSArray *values) {
    double sum = 0;
    NSUInteger c = 0;
    count(values, &sum, &c);
    return sum;
}
static double average(NSArray *values) {
    double sum = 0;
    NSUInteger c = 0;
    count(values, &sum, &c);
    return sum / c;
}

@interface LinkToAllPrimitiveArrays : RLMObject
@property (nonatomic) AllPrimitiveArrays *link;
@end
@implementation LinkToAllPrimitiveArrays
@end

@interface LinkToAllOptionalPrimitiveArrays : RLMObject
@property (nonatomic) AllOptionalPrimitiveArrays *link;
@end
@implementation LinkToAllOptionalPrimitiveArrays
@end

@interface PrimitiveArrayPropertyTests : RLMTestCase
@end

@implementation PrimitiveArrayPropertyTests {
    AllPrimitiveArrays *unmanaged;
    AllPrimitiveArrays *managed;
    AllOptionalPrimitiveArrays *optUnmanaged;
    AllOptionalPrimitiveArrays *optManaged;
    RLMRealm *realm;
    NSArray<RLMArray *> *allArrays;
}

- (void)setUp {
    unmanaged = [[AllPrimitiveArrays alloc] init];
    optUnmanaged = [[AllOptionalPrimitiveArrays alloc] init];
    realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    managed = [AllPrimitiveArrays createInRealm:realm withValue:@[]];
    optManaged = [AllOptionalPrimitiveArrays createInRealm:realm withValue:@[]];
    allArrays = @[
        $array,
    ];
}

- (void)tearDown {
    if (realm.inWriteTransaction) {
        [realm cancelWriteTransaction];
    }
}

- (void)addObjects {
    [$array addObjects:$values];
}

- (void)testCount {
    uncheckedAssertEqual(unmanaged.intObj.count, 0U);
    [unmanaged.intObj addObject:@1];
    uncheckedAssertEqual(unmanaged.intObj.count, 1U);
}

- (void)testType {
    uncheckedAssertEqual(unmanaged.boolObj.type, RLMPropertyTypeBool);
    uncheckedAssertEqual(unmanaged.intObj.type, RLMPropertyTypeInt);
    uncheckedAssertEqual(unmanaged.floatObj.type, RLMPropertyTypeFloat);
    uncheckedAssertEqual(unmanaged.doubleObj.type, RLMPropertyTypeDouble);
    uncheckedAssertEqual(unmanaged.stringObj.type, RLMPropertyTypeString);
    uncheckedAssertEqual(unmanaged.dataObj.type, RLMPropertyTypeData);
    uncheckedAssertEqual(unmanaged.dateObj.type, RLMPropertyTypeDate);
    uncheckedAssertEqual(unmanaged.anyBoolObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyIntObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyFloatObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyDoubleObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyStringObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyDataObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyDateObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyDecimalObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyObjectIdObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(unmanaged.anyUUIDObj.type, RLMPropertyTypeAny);
    uncheckedAssertEqual(optUnmanaged.boolObj.type, RLMPropertyTypeBool);
    uncheckedAssertEqual(optUnmanaged.intObj.type, RLMPropertyTypeInt);
    uncheckedAssertEqual(optUnmanaged.floatObj.type, RLMPropertyTypeFloat);
    uncheckedAssertEqual(optUnmanaged.doubleObj.type, RLMPropertyTypeDouble);
    uncheckedAssertEqual(optUnmanaged.stringObj.type, RLMPropertyTypeString);
    uncheckedAssertEqual(optUnmanaged.dataObj.type, RLMPropertyTypeData);
    uncheckedAssertEqual(optUnmanaged.dateObj.type, RLMPropertyTypeDate);
}

- (void)testOptional {
    uncheckedAssertFalse(unmanaged.boolObj.optional);
    uncheckedAssertFalse(unmanaged.intObj.optional);
    uncheckedAssertFalse(unmanaged.floatObj.optional);
    uncheckedAssertFalse(unmanaged.doubleObj.optional);
    uncheckedAssertFalse(unmanaged.stringObj.optional);
    uncheckedAssertFalse(unmanaged.dataObj.optional);
    uncheckedAssertFalse(unmanaged.dateObj.optional);
    uncheckedAssertFalse(unmanaged.anyBoolObj.optional);
    uncheckedAssertFalse(unmanaged.anyIntObj.optional);
    uncheckedAssertFalse(unmanaged.anyFloatObj.optional);
    uncheckedAssertFalse(unmanaged.anyDoubleObj.optional);
    uncheckedAssertFalse(unmanaged.anyStringObj.optional);
    uncheckedAssertFalse(unmanaged.anyDataObj.optional);
    uncheckedAssertFalse(unmanaged.anyDateObj.optional);
    uncheckedAssertFalse(unmanaged.anyDecimalObj.optional);
    uncheckedAssertFalse(unmanaged.anyObjectIdObj.optional);
    uncheckedAssertFalse(unmanaged.anyUUIDObj.optional);
    uncheckedAssertTrue(optUnmanaged.boolObj.optional);
    uncheckedAssertTrue(optUnmanaged.intObj.optional);
    uncheckedAssertTrue(optUnmanaged.floatObj.optional);
    uncheckedAssertTrue(optUnmanaged.doubleObj.optional);
    uncheckedAssertTrue(optUnmanaged.stringObj.optional);
    uncheckedAssertTrue(optUnmanaged.dataObj.optional);
    uncheckedAssertTrue(optUnmanaged.dateObj.optional);
}

- (void)testObjectClassName {
    uncheckedAssertNil(unmanaged.boolObj.objectClassName);
    uncheckedAssertNil(unmanaged.intObj.objectClassName);
    uncheckedAssertNil(unmanaged.floatObj.objectClassName);
    uncheckedAssertNil(unmanaged.doubleObj.objectClassName);
    uncheckedAssertNil(unmanaged.stringObj.objectClassName);
    uncheckedAssertNil(unmanaged.dataObj.objectClassName);
    uncheckedAssertNil(unmanaged.dateObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyBoolObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyIntObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyFloatObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyDoubleObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyStringObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyDataObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyDateObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyDecimalObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyObjectIdObj.objectClassName);
    uncheckedAssertNil(unmanaged.anyUUIDObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.boolObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.intObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.floatObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.doubleObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.stringObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.dataObj.objectClassName);
    uncheckedAssertNil(optUnmanaged.dateObj.objectClassName);
}

- (void)testRealm {
    uncheckedAssertNil(unmanaged.boolObj.realm);
    uncheckedAssertNil(unmanaged.intObj.realm);
    uncheckedAssertNil(unmanaged.floatObj.realm);
    uncheckedAssertNil(unmanaged.doubleObj.realm);
    uncheckedAssertNil(unmanaged.stringObj.realm);
    uncheckedAssertNil(unmanaged.dataObj.realm);
    uncheckedAssertNil(unmanaged.dateObj.realm);
    uncheckedAssertNil(unmanaged.anyBoolObj.realm);
    uncheckedAssertNil(unmanaged.anyIntObj.realm);
    uncheckedAssertNil(unmanaged.anyFloatObj.realm);
    uncheckedAssertNil(unmanaged.anyDoubleObj.realm);
    uncheckedAssertNil(unmanaged.anyStringObj.realm);
    uncheckedAssertNil(unmanaged.anyDataObj.realm);
    uncheckedAssertNil(unmanaged.anyDateObj.realm);
    uncheckedAssertNil(unmanaged.anyDecimalObj.realm);
    uncheckedAssertNil(unmanaged.anyObjectIdObj.realm);
    uncheckedAssertNil(unmanaged.anyUUIDObj.realm);
    uncheckedAssertNil(optUnmanaged.boolObj.realm);
    uncheckedAssertNil(optUnmanaged.intObj.realm);
    uncheckedAssertNil(optUnmanaged.floatObj.realm);
    uncheckedAssertNil(optUnmanaged.doubleObj.realm);
    uncheckedAssertNil(optUnmanaged.stringObj.realm);
    uncheckedAssertNil(optUnmanaged.dataObj.realm);
    uncheckedAssertNil(optUnmanaged.dateObj.realm);
}

- (void)testInvalidated {
    RLMArray *array;
    @autoreleasepool {
        AllPrimitiveArrays *obj = [[AllPrimitiveArrays alloc] init];
        array = obj.intObj;
        uncheckedAssertFalse(array.invalidated);
    }
    uncheckedAssertFalse(array.invalidated);
}

- (void)testDeleteObjectsInRealm {
    RLMAssertThrowsWithReason([realm deleteObjects:$allArrays], @"Cannot delete objects from RLMArray");
}

- (void)testObjectAtIndex {
    RLMAssertThrowsWithReason([unmanaged.intObj objectAtIndex:0],
                              @"Index 0 is out of bounds (must be less than 0).");

    [unmanaged.intObj addObject:@1];
    uncheckedAssertEqualObjects([unmanaged.intObj objectAtIndex:0], @1);
}

- (void)testObjectsAtIndexes {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet new];
    [indexSet addIndex:0];
    [indexSet addIndex:2];
    XCTAssertNil([unmanaged.intObj objectsAtIndexes:indexSet]);
    XCTAssertNil([managed.intObj objectsAtIndexes:indexSet]);

    [unmanaged.intObj addObject:@1];
    [unmanaged.intObj addObject:@2];
    [unmanaged.intObj addObject:@3];
    uncheckedAssertEqualObjects([unmanaged.intObj objectsAtIndexes:indexSet], (@[@1, @3]));
    [managed.intObj addObject:@1];
    [managed.intObj addObject:@2];
    [managed.intObj addObject:@3];
    uncheckedAssertEqualObjects([managed.intObj objectsAtIndexes:indexSet], (@[@1, @3]));

    [indexSet addIndex:3];
    XCTAssertNil([unmanaged.intObj objectsAtIndexes:indexSet]);
    XCTAssertNil([managed.intObj objectsAtIndexes:indexSet]);
}

- (void)testFirstObject {
    uncheckedAssertNil($allArrays.firstObject);

    [self addObjects];
    uncheckedAssertEqualObjects($array.firstObject, $first);

    [$allArrays removeAllObjects];

    %o [$array addObject:NSNull.null];
    %o uncheckedAssertEqualObjects($array.firstObject, NSNull.null);
}

- (void)testLastObject {
    uncheckedAssertNil($allArrays.lastObject);

    [self addObjects];

    uncheckedAssertEqualObjects($array.lastObject, $last);

    [$allArrays removeLastObject];
    %o uncheckedAssertEqualObjects($array.lastObject, $v1);
}

- (void)testAddObject {
    %noany RLMAssertThrowsWithReason([$array addObject:$wrong], ^n @"Invalid value '$wdesc' of type '" $wtype "' for expected type '$type'");
    %noany %r RLMAssertThrowsWithReason([$array addObject:NSNull.null], ^n @"Invalid value '<null>' of type 'NSNull' for expected type '$type'");

    [$array addObject:$v0];
    uncheckedAssertEqualObjects($array[0], $v0);

    %o [$array addObject:NSNull.null];
    %o uncheckedAssertEqualObjects($array[1], NSNull.null);
}

- (void)testAddObjects {
    %noany RLMAssertThrowsWithReason([$array addObjects:@[$wrong]], ^n @"Invalid value '$wdesc' of type '" $wtype "' for expected type '$type'");
    %noany %r RLMAssertThrowsWithReason([$array addObjects:@[NSNull.null]], ^n @"Invalid value '<null>' of type 'NSNull' for expected type '$type'");

    [self addObjects];
    uncheckedAssertEqualObjects($array[0], $v0);
    uncheckedAssertEqualObjects($array[1], $v1);
    %o uncheckedAssertEqualObjects($array[2], NSNull.null);
}

- (void)testInsertObject {
    %noany RLMAssertThrowsWithReason([$array insertObject:$wrong atIndex:0], ^n @"Invalid value '$wdesc' of type '" $wtype "' for expected type '$type'");
    %noany %r RLMAssertThrowsWithReason([$array insertObject:NSNull.null atIndex:0], ^n @"Invalid value '<null>' of type 'NSNull' for expected type '$type'");
    RLMAssertThrowsWithReason([$array insertObject:$v0 atIndex:1], ^n @"Index 1 is out of bounds (must be less than 1).");

    [$array insertObject:$v0 atIndex:0];
    uncheckedAssertEqualObjects($array[0], $v0);

    [$array insertObject:$v1 atIndex:0];
    uncheckedAssertEqualObjects($array[0], $v1);
    uncheckedAssertEqualObjects($array[1], $v0);

    %o [$array insertObject:NSNull.null atIndex:1];
    %o uncheckedAssertEqualObjects($array[0], $v1);
    %o uncheckedAssertEqualObjects($array[1], NSNull.null);
    %o uncheckedAssertEqualObjects($array[2], $v0);
}

- (void)testRemoveObject {
    RLMAssertThrowsWithReason([$allArrays removeObjectAtIndex:0], ^n @"Index 0 is out of bounds (must be less than 0).");

    [self addObjects];
    %r uncheckedAssertEqual($array.count, 2U);
    %o uncheckedAssertEqual($array.count, 3U);

    %r RLMAssertThrowsWithReason([$array removeObjectAtIndex:2], ^n @"Index 2 is out of bounds (must be less than 2).");
    %o RLMAssertThrowsWithReason([$array removeObjectAtIndex:3], ^n @"Index 3 is out of bounds (must be less than 3).");

    [$allArrays removeObjectAtIndex:0];
    %r uncheckedAssertEqual($array.count, 1U);
    %o uncheckedAssertEqual($array.count, 2U);

    uncheckedAssertEqualObjects($array[0], $v1);
    %o uncheckedAssertEqualObjects($array[1], NSNull.null);
}

- (void)testRemoveLastObject {
    XCTAssertNoThrow([$allArrays removeLastObject]);

    [self addObjects];
    %r uncheckedAssertEqual($array.count, 2U);
    %o uncheckedAssertEqual($array.count, 3U);

    [$allArrays removeLastObject];
    %r uncheckedAssertEqual($array.count, 1U);
    %o uncheckedAssertEqual($array.count, 2U);

    uncheckedAssertEqualObjects($array[0], $v0);
    %o uncheckedAssertEqualObjects($array[1], $v1);
}

- (void)testReplace {
    RLMAssertThrowsWithReason([$array replaceObjectAtIndex:0 withObject:$v0], ^n @"Index 0 is out of bounds (must be less than 0).");

    [$array addObject:$v0]; ^nl [$array replaceObjectAtIndex:0 withObject:$v1]; ^nl uncheckedAssertEqualObjects($array[0], $v1); ^nl 

    %o [$array replaceObjectAtIndex:0 withObject:NSNull.null]; ^nl uncheckedAssertEqualObjects($array[0], NSNull.null);

    %noany RLMAssertThrowsWithReason([$array replaceObjectAtIndex:0 withObject:$wrong], ^n @"Invalid value '$wdesc' of type '" $wtype "' for expected type '$type'");
    %noany %r RLMAssertThrowsWithReason([$array replaceObjectAtIndex:0 withObject:NSNull.null], ^n @"Invalid value '<null>' of type 'NSNull' for expected type '$type'");
}

- (void)testMove {
    RLMAssertThrowsWithReason([$allArrays moveObjectAtIndex:0 toIndex:1], ^n @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([$allArrays moveObjectAtIndex:1 toIndex:0], ^n @"Index 1 is out of bounds (must be less than 0).");

    [$array addObjects:@[$v0, $v1, $v0, $v1]];

    [$allArrays moveObjectAtIndex:2 toIndex:0];

    uncheckedAssertEqualObjects([$array valueForKey:@"self"], ^n (@[$v0, $v0, $v1, $v1]));
}

- (void)testExchange {
    RLMAssertThrowsWithReason([$allArrays exchangeObjectAtIndex:0 withObjectAtIndex:1], ^n @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([$allArrays exchangeObjectAtIndex:1 withObjectAtIndex:0], ^n @"Index 1 is out of bounds (must be less than 0).");

    [$array addObjects:@[$v0, $v1, $v0, $v1]];

    [$allArrays exchangeObjectAtIndex:2 withObjectAtIndex:1];

    uncheckedAssertEqualObjects([$array valueForKey:@"self"], ^n (@[$v0, $v0, $v1, $v1]));
}

- (void)testIndexOfObject {
    uncheckedAssertEqual(NSNotFound, [$array indexOfObject:$v0]);

    %noany RLMAssertThrowsWithReason([$array indexOfObject:$wrong], ^n @"Invalid value '$wdesc' of type '" $wtype "' for expected type '$type'");

    %noany %r RLMAssertThrowsWithReason([$array indexOfObject:NSNull.null], ^n @"Invalid value '<null>' of type 'NSNull' for expected type '$type'");
    %o uncheckedAssertEqual(NSNotFound, [$array indexOfObject:NSNull.null]);

    [self addObjects];

    uncheckedAssertEqual(1U, [$array indexOfObject:$v1]);
}

- (void)testIndexOfObjectSorted {
    %man %r [$array addObjects:@[$v0, $v1, $v0, $v1]];
    %man %o [$array addObjects:@[$v0, $v1, NSNull.null, $v1, $v0]];

    %man %r uncheckedAssertEqual(0U, [[$array sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:$v1]);
    %man %r uncheckedAssertEqual(2U, [[$array sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:$v0]);

    %man %o uncheckedAssertEqual(0U, [[$array sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:$v1]);
    %man %o uncheckedAssertEqual(2U, [[$array sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:$v0]);
    %man %o uncheckedAssertEqual(4U, [[$array sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
}

- (void)testIndexOfObjectDistinct {
    %man %r [$array addObjects:@[$v0, $v0, $v1]];
    %man %o [$array addObjects:@[$v0, $v0, NSNull.null, $v1, $v0]];

    %man %r uncheckedAssertEqual(0U, [[$array distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:$v0]);
    %man %r uncheckedAssertEqual(1U, [[$array distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:$v1]);

    %man %o uncheckedAssertEqual(0U, [[$array distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:$v0]);
    %man %o uncheckedAssertEqual(2U, [[$array distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:$v1]);
    %man %o uncheckedAssertEqual(1U, [[$array distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
}

- (void)testIndexOfObjectWhere {
    %man RLMAssertThrowsWithReason([$array indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    %man RLMAssertThrowsWithReason([[$array sortedResultsUsingKeyPath:@"self" ascending:NO] ^n  indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");

    %unman uncheckedAssertEqual(NSNotFound, [$array indexOfObjectWhere:@"TRUEPREDICATE"]);

    [self addObjects];

    %unman uncheckedAssertEqual(0U, [$array indexOfObjectWhere:@"TRUEPREDICATE"]);
    %unman uncheckedAssertEqual(NSNotFound, [$array indexOfObjectWhere:@"FALSEPREDICATE"]);
}

- (void)testIndexOfObjectWithPredicate {
    %man RLMAssertThrowsWithReason([$array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    %man RLMAssertThrowsWithReason([[$array sortedResultsUsingKeyPath:@"self" ascending:NO] ^n  indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");

    %unman uncheckedAssertEqual(NSNotFound, [$array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);

    [self addObjects];

    %unman uncheckedAssertEqual(0U, [$array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    %unman uncheckedAssertEqual(NSNotFound, [$array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
}

- (void)testSort {
    %unman RLMAssertThrowsWithReason([$array sortedResultsUsingKeyPath:@"self" ascending:NO], ^n @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    %unman RLMAssertThrowsWithReason([$array sortedResultsUsingDescriptors:@[]], ^n @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    %man RLMAssertThrowsWithReason([$array sortedResultsUsingKeyPath:@"not self" ascending:NO], ^n @"can only be sorted on 'self'");

    %man %r [$array addObjects:@[$v0, $v1, $v0]];
    %man %o [$array addObjects:@[$v0, $v1, NSNull.null, $v1, $v0]];

    %man %r uncheckedAssertEqualObjects([[$array sortedResultsUsingDescriptors:@[]] valueForKey:@"self"], ^n (@[$v0, $v1, $v0]));
    %man %o uncheckedAssertEqualObjects([[$array sortedResultsUsingDescriptors:@[]] valueForKey:@"self"], ^n (@[$v0, $v1, NSNull.null, $v1, $v0]));

    %man %r uncheckedAssertEqualObjects([[$array sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"], ^n (@[$v1, $v0, $v0]));
    %man %o uncheckedAssertEqualObjects([[$array sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"], ^n (@[$v1, $v1, $v0, $v0, NSNull.null]));

    %man %r uncheckedAssertEqualObjects([[$array sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"], ^n (@[$v0, $v0, $v1]));
    %man %o uncheckedAssertEqualObjects([[$array sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"], ^n (@[NSNull.null, $v0, $v0, $v1, $v1]));
}

- (void)testFilter {
    %unman RLMAssertThrowsWithReason([$array objectsWhere:@"TRUEPREDICATE"], ^n @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    %unman RLMAssertThrowsWithReason([$array objectsWithPredicate:[NSPredicate predicateWithValue:YES]], ^n @"This method may only be called on RLMArray instances retrieved from an RLMRealm");

    %man RLMAssertThrowsWithReason([$array objectsWhere:@"TRUEPREDICATE"], ^n @"implemented");
    %man RLMAssertThrowsWithReason([$array objectsWithPredicate:[NSPredicate predicateWithValue:YES]], ^n @"implemented");

    %man RLMAssertThrowsWithReason([[$array sortedResultsUsingKeyPath:@"self" ascending:NO] ^n  objectsWhere:@"TRUEPREDICATE"], @"implemented");
    %man RLMAssertThrowsWithReason([[$array sortedResultsUsingKeyPath:@"self" ascending:NO] ^n  objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
}

- (void)testNotifications {
    %unman RLMAssertThrowsWithReason([$array addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }], ^n @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
}

- (void)testMin {
    %noany %nominmax %unman RLMAssertThrowsWithReason([$array minOfProperty:@"self"], ^n @"minOfProperty: is not supported for $type array");
    %noany %nominmax %man RLMAssertThrowsWithReason([$array minOfProperty:@"self"], ^n @"minOfProperty: is not supported for $type array '$class.$prop'");

    %minmax uncheckedAssertNil([$array minOfProperty:@"self"]);

    [self addObjects];

    %minmax uncheckedAssertEqualObjects([$array minOfProperty:@"self"], $v0);
}

- (void)testMax {
    %noany %nominmax %unman RLMAssertThrowsWithReason([$array maxOfProperty:@"self"], ^n @"maxOfProperty: is not supported for $type array");
    %noany %nominmax %man RLMAssertThrowsWithReason([$array maxOfProperty:@"self"], ^n @"maxOfProperty: is not supported for $type array '$class.$prop'");

    %minmax uncheckedAssertNil([$array maxOfProperty:@"self"]);

    [self addObjects];

    %minmax uncheckedAssertEqualObjects([$array maxOfProperty:@"self"], $v1);
}

- (void)testSum {
    %noany %nosum %unman RLMAssertThrowsWithReason([$array sumOfProperty:@"self"], ^n @"sumOfProperty: is not supported for $type array");
    %noany %nosum %man RLMAssertThrowsWithReason([$array sumOfProperty:@"self"], ^n @"sumOfProperty: is not supported for $type array '$class.$prop'");

    %sum uncheckedAssertEqualObjects([$array sumOfProperty:@"self"], @0);

    [self addObjects];

    %sum XCTAssertEqualWithAccuracy([$array sumOfProperty:@"self"].doubleValue, sum($values), .001);
}

- (void)testAverage {
    %noany %noavg %unman RLMAssertThrowsWithReason([$array averageOfProperty:@"self"], ^n @"averageOfProperty: is not supported for $type array");
    %noany %noavg %man RLMAssertThrowsWithReason([$array averageOfProperty:@"self"], ^n @"averageOfProperty: is not supported for $type array '$class.$prop'");

    %avg uncheckedAssertNil([$array averageOfProperty:@"self"]);

    [self addObjects];

    %avg XCTAssertEqualWithAccuracy([$array averageOfProperty:@"self"].doubleValue, average($values), .001);
}

- (void)testFastEnumeration {
    for (int i = 0; i < 10; ++i) {
        [self addObjects];
    }

    // This is wrapped in a block to work around a compiler bug in Xcode 12.5:
    // in release builds, reads on `values` will read the wrong local variable,
    // resulting in a crash when it tries to send a message to some unitialized
    // stack space. Putting them in separate obj-c blocks prevents this
    // incorrect optimization.
    ^{ ^nl NSUInteger i = 0; ^nl NSArray *values = $values; ^nl for (id value in $array) { ^nl uncheckedAssertEqualObjects(values[i++ % values.count], value); ^nl } ^nl uncheckedAssertEqual(i, $array.count); ^nl }(); ^nl 
}

- (void)testValueForKeySelf {
    uncheckedAssertEqualObjects([$allArrays valueForKey:@"self"], @[]);

    [self addObjects];

    uncheckedAssertEqualObjects([$array valueForKey:@"self"], ($values));
}

- (void)testValueForKeyNumericAggregates {
    %minmax uncheckedAssertNil([$array valueForKeyPath:@"@min.self"]);
    %minmax uncheckedAssertNil([$array valueForKeyPath:@"@max.self"]);
    %noany %sum uncheckedAssertEqualObjects([$array valueForKeyPath:@"@sum.self"], @0);
    %noany %avg uncheckedAssertNil([$array valueForKeyPath:@"@avg.self"]);

    [self addObjects];

    %minmax uncheckedAssertEqualObjects([$array valueForKeyPath:@"@min.self"], $v0);
    %minmax uncheckedAssertEqualObjects([$array valueForKeyPath:@"@max.self"], $v1);
    %noany %sum XCTAssertEqualWithAccuracy([[$array valueForKeyPath:@"@sum.self"] doubleValue], sum($values), .001);
    %noany %avg XCTAssertEqualWithAccuracy([[$array valueForKeyPath:@"@avg.self"] doubleValue], average($values), .001);
}

- (void)testValueForKeyLength {
    uncheckedAssertEqualObjects([$allArrays valueForKey:@"length"], @[]);

    [self addObjects];

    %string uncheckedAssertEqualObjects([$array valueForKey:@"length"], ([$values valueForKey:@"length"]));
}

// Sort the distinct results to match the order used in values, as it
// doesn't preserve the order naturally
static NSArray *sortedDistinctUnion(id array, NSString *type, NSString *prop) {
    return [[array valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOf%@.%@", type, prop]]
            sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                bool aIsNull = a == NSNull.null;
                bool bIsNull = b == NSNull.null;
                if (aIsNull && bIsNull) {
                    return 0;
                }
                if (aIsNull) {
                    return 1;
                }
                if (bIsNull) {
                    return -1;
                }

                if ([a isKindOfClass:[NSData class]]) {
                    if ([a length] != [b length]) {
                        return [a length] < [b length] ? -1 : 1;
                    }
                    int result = memcmp([a bytes], [b bytes], [a length]);
                    if (!result) {
                        return 0;
                    }
                    return result < 0 ? -1 : 1;
                }

                if ([a isKindOfClass:[RLMObjectId class]]) {
                    int64_t idx1 = [objectIds indexOfObject:a];
                    int64_t idx2 = [objectIds indexOfObject:b];
                    return idx1 - idx2;
                }

                if ([a respondsToSelector:@selector(objCType)]
                    && [b respondsToSelector:@selector(objCType)]) {
                    return [a compare:b];
                } else {
                    if ([a isKindOfClass:[RLMDecimal128 class]]) {
                        a = [NSNumber numberWithDouble:[(RLMDecimal128 *)a doubleValue]];
                    }
                    if ([b isKindOfClass:[RLMDecimal128 class]]) {
                        b = [NSNumber numberWithDouble:[(RLMDecimal128 *)b doubleValue]];
                    }
                    return [a compare:b];
                }
            }];
}

- (void)testUnionOfObjects {
    uncheckedAssertEqualObjects([$allArrays valueForKeyPath:@"@unionOfObjects.self"], @[]);
    uncheckedAssertEqualObjects([$allArrays valueForKeyPath:@"@distinctUnionOfObjects.self"], @[]);

    [self addObjects];
    [self addObjects];

    uncheckedAssertEqualObjects([$array valueForKeyPath:@"@unionOfObjects.self"], ^n ($values2));
    uncheckedAssertEqualObjects(sortedDistinctUnion($array, @"Objects", @"self"), ^n ($values));
}

- (void)testUnionOfArrays {
    RLMResults *allRequired = [AllPrimitiveArrays allObjectsInRealm:realm];
    RLMResults *allOptional = [AllOptionalPrimitiveArrays allObjectsInRealm:realm];

    %man %r uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.$prop"], @[]);
    %man %o uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.$prop"], @[]);
    %man %r uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.$prop"], @[]);
    %man %o uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.$prop"], @[]);

    %man %any XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.$prop"], @[]);
    %man %any XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.$prop"], @[]);


    [self addObjects];

    [AllPrimitiveArrays createInRealm:realm withValue:managed];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:optManaged];

    %man %r uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.$prop"], ^n ($values2));
    %man %o uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.$prop"], ^n ($values2));
    %man %r uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"$prop"), ^n ($values));
    %man %o uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"$prop"), ^n ($values));

    %man %any uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.$prop"], ^n ($values2));
    %man %any uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"$prop"), ^n ($values));
}

- (void)testSetValueForKey {
    RLMAssertThrowsWithReason([$allArrays setValue:@0 forKey:@"not self"], ^n @"this class is not key value coding-compliant for the key not self.");
    %noany RLMAssertThrowsWithReason([$array setValue:$wrong forKey:@"self"], ^n @"Invalid value '$wdesc' of type '" $wtype "' for expected type '$type'");
    %noany %r RLMAssertThrowsWithReason([$array setValue:NSNull.null forKey:@"self"], ^n @"Invalid value '<null>' of type 'NSNull' for expected type '$type'");

    [self addObjects];

    [$array setValue:$v0 forKey:@"self"];

    uncheckedAssertEqualObjects($array[0], $v0);
    uncheckedAssertEqualObjects($array[1], $v0);
    %o uncheckedAssertEqualObjects($array[2], $v0);

    %o [$array setValue:NSNull.null forKey:@"self"];
    %o uncheckedAssertEqualObjects($array[0], NSNull.null);
}

- (void)testAssignment {
    $array = (id)@[$v1]; ^nl uncheckedAssertEqualObjects($array[0], $v1);

    // Should replace and not append
    $array = (id)$values; ^nl uncheckedAssertEqualObjects([$array valueForKey:@"self"], ($values)); ^nl 

    // Should not clear the array
    $array = $array; ^nl uncheckedAssertEqualObjects([$array valueForKey:@"self"], ($values)); ^nl 

    [unmanaged.intObj removeAllObjects];
    unmanaged.intObj = managed.intObj;
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"], (@[@2, @3]));

    [managed.intObj removeAllObjects];
    managed.intObj = unmanaged.intObj;
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"], (@[@2, @3]));
}

- (void)testDynamicAssignment {
    $obj[@"$prop"] = (id)@[$v1]; ^nl uncheckedAssertEqualObjects($obj[@"$prop"][0], $v1);

    // Should replace and not append
    $obj[@"$prop"] = (id)$values; ^nl uncheckedAssertEqualObjects([$obj[@"$prop"] valueForKey:@"self"], ($values)); ^nl 

    // Should not clear the array
    $obj[@"$prop"] = $obj[@"$prop"]; ^nl uncheckedAssertEqualObjects([$obj[@"$prop"] valueForKey:@"self"], ($values)); ^nl 

    [unmanaged[@"intObj"] removeAllObjects];
    unmanaged[@"intObj"] = managed.intObj;
    uncheckedAssertEqualObjects([unmanaged[@"intObj"] valueForKey:@"self"], (@[@2, @3]));

    [managed[@"intObj"] removeAllObjects];
    managed[@"intObj"] = unmanaged.intObj;
    uncheckedAssertEqualObjects([managed[@"intObj"] valueForKey:@"self"], (@[@2, @3]));
}

- (void)testInvalidAssignment {
    RLMAssertThrowsWithReason(unmanaged.intObj = (id)@[NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for 'int' array property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(unmanaged.intObj = (id)@[@"a"],
                              @"Invalid value 'a' of type '__NSCFConstantString' for 'int' array property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(unmanaged.intObj = (id)(@[@1, @"a"]),
                              @"Invalid value 'a' of type '__NSCFConstantString' for 'int' array property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(unmanaged.intObj = (id)unmanaged.floatObj,
                              @"RLMArray<float> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(unmanaged.intObj = (id)optUnmanaged.intObj,
                              @"RLMArray<int?> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(unmanaged[@"intObj"] = unmanaged[@"floatObj"],
                              @"RLMArray<float> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(unmanaged[@"intObj"] = optUnmanaged[@"intObj"],
                              @"RLMArray<int?> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");

    RLMAssertThrowsWithReason(managed.intObj = (id)@[NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for 'int' array property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(managed.intObj = (id)@[@"a"],
                              @"Invalid value 'a' of type '__NSCFConstantString' for 'int' array property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(managed.intObj = (id)(@[@1, @"a"]),
                              @"Invalid value 'a' of type '__NSCFConstantString' for 'int' array property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(managed.intObj = (id)managed.floatObj,
                              @"RLMArray<float> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(managed.intObj = (id)optManaged.intObj,
                              @"RLMArray<int?> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(managed[@"intObj"] = (id)managed[@"floatObj"],
                              @"RLMArray<float> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
    RLMAssertThrowsWithReason(managed[@"intObj"] = (id)optManaged[@"intObj"],
                              @"RLMArray<int?> does not match expected type 'int' for property 'AllPrimitiveArrays.intObj'.");
}

- (void)testAllMethodsCheckThread {
    RLMArray *array = managed.intObj;
    [self dispatchAsyncAndWait:^{
        RLMAssertThrowsWithReason([array count], @"thread");
        RLMAssertThrowsWithReason([array objectAtIndex:0], @"thread");
        RLMAssertThrowsWithReason([array firstObject], @"thread");
        RLMAssertThrowsWithReason([array lastObject], @"thread");

        RLMAssertThrowsWithReason([array addObject:@0], @"thread");
        RLMAssertThrowsWithReason([array addObjects:@[@0]], @"thread");
        RLMAssertThrowsWithReason([array insertObject:@0 atIndex:0], @"thread");
        RLMAssertThrowsWithReason([array removeObjectAtIndex:0], @"thread");
        RLMAssertThrowsWithReason([array removeLastObject], @"thread");
        RLMAssertThrowsWithReason([array removeAllObjects], @"thread");
        RLMAssertThrowsWithReason([array replaceObjectAtIndex:0 withObject:@0], @"thread");
        RLMAssertThrowsWithReason([array moveObjectAtIndex:0 toIndex:1], @"thread");
        RLMAssertThrowsWithReason([array exchangeObjectAtIndex:0 withObjectAtIndex:1], @"thread");

        RLMAssertThrowsWithReason([array indexOfObject:@1], @"thread");
        /* RLMAssertThrowsWithReason([array indexOfObjectWhere:@"TRUEPREDICATE"], @"thread"); */
        /* RLMAssertThrowsWithReason([array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]], @"thread"); */
        /* RLMAssertThrowsWithReason([array objectsWhere:@"TRUEPREDICATE"], @"thread"); */
        /* RLMAssertThrowsWithReason([array objectsWithPredicate:[NSPredicate predicateWithValue:NO]], @"thread"); */
        RLMAssertThrowsWithReason([array sortedResultsUsingKeyPath:@"self" ascending:YES], @"thread");
        RLMAssertThrowsWithReason([array sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"self" ascending:YES]]], @"thread");
        RLMAssertThrowsWithReason(array[0], @"thread");
        RLMAssertThrowsWithReason(array[0] = @0, @"thread");
        RLMAssertThrowsWithReason([array valueForKey:@"self"], @"thread");
        RLMAssertThrowsWithReason([array setValue:@1 forKey:@"self"], @"thread");
        RLMAssertThrowsWithReason(({for (__unused id obj in array);}), @"thread");
    }];
}

- (void)testAllMethodsCheckForInvalidation {
    RLMArray *array = managed.intObj;
    [realm cancelWriteTransaction];
    [realm invalidate];

    XCTAssertNoThrow([array objectClassName]);
    XCTAssertNoThrow([array realm]);
    XCTAssertNoThrow([array isInvalidated]);

    RLMAssertThrowsWithReason([array count], @"invalidated");
    RLMAssertThrowsWithReason([array objectAtIndex:0], @"invalidated");
    RLMAssertThrowsWithReason([array firstObject], @"invalidated");
    RLMAssertThrowsWithReason([array lastObject], @"invalidated");

    RLMAssertThrowsWithReason([array addObject:@0], @"invalidated");
    RLMAssertThrowsWithReason([array addObjects:@[@0]], @"invalidated");
    RLMAssertThrowsWithReason([array insertObject:@0 atIndex:0], @"invalidated");
    RLMAssertThrowsWithReason([array removeObjectAtIndex:0], @"invalidated");
    RLMAssertThrowsWithReason([array removeLastObject], @"invalidated");
    RLMAssertThrowsWithReason([array removeAllObjects], @"invalidated");
    RLMAssertThrowsWithReason([array replaceObjectAtIndex:0 withObject:@0], @"invalidated");
    RLMAssertThrowsWithReason([array moveObjectAtIndex:0 toIndex:1], @"invalidated");
    RLMAssertThrowsWithReason([array exchangeObjectAtIndex:0 withObjectAtIndex:1], @"invalidated");

    RLMAssertThrowsWithReason([array indexOfObject:@1], @"invalidated");
    /* RLMAssertThrowsWithReason([array indexOfObjectWhere:@"TRUEPREDICATE"], @"invalidated"); */
    /* RLMAssertThrowsWithReason([array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"invalidated"); */
    /* RLMAssertThrowsWithReason([array objectsWhere:@"TRUEPREDICATE"], @"invalidated"); */
    /* RLMAssertThrowsWithReason([array objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"invalidated"); */
    RLMAssertThrowsWithReason([array sortedResultsUsingKeyPath:@"self" ascending:YES], @"invalidated");
    RLMAssertThrowsWithReason([array sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"self" ascending:YES]]], @"invalidated");
    RLMAssertThrowsWithReason(array[0], @"invalidated");
    RLMAssertThrowsWithReason(array[0] = @0, @"invalidated");
    RLMAssertThrowsWithReason([array valueForKey:@"self"], @"invalidated");
    RLMAssertThrowsWithReason([array setValue:@1 forKey:@"self"], @"invalidated");
    RLMAssertThrowsWithReason(({for (__unused id obj in array);}), @"invalidated");

    [realm beginWriteTransaction];
}

- (void)testMutatingMethodsCheckForWriteTransaction {
    RLMArray *array = managed.intObj;
    [array addObject:@0];
    [realm commitWriteTransaction];

    XCTAssertNoThrow([array objectClassName]);
    XCTAssertNoThrow([array realm]);
    XCTAssertNoThrow([array isInvalidated]);

    XCTAssertNoThrow([array count]);
    XCTAssertNoThrow([array objectAtIndex:0]);
    XCTAssertNoThrow([array firstObject]);
    XCTAssertNoThrow([array lastObject]);

    XCTAssertNoThrow([array indexOfObject:@1]);
    /* XCTAssertNoThrow([array indexOfObjectWhere:@"TRUEPREDICATE"]); */
    /* XCTAssertNoThrow([array indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]); */
    /* XCTAssertNoThrow([array objectsWhere:@"TRUEPREDICATE"]); */
    /* XCTAssertNoThrow([array objectsWithPredicate:[NSPredicate predicateWithValue:YES]]); */
    XCTAssertNoThrow([array sortedResultsUsingKeyPath:@"self" ascending:YES]);
    XCTAssertNoThrow([array sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:@"self" ascending:YES]]]);
    XCTAssertNoThrow(array[0]);
    XCTAssertNoThrow([array valueForKey:@"self"]);
    XCTAssertNoThrow(({for (__unused id obj in array);}));


    RLMAssertThrowsWithReason([array addObject:@0], @"write transaction");
    RLMAssertThrowsWithReason([array addObjects:@[@0]], @"write transaction");
    RLMAssertThrowsWithReason([array insertObject:@0 atIndex:0], @"write transaction");
    RLMAssertThrowsWithReason([array removeObjectAtIndex:0], @"write transaction");
    RLMAssertThrowsWithReason([array removeLastObject], @"write transaction");
    RLMAssertThrowsWithReason([array removeAllObjects], @"write transaction");
    RLMAssertThrowsWithReason([array replaceObjectAtIndex:0 withObject:@0], @"write transaction");
    RLMAssertThrowsWithReason([array moveObjectAtIndex:0 toIndex:1], @"write transaction");
    RLMAssertThrowsWithReason([array exchangeObjectAtIndex:0 withObjectAtIndex:1], @"write transaction");

    RLMAssertThrowsWithReason(array[0] = @0, @"write transaction");
    RLMAssertThrowsWithReason([array setValue:@1 forKey:@"self"], @"write transaction");
}

- (void)testDeleteOwningObject {
    RLMArray *array = managed.intObj;
    uncheckedAssertFalse(array.isInvalidated);
    [realm deleteObject:managed];
    uncheckedAssertTrue(array.isInvalidated);
}

#pragma clang diagnostic ignored "-Warc-retain-cycles"

- (void)testNotificationSentInitially {
    [realm commitWriteTransaction];

    id expectation = [self expectationWithDescription:@""];
    id token = [managed.intObj addNotificationBlock:^(RLMArray *array, RLMCollectionChange *change, NSError *error) {
        XCTAssertNotNil(array);
        uncheckedAssertNil(change);
        uncheckedAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [(RLMNotificationToken *)token invalidate];
}

- (void)testNotificationSentAfterCommit {
    [realm commitWriteTransaction];

    __block bool first = true;
    __block id expectation = [self expectationWithDescription:@""];
    id token = [managed.intObj addNotificationBlock:^(RLMArray *array, RLMCollectionChange *change, NSError *error) {
        XCTAssertNotNil(array);
        uncheckedAssertNil(error);
        if (first) {
            uncheckedAssertNil(change);
        }
        else {
            uncheckedAssertEqualObjects(change.insertions, @[@0]);
        }

        first = false;
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    expectation = [self expectationWithDescription:@""];
    [self dispatchAsyncAndWait:^{
        RLMRealm *r = [RLMRealm defaultRealm];
        [r transactionWithBlock:^{
            RLMArray *array = [(AllPrimitiveArrays *)[AllPrimitiveArrays allObjectsInRealm:r].firstObject intObj];
            [array addObject:@0];
        }];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [(RLMNotificationToken *)token invalidate];
}

- (void)testNotificationNotSentForUnrelatedChange {
    [realm commitWriteTransaction];

    id expectation = [self expectationWithDescription:@""];
    id token = [managed.intObj addNotificationBlock:^(__unused RLMArray *array, __unused RLMCollectionChange *change, __unused NSError *error) {
        // will throw if it's incorrectly called a second time due to the
        // unrelated write transaction
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    // All notification blocks are called as part of a single runloop event, so
    // waiting for this one also waits for the above one to get a chance to run
    [self waitForNotification:RLMRealmDidChangeNotification realm:realm block:^{
        [self dispatchAsyncAndWait:^{
            RLMRealm *r = [RLMRealm defaultRealm];
            [r transactionWithBlock:^{
                [AllPrimitiveArrays createInRealm:r withValue:@[]];
            }];
        }];
    }];
    [(RLMNotificationToken *)token invalidate];
}

- (void)testNotificationSentOnlyForActualRefresh {
    [realm commitWriteTransaction];

    __block id expectation = [self expectationWithDescription:@""];
    id token = [managed.intObj addNotificationBlock:^(RLMArray *array, __unused RLMCollectionChange *change, NSError *error) {
        XCTAssertNotNil(array);
        uncheckedAssertNil(error);
        // will throw if it's called a second time before we create the new
        // expectation object immediately before manually refreshing
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    // Turn off autorefresh, so the background commit should not result in a notification
    realm.autorefresh = NO;

    // All notification blocks are called as part of a single runloop event, so
    // waiting for this one also waits for the above one to get a chance to run
    [self waitForNotification:RLMRealmRefreshRequiredNotification realm:realm block:^{
        [self dispatchAsyncAndWait:^{
            RLMRealm *r = [RLMRealm defaultRealm];
            [r transactionWithBlock:^{
                RLMArray *array = [(AllPrimitiveArrays *)[AllPrimitiveArrays allObjectsInRealm:r].firstObject intObj];
                [array addObject:@0];
            }];
        }];
    }];

    expectation = [self expectationWithDescription:@""];
    [realm refresh];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [(RLMNotificationToken *)token invalidate];
}

- (void)testDeletingObjectWithNotificationsRegistered {
    [managed.intObj addObjects:@[@10, @20]];
    [realm commitWriteTransaction];

    __block bool first = true;
    __block id expectation = [self expectationWithDescription:@""];
    id token = [managed.intObj addNotificationBlock:^(RLMArray *array, RLMCollectionChange *change, NSError *error) {
        XCTAssertNotNil(array);
        uncheckedAssertNil(error);
        if (first) {
            uncheckedAssertNil(change);
            first = false;
        }
        else {
            uncheckedAssertEqualObjects(change.deletions, (@[@0, @1]));
        }
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [realm beginWriteTransaction];
    [realm deleteObject:managed];
    [realm commitWriteTransaction];

    expectation = [self expectationWithDescription:@""];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [(RLMNotificationToken *)token invalidate];
}

#pragma mark - Queries

#define RLMAssertCount(cls, expectedCount, ...) \
    uncheckedAssertEqual(expectedCount, ([cls objectsInRealm:realm where:__VA_ARGS__].count))

- (void)createObjectWithValueIndex:(NSUInteger)index {
    NSRange range = {index, 1};
    id obj = [AllPrimitiveArrays createInRealm:realm withValue:@{
        %r %man @"$prop": [$values subarrayWithRange:range],
        %any %man @"$prop": [$values subarrayWithRange:range],
    }];
    [LinkToAllPrimitiveArrays createInRealm:realm withValue:@[obj]];
    obj = [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %o %man @"$prop": [$values subarrayWithRange:range],
    }];
    [LinkToAllOptionalPrimitiveArrays createInRealm:realm withValue:@[obj]];
}

- (void)testQueryBasicOperators {
    [realm deleteAllObjects];

    %man RLMAssertCount($class, 0, @"ANY $prop = %@", $v0);
    %man RLMAssertCount($class, 0, @"ANY $prop != %@", $v0);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop > %@", $v0);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop >= %@", $v0);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop < %@", $v0);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop <= %@", $v0);

    [self createObjectWithValueIndex:0];

    %man RLMAssertCount($class, 0, @"ANY $prop = %@", $v1);
    %man RLMAssertCount($class, 1, @"ANY $prop = %@", $v0);
    %man RLMAssertCount($class, 0, @"ANY $prop != %@", $v0);
    %man RLMAssertCount($class, 1, @"ANY $prop != %@", $v1);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop > %@", $v0);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop >= %@", $v0);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop < %@", $v0);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop < %@", $v1);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop <= %@", $v0);

    [self createObjectWithValueIndex:1];

    %man RLMAssertCount($class, 1, @"ANY $prop = %@", $v0);
    %man RLMAssertCount($class, 1, @"ANY $prop = %@", $v1);
    %man RLMAssertCount($class, 1, @"ANY $prop != %@", $v0);
    %man RLMAssertCount($class, 1, @"ANY $prop != %@", $v1);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop > %@", $v0);
    %man %minmax RLMAssertCount($class, 2, @"ANY $prop >= %@", $v0);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop < %@", $v0);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop < %@", $v1);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop <= %@", $v0);
    %man %minmax RLMAssertCount($class, 2, @"ANY $prop <= %@", $v1);

    %man %nominmax %noany RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"ANY $prop > %@", $v0]), ^n @"Operator '>' not supported for type '$basetype'");
}

- (void)testQueryBetween {
    [realm deleteAllObjects];

    %noany %man %nominmax RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"ANY $prop BETWEEN %@", @[$v0, $v1]]), ^n @"Operator 'BETWEEN' not supported for type '$basetype'");

    %man %minmax RLMAssertCount($class, 0, @"ANY $prop BETWEEN %@", @[$v0, $v1]);

    [self createObjectWithValueIndex:0];

    %man %minmax RLMAssertCount($class, 1, @"ANY $prop BETWEEN %@", @[$v0, $v0]);
    %man %minmax RLMAssertCount($class, 1, @"ANY $prop BETWEEN %@", @[$v0, $v1]);
    %man %minmax RLMAssertCount($class, 0, @"ANY $prop BETWEEN %@", @[$v1, $v1]);
}

- (void)testQueryIn {
    [realm deleteAllObjects];

    %man RLMAssertCount($class, 0, @"ANY $prop IN %@", @[$v0, $v1]);

    [self createObjectWithValueIndex:0];

    %man RLMAssertCount($class, 0, @"ANY $prop IN %@", @[$v1]);
    %man RLMAssertCount($class, 1, @"ANY $prop IN %@", @[$v0, $v1]);
}

- (void)testQueryCount {
    [realm deleteAllObjects];

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %r %man @"$prop": @[],
        %any %man @"$prop": @[],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %o %man @"$prop": @[],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %r %man @"$prop": @[$v0],
        %any %man @"$prop": @[$v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %o %man @"$prop": @[$v0],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %r %man @"$prop": @[$v0, $v0],
        %any %man @"$prop": @[$v0, $v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %o %man @"$prop": @[$v0, $v0],
    }];

    for (unsigned int i = 0; i < 3; ++i) {
        %man RLMAssertCount($class, 1U, @"$prop.@count == %@", @(i));
        %man RLMAssertCount($class, 2U, @"$prop.@count != %@", @(i));
        %man RLMAssertCount($class, 2 - i, @"$prop.@count > %@", @(i));
        %man RLMAssertCount($class, 3 - i, @"$prop.@count >= %@", @(i));
        %man RLMAssertCount($class, i, @"$prop.@count < %@", @(i));
        %man RLMAssertCount($class, i + 1, @"$prop.@count <= %@", @(i));
    }
}

- (void)testQuerySum {
    [realm deleteAllObjects];

    %noany %nodate %nosum %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@sum = %@", $v0]), ^n @"@sum can only be applied to a numeric property.");
    %noany %date %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@sum = %@", $v0]), ^n @"Cannot sum or average date properties");

    %noany %sum %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@sum = %@", $wrong]), ^n @"@sum on a property of type $basetype cannot be compared with '$wdesc'");
    %noany %sum %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@sum.prop = %@", $wrong]), ^n @"Property '$prop' is not a link in object of type '$class'");
    %noany %sum %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@sum = %@", NSNull.null]), ^n @"@sum on a property of type $basetype cannot be compared with '<null>'");

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %sum @"$prop": @[],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %sum @"$prop": @[],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %sum @"$prop": @[$v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %sum @"$prop": @[$v0],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %sum @"$prop": @[$v0, $v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %sum @"$prop": @[$v0, $v0],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %sum @"$prop": @[$v0, $v0, $v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %sum @"$prop": @[$v0, $v0, $v0],
    }];

    %noany %sum %man RLMAssertCount($class, 1U, @"$prop.@sum == %@", @0);
    %noany %sum %man RLMAssertCount($class, 1U, @"$prop.@sum == %@", $v0);
    %noany %sum %man RLMAssertCount($class, 3U, @"$prop.@sum != %@", $v0);
    %noany %sum %man RLMAssertCount($class, 3U, @"$prop.@sum >= %@", $v0);
    %noany %sum %man RLMAssertCount($class, 2U, @"$prop.@sum > %@", $v0);
    %noany %sum %man RLMAssertCount($class, 2U, @"$prop.@sum < %@", $v1);
    %noany %sum %man RLMAssertCount($class, 2U, @"$prop.@sum <= %@", $v1);
}

- (void)testQueryAverage {
    [realm deleteAllObjects];

    %noany %nodate %noavg %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@avg = %@", $v0]), ^n @"@avg can only be applied to a numeric property.");
    %noany %date %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@avg = %@", $v0]), ^n @"Cannot sum or average date properties");
    %noany %any %date %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@avg = %@", $v0]), ^n @"Cannot sum or average date properties");

    %noany %avg %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@avg = %@", $wrong]), ^n @"@avg on a property of type $basetype cannot be compared with '$wdesc'");
    %noany %avg %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@avg.prop = %@", $wrong]), ^n @"Property '$prop' is not a link in object of type '$class'");

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %avg @"$prop": @[],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %avg @"$prop": @[],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %avg @"$prop": @[$v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %avg @"$prop": @[$v0],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %avg @"$prop": @[$v0, $v1],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %avg @"$prop": @[$v0, $v1],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %man %r %avg @"$prop": @[$v1],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %man %o %avg @"$prop": @[$v1],
    }];

    %noany %avg %man RLMAssertCount($class, 1U, @"$prop.@avg == %@", NSNull.null);
    %noany %avg %man RLMAssertCount($class, 1U, @"$prop.@avg == %@", $v0);
    %noany %avg %man RLMAssertCount($class, 3U, @"$prop.@avg != %@", $v0);
    %noany %avg %man RLMAssertCount($class, 3U, @"$prop.@avg >= %@", $v0);
    %noany %avg %man RLMAssertCount($class, 2U, @"$prop.@avg > %@", $v0);
    %noany %avg %man RLMAssertCount($class, 2U, @"$prop.@avg < %@", $v1);
    %noany %avg %man RLMAssertCount($class, 3U, @"$prop.@avg <= %@", $v1);
}

- (void)testQueryMin {
    [realm deleteAllObjects];

    %noany %nominmax %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@min = %@", $v0]), ^n @"@min can only be applied to a numeric property.");
    %noany %minmax %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@min = %@", $wrong]), ^n @"@min on a property of type $basetype cannot be compared with '$wdesc'");
    %minmax %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@min.prop = %@", $wrong]), ^n @"Property '$prop' is not a link in object of type '$class'");

    // No objects, so count is zero
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@min == %@", $v0);

    [AllPrimitiveArrays createInRealm:realm withValue:@{}];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{}];

    // Only empty arrays, so count is zero
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@min == %@", $v0);
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@min == %@", $v1);

    %minmax %man RLMAssertCount($class, 1U, @"$prop.@min == nil");
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@min == %@", NSNull.null);

    [self createObjectWithValueIndex:0];

    // One object where v0 is min and zero with v1
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@min == %@", $v0);
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@min == %@", $v1);

    [self createObjectWithValueIndex:1];

    // One object where v0 is min and one with v1
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@min == %@", $v0);
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@min == %@", $v1);

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %minmax %r %man @"$prop": @[$v1, $v0],
        %minmax %any %man @"$prop": @[$v1, $v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %minmax %o %man @"$prop": @[$v1, $v0],
    }];

    // New object with both v0 and v1 matches v0 but not v1
    %minmax %man RLMAssertCount($class, 2U, @"$prop.@min == %@", $v0);
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@min == %@", $v1);
}

- (void)testQueryMax {
    [realm deleteAllObjects];

    %noany %nominmax %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@max = %@", $v0]), ^n @"@max can only be applied to a numeric property.");
    %noany %minmax %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@max = %@", $wrong]), ^n @"@max on a property of type $basetype cannot be compared with '$wdesc'");
    %minmax %man RLMAssertThrowsWithReason(([$class objectsInRealm:realm where:@"$prop.@max.prop = %@", $wrong]), ^n @"Property '$prop' is not a link in object of type '$class'");

    // No objects, so count is zero
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@max == %@", $v0);

    [AllPrimitiveArrays createInRealm:realm withValue:@{}];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{}];

    // Only empty arrays, so count is zero
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@max == %@", $v0);
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@max == %@", $v1);

    %minmax %man RLMAssertCount($class, 1U, @"$prop.@max == nil");
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@max == %@", NSNull.null);

    [self createObjectWithValueIndex:0];

    // One object where v0 is min and zero with v1
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@max == %@", $v0);
    %minmax %man RLMAssertCount($class, 0U, @"$prop.@max == %@", $v1);

    [self createObjectWithValueIndex:1];

    // One object where v0 is min and one with v1
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@max == %@", $v0);
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@max == %@", $v1);

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        %minmax %r %man @"$prop": @[$v1, $v0],
        %any %minmax %man @"$prop": @[$v1, $v0],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        %minmax %o %man @"$prop": @[$v1, $v0],
    }];

    // New object with both v0 and v1 matches v1 but not v0
    %minmax %man RLMAssertCount($class, 1U, @"$prop.@max == %@", $v0);
    %minmax %man RLMAssertCount($class, 2U, @"$prop.@max == %@", $v1);
}

- (void)testQueryBasicOperatorsOverLink {
    [realm deleteAllObjects];

    %man RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop = %@", $v0);
    %man RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop != %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop > %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop >= %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop < %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop <= %@", $v0);

    [self createObjectWithValueIndex:0];

    %man RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop = %@", $v1);
    %man RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop = %@", $v0);
    %man RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop != %@", $v0);
    %man RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop != %@", $v1);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop > %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop >= %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop < %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop < %@", $v1);
    %man %minmax RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop <= %@", $v0);

    [self createObjectWithValueIndex:1];

    %man RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop = %@", $v0);
    %man RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop = %@", $v1);
    %man RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop != %@", $v0);
    %man RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop != %@", $v1);
    %man %minmax RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop > %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 2, @"ANY link.$prop >= %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 0, @"ANY link.$prop < %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop < %@", $v1);
    %man %minmax RLMAssertCount(LinkTo$class, 1, @"ANY link.$prop <= %@", $v0);
    %man %minmax RLMAssertCount(LinkTo$class, 2, @"ANY link.$prop <= %@", $v1);

    %man %nominmax %noany RLMAssertThrowsWithReason(([LinkTo$class objectsInRealm:realm where:@"ANY link.$prop > %@", $v0]), ^n @"Operator '>' not supported for type '$basetype'");
}

- (void)testSubstringQueries {
    NSArray *values = @[
        @"",

        @"á", @"ó", @"ú",

        @"áá", @"áó", @"áú",
        @"óá", @"óó", @"óú",
        @"úá", @"úó", @"úú",

        @"ááá", @"ááó", @"ááú", @"áóá", @"áóó", @"áóú", @"áúá", @"áúó", @"áúú",
        @"óáá", @"óáó", @"óáú", @"óóá", @"óóó", @"óóú", @"óúá", @"óúó", @"óúú",
        @"úáá", @"úáó", @"úáú", @"úóá", @"úóó", @"úóú", @"úúá", @"úúó", @"úúú",
    ];

    void (^create)(NSString *) = ^(NSString *value) {
        id obj = [AllPrimitiveArrays createInRealm:realm withValue:@{
            @"stringObj": @[value],
            @"dataObj": @[[value dataUsingEncoding:NSUTF8StringEncoding]]
        }];
        [LinkToAllPrimitiveArrays createInRealm:realm withValue:@[obj]];
        obj = [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
            @"stringObj": @[value],
            @"dataObj": @[[value dataUsingEncoding:NSUTF8StringEncoding]]
        }];
        [LinkToAllOptionalPrimitiveArrays createInRealm:realm withValue:@[obj]];
    };

    for (NSString *value in values) {
        create(value);
        create(value.uppercaseString);
        create([value stringByApplyingTransform:NSStringTransformStripDiacritics reverse:NO]);
        create([value.uppercaseString stringByApplyingTransform:NSStringTransformStripDiacritics reverse:NO]);
    }

    void (^test)(NSString *, id, NSUInteger) = ^(NSString *operator, NSString *value, NSUInteger count) {
        NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];

        NSString *query = [NSString stringWithFormat:@"ANY stringObj %@ %%@", operator];
        %man %string RLMAssertCount($class, count, query, value);
        query = [NSString stringWithFormat:@"ANY link.stringObj %@ %%@", operator];
        %man %string RLMAssertCount(LinkTo$class, count, query, value);

        query = [NSString stringWithFormat:@"ANY dataObj %@ %%@", operator];
        %man %string RLMAssertCount($class, count, query, data);
        query = [NSString stringWithFormat:@"ANY link.dataObj %@ %%@", operator];
        %man %string RLMAssertCount(LinkTo$class, count, query, data);
    };
    void (^testNull)(NSString *, NSUInteger) = ^(NSString *operator, NSUInteger count) {
        NSString *query = [NSString stringWithFormat:@"ANY stringObj %@ nil", operator];
        RLMAssertThrowsWithReason([AllPrimitiveArrays objectsInRealm:realm where:query],
                                  @"Expected object of type string for property 'stringObj' on object of type 'AllPrimitiveArrays', but received: (null)");
        RLMAssertCount(AllOptionalPrimitiveArrays, count, query, NSNull.null);
        query = [NSString stringWithFormat:@"ANY link.stringObj %@ nil", operator];
        RLMAssertThrowsWithReason([LinkToAllPrimitiveArrays objectsInRealm:realm where:query],
                                  @"Expected object of type string for property 'link.stringObj' on object of type 'LinkToAllPrimitiveArrays', but received: (null)");
        RLMAssertCount(LinkToAllOptionalPrimitiveArrays, count, query, NSNull.null);

        query = [NSString stringWithFormat:@"ANY dataObj %@ nil", operator];
        RLMAssertThrowsWithReason([AllPrimitiveArrays objectsInRealm:realm where:query],
                                  @"Expected object of type data for property 'dataObj' on object of type 'AllPrimitiveArrays', but received: (null)");
        RLMAssertCount(AllOptionalPrimitiveArrays, count, query, NSNull.null);

        query = [NSString stringWithFormat:@"ANY link.dataObj %@ nil", operator];
        RLMAssertThrowsWithReason([LinkToAllPrimitiveArrays objectsInRealm:realm where:query],
                                  @"Expected object of type data for property 'link.dataObj' on object of type 'LinkToAllPrimitiveArrays', but received: (null)");
        RLMAssertCount(LinkToAllOptionalPrimitiveArrays, count, query, NSNull.null);
    };

    // Core's implementation of case-insensitive comparisons only works for
    // unaccented a-z, so the diacritic-sensitive, case-insensitive queries
    // match half as many as they should. Many of the below tests will start
    // failing if this is fixed.

    testNull(@"==", 0);
    test(@"==", @"", 4);
    test(@"==", @"a", 1);
    test(@"==", @"á", 1);
    test(@"==[c]", @"a", 2);
    test(@"==[c]", @"á", 1);
    test(@"==", @"A", 1);
    test(@"==", @"Á", 1);
    test(@"==[c]", @"A", 2);
    test(@"==[c]", @"Á", 1);
    test(@"==[d]", @"a", 2);
    test(@"==[d]", @"á", 2);
    test(@"==[cd]", @"a", 4);
    test(@"==[cd]", @"á", 4);
    test(@"==[d]", @"A", 2);
    test(@"==[d]", @"Á", 2);
    test(@"==[cd]", @"A", 4);
    test(@"==[cd]", @"Á", 4);

    testNull(@"!=", 160);
    test(@"!=", @"", 156);
    test(@"!=", @"a", 159);
    test(@"!=", @"á", 159);
    test(@"!=[c]", @"a", 158);
    test(@"!=[c]", @"á", 159);
    test(@"!=", @"A", 159);
    test(@"!=", @"Á", 159);
    test(@"!=[c]", @"A", 158);
    test(@"!=[c]", @"Á", 159);
    test(@"!=[d]", @"a", 158);
    test(@"!=[d]", @"á", 158);
    test(@"!=[cd]", @"a", 156);
    test(@"!=[cd]", @"á", 156);
    test(@"!=[d]", @"A", 158);
    test(@"!=[d]", @"Á", 158);
    test(@"!=[cd]", @"A", 156);
    test(@"!=[cd]", @"Á", 156);

    testNull(@"CONTAINS", 0);
    testNull(@"CONTAINS[c]", 0);
    testNull(@"CONTAINS[d]", 0);
    testNull(@"CONTAINS[cd]", 0);
    test(@"CONTAINS", @"a", 25);
    test(@"CONTAINS", @"á", 25);
    test(@"CONTAINS[c]", @"a", 50);
    test(@"CONTAINS[c]", @"á", 25);
    test(@"CONTAINS", @"A", 25);
    test(@"CONTAINS", @"Á", 25);
    test(@"CONTAINS[c]", @"A", 50);
    test(@"CONTAINS[c]", @"Á", 25);
    test(@"CONTAINS[d]", @"a", 50);
    test(@"CONTAINS[d]", @"á", 50);
    test(@"CONTAINS[cd]", @"a", 100);
    test(@"CONTAINS[cd]", @"á", 100);
    test(@"CONTAINS[d]", @"A", 50);
    test(@"CONTAINS[d]", @"Á", 50);
    test(@"CONTAINS[cd]", @"A", 100);
    test(@"CONTAINS[cd]", @"Á", 100);

    test(@"BEGINSWITH", @"a", 13);
    test(@"BEGINSWITH", @"á", 13);
    test(@"BEGINSWITH[c]", @"a", 26);
    test(@"BEGINSWITH[c]", @"á", 13);
    test(@"BEGINSWITH", @"A", 13);
    test(@"BEGINSWITH", @"Á", 13);
    test(@"BEGINSWITH[c]", @"A", 26);
    test(@"BEGINSWITH[c]", @"Á", 13);
    test(@"BEGINSWITH[d]", @"a", 26);
    test(@"BEGINSWITH[d]", @"á", 26);
    test(@"BEGINSWITH[cd]", @"a", 52);
    test(@"BEGINSWITH[cd]", @"á", 52);
    test(@"BEGINSWITH[d]", @"A", 26);
    test(@"BEGINSWITH[d]", @"Á", 26);
    test(@"BEGINSWITH[cd]", @"A", 52);
    test(@"BEGINSWITH[cd]", @"Á", 52);

    test(@"ENDSWITH", @"a", 13);
    test(@"ENDSWITH", @"á", 13);
    test(@"ENDSWITH[c]", @"a", 26);
    test(@"ENDSWITH[c]", @"á", 13);
    test(@"ENDSWITH", @"A", 13);
    test(@"ENDSWITH", @"Á", 13);
    test(@"ENDSWITH[c]", @"A", 26);
    test(@"ENDSWITH[c]", @"Á", 13);
    test(@"ENDSWITH[d]", @"a", 26);
    test(@"ENDSWITH[d]", @"á", 26);
    test(@"ENDSWITH[cd]", @"a", 52);
    test(@"ENDSWITH[cd]", @"á", 52);
    test(@"ENDSWITH[d]", @"A", 26);
    test(@"ENDSWITH[d]", @"Á", 26);
    test(@"ENDSWITH[cd]", @"A", 52);
    test(@"ENDSWITH[cd]", @"Á", 52);
}

@end
