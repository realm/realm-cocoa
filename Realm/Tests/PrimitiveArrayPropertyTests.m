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

// XCTest assertions wrap each assertion in a try/catch to provide nice
// reporting if an assertion unexpectedly throws an exception. This is normally
// quite nice, but becomes a problem with the very large number of assertions
// in this file and makes this file take several minutes to compile in release
// builds. Replacing these with assertions which do not try/catch cuts this by
// about 75%.
#define uncheckedAssertEqual(ex1, ex2) do { \
    __typeof__(ex1) value1 = (ex1); \
    __typeof__(ex2) value2 = (ex2); \
    if (value1 != value2) { \
        NSValue *box1 = [NSValue value:&value1 withObjCType:@encode(__typeof__(ex1))]; \
        NSValue *box2 = [NSValue value:&value2 withObjCType:@encode(__typeof__(ex2))]; \
        _XCTRegisterFailure(nil, _XCTFailureDescription(_XCTAssertion_Equal, 0, @#ex1, @#ex2, _XCTDescriptionForValue(box1), _XCTDescriptionForValue(box2))); \
    } \
} while (0)

#define uncheckedAssertEqualObjects(ex1, ex2) do { \
    id value1 = (ex1); \
    id value2 = (ex2); \
    if (value1 != value2 && ![(id)value1 isEqual:value2]) { \
        _XCTRegisterFailure(nil, _XCTFailureDescription(_XCTAssertion_EqualObjects, 0, @#ex1, @#ex2, value1, value2)); \
    } \
} while (0)

#define uncheckedAssertTrue(ex) uncheckedAssertEqual(ex, true)
#define uncheckedAssertFalse(ex) uncheckedAssertEqual(ex, false)
#define uncheckedAssertNil(ex) uncheckedAssertEqual(ex, nil)

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
        unmanaged.boolObj,
        unmanaged.intObj,
        unmanaged.floatObj,
        unmanaged.doubleObj,
        unmanaged.stringObj,
        unmanaged.dataObj,
        unmanaged.dateObj,
        unmanaged.decimalObj,
        unmanaged.objectIdObj,
        unmanaged.uuidObj,
        unmanaged.anyBoolObj,
        unmanaged.anyIntObj,
        unmanaged.anyFloatObj,
        unmanaged.anyDoubleObj,
        unmanaged.anyStringObj,
        unmanaged.anyDataObj,
        unmanaged.anyDateObj,
        unmanaged.anyDecimalObj,
        unmanaged.anyObjectIdObj,
        unmanaged.anyUUIDObj,
        optUnmanaged.boolObj,
        optUnmanaged.intObj,
        optUnmanaged.floatObj,
        optUnmanaged.doubleObj,
        optUnmanaged.stringObj,
        optUnmanaged.dataObj,
        optUnmanaged.dateObj,
        optUnmanaged.decimalObj,
        optUnmanaged.objectIdObj,
        optUnmanaged.uuidObj,
        managed.boolObj,
        managed.intObj,
        managed.floatObj,
        managed.doubleObj,
        managed.stringObj,
        managed.dataObj,
        managed.dateObj,
        managed.decimalObj,
        managed.objectIdObj,
        managed.uuidObj,
        managed.anyBoolObj,
        managed.anyIntObj,
        managed.anyFloatObj,
        managed.anyDoubleObj,
        managed.anyStringObj,
        managed.anyDataObj,
        managed.anyDateObj,
        managed.anyDecimalObj,
        managed.anyObjectIdObj,
        managed.anyUUIDObj,
        optManaged.boolObj,
        optManaged.intObj,
        optManaged.floatObj,
        optManaged.doubleObj,
        optManaged.stringObj,
        optManaged.dataObj,
        optManaged.dateObj,
        optManaged.decimalObj,
        optManaged.objectIdObj,
        optManaged.uuidObj,
    ];
}

- (void)tearDown {
    if (realm.inWriteTransaction) {
        [realm cancelWriteTransaction];
    }
}

- (void)addObjects {
    [unmanaged.boolObj addObjects:@[@NO, @YES]];
    [unmanaged.intObj addObjects:@[@2, @3]];
    [unmanaged.floatObj addObjects:@[@2.2f, @3.3f]];
    [unmanaged.doubleObj addObjects:@[@2.2, @3.3]];
    [unmanaged.stringObj addObjects:@[@"a", @"b"]];
    [unmanaged.dataObj addObjects:@[data(1), data(2)]];
    [unmanaged.dateObj addObjects:@[date(1), date(2)]];
    [unmanaged.decimalObj addObjects:@[decimal128(2), decimal128(3)]];
    [unmanaged.objectIdObj addObjects:@[objectId(1), objectId(2)]];
    [unmanaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [unmanaged.anyBoolObj addObjects:@[@NO, @YES]];
    [unmanaged.anyIntObj addObjects:@[@2, @3]];
    [unmanaged.anyFloatObj addObjects:@[@2.2f, @3.3f]];
    [unmanaged.anyDoubleObj addObjects:@[@2.2, @3.3]];
    [unmanaged.anyStringObj addObjects:@[@"a", @"b"]];
    [unmanaged.anyDataObj addObjects:@[data(1), data(2)]];
    [unmanaged.anyDateObj addObjects:@[date(1), date(2)]];
    [unmanaged.anyDecimalObj addObjects:@[decimal128(2), decimal128(3)]];
    [unmanaged.anyObjectIdObj addObjects:@[objectId(1), objectId(2)]];
    [unmanaged.anyUUIDObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optUnmanaged.boolObj addObjects:@[@NO, @YES, NSNull.null]];
    [optUnmanaged.intObj addObjects:@[@2, @3, NSNull.null]];
    [optUnmanaged.floatObj addObjects:@[@2.2f, @3.3f, NSNull.null]];
    [optUnmanaged.doubleObj addObjects:@[@2.2, @3.3, NSNull.null]];
    [optUnmanaged.stringObj addObjects:@[@"a", @"b", NSNull.null]];
    [optUnmanaged.dataObj addObjects:@[data(1), data(2), NSNull.null]];
    [optUnmanaged.dateObj addObjects:@[date(1), date(2), NSNull.null]];
    [optUnmanaged.decimalObj addObjects:@[decimal128(2), decimal128(3), NSNull.null]];
    [optUnmanaged.objectIdObj addObjects:@[objectId(1), objectId(2), NSNull.null]];
    [optUnmanaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]];
    [managed.boolObj addObjects:@[@NO, @YES]];
    [managed.intObj addObjects:@[@2, @3]];
    [managed.floatObj addObjects:@[@2.2f, @3.3f]];
    [managed.doubleObj addObjects:@[@2.2, @3.3]];
    [managed.stringObj addObjects:@[@"a", @"b"]];
    [managed.dataObj addObjects:@[data(1), data(2)]];
    [managed.dateObj addObjects:@[date(1), date(2)]];
    [managed.decimalObj addObjects:@[decimal128(2), decimal128(3)]];
    [managed.objectIdObj addObjects:@[objectId(1), objectId(2)]];
    [managed.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [managed.anyBoolObj addObjects:@[@NO, @YES]];
    [managed.anyIntObj addObjects:@[@2, @3]];
    [managed.anyFloatObj addObjects:@[@2.2f, @3.3f]];
    [managed.anyDoubleObj addObjects:@[@2.2, @3.3]];
    [managed.anyStringObj addObjects:@[@"a", @"b"]];
    [managed.anyDataObj addObjects:@[data(1), data(2)]];
    [managed.anyDateObj addObjects:@[date(1), date(2)]];
    [managed.anyDecimalObj addObjects:@[decimal128(2), decimal128(3)]];
    [managed.anyObjectIdObj addObjects:@[objectId(1), objectId(2)]];
    [managed.anyUUIDObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optManaged.boolObj addObjects:@[@NO, @YES, NSNull.null]];
    [optManaged.intObj addObjects:@[@2, @3, NSNull.null]];
    [optManaged.floatObj addObjects:@[@2.2f, @3.3f, NSNull.null]];
    [optManaged.doubleObj addObjects:@[@2.2, @3.3, NSNull.null]];
    [optManaged.stringObj addObjects:@[@"a", @"b", NSNull.null]];
    [optManaged.dataObj addObjects:@[data(1), data(2), NSNull.null]];
    [optManaged.dateObj addObjects:@[date(1), date(2), NSNull.null]];
    [optManaged.decimalObj addObjects:@[decimal128(2), decimal128(3), NSNull.null]];
    [optManaged.objectIdObj addObjects:@[objectId(1), objectId(2), NSNull.null]];
    [optManaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]];
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
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([realm deleteObjects:array], @"Cannot delete objects from RLMArray");
    }
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
    for (RLMArray *array in allArrays) {
        uncheckedAssertNil(array.firstObject);
    }

    [self addObjects];
    uncheckedAssertEqualObjects(unmanaged.boolObj.firstObject, @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj.firstObject, @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj.firstObject, @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj.firstObject, @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj.firstObject, @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj.firstObject, data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj.firstObject, date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj.firstObject, decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj.firstObject, objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj.firstObject, uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj.firstObject, @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj.firstObject, @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj.firstObject, @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj.firstObject, @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj.firstObject, @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj.firstObject, data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj.firstObject, date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj.firstObject, decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj.firstObject, objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj.firstObject, uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj.firstObject, @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj.firstObject, @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj.firstObject, @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj.firstObject, @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj.firstObject, @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj.firstObject, data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj.firstObject, date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj.firstObject, decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj.firstObject, objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj.firstObject, uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj.firstObject, @NO);
    uncheckedAssertEqualObjects(managed.intObj.firstObject, @2);
    uncheckedAssertEqualObjects(managed.floatObj.firstObject, @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj.firstObject, @2.2);
    uncheckedAssertEqualObjects(managed.stringObj.firstObject, @"a");
    uncheckedAssertEqualObjects(managed.dataObj.firstObject, data(1));
    uncheckedAssertEqualObjects(managed.dateObj.firstObject, date(1));
    uncheckedAssertEqualObjects(managed.decimalObj.firstObject, decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj.firstObject, objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj.firstObject, uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj.firstObject, @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj.firstObject, @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj.firstObject, @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj.firstObject, @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj.firstObject, @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj.firstObject, data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj.firstObject, date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj.firstObject, decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj.firstObject, objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj.firstObject, uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj.firstObject, @NO);
    uncheckedAssertEqualObjects(optManaged.intObj.firstObject, @2);
    uncheckedAssertEqualObjects(optManaged.floatObj.firstObject, @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj.firstObject, @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj.firstObject, @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj.firstObject, data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj.firstObject, date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj.firstObject, decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj.firstObject, objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj.firstObject, uuid(@"00000000-0000-0000-0000-000000000000"));

    for (RLMArray *array in allArrays) {
        [array removeAllObjects];
    }

    [optUnmanaged.boolObj addObject:NSNull.null];
    [optUnmanaged.intObj addObject:NSNull.null];
    [optUnmanaged.floatObj addObject:NSNull.null];
    [optUnmanaged.doubleObj addObject:NSNull.null];
    [optUnmanaged.stringObj addObject:NSNull.null];
    [optUnmanaged.dataObj addObject:NSNull.null];
    [optUnmanaged.dateObj addObject:NSNull.null];
    [optUnmanaged.decimalObj addObject:NSNull.null];
    [optUnmanaged.objectIdObj addObject:NSNull.null];
    [optUnmanaged.uuidObj addObject:NSNull.null];
    [optManaged.boolObj addObject:NSNull.null];
    [optManaged.intObj addObject:NSNull.null];
    [optManaged.floatObj addObject:NSNull.null];
    [optManaged.doubleObj addObject:NSNull.null];
    [optManaged.stringObj addObject:NSNull.null];
    [optManaged.dataObj addObject:NSNull.null];
    [optManaged.dateObj addObject:NSNull.null];
    [optManaged.decimalObj addObject:NSNull.null];
    [optManaged.objectIdObj addObject:NSNull.null];
    [optManaged.uuidObj addObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.boolObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj.firstObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj.firstObject, NSNull.null);
}

- (void)testLastObject {
    for (RLMArray *array in allArrays) {
        uncheckedAssertNil(array.lastObject);
    }

    [self addObjects];

    uncheckedAssertEqualObjects(unmanaged.boolObj.lastObject, @YES);
    uncheckedAssertEqualObjects(unmanaged.intObj.lastObject, @3);
    uncheckedAssertEqualObjects(unmanaged.floatObj.lastObject, @3.3f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj.lastObject, @3.3);
    uncheckedAssertEqualObjects(unmanaged.stringObj.lastObject, @"b");
    uncheckedAssertEqualObjects(unmanaged.dataObj.lastObject, data(2));
    uncheckedAssertEqualObjects(unmanaged.dateObj.lastObject, date(2));
    uncheckedAssertEqualObjects(unmanaged.decimalObj.lastObject, decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj.lastObject, objectId(2));
    uncheckedAssertEqualObjects(unmanaged.uuidObj.lastObject, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj.lastObject, @YES);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj.lastObject, @3);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj.lastObject, @3.3f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj.lastObject, @3.3);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj.lastObject, @"b");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj.lastObject, data(2));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj.lastObject, date(2));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj.lastObject, decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj.lastObject, objectId(2));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj.lastObject, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(managed.boolObj.lastObject, @YES);
    uncheckedAssertEqualObjects(managed.intObj.lastObject, @3);
    uncheckedAssertEqualObjects(managed.floatObj.lastObject, @3.3f);
    uncheckedAssertEqualObjects(managed.doubleObj.lastObject, @3.3);
    uncheckedAssertEqualObjects(managed.stringObj.lastObject, @"b");
    uncheckedAssertEqualObjects(managed.dataObj.lastObject, data(2));
    uncheckedAssertEqualObjects(managed.dateObj.lastObject, date(2));
    uncheckedAssertEqualObjects(managed.decimalObj.lastObject, decimal128(3));
    uncheckedAssertEqualObjects(managed.objectIdObj.lastObject, objectId(2));
    uncheckedAssertEqualObjects(managed.uuidObj.lastObject, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.anyBoolObj.lastObject, @YES);
    uncheckedAssertEqualObjects(managed.anyIntObj.lastObject, @3);
    uncheckedAssertEqualObjects(managed.anyFloatObj.lastObject, @3.3f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj.lastObject, @3.3);
    uncheckedAssertEqualObjects(managed.anyStringObj.lastObject, @"b");
    uncheckedAssertEqualObjects(managed.anyDataObj.lastObject, data(2));
    uncheckedAssertEqualObjects(managed.anyDateObj.lastObject, date(2));
    uncheckedAssertEqualObjects(managed.anyDecimalObj.lastObject, decimal128(3));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj.lastObject, objectId(2));
    uncheckedAssertEqualObjects(managed.anyUUIDObj.lastObject, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj.lastObject, NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj.lastObject, NSNull.null);

    for (RLMArray *array in allArrays) {
        [array removeLastObject];
    }
    uncheckedAssertEqualObjects(optUnmanaged.boolObj.lastObject, @YES);
    uncheckedAssertEqualObjects(optUnmanaged.intObj.lastObject, @3);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj.lastObject, @3.3f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj.lastObject, @3.3);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj.lastObject, @"b");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj.lastObject, data(2));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj.lastObject, date(2));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj.lastObject, decimal128(3));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj.lastObject, objectId(2));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj.lastObject, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj.lastObject, @YES);
    uncheckedAssertEqualObjects(optManaged.intObj.lastObject, @3);
    uncheckedAssertEqualObjects(optManaged.floatObj.lastObject, @3.3f);
    uncheckedAssertEqualObjects(optManaged.doubleObj.lastObject, @3.3);
    uncheckedAssertEqualObjects(optManaged.stringObj.lastObject, @"b");
    uncheckedAssertEqualObjects(optManaged.dataObj.lastObject, data(2));
    uncheckedAssertEqualObjects(optManaged.dateObj.lastObject, date(2));
    uncheckedAssertEqualObjects(optManaged.decimalObj.lastObject, decimal128(3));
    uncheckedAssertEqualObjects(optManaged.objectIdObj.lastObject, objectId(2));
    uncheckedAssertEqualObjects(optManaged.uuidObj.lastObject, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
}

- (void)testAddObject {
    RLMAssertThrowsWithReason([unmanaged.boolObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj addObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optUnmanaged.intObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj addObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([managed.boolObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj addObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optManaged.boolObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optManaged.intObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optManaged.floatObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optManaged.doubleObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optManaged.stringObj addObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optManaged.dataObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optManaged.dateObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optManaged.decimalObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optManaged.uuidObj addObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([unmanaged.boolObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([managed.boolObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj addObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");

    [unmanaged.boolObj addObject:@NO];
    [unmanaged.intObj addObject:@2];
    [unmanaged.floatObj addObject:@2.2f];
    [unmanaged.doubleObj addObject:@2.2];
    [unmanaged.stringObj addObject:@"a"];
    [unmanaged.dataObj addObject:data(1)];
    [unmanaged.dateObj addObject:date(1)];
    [unmanaged.decimalObj addObject:decimal128(2)];
    [unmanaged.objectIdObj addObject:objectId(1)];
    [unmanaged.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [unmanaged.anyBoolObj addObject:@NO];
    [unmanaged.anyIntObj addObject:@2];
    [unmanaged.anyFloatObj addObject:@2.2f];
    [unmanaged.anyDoubleObj addObject:@2.2];
    [unmanaged.anyStringObj addObject:@"a"];
    [unmanaged.anyDataObj addObject:data(1)];
    [unmanaged.anyDateObj addObject:date(1)];
    [unmanaged.anyDecimalObj addObject:decimal128(2)];
    [unmanaged.anyObjectIdObj addObject:objectId(1)];
    [unmanaged.anyUUIDObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [optUnmanaged.boolObj addObject:@NO];
    [optUnmanaged.intObj addObject:@2];
    [optUnmanaged.floatObj addObject:@2.2f];
    [optUnmanaged.doubleObj addObject:@2.2];
    [optUnmanaged.stringObj addObject:@"a"];
    [optUnmanaged.dataObj addObject:data(1)];
    [optUnmanaged.dateObj addObject:date(1)];
    [optUnmanaged.decimalObj addObject:decimal128(2)];
    [optUnmanaged.objectIdObj addObject:objectId(1)];
    [optUnmanaged.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [managed.boolObj addObject:@NO];
    [managed.intObj addObject:@2];
    [managed.floatObj addObject:@2.2f];
    [managed.doubleObj addObject:@2.2];
    [managed.stringObj addObject:@"a"];
    [managed.dataObj addObject:data(1)];
    [managed.dateObj addObject:date(1)];
    [managed.decimalObj addObject:decimal128(2)];
    [managed.objectIdObj addObject:objectId(1)];
    [managed.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [managed.anyBoolObj addObject:@NO];
    [managed.anyIntObj addObject:@2];
    [managed.anyFloatObj addObject:@2.2f];
    [managed.anyDoubleObj addObject:@2.2];
    [managed.anyStringObj addObject:@"a"];
    [managed.anyDataObj addObject:data(1)];
    [managed.anyDateObj addObject:date(1)];
    [managed.anyDecimalObj addObject:decimal128(2)];
    [managed.anyObjectIdObj addObject:objectId(1)];
    [managed.anyUUIDObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [optManaged.boolObj addObject:@NO];
    [optManaged.intObj addObject:@2];
    [optManaged.floatObj addObject:@2.2f];
    [optManaged.doubleObj addObject:@2.2];
    [optManaged.stringObj addObject:@"a"];
    [optManaged.dataObj addObject:data(1)];
    [optManaged.dateObj addObject:date(1)];
    [optManaged.decimalObj addObject:decimal128(2)];
    [optManaged.objectIdObj addObject:objectId(1)];
    [optManaged.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.intObj[0], @2);
    uncheckedAssertEqualObjects(managed.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));

    [optUnmanaged.boolObj addObject:NSNull.null];
    [optUnmanaged.intObj addObject:NSNull.null];
    [optUnmanaged.floatObj addObject:NSNull.null];
    [optUnmanaged.doubleObj addObject:NSNull.null];
    [optUnmanaged.stringObj addObject:NSNull.null];
    [optUnmanaged.dataObj addObject:NSNull.null];
    [optUnmanaged.dateObj addObject:NSNull.null];
    [optUnmanaged.decimalObj addObject:NSNull.null];
    [optUnmanaged.objectIdObj addObject:NSNull.null];
    [optUnmanaged.uuidObj addObject:NSNull.null];
    [optManaged.boolObj addObject:NSNull.null];
    [optManaged.intObj addObject:NSNull.null];
    [optManaged.floatObj addObject:NSNull.null];
    [optManaged.doubleObj addObject:NSNull.null];
    [optManaged.stringObj addObject:NSNull.null];
    [optManaged.dataObj addObject:NSNull.null];
    [optManaged.dateObj addObject:NSNull.null];
    [optManaged.decimalObj addObject:NSNull.null];
    [optManaged.objectIdObj addObject:NSNull.null];
    [optManaged.uuidObj addObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.boolObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], NSNull.null);
}

- (void)testAddObjects {
    RLMAssertThrowsWithReason([unmanaged.boolObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj addObjects:@[@2]],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optUnmanaged.intObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj addObjects:@[@2]],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([managed.boolObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj addObjects:@[@2]],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optManaged.boolObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optManaged.intObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optManaged.floatObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optManaged.doubleObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optManaged.stringObj addObjects:@[@2]],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optManaged.dataObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optManaged.dateObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optManaged.decimalObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optManaged.uuidObj addObjects:@[@"a"]],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([unmanaged.boolObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([managed.boolObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj addObjects:@[NSNull.null]],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");

    [self addObjects];
    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.intObj[0], @2);
    uncheckedAssertEqualObjects(managed.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.boolObj[1], @YES);
    uncheckedAssertEqualObjects(unmanaged.intObj[1], @3);
    uncheckedAssertEqualObjects(unmanaged.floatObj[1], @3.3f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[1], @3.3);
    uncheckedAssertEqualObjects(unmanaged.stringObj[1], @"b");
    uncheckedAssertEqualObjects(unmanaged.dataObj[1], data(2));
    uncheckedAssertEqualObjects(unmanaged.dateObj[1], date(2));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[1], @YES);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[1], @3);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[1], @3.3f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[1], @3.3);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[1], @"b");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[1], data(2));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[1], date(2));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], @YES);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], @3);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], @3.3f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], @3.3);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], @"b");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], data(2));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], date(2));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.boolObj[1], @YES);
    uncheckedAssertEqualObjects(managed.intObj[1], @3);
    uncheckedAssertEqualObjects(managed.floatObj[1], @3.3f);
    uncheckedAssertEqualObjects(managed.doubleObj[1], @3.3);
    uncheckedAssertEqualObjects(managed.stringObj[1], @"b");
    uncheckedAssertEqualObjects(managed.dataObj[1], data(2));
    uncheckedAssertEqualObjects(managed.dateObj[1], date(2));
    uncheckedAssertEqualObjects(managed.decimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(managed.objectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(managed.uuidObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[1], @YES);
    uncheckedAssertEqualObjects(managed.anyIntObj[1], @3);
    uncheckedAssertEqualObjects(managed.anyFloatObj[1], @3.3f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[1], @3.3);
    uncheckedAssertEqualObjects(managed.anyStringObj[1], @"b");
    uncheckedAssertEqualObjects(managed.anyDataObj[1], data(2));
    uncheckedAssertEqualObjects(managed.anyDateObj[1], date(2));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj[1], @YES);
    uncheckedAssertEqualObjects(optManaged.intObj[1], @3);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], @3.3f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], @3.3);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], @"b");
    uncheckedAssertEqualObjects(optManaged.dataObj[1], data(2));
    uncheckedAssertEqualObjects(optManaged.dateObj[1], date(2));
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.boolObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj[2], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj[2], NSNull.null);
}

- (void)testInsertObject {
    RLMAssertThrowsWithReason([unmanaged.boolObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj insertObject:@2 atIndex:0],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optUnmanaged.intObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj insertObject:@2 atIndex:0],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([managed.boolObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj insertObject:@2 atIndex:0],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optManaged.boolObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optManaged.intObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optManaged.floatObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optManaged.doubleObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optManaged.stringObj insertObject:@2 atIndex:0],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optManaged.dataObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optManaged.dateObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optManaged.decimalObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optManaged.uuidObj insertObject:@"a" atIndex:0],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([unmanaged.boolObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([managed.boolObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj insertObject:NSNull.null atIndex:0],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([unmanaged.boolObj insertObject:@NO atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.intObj insertObject:@2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.floatObj insertObject:@2.2f atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.doubleObj insertObject:@2.2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.stringObj insertObject:@"a" atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.dataObj insertObject:data(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.dateObj insertObject:date(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.decimalObj insertObject:decimal128(2) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj insertObject:objectId(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj insertObject:@NO atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj insertObject:@2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj insertObject:@2.2f atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj insertObject:@2.2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj insertObject:@"a" atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj insertObject:data(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj insertObject:date(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj insertObject:decimal128(2) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj insertObject:objectId(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj insertObject:@NO atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.intObj insertObject:@2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj insertObject:@2.2f atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj insertObject:@2.2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj insertObject:@"a" atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj insertObject:data(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj insertObject:date(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj insertObject:decimal128(2) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj insertObject:objectId(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.boolObj insertObject:@NO atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.intObj insertObject:@2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.floatObj insertObject:@2.2f atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.doubleObj insertObject:@2.2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.stringObj insertObject:@"a" atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.dataObj insertObject:data(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.dateObj insertObject:date(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.decimalObj insertObject:decimal128(2) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.objectIdObj insertObject:objectId(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyBoolObj insertObject:@NO atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyIntObj insertObject:@2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyFloatObj insertObject:@2.2f atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyDoubleObj insertObject:@2.2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyStringObj insertObject:@"a" atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyDataObj insertObject:data(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyDateObj insertObject:date(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyDecimalObj insertObject:decimal128(2) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj insertObject:objectId(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([managed.anyUUIDObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.boolObj insertObject:@NO atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.intObj insertObject:@2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.floatObj insertObject:@2.2f atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.doubleObj insertObject:@2.2 atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.stringObj insertObject:@"a" atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.dataObj insertObject:data(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.dateObj insertObject:date(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.decimalObj insertObject:decimal128(2) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.objectIdObj insertObject:objectId(1) atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");
    RLMAssertThrowsWithReason([optManaged.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:1],
                              @"Index 1 is out of bounds (must be less than 1).");

    [unmanaged.boolObj insertObject:@NO atIndex:0];
    [unmanaged.intObj insertObject:@2 atIndex:0];
    [unmanaged.floatObj insertObject:@2.2f atIndex:0];
    [unmanaged.doubleObj insertObject:@2.2 atIndex:0];
    [unmanaged.stringObj insertObject:@"a" atIndex:0];
    [unmanaged.dataObj insertObject:data(1) atIndex:0];
    [unmanaged.dateObj insertObject:date(1) atIndex:0];
    [unmanaged.decimalObj insertObject:decimal128(2) atIndex:0];
    [unmanaged.objectIdObj insertObject:objectId(1) atIndex:0];
    [unmanaged.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:0];
    [unmanaged.anyBoolObj insertObject:@NO atIndex:0];
    [unmanaged.anyIntObj insertObject:@2 atIndex:0];
    [unmanaged.anyFloatObj insertObject:@2.2f atIndex:0];
    [unmanaged.anyDoubleObj insertObject:@2.2 atIndex:0];
    [unmanaged.anyStringObj insertObject:@"a" atIndex:0];
    [unmanaged.anyDataObj insertObject:data(1) atIndex:0];
    [unmanaged.anyDateObj insertObject:date(1) atIndex:0];
    [unmanaged.anyDecimalObj insertObject:decimal128(2) atIndex:0];
    [unmanaged.anyObjectIdObj insertObject:objectId(1) atIndex:0];
    [unmanaged.anyUUIDObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:0];
    [optUnmanaged.boolObj insertObject:@NO atIndex:0];
    [optUnmanaged.intObj insertObject:@2 atIndex:0];
    [optUnmanaged.floatObj insertObject:@2.2f atIndex:0];
    [optUnmanaged.doubleObj insertObject:@2.2 atIndex:0];
    [optUnmanaged.stringObj insertObject:@"a" atIndex:0];
    [optUnmanaged.dataObj insertObject:data(1) atIndex:0];
    [optUnmanaged.dateObj insertObject:date(1) atIndex:0];
    [optUnmanaged.decimalObj insertObject:decimal128(2) atIndex:0];
    [optUnmanaged.objectIdObj insertObject:objectId(1) atIndex:0];
    [optUnmanaged.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:0];
    [managed.boolObj insertObject:@NO atIndex:0];
    [managed.intObj insertObject:@2 atIndex:0];
    [managed.floatObj insertObject:@2.2f atIndex:0];
    [managed.doubleObj insertObject:@2.2 atIndex:0];
    [managed.stringObj insertObject:@"a" atIndex:0];
    [managed.dataObj insertObject:data(1) atIndex:0];
    [managed.dateObj insertObject:date(1) atIndex:0];
    [managed.decimalObj insertObject:decimal128(2) atIndex:0];
    [managed.objectIdObj insertObject:objectId(1) atIndex:0];
    [managed.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:0];
    [managed.anyBoolObj insertObject:@NO atIndex:0];
    [managed.anyIntObj insertObject:@2 atIndex:0];
    [managed.anyFloatObj insertObject:@2.2f atIndex:0];
    [managed.anyDoubleObj insertObject:@2.2 atIndex:0];
    [managed.anyStringObj insertObject:@"a" atIndex:0];
    [managed.anyDataObj insertObject:data(1) atIndex:0];
    [managed.anyDateObj insertObject:date(1) atIndex:0];
    [managed.anyDecimalObj insertObject:decimal128(2) atIndex:0];
    [managed.anyObjectIdObj insertObject:objectId(1) atIndex:0];
    [managed.anyUUIDObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:0];
    [optManaged.boolObj insertObject:@NO atIndex:0];
    [optManaged.intObj insertObject:@2 atIndex:0];
    [optManaged.floatObj insertObject:@2.2f atIndex:0];
    [optManaged.doubleObj insertObject:@2.2 atIndex:0];
    [optManaged.stringObj insertObject:@"a" atIndex:0];
    [optManaged.dataObj insertObject:data(1) atIndex:0];
    [optManaged.dateObj insertObject:date(1) atIndex:0];
    [optManaged.decimalObj insertObject:decimal128(2) atIndex:0];
    [optManaged.objectIdObj insertObject:objectId(1) atIndex:0];
    [optManaged.uuidObj insertObject:uuid(@"00000000-0000-0000-0000-000000000000") atIndex:0];
    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.intObj[0], @2);
    uncheckedAssertEqualObjects(managed.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));

    [unmanaged.boolObj insertObject:@YES atIndex:0];
    [unmanaged.intObj insertObject:@3 atIndex:0];
    [unmanaged.floatObj insertObject:@3.3f atIndex:0];
    [unmanaged.doubleObj insertObject:@3.3 atIndex:0];
    [unmanaged.stringObj insertObject:@"b" atIndex:0];
    [unmanaged.dataObj insertObject:data(2) atIndex:0];
    [unmanaged.dateObj insertObject:date(2) atIndex:0];
    [unmanaged.decimalObj insertObject:decimal128(3) atIndex:0];
    [unmanaged.objectIdObj insertObject:objectId(2) atIndex:0];
    [unmanaged.uuidObj insertObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89") atIndex:0];
    [unmanaged.anyBoolObj insertObject:@YES atIndex:0];
    [unmanaged.anyIntObj insertObject:@3 atIndex:0];
    [unmanaged.anyFloatObj insertObject:@3.3f atIndex:0];
    [unmanaged.anyDoubleObj insertObject:@3.3 atIndex:0];
    [unmanaged.anyStringObj insertObject:@"b" atIndex:0];
    [unmanaged.anyDataObj insertObject:data(2) atIndex:0];
    [unmanaged.anyDateObj insertObject:date(2) atIndex:0];
    [unmanaged.anyDecimalObj insertObject:decimal128(3) atIndex:0];
    [unmanaged.anyObjectIdObj insertObject:objectId(2) atIndex:0];
    [unmanaged.anyUUIDObj insertObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89") atIndex:0];
    [optUnmanaged.boolObj insertObject:@YES atIndex:0];
    [optUnmanaged.intObj insertObject:@3 atIndex:0];
    [optUnmanaged.floatObj insertObject:@3.3f atIndex:0];
    [optUnmanaged.doubleObj insertObject:@3.3 atIndex:0];
    [optUnmanaged.stringObj insertObject:@"b" atIndex:0];
    [optUnmanaged.dataObj insertObject:data(2) atIndex:0];
    [optUnmanaged.dateObj insertObject:date(2) atIndex:0];
    [optUnmanaged.decimalObj insertObject:decimal128(3) atIndex:0];
    [optUnmanaged.objectIdObj insertObject:objectId(2) atIndex:0];
    [optUnmanaged.uuidObj insertObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89") atIndex:0];
    [managed.boolObj insertObject:@YES atIndex:0];
    [managed.intObj insertObject:@3 atIndex:0];
    [managed.floatObj insertObject:@3.3f atIndex:0];
    [managed.doubleObj insertObject:@3.3 atIndex:0];
    [managed.stringObj insertObject:@"b" atIndex:0];
    [managed.dataObj insertObject:data(2) atIndex:0];
    [managed.dateObj insertObject:date(2) atIndex:0];
    [managed.decimalObj insertObject:decimal128(3) atIndex:0];
    [managed.objectIdObj insertObject:objectId(2) atIndex:0];
    [managed.uuidObj insertObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89") atIndex:0];
    [managed.anyBoolObj insertObject:@YES atIndex:0];
    [managed.anyIntObj insertObject:@3 atIndex:0];
    [managed.anyFloatObj insertObject:@3.3f atIndex:0];
    [managed.anyDoubleObj insertObject:@3.3 atIndex:0];
    [managed.anyStringObj insertObject:@"b" atIndex:0];
    [managed.anyDataObj insertObject:data(2) atIndex:0];
    [managed.anyDateObj insertObject:date(2) atIndex:0];
    [managed.anyDecimalObj insertObject:decimal128(3) atIndex:0];
    [managed.anyObjectIdObj insertObject:objectId(2) atIndex:0];
    [managed.anyUUIDObj insertObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89") atIndex:0];
    [optManaged.boolObj insertObject:@YES atIndex:0];
    [optManaged.intObj insertObject:@3 atIndex:0];
    [optManaged.floatObj insertObject:@3.3f atIndex:0];
    [optManaged.doubleObj insertObject:@3.3 atIndex:0];
    [optManaged.stringObj insertObject:@"b" atIndex:0];
    [optManaged.dataObj insertObject:data(2) atIndex:0];
    [optManaged.dateObj insertObject:date(2) atIndex:0];
    [optManaged.decimalObj insertObject:decimal128(3) atIndex:0];
    [optManaged.objectIdObj insertObject:objectId(2) atIndex:0];
    [optManaged.uuidObj insertObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89") atIndex:0];
    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @3);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @YES);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @3);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @3.3f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @3.3);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"b");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(2));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(2));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @3);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @YES);
    uncheckedAssertEqualObjects(managed.intObj[0], @3);
    uncheckedAssertEqualObjects(managed.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"b");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(2));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(2));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @YES);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @3);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @3.3f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @3.3);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"b");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(2));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(2));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @3);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(unmanaged.boolObj[1], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[1], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[1], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[1], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[1], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[1], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[1], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[1], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[1], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[1], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[1], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[1], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[1], @NO);
    uncheckedAssertEqualObjects(managed.intObj[1], @2);
    uncheckedAssertEqualObjects(managed.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[1], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[1], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[1], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[1], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[1], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[1], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[1], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[1], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[1], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[1], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[1], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[1], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[1], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[1], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));

    [optUnmanaged.boolObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.intObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.floatObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.doubleObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.stringObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.dataObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.dateObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.decimalObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.objectIdObj insertObject:NSNull.null atIndex:1];
    [optUnmanaged.uuidObj insertObject:NSNull.null atIndex:1];
    [optManaged.boolObj insertObject:NSNull.null atIndex:1];
    [optManaged.intObj insertObject:NSNull.null atIndex:1];
    [optManaged.floatObj insertObject:NSNull.null atIndex:1];
    [optManaged.doubleObj insertObject:NSNull.null atIndex:1];
    [optManaged.stringObj insertObject:NSNull.null atIndex:1];
    [optManaged.dataObj insertObject:NSNull.null atIndex:1];
    [optManaged.dateObj insertObject:NSNull.null atIndex:1];
    [optManaged.decimalObj insertObject:NSNull.null atIndex:1];
    [optManaged.objectIdObj insertObject:NSNull.null atIndex:1];
    [optManaged.uuidObj insertObject:NSNull.null atIndex:1];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @3);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @3);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.boolObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[2], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[2], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[2], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[2], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[2], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[2], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[2], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[2], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[2], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[2], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[2], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[2], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[2], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[2], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[2], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[2], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[2], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[2], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[2], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[2], uuid(@"00000000-0000-0000-0000-000000000000"));
}

- (void)testRemoveObject {
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([array removeObjectAtIndex:0],
                                  @"Index 0 is out of bounds (must be less than 0).");
    }

    [self addObjects];
    uncheckedAssertEqual(unmanaged.boolObj.count, 2U);
    uncheckedAssertEqual(unmanaged.intObj.count, 2U);
    uncheckedAssertEqual(unmanaged.floatObj.count, 2U);
    uncheckedAssertEqual(unmanaged.doubleObj.count, 2U);
    uncheckedAssertEqual(unmanaged.stringObj.count, 2U);
    uncheckedAssertEqual(unmanaged.dataObj.count, 2U);
    uncheckedAssertEqual(unmanaged.dateObj.count, 2U);
    uncheckedAssertEqual(unmanaged.decimalObj.count, 2U);
    uncheckedAssertEqual(unmanaged.objectIdObj.count, 2U);
    uncheckedAssertEqual(unmanaged.uuidObj.count, 2U);
    uncheckedAssertEqual(managed.boolObj.count, 2U);
    uncheckedAssertEqual(managed.intObj.count, 2U);
    uncheckedAssertEqual(managed.floatObj.count, 2U);
    uncheckedAssertEqual(managed.doubleObj.count, 2U);
    uncheckedAssertEqual(managed.stringObj.count, 2U);
    uncheckedAssertEqual(managed.dataObj.count, 2U);
    uncheckedAssertEqual(managed.dateObj.count, 2U);
    uncheckedAssertEqual(managed.decimalObj.count, 2U);
    uncheckedAssertEqual(managed.objectIdObj.count, 2U);
    uncheckedAssertEqual(managed.uuidObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.boolObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.intObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.floatObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.doubleObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.stringObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.dataObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.dateObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.decimalObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.objectIdObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.uuidObj.count, 3U);
    uncheckedAssertEqual(optManaged.boolObj.count, 3U);
    uncheckedAssertEqual(optManaged.intObj.count, 3U);
    uncheckedAssertEqual(optManaged.floatObj.count, 3U);
    uncheckedAssertEqual(optManaged.doubleObj.count, 3U);
    uncheckedAssertEqual(optManaged.stringObj.count, 3U);
    uncheckedAssertEqual(optManaged.dataObj.count, 3U);
    uncheckedAssertEqual(optManaged.dateObj.count, 3U);
    uncheckedAssertEqual(optManaged.decimalObj.count, 3U);
    uncheckedAssertEqual(optManaged.objectIdObj.count, 3U);
    uncheckedAssertEqual(optManaged.uuidObj.count, 3U);

    RLMAssertThrowsWithReason([unmanaged.boolObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.intObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.floatObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.doubleObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.stringObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.dataObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.dateObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.decimalObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([unmanaged.uuidObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.boolObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.intObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.floatObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.doubleObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.stringObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.dataObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.dateObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.decimalObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.objectIdObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([managed.uuidObj removeObjectAtIndex:2],
                              @"Index 2 is out of bounds (must be less than 2).");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.intObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.boolObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.intObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.floatObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.doubleObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.stringObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.dataObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.dateObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.decimalObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.objectIdObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");
    RLMAssertThrowsWithReason([optManaged.uuidObj removeObjectAtIndex:3],
                              @"Index 3 is out of bounds (must be less than 3).");

    for (RLMArray *array in allArrays) {
        [array removeObjectAtIndex:0];
    }
    uncheckedAssertEqual(unmanaged.boolObj.count, 1U);
    uncheckedAssertEqual(unmanaged.intObj.count, 1U);
    uncheckedAssertEqual(unmanaged.floatObj.count, 1U);
    uncheckedAssertEqual(unmanaged.doubleObj.count, 1U);
    uncheckedAssertEqual(unmanaged.stringObj.count, 1U);
    uncheckedAssertEqual(unmanaged.dataObj.count, 1U);
    uncheckedAssertEqual(unmanaged.dateObj.count, 1U);
    uncheckedAssertEqual(unmanaged.decimalObj.count, 1U);
    uncheckedAssertEqual(unmanaged.objectIdObj.count, 1U);
    uncheckedAssertEqual(unmanaged.uuidObj.count, 1U);
    uncheckedAssertEqual(managed.boolObj.count, 1U);
    uncheckedAssertEqual(managed.intObj.count, 1U);
    uncheckedAssertEqual(managed.floatObj.count, 1U);
    uncheckedAssertEqual(managed.doubleObj.count, 1U);
    uncheckedAssertEqual(managed.stringObj.count, 1U);
    uncheckedAssertEqual(managed.dataObj.count, 1U);
    uncheckedAssertEqual(managed.dateObj.count, 1U);
    uncheckedAssertEqual(managed.decimalObj.count, 1U);
    uncheckedAssertEqual(managed.objectIdObj.count, 1U);
    uncheckedAssertEqual(managed.uuidObj.count, 1U);
    uncheckedAssertEqual(optUnmanaged.boolObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.intObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.floatObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.doubleObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.stringObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.dataObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.dateObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.decimalObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.objectIdObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.uuidObj.count, 2U);
    uncheckedAssertEqual(optManaged.boolObj.count, 2U);
    uncheckedAssertEqual(optManaged.intObj.count, 2U);
    uncheckedAssertEqual(optManaged.floatObj.count, 2U);
    uncheckedAssertEqual(optManaged.doubleObj.count, 2U);
    uncheckedAssertEqual(optManaged.stringObj.count, 2U);
    uncheckedAssertEqual(optManaged.dataObj.count, 2U);
    uncheckedAssertEqual(optManaged.dateObj.count, 2U);
    uncheckedAssertEqual(optManaged.decimalObj.count, 2U);
    uncheckedAssertEqual(optManaged.objectIdObj.count, 2U);
    uncheckedAssertEqual(optManaged.uuidObj.count, 2U);

    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @3);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @YES);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @3);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @3.3f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @3.3);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"b");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(2));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(2));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @3);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @YES);
    uncheckedAssertEqualObjects(managed.intObj[0], @3);
    uncheckedAssertEqualObjects(managed.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"b");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(2));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(2));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @YES);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @3);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @3.3f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @3.3);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"b");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(2));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(2));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @YES);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @3);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @3.3f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @3.3);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"b");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(2));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(2));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(3));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(2));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.boolObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], NSNull.null);
}

- (void)testRemoveLastObject {
    for (RLMArray *array in allArrays) {
        XCTAssertNoThrow([array removeLastObject]);
    }

    [self addObjects];
    uncheckedAssertEqual(unmanaged.boolObj.count, 2U);
    uncheckedAssertEqual(unmanaged.intObj.count, 2U);
    uncheckedAssertEqual(unmanaged.floatObj.count, 2U);
    uncheckedAssertEqual(unmanaged.doubleObj.count, 2U);
    uncheckedAssertEqual(unmanaged.stringObj.count, 2U);
    uncheckedAssertEqual(unmanaged.dataObj.count, 2U);
    uncheckedAssertEqual(unmanaged.dateObj.count, 2U);
    uncheckedAssertEqual(unmanaged.decimalObj.count, 2U);
    uncheckedAssertEqual(unmanaged.objectIdObj.count, 2U);
    uncheckedAssertEqual(unmanaged.uuidObj.count, 2U);
    uncheckedAssertEqual(managed.boolObj.count, 2U);
    uncheckedAssertEqual(managed.intObj.count, 2U);
    uncheckedAssertEqual(managed.floatObj.count, 2U);
    uncheckedAssertEqual(managed.doubleObj.count, 2U);
    uncheckedAssertEqual(managed.stringObj.count, 2U);
    uncheckedAssertEqual(managed.dataObj.count, 2U);
    uncheckedAssertEqual(managed.dateObj.count, 2U);
    uncheckedAssertEqual(managed.decimalObj.count, 2U);
    uncheckedAssertEqual(managed.objectIdObj.count, 2U);
    uncheckedAssertEqual(managed.uuidObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.boolObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.intObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.floatObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.doubleObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.stringObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.dataObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.dateObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.decimalObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.objectIdObj.count, 3U);
    uncheckedAssertEqual(optUnmanaged.uuidObj.count, 3U);
    uncheckedAssertEqual(optManaged.boolObj.count, 3U);
    uncheckedAssertEqual(optManaged.intObj.count, 3U);
    uncheckedAssertEqual(optManaged.floatObj.count, 3U);
    uncheckedAssertEqual(optManaged.doubleObj.count, 3U);
    uncheckedAssertEqual(optManaged.stringObj.count, 3U);
    uncheckedAssertEqual(optManaged.dataObj.count, 3U);
    uncheckedAssertEqual(optManaged.dateObj.count, 3U);
    uncheckedAssertEqual(optManaged.decimalObj.count, 3U);
    uncheckedAssertEqual(optManaged.objectIdObj.count, 3U);
    uncheckedAssertEqual(optManaged.uuidObj.count, 3U);

    for (RLMArray *array in allArrays) {
        [array removeLastObject];
    }
    uncheckedAssertEqual(unmanaged.boolObj.count, 1U);
    uncheckedAssertEqual(unmanaged.intObj.count, 1U);
    uncheckedAssertEqual(unmanaged.floatObj.count, 1U);
    uncheckedAssertEqual(unmanaged.doubleObj.count, 1U);
    uncheckedAssertEqual(unmanaged.stringObj.count, 1U);
    uncheckedAssertEqual(unmanaged.dataObj.count, 1U);
    uncheckedAssertEqual(unmanaged.dateObj.count, 1U);
    uncheckedAssertEqual(unmanaged.decimalObj.count, 1U);
    uncheckedAssertEqual(unmanaged.objectIdObj.count, 1U);
    uncheckedAssertEqual(unmanaged.uuidObj.count, 1U);
    uncheckedAssertEqual(managed.boolObj.count, 1U);
    uncheckedAssertEqual(managed.intObj.count, 1U);
    uncheckedAssertEqual(managed.floatObj.count, 1U);
    uncheckedAssertEqual(managed.doubleObj.count, 1U);
    uncheckedAssertEqual(managed.stringObj.count, 1U);
    uncheckedAssertEqual(managed.dataObj.count, 1U);
    uncheckedAssertEqual(managed.dateObj.count, 1U);
    uncheckedAssertEqual(managed.decimalObj.count, 1U);
    uncheckedAssertEqual(managed.objectIdObj.count, 1U);
    uncheckedAssertEqual(managed.uuidObj.count, 1U);
    uncheckedAssertEqual(optUnmanaged.boolObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.intObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.floatObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.doubleObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.stringObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.dataObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.dateObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.decimalObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.objectIdObj.count, 2U);
    uncheckedAssertEqual(optUnmanaged.uuidObj.count, 2U);
    uncheckedAssertEqual(optManaged.boolObj.count, 2U);
    uncheckedAssertEqual(optManaged.intObj.count, 2U);
    uncheckedAssertEqual(optManaged.floatObj.count, 2U);
    uncheckedAssertEqual(optManaged.doubleObj.count, 2U);
    uncheckedAssertEqual(optManaged.stringObj.count, 2U);
    uncheckedAssertEqual(optManaged.dataObj.count, 2U);
    uncheckedAssertEqual(optManaged.dateObj.count, 2U);
    uncheckedAssertEqual(optManaged.decimalObj.count, 2U);
    uncheckedAssertEqual(optManaged.objectIdObj.count, 2U);
    uncheckedAssertEqual(optManaged.uuidObj.count, 2U);

    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.intObj[0], @2);
    uncheckedAssertEqualObjects(managed.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], @YES);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], @3);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], @3.3f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], @3.3);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], @"b");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], data(2));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], date(2));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    uncheckedAssertEqualObjects(optManaged.boolObj[1], @YES);
    uncheckedAssertEqualObjects(optManaged.intObj[1], @3);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], @3.3f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], @3.3);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], @"b");
    uncheckedAssertEqualObjects(optManaged.dataObj[1], data(2));
    uncheckedAssertEqualObjects(optManaged.dateObj[1], date(2));
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], decimal128(3));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], objectId(2));
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
}

- (void)testReplace {
    RLMAssertThrowsWithReason([unmanaged.boolObj replaceObjectAtIndex:0 withObject:@NO],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.intObj replaceObjectAtIndex:0 withObject:@2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.floatObj replaceObjectAtIndex:0 withObject:@2.2f],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.doubleObj replaceObjectAtIndex:0 withObject:@2.2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.stringObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.dataObj replaceObjectAtIndex:0 withObject:data(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.dateObj replaceObjectAtIndex:0 withObject:date(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.decimalObj replaceObjectAtIndex:0 withObject:decimal128(2)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj replaceObjectAtIndex:0 withObject:objectId(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"00000000-0000-0000-0000-000000000000")],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj replaceObjectAtIndex:0 withObject:@NO],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj replaceObjectAtIndex:0 withObject:@2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj replaceObjectAtIndex:0 withObject:@2.2f],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj replaceObjectAtIndex:0 withObject:@2.2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj replaceObjectAtIndex:0 withObject:data(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj replaceObjectAtIndex:0 withObject:date(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj replaceObjectAtIndex:0 withObject:decimal128(2)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj replaceObjectAtIndex:0 withObject:objectId(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj replaceObjectAtIndex:0 withObject:uuid(@"00000000-0000-0000-0000-000000000000")],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj replaceObjectAtIndex:0 withObject:@NO],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.intObj replaceObjectAtIndex:0 withObject:@2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj replaceObjectAtIndex:0 withObject:@2.2f],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj replaceObjectAtIndex:0 withObject:@2.2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj replaceObjectAtIndex:0 withObject:data(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj replaceObjectAtIndex:0 withObject:date(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj replaceObjectAtIndex:0 withObject:decimal128(2)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj replaceObjectAtIndex:0 withObject:objectId(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"00000000-0000-0000-0000-000000000000")],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.boolObj replaceObjectAtIndex:0 withObject:@NO],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.intObj replaceObjectAtIndex:0 withObject:@2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.floatObj replaceObjectAtIndex:0 withObject:@2.2f],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.doubleObj replaceObjectAtIndex:0 withObject:@2.2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.stringObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.dataObj replaceObjectAtIndex:0 withObject:data(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.dateObj replaceObjectAtIndex:0 withObject:date(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.decimalObj replaceObjectAtIndex:0 withObject:decimal128(2)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.objectIdObj replaceObjectAtIndex:0 withObject:objectId(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"00000000-0000-0000-0000-000000000000")],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyBoolObj replaceObjectAtIndex:0 withObject:@NO],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyIntObj replaceObjectAtIndex:0 withObject:@2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyFloatObj replaceObjectAtIndex:0 withObject:@2.2f],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyDoubleObj replaceObjectAtIndex:0 withObject:@2.2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyStringObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyDataObj replaceObjectAtIndex:0 withObject:data(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyDateObj replaceObjectAtIndex:0 withObject:date(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyDecimalObj replaceObjectAtIndex:0 withObject:decimal128(2)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj replaceObjectAtIndex:0 withObject:objectId(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([managed.anyUUIDObj replaceObjectAtIndex:0 withObject:uuid(@"00000000-0000-0000-0000-000000000000")],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.boolObj replaceObjectAtIndex:0 withObject:@NO],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.intObj replaceObjectAtIndex:0 withObject:@2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.floatObj replaceObjectAtIndex:0 withObject:@2.2f],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.doubleObj replaceObjectAtIndex:0 withObject:@2.2],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.stringObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.dataObj replaceObjectAtIndex:0 withObject:data(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.dateObj replaceObjectAtIndex:0 withObject:date(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.decimalObj replaceObjectAtIndex:0 withObject:decimal128(2)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.objectIdObj replaceObjectAtIndex:0 withObject:objectId(1)],
                              @"Index 0 is out of bounds (must be less than 0).");
    RLMAssertThrowsWithReason([optManaged.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"00000000-0000-0000-0000-000000000000")],
                              @"Index 0 is out of bounds (must be less than 0).");

    [unmanaged.boolObj addObject:@NO];
    [unmanaged.boolObj replaceObjectAtIndex:0 withObject:@YES];
    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @YES);
    
    [unmanaged.intObj addObject:@2];
    [unmanaged.intObj replaceObjectAtIndex:0 withObject:@3];
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @3);
    
    [unmanaged.floatObj addObject:@2.2f];
    [unmanaged.floatObj replaceObjectAtIndex:0 withObject:@3.3f];
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @3.3f);
    
    [unmanaged.doubleObj addObject:@2.2];
    [unmanaged.doubleObj replaceObjectAtIndex:0 withObject:@3.3];
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @3.3);
    
    [unmanaged.stringObj addObject:@"a"];
    [unmanaged.stringObj replaceObjectAtIndex:0 withObject:@"b"];
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"b");
    
    [unmanaged.dataObj addObject:data(1)];
    [unmanaged.dataObj replaceObjectAtIndex:0 withObject:data(2)];
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(2));
    
    [unmanaged.dateObj addObject:date(1)];
    [unmanaged.dateObj replaceObjectAtIndex:0 withObject:date(2)];
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(2));
    
    [unmanaged.decimalObj addObject:decimal128(2)];
    [unmanaged.decimalObj replaceObjectAtIndex:0 withObject:decimal128(3)];
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(3));
    
    [unmanaged.objectIdObj addObject:objectId(1)];
    [unmanaged.objectIdObj replaceObjectAtIndex:0 withObject:objectId(2)];
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(2));
    
    [unmanaged.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [unmanaged.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    
    [unmanaged.anyBoolObj addObject:@NO];
    [unmanaged.anyBoolObj replaceObjectAtIndex:0 withObject:@YES];
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @YES);
    
    [unmanaged.anyIntObj addObject:@2];
    [unmanaged.anyIntObj replaceObjectAtIndex:0 withObject:@3];
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @3);
    
    [unmanaged.anyFloatObj addObject:@2.2f];
    [unmanaged.anyFloatObj replaceObjectAtIndex:0 withObject:@3.3f];
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @3.3f);
    
    [unmanaged.anyDoubleObj addObject:@2.2];
    [unmanaged.anyDoubleObj replaceObjectAtIndex:0 withObject:@3.3];
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @3.3);
    
    [unmanaged.anyStringObj addObject:@"a"];
    [unmanaged.anyStringObj replaceObjectAtIndex:0 withObject:@"b"];
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"b");
    
    [unmanaged.anyDataObj addObject:data(1)];
    [unmanaged.anyDataObj replaceObjectAtIndex:0 withObject:data(2)];
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(2));
    
    [unmanaged.anyDateObj addObject:date(1)];
    [unmanaged.anyDateObj replaceObjectAtIndex:0 withObject:date(2)];
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(2));
    
    [unmanaged.anyDecimalObj addObject:decimal128(2)];
    [unmanaged.anyDecimalObj replaceObjectAtIndex:0 withObject:decimal128(3)];
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(3));
    
    [unmanaged.anyObjectIdObj addObject:objectId(1)];
    [unmanaged.anyObjectIdObj replaceObjectAtIndex:0 withObject:objectId(2)];
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(2));
    
    [unmanaged.anyUUIDObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [unmanaged.anyUUIDObj replaceObjectAtIndex:0 withObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    
    [optUnmanaged.boolObj addObject:@NO];
    [optUnmanaged.boolObj replaceObjectAtIndex:0 withObject:@YES];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @YES);
    
    [optUnmanaged.intObj addObject:@2];
    [optUnmanaged.intObj replaceObjectAtIndex:0 withObject:@3];
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @3);
    
    [optUnmanaged.floatObj addObject:@2.2f];
    [optUnmanaged.floatObj replaceObjectAtIndex:0 withObject:@3.3f];
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @3.3f);
    
    [optUnmanaged.doubleObj addObject:@2.2];
    [optUnmanaged.doubleObj replaceObjectAtIndex:0 withObject:@3.3];
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @3.3);
    
    [optUnmanaged.stringObj addObject:@"a"];
    [optUnmanaged.stringObj replaceObjectAtIndex:0 withObject:@"b"];
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"b");
    
    [optUnmanaged.dataObj addObject:data(1)];
    [optUnmanaged.dataObj replaceObjectAtIndex:0 withObject:data(2)];
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(2));
    
    [optUnmanaged.dateObj addObject:date(1)];
    [optUnmanaged.dateObj replaceObjectAtIndex:0 withObject:date(2)];
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(2));
    
    [optUnmanaged.decimalObj addObject:decimal128(2)];
    [optUnmanaged.decimalObj replaceObjectAtIndex:0 withObject:decimal128(3)];
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(3));
    
    [optUnmanaged.objectIdObj addObject:objectId(1)];
    [optUnmanaged.objectIdObj replaceObjectAtIndex:0 withObject:objectId(2)];
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(2));
    
    [optUnmanaged.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [optUnmanaged.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    
    [managed.boolObj addObject:@NO];
    [managed.boolObj replaceObjectAtIndex:0 withObject:@YES];
    uncheckedAssertEqualObjects(managed.boolObj[0], @YES);
    
    [managed.intObj addObject:@2];
    [managed.intObj replaceObjectAtIndex:0 withObject:@3];
    uncheckedAssertEqualObjects(managed.intObj[0], @3);
    
    [managed.floatObj addObject:@2.2f];
    [managed.floatObj replaceObjectAtIndex:0 withObject:@3.3f];
    uncheckedAssertEqualObjects(managed.floatObj[0], @3.3f);
    
    [managed.doubleObj addObject:@2.2];
    [managed.doubleObj replaceObjectAtIndex:0 withObject:@3.3];
    uncheckedAssertEqualObjects(managed.doubleObj[0], @3.3);
    
    [managed.stringObj addObject:@"a"];
    [managed.stringObj replaceObjectAtIndex:0 withObject:@"b"];
    uncheckedAssertEqualObjects(managed.stringObj[0], @"b");
    
    [managed.dataObj addObject:data(1)];
    [managed.dataObj replaceObjectAtIndex:0 withObject:data(2)];
    uncheckedAssertEqualObjects(managed.dataObj[0], data(2));
    
    [managed.dateObj addObject:date(1)];
    [managed.dateObj replaceObjectAtIndex:0 withObject:date(2)];
    uncheckedAssertEqualObjects(managed.dateObj[0], date(2));
    
    [managed.decimalObj addObject:decimal128(2)];
    [managed.decimalObj replaceObjectAtIndex:0 withObject:decimal128(3)];
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(3));
    
    [managed.objectIdObj addObject:objectId(1)];
    [managed.objectIdObj replaceObjectAtIndex:0 withObject:objectId(2)];
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(2));
    
    [managed.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [managed.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    
    [managed.anyBoolObj addObject:@NO];
    [managed.anyBoolObj replaceObjectAtIndex:0 withObject:@YES];
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @YES);
    
    [managed.anyIntObj addObject:@2];
    [managed.anyIntObj replaceObjectAtIndex:0 withObject:@3];
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @3);
    
    [managed.anyFloatObj addObject:@2.2f];
    [managed.anyFloatObj replaceObjectAtIndex:0 withObject:@3.3f];
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @3.3f);
    
    [managed.anyDoubleObj addObject:@2.2];
    [managed.anyDoubleObj replaceObjectAtIndex:0 withObject:@3.3];
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @3.3);
    
    [managed.anyStringObj addObject:@"a"];
    [managed.anyStringObj replaceObjectAtIndex:0 withObject:@"b"];
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"b");
    
    [managed.anyDataObj addObject:data(1)];
    [managed.anyDataObj replaceObjectAtIndex:0 withObject:data(2)];
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(2));
    
    [managed.anyDateObj addObject:date(1)];
    [managed.anyDateObj replaceObjectAtIndex:0 withObject:date(2)];
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(2));
    
    [managed.anyDecimalObj addObject:decimal128(2)];
    [managed.anyDecimalObj replaceObjectAtIndex:0 withObject:decimal128(3)];
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(3));
    
    [managed.anyObjectIdObj addObject:objectId(1)];
    [managed.anyObjectIdObj replaceObjectAtIndex:0 withObject:objectId(2)];
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(2));
    
    [managed.anyUUIDObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [managed.anyUUIDObj replaceObjectAtIndex:0 withObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    
    [optManaged.boolObj addObject:@NO];
    [optManaged.boolObj replaceObjectAtIndex:0 withObject:@YES];
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @YES);
    
    [optManaged.intObj addObject:@2];
    [optManaged.intObj replaceObjectAtIndex:0 withObject:@3];
    uncheckedAssertEqualObjects(optManaged.intObj[0], @3);
    
    [optManaged.floatObj addObject:@2.2f];
    [optManaged.floatObj replaceObjectAtIndex:0 withObject:@3.3f];
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @3.3f);
    
    [optManaged.doubleObj addObject:@2.2];
    [optManaged.doubleObj replaceObjectAtIndex:0 withObject:@3.3];
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @3.3);
    
    [optManaged.stringObj addObject:@"a"];
    [optManaged.stringObj replaceObjectAtIndex:0 withObject:@"b"];
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"b");
    
    [optManaged.dataObj addObject:data(1)];
    [optManaged.dataObj replaceObjectAtIndex:0 withObject:data(2)];
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(2));
    
    [optManaged.dateObj addObject:date(1)];
    [optManaged.dateObj replaceObjectAtIndex:0 withObject:date(2)];
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(2));
    
    [optManaged.decimalObj addObject:decimal128(2)];
    [optManaged.decimalObj replaceObjectAtIndex:0 withObject:decimal128(3)];
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(3));
    
    [optManaged.objectIdObj addObject:objectId(1)];
    [optManaged.objectIdObj replaceObjectAtIndex:0 withObject:objectId(2)];
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(2));
    
    [optManaged.uuidObj addObject:uuid(@"00000000-0000-0000-0000-000000000000")];
    [optManaged.uuidObj replaceObjectAtIndex:0 withObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    

    [optUnmanaged.boolObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], NSNull.null);
    [optUnmanaged.intObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], NSNull.null);
    [optUnmanaged.floatObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], NSNull.null);
    [optUnmanaged.doubleObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], NSNull.null);
    [optUnmanaged.stringObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], NSNull.null);
    [optUnmanaged.dataObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], NSNull.null);
    [optUnmanaged.dateObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], NSNull.null);
    [optUnmanaged.decimalObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], NSNull.null);
    [optUnmanaged.objectIdObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], NSNull.null);
    [optUnmanaged.uuidObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], NSNull.null);
    [optManaged.boolObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.boolObj[0], NSNull.null);
    [optManaged.intObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.intObj[0], NSNull.null);
    [optManaged.floatObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.floatObj[0], NSNull.null);
    [optManaged.doubleObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], NSNull.null);
    [optManaged.stringObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.stringObj[0], NSNull.null);
    [optManaged.dataObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.dataObj[0], NSNull.null);
    [optManaged.dateObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.dateObj[0], NSNull.null);
    [optManaged.decimalObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], NSNull.null);
    [optManaged.objectIdObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], NSNull.null);
    [optManaged.uuidObj replaceObjectAtIndex:0 withObject:NSNull.null];
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], NSNull.null);

    RLMAssertThrowsWithReason([unmanaged.boolObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj replaceObjectAtIndex:0 withObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optUnmanaged.intObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj replaceObjectAtIndex:0 withObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([managed.boolObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj replaceObjectAtIndex:0 withObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optManaged.boolObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optManaged.intObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optManaged.floatObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optManaged.doubleObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optManaged.stringObj replaceObjectAtIndex:0 withObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optManaged.dataObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optManaged.dateObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optManaged.decimalObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optManaged.uuidObj replaceObjectAtIndex:0 withObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([unmanaged.boolObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([managed.boolObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj replaceObjectAtIndex:0 withObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
}

- (void)testMove {
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([array moveObjectAtIndex:0 toIndex:1],
                                  @"Index 0 is out of bounds (must be less than 0).");
    }
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([array moveObjectAtIndex:1 toIndex:0],
                                  @"Index 1 is out of bounds (must be less than 0).");
    }

    [unmanaged.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [unmanaged.intObj addObjects:@[@2, @3, @2, @3]];
    [unmanaged.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [unmanaged.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [unmanaged.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [unmanaged.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [unmanaged.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [unmanaged.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [unmanaged.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [unmanaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [unmanaged.anyBoolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [unmanaged.anyIntObj addObjects:@[@2, @3, @2, @3]];
    [unmanaged.anyFloatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [unmanaged.anyDoubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [unmanaged.anyStringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [unmanaged.anyDataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [unmanaged.anyDateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [unmanaged.anyDecimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [unmanaged.anyObjectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [unmanaged.anyUUIDObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optUnmanaged.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [optUnmanaged.intObj addObjects:@[@2, @3, @2, @3]];
    [optUnmanaged.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [optUnmanaged.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [optUnmanaged.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [optUnmanaged.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [optUnmanaged.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [optUnmanaged.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [optUnmanaged.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [optUnmanaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [managed.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [managed.intObj addObjects:@[@2, @3, @2, @3]];
    [managed.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [managed.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [managed.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [managed.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [managed.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [managed.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [managed.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [managed.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [managed.anyBoolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [managed.anyIntObj addObjects:@[@2, @3, @2, @3]];
    [managed.anyFloatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [managed.anyDoubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [managed.anyStringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [managed.anyDataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [managed.anyDateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [managed.anyDecimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [managed.anyObjectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [managed.anyUUIDObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optManaged.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [optManaged.intObj addObjects:@[@2, @3, @2, @3]];
    [optManaged.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [optManaged.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [optManaged.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [optManaged.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [optManaged.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [optManaged.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [optManaged.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [optManaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];

    for (RLMArray *array in allArrays) {
        [array moveObjectAtIndex:2 toIndex:0];
    }

    uncheckedAssertEqualObjects([unmanaged.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([unmanaged.anyBoolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([unmanaged.anyIntObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.anyDataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.anyObjectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyUUIDObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optUnmanaged.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([optUnmanaged.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([optUnmanaged.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([optUnmanaged.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([managed.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([managed.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([managed.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([managed.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([managed.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([managed.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([managed.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([managed.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([managed.anyBoolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([managed.anyDataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.anyObjectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([managed.anyUUIDObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optManaged.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([optManaged.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([optManaged.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([optManaged.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([optManaged.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
}

- (void)testExchange {
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([array exchangeObjectAtIndex:0 withObjectAtIndex:1],
                                  @"Index 0 is out of bounds (must be less than 0).");
    }
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([array exchangeObjectAtIndex:1 withObjectAtIndex:0],
                                  @"Index 1 is out of bounds (must be less than 0).");
    }

    [unmanaged.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [unmanaged.intObj addObjects:@[@2, @3, @2, @3]];
    [unmanaged.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [unmanaged.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [unmanaged.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [unmanaged.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [unmanaged.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [unmanaged.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [unmanaged.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [unmanaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [unmanaged.anyBoolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [unmanaged.anyIntObj addObjects:@[@2, @3, @2, @3]];
    [unmanaged.anyFloatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [unmanaged.anyDoubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [unmanaged.anyStringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [unmanaged.anyDataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [unmanaged.anyDateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [unmanaged.anyDecimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [unmanaged.anyObjectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [unmanaged.anyUUIDObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optUnmanaged.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [optUnmanaged.intObj addObjects:@[@2, @3, @2, @3]];
    [optUnmanaged.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [optUnmanaged.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [optUnmanaged.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [optUnmanaged.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [optUnmanaged.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [optUnmanaged.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [optUnmanaged.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [optUnmanaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [managed.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [managed.intObj addObjects:@[@2, @3, @2, @3]];
    [managed.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [managed.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [managed.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [managed.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [managed.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [managed.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [managed.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [managed.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [managed.anyBoolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [managed.anyIntObj addObjects:@[@2, @3, @2, @3]];
    [managed.anyFloatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [managed.anyDoubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [managed.anyStringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [managed.anyDataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [managed.anyDateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [managed.anyDecimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [managed.anyObjectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [managed.anyUUIDObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optManaged.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [optManaged.intObj addObjects:@[@2, @3, @2, @3]];
    [optManaged.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [optManaged.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [optManaged.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [optManaged.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [optManaged.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [optManaged.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [optManaged.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [optManaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];

    for (RLMArray *array in allArrays) {
        [array exchangeObjectAtIndex:2 withObjectAtIndex:1];
    }

    uncheckedAssertEqualObjects([unmanaged.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([unmanaged.anyBoolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([unmanaged.anyIntObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.anyDataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.anyObjectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyUUIDObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optUnmanaged.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([optUnmanaged.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([optUnmanaged.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([optUnmanaged.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([managed.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([managed.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([managed.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([managed.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([managed.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([managed.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([managed.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([managed.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([managed.anyBoolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([managed.anyDataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.anyObjectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([managed.anyUUIDObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optManaged.boolObj valueForKey:@"self"],
                                (@[@NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([optManaged.intObj valueForKey:@"self"],
                                (@[@2, @2, @3, @3]));
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKey:@"self"],
                                (@[@"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([optManaged.dataObj valueForKey:@"self"],
                                (@[data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKey:@"self"],
                                (@[date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([optManaged.objectIdObj valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([optManaged.uuidObj valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
}

- (void)testIndexOfObject {
    uncheckedAssertEqual(NSNotFound, [unmanaged.boolObj indexOfObject:@NO]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.intObj indexOfObject:@2]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.floatObj indexOfObject:@2.2f]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.doubleObj indexOfObject:@2.2]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.stringObj indexOfObject:@"a"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dataObj indexOfObject:data(1)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dateObj indexOfObject:date(1)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.decimalObj indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.objectIdObj indexOfObject:objectId(1)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.uuidObj indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyBoolObj indexOfObject:@NO]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyIntObj indexOfObject:@2]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyFloatObj indexOfObject:@2.2f]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDoubleObj indexOfObject:@2.2]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyStringObj indexOfObject:@"a"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDataObj indexOfObject:data(1)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDateObj indexOfObject:date(1)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDecimalObj indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyObjectIdObj indexOfObject:objectId(1)]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyUUIDObj indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.boolObj indexOfObject:@NO]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.intObj indexOfObject:@2]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.floatObj indexOfObject:@2.2f]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.doubleObj indexOfObject:@2.2]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.stringObj indexOfObject:@"a"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dataObj indexOfObject:data(1)]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dateObj indexOfObject:date(1)]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.decimalObj indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.objectIdObj indexOfObject:objectId(1)]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.uuidObj indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(NSNotFound, [managed.boolObj indexOfObject:@NO]);
    uncheckedAssertEqual(NSNotFound, [managed.intObj indexOfObject:@2]);
    uncheckedAssertEqual(NSNotFound, [managed.floatObj indexOfObject:@2.2f]);
    uncheckedAssertEqual(NSNotFound, [managed.doubleObj indexOfObject:@2.2]);
    uncheckedAssertEqual(NSNotFound, [managed.stringObj indexOfObject:@"a"]);
    uncheckedAssertEqual(NSNotFound, [managed.dataObj indexOfObject:data(1)]);
    uncheckedAssertEqual(NSNotFound, [managed.dateObj indexOfObject:date(1)]);
    uncheckedAssertEqual(NSNotFound, [managed.decimalObj indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(NSNotFound, [managed.objectIdObj indexOfObject:objectId(1)]);
    uncheckedAssertEqual(NSNotFound, [managed.uuidObj indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(NSNotFound, [managed.anyBoolObj indexOfObject:@NO]);
    uncheckedAssertEqual(NSNotFound, [managed.anyIntObj indexOfObject:@2]);
    uncheckedAssertEqual(NSNotFound, [managed.anyFloatObj indexOfObject:@2.2f]);
    uncheckedAssertEqual(NSNotFound, [managed.anyDoubleObj indexOfObject:@2.2]);
    uncheckedAssertEqual(NSNotFound, [managed.anyStringObj indexOfObject:@"a"]);
    uncheckedAssertEqual(NSNotFound, [managed.anyDataObj indexOfObject:data(1)]);
    uncheckedAssertEqual(NSNotFound, [managed.anyDateObj indexOfObject:date(1)]);
    uncheckedAssertEqual(NSNotFound, [managed.anyDecimalObj indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(NSNotFound, [managed.anyObjectIdObj indexOfObject:objectId(1)]);
    uncheckedAssertEqual(NSNotFound, [managed.anyUUIDObj indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(NSNotFound, [optManaged.boolObj indexOfObject:@NO]);
    uncheckedAssertEqual(NSNotFound, [optManaged.intObj indexOfObject:@2]);
    uncheckedAssertEqual(NSNotFound, [optManaged.floatObj indexOfObject:@2.2f]);
    uncheckedAssertEqual(NSNotFound, [optManaged.doubleObj indexOfObject:@2.2]);
    uncheckedAssertEqual(NSNotFound, [optManaged.stringObj indexOfObject:@"a"]);
    uncheckedAssertEqual(NSNotFound, [optManaged.dataObj indexOfObject:data(1)]);
    uncheckedAssertEqual(NSNotFound, [optManaged.dateObj indexOfObject:date(1)]);
    uncheckedAssertEqual(NSNotFound, [optManaged.decimalObj indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(NSNotFound, [optManaged.objectIdObj indexOfObject:objectId(1)]);
    uncheckedAssertEqual(NSNotFound, [optManaged.uuidObj indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);

    RLMAssertThrowsWithReason([unmanaged.boolObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj indexOfObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optUnmanaged.intObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj indexOfObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([managed.boolObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj indexOfObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optManaged.boolObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optManaged.intObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optManaged.floatObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optManaged.doubleObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optManaged.stringObj indexOfObject:@2],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optManaged.dataObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optManaged.dateObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optManaged.decimalObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optManaged.uuidObj indexOfObject:@"a"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");

    RLMAssertThrowsWithReason([unmanaged.boolObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([managed.boolObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj indexOfObject:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.boolObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.intObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.floatObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.doubleObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.stringObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dataObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dateObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.decimalObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.objectIdObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.uuidObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.boolObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.intObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.floatObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.doubleObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.stringObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.dataObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.dateObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.decimalObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.objectIdObj indexOfObject:NSNull.null]);
    uncheckedAssertEqual(NSNotFound, [optManaged.uuidObj indexOfObject:NSNull.null]);

    [self addObjects];

    uncheckedAssertEqual(1U, [unmanaged.boolObj indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [unmanaged.intObj indexOfObject:@3]);
    uncheckedAssertEqual(1U, [unmanaged.floatObj indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [unmanaged.doubleObj indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [unmanaged.stringObj indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [unmanaged.dataObj indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [unmanaged.dateObj indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [unmanaged.decimalObj indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [unmanaged.objectIdObj indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [unmanaged.uuidObj indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(1U, [unmanaged.anyBoolObj indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [unmanaged.anyIntObj indexOfObject:@3]);
    uncheckedAssertEqual(1U, [unmanaged.anyFloatObj indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [unmanaged.anyDoubleObj indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [unmanaged.anyStringObj indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [unmanaged.anyDataObj indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [unmanaged.anyDateObj indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [unmanaged.anyDecimalObj indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [unmanaged.anyObjectIdObj indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [unmanaged.anyUUIDObj indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(1U, [optUnmanaged.boolObj indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [optUnmanaged.intObj indexOfObject:@3]);
    uncheckedAssertEqual(1U, [optUnmanaged.floatObj indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [optUnmanaged.doubleObj indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [optUnmanaged.stringObj indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [optUnmanaged.dataObj indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [optUnmanaged.dateObj indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [optUnmanaged.decimalObj indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [optUnmanaged.objectIdObj indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [optUnmanaged.uuidObj indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(1U, [managed.boolObj indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [managed.intObj indexOfObject:@3]);
    uncheckedAssertEqual(1U, [managed.floatObj indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [managed.doubleObj indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [managed.stringObj indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [managed.dataObj indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [managed.dateObj indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [managed.decimalObj indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [managed.objectIdObj indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [managed.uuidObj indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(1U, [managed.anyBoolObj indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [managed.anyIntObj indexOfObject:@3]);
    uncheckedAssertEqual(1U, [managed.anyFloatObj indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [managed.anyDoubleObj indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [managed.anyStringObj indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [managed.anyDataObj indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [managed.anyDateObj indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [managed.anyDecimalObj indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [managed.anyObjectIdObj indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [managed.anyUUIDObj indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(1U, [optManaged.boolObj indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [optManaged.intObj indexOfObject:@3]);
    uncheckedAssertEqual(1U, [optManaged.floatObj indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [optManaged.doubleObj indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [optManaged.stringObj indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [optManaged.dataObj indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [optManaged.dateObj indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [optManaged.decimalObj indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [optManaged.objectIdObj indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [optManaged.uuidObj indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
}

- (void)testIndexOfObjectSorted {
    [managed.boolObj addObjects:@[@NO, @YES, @NO, @YES]];
    [managed.intObj addObjects:@[@2, @3, @2, @3]];
    [managed.floatObj addObjects:@[@2.2f, @3.3f, @2.2f, @3.3f]];
    [managed.doubleObj addObjects:@[@2.2, @3.3, @2.2, @3.3]];
    [managed.stringObj addObjects:@[@"a", @"b", @"a", @"b"]];
    [managed.dataObj addObjects:@[data(1), data(2), data(1), data(2)]];
    [managed.dateObj addObjects:@[date(1), date(2), date(1), date(2)]];
    [managed.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]];
    [managed.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1), objectId(2)]];
    [managed.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optManaged.boolObj addObjects:@[@NO, @YES, NSNull.null, @YES, @NO]];
    [optManaged.intObj addObjects:@[@2, @3, NSNull.null, @3, @2]];
    [optManaged.floatObj addObjects:@[@2.2f, @3.3f, NSNull.null, @3.3f, @2.2f]];
    [optManaged.doubleObj addObjects:@[@2.2, @3.3, NSNull.null, @3.3, @2.2]];
    [optManaged.stringObj addObjects:@[@"a", @"b", NSNull.null, @"b", @"a"]];
    [optManaged.dataObj addObjects:@[data(1), data(2), NSNull.null, data(2), data(1)]];
    [optManaged.dateObj addObjects:@[date(1), date(2), NSNull.null, date(2), date(1)]];
    [optManaged.decimalObj addObjects:@[decimal128(2), decimal128(3), NSNull.null, decimal128(3), decimal128(2)]];
    [optManaged.objectIdObj addObjects:@[objectId(1), objectId(2), NSNull.null, objectId(2), objectId(1)]];
    [optManaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000")]];

    uncheckedAssertEqual(0U, [[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@YES]);
    uncheckedAssertEqual(0U, [[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@3]);
    uncheckedAssertEqual(0U, [[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@3.3f]);
    uncheckedAssertEqual(0U, [[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@3.3]);
    uncheckedAssertEqual(0U, [[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@"b"]);
    uncheckedAssertEqual(0U, [[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:data(2)]);
    uncheckedAssertEqual(0U, [[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:date(2)]);
    uncheckedAssertEqual(0U, [[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(0U, [[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:objectId(2)]);
    uncheckedAssertEqual(0U, [[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(2U, [[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@NO]);
    uncheckedAssertEqual(2U, [[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@2]);
    uncheckedAssertEqual(2U, [[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@2.2f]);
    uncheckedAssertEqual(2U, [[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@2.2]);
    uncheckedAssertEqual(2U, [[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@"a"]);
    uncheckedAssertEqual(2U, [[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:data(1)]);
    uncheckedAssertEqual(2U, [[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:date(1)]);
    uncheckedAssertEqual(2U, [[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(2U, [[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:objectId(1)]);
    uncheckedAssertEqual(2U, [[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);

    uncheckedAssertEqual(0U, [[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@YES]);
    uncheckedAssertEqual(0U, [[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@3]);
    uncheckedAssertEqual(0U, [[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@3.3f]);
    uncheckedAssertEqual(0U, [[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@3.3]);
    uncheckedAssertEqual(0U, [[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@"b"]);
    uncheckedAssertEqual(0U, [[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:data(2)]);
    uncheckedAssertEqual(0U, [[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:date(2)]);
    uncheckedAssertEqual(0U, [[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(0U, [[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:objectId(2)]);
    uncheckedAssertEqual(0U, [[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(2U, [[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@NO]);
    uncheckedAssertEqual(2U, [[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@2]);
    uncheckedAssertEqual(2U, [[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@2.2f]);
    uncheckedAssertEqual(2U, [[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@2.2]);
    uncheckedAssertEqual(2U, [[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:@"a"]);
    uncheckedAssertEqual(2U, [[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:data(1)]);
    uncheckedAssertEqual(2U, [[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:date(1)]);
    uncheckedAssertEqual(2U, [[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(2U, [[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:objectId(1)]);
    uncheckedAssertEqual(2U, [[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(4U, [[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(4U, [[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] indexOfObject:NSNull.null]);
}

- (void)testIndexOfObjectDistinct {
    [managed.boolObj addObjects:@[@NO, @NO, @YES]];
    [managed.intObj addObjects:@[@2, @2, @3]];
    [managed.floatObj addObjects:@[@2.2f, @2.2f, @3.3f]];
    [managed.doubleObj addObjects:@[@2.2, @2.2, @3.3]];
    [managed.stringObj addObjects:@[@"a", @"a", @"b"]];
    [managed.dataObj addObjects:@[data(1), data(1), data(2)]];
    [managed.dateObj addObjects:@[date(1), date(1), date(2)]];
    [managed.decimalObj addObjects:@[decimal128(2), decimal128(2), decimal128(3)]];
    [managed.objectIdObj addObjects:@[objectId(1), objectId(1), objectId(2)]];
    [managed.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]];
    [optManaged.boolObj addObjects:@[@NO, @NO, NSNull.null, @YES, @NO]];
    [optManaged.intObj addObjects:@[@2, @2, NSNull.null, @3, @2]];
    [optManaged.floatObj addObjects:@[@2.2f, @2.2f, NSNull.null, @3.3f, @2.2f]];
    [optManaged.doubleObj addObjects:@[@2.2, @2.2, NSNull.null, @3.3, @2.2]];
    [optManaged.stringObj addObjects:@[@"a", @"a", NSNull.null, @"b", @"a"]];
    [optManaged.dataObj addObjects:@[data(1), data(1), NSNull.null, data(2), data(1)]];
    [optManaged.dateObj addObjects:@[date(1), date(1), NSNull.null, date(2), date(1)]];
    [optManaged.decimalObj addObjects:@[decimal128(2), decimal128(2), NSNull.null, decimal128(3), decimal128(2)]];
    [optManaged.objectIdObj addObjects:@[objectId(1), objectId(1), NSNull.null, objectId(2), objectId(1)]];
    [optManaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), NSNull.null, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000")]];

    uncheckedAssertEqual(0U, [[managed.boolObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@NO]);
    uncheckedAssertEqual(0U, [[managed.intObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@2]);
    uncheckedAssertEqual(0U, [[managed.floatObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@2.2f]);
    uncheckedAssertEqual(0U, [[managed.doubleObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@2.2]);
    uncheckedAssertEqual(0U, [[managed.stringObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@"a"]);
    uncheckedAssertEqual(0U, [[managed.dataObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:data(1)]);
    uncheckedAssertEqual(0U, [[managed.dateObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:date(1)]);
    uncheckedAssertEqual(0U, [[managed.decimalObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(0U, [[managed.objectIdObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:objectId(1)]);
    uncheckedAssertEqual(0U, [[managed.uuidObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(1U, [[managed.boolObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@YES]);
    uncheckedAssertEqual(1U, [[managed.intObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@3]);
    uncheckedAssertEqual(1U, [[managed.floatObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@3.3f]);
    uncheckedAssertEqual(1U, [[managed.doubleObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@3.3]);
    uncheckedAssertEqual(1U, [[managed.stringObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@"b"]);
    uncheckedAssertEqual(1U, [[managed.dataObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:data(2)]);
    uncheckedAssertEqual(1U, [[managed.dateObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:date(2)]);
    uncheckedAssertEqual(1U, [[managed.decimalObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(1U, [[managed.objectIdObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:objectId(2)]);
    uncheckedAssertEqual(1U, [[managed.uuidObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);

    uncheckedAssertEqual(0U, [[optManaged.boolObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@NO]);
    uncheckedAssertEqual(0U, [[optManaged.intObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@2]);
    uncheckedAssertEqual(0U, [[optManaged.floatObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@2.2f]);
    uncheckedAssertEqual(0U, [[optManaged.doubleObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@2.2]);
    uncheckedAssertEqual(0U, [[optManaged.stringObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@"a"]);
    uncheckedAssertEqual(0U, [[optManaged.dataObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:data(1)]);
    uncheckedAssertEqual(0U, [[optManaged.dateObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:date(1)]);
    uncheckedAssertEqual(0U, [[optManaged.decimalObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:decimal128(2)]);
    uncheckedAssertEqual(0U, [[optManaged.objectIdObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:objectId(1)]);
    uncheckedAssertEqual(0U, [[optManaged.uuidObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:uuid(@"00000000-0000-0000-0000-000000000000")]);
    uncheckedAssertEqual(2U, [[optManaged.boolObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@YES]);
    uncheckedAssertEqual(2U, [[optManaged.intObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@3]);
    uncheckedAssertEqual(2U, [[optManaged.floatObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@3.3f]);
    uncheckedAssertEqual(2U, [[optManaged.doubleObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@3.3]);
    uncheckedAssertEqual(2U, [[optManaged.stringObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:@"b"]);
    uncheckedAssertEqual(2U, [[optManaged.dataObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:data(2)]);
    uncheckedAssertEqual(2U, [[optManaged.dateObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:date(2)]);
    uncheckedAssertEqual(2U, [[optManaged.decimalObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:decimal128(3)]);
    uncheckedAssertEqual(2U, [[optManaged.objectIdObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:objectId(2)]);
    uncheckedAssertEqual(2U, [[optManaged.uuidObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    uncheckedAssertEqual(1U, [[optManaged.boolObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.intObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.floatObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.doubleObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.stringObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.dataObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.dateObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.decimalObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.objectIdObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
    uncheckedAssertEqual(1U, [[optManaged.uuidObj distinctResultsUsingKeyPaths:@[@"self"]] indexOfObject:NSNull.null]);
}

- (void)testIndexOfObjectWhere {
    RLMAssertThrowsWithReason([managed.boolObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.intObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.floatObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.doubleObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.stringObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.dataObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.dateObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.decimalObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.objectIdObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.uuidObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyBoolObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyIntObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyFloatObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDoubleObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyStringObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDataObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDateObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDecimalObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([managed.anyUUIDObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.boolObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.intObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.floatObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.doubleObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.stringObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.dataObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.dateObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.decimalObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.objectIdObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([optManaged.uuidObj indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyBoolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyIntObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyFloatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDoubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyStringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDecimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyObjectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyUUIDObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWhere:@"TRUEPREDICATE"], @"implemented");

    uncheckedAssertEqual(NSNotFound, [unmanaged.boolObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.intObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.floatObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.doubleObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.stringObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dataObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dateObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.decimalObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.objectIdObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.uuidObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyBoolObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyIntObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyFloatObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDoubleObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyStringObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDataObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDateObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDecimalObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyObjectIdObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyUUIDObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.boolObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.intObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.floatObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.doubleObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.stringObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dataObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dateObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.decimalObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.objectIdObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.uuidObj indexOfObjectWhere:@"TRUEPREDICATE"]);

    [self addObjects];

    uncheckedAssertEqual(0U, [unmanaged.boolObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.intObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.floatObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.doubleObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.stringObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.dataObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.dateObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.decimalObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.objectIdObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.uuidObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyBoolObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyIntObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyFloatObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyDoubleObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyStringObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyDataObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyDateObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyDecimalObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyObjectIdObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [unmanaged.anyUUIDObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.boolObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.intObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.floatObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.doubleObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.stringObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.dataObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.dateObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.decimalObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.objectIdObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(0U, [optUnmanaged.uuidObj indexOfObjectWhere:@"TRUEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.boolObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.intObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.floatObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.doubleObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.stringObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dataObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dateObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.decimalObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.objectIdObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.uuidObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyBoolObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyIntObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyFloatObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDoubleObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyStringObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDataObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDateObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDecimalObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyObjectIdObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyUUIDObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.boolObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.intObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.floatObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.doubleObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.stringObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dataObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dateObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.decimalObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.objectIdObj indexOfObjectWhere:@"FALSEPREDICATE"]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.uuidObj indexOfObjectWhere:@"FALSEPREDICATE"]);
}

- (void)testIndexOfObjectWithPredicate {
    RLMAssertThrowsWithReason([managed.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyBoolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyIntObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyFloatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDoubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyStringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyDecimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([managed.anyUUIDObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([optManaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyBoolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyIntObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyFloatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDoubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyStringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDecimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyObjectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyUUIDObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");

    uncheckedAssertEqual(NSNotFound, [unmanaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyBoolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyIntObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyFloatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDoubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyStringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDecimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyObjectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyUUIDObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);

    [self addObjects];

    uncheckedAssertEqual(0U, [unmanaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyBoolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyIntObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyFloatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyDoubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyStringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyDataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyDateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyDecimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyObjectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [unmanaged.anyUUIDObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(0U, [optUnmanaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:YES]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyBoolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyIntObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyFloatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDoubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyStringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyDecimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyObjectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [unmanaged.anyUUIDObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.boolObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.intObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.floatObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.doubleObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.stringObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dataObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.dateObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.decimalObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.objectIdObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
    uncheckedAssertEqual(NSNotFound, [optUnmanaged.uuidObj indexOfObjectWithPredicate:[NSPredicate predicateWithValue:NO]]);
}

- (void)testSort {
    RLMAssertThrowsWithReason([unmanaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.boolObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.intObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.floatObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.doubleObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.stringObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dataObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dateObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.decimalObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.uuidObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.intObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj sortedResultsUsingDescriptors:@[]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([managed.boolObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.intObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.floatObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.doubleObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.stringObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.dataObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.dateObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.decimalObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.objectIdObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.uuidObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyBoolObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyIntObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyFloatObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyDoubleObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyStringObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyDataObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyDateObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyDecimalObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([managed.anyUUIDObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.boolObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.intObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.floatObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.doubleObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.stringObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.dataObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.dateObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.decimalObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");
    RLMAssertThrowsWithReason([optManaged.uuidObj sortedResultsUsingKeyPath:@"not self" ascending:NO],
                              @"can only be sorted on 'self'");

    [managed.boolObj addObjects:@[@NO, @YES, @NO]];
    [managed.intObj addObjects:@[@2, @3, @2]];
    [managed.floatObj addObjects:@[@2.2f, @3.3f, @2.2f]];
    [managed.doubleObj addObjects:@[@2.2, @3.3, @2.2]];
    [managed.stringObj addObjects:@[@"a", @"b", @"a"]];
    [managed.dataObj addObjects:@[data(1), data(2), data(1)]];
    [managed.dateObj addObjects:@[date(1), date(2), date(1)]];
    [managed.decimalObj addObjects:@[decimal128(2), decimal128(3), decimal128(2)]];
    [managed.objectIdObj addObjects:@[objectId(1), objectId(2), objectId(1)]];
    [managed.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000")]];
    [optManaged.boolObj addObjects:@[@NO, @YES, NSNull.null, @YES, @NO]];
    [optManaged.intObj addObjects:@[@2, @3, NSNull.null, @3, @2]];
    [optManaged.floatObj addObjects:@[@2.2f, @3.3f, NSNull.null, @3.3f, @2.2f]];
    [optManaged.doubleObj addObjects:@[@2.2, @3.3, NSNull.null, @3.3, @2.2]];
    [optManaged.stringObj addObjects:@[@"a", @"b", NSNull.null, @"b", @"a"]];
    [optManaged.dataObj addObjects:@[data(1), data(2), NSNull.null, data(2), data(1)]];
    [optManaged.dateObj addObjects:@[date(1), date(2), NSNull.null, date(2), date(1)]];
    [optManaged.decimalObj addObjects:@[decimal128(2), decimal128(3), NSNull.null, decimal128(3), decimal128(2)]];
    [optManaged.objectIdObj addObjects:@[objectId(1), objectId(2), NSNull.null, objectId(2), objectId(1)]];
    [optManaged.uuidObj addObjects:@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000")]];

    uncheckedAssertEqualObjects([[managed.boolObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@NO, @YES, @NO]));
    uncheckedAssertEqualObjects([[managed.intObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@2, @3, @2]));
    uncheckedAssertEqualObjects([[managed.floatObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@2.2f, @3.3f, @2.2f]));
    uncheckedAssertEqualObjects([[managed.doubleObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@2.2, @3.3, @2.2]));
    uncheckedAssertEqualObjects([[managed.stringObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@"a", @"b", @"a"]));
    uncheckedAssertEqualObjects([[managed.dataObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[data(1), data(2), data(1)]));
    uncheckedAssertEqualObjects([[managed.dateObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[date(1), date(2), date(1)]));
    uncheckedAssertEqualObjects([[managed.decimalObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[decimal128(2), decimal128(3), decimal128(2)]));
    uncheckedAssertEqualObjects([[managed.objectIdObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[objectId(1), objectId(2), objectId(1)]));
    uncheckedAssertEqualObjects([[managed.uuidObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000")]));
    uncheckedAssertEqualObjects([[optManaged.boolObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@NO, @YES, NSNull.null, @YES, @NO]));
    uncheckedAssertEqualObjects([[optManaged.intObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@2, @3, NSNull.null, @3, @2]));
    uncheckedAssertEqualObjects([[optManaged.floatObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@2.2f, @3.3f, NSNull.null, @3.3f, @2.2f]));
    uncheckedAssertEqualObjects([[optManaged.doubleObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@2.2, @3.3, NSNull.null, @3.3, @2.2]));
    uncheckedAssertEqualObjects([[optManaged.stringObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[@"a", @"b", NSNull.null, @"b", @"a"]));
    uncheckedAssertEqualObjects([[optManaged.dataObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[data(1), data(2), NSNull.null, data(2), data(1)]));
    uncheckedAssertEqualObjects([[optManaged.dateObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[date(1), date(2), NSNull.null, date(2), date(1)]));
    uncheckedAssertEqualObjects([[optManaged.decimalObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[decimal128(2), decimal128(3), NSNull.null, decimal128(3), decimal128(2)]));
    uncheckedAssertEqualObjects([[optManaged.objectIdObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[objectId(1), objectId(2), NSNull.null, objectId(2), objectId(1)]));
    uncheckedAssertEqualObjects([[optManaged.uuidObj sortedResultsUsingDescriptors:@[]] valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null, uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000")]));

    uncheckedAssertEqualObjects([[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@YES, @NO, @NO]));
    uncheckedAssertEqualObjects([[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@3, @2, @2]));
    uncheckedAssertEqualObjects([[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@3.3f, @2.2f, @2.2f]));
    uncheckedAssertEqualObjects([[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@3.3, @2.2, @2.2]));
    uncheckedAssertEqualObjects([[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@"b", @"a", @"a"]));
    uncheckedAssertEqualObjects([[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[data(2), data(1), data(1)]));
    uncheckedAssertEqualObjects([[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[date(2), date(1), date(1)]));
    uncheckedAssertEqualObjects([[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[decimal128(3), decimal128(2), decimal128(2)]));
    uncheckedAssertEqualObjects([[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[objectId(2), objectId(1), objectId(1)]));
    uncheckedAssertEqualObjects([[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000")]));
    uncheckedAssertEqualObjects([[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@YES, @YES, @NO, @NO, NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@3, @3, @2, @2, NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@3.3f, @3.3f, @2.2f, @2.2f, NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@3.3, @3.3, @2.2, @2.2, NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[@"b", @"b", @"a", @"a", NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[data(2), data(2), data(1), data(1), NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[date(2), date(2), date(1), date(1), NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[decimal128(3), decimal128(3), decimal128(2), decimal128(2), NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[objectId(2), objectId(2), objectId(1), objectId(1), NSNull.null]));
    uncheckedAssertEqualObjects([[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO] valueForKey:@"self"],
                                (@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), NSNull.null]));

    uncheckedAssertEqualObjects([[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[@NO, @NO, @YES]));
    uncheckedAssertEqualObjects([[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[@2, @2, @3]));
    uncheckedAssertEqualObjects([[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[@2.2f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[@2.2, @2.2, @3.3]));
    uncheckedAssertEqualObjects([[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[@"a", @"a", @"b"]));
    uncheckedAssertEqualObjects([[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[data(1), data(1), data(2)]));
    uncheckedAssertEqualObjects([[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[date(1), date(1), date(2)]));
    uncheckedAssertEqualObjects([[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[decimal128(2), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[objectId(1), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, @NO, @NO, @YES, @YES]));
    uncheckedAssertEqualObjects([[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, @2, @2, @3, @3]));
    uncheckedAssertEqualObjects([[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, @2.2f, @2.2f, @3.3f, @3.3f]));
    uncheckedAssertEqualObjects([[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, @2.2, @2.2, @3.3, @3.3]));
    uncheckedAssertEqualObjects([[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, @"a", @"a", @"b", @"b"]));
    uncheckedAssertEqualObjects([[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, data(1), data(1), data(2), data(2)]));
    uncheckedAssertEqualObjects([[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, date(1), date(1), date(2), date(2)]));
    uncheckedAssertEqualObjects([[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, decimal128(2), decimal128(2), decimal128(3), decimal128(3)]));
    uncheckedAssertEqualObjects([[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, objectId(1), objectId(1), objectId(2), objectId(2)]));
    uncheckedAssertEqualObjects([[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:YES] valueForKey:@"self"],
                                (@[NSNull.null, uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
}

- (void)testFilter {
    RLMAssertThrowsWithReason([unmanaged.boolObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.intObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.floatObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.doubleObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.stringObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dataObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dateObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.decimalObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.uuidObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.intObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj objectsWhere:@"TRUEPREDICATE"],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.boolObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.intObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.floatObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.doubleObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.stringObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dataObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dateObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.decimalObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.uuidObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.intObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");

    RLMAssertThrowsWithReason([managed.boolObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.intObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.floatObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.doubleObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.stringObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.dataObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.dateObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.decimalObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.objectIdObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.uuidObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyBoolObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyIntObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyFloatObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDoubleObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyStringObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDataObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDateObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDecimalObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyUUIDObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.boolObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.intObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.floatObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.doubleObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.stringObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.dataObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.dateObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.decimalObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.objectIdObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.uuidObj objectsWhere:@"TRUEPREDICATE"],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.boolObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.intObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.floatObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.doubleObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.stringObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.dataObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.dateObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.decimalObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.objectIdObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.uuidObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyBoolObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyIntObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyFloatObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDoubleObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyStringObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDataObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDateObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyDecimalObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyObjectIdObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([managed.anyUUIDObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.boolObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.intObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.floatObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.doubleObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.stringObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.dataObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.dateObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.decimalObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.objectIdObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");
    RLMAssertThrowsWithReason([optManaged.uuidObj objectsWithPredicate:[NSPredicate predicateWithValue:YES]],
                              @"implemented");

    RLMAssertThrowsWithReason([[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyBoolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyIntObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyFloatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDoubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyStringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDecimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyObjectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyUUIDObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWhere:@"TRUEPREDICATE"], @"implemented");
    RLMAssertThrowsWithReason([[managed.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyBoolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyIntObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyFloatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDoubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyStringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyDecimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyObjectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[managed.anyUUIDObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.boolObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.intObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.floatObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.doubleObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.stringObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dataObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.dateObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.decimalObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.objectIdObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
    RLMAssertThrowsWithReason([[optManaged.uuidObj sortedResultsUsingKeyPath:@"self" ascending:NO]
                               objectsWithPredicate:[NSPredicate predicateWithValue:YES]], @"implemented");
}

- (void)testNotifications {
    RLMAssertThrowsWithReason([unmanaged.boolObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.intObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.floatObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.doubleObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.stringObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dataObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.dateObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.decimalObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.uuidObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyBoolObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyIntObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyFloatObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDoubleObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyStringObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDataObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDateObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyDecimalObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyObjectIdObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([unmanaged.anyUUIDObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.intObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj addNotificationBlock:^(__unused id a, __unused id c, __unused id e) { }],
                              @"This method may only be called on RLMArray instances retrieved from an RLMRealm");
}

- (void)testMin {
    RLMAssertThrowsWithReason([unmanaged.boolObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for bool array");
    RLMAssertThrowsWithReason([unmanaged.stringObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for string array");
    RLMAssertThrowsWithReason([unmanaged.dataObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for data array");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for object id array");
    RLMAssertThrowsWithReason([unmanaged.uuidObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for uuid array");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for bool? array");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for string? array");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for data? array");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for object id? array");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for uuid? array");
    RLMAssertThrowsWithReason([managed.boolObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for bool array 'AllPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([managed.stringObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for string array 'AllPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([managed.dataObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for data array 'AllPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([managed.objectIdObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for object id array 'AllPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([managed.uuidObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for uuid array 'AllPrimitiveArrays.uuidObj'");
    RLMAssertThrowsWithReason([optManaged.boolObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for bool? array 'AllOptionalPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([optManaged.stringObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for string? array 'AllOptionalPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([optManaged.dataObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for data? array 'AllOptionalPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for object id? array 'AllOptionalPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([optManaged.uuidObj minOfProperty:@"self"],
                              @"minOfProperty: is not supported for uuid? array 'AllOptionalPrimitiveArrays.uuidObj'");

    uncheckedAssertNil([unmanaged.intObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.floatObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.doubleObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.dateObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.decimalObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyFloatObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDoubleObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDateObj minOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDecimalObj minOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.intObj minOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.floatObj minOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.doubleObj minOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.dateObj minOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.decimalObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.intObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.floatObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.doubleObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.dateObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.decimalObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyIntObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyFloatObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDoubleObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDateObj minOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDecimalObj minOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.intObj minOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.floatObj minOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.doubleObj minOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.dateObj minOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.decimalObj minOfProperty:@"self"]);

    [self addObjects];

    uncheckedAssertEqualObjects([unmanaged.intObj minOfProperty:@"self"], @2);
    uncheckedAssertEqualObjects([unmanaged.floatObj minOfProperty:@"self"], @2.2f);
    uncheckedAssertEqualObjects([unmanaged.doubleObj minOfProperty:@"self"], @2.2);
    uncheckedAssertEqualObjects([unmanaged.dateObj minOfProperty:@"self"], date(1));
    uncheckedAssertEqualObjects([unmanaged.decimalObj minOfProperty:@"self"], decimal128(2));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj minOfProperty:@"self"], @2.2f);
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj minOfProperty:@"self"], @2.2);
    uncheckedAssertEqualObjects([unmanaged.anyDateObj minOfProperty:@"self"], date(1));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj minOfProperty:@"self"], decimal128(2));
    uncheckedAssertEqualObjects([optUnmanaged.intObj minOfProperty:@"self"], @2);
    uncheckedAssertEqualObjects([optUnmanaged.floatObj minOfProperty:@"self"], @2.2f);
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj minOfProperty:@"self"], @2.2);
    uncheckedAssertEqualObjects([optUnmanaged.dateObj minOfProperty:@"self"], date(1));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj minOfProperty:@"self"], decimal128(2));
    uncheckedAssertEqualObjects([managed.intObj minOfProperty:@"self"], @2);
    uncheckedAssertEqualObjects([managed.floatObj minOfProperty:@"self"], @2.2f);
    uncheckedAssertEqualObjects([managed.doubleObj minOfProperty:@"self"], @2.2);
    uncheckedAssertEqualObjects([managed.dateObj minOfProperty:@"self"], date(1));
    uncheckedAssertEqualObjects([managed.decimalObj minOfProperty:@"self"], decimal128(2));
    uncheckedAssertEqualObjects([managed.anyIntObj minOfProperty:@"self"], @2);
    uncheckedAssertEqualObjects([managed.anyFloatObj minOfProperty:@"self"], @2.2f);
    uncheckedAssertEqualObjects([managed.anyDoubleObj minOfProperty:@"self"], @2.2);
    uncheckedAssertEqualObjects([managed.anyDateObj minOfProperty:@"self"], date(1));
    uncheckedAssertEqualObjects([managed.anyDecimalObj minOfProperty:@"self"], decimal128(2));
    uncheckedAssertEqualObjects([optManaged.intObj minOfProperty:@"self"], @2);
    uncheckedAssertEqualObjects([optManaged.floatObj minOfProperty:@"self"], @2.2f);
    uncheckedAssertEqualObjects([optManaged.doubleObj minOfProperty:@"self"], @2.2);
    uncheckedAssertEqualObjects([optManaged.dateObj minOfProperty:@"self"], date(1));
    uncheckedAssertEqualObjects([optManaged.decimalObj minOfProperty:@"self"], decimal128(2));
}

- (void)testMax {
    RLMAssertThrowsWithReason([unmanaged.boolObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for bool array");
    RLMAssertThrowsWithReason([unmanaged.stringObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for string array");
    RLMAssertThrowsWithReason([unmanaged.dataObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for data array");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for object id array");
    RLMAssertThrowsWithReason([unmanaged.uuidObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for uuid array");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for bool? array");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for string? array");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for data? array");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for object id? array");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for uuid? array");
    RLMAssertThrowsWithReason([managed.boolObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for bool array 'AllPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([managed.stringObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for string array 'AllPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([managed.dataObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for data array 'AllPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([managed.objectIdObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for object id array 'AllPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([managed.uuidObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for uuid array 'AllPrimitiveArrays.uuidObj'");
    RLMAssertThrowsWithReason([optManaged.boolObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for bool? array 'AllOptionalPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([optManaged.stringObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for string? array 'AllOptionalPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([optManaged.dataObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for data? array 'AllOptionalPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for object id? array 'AllOptionalPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([optManaged.uuidObj maxOfProperty:@"self"],
                              @"maxOfProperty: is not supported for uuid? array 'AllOptionalPrimitiveArrays.uuidObj'");

    uncheckedAssertNil([unmanaged.intObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.floatObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.doubleObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.dateObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.decimalObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyFloatObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDoubleObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDateObj maxOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDecimalObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.intObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.floatObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.doubleObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.dateObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.decimalObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.intObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.floatObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.doubleObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.dateObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.decimalObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyIntObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyFloatObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDoubleObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDateObj maxOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDecimalObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.intObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.floatObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.doubleObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.dateObj maxOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.decimalObj maxOfProperty:@"self"]);

    [self addObjects];

    uncheckedAssertEqualObjects([unmanaged.intObj maxOfProperty:@"self"], @3);
    uncheckedAssertEqualObjects([unmanaged.floatObj maxOfProperty:@"self"], @3.3f);
    uncheckedAssertEqualObjects([unmanaged.doubleObj maxOfProperty:@"self"], @3.3);
    uncheckedAssertEqualObjects([unmanaged.dateObj maxOfProperty:@"self"], date(2));
    uncheckedAssertEqualObjects([unmanaged.decimalObj maxOfProperty:@"self"], decimal128(3));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj maxOfProperty:@"self"], @3.3f);
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj maxOfProperty:@"self"], @3.3);
    uncheckedAssertEqualObjects([unmanaged.anyDateObj maxOfProperty:@"self"], date(2));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj maxOfProperty:@"self"], decimal128(3));
    uncheckedAssertEqualObjects([optUnmanaged.intObj maxOfProperty:@"self"], @3);
    uncheckedAssertEqualObjects([optUnmanaged.floatObj maxOfProperty:@"self"], @3.3f);
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj maxOfProperty:@"self"], @3.3);
    uncheckedAssertEqualObjects([optUnmanaged.dateObj maxOfProperty:@"self"], date(2));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj maxOfProperty:@"self"], decimal128(3));
    uncheckedAssertEqualObjects([managed.intObj maxOfProperty:@"self"], @3);
    uncheckedAssertEqualObjects([managed.floatObj maxOfProperty:@"self"], @3.3f);
    uncheckedAssertEqualObjects([managed.doubleObj maxOfProperty:@"self"], @3.3);
    uncheckedAssertEqualObjects([managed.dateObj maxOfProperty:@"self"], date(2));
    uncheckedAssertEqualObjects([managed.decimalObj maxOfProperty:@"self"], decimal128(3));
    uncheckedAssertEqualObjects([managed.anyIntObj maxOfProperty:@"self"], @3);
    uncheckedAssertEqualObjects([managed.anyFloatObj maxOfProperty:@"self"], @3.3f);
    uncheckedAssertEqualObjects([managed.anyDoubleObj maxOfProperty:@"self"], @3.3);
    uncheckedAssertEqualObjects([managed.anyDateObj maxOfProperty:@"self"], date(2));
    uncheckedAssertEqualObjects([managed.anyDecimalObj maxOfProperty:@"self"], decimal128(3));
    uncheckedAssertEqualObjects([optManaged.intObj maxOfProperty:@"self"], @3);
    uncheckedAssertEqualObjects([optManaged.floatObj maxOfProperty:@"self"], @3.3f);
    uncheckedAssertEqualObjects([optManaged.doubleObj maxOfProperty:@"self"], @3.3);
    uncheckedAssertEqualObjects([optManaged.dateObj maxOfProperty:@"self"], date(2));
    uncheckedAssertEqualObjects([optManaged.decimalObj maxOfProperty:@"self"], decimal128(3));
}

- (void)testSum {
    RLMAssertThrowsWithReason([unmanaged.boolObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for bool array");
    RLMAssertThrowsWithReason([unmanaged.stringObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for string array");
    RLMAssertThrowsWithReason([unmanaged.dataObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for data array");
    RLMAssertThrowsWithReason([unmanaged.dateObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for date array");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for object id array");
    RLMAssertThrowsWithReason([unmanaged.uuidObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for uuid array");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for bool? array");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for string? array");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for data? array");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for date? array");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for object id? array");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for uuid? array");
    RLMAssertThrowsWithReason([managed.boolObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for bool array 'AllPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([managed.stringObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for string array 'AllPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([managed.dataObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for data array 'AllPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([managed.dateObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for date array 'AllPrimitiveArrays.dateObj'");
    RLMAssertThrowsWithReason([managed.objectIdObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for object id array 'AllPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([managed.uuidObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for uuid array 'AllPrimitiveArrays.uuidObj'");
    RLMAssertThrowsWithReason([optManaged.boolObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for bool? array 'AllOptionalPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([optManaged.stringObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for string? array 'AllOptionalPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([optManaged.dataObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for data? array 'AllOptionalPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([optManaged.dateObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for date? array 'AllOptionalPrimitiveArrays.dateObj'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for object id? array 'AllOptionalPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([optManaged.uuidObj sumOfProperty:@"self"],
                              @"sumOfProperty: is not supported for uuid? array 'AllOptionalPrimitiveArrays.uuidObj'");

    uncheckedAssertEqualObjects([unmanaged.intObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.floatObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.doubleObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.decimalObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.anyIntObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.intObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.floatObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.intObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.floatObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.doubleObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.decimalObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.anyIntObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.anyFloatObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.anyDoubleObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([managed.anyDecimalObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optManaged.intObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optManaged.floatObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optManaged.doubleObj sumOfProperty:@"self"], @0);
    uncheckedAssertEqualObjects([optManaged.decimalObj sumOfProperty:@"self"], @0);

    [self addObjects];

    XCTAssertEqualWithAccuracy([unmanaged.intObj sumOfProperty:@"self"].doubleValue, sum(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.floatObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.doubleObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.decimalObj sumOfProperty:@"self"].doubleValue, sum(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyIntObj sumOfProperty:@"self"].doubleValue, sum(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyFloatObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyDoubleObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyDecimalObj sumOfProperty:@"self"].doubleValue, sum(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.intObj sumOfProperty:@"self"].doubleValue, sum(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.floatObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.doubleObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.decimalObj sumOfProperty:@"self"].doubleValue, sum(@[decimal128(2), decimal128(3), NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([managed.intObj sumOfProperty:@"self"].doubleValue, sum(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([managed.floatObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([managed.doubleObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([managed.decimalObj sumOfProperty:@"self"].doubleValue, sum(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([managed.anyIntObj sumOfProperty:@"self"].doubleValue, sum(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([managed.anyFloatObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([managed.anyDoubleObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([managed.anyDecimalObj sumOfProperty:@"self"].doubleValue, sum(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([optManaged.intObj sumOfProperty:@"self"].doubleValue, sum(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optManaged.floatObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optManaged.doubleObj sumOfProperty:@"self"].doubleValue, sum(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optManaged.decimalObj sumOfProperty:@"self"].doubleValue, sum(@[decimal128(2), decimal128(3), NSNull.null]), .001);
}

- (void)testAverage {
    RLMAssertThrowsWithReason([unmanaged.boolObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for bool array");
    RLMAssertThrowsWithReason([unmanaged.stringObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for string array");
    RLMAssertThrowsWithReason([unmanaged.dataObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for data array");
    RLMAssertThrowsWithReason([unmanaged.dateObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for date array");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for object id array");
    RLMAssertThrowsWithReason([unmanaged.uuidObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for uuid array");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for bool? array");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for string? array");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for data? array");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for date? array");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for object id? array");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for uuid? array");
    RLMAssertThrowsWithReason([managed.boolObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for bool array 'AllPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([managed.stringObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for string array 'AllPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([managed.dataObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for data array 'AllPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([managed.dateObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for date array 'AllPrimitiveArrays.dateObj'");
    RLMAssertThrowsWithReason([managed.objectIdObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for object id array 'AllPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([managed.uuidObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for uuid array 'AllPrimitiveArrays.uuidObj'");
    RLMAssertThrowsWithReason([optManaged.boolObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for bool? array 'AllOptionalPrimitiveArrays.boolObj'");
    RLMAssertThrowsWithReason([optManaged.stringObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for string? array 'AllOptionalPrimitiveArrays.stringObj'");
    RLMAssertThrowsWithReason([optManaged.dataObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for data? array 'AllOptionalPrimitiveArrays.dataObj'");
    RLMAssertThrowsWithReason([optManaged.dateObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for date? array 'AllOptionalPrimitiveArrays.dateObj'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for object id? array 'AllOptionalPrimitiveArrays.objectIdObj'");
    RLMAssertThrowsWithReason([optManaged.uuidObj averageOfProperty:@"self"],
                              @"averageOfProperty: is not supported for uuid? array 'AllOptionalPrimitiveArrays.uuidObj'");

    uncheckedAssertNil([unmanaged.intObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.floatObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.doubleObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.decimalObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyIntObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyFloatObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDoubleObj averageOfProperty:@"self"]);
    uncheckedAssertNil([unmanaged.anyDecimalObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.intObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.floatObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.doubleObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optUnmanaged.decimalObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.intObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.floatObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.doubleObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.decimalObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyIntObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyFloatObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDoubleObj averageOfProperty:@"self"]);
    uncheckedAssertNil([managed.anyDecimalObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.intObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.floatObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.doubleObj averageOfProperty:@"self"]);
    uncheckedAssertNil([optManaged.decimalObj averageOfProperty:@"self"]);

    [self addObjects];

    XCTAssertEqualWithAccuracy([unmanaged.intObj averageOfProperty:@"self"].doubleValue, average(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.floatObj averageOfProperty:@"self"].doubleValue, average(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.doubleObj averageOfProperty:@"self"].doubleValue, average(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.decimalObj averageOfProperty:@"self"].doubleValue, average(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyIntObj averageOfProperty:@"self"].doubleValue, average(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyFloatObj averageOfProperty:@"self"].doubleValue, average(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyDoubleObj averageOfProperty:@"self"].doubleValue, average(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([unmanaged.anyDecimalObj averageOfProperty:@"self"].doubleValue, average(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.intObj averageOfProperty:@"self"].doubleValue, average(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.floatObj averageOfProperty:@"self"].doubleValue, average(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.doubleObj averageOfProperty:@"self"].doubleValue, average(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optUnmanaged.decimalObj averageOfProperty:@"self"].doubleValue, average(@[decimal128(2), decimal128(3), NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([managed.intObj averageOfProperty:@"self"].doubleValue, average(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([managed.floatObj averageOfProperty:@"self"].doubleValue, average(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([managed.doubleObj averageOfProperty:@"self"].doubleValue, average(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([managed.decimalObj averageOfProperty:@"self"].doubleValue, average(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([managed.anyIntObj averageOfProperty:@"self"].doubleValue, average(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([managed.anyFloatObj averageOfProperty:@"self"].doubleValue, average(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([managed.anyDoubleObj averageOfProperty:@"self"].doubleValue, average(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([managed.anyDecimalObj averageOfProperty:@"self"].doubleValue, average(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([optManaged.intObj averageOfProperty:@"self"].doubleValue, average(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optManaged.floatObj averageOfProperty:@"self"].doubleValue, average(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optManaged.doubleObj averageOfProperty:@"self"].doubleValue, average(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([optManaged.decimalObj averageOfProperty:@"self"].doubleValue, average(@[decimal128(2), decimal128(3), NSNull.null]), .001);
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
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@NO, @YES];
    for (id value in unmanaged.boolObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.boolObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2, @3];
    for (id value in unmanaged.intObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.intObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2f, @3.3f];
    for (id value in unmanaged.floatObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.floatObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2, @3.3];
    for (id value in unmanaged.doubleObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.doubleObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@"a", @"b"];
    for (id value in unmanaged.stringObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.stringObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[data(1), data(2)];
    for (id value in unmanaged.dataObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.dataObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[date(1), date(2)];
    for (id value in unmanaged.dateObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.dateObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[decimal128(2), decimal128(3)];
    for (id value in unmanaged.decimalObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.decimalObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[objectId(1), objectId(2)];
    for (id value in unmanaged.objectIdObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.objectIdObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    for (id value in unmanaged.uuidObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.uuidObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@NO, @YES];
    for (id value in unmanaged.anyBoolObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyBoolObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2, @3];
    for (id value in unmanaged.anyIntObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyIntObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2f, @3.3f];
    for (id value in unmanaged.anyFloatObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyFloatObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2, @3.3];
    for (id value in unmanaged.anyDoubleObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyDoubleObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@"a", @"b"];
    for (id value in unmanaged.anyStringObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyStringObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[data(1), data(2)];
    for (id value in unmanaged.anyDataObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyDataObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[date(1), date(2)];
    for (id value in unmanaged.anyDateObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyDateObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[decimal128(2), decimal128(3)];
    for (id value in unmanaged.anyDecimalObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyDecimalObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[objectId(1), objectId(2)];
    for (id value in unmanaged.anyObjectIdObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyObjectIdObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    for (id value in unmanaged.anyUUIDObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, unmanaged.anyUUIDObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@NO, @YES, NSNull.null];
    for (id value in optUnmanaged.boolObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.boolObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2, @3, NSNull.null];
    for (id value in optUnmanaged.intObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.intObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2f, @3.3f, NSNull.null];
    for (id value in optUnmanaged.floatObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.floatObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2, @3.3, NSNull.null];
    for (id value in optUnmanaged.doubleObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.doubleObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@"a", @"b", NSNull.null];
    for (id value in optUnmanaged.stringObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.stringObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[data(1), data(2), NSNull.null];
    for (id value in optUnmanaged.dataObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.dataObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[date(1), date(2), NSNull.null];
    for (id value in optUnmanaged.dateObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.dateObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[decimal128(2), decimal128(3), NSNull.null];
    for (id value in optUnmanaged.decimalObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.decimalObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[objectId(1), objectId(2), NSNull.null];
    for (id value in optUnmanaged.objectIdObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.objectIdObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null];
    for (id value in optUnmanaged.uuidObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optUnmanaged.uuidObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@NO, @YES];
    for (id value in managed.boolObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.boolObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2, @3];
    for (id value in managed.intObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.intObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2f, @3.3f];
    for (id value in managed.floatObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.floatObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2, @3.3];
    for (id value in managed.doubleObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.doubleObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@"a", @"b"];
    for (id value in managed.stringObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.stringObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[data(1), data(2)];
    for (id value in managed.dataObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.dataObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[date(1), date(2)];
    for (id value in managed.dateObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.dateObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[decimal128(2), decimal128(3)];
    for (id value in managed.decimalObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.decimalObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[objectId(1), objectId(2)];
    for (id value in managed.objectIdObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.objectIdObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    for (id value in managed.uuidObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.uuidObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@NO, @YES];
    for (id value in managed.anyBoolObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyBoolObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2, @3];
    for (id value in managed.anyIntObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyIntObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2f, @3.3f];
    for (id value in managed.anyFloatObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyFloatObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2, @3.3];
    for (id value in managed.anyDoubleObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyDoubleObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@"a", @"b"];
    for (id value in managed.anyStringObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyStringObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[data(1), data(2)];
    for (id value in managed.anyDataObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyDataObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[date(1), date(2)];
    for (id value in managed.anyDateObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyDateObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[decimal128(2), decimal128(3)];
    for (id value in managed.anyDecimalObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyDecimalObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[objectId(1), objectId(2)];
    for (id value in managed.anyObjectIdObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyObjectIdObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    for (id value in managed.anyUUIDObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, managed.anyUUIDObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@NO, @YES, NSNull.null];
    for (id value in optManaged.boolObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.boolObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2, @3, NSNull.null];
    for (id value in optManaged.intObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.intObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2f, @3.3f, NSNull.null];
    for (id value in optManaged.floatObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.floatObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@2.2, @3.3, NSNull.null];
    for (id value in optManaged.doubleObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.doubleObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[@"a", @"b", NSNull.null];
    for (id value in optManaged.stringObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.stringObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[data(1), data(2), NSNull.null];
    for (id value in optManaged.dataObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.dataObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[date(1), date(2), NSNull.null];
    for (id value in optManaged.dateObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.dateObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[decimal128(2), decimal128(3), NSNull.null];
    for (id value in optManaged.decimalObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.decimalObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[objectId(1), objectId(2), NSNull.null];
    for (id value in optManaged.objectIdObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.objectIdObj.count);
    }();
    
    ^{
    NSUInteger i = 0;
    NSArray *values = @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null];
    for (id value in optManaged.uuidObj) {
    uncheckedAssertEqualObjects(values[i++ % values.count], value);
    }
    uncheckedAssertEqual(i, optManaged.uuidObj.count);
    }();
    
}

- (void)testValueForKeySelf {
    for (RLMArray *array in allArrays) {
        uncheckedAssertEqualObjects([array valueForKey:@"self"], @[]);
    }

    [self addObjects];

    uncheckedAssertEqualObjects([unmanaged.boolObj valueForKey:@"self"], (@[@NO, @YES]));
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"], (@[@2, @3]));
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKey:@"self"], (@[@"a", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.dataObj valueForKey:@"self"], (@[data(1), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKey:@"self"], (@[date(1), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([unmanaged.anyBoolObj valueForKey:@"self"], (@[@NO, @YES]));
    uncheckedAssertEqualObjects([unmanaged.anyIntObj valueForKey:@"self"], (@[@2, @3]));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKey:@"self"], (@[@"a", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.anyDataObj valueForKey:@"self"], (@[data(1), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKey:@"self"], (@[date(1), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.anyObjectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyUUIDObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optUnmanaged.boolObj valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.dataObj valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    uncheckedAssertEqualObjects([managed.boolObj valueForKey:@"self"], (@[@NO, @YES]));
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"], (@[@2, @3]));
    uncheckedAssertEqualObjects([managed.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects([managed.doubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects([managed.stringObj valueForKey:@"self"], (@[@"a", @"b"]));
    uncheckedAssertEqualObjects([managed.dataObj valueForKey:@"self"], (@[data(1), data(2)]));
    uncheckedAssertEqualObjects([managed.dateObj valueForKey:@"self"], (@[date(1), date(2)]));
    uncheckedAssertEqualObjects([managed.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([managed.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([managed.anyBoolObj valueForKey:@"self"], (@[@NO, @YES]));
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKey:@"self"], (@[@2, @3]));
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKey:@"self"], (@[@"a", @"b"]));
    uncheckedAssertEqualObjects([managed.anyDataObj valueForKey:@"self"], (@[data(1), data(2)]));
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKey:@"self"], (@[date(1), date(2)]));
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.anyObjectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([managed.anyUUIDObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optManaged.boolObj valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.intObj valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.dataObj valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
}

- (void)testValueForKeyNumericAggregates {
    uncheckedAssertNil([unmanaged.intObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.floatObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.doubleObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.dateObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.decimalObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.anyFloatObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.anyDoubleObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.anyDateObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.anyDecimalObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optUnmanaged.intObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optUnmanaged.floatObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optUnmanaged.doubleObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optUnmanaged.dateObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optUnmanaged.decimalObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.intObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.floatObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.doubleObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.dateObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.decimalObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.anyIntObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.anyFloatObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.anyDoubleObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.anyDateObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([managed.anyDecimalObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optManaged.intObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optManaged.floatObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optManaged.doubleObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optManaged.dateObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([optManaged.decimalObj valueForKeyPath:@"@min.self"]);
    uncheckedAssertNil([unmanaged.intObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.floatObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.doubleObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.dateObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.decimalObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.anyFloatObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.anyDoubleObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.anyDateObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([unmanaged.anyDecimalObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optUnmanaged.intObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optUnmanaged.floatObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optUnmanaged.doubleObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optUnmanaged.dateObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optUnmanaged.decimalObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.intObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.floatObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.doubleObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.dateObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.decimalObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.anyIntObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.anyFloatObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.anyDoubleObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.anyDateObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([managed.anyDecimalObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optManaged.intObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optManaged.floatObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optManaged.doubleObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optManaged.dateObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertNil([optManaged.decimalObj valueForKeyPath:@"@max.self"]);
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([managed.intObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([managed.floatObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([managed.doubleObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([managed.decimalObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optManaged.intObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKeyPath:@"@sum.self"], @0);
    uncheckedAssertNil([unmanaged.intObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([unmanaged.floatObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([unmanaged.doubleObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([unmanaged.decimalObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optUnmanaged.intObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optUnmanaged.floatObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optUnmanaged.doubleObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optUnmanaged.decimalObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([managed.intObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([managed.floatObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([managed.doubleObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([managed.decimalObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optManaged.intObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optManaged.floatObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optManaged.doubleObj valueForKeyPath:@"@avg.self"]);
    uncheckedAssertNil([optManaged.decimalObj valueForKeyPath:@"@avg.self"]);

    [self addObjects];

    uncheckedAssertEqualObjects([unmanaged.intObj valueForKeyPath:@"@min.self"], @2);
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKeyPath:@"@min.self"], @2.2f);
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKeyPath:@"@min.self"], @2.2);
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKeyPath:@"@min.self"], date(1));
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKeyPath:@"@min.self"], decimal128(2));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKeyPath:@"@min.self"], @2.2f);
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKeyPath:@"@min.self"], @2.2);
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKeyPath:@"@min.self"], date(1));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKeyPath:@"@min.self"], decimal128(2));
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKeyPath:@"@min.self"], @2);
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKeyPath:@"@min.self"], @2.2f);
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKeyPath:@"@min.self"], @2.2);
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKeyPath:@"@min.self"], date(1));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKeyPath:@"@min.self"], decimal128(2));
    uncheckedAssertEqualObjects([managed.intObj valueForKeyPath:@"@min.self"], @2);
    uncheckedAssertEqualObjects([managed.floatObj valueForKeyPath:@"@min.self"], @2.2f);
    uncheckedAssertEqualObjects([managed.doubleObj valueForKeyPath:@"@min.self"], @2.2);
    uncheckedAssertEqualObjects([managed.dateObj valueForKeyPath:@"@min.self"], date(1));
    uncheckedAssertEqualObjects([managed.decimalObj valueForKeyPath:@"@min.self"], decimal128(2));
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKeyPath:@"@min.self"], @2);
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKeyPath:@"@min.self"], @2.2f);
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKeyPath:@"@min.self"], @2.2);
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKeyPath:@"@min.self"], date(1));
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKeyPath:@"@min.self"], decimal128(2));
    uncheckedAssertEqualObjects([optManaged.intObj valueForKeyPath:@"@min.self"], @2);
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKeyPath:@"@min.self"], @2.2f);
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKeyPath:@"@min.self"], @2.2);
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKeyPath:@"@min.self"], date(1));
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKeyPath:@"@min.self"], decimal128(2));
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKeyPath:@"@max.self"], @3);
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKeyPath:@"@max.self"], @3.3f);
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKeyPath:@"@max.self"], @3.3);
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKeyPath:@"@max.self"], date(2));
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKeyPath:@"@max.self"], decimal128(3));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKeyPath:@"@max.self"], @3.3f);
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKeyPath:@"@max.self"], @3.3);
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKeyPath:@"@max.self"], date(2));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKeyPath:@"@max.self"], decimal128(3));
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKeyPath:@"@max.self"], @3);
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKeyPath:@"@max.self"], @3.3f);
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKeyPath:@"@max.self"], @3.3);
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKeyPath:@"@max.self"], date(2));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKeyPath:@"@max.self"], decimal128(3));
    uncheckedAssertEqualObjects([managed.intObj valueForKeyPath:@"@max.self"], @3);
    uncheckedAssertEqualObjects([managed.floatObj valueForKeyPath:@"@max.self"], @3.3f);
    uncheckedAssertEqualObjects([managed.doubleObj valueForKeyPath:@"@max.self"], @3.3);
    uncheckedAssertEqualObjects([managed.dateObj valueForKeyPath:@"@max.self"], date(2));
    uncheckedAssertEqualObjects([managed.decimalObj valueForKeyPath:@"@max.self"], decimal128(3));
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKeyPath:@"@max.self"], @3);
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKeyPath:@"@max.self"], @3.3f);
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKeyPath:@"@max.self"], @3.3);
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKeyPath:@"@max.self"], date(2));
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKeyPath:@"@max.self"], decimal128(3));
    uncheckedAssertEqualObjects([optManaged.intObj valueForKeyPath:@"@max.self"], @3);
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKeyPath:@"@max.self"], @3.3f);
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKeyPath:@"@max.self"], @3.3);
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKeyPath:@"@max.self"], date(2));
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKeyPath:@"@max.self"], decimal128(3));
    XCTAssertEqualWithAccuracy([[unmanaged.intObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.floatObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.doubleObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.decimalObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.intObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.floatObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.doubleObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.decimalObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[decimal128(2), decimal128(3), NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[managed.intObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([[managed.floatObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([[managed.doubleObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([[managed.decimalObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.intObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.floatObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.doubleObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.decimalObj valueForKeyPath:@"@sum.self"] doubleValue], sum(@[decimal128(2), decimal128(3), NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.intObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.floatObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.doubleObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([[unmanaged.decimalObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.intObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.floatObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.doubleObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optUnmanaged.decimalObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[decimal128(2), decimal128(3), NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[managed.intObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2, @3]), .001);
    XCTAssertEqualWithAccuracy([[managed.floatObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2f, @3.3f]), .001);
    XCTAssertEqualWithAccuracy([[managed.doubleObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2, @3.3]), .001);
    XCTAssertEqualWithAccuracy([[managed.decimalObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[decimal128(2), decimal128(3)]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.intObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2, @3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.floatObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2f, @3.3f, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.doubleObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[@2.2, @3.3, NSNull.null]), .001);
    XCTAssertEqualWithAccuracy([[optManaged.decimalObj valueForKeyPath:@"@avg.self"] doubleValue], average(@[decimal128(2), decimal128(3), NSNull.null]), .001);
}

- (void)testValueForKeyLength {
    for (RLMArray *array in allArrays) {
        uncheckedAssertEqualObjects([array valueForKey:@"length"], @[]);
    }

    [self addObjects];

    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKey:@"length"], ([@[@"a", @"b"] valueForKey:@"length"]));
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKey:@"length"], ([@[@"a", @"b"] valueForKey:@"length"]));
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKey:@"length"], ([@[@"a", @"b", NSNull.null] valueForKey:@"length"]));
    uncheckedAssertEqualObjects([managed.stringObj valueForKey:@"length"], ([@[@"a", @"b"] valueForKey:@"length"]));
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKey:@"length"], ([@[@"a", @"b"] valueForKey:@"length"]));
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKey:@"length"], ([@[@"a", @"b", NSNull.null] valueForKey:@"length"]));
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
    for (RLMArray *array in allArrays) {
        uncheckedAssertEqualObjects([array valueForKeyPath:@"@unionOfObjects.self"], @[]);
    }
    for (RLMArray *array in allArrays) {
        uncheckedAssertEqualObjects([array valueForKeyPath:@"@distinctUnionOfObjects.self"], @[]);
    }

    [self addObjects];
    [self addObjects];

    uncheckedAssertEqualObjects([unmanaged.boolObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@NO, @YES, @NO, @YES]));
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2, @3, @2, @3]));
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2f, @3.3f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2, @3.3, @2.2, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@"a", @"b", @"a", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.dataObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[data(1), data(2), data(1), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[date(1), date(2), date(1), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.objectIdObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[objectId(1), objectId(2), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.uuidObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([unmanaged.anyBoolObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@NO, @YES, @NO, @YES]));
    uncheckedAssertEqualObjects([unmanaged.anyIntObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2, @3, @2, @3]));
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2f, @3.3f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2, @3.3, @2.2, @3.3]));
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@"a", @"b", @"a", @"b"]));
    uncheckedAssertEqualObjects([unmanaged.anyDataObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[data(1), data(2), data(1), data(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[date(1), date(2), date(1), date(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([unmanaged.anyObjectIdObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[objectId(1), objectId(2), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([unmanaged.anyUUIDObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optUnmanaged.boolObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@NO, @YES, NSNull.null, @NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2, @3, NSNull.null, @2, @3, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2f, @3.3f, NSNull.null, @2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2, @3.3, NSNull.null, @2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@"a", @"b", NSNull.null, @"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.dataObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[data(1), data(2), NSNull.null, data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[date(1), date(2), NSNull.null, date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[decimal128(2), decimal128(3), NSNull.null, decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.objectIdObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[objectId(1), objectId(2), NSNull.null, objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects([optUnmanaged.uuidObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null, uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    uncheckedAssertEqualObjects([managed.boolObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@NO, @YES, @NO, @YES]));
    uncheckedAssertEqualObjects([managed.intObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2, @3, @2, @3]));
    uncheckedAssertEqualObjects([managed.floatObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2f, @3.3f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([managed.doubleObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2, @3.3, @2.2, @3.3]));
    uncheckedAssertEqualObjects([managed.stringObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@"a", @"b", @"a", @"b"]));
    uncheckedAssertEqualObjects([managed.dataObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[data(1), data(2), data(1), data(2)]));
    uncheckedAssertEqualObjects([managed.dateObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[date(1), date(2), date(1), date(2)]));
    uncheckedAssertEqualObjects([managed.decimalObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.objectIdObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[objectId(1), objectId(2), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([managed.uuidObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([managed.anyBoolObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@NO, @YES, @NO, @YES]));
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2, @3, @2, @3]));
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2f, @3.3f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2, @3.3, @2.2, @3.3]));
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@"a", @"b", @"a", @"b"]));
    uncheckedAssertEqualObjects([managed.anyDataObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[data(1), data(2), data(1), data(2)]));
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[date(1), date(2), date(1), date(2)]));
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([managed.anyObjectIdObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[objectId(1), objectId(2), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([managed.anyUUIDObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([optManaged.boolObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@NO, @YES, NSNull.null, @NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.intObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2, @3, NSNull.null, @2, @3, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2f, @3.3f, NSNull.null, @2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@2.2, @3.3, NSNull.null, @2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[@"a", @"b", NSNull.null, @"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.dataObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[data(1), data(2), NSNull.null, data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[date(1), date(2), NSNull.null, date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[decimal128(2), decimal128(3), NSNull.null, decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.objectIdObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[objectId(1), objectId(2), NSNull.null, objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects([optManaged.uuidObj valueForKeyPath:@"@unionOfObjects.self"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null, uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.boolObj, @"Objects", @"self"),
                                (@[@NO, @YES]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.intObj, @"Objects", @"self"),
                                (@[@2, @3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.floatObj, @"Objects", @"self"),
                                (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.doubleObj, @"Objects", @"self"),
                                (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.stringObj, @"Objects", @"self"),
                                (@[@"a", @"b"]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.dataObj, @"Objects", @"self"),
                                (@[data(1), data(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.dateObj, @"Objects", @"self"),
                                (@[date(1), date(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.decimalObj, @"Objects", @"self"),
                                (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.objectIdObj, @"Objects", @"self"),
                                (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.uuidObj, @"Objects", @"self"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyBoolObj, @"Objects", @"self"),
                                (@[@NO, @YES]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyIntObj, @"Objects", @"self"),
                                (@[@2, @3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyFloatObj, @"Objects", @"self"),
                                (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyDoubleObj, @"Objects", @"self"),
                                (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyStringObj, @"Objects", @"self"),
                                (@[@"a", @"b"]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyDataObj, @"Objects", @"self"),
                                (@[data(1), data(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyDateObj, @"Objects", @"self"),
                                (@[date(1), date(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyDecimalObj, @"Objects", @"self"),
                                (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyObjectIdObj, @"Objects", @"self"),
                                (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(unmanaged.anyUUIDObj, @"Objects", @"self"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.boolObj, @"Objects", @"self"),
                                (@[@NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.intObj, @"Objects", @"self"),
                                (@[@2, @3, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.floatObj, @"Objects", @"self"),
                                (@[@2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.doubleObj, @"Objects", @"self"),
                                (@[@2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.stringObj, @"Objects", @"self"),
                                (@[@"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.dataObj, @"Objects", @"self"),
                                (@[data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.dateObj, @"Objects", @"self"),
                                (@[date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.decimalObj, @"Objects", @"self"),
                                (@[decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.objectIdObj, @"Objects", @"self"),
                                (@[objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optUnmanaged.uuidObj, @"Objects", @"self"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.boolObj, @"Objects", @"self"),
                                (@[@NO, @YES]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.intObj, @"Objects", @"self"),
                                (@[@2, @3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.floatObj, @"Objects", @"self"),
                                (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.doubleObj, @"Objects", @"self"),
                                (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.stringObj, @"Objects", @"self"),
                                (@[@"a", @"b"]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.dataObj, @"Objects", @"self"),
                                (@[data(1), data(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.dateObj, @"Objects", @"self"),
                                (@[date(1), date(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.decimalObj, @"Objects", @"self"),
                                (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.objectIdObj, @"Objects", @"self"),
                                (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.uuidObj, @"Objects", @"self"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyBoolObj, @"Objects", @"self"),
                                (@[@NO, @YES]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyIntObj, @"Objects", @"self"),
                                (@[@2, @3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyFloatObj, @"Objects", @"self"),
                                (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyDoubleObj, @"Objects", @"self"),
                                (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyStringObj, @"Objects", @"self"),
                                (@[@"a", @"b"]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyDataObj, @"Objects", @"self"),
                                (@[data(1), data(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyDateObj, @"Objects", @"self"),
                                (@[date(1), date(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyDecimalObj, @"Objects", @"self"),
                                (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyObjectIdObj, @"Objects", @"self"),
                                (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(managed.anyUUIDObj, @"Objects", @"self"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.boolObj, @"Objects", @"self"),
                                (@[@NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.intObj, @"Objects", @"self"),
                                (@[@2, @3, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.floatObj, @"Objects", @"self"),
                                (@[@2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.doubleObj, @"Objects", @"self"),
                                (@[@2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.stringObj, @"Objects", @"self"),
                                (@[@"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.dataObj, @"Objects", @"self"),
                                (@[data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.dateObj, @"Objects", @"self"),
                                (@[date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.decimalObj, @"Objects", @"self"),
                                (@[decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.objectIdObj, @"Objects", @"self"),
                                (@[objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(optManaged.uuidObj, @"Objects", @"self"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
}

- (void)testUnionOfArrays {
    RLMResults *allRequired = [AllPrimitiveArrays allObjectsInRealm:realm];
    RLMResults *allOptional = [AllOptionalPrimitiveArrays allObjectsInRealm:realm];

    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.boolObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.intObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.floatObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.doubleObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.stringObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.dataObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.dateObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.decimalObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.objectIdObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.uuidObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.boolObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.intObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.floatObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.doubleObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.stringObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.dataObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.dateObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.decimalObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.objectIdObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.uuidObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.boolObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.intObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.floatObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.doubleObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.stringObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.dataObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.dateObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.decimalObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.objectIdObj"], @[]);
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.uuidObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.boolObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.intObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.floatObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.doubleObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.stringObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.dataObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.dateObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.decimalObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.objectIdObj"], @[]);
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@distinctUnionOfArrays.uuidObj"], @[]);

    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyBoolObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyIntObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyFloatObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDoubleObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyStringObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDataObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDateObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDecimalObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyObjectIdObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyUUIDObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyBoolObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyIntObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyFloatObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyDoubleObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyStringObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyDataObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyDateObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyDecimalObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyObjectIdObj"], @[]);
    XCTAssertEqualObjects([allRequired valueForKeyPath:@"@distinctUnionOfArrays.anyUUIDObj"], @[]);


    [self addObjects];

    [AllPrimitiveArrays createInRealm:realm withValue:managed];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:optManaged];

    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.boolObj"],
                                (@[@NO, @YES, @NO, @YES]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.intObj"],
                                (@[@2, @3, @2, @3]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.floatObj"],
                                (@[@2.2f, @3.3f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.doubleObj"],
                                (@[@2.2, @3.3, @2.2, @3.3]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.stringObj"],
                                (@[@"a", @"b", @"a", @"b"]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.dataObj"],
                                (@[data(1), data(2), data(1), data(2)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.dateObj"],
                                (@[date(1), date(2), date(1), date(2)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.decimalObj"],
                                (@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.objectIdObj"],
                                (@[objectId(1), objectId(2), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.uuidObj"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.boolObj"],
                                (@[@NO, @YES, NSNull.null, @NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.intObj"],
                                (@[@2, @3, NSNull.null, @2, @3, NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.floatObj"],
                                (@[@2.2f, @3.3f, NSNull.null, @2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.doubleObj"],
                                (@[@2.2, @3.3, NSNull.null, @2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.stringObj"],
                                (@[@"a", @"b", NSNull.null, @"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.dataObj"],
                                (@[data(1), data(2), NSNull.null, data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.dateObj"],
                                (@[date(1), date(2), NSNull.null, date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.decimalObj"],
                                (@[decimal128(2), decimal128(3), NSNull.null, decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.objectIdObj"],
                                (@[objectId(1), objectId(2), NSNull.null, objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects([allOptional valueForKeyPath:@"@unionOfArrays.uuidObj"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null, uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"boolObj"),
                                (@[@NO, @YES]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"intObj"),
                                (@[@2, @3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"floatObj"),
                                (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"doubleObj"),
                                (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"stringObj"),
                                (@[@"a", @"b"]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"dataObj"),
                                (@[data(1), data(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"dateObj"),
                                (@[date(1), date(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"decimalObj"),
                                (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"objectIdObj"),
                                (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"uuidObj"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"boolObj"),
                                (@[@NO, @YES, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"intObj"),
                                (@[@2, @3, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"floatObj"),
                                (@[@2.2f, @3.3f, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"doubleObj"),
                                (@[@2.2, @3.3, NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"stringObj"),
                                (@[@"a", @"b", NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"dataObj"),
                                (@[data(1), data(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"dateObj"),
                                (@[date(1), date(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"decimalObj"),
                                (@[decimal128(2), decimal128(3), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"objectIdObj"),
                                (@[objectId(1), objectId(2), NSNull.null]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allOptional, @"Arrays", @"uuidObj"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));

    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyBoolObj"],
                                (@[@NO, @YES, @NO, @YES]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyIntObj"],
                                (@[@2, @3, @2, @3]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyFloatObj"],
                                (@[@2.2f, @3.3f, @2.2f, @3.3f]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDoubleObj"],
                                (@[@2.2, @3.3, @2.2, @3.3]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyStringObj"],
                                (@[@"a", @"b", @"a", @"b"]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDataObj"],
                                (@[data(1), data(2), data(1), data(2)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDateObj"],
                                (@[date(1), date(2), date(1), date(2)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyDecimalObj"],
                                (@[decimal128(2), decimal128(3), decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyObjectIdObj"],
                                (@[objectId(1), objectId(2), objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects([allRequired valueForKeyPath:@"@unionOfArrays.anyUUIDObj"],
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyBoolObj"),
                                (@[@NO, @YES]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyIntObj"),
                                (@[@2, @3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyFloatObj"),
                                (@[@2.2f, @3.3f]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyDoubleObj"),
                                (@[@2.2, @3.3]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyStringObj"),
                                (@[@"a", @"b"]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyDataObj"),
                                (@[data(1), data(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyDateObj"),
                                (@[date(1), date(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyDecimalObj"),
                                (@[decimal128(2), decimal128(3)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyObjectIdObj"),
                                (@[objectId(1), objectId(2)]));
    uncheckedAssertEqualObjects(sortedDistinctUnion(allRequired, @"Arrays", @"anyUUIDObj"),
                                (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
}

- (void)testSetValueForKey {
    for (RLMArray *array in allArrays) {
        RLMAssertThrowsWithReason([array setValue:@0 forKey:@"not self"],
                                  @"this class is not key value coding-compliant for the key not self.");
    }
    RLMAssertThrowsWithReason([unmanaged.boolObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj setValue:@2 forKey:@"self"],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optUnmanaged.boolObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optUnmanaged.intObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optUnmanaged.floatObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optUnmanaged.doubleObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optUnmanaged.stringObj setValue:@2 forKey:@"self"],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optUnmanaged.dataObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optUnmanaged.dateObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optUnmanaged.decimalObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optUnmanaged.objectIdObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optUnmanaged.uuidObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([managed.boolObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj setValue:@2 forKey:@"self"],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid'");
    RLMAssertThrowsWithReason([optManaged.boolObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'bool?'");
    RLMAssertThrowsWithReason([optManaged.intObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'int?'");
    RLMAssertThrowsWithReason([optManaged.floatObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'float?'");
    RLMAssertThrowsWithReason([optManaged.doubleObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'double?'");
    RLMAssertThrowsWithReason([optManaged.stringObj setValue:@2 forKey:@"self"],
                              @"Invalid value '2' of type '" RLMConstantInt "' for expected type 'string?'");
    RLMAssertThrowsWithReason([optManaged.dataObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'data?'");
    RLMAssertThrowsWithReason([optManaged.dateObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'date?'");
    RLMAssertThrowsWithReason([optManaged.decimalObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'decimal128?'");
    RLMAssertThrowsWithReason([optManaged.objectIdObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'object id?'");
    RLMAssertThrowsWithReason([optManaged.uuidObj setValue:@"a" forKey:@"self"],
                              @"Invalid value 'a' of type '" RLMConstantString "' for expected type 'uuid?'");
    RLMAssertThrowsWithReason([unmanaged.boolObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([unmanaged.intObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([unmanaged.floatObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([unmanaged.doubleObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([unmanaged.stringObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([unmanaged.dataObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([unmanaged.dateObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([unmanaged.decimalObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([unmanaged.objectIdObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([unmanaged.uuidObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");
    RLMAssertThrowsWithReason([managed.boolObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'bool'");
    RLMAssertThrowsWithReason([managed.intObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'int'");
    RLMAssertThrowsWithReason([managed.floatObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'float'");
    RLMAssertThrowsWithReason([managed.doubleObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'double'");
    RLMAssertThrowsWithReason([managed.stringObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'string'");
    RLMAssertThrowsWithReason([managed.dataObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'data'");
    RLMAssertThrowsWithReason([managed.dateObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'date'");
    RLMAssertThrowsWithReason([managed.decimalObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'decimal128'");
    RLMAssertThrowsWithReason([managed.objectIdObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'object id'");
    RLMAssertThrowsWithReason([managed.uuidObj setValue:NSNull.null forKey:@"self"],
                              @"Invalid value '<null>' of type 'NSNull' for expected type 'uuid'");

    [self addObjects];

    [unmanaged.boolObj setValue:@NO forKey:@"self"];
    [unmanaged.intObj setValue:@2 forKey:@"self"];
    [unmanaged.floatObj setValue:@2.2f forKey:@"self"];
    [unmanaged.doubleObj setValue:@2.2 forKey:@"self"];
    [unmanaged.stringObj setValue:@"a" forKey:@"self"];
    [unmanaged.dataObj setValue:data(1) forKey:@"self"];
    [unmanaged.dateObj setValue:date(1) forKey:@"self"];
    [unmanaged.decimalObj setValue:decimal128(2) forKey:@"self"];
    [unmanaged.objectIdObj setValue:objectId(1) forKey:@"self"];
    [unmanaged.uuidObj setValue:uuid(@"00000000-0000-0000-0000-000000000000") forKey:@"self"];
    [unmanaged.anyBoolObj setValue:@NO forKey:@"self"];
    [unmanaged.anyIntObj setValue:@2 forKey:@"self"];
    [unmanaged.anyFloatObj setValue:@2.2f forKey:@"self"];
    [unmanaged.anyDoubleObj setValue:@2.2 forKey:@"self"];
    [unmanaged.anyStringObj setValue:@"a" forKey:@"self"];
    [unmanaged.anyDataObj setValue:data(1) forKey:@"self"];
    [unmanaged.anyDateObj setValue:date(1) forKey:@"self"];
    [unmanaged.anyDecimalObj setValue:decimal128(2) forKey:@"self"];
    [unmanaged.anyObjectIdObj setValue:objectId(1) forKey:@"self"];
    [unmanaged.anyUUIDObj setValue:uuid(@"00000000-0000-0000-0000-000000000000") forKey:@"self"];
    [optUnmanaged.boolObj setValue:@NO forKey:@"self"];
    [optUnmanaged.intObj setValue:@2 forKey:@"self"];
    [optUnmanaged.floatObj setValue:@2.2f forKey:@"self"];
    [optUnmanaged.doubleObj setValue:@2.2 forKey:@"self"];
    [optUnmanaged.stringObj setValue:@"a" forKey:@"self"];
    [optUnmanaged.dataObj setValue:data(1) forKey:@"self"];
    [optUnmanaged.dateObj setValue:date(1) forKey:@"self"];
    [optUnmanaged.decimalObj setValue:decimal128(2) forKey:@"self"];
    [optUnmanaged.objectIdObj setValue:objectId(1) forKey:@"self"];
    [optUnmanaged.uuidObj setValue:uuid(@"00000000-0000-0000-0000-000000000000") forKey:@"self"];
    [managed.boolObj setValue:@NO forKey:@"self"];
    [managed.intObj setValue:@2 forKey:@"self"];
    [managed.floatObj setValue:@2.2f forKey:@"self"];
    [managed.doubleObj setValue:@2.2 forKey:@"self"];
    [managed.stringObj setValue:@"a" forKey:@"self"];
    [managed.dataObj setValue:data(1) forKey:@"self"];
    [managed.dateObj setValue:date(1) forKey:@"self"];
    [managed.decimalObj setValue:decimal128(2) forKey:@"self"];
    [managed.objectIdObj setValue:objectId(1) forKey:@"self"];
    [managed.uuidObj setValue:uuid(@"00000000-0000-0000-0000-000000000000") forKey:@"self"];
    [managed.anyBoolObj setValue:@NO forKey:@"self"];
    [managed.anyIntObj setValue:@2 forKey:@"self"];
    [managed.anyFloatObj setValue:@2.2f forKey:@"self"];
    [managed.anyDoubleObj setValue:@2.2 forKey:@"self"];
    [managed.anyStringObj setValue:@"a" forKey:@"self"];
    [managed.anyDataObj setValue:data(1) forKey:@"self"];
    [managed.anyDateObj setValue:date(1) forKey:@"self"];
    [managed.anyDecimalObj setValue:decimal128(2) forKey:@"self"];
    [managed.anyObjectIdObj setValue:objectId(1) forKey:@"self"];
    [managed.anyUUIDObj setValue:uuid(@"00000000-0000-0000-0000-000000000000") forKey:@"self"];
    [optManaged.boolObj setValue:@NO forKey:@"self"];
    [optManaged.intObj setValue:@2 forKey:@"self"];
    [optManaged.floatObj setValue:@2.2f forKey:@"self"];
    [optManaged.doubleObj setValue:@2.2 forKey:@"self"];
    [optManaged.stringObj setValue:@"a" forKey:@"self"];
    [optManaged.dataObj setValue:data(1) forKey:@"self"];
    [optManaged.dateObj setValue:date(1) forKey:@"self"];
    [optManaged.decimalObj setValue:decimal128(2) forKey:@"self"];
    [optManaged.objectIdObj setValue:objectId(1) forKey:@"self"];
    [optManaged.uuidObj setValue:uuid(@"00000000-0000-0000-0000-000000000000") forKey:@"self"];

    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.intObj[0], @2);
    uncheckedAssertEqualObjects(managed.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[0], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.boolObj[1], @NO);
    uncheckedAssertEqualObjects(unmanaged.intObj[1], @2);
    uncheckedAssertEqualObjects(unmanaged.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(unmanaged.stringObj[1], @"a");
    uncheckedAssertEqualObjects(unmanaged.dataObj[1], data(1));
    uncheckedAssertEqualObjects(unmanaged.dateObj[1], date(1));
    uncheckedAssertEqualObjects(unmanaged.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[1], @NO);
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[1], @2);
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[1], @2.2f);
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[1], @2.2);
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[1], @"a");
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[1], data(1));
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[1], date(1));
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[1], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[1], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[1], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[1], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[1], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.boolObj[1], @NO);
    uncheckedAssertEqualObjects(managed.intObj[1], @2);
    uncheckedAssertEqualObjects(managed.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(managed.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(managed.stringObj[1], @"a");
    uncheckedAssertEqualObjects(managed.dataObj[1], data(1));
    uncheckedAssertEqualObjects(managed.dateObj[1], date(1));
    uncheckedAssertEqualObjects(managed.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(managed.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(managed.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(managed.anyBoolObj[1], @NO);
    uncheckedAssertEqualObjects(managed.anyIntObj[1], @2);
    uncheckedAssertEqualObjects(managed.anyFloatObj[1], @2.2f);
    uncheckedAssertEqualObjects(managed.anyDoubleObj[1], @2.2);
    uncheckedAssertEqualObjects(managed.anyStringObj[1], @"a");
    uncheckedAssertEqualObjects(managed.anyDataObj[1], data(1));
    uncheckedAssertEqualObjects(managed.anyDateObj[1], date(1));
    uncheckedAssertEqualObjects(managed.anyDecimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(managed.anyUUIDObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[1], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[1], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[1], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[1], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[1], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[1], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[1], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[1], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[1], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[1], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[2], @NO);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[2], @2);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[2], @2.2f);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[2], @2.2);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[2], @"a");
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[2], data(1));
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[2], date(1));
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[2], decimal128(2));
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[2], objectId(1));
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[2], uuid(@"00000000-0000-0000-0000-000000000000"));
    uncheckedAssertEqualObjects(optManaged.boolObj[2], @NO);
    uncheckedAssertEqualObjects(optManaged.intObj[2], @2);
    uncheckedAssertEqualObjects(optManaged.floatObj[2], @2.2f);
    uncheckedAssertEqualObjects(optManaged.doubleObj[2], @2.2);
    uncheckedAssertEqualObjects(optManaged.stringObj[2], @"a");
    uncheckedAssertEqualObjects(optManaged.dataObj[2], data(1));
    uncheckedAssertEqualObjects(optManaged.dateObj[2], date(1));
    uncheckedAssertEqualObjects(optManaged.decimalObj[2], decimal128(2));
    uncheckedAssertEqualObjects(optManaged.objectIdObj[2], objectId(1));
    uncheckedAssertEqualObjects(optManaged.uuidObj[2], uuid(@"00000000-0000-0000-0000-000000000000"));

    [optUnmanaged.boolObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.intObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.floatObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.doubleObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.stringObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.dataObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.dateObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.decimalObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.objectIdObj setValue:NSNull.null forKey:@"self"];
    [optUnmanaged.uuidObj setValue:NSNull.null forKey:@"self"];
    [optManaged.boolObj setValue:NSNull.null forKey:@"self"];
    [optManaged.intObj setValue:NSNull.null forKey:@"self"];
    [optManaged.floatObj setValue:NSNull.null forKey:@"self"];
    [optManaged.doubleObj setValue:NSNull.null forKey:@"self"];
    [optManaged.stringObj setValue:NSNull.null forKey:@"self"];
    [optManaged.dataObj setValue:NSNull.null forKey:@"self"];
    [optManaged.dateObj setValue:NSNull.null forKey:@"self"];
    [optManaged.decimalObj setValue:NSNull.null forKey:@"self"];
    [optManaged.objectIdObj setValue:NSNull.null forKey:@"self"];
    [optManaged.uuidObj setValue:NSNull.null forKey:@"self"];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.boolObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.intObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.floatObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.stringObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dataObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.dateObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], NSNull.null);
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], NSNull.null);
}

- (void)testAssignment {
    unmanaged.boolObj = (id)@[@YES];
    uncheckedAssertEqualObjects(unmanaged.boolObj[0], @YES);
    unmanaged.intObj = (id)@[@3];
    uncheckedAssertEqualObjects(unmanaged.intObj[0], @3);
    unmanaged.floatObj = (id)@[@3.3f];
    uncheckedAssertEqualObjects(unmanaged.floatObj[0], @3.3f);
    unmanaged.doubleObj = (id)@[@3.3];
    uncheckedAssertEqualObjects(unmanaged.doubleObj[0], @3.3);
    unmanaged.stringObj = (id)@[@"b"];
    uncheckedAssertEqualObjects(unmanaged.stringObj[0], @"b");
    unmanaged.dataObj = (id)@[data(2)];
    uncheckedAssertEqualObjects(unmanaged.dataObj[0], data(2));
    unmanaged.dateObj = (id)@[date(2)];
    uncheckedAssertEqualObjects(unmanaged.dateObj[0], date(2));
    unmanaged.decimalObj = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(unmanaged.decimalObj[0], decimal128(3));
    unmanaged.objectIdObj = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(unmanaged.objectIdObj[0], objectId(2));
    unmanaged.uuidObj = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(unmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    unmanaged.anyBoolObj = (id)@[@YES];
    uncheckedAssertEqualObjects(unmanaged.anyBoolObj[0], @YES);
    unmanaged.anyIntObj = (id)@[@3];
    uncheckedAssertEqualObjects(unmanaged.anyIntObj[0], @3);
    unmanaged.anyFloatObj = (id)@[@3.3f];
    uncheckedAssertEqualObjects(unmanaged.anyFloatObj[0], @3.3f);
    unmanaged.anyDoubleObj = (id)@[@3.3];
    uncheckedAssertEqualObjects(unmanaged.anyDoubleObj[0], @3.3);
    unmanaged.anyStringObj = (id)@[@"b"];
    uncheckedAssertEqualObjects(unmanaged.anyStringObj[0], @"b");
    unmanaged.anyDataObj = (id)@[data(2)];
    uncheckedAssertEqualObjects(unmanaged.anyDataObj[0], data(2));
    unmanaged.anyDateObj = (id)@[date(2)];
    uncheckedAssertEqualObjects(unmanaged.anyDateObj[0], date(2));
    unmanaged.anyDecimalObj = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(unmanaged.anyDecimalObj[0], decimal128(3));
    unmanaged.anyObjectIdObj = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(unmanaged.anyObjectIdObj[0], objectId(2));
    unmanaged.anyUUIDObj = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(unmanaged.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    optUnmanaged.boolObj = (id)@[@YES];
    uncheckedAssertEqualObjects(optUnmanaged.boolObj[0], @YES);
    optUnmanaged.intObj = (id)@[@3];
    uncheckedAssertEqualObjects(optUnmanaged.intObj[0], @3);
    optUnmanaged.floatObj = (id)@[@3.3f];
    uncheckedAssertEqualObjects(optUnmanaged.floatObj[0], @3.3f);
    optUnmanaged.doubleObj = (id)@[@3.3];
    uncheckedAssertEqualObjects(optUnmanaged.doubleObj[0], @3.3);
    optUnmanaged.stringObj = (id)@[@"b"];
    uncheckedAssertEqualObjects(optUnmanaged.stringObj[0], @"b");
    optUnmanaged.dataObj = (id)@[data(2)];
    uncheckedAssertEqualObjects(optUnmanaged.dataObj[0], data(2));
    optUnmanaged.dateObj = (id)@[date(2)];
    uncheckedAssertEqualObjects(optUnmanaged.dateObj[0], date(2));
    optUnmanaged.decimalObj = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(optUnmanaged.decimalObj[0], decimal128(3));
    optUnmanaged.objectIdObj = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(optUnmanaged.objectIdObj[0], objectId(2));
    optUnmanaged.uuidObj = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(optUnmanaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    managed.boolObj = (id)@[@YES];
    uncheckedAssertEqualObjects(managed.boolObj[0], @YES);
    managed.intObj = (id)@[@3];
    uncheckedAssertEqualObjects(managed.intObj[0], @3);
    managed.floatObj = (id)@[@3.3f];
    uncheckedAssertEqualObjects(managed.floatObj[0], @3.3f);
    managed.doubleObj = (id)@[@3.3];
    uncheckedAssertEqualObjects(managed.doubleObj[0], @3.3);
    managed.stringObj = (id)@[@"b"];
    uncheckedAssertEqualObjects(managed.stringObj[0], @"b");
    managed.dataObj = (id)@[data(2)];
    uncheckedAssertEqualObjects(managed.dataObj[0], data(2));
    managed.dateObj = (id)@[date(2)];
    uncheckedAssertEqualObjects(managed.dateObj[0], date(2));
    managed.decimalObj = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(managed.decimalObj[0], decimal128(3));
    managed.objectIdObj = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(managed.objectIdObj[0], objectId(2));
    managed.uuidObj = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(managed.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    managed.anyBoolObj = (id)@[@YES];
    uncheckedAssertEqualObjects(managed.anyBoolObj[0], @YES);
    managed.anyIntObj = (id)@[@3];
    uncheckedAssertEqualObjects(managed.anyIntObj[0], @3);
    managed.anyFloatObj = (id)@[@3.3f];
    uncheckedAssertEqualObjects(managed.anyFloatObj[0], @3.3f);
    managed.anyDoubleObj = (id)@[@3.3];
    uncheckedAssertEqualObjects(managed.anyDoubleObj[0], @3.3);
    managed.anyStringObj = (id)@[@"b"];
    uncheckedAssertEqualObjects(managed.anyStringObj[0], @"b");
    managed.anyDataObj = (id)@[data(2)];
    uncheckedAssertEqualObjects(managed.anyDataObj[0], data(2));
    managed.anyDateObj = (id)@[date(2)];
    uncheckedAssertEqualObjects(managed.anyDateObj[0], date(2));
    managed.anyDecimalObj = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(managed.anyDecimalObj[0], decimal128(3));
    managed.anyObjectIdObj = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(managed.anyObjectIdObj[0], objectId(2));
    managed.anyUUIDObj = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(managed.anyUUIDObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    optManaged.boolObj = (id)@[@YES];
    uncheckedAssertEqualObjects(optManaged.boolObj[0], @YES);
    optManaged.intObj = (id)@[@3];
    uncheckedAssertEqualObjects(optManaged.intObj[0], @3);
    optManaged.floatObj = (id)@[@3.3f];
    uncheckedAssertEqualObjects(optManaged.floatObj[0], @3.3f);
    optManaged.doubleObj = (id)@[@3.3];
    uncheckedAssertEqualObjects(optManaged.doubleObj[0], @3.3);
    optManaged.stringObj = (id)@[@"b"];
    uncheckedAssertEqualObjects(optManaged.stringObj[0], @"b");
    optManaged.dataObj = (id)@[data(2)];
    uncheckedAssertEqualObjects(optManaged.dataObj[0], data(2));
    optManaged.dateObj = (id)@[date(2)];
    uncheckedAssertEqualObjects(optManaged.dateObj[0], date(2));
    optManaged.decimalObj = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(optManaged.decimalObj[0], decimal128(3));
    optManaged.objectIdObj = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(optManaged.objectIdObj[0], objectId(2));
    optManaged.uuidObj = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(optManaged.uuidObj[0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));

    // Should replace and not append
    unmanaged.boolObj = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([unmanaged.boolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged.intObj = (id)@[@2, @3];
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged.floatObj = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged.doubleObj = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged.stringObj = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged.dataObj = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([unmanaged.dataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged.dateObj = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged.decimalObj = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged.objectIdObj = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([unmanaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged.uuidObj = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([unmanaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    unmanaged.anyBoolObj = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([unmanaged.anyBoolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged.anyIntObj = (id)@[@2, @3];
    uncheckedAssertEqualObjects([unmanaged.anyIntObj valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged.anyFloatObj = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged.anyDoubleObj = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged.anyStringObj = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged.anyDataObj = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([unmanaged.anyDataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged.anyDateObj = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged.anyDecimalObj = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged.anyObjectIdObj = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([unmanaged.anyObjectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged.anyUUIDObj = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([unmanaged.anyUUIDObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optUnmanaged.boolObj = (id)@[@NO, @YES, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.boolObj valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optUnmanaged.intObj = (id)@[@2, @3, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optUnmanaged.floatObj = (id)@[@2.2f, @3.3f, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optUnmanaged.doubleObj = (id)@[@2.2, @3.3, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optUnmanaged.stringObj = (id)@[@"a", @"b", NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optUnmanaged.dataObj = (id)@[data(1), data(2), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.dataObj valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optUnmanaged.dateObj = (id)@[date(1), date(2), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optUnmanaged.decimalObj = (id)@[decimal128(2), decimal128(3), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optUnmanaged.objectIdObj = (id)@[objectId(1), objectId(2), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optUnmanaged.uuidObj = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    
    managed.boolObj = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([managed.boolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    managed.intObj = (id)@[@2, @3];
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"], (@[@2, @3]));
    
    managed.floatObj = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([managed.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed.doubleObj = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([managed.doubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed.stringObj = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([managed.stringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed.dataObj = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([managed.dataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed.dateObj = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([managed.dateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed.decimalObj = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([managed.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed.objectIdObj = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([managed.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed.uuidObj = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([managed.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    managed.anyBoolObj = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([managed.anyBoolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    managed.anyIntObj = (id)@[@2, @3];
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKey:@"self"], (@[@2, @3]));
    
    managed.anyFloatObj = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed.anyDoubleObj = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed.anyStringObj = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed.anyDataObj = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([managed.anyDataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed.anyDateObj = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed.anyDecimalObj = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed.anyObjectIdObj = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([managed.anyObjectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed.anyUUIDObj = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([managed.anyUUIDObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optManaged.boolObj = (id)@[@NO, @YES, NSNull.null];
    uncheckedAssertEqualObjects([optManaged.boolObj valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optManaged.intObj = (id)@[@2, @3, NSNull.null];
    uncheckedAssertEqualObjects([optManaged.intObj valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optManaged.floatObj = (id)@[@2.2f, @3.3f, NSNull.null];
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optManaged.doubleObj = (id)@[@2.2, @3.3, NSNull.null];
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optManaged.stringObj = (id)@[@"a", @"b", NSNull.null];
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optManaged.dataObj = (id)@[data(1), data(2), NSNull.null];
    uncheckedAssertEqualObjects([optManaged.dataObj valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optManaged.dateObj = (id)@[date(1), date(2), NSNull.null];
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optManaged.decimalObj = (id)@[decimal128(2), decimal128(3), NSNull.null];
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optManaged.objectIdObj = (id)@[objectId(1), objectId(2), NSNull.null];
    uncheckedAssertEqualObjects([optManaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optManaged.uuidObj = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null];
    uncheckedAssertEqualObjects([optManaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    

    // Should not clear the array
    unmanaged.boolObj = unmanaged.boolObj;
    uncheckedAssertEqualObjects([unmanaged.boolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged.intObj = unmanaged.intObj;
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged.floatObj = unmanaged.floatObj;
    uncheckedAssertEqualObjects([unmanaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged.doubleObj = unmanaged.doubleObj;
    uncheckedAssertEqualObjects([unmanaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged.stringObj = unmanaged.stringObj;
    uncheckedAssertEqualObjects([unmanaged.stringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged.dataObj = unmanaged.dataObj;
    uncheckedAssertEqualObjects([unmanaged.dataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged.dateObj = unmanaged.dateObj;
    uncheckedAssertEqualObjects([unmanaged.dateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged.decimalObj = unmanaged.decimalObj;
    uncheckedAssertEqualObjects([unmanaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged.objectIdObj = unmanaged.objectIdObj;
    uncheckedAssertEqualObjects([unmanaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged.uuidObj = unmanaged.uuidObj;
    uncheckedAssertEqualObjects([unmanaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    unmanaged.anyBoolObj = unmanaged.anyBoolObj;
    uncheckedAssertEqualObjects([unmanaged.anyBoolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged.anyIntObj = unmanaged.anyIntObj;
    uncheckedAssertEqualObjects([unmanaged.anyIntObj valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged.anyFloatObj = unmanaged.anyFloatObj;
    uncheckedAssertEqualObjects([unmanaged.anyFloatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged.anyDoubleObj = unmanaged.anyDoubleObj;
    uncheckedAssertEqualObjects([unmanaged.anyDoubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged.anyStringObj = unmanaged.anyStringObj;
    uncheckedAssertEqualObjects([unmanaged.anyStringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged.anyDataObj = unmanaged.anyDataObj;
    uncheckedAssertEqualObjects([unmanaged.anyDataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged.anyDateObj = unmanaged.anyDateObj;
    uncheckedAssertEqualObjects([unmanaged.anyDateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged.anyDecimalObj = unmanaged.anyDecimalObj;
    uncheckedAssertEqualObjects([unmanaged.anyDecimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged.anyObjectIdObj = unmanaged.anyObjectIdObj;
    uncheckedAssertEqualObjects([unmanaged.anyObjectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged.anyUUIDObj = unmanaged.anyUUIDObj;
    uncheckedAssertEqualObjects([unmanaged.anyUUIDObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optUnmanaged.boolObj = optUnmanaged.boolObj;
    uncheckedAssertEqualObjects([optUnmanaged.boolObj valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optUnmanaged.intObj = optUnmanaged.intObj;
    uncheckedAssertEqualObjects([optUnmanaged.intObj valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optUnmanaged.floatObj = optUnmanaged.floatObj;
    uncheckedAssertEqualObjects([optUnmanaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optUnmanaged.doubleObj = optUnmanaged.doubleObj;
    uncheckedAssertEqualObjects([optUnmanaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optUnmanaged.stringObj = optUnmanaged.stringObj;
    uncheckedAssertEqualObjects([optUnmanaged.stringObj valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optUnmanaged.dataObj = optUnmanaged.dataObj;
    uncheckedAssertEqualObjects([optUnmanaged.dataObj valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optUnmanaged.dateObj = optUnmanaged.dateObj;
    uncheckedAssertEqualObjects([optUnmanaged.dateObj valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optUnmanaged.decimalObj = optUnmanaged.decimalObj;
    uncheckedAssertEqualObjects([optUnmanaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optUnmanaged.objectIdObj = optUnmanaged.objectIdObj;
    uncheckedAssertEqualObjects([optUnmanaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optUnmanaged.uuidObj = optUnmanaged.uuidObj;
    uncheckedAssertEqualObjects([optUnmanaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    
    managed.boolObj = managed.boolObj;
    uncheckedAssertEqualObjects([managed.boolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    managed.intObj = managed.intObj;
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"], (@[@2, @3]));
    
    managed.floatObj = managed.floatObj;
    uncheckedAssertEqualObjects([managed.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed.doubleObj = managed.doubleObj;
    uncheckedAssertEqualObjects([managed.doubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed.stringObj = managed.stringObj;
    uncheckedAssertEqualObjects([managed.stringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed.dataObj = managed.dataObj;
    uncheckedAssertEqualObjects([managed.dataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed.dateObj = managed.dateObj;
    uncheckedAssertEqualObjects([managed.dateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed.decimalObj = managed.decimalObj;
    uncheckedAssertEqualObjects([managed.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed.objectIdObj = managed.objectIdObj;
    uncheckedAssertEqualObjects([managed.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed.uuidObj = managed.uuidObj;
    uncheckedAssertEqualObjects([managed.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    managed.anyBoolObj = managed.anyBoolObj;
    uncheckedAssertEqualObjects([managed.anyBoolObj valueForKey:@"self"], (@[@NO, @YES]));
    
    managed.anyIntObj = managed.anyIntObj;
    uncheckedAssertEqualObjects([managed.anyIntObj valueForKey:@"self"], (@[@2, @3]));
    
    managed.anyFloatObj = managed.anyFloatObj;
    uncheckedAssertEqualObjects([managed.anyFloatObj valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed.anyDoubleObj = managed.anyDoubleObj;
    uncheckedAssertEqualObjects([managed.anyDoubleObj valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed.anyStringObj = managed.anyStringObj;
    uncheckedAssertEqualObjects([managed.anyStringObj valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed.anyDataObj = managed.anyDataObj;
    uncheckedAssertEqualObjects([managed.anyDataObj valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed.anyDateObj = managed.anyDateObj;
    uncheckedAssertEqualObjects([managed.anyDateObj valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed.anyDecimalObj = managed.anyDecimalObj;
    uncheckedAssertEqualObjects([managed.anyDecimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed.anyObjectIdObj = managed.anyObjectIdObj;
    uncheckedAssertEqualObjects([managed.anyObjectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed.anyUUIDObj = managed.anyUUIDObj;
    uncheckedAssertEqualObjects([managed.anyUUIDObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optManaged.boolObj = optManaged.boolObj;
    uncheckedAssertEqualObjects([optManaged.boolObj valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optManaged.intObj = optManaged.intObj;
    uncheckedAssertEqualObjects([optManaged.intObj valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optManaged.floatObj = optManaged.floatObj;
    uncheckedAssertEqualObjects([optManaged.floatObj valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optManaged.doubleObj = optManaged.doubleObj;
    uncheckedAssertEqualObjects([optManaged.doubleObj valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optManaged.stringObj = optManaged.stringObj;
    uncheckedAssertEqualObjects([optManaged.stringObj valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optManaged.dataObj = optManaged.dataObj;
    uncheckedAssertEqualObjects([optManaged.dataObj valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optManaged.dateObj = optManaged.dateObj;
    uncheckedAssertEqualObjects([optManaged.dateObj valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optManaged.decimalObj = optManaged.decimalObj;
    uncheckedAssertEqualObjects([optManaged.decimalObj valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optManaged.objectIdObj = optManaged.objectIdObj;
    uncheckedAssertEqualObjects([optManaged.objectIdObj valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optManaged.uuidObj = optManaged.uuidObj;
    uncheckedAssertEqualObjects([optManaged.uuidObj valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    

    [unmanaged.intObj removeAllObjects];
    unmanaged.intObj = managed.intObj;
    uncheckedAssertEqualObjects([unmanaged.intObj valueForKey:@"self"], (@[@2, @3]));

    [managed.intObj removeAllObjects];
    managed.intObj = unmanaged.intObj;
    uncheckedAssertEqualObjects([managed.intObj valueForKey:@"self"], (@[@2, @3]));
}

- (void)testDynamicAssignment {
    unmanaged[@"boolObj"] = (id)@[@YES];
    uncheckedAssertEqualObjects(unmanaged[@"boolObj"][0], @YES);
    unmanaged[@"intObj"] = (id)@[@3];
    uncheckedAssertEqualObjects(unmanaged[@"intObj"][0], @3);
    unmanaged[@"floatObj"] = (id)@[@3.3f];
    uncheckedAssertEqualObjects(unmanaged[@"floatObj"][0], @3.3f);
    unmanaged[@"doubleObj"] = (id)@[@3.3];
    uncheckedAssertEqualObjects(unmanaged[@"doubleObj"][0], @3.3);
    unmanaged[@"stringObj"] = (id)@[@"b"];
    uncheckedAssertEqualObjects(unmanaged[@"stringObj"][0], @"b");
    unmanaged[@"dataObj"] = (id)@[data(2)];
    uncheckedAssertEqualObjects(unmanaged[@"dataObj"][0], data(2));
    unmanaged[@"dateObj"] = (id)@[date(2)];
    uncheckedAssertEqualObjects(unmanaged[@"dateObj"][0], date(2));
    unmanaged[@"decimalObj"] = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(unmanaged[@"decimalObj"][0], decimal128(3));
    unmanaged[@"objectIdObj"] = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(unmanaged[@"objectIdObj"][0], objectId(2));
    unmanaged[@"uuidObj"] = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(unmanaged[@"uuidObj"][0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    unmanaged[@"anyBoolObj"] = (id)@[@YES];
    uncheckedAssertEqualObjects(unmanaged[@"anyBoolObj"][0], @YES);
    unmanaged[@"anyIntObj"] = (id)@[@3];
    uncheckedAssertEqualObjects(unmanaged[@"anyIntObj"][0], @3);
    unmanaged[@"anyFloatObj"] = (id)@[@3.3f];
    uncheckedAssertEqualObjects(unmanaged[@"anyFloatObj"][0], @3.3f);
    unmanaged[@"anyDoubleObj"] = (id)@[@3.3];
    uncheckedAssertEqualObjects(unmanaged[@"anyDoubleObj"][0], @3.3);
    unmanaged[@"anyStringObj"] = (id)@[@"b"];
    uncheckedAssertEqualObjects(unmanaged[@"anyStringObj"][0], @"b");
    unmanaged[@"anyDataObj"] = (id)@[data(2)];
    uncheckedAssertEqualObjects(unmanaged[@"anyDataObj"][0], data(2));
    unmanaged[@"anyDateObj"] = (id)@[date(2)];
    uncheckedAssertEqualObjects(unmanaged[@"anyDateObj"][0], date(2));
    unmanaged[@"anyDecimalObj"] = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(unmanaged[@"anyDecimalObj"][0], decimal128(3));
    unmanaged[@"anyObjectIdObj"] = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(unmanaged[@"anyObjectIdObj"][0], objectId(2));
    unmanaged[@"anyUUIDObj"] = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(unmanaged[@"anyUUIDObj"][0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    optUnmanaged[@"boolObj"] = (id)@[@YES];
    uncheckedAssertEqualObjects(optUnmanaged[@"boolObj"][0], @YES);
    optUnmanaged[@"intObj"] = (id)@[@3];
    uncheckedAssertEqualObjects(optUnmanaged[@"intObj"][0], @3);
    optUnmanaged[@"floatObj"] = (id)@[@3.3f];
    uncheckedAssertEqualObjects(optUnmanaged[@"floatObj"][0], @3.3f);
    optUnmanaged[@"doubleObj"] = (id)@[@3.3];
    uncheckedAssertEqualObjects(optUnmanaged[@"doubleObj"][0], @3.3);
    optUnmanaged[@"stringObj"] = (id)@[@"b"];
    uncheckedAssertEqualObjects(optUnmanaged[@"stringObj"][0], @"b");
    optUnmanaged[@"dataObj"] = (id)@[data(2)];
    uncheckedAssertEqualObjects(optUnmanaged[@"dataObj"][0], data(2));
    optUnmanaged[@"dateObj"] = (id)@[date(2)];
    uncheckedAssertEqualObjects(optUnmanaged[@"dateObj"][0], date(2));
    optUnmanaged[@"decimalObj"] = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(optUnmanaged[@"decimalObj"][0], decimal128(3));
    optUnmanaged[@"objectIdObj"] = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(optUnmanaged[@"objectIdObj"][0], objectId(2));
    optUnmanaged[@"uuidObj"] = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(optUnmanaged[@"uuidObj"][0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    managed[@"boolObj"] = (id)@[@YES];
    uncheckedAssertEqualObjects(managed[@"boolObj"][0], @YES);
    managed[@"intObj"] = (id)@[@3];
    uncheckedAssertEqualObjects(managed[@"intObj"][0], @3);
    managed[@"floatObj"] = (id)@[@3.3f];
    uncheckedAssertEqualObjects(managed[@"floatObj"][0], @3.3f);
    managed[@"doubleObj"] = (id)@[@3.3];
    uncheckedAssertEqualObjects(managed[@"doubleObj"][0], @3.3);
    managed[@"stringObj"] = (id)@[@"b"];
    uncheckedAssertEqualObjects(managed[@"stringObj"][0], @"b");
    managed[@"dataObj"] = (id)@[data(2)];
    uncheckedAssertEqualObjects(managed[@"dataObj"][0], data(2));
    managed[@"dateObj"] = (id)@[date(2)];
    uncheckedAssertEqualObjects(managed[@"dateObj"][0], date(2));
    managed[@"decimalObj"] = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(managed[@"decimalObj"][0], decimal128(3));
    managed[@"objectIdObj"] = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(managed[@"objectIdObj"][0], objectId(2));
    managed[@"uuidObj"] = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(managed[@"uuidObj"][0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    managed[@"anyBoolObj"] = (id)@[@YES];
    uncheckedAssertEqualObjects(managed[@"anyBoolObj"][0], @YES);
    managed[@"anyIntObj"] = (id)@[@3];
    uncheckedAssertEqualObjects(managed[@"anyIntObj"][0], @3);
    managed[@"anyFloatObj"] = (id)@[@3.3f];
    uncheckedAssertEqualObjects(managed[@"anyFloatObj"][0], @3.3f);
    managed[@"anyDoubleObj"] = (id)@[@3.3];
    uncheckedAssertEqualObjects(managed[@"anyDoubleObj"][0], @3.3);
    managed[@"anyStringObj"] = (id)@[@"b"];
    uncheckedAssertEqualObjects(managed[@"anyStringObj"][0], @"b");
    managed[@"anyDataObj"] = (id)@[data(2)];
    uncheckedAssertEqualObjects(managed[@"anyDataObj"][0], data(2));
    managed[@"anyDateObj"] = (id)@[date(2)];
    uncheckedAssertEqualObjects(managed[@"anyDateObj"][0], date(2));
    managed[@"anyDecimalObj"] = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(managed[@"anyDecimalObj"][0], decimal128(3));
    managed[@"anyObjectIdObj"] = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(managed[@"anyObjectIdObj"][0], objectId(2));
    managed[@"anyUUIDObj"] = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(managed[@"anyUUIDObj"][0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    optManaged[@"boolObj"] = (id)@[@YES];
    uncheckedAssertEqualObjects(optManaged[@"boolObj"][0], @YES);
    optManaged[@"intObj"] = (id)@[@3];
    uncheckedAssertEqualObjects(optManaged[@"intObj"][0], @3);
    optManaged[@"floatObj"] = (id)@[@3.3f];
    uncheckedAssertEqualObjects(optManaged[@"floatObj"][0], @3.3f);
    optManaged[@"doubleObj"] = (id)@[@3.3];
    uncheckedAssertEqualObjects(optManaged[@"doubleObj"][0], @3.3);
    optManaged[@"stringObj"] = (id)@[@"b"];
    uncheckedAssertEqualObjects(optManaged[@"stringObj"][0], @"b");
    optManaged[@"dataObj"] = (id)@[data(2)];
    uncheckedAssertEqualObjects(optManaged[@"dataObj"][0], data(2));
    optManaged[@"dateObj"] = (id)@[date(2)];
    uncheckedAssertEqualObjects(optManaged[@"dateObj"][0], date(2));
    optManaged[@"decimalObj"] = (id)@[decimal128(3)];
    uncheckedAssertEqualObjects(optManaged[@"decimalObj"][0], decimal128(3));
    optManaged[@"objectIdObj"] = (id)@[objectId(2)];
    uncheckedAssertEqualObjects(optManaged[@"objectIdObj"][0], objectId(2));
    optManaged[@"uuidObj"] = (id)@[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects(optManaged[@"uuidObj"][0], uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));

    // Should replace and not append
    unmanaged[@"boolObj"] = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([unmanaged[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged[@"intObj"] = (id)@[@2, @3];
    uncheckedAssertEqualObjects([unmanaged[@"intObj"] valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged[@"floatObj"] = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([unmanaged[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged[@"doubleObj"] = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([unmanaged[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged[@"stringObj"] = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([unmanaged[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged[@"dataObj"] = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([unmanaged[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged[@"dateObj"] = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([unmanaged[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged[@"decimalObj"] = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([unmanaged[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged[@"objectIdObj"] = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([unmanaged[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged[@"uuidObj"] = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([unmanaged[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    unmanaged[@"anyBoolObj"] = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([unmanaged[@"anyBoolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged[@"anyIntObj"] = (id)@[@2, @3];
    uncheckedAssertEqualObjects([unmanaged[@"anyIntObj"] valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged[@"anyFloatObj"] = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([unmanaged[@"anyFloatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged[@"anyDoubleObj"] = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([unmanaged[@"anyDoubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged[@"anyStringObj"] = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([unmanaged[@"anyStringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged[@"anyDataObj"] = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([unmanaged[@"anyDataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged[@"anyDateObj"] = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([unmanaged[@"anyDateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged[@"anyDecimalObj"] = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([unmanaged[@"anyDecimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged[@"anyObjectIdObj"] = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([unmanaged[@"anyObjectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged[@"anyUUIDObj"] = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([unmanaged[@"anyUUIDObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optUnmanaged[@"boolObj"] = (id)@[@NO, @YES, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optUnmanaged[@"intObj"] = (id)@[@2, @3, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"intObj"] valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optUnmanaged[@"floatObj"] = (id)@[@2.2f, @3.3f, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optUnmanaged[@"doubleObj"] = (id)@[@2.2, @3.3, NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optUnmanaged[@"stringObj"] = (id)@[@"a", @"b", NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optUnmanaged[@"dataObj"] = (id)@[data(1), data(2), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optUnmanaged[@"dateObj"] = (id)@[date(1), date(2), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optUnmanaged[@"decimalObj"] = (id)@[decimal128(2), decimal128(3), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optUnmanaged[@"objectIdObj"] = (id)@[objectId(1), objectId(2), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optUnmanaged[@"uuidObj"] = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null];
    uncheckedAssertEqualObjects([optUnmanaged[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    
    managed[@"boolObj"] = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([managed[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    managed[@"intObj"] = (id)@[@2, @3];
    uncheckedAssertEqualObjects([managed[@"intObj"] valueForKey:@"self"], (@[@2, @3]));
    
    managed[@"floatObj"] = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([managed[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed[@"doubleObj"] = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([managed[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed[@"stringObj"] = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([managed[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed[@"dataObj"] = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([managed[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed[@"dateObj"] = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([managed[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed[@"decimalObj"] = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([managed[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed[@"objectIdObj"] = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([managed[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed[@"uuidObj"] = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([managed[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    managed[@"anyBoolObj"] = (id)@[@NO, @YES];
    uncheckedAssertEqualObjects([managed[@"anyBoolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    managed[@"anyIntObj"] = (id)@[@2, @3];
    uncheckedAssertEqualObjects([managed[@"anyIntObj"] valueForKey:@"self"], (@[@2, @3]));
    
    managed[@"anyFloatObj"] = (id)@[@2.2f, @3.3f];
    uncheckedAssertEqualObjects([managed[@"anyFloatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed[@"anyDoubleObj"] = (id)@[@2.2, @3.3];
    uncheckedAssertEqualObjects([managed[@"anyDoubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed[@"anyStringObj"] = (id)@[@"a", @"b"];
    uncheckedAssertEqualObjects([managed[@"anyStringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed[@"anyDataObj"] = (id)@[data(1), data(2)];
    uncheckedAssertEqualObjects([managed[@"anyDataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed[@"anyDateObj"] = (id)@[date(1), date(2)];
    uncheckedAssertEqualObjects([managed[@"anyDateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed[@"anyDecimalObj"] = (id)@[decimal128(2), decimal128(3)];
    uncheckedAssertEqualObjects([managed[@"anyDecimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed[@"anyObjectIdObj"] = (id)@[objectId(1), objectId(2)];
    uncheckedAssertEqualObjects([managed[@"anyObjectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed[@"anyUUIDObj"] = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")];
    uncheckedAssertEqualObjects([managed[@"anyUUIDObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optManaged[@"boolObj"] = (id)@[@NO, @YES, NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optManaged[@"intObj"] = (id)@[@2, @3, NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"intObj"] valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optManaged[@"floatObj"] = (id)@[@2.2f, @3.3f, NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optManaged[@"doubleObj"] = (id)@[@2.2, @3.3, NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optManaged[@"stringObj"] = (id)@[@"a", @"b", NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optManaged[@"dataObj"] = (id)@[data(1), data(2), NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optManaged[@"dateObj"] = (id)@[date(1), date(2), NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optManaged[@"decimalObj"] = (id)@[decimal128(2), decimal128(3), NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optManaged[@"objectIdObj"] = (id)@[objectId(1), objectId(2), NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optManaged[@"uuidObj"] = (id)@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null];
    uncheckedAssertEqualObjects([optManaged[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    

    // Should not clear the array
    unmanaged[@"boolObj"] = unmanaged[@"boolObj"];
    uncheckedAssertEqualObjects([unmanaged[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged[@"intObj"] = unmanaged[@"intObj"];
    uncheckedAssertEqualObjects([unmanaged[@"intObj"] valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged[@"floatObj"] = unmanaged[@"floatObj"];
    uncheckedAssertEqualObjects([unmanaged[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged[@"doubleObj"] = unmanaged[@"doubleObj"];
    uncheckedAssertEqualObjects([unmanaged[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged[@"stringObj"] = unmanaged[@"stringObj"];
    uncheckedAssertEqualObjects([unmanaged[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged[@"dataObj"] = unmanaged[@"dataObj"];
    uncheckedAssertEqualObjects([unmanaged[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged[@"dateObj"] = unmanaged[@"dateObj"];
    uncheckedAssertEqualObjects([unmanaged[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged[@"decimalObj"] = unmanaged[@"decimalObj"];
    uncheckedAssertEqualObjects([unmanaged[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged[@"objectIdObj"] = unmanaged[@"objectIdObj"];
    uncheckedAssertEqualObjects([unmanaged[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged[@"uuidObj"] = unmanaged[@"uuidObj"];
    uncheckedAssertEqualObjects([unmanaged[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    unmanaged[@"anyBoolObj"] = unmanaged[@"anyBoolObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyBoolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    unmanaged[@"anyIntObj"] = unmanaged[@"anyIntObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyIntObj"] valueForKey:@"self"], (@[@2, @3]));
    
    unmanaged[@"anyFloatObj"] = unmanaged[@"anyFloatObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyFloatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    unmanaged[@"anyDoubleObj"] = unmanaged[@"anyDoubleObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyDoubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    unmanaged[@"anyStringObj"] = unmanaged[@"anyStringObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyStringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    unmanaged[@"anyDataObj"] = unmanaged[@"anyDataObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyDataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    unmanaged[@"anyDateObj"] = unmanaged[@"anyDateObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyDateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    unmanaged[@"anyDecimalObj"] = unmanaged[@"anyDecimalObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyDecimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    unmanaged[@"anyObjectIdObj"] = unmanaged[@"anyObjectIdObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyObjectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    unmanaged[@"anyUUIDObj"] = unmanaged[@"anyUUIDObj"];
    uncheckedAssertEqualObjects([unmanaged[@"anyUUIDObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optUnmanaged[@"boolObj"] = optUnmanaged[@"boolObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optUnmanaged[@"intObj"] = optUnmanaged[@"intObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"intObj"] valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optUnmanaged[@"floatObj"] = optUnmanaged[@"floatObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optUnmanaged[@"doubleObj"] = optUnmanaged[@"doubleObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optUnmanaged[@"stringObj"] = optUnmanaged[@"stringObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optUnmanaged[@"dataObj"] = optUnmanaged[@"dataObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optUnmanaged[@"dateObj"] = optUnmanaged[@"dateObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optUnmanaged[@"decimalObj"] = optUnmanaged[@"decimalObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optUnmanaged[@"objectIdObj"] = optUnmanaged[@"objectIdObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optUnmanaged[@"uuidObj"] = optUnmanaged[@"uuidObj"];
    uncheckedAssertEqualObjects([optUnmanaged[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    
    managed[@"boolObj"] = managed[@"boolObj"];
    uncheckedAssertEqualObjects([managed[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    managed[@"intObj"] = managed[@"intObj"];
    uncheckedAssertEqualObjects([managed[@"intObj"] valueForKey:@"self"], (@[@2, @3]));
    
    managed[@"floatObj"] = managed[@"floatObj"];
    uncheckedAssertEqualObjects([managed[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed[@"doubleObj"] = managed[@"doubleObj"];
    uncheckedAssertEqualObjects([managed[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed[@"stringObj"] = managed[@"stringObj"];
    uncheckedAssertEqualObjects([managed[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed[@"dataObj"] = managed[@"dataObj"];
    uncheckedAssertEqualObjects([managed[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed[@"dateObj"] = managed[@"dateObj"];
    uncheckedAssertEqualObjects([managed[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed[@"decimalObj"] = managed[@"decimalObj"];
    uncheckedAssertEqualObjects([managed[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed[@"objectIdObj"] = managed[@"objectIdObj"];
    uncheckedAssertEqualObjects([managed[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed[@"uuidObj"] = managed[@"uuidObj"];
    uncheckedAssertEqualObjects([managed[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    managed[@"anyBoolObj"] = managed[@"anyBoolObj"];
    uncheckedAssertEqualObjects([managed[@"anyBoolObj"] valueForKey:@"self"], (@[@NO, @YES]));
    
    managed[@"anyIntObj"] = managed[@"anyIntObj"];
    uncheckedAssertEqualObjects([managed[@"anyIntObj"] valueForKey:@"self"], (@[@2, @3]));
    
    managed[@"anyFloatObj"] = managed[@"anyFloatObj"];
    uncheckedAssertEqualObjects([managed[@"anyFloatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f]));
    
    managed[@"anyDoubleObj"] = managed[@"anyDoubleObj"];
    uncheckedAssertEqualObjects([managed[@"anyDoubleObj"] valueForKey:@"self"], (@[@2.2, @3.3]));
    
    managed[@"anyStringObj"] = managed[@"anyStringObj"];
    uncheckedAssertEqualObjects([managed[@"anyStringObj"] valueForKey:@"self"], (@[@"a", @"b"]));
    
    managed[@"anyDataObj"] = managed[@"anyDataObj"];
    uncheckedAssertEqualObjects([managed[@"anyDataObj"] valueForKey:@"self"], (@[data(1), data(2)]));
    
    managed[@"anyDateObj"] = managed[@"anyDateObj"];
    uncheckedAssertEqualObjects([managed[@"anyDateObj"] valueForKey:@"self"], (@[date(1), date(2)]));
    
    managed[@"anyDecimalObj"] = managed[@"anyDecimalObj"];
    uncheckedAssertEqualObjects([managed[@"anyDecimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3)]));
    
    managed[@"anyObjectIdObj"] = managed[@"anyObjectIdObj"];
    uncheckedAssertEqualObjects([managed[@"anyObjectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2)]));
    
    managed[@"anyUUIDObj"] = managed[@"anyUUIDObj"];
    uncheckedAssertEqualObjects([managed[@"anyUUIDObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]));
    
    optManaged[@"boolObj"] = optManaged[@"boolObj"];
    uncheckedAssertEqualObjects([optManaged[@"boolObj"] valueForKey:@"self"], (@[@NO, @YES, NSNull.null]));
    
    optManaged[@"intObj"] = optManaged[@"intObj"];
    uncheckedAssertEqualObjects([optManaged[@"intObj"] valueForKey:@"self"], (@[@2, @3, NSNull.null]));
    
    optManaged[@"floatObj"] = optManaged[@"floatObj"];
    uncheckedAssertEqualObjects([optManaged[@"floatObj"] valueForKey:@"self"], (@[@2.2f, @3.3f, NSNull.null]));
    
    optManaged[@"doubleObj"] = optManaged[@"doubleObj"];
    uncheckedAssertEqualObjects([optManaged[@"doubleObj"] valueForKey:@"self"], (@[@2.2, @3.3, NSNull.null]));
    
    optManaged[@"stringObj"] = optManaged[@"stringObj"];
    uncheckedAssertEqualObjects([optManaged[@"stringObj"] valueForKey:@"self"], (@[@"a", @"b", NSNull.null]));
    
    optManaged[@"dataObj"] = optManaged[@"dataObj"];
    uncheckedAssertEqualObjects([optManaged[@"dataObj"] valueForKey:@"self"], (@[data(1), data(2), NSNull.null]));
    
    optManaged[@"dateObj"] = optManaged[@"dateObj"];
    uncheckedAssertEqualObjects([optManaged[@"dateObj"] valueForKey:@"self"], (@[date(1), date(2), NSNull.null]));
    
    optManaged[@"decimalObj"] = optManaged[@"decimalObj"];
    uncheckedAssertEqualObjects([optManaged[@"decimalObj"] valueForKey:@"self"], (@[decimal128(2), decimal128(3), NSNull.null]));
    
    optManaged[@"objectIdObj"] = optManaged[@"objectIdObj"];
    uncheckedAssertEqualObjects([optManaged[@"objectIdObj"] valueForKey:@"self"], (@[objectId(1), objectId(2), NSNull.null]));
    
    optManaged[@"uuidObj"] = optManaged[@"uuidObj"];
    uncheckedAssertEqualObjects([optManaged[@"uuidObj"] valueForKey:@"self"], (@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null]));
    

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
        @"boolObj": [@[@NO, @YES] subarrayWithRange:range],
        @"intObj": [@[@2, @3] subarrayWithRange:range],
        @"floatObj": [@[@2.2f, @3.3f] subarrayWithRange:range],
        @"doubleObj": [@[@2.2, @3.3] subarrayWithRange:range],
        @"stringObj": [@[@"a", @"b"] subarrayWithRange:range],
        @"dataObj": [@[data(1), data(2)] subarrayWithRange:range],
        @"dateObj": [@[date(1), date(2)] subarrayWithRange:range],
        @"decimalObj": [@[decimal128(2), decimal128(3)] subarrayWithRange:range],
        @"objectIdObj": [@[objectId(1), objectId(2)] subarrayWithRange:range],
        @"uuidObj": [@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")] subarrayWithRange:range],
        @"anyBoolObj": [@[@NO, @YES] subarrayWithRange:range],
        @"anyIntObj": [@[@2, @3] subarrayWithRange:range],
        @"anyFloatObj": [@[@2.2f, @3.3f] subarrayWithRange:range],
        @"anyDoubleObj": [@[@2.2, @3.3] subarrayWithRange:range],
        @"anyStringObj": [@[@"a", @"b"] subarrayWithRange:range],
        @"anyDataObj": [@[data(1), data(2)] subarrayWithRange:range],
        @"anyDateObj": [@[date(1), date(2)] subarrayWithRange:range],
        @"anyDecimalObj": [@[decimal128(2), decimal128(3)] subarrayWithRange:range],
        @"anyObjectIdObj": [@[objectId(1), objectId(2)] subarrayWithRange:range],
        @"anyUUIDObj": [@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")] subarrayWithRange:range],
    }];
    [LinkToAllPrimitiveArrays createInRealm:realm withValue:@[obj]];
    obj = [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": [@[@NO, @YES, NSNull.null] subarrayWithRange:range],
        @"intObj": [@[@2, @3, NSNull.null] subarrayWithRange:range],
        @"floatObj": [@[@2.2f, @3.3f, NSNull.null] subarrayWithRange:range],
        @"doubleObj": [@[@2.2, @3.3, NSNull.null] subarrayWithRange:range],
        @"stringObj": [@[@"a", @"b", NSNull.null] subarrayWithRange:range],
        @"dataObj": [@[data(1), data(2), NSNull.null] subarrayWithRange:range],
        @"dateObj": [@[date(1), date(2), NSNull.null] subarrayWithRange:range],
        @"decimalObj": [@[decimal128(2), decimal128(3), NSNull.null] subarrayWithRange:range],
        @"objectIdObj": [@[objectId(1), objectId(2), NSNull.null] subarrayWithRange:range],
        @"uuidObj": [@[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"), NSNull.null] subarrayWithRange:range],
    }];
    [LinkToAllOptionalPrimitiveArrays createInRealm:realm withValue:@[obj]];
}

- (void)testQueryBasicOperators {
    [realm deleteAllObjects];

    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY boolObj = %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj = %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj = %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj = %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY stringObj = %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dataObj = %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj = %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj = %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY objectIdObj = %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyBoolObj = %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj = %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj = %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj = %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyStringObj = %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDataObj = %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj = %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj = %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyObjectIdObj = %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyUUIDObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY boolObj = %@", @NO);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj = %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj = %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj = %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY stringObj = %@", @"a");
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dataObj = %@", data(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj = %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj = %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY objectIdObj = %@", objectId(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY boolObj != %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY stringObj != %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dataObj != %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj != %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY objectIdObj != %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyBoolObj != %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyStringObj != %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDataObj != %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj != %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyObjectIdObj != %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyUUIDObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY boolObj != %@", @NO);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj != %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj != %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj != %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY stringObj != %@", @"a");
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dataObj != %@", data(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj != %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj != %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY objectIdObj != %@", objectId(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj > %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj > %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj > %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj > %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj > %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj > %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj > %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj >= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj >= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj >= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj >= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj >= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj >= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj >= %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj < %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj < %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj < %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj < %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj < %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj < %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj < %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj < %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj < %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj < %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj < %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj < %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj < %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj < %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj < %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj <= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj <= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj <= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj <= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj <= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj <= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj <= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj <= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj <= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj <= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj <= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj <= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj <= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj <= %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj <= %@", decimal128(2));

    [self createObjectWithValueIndex:0];

    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY boolObj = %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj = %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj = %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj = %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY stringObj = %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dataObj = %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj = %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj = %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY objectIdObj = %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyBoolObj = %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj = %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj = %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj = %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyStringObj = %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDataObj = %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj = %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj = %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyObjectIdObj = %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyUUIDObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY boolObj = %@", @YES);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj = %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj = %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj = %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY stringObj = %@", @"b");
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dataObj = %@", data(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj = %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj = %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY objectIdObj = %@", objectId(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj = %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj = %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj = %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj = %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj = %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj = %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj = %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj = %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj = %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj = %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj = %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj = %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj = %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj = %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj = %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj = %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj = %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj = %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj = %@", @NO);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj = %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj = %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj = %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj = %@", @"a");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj = %@", data(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj = %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj = %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj = %@", objectId(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY boolObj != %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY stringObj != %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dataObj != %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj != %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY objectIdObj != %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyBoolObj != %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyStringObj != %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDataObj != %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj != %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyObjectIdObj != %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyUUIDObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY boolObj != %@", @NO);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj != %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj != %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj != %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY stringObj != %@", @"a");
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dataObj != %@", data(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj != %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj != %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY objectIdObj != %@", objectId(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj != %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj != %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj != %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj != %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj != %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj != %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj != %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj != %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj != %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj != %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj != %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj != %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj != %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj != %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj != %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj != %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj != %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj != %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj != %@", @YES);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj != %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj != %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj != %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj != %@", @"b");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj != %@", data(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj != %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj != %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj != %@", objectId(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj > %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj > %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj > %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj > %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj > %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj > %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj > %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj >= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj >= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj >= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj >= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj >= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj >= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj >= %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj < %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj < %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj < %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj < %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj < %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj < %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj < %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj < %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj < %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj < %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj < %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj < %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj < %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj < %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj < %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj < %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj < %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj < %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj < %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj < %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj < %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj < %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj < %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj < %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj < %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj < %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj < %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj < %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj < %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj < %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj <= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj <= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj <= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj <= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj <= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj <= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj <= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj <= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj <= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj <= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj <= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj <= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj <= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj <= %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj <= %@", decimal128(2));

    [self createObjectWithValueIndex:1];

    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj = %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj = %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj = %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj = %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj = %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj = %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj = %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj = %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj = %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj = %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj = %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj = %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj = %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj = %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj = %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj = %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj = %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj = %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj = %@", @NO);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj = %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj = %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj = %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj = %@", @"a");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj = %@", data(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj = %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj = %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj = %@", objectId(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj = %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj = %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj = %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj = %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj = %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj = %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj = %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj = %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj = %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj = %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj = %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj = %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj = %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj = %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj = %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj = %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj = %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj = %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj = %@", @YES);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj = %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj = %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj = %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj = %@", @"b");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj = %@", data(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj = %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj = %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj = %@", objectId(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj != %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj != %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj != %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj != %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj != %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj != %@", @NO);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj != %@", @"a");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj != %@", data(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj != %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj != %@", objectId(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj != %@", @NO);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj != %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj != %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj != %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj != %@", @"a");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj != %@", data(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj != %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj != %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj != %@", objectId(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj != %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj != %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj != %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj != %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj != %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj != %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj != %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj != %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj != %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj != %@", @YES);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj != %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj != %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj != %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj != %@", @"b");
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj != %@", data(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj != %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj != %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj != %@", objectId(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj != %@", @YES);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj != %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj != %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj != %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj != %@", @"b");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj != %@", data(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj != %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj != %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj != %@", objectId(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj > %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj > %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj > %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj > %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj > %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj > %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj > %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY intObj >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY floatObj >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY doubleObj >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY dateObj >= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY decimalObj >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyIntObj >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyFloatObj >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyDoubleObj >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyDateObj >= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyDecimalObj >= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY intObj >= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY floatObj >= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY doubleObj >= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY dateObj >= %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY decimalObj >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj < %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj < %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj < %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj < %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj < %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj < %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj < %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj < %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj < %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj < %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj < %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj < %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj < %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj < %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj < %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj < %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj < %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj < %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj < %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj < %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj < %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj < %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj < %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj < %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj < %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj < %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj < %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj < %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj < %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj < %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj <= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj <= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj <= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj <= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj <= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj <= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj <= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj <= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj <= %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj <= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj <= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj <= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj <= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj <= %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj <= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY intObj <= %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY floatObj <= %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY doubleObj <= %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY dateObj <= %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY decimalObj <= %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyIntObj <= %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyFloatObj <= %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyDoubleObj <= %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyDateObj <= %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 2, @"ANY anyDecimalObj <= %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY intObj <= %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY floatObj <= %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY doubleObj <= %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY dateObj <= %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2, @"ANY decimalObj <= %@", decimal128(3));

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY boolObj > %@", @NO]),
                              @"Operator '>' not supported for type 'bool'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY stringObj > %@", @"a"]),
                              @"Operator '>' not supported for type 'string'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY dataObj > %@", data(1)]),
                              @"Operator '>' not supported for type 'data'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY objectIdObj > %@", objectId(1)]),
                              @"Operator '>' not supported for type 'object id'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY uuidObj > %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"Operator '>' not supported for type 'uuid'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY boolObj > %@", @NO]),
                              @"Operator '>' not supported for type 'bool'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY stringObj > %@", @"a"]),
                              @"Operator '>' not supported for type 'string'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY dataObj > %@", data(1)]),
                              @"Operator '>' not supported for type 'data'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY objectIdObj > %@", objectId(1)]),
                              @"Operator '>' not supported for type 'object id'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY uuidObj > %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"Operator '>' not supported for type 'uuid'");
}

- (void)testQueryBetween {
    [realm deleteAllObjects];

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY boolObj BETWEEN %@", @[@NO, @YES]]),
                              @"Operator 'BETWEEN' not supported for type 'bool'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY stringObj BETWEEN %@", @[@"a", @"b"]]),
                              @"Operator 'BETWEEN' not supported for type 'string'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY dataObj BETWEEN %@", @[data(1), data(2)]]),
                              @"Operator 'BETWEEN' not supported for type 'data'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY objectIdObj BETWEEN %@", @[objectId(1), objectId(2)]]),
                              @"Operator 'BETWEEN' not supported for type 'object id'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"ANY uuidObj BETWEEN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]]),
                              @"Operator 'BETWEEN' not supported for type 'uuid'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY boolObj BETWEEN %@", @[@NO, @YES]]),
                              @"Operator 'BETWEEN' not supported for type 'bool'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY stringObj BETWEEN %@", @[@"a", @"b"]]),
                              @"Operator 'BETWEEN' not supported for type 'string'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY dataObj BETWEEN %@", @[data(1), data(2)]]),
                              @"Operator 'BETWEEN' not supported for type 'data'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY objectIdObj BETWEEN %@", @[objectId(1), objectId(2)]]),
                              @"Operator 'BETWEEN' not supported for type 'object id'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY uuidObj BETWEEN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]]),
                              @"Operator 'BETWEEN' not supported for type 'uuid'");

    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj BETWEEN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj BETWEEN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj BETWEEN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj BETWEEN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj BETWEEN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj BETWEEN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj BETWEEN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj BETWEEN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj BETWEEN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj BETWEEN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj BETWEEN %@", @[@2, @3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj BETWEEN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj BETWEEN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj BETWEEN %@", @[date(1), date(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj BETWEEN %@", @[decimal128(2), decimal128(3)]);

    [self createObjectWithValueIndex:0];

    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj BETWEEN %@", @[@2, @2]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj BETWEEN %@", @[@2.2f, @2.2f]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj BETWEEN %@", @[@2.2, @2.2]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj BETWEEN %@", @[date(1), date(1)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj BETWEEN %@", @[decimal128(2), decimal128(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj BETWEEN %@", @[@2, @2]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj BETWEEN %@", @[@2.2f, @2.2f]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj BETWEEN %@", @[@2.2, @2.2]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj BETWEEN %@", @[date(1), date(1)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj BETWEEN %@", @[decimal128(2), decimal128(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj BETWEEN %@", @[@2, @2]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj BETWEEN %@", @[@2.2f, @2.2f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj BETWEEN %@", @[@2.2, @2.2]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj BETWEEN %@", @[date(1), date(1)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj BETWEEN %@", @[decimal128(2), decimal128(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj BETWEEN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj BETWEEN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj BETWEEN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj BETWEEN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj BETWEEN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj BETWEEN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj BETWEEN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj BETWEEN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj BETWEEN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj BETWEEN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj BETWEEN %@", @[@2, @3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj BETWEEN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj BETWEEN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj BETWEEN %@", @[date(1), date(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj BETWEEN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj BETWEEN %@", @[@3, @3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj BETWEEN %@", @[@3.3f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj BETWEEN %@", @[@3.3, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj BETWEEN %@", @[date(2), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj BETWEEN %@", @[decimal128(3), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj BETWEEN %@", @[@3, @3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj BETWEEN %@", @[@3.3f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj BETWEEN %@", @[@3.3, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj BETWEEN %@", @[date(2), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj BETWEEN %@", @[decimal128(3), decimal128(3)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj BETWEEN %@", @[@3, @3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj BETWEEN %@", @[@3.3f, @3.3f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj BETWEEN %@", @[@3.3, @3.3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj BETWEEN %@", @[date(2), date(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj BETWEEN %@", @[decimal128(3), decimal128(3)]);
}

- (void)testQueryIn {
    [realm deleteAllObjects];

    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY boolObj IN %@", @[@NO, @YES]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj IN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj IN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj IN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY stringObj IN %@", @[@"a", @"b"]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dataObj IN %@", @[data(1), data(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj IN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj IN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY objectIdObj IN %@", @[objectId(1), objectId(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY uuidObj IN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyBoolObj IN %@", @[@NO, @YES]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj IN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj IN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj IN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyStringObj IN %@", @[@"a", @"b"]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDataObj IN %@", @[data(1), data(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj IN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj IN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyObjectIdObj IN %@", @[objectId(1), objectId(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyUUIDObj IN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY boolObj IN %@", @[@NO, @YES]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj IN %@", @[@2, @3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj IN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj IN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY stringObj IN %@", @[@"a", @"b"]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dataObj IN %@", @[data(1), data(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj IN %@", @[date(1), date(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj IN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY objectIdObj IN %@", @[objectId(1), objectId(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY uuidObj IN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);

    [self createObjectWithValueIndex:0];

    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY boolObj IN %@", @[@YES]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY intObj IN %@", @[@3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY floatObj IN %@", @[@3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY doubleObj IN %@", @[@3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY stringObj IN %@", @[@"b"]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dataObj IN %@", @[data(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY dateObj IN %@", @[date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY decimalObj IN %@", @[decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY objectIdObj IN %@", @[objectId(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY uuidObj IN %@", @[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyBoolObj IN %@", @[@YES]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyIntObj IN %@", @[@3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyFloatObj IN %@", @[@3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDoubleObj IN %@", @[@3.3]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyStringObj IN %@", @[@"b"]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDataObj IN %@", @[data(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDateObj IN %@", @[date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyDecimalObj IN %@", @[decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyObjectIdObj IN %@", @[objectId(2)]);
    RLMAssertCount(AllPrimitiveArrays, 0, @"ANY anyUUIDObj IN %@", @[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY boolObj IN %@", @[@YES]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY intObj IN %@", @[@3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY floatObj IN %@", @[@3.3f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY doubleObj IN %@", @[@3.3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY stringObj IN %@", @[@"b"]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dataObj IN %@", @[data(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY dateObj IN %@", @[date(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY decimalObj IN %@", @[decimal128(3)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY objectIdObj IN %@", @[objectId(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0, @"ANY uuidObj IN %@", @[uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY boolObj IN %@", @[@NO, @YES]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY intObj IN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY floatObj IN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY doubleObj IN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY stringObj IN %@", @[@"a", @"b"]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dataObj IN %@", @[data(1), data(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY dateObj IN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY decimalObj IN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY objectIdObj IN %@", @[objectId(1), objectId(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY uuidObj IN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyBoolObj IN %@", @[@NO, @YES]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyIntObj IN %@", @[@2, @3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyFloatObj IN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDoubleObj IN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyStringObj IN %@", @[@"a", @"b"]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDataObj IN %@", @[data(1), data(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDateObj IN %@", @[date(1), date(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyDecimalObj IN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyObjectIdObj IN %@", @[objectId(1), objectId(2)]);
    RLMAssertCount(AllPrimitiveArrays, 1, @"ANY anyUUIDObj IN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY boolObj IN %@", @[@NO, @YES]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY intObj IN %@", @[@2, @3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY floatObj IN %@", @[@2.2f, @3.3f]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY doubleObj IN %@", @[@2.2, @3.3]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY stringObj IN %@", @[@"a", @"b"]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dataObj IN %@", @[data(1), data(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY dateObj IN %@", @[date(1), date(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY decimalObj IN %@", @[decimal128(2), decimal128(3)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY objectIdObj IN %@", @[objectId(1), objectId(2)]);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1, @"ANY uuidObj IN %@", @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"137DECC8-B300-4954-A233-F89909F4FD89")]);
}

- (void)testQueryCount {
    [realm deleteAllObjects];

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": @[],
        @"intObj": @[],
        @"floatObj": @[],
        @"doubleObj": @[],
        @"stringObj": @[],
        @"dataObj": @[],
        @"dateObj": @[],
        @"decimalObj": @[],
        @"objectIdObj": @[],
        @"uuidObj": @[],
        @"anyBoolObj": @[],
        @"anyIntObj": @[],
        @"anyFloatObj": @[],
        @"anyDoubleObj": @[],
        @"anyStringObj": @[],
        @"anyDataObj": @[],
        @"anyDateObj": @[],
        @"anyDecimalObj": @[],
        @"anyObjectIdObj": @[],
        @"anyUUIDObj": @[],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": @[],
        @"intObj": @[],
        @"floatObj": @[],
        @"doubleObj": @[],
        @"stringObj": @[],
        @"dataObj": @[],
        @"dateObj": @[],
        @"decimalObj": @[],
        @"objectIdObj": @[],
        @"uuidObj": @[],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": @[@NO],
        @"intObj": @[@2],
        @"floatObj": @[@2.2f],
        @"doubleObj": @[@2.2],
        @"stringObj": @[@"a"],
        @"dataObj": @[data(1)],
        @"dateObj": @[date(1)],
        @"decimalObj": @[decimal128(2)],
        @"objectIdObj": @[objectId(1)],
        @"uuidObj": @[uuid(@"00000000-0000-0000-0000-000000000000")],
        @"anyBoolObj": @[@NO],
        @"anyIntObj": @[@2],
        @"anyFloatObj": @[@2.2f],
        @"anyDoubleObj": @[@2.2],
        @"anyStringObj": @[@"a"],
        @"anyDataObj": @[data(1)],
        @"anyDateObj": @[date(1)],
        @"anyDecimalObj": @[decimal128(2)],
        @"anyObjectIdObj": @[objectId(1)],
        @"anyUUIDObj": @[uuid(@"00000000-0000-0000-0000-000000000000")],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": @[@NO],
        @"intObj": @[@2],
        @"floatObj": @[@2.2f],
        @"doubleObj": @[@2.2],
        @"stringObj": @[@"a"],
        @"dataObj": @[data(1)],
        @"dateObj": @[date(1)],
        @"decimalObj": @[decimal128(2)],
        @"objectIdObj": @[objectId(1)],
        @"uuidObj": @[uuid(@"00000000-0000-0000-0000-000000000000")],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": @[@NO, @NO],
        @"intObj": @[@2, @2],
        @"floatObj": @[@2.2f, @2.2f],
        @"doubleObj": @[@2.2, @2.2],
        @"stringObj": @[@"a", @"a"],
        @"dataObj": @[data(1), data(1)],
        @"dateObj": @[date(1), date(1)],
        @"decimalObj": @[decimal128(2), decimal128(2)],
        @"objectIdObj": @[objectId(1), objectId(1)],
        @"uuidObj": @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000")],
        @"anyBoolObj": @[@NO, @NO],
        @"anyIntObj": @[@2, @2],
        @"anyFloatObj": @[@2.2f, @2.2f],
        @"anyDoubleObj": @[@2.2, @2.2],
        @"anyStringObj": @[@"a", @"a"],
        @"anyDataObj": @[data(1), data(1)],
        @"anyDateObj": @[date(1), date(1)],
        @"anyDecimalObj": @[decimal128(2), decimal128(2)],
        @"anyObjectIdObj": @[objectId(1), objectId(1)],
        @"anyUUIDObj": @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000")],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"boolObj": @[@NO, @NO],
        @"intObj": @[@2, @2],
        @"floatObj": @[@2.2f, @2.2f],
        @"doubleObj": @[@2.2, @2.2],
        @"stringObj": @[@"a", @"a"],
        @"dataObj": @[data(1), data(1)],
        @"dateObj": @[date(1), date(1)],
        @"decimalObj": @[decimal128(2), decimal128(2)],
        @"objectIdObj": @[objectId(1), objectId(1)],
        @"uuidObj": @[uuid(@"00000000-0000-0000-0000-000000000000"), uuid(@"00000000-0000-0000-0000-000000000000")],
    }];

    for (unsigned int i = 0; i < 3; ++i) {
        RLMAssertCount(AllPrimitiveArrays, 1U, @"boolObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"stringObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"dataObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"objectIdObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"uuidObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyBoolObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyStringObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDataObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyObjectIdObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 1U, @"anyUUIDObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"boolObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"stringObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dataObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"objectIdObj.@count == %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"uuidObj.@count == %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"boolObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"stringObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"dataObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"dateObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"objectIdObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"uuidObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyBoolObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyIntObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyFloatObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDoubleObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyStringObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDataObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDateObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDecimalObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyObjectIdObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2U, @"anyUUIDObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"boolObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"stringObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"dataObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"dateObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"objectIdObj.@count != %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"uuidObj.@count != %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"boolObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"intObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"floatObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"doubleObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"stringObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"dataObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"dateObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"decimalObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"objectIdObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"uuidObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyBoolObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyIntObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyFloatObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyDoubleObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyStringObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyDataObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyDateObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyDecimalObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyObjectIdObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 2 - i, @"anyUUIDObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"boolObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"intObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"floatObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"doubleObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"stringObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"dataObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"dateObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"decimalObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"objectIdObj.@count > %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 2 - i, @"uuidObj.@count > %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"boolObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"intObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"floatObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"doubleObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"stringObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"dataObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"dateObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"decimalObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"objectIdObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"uuidObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyBoolObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyIntObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyFloatObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyDoubleObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyStringObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyDataObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyDateObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyDecimalObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyObjectIdObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, 3 - i, @"anyUUIDObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"boolObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"intObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"floatObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"doubleObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"stringObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"dataObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"dateObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"decimalObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"objectIdObj.@count >= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, 3 - i, @"uuidObj.@count >= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"boolObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"intObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"floatObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"doubleObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"stringObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"dataObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"dateObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"decimalObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"objectIdObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"uuidObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyBoolObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyIntObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyFloatObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyDoubleObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyStringObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyDataObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyDateObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyDecimalObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyObjectIdObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i, @"anyUUIDObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"boolObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"intObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"floatObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"doubleObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"stringObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"dataObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"dateObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"decimalObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"objectIdObj.@count < %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i, @"uuidObj.@count < %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"boolObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"intObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"floatObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"doubleObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"stringObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"dataObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"dateObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"decimalObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"objectIdObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"uuidObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyBoolObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyIntObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyFloatObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyDoubleObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyStringObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyDataObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyDateObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyDecimalObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyObjectIdObj.@count <= %@", @(i));
        RLMAssertCount(AllPrimitiveArrays, i + 1, @"anyUUIDObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"boolObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"intObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"floatObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"doubleObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"stringObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"dataObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"dateObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"decimalObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"objectIdObj.@count <= %@", @(i));
        RLMAssertCount(AllOptionalPrimitiveArrays, i + 1, @"uuidObj.@count <= %@", @(i));
    }
}

- (void)testQuerySum {
    [realm deleteAllObjects];

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"boolObj.@sum = %@", @NO]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"stringObj.@sum = %@", @"a"]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dataObj.@sum = %@", data(1)]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@sum = %@", objectId(1)]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@sum = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"boolObj.@sum = %@", @NO]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"stringObj.@sum = %@", @"a"]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dataObj.@sum = %@", data(1)]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@sum = %@", objectId(1)]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@sum = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@sum can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dateObj.@sum = %@", date(1)]),
                              @"Cannot sum or average date properties");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dateObj.@sum = %@", date(1)]),
                              @"Cannot sum or average date properties");

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@sum = %@", @"a"]),
                              @"@sum on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@sum = %@", @"a"]),
                              @"@sum on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@sum = %@", @"a"]),
                              @"@sum on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@sum = %@", @"a"]),
                              @"@sum on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@sum = %@", @"a"]),
                              @"@sum on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@sum = %@", @"a"]),
                              @"@sum on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@sum = %@", @"a"]),
                              @"@sum on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@sum = %@", @"a"]),
                              @"@sum on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@sum.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@sum.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@sum.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@sum.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@sum.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@sum.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@sum.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@sum.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type int cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type float cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type double cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type decimal128 cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type int cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type float cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type double cannot be compared with '<null>'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@sum = %@", NSNull.null]),
                              @"@sum on a property of type decimal128 cannot be compared with '<null>'");

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[],
        @"floatObj": @[],
        @"doubleObj": @[],
        @"decimalObj": @[],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[],
        @"floatObj": @[],
        @"doubleObj": @[],
        @"decimalObj": @[],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2],
        @"floatObj": @[@2.2f],
        @"doubleObj": @[@2.2],
        @"decimalObj": @[decimal128(2)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2],
        @"floatObj": @[@2.2f],
        @"doubleObj": @[@2.2],
        @"decimalObj": @[decimal128(2)],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2, @2],
        @"floatObj": @[@2.2f, @2.2f],
        @"doubleObj": @[@2.2, @2.2],
        @"decimalObj": @[decimal128(2), decimal128(2)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2, @2],
        @"floatObj": @[@2.2f, @2.2f],
        @"doubleObj": @[@2.2, @2.2],
        @"decimalObj": @[decimal128(2), decimal128(2)],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2, @2, @2],
        @"floatObj": @[@2.2f, @2.2f, @2.2f],
        @"doubleObj": @[@2.2, @2.2, @2.2],
        @"decimalObj": @[decimal128(2), decimal128(2), decimal128(2)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2, @2, @2],
        @"floatObj": @[@2.2f, @2.2f, @2.2f],
        @"doubleObj": @[@2.2, @2.2, @2.2],
        @"decimalObj": @[decimal128(2), decimal128(2), decimal128(2)],
    }];

    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@sum == %@", @0);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@sum == %@", @0);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@sum == %@", @0);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@sum == %@", @0);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@sum == %@", @0);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@sum == %@", @0);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@sum == %@", @0);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@sum == %@", @0);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@sum == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@sum == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@sum == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@sum == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@sum == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@sum == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@sum == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@sum == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 3U, @"intObj.@sum != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"floatObj.@sum != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"doubleObj.@sum != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"decimalObj.@sum != %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"intObj.@sum != %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"floatObj.@sum != %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"doubleObj.@sum != %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"decimalObj.@sum != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 3U, @"intObj.@sum >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"floatObj.@sum >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"doubleObj.@sum >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"decimalObj.@sum >= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"intObj.@sum >= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"floatObj.@sum >= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"doubleObj.@sum >= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"decimalObj.@sum >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@sum > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@sum > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@sum > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@sum > %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@sum > %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@sum > %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@sum > %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@sum > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@sum < %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@sum < %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@sum < %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@sum < %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@sum < %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@sum < %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@sum < %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@sum < %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@sum <= %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@sum <= %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@sum <= %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@sum <= %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@sum <= %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@sum <= %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@sum <= %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@sum <= %@", decimal128(3));
}

- (void)testQueryAverage {
    [realm deleteAllObjects];

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"boolObj.@avg = %@", @NO]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"stringObj.@avg = %@", @"a"]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dataObj.@avg = %@", data(1)]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@avg = %@", objectId(1)]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@avg = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"boolObj.@avg = %@", @NO]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"stringObj.@avg = %@", @"a"]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dataObj.@avg = %@", data(1)]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@avg = %@", objectId(1)]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@avg = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@avg can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dateObj.@avg = %@", date(1)]),
                              @"Cannot sum or average date properties");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dateObj.@avg = %@", date(1)]),
                              @"Cannot sum or average date properties");

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@avg = %@", @"a"]),
                              @"@avg on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@avg = %@", @"a"]),
                              @"@avg on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@avg = %@", @"a"]),
                              @"@avg on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@avg = %@", @"a"]),
                              @"@avg on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@avg = %@", @"a"]),
                              @"@avg on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@avg = %@", @"a"]),
                              @"@avg on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@avg = %@", @"a"]),
                              @"@avg on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@avg = %@", @"a"]),
                              @"@avg on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@avg.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@avg.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@avg.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@avg.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@avg.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@avg.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@avg.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@avg.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[],
        @"floatObj": @[],
        @"doubleObj": @[],
        @"decimalObj": @[],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[],
        @"floatObj": @[],
        @"doubleObj": @[],
        @"decimalObj": @[],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2],
        @"floatObj": @[@2.2f],
        @"doubleObj": @[@2.2],
        @"decimalObj": @[decimal128(2)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2],
        @"floatObj": @[@2.2f],
        @"doubleObj": @[@2.2],
        @"decimalObj": @[decimal128(2)],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2, @3],
        @"floatObj": @[@2.2f, @3.3f],
        @"doubleObj": @[@2.2, @3.3],
        @"decimalObj": @[decimal128(2), decimal128(3)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@2, @3],
        @"floatObj": @[@2.2f, @3.3f],
        @"doubleObj": @[@2.2, @3.3],
        @"decimalObj": @[decimal128(2), decimal128(3)],
    }];
    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@3],
        @"floatObj": @[@3.3f],
        @"doubleObj": @[@3.3],
        @"decimalObj": @[decimal128(3)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@3],
        @"floatObj": @[@3.3f],
        @"doubleObj": @[@3.3],
        @"decimalObj": @[decimal128(3)],
    }];

    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@avg == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@avg == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@avg == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@avg == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@avg == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@avg == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@avg == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@avg == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@avg == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 3U, @"intObj.@avg != %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"floatObj.@avg != %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"doubleObj.@avg != %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"decimalObj.@avg != %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"intObj.@avg != %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"floatObj.@avg != %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"doubleObj.@avg != %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"decimalObj.@avg != %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 3U, @"intObj.@avg >= %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"floatObj.@avg >= %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"doubleObj.@avg >= %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"decimalObj.@avg >= %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"intObj.@avg >= %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"floatObj.@avg >= %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"doubleObj.@avg >= %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"decimalObj.@avg >= %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@avg > %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@avg > %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@avg > %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@avg > %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@avg > %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@avg > %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@avg > %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@avg > %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@avg < %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@avg < %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@avg < %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@avg < %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@avg < %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@avg < %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@avg < %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@avg < %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 3U, @"intObj.@avg <= %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"floatObj.@avg <= %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"doubleObj.@avg <= %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 3U, @"decimalObj.@avg <= %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"intObj.@avg <= %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"floatObj.@avg <= %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"doubleObj.@avg <= %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 3U, @"decimalObj.@avg <= %@", decimal128(3));
}

- (void)testQueryMin {
    [realm deleteAllObjects];

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"boolObj.@min = %@", @NO]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"stringObj.@min = %@", @"a"]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dataObj.@min = %@", data(1)]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@min = %@", objectId(1)]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@min = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"boolObj.@min = %@", @NO]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"stringObj.@min = %@", @"a"]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dataObj.@min = %@", data(1)]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@min = %@", objectId(1)]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@min = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@min can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@min = %@", @"a"]),
                              @"@min on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@min = %@", @"a"]),
                              @"@min on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@min = %@", @"a"]),
                              @"@min on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dateObj.@min = %@", @"a"]),
                              @"@min on a property of type date cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@min = %@", @"a"]),
                              @"@min on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@min = %@", @"a"]),
                              @"@min on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@min = %@", @"a"]),
                              @"@min on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@min = %@", @"a"]),
                              @"@min on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dateObj.@min = %@", @"a"]),
                              @"@min on a property of type date cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@min = %@", @"a"]),
                              @"@min on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@min.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@min.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@min.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dateObj.@min.prop = %@", @"a"]),
                              @"Property 'dateObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@min.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyIntObj.@min.prop = %@", @"a"]),
                              @"Property 'anyIntObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyFloatObj.@min.prop = %@", @"a"]),
                              @"Property 'anyFloatObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyDoubleObj.@min.prop = %@", @"a"]),
                              @"Property 'anyDoubleObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyDateObj.@min.prop = %@", @"a"]),
                              @"Property 'anyDateObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyDecimalObj.@min.prop = %@", @"a"]),
                              @"Property 'anyDecimalObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@min.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@min.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@min.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dateObj.@min.prop = %@", @"a"]),
                              @"Property 'dateObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@min.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");

    // No objects, so count is zero
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(2));

    [AllPrimitiveArrays createInRealm:realm withValue:@{}];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{}];

    // Only empty arrays, so count is zero
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(3));

    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@min == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@min == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@min == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@min == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@min == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@min == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@min == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@min == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@min == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@min == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@min == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@min == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@min == %@", NSNull.null);

    [self createObjectWithValueIndex:0];

    // One object where v0 is min and zero with v1
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@min == %@", decimal128(3));

    [self createObjectWithValueIndex:1];

    // One object where v0 is min and one with v1
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(3));

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@3, @2],
        @"floatObj": @[@3.3f, @2.2f],
        @"doubleObj": @[@3.3, @2.2],
        @"dateObj": @[date(2), date(1)],
        @"decimalObj": @[decimal128(3), decimal128(2)],
        @"anyIntObj": @[@3, @2],
        @"anyFloatObj": @[@3.3f, @2.2f],
        @"anyDoubleObj": @[@3.3, @2.2],
        @"anyDateObj": @[date(2), date(1)],
        @"anyDecimalObj": @[decimal128(3), decimal128(2)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@3, @2],
        @"floatObj": @[@3.3f, @2.2f],
        @"doubleObj": @[@3.3, @2.2],
        @"dateObj": @[date(2), date(1)],
        @"decimalObj": @[decimal128(3), decimal128(2)],
    }];

    // New object with both v0 and v1 matches v0 but not v1
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyIntObj.@min == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyFloatObj.@min == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDoubleObj.@min == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDateObj.@min == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDecimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@min == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@min == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@min == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"dateObj.@min == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@min == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@min == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@min == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@min == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@min == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@min == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@min == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@min == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@min == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@min == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@min == %@", decimal128(3));
}

- (void)testQueryMax {
    [realm deleteAllObjects];

    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"boolObj.@max = %@", @NO]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"stringObj.@max = %@", @"a"]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dataObj.@max = %@", data(1)]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@max = %@", objectId(1)]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@max = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"boolObj.@max = %@", @NO]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"stringObj.@max = %@", @"a"]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dataObj.@max = %@", data(1)]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"objectIdObj.@max = %@", objectId(1)]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"uuidObj.@max = %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"@max can only be applied to a numeric property.");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@max = %@", @"a"]),
                              @"@max on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@max = %@", @"a"]),
                              @"@max on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@max = %@", @"a"]),
                              @"@max on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dateObj.@max = %@", @"a"]),
                              @"@max on a property of type date cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@max = %@", @"a"]),
                              @"@max on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@max = %@", @"a"]),
                              @"@max on a property of type int cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@max = %@", @"a"]),
                              @"@max on a property of type float cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@max = %@", @"a"]),
                              @"@max on a property of type double cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dateObj.@max = %@", @"a"]),
                              @"@max on a property of type date cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@max = %@", @"a"]),
                              @"@max on a property of type decimal128 cannot be compared with 'a'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"intObj.@max.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"floatObj.@max.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@max.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"dateObj.@max.prop = %@", @"a"]),
                              @"Property 'dateObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@max.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyIntObj.@max.prop = %@", @"a"]),
                              @"Property 'anyIntObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyFloatObj.@max.prop = %@", @"a"]),
                              @"Property 'anyFloatObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyDoubleObj.@max.prop = %@", @"a"]),
                              @"Property 'anyDoubleObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyDateObj.@max.prop = %@", @"a"]),
                              @"Property 'anyDateObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllPrimitiveArrays objectsInRealm:realm where:@"anyDecimalObj.@max.prop = %@", @"a"]),
                              @"Property 'anyDecimalObj' is not a link in object of type 'AllPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"intObj.@max.prop = %@", @"a"]),
                              @"Property 'intObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"floatObj.@max.prop = %@", @"a"]),
                              @"Property 'floatObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"doubleObj.@max.prop = %@", @"a"]),
                              @"Property 'doubleObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"dateObj.@max.prop = %@", @"a"]),
                              @"Property 'dateObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");
    RLMAssertThrowsWithReason(([AllOptionalPrimitiveArrays objectsInRealm:realm where:@"decimalObj.@max.prop = %@", @"a"]),
                              @"Property 'decimalObj' is not a link in object of type 'AllOptionalPrimitiveArrays'");

    // No objects, so count is zero
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(2));

    [AllPrimitiveArrays createInRealm:realm withValue:@{}];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{}];

    // Only empty arrays, so count is zero
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(3));

    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@max == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@max == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@max == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@max == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@max == nil");
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@max == nil");
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@max == %@", NSNull.null);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@max == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@max == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@max == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@max == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@max == %@", NSNull.null);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@max == %@", NSNull.null);

    [self createObjectWithValueIndex:0];

    // One object where v0 is min and zero with v1
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyIntObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyFloatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDoubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 0U, @"anyDecimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 0U, @"decimalObj.@max == %@", decimal128(3));

    [self createObjectWithValueIndex:1];

    // One object where v0 is min and one with v1
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(3));

    [AllPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@3, @2],
        @"floatObj": @[@3.3f, @2.2f],
        @"doubleObj": @[@3.3, @2.2],
        @"dateObj": @[date(2), date(1)],
        @"decimalObj": @[decimal128(3), decimal128(2)],
        @"anyIntObj": @[@3, @2],
        @"anyFloatObj": @[@3.3f, @2.2f],
        @"anyDoubleObj": @[@3.3, @2.2],
        @"anyDateObj": @[date(2), date(1)],
        @"anyDecimalObj": @[decimal128(3), decimal128(2)],
    }];
    [AllOptionalPrimitiveArrays createInRealm:realm withValue:@{
        @"intObj": @[@3, @2],
        @"floatObj": @[@3.3f, @2.2f],
        @"doubleObj": @[@3.3, @2.2],
        @"dateObj": @[date(2), date(1)],
        @"decimalObj": @[decimal128(3), decimal128(2)],
    }];

    // New object with both v0 and v1 matches v1 but not v0
    RLMAssertCount(AllPrimitiveArrays, 1U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyIntObj.@max == %@", @2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyFloatObj.@max == %@", @2.2f);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDoubleObj.@max == %@", @2.2);
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDateObj.@max == %@", date(1));
    RLMAssertCount(AllPrimitiveArrays, 1U, @"anyDecimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"intObj.@max == %@", @2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"floatObj.@max == %@", @2.2f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"doubleObj.@max == %@", @2.2);
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"dateObj.@max == %@", date(1));
    RLMAssertCount(AllOptionalPrimitiveArrays, 1U, @"decimalObj.@max == %@", decimal128(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"decimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyIntObj.@max == %@", @3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyFloatObj.@max == %@", @3.3f);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDoubleObj.@max == %@", @3.3);
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDateObj.@max == %@", date(2));
    RLMAssertCount(AllPrimitiveArrays, 2U, @"anyDecimalObj.@max == %@", decimal128(3));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"intObj.@max == %@", @3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"floatObj.@max == %@", @3.3f);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"doubleObj.@max == %@", @3.3);
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"dateObj.@max == %@", date(2));
    RLMAssertCount(AllOptionalPrimitiveArrays, 2U, @"decimalObj.@max == %@", decimal128(3));
}

- (void)testQueryBasicOperatorsOverLink {
    [realm deleteAllObjects];

    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.boolObj = %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj = %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.stringObj = %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dataObj = %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj = %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.objectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyBoolObj = %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj = %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyStringObj = %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDataObj = %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj = %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyObjectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyUUIDObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.boolObj = %@", @NO);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj = %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.stringObj = %@", @"a");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dataObj = %@", data(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj = %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.objectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.boolObj != %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj != %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.stringObj != %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dataObj != %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj != %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.objectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyBoolObj != %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj != %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyStringObj != %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDataObj != %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj != %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyObjectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyUUIDObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.boolObj != %@", @NO);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj != %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.stringObj != %@", @"a");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dataObj != %@", data(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj != %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.objectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj > %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj > %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj > %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj > %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj > %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj > %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj >= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj >= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj >= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj >= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj >= %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj >= %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj < %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj < %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj < %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj < %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj < %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj < %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj <= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj <= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj <= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj <= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj <= %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj <= %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj <= %@", decimal128(2));

    [self createObjectWithValueIndex:0];

    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.boolObj = %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj = %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj = %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj = %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.stringObj = %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dataObj = %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj = %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj = %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.objectIdObj = %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyBoolObj = %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj = %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj = %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj = %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyStringObj = %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDataObj = %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj = %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj = %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyObjectIdObj = %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyUUIDObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.boolObj = %@", @YES);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj = %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj = %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj = %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.stringObj = %@", @"b");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dataObj = %@", data(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj = %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj = %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.objectIdObj = %@", objectId(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.boolObj = %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj = %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.stringObj = %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dataObj = %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj = %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.objectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyBoolObj = %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj = %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyStringObj = %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDataObj = %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj = %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyObjectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyUUIDObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.boolObj = %@", @NO);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj = %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.stringObj = %@", @"a");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dataObj = %@", data(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj = %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.objectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.boolObj != %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj != %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.stringObj != %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dataObj != %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj != %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.objectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyBoolObj != %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj != %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyStringObj != %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDataObj != %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj != %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyObjectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyUUIDObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.boolObj != %@", @NO);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj != %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.stringObj != %@", @"a");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dataObj != %@", data(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj != %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.objectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.boolObj != %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj != %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj != %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj != %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.stringObj != %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dataObj != %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj != %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj != %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.objectIdObj != %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyBoolObj != %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj != %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj != %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj != %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyStringObj != %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDataObj != %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj != %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj != %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyObjectIdObj != %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyUUIDObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.boolObj != %@", @YES);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj != %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj != %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj != %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.stringObj != %@", @"b");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dataObj != %@", data(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj != %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj != %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.objectIdObj != %@", objectId(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj > %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj > %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj > %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj > %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj > %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj > %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj >= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj >= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj >= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj >= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj >= %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj >= %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj < %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj < %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj < %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj < %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj < %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj < %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj < %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj < %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj < %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj < %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj < %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj < %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj < %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj < %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj < %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj < %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj < %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj < %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj < %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj < %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj < %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj <= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj <= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj <= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj <= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj <= %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj <= %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj <= %@", decimal128(2));

    [self createObjectWithValueIndex:1];

    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.boolObj = %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj = %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.stringObj = %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dataObj = %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj = %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.objectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyBoolObj = %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj = %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyStringObj = %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDataObj = %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj = %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyObjectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyUUIDObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.boolObj = %@", @NO);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj = %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj = %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj = %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.stringObj = %@", @"a");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dataObj = %@", data(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj = %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj = %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.objectIdObj = %@", objectId(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.uuidObj = %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.boolObj = %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj = %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj = %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj = %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.stringObj = %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dataObj = %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj = %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj = %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.objectIdObj = %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyBoolObj = %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj = %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj = %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj = %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyStringObj = %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDataObj = %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj = %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj = %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyObjectIdObj = %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyUUIDObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.boolObj = %@", @YES);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj = %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj = %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj = %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.stringObj = %@", @"b");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dataObj = %@", data(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj = %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj = %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.objectIdObj = %@", objectId(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.uuidObj = %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.boolObj != %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj != %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.stringObj != %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dataObj != %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj != %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.objectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyBoolObj != %@", @NO);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj != %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyStringObj != %@", @"a");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDataObj != %@", data(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj != %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyObjectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyUUIDObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.boolObj != %@", @NO);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj != %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj != %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj != %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.stringObj != %@", @"a");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dataObj != %@", data(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj != %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj != %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.objectIdObj != %@", objectId(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.uuidObj != %@", uuid(@"00000000-0000-0000-0000-000000000000"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.boolObj != %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj != %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj != %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj != %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.stringObj != %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dataObj != %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj != %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj != %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.objectIdObj != %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyBoolObj != %@", @YES);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj != %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj != %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj != %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyStringObj != %@", @"b");
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDataObj != %@", data(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj != %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj != %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyObjectIdObj != %@", objectId(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyUUIDObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.boolObj != %@", @YES);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj != %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj != %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj != %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.stringObj != %@", @"b");
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dataObj != %@", data(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj != %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj != %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.objectIdObj != %@", objectId(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.uuidObj != %@", uuid(@"137DECC8-B300-4954-A233-F89909F4FD89"));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj > %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj > %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj > %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj > %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj > %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj > %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj > %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj > %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj > %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.intObj >= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.floatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.doubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.dateObj >= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.decimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyIntObj >= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyFloatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyDoubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyDateObj >= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyDecimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.intObj >= %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.floatObj >= %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.doubleObj >= %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.dateObj >= %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.decimalObj >= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.intObj < %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.floatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.doubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.dateObj < %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.decimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyIntObj < %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyFloatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDoubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDateObj < %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 0, @"ANY link.anyDecimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.intObj < %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.floatObj < %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.doubleObj < %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.dateObj < %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 0, @"ANY link.decimalObj < %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj < %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj < %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj < %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj < %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj < %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj < %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj < %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj < %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj < %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj < %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj < %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj < %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj < %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj < %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj < %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.intObj <= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.floatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.doubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.dateObj <= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.decimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyIntObj <= %@", @2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyFloatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDoubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDateObj <= %@", date(1));
    RLMAssertCount(LinkToAllPrimitiveArrays, 1, @"ANY link.anyDecimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.intObj <= %@", @2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.floatObj <= %@", @2.2f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.doubleObj <= %@", @2.2);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.dateObj <= %@", date(1));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 1, @"ANY link.decimalObj <= %@", decimal128(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.intObj <= %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.floatObj <= %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.doubleObj <= %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.dateObj <= %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.decimalObj <= %@", decimal128(3));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyIntObj <= %@", @3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyFloatObj <= %@", @3.3f);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyDoubleObj <= %@", @3.3);
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyDateObj <= %@", date(2));
    RLMAssertCount(LinkToAllPrimitiveArrays, 2, @"ANY link.anyDecimalObj <= %@", decimal128(3));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.intObj <= %@", @3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.floatObj <= %@", @3.3f);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.doubleObj <= %@", @3.3);
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.dateObj <= %@", date(2));
    RLMAssertCount(LinkToAllOptionalPrimitiveArrays, 2, @"ANY link.decimalObj <= %@", decimal128(3));

    RLMAssertThrowsWithReason(([LinkToAllPrimitiveArrays objectsInRealm:realm where:@"ANY link.boolObj > %@", @NO]),
                              @"Operator '>' not supported for type 'bool'");
    RLMAssertThrowsWithReason(([LinkToAllPrimitiveArrays objectsInRealm:realm where:@"ANY link.stringObj > %@", @"a"]),
                              @"Operator '>' not supported for type 'string'");
    RLMAssertThrowsWithReason(([LinkToAllPrimitiveArrays objectsInRealm:realm where:@"ANY link.dataObj > %@", data(1)]),
                              @"Operator '>' not supported for type 'data'");
    RLMAssertThrowsWithReason(([LinkToAllPrimitiveArrays objectsInRealm:realm where:@"ANY link.objectIdObj > %@", objectId(1)]),
                              @"Operator '>' not supported for type 'object id'");
    RLMAssertThrowsWithReason(([LinkToAllPrimitiveArrays objectsInRealm:realm where:@"ANY link.uuidObj > %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"Operator '>' not supported for type 'uuid'");
    RLMAssertThrowsWithReason(([LinkToAllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY link.boolObj > %@", @NO]),
                              @"Operator '>' not supported for type 'bool'");
    RLMAssertThrowsWithReason(([LinkToAllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY link.stringObj > %@", @"a"]),
                              @"Operator '>' not supported for type 'string'");
    RLMAssertThrowsWithReason(([LinkToAllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY link.dataObj > %@", data(1)]),
                              @"Operator '>' not supported for type 'data'");
    RLMAssertThrowsWithReason(([LinkToAllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY link.objectIdObj > %@", objectId(1)]),
                              @"Operator '>' not supported for type 'object id'");
    RLMAssertThrowsWithReason(([LinkToAllOptionalPrimitiveArrays objectsInRealm:realm where:@"ANY link.uuidObj > %@", uuid(@"00000000-0000-0000-0000-000000000000")]),
                              @"Operator '>' not supported for type 'uuid'");
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
        RLMAssertCount(AllPrimitiveArrays, count, query, value);
        RLMAssertCount(AllPrimitiveArrays, count, query, value);
        RLMAssertCount(AllOptionalPrimitiveArrays, count, query, value);
        query = [NSString stringWithFormat:@"ANY link.stringObj %@ %%@", operator];
        RLMAssertCount(LinkToAllPrimitiveArrays, count, query, value);
        RLMAssertCount(LinkToAllPrimitiveArrays, count, query, value);
        RLMAssertCount(LinkToAllOptionalPrimitiveArrays, count, query, value);

        query = [NSString stringWithFormat:@"ANY dataObj %@ %%@", operator];
        RLMAssertCount(AllPrimitiveArrays, count, query, data);
        RLMAssertCount(AllPrimitiveArrays, count, query, data);
        RLMAssertCount(AllOptionalPrimitiveArrays, count, query, data);
        query = [NSString stringWithFormat:@"ANY link.dataObj %@ %%@", operator];
        RLMAssertCount(LinkToAllPrimitiveArrays, count, query, data);
        RLMAssertCount(LinkToAllPrimitiveArrays, count, query, data);
        RLMAssertCount(LinkToAllOptionalPrimitiveArrays, count, query, data);
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
