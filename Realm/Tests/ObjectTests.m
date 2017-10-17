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

#import "RLMObjectSchema_Private.h"
#import "RLMSchema_Private.h"

#import <libkern/OSAtomic.h>
#import <math.h>
#import <objc/runtime.h>
#import <stdalign.h>

#pragma mark - Test Objects

@interface DefaultObject : RLMObject
@property int       intCol;
@property float     floatCol;
@property double    doubleCol;
@property BOOL      boolCol;
@property NSDate   *dateCol;
@property NSString *stringCol;
@property NSData   *binaryCol;
@end

@implementation DefaultObject
+ (NSDictionary *)defaultPropertyValues {
    NSString *binaryString = @"binary";
    NSData *binaryData = [binaryString dataUsingEncoding:NSUTF8StringEncoding];

    return @{@"intCol": @12,
             @"floatCol": @88.9f,
             @"doubleCol": @1002.892,
             @"boolCol": @YES,
             @"dateCol": [NSDate dateWithTimeIntervalSince1970:999999],
             @"stringCol": @"potato",
             @"binaryCol": binaryData};
}
@end

@interface DynamicDefaultObject : RLMObject
@property int       intCol;
@property float     floatCol;
@property double    doubleCol;
@property NSDate   *dateCol;
@property NSString *stringCol;
@property NSData   *binaryCol;
@end

@implementation DynamicDefaultObject
+ (BOOL)shouldIncludeInDefaultSchema {
    return NO;
}
+ (NSDictionary *)defaultPropertyValues {
    static NSInteger dynamicDefaultSeed = 0;
    dynamicDefaultSeed++;
    return @{@"intCol": @(dynamicDefaultSeed),
             @"floatCol": @((float)dynamicDefaultSeed),
             @"doubleCol": @((double)dynamicDefaultSeed),
             @"dateCol": [NSDate dateWithTimeIntervalSince1970:dynamicDefaultSeed],
             @"stringCol": [[NSUUID UUID] UUIDString],
             @"binaryCol": [[[NSUUID UUID] UUIDString] dataUsingEncoding:NSUTF8StringEncoding]};
}
+ (NSString *)primaryKey {
    return @"intCol";
}
@end

@class CycleObject;
RLM_ARRAY_TYPE(CycleObject)
@interface CycleObject : RLMObject
@property RLM_GENERIC_ARRAY(CycleObject) *objects;
@end

@implementation CycleObject
@end

@interface PrimaryStringObjectWrapper : RLMObject
@property PrimaryStringObject *primaryStringObject;
@end

@implementation PrimaryStringObjectWrapper
@end

@interface PrimaryNestedObject : RLMObject
@property int primaryCol;
@property PrimaryStringObject *primaryStringObject;
@property PrimaryStringObjectWrapper *primaryStringObjectWrapper;
@property StringObject *stringObject;
@property RLM_GENERIC_ARRAY(PrimaryIntObject) *primaryIntArray;
@property NSString *stringCol;
@end

@implementation PrimaryNestedObject
+ (NSString *)primaryKey {
    return @"primaryCol";
}
+ (NSDictionary *)defaultPropertyValues {
    return @{@"stringCol": @"default"};
}
@end

@interface StringSubclassObject : StringObject
@property NSString *stringCol2;
@end

@implementation StringSubclassObject
@end

@interface StringObjectNoThrow : StringObject
@end

@implementation StringObjectNoThrow
- (id)valueForUndefinedKey:(__unused NSString *)key {
    return nil;
}
@end

@interface StringSubclassObjectWithDefaults : StringObjectNoThrow
@property NSString *stringCol2;
@end

@implementation StringSubclassObjectWithDefaults
+(NSDictionary *)defaultPropertyValues {
    return @{@"stringCol2": @"default"};
}
@end

@interface StringLinkObject : RLMObject
@property StringObject *stringObjectCol;
@property RLM_GENERIC_ARRAY(StringObject) *stringObjectArrayCol;
@end

@implementation StringLinkObject
@end

@interface ReadOnlyPropertyObject ()
@property (readwrite) int readOnlyPropertyMadeReadWriteInClassExtension;
@end

@interface DataObject : RLMObject
@property NSData *data1;
@property NSData *data2;
@end

@implementation DataObject
@end

@interface DateObjectNoThrow : DateObject
@property NSDate *date2;
@end

@implementation DateObjectNoThrow
- (id)valueForUndefinedKey:(__unused NSString *)key {
    return nil;
}
@end

@interface DateSubclassObject : DateObjectNoThrow
@property NSDate *date3;
@end

@implementation DateSubclassObject
@end

@interface DateDefaultsObject : DateObjectNoThrow
@property NSDate *date3;
@end

@implementation DateDefaultsObject
+ (NSDictionary *)defaultPropertyValues {
    return @{@"date3": [NSDate date]};
}
@end

@interface SubclassDateObject : NSObject
@property NSDate *dateCol;
@property (getter=customGetter) NSDate *date2;
@property (setter=customSetter:) NSDate *date3;
@end

@implementation SubclassDateObject
@end

#pragma mark - Tests

@interface ObjectTests : RLMTestCase
@end

@implementation ObjectTests

- (void)testKeyedSubscripting {
    EmployeeObject *objs = [[EmployeeObject alloc] initWithValue:@{@"name": @"Test0", @"age": @23, @"hired": @NO}];
    XCTAssertEqualObjects(objs[@"name"], @"Test0",  @"Name should be Test0");
    XCTAssertEqualObjects(objs[@"age"], @23,  @"age should be 23");
    XCTAssertEqualObjects(objs[@"hired"], @NO,  @"hired should be NO");
    objs[@"name"] = @"Test1";
    XCTAssertEqualObjects(objs.name, @"Test1",  @"Name should be Test1");

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    EmployeeObject *obj0 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Test1", @"age": @24, @"hired": @NO}];
    EmployeeObject *obj1 = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Test2", @"age": @25, @"hired": @YES}];
    [realm commitWriteTransaction];

    XCTAssertEqualObjects(obj0[@"name"], @"Test1",  @"Name should be Test1");
    XCTAssertEqualObjects(obj1[@"name"], @"Test2", @"Name should be Test1");

    [realm beginWriteTransaction];
    obj0[@"name"] = @"newName";
    [realm commitWriteTransaction];

    XCTAssertEqualObjects(obj0[@"name"], @"newName",  @"Name should be newName");

    [realm beginWriteTransaction];
    obj0[@"name"] = nil;
    [realm commitWriteTransaction];

    XCTAssertNil(obj0[@"name"]);
}

- (void)testCannotUpdatePrimaryKey {
    PrimaryIntObject *intObj = [[PrimaryIntObject alloc] init];
    intObj.intCol = 1;
    XCTAssertNoThrow(intObj.intCol = 0);

    PrimaryStringObject *stringObj = [[PrimaryStringObject alloc] init];
    stringObj.stringCol = @"a";
    XCTAssertNoThrow(stringObj.stringCol = @"b");

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [realm addObject:intObj];

    RLMAssertThrowsWithReason(intObj.intCol = 1, @"Primary key can't be changed");
    RLMAssertThrowsWithReason(intObj[@"intCol"] = @1, @"Primary key can't be changed");
    RLMAssertThrowsWithReason([intObj setValue:@1 forKey:@"intCol"], @"Primary key can't be changed");

    [realm addObject:stringObj];

    RLMAssertThrowsWithReason(stringObj.stringCol = @"a", @"Primary key can't be changed");
    RLMAssertThrowsWithReason(stringObj[@"stringCol"] = @"a", @"Primary key can't be changed");
    RLMAssertThrowsWithReason([stringObj setValue:@"a" forKey:@"stringCol"], @"Primary key can't be changed");
    [realm cancelWriteTransaction];
}

- (void)testDataTypes {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];

    const char bin[4] = { 0, 1, 2, 3 };
    NSData *bin1 = [[NSData alloc] initWithBytes:bin length:sizeof bin / 2];
    NSData *bin2 = [[NSData alloc] initWithBytes:bin length:sizeof bin];
    NSDate *timeNow = [NSDate dateWithTimeIntervalSince1970:1000000];
    NSDate *timeZero = [NSDate dateWithTimeIntervalSince1970:0];

    AllTypesObject *c = [[AllTypesObject alloc] init];

    c.boolCol   = NO;
    c.intCol  = 54;
    c.floatCol = 0.7f;
    c.doubleCol = 0.8;
    c.stringCol = @"foo";
    c.binaryCol = bin1;
    c.dateCol = timeZero;
    c.cBoolCol = false;
    c.longCol = 99;
    c.objectCol = [[StringObject alloc] init];
    c.objectCol.stringCol = @"c";
    c.realmIntCol = [[RLMInteger alloc] initWithValue:@900];
    c.realmNullableIntCol = [[RLMInteger alloc] initWithValue:@14];

    [realm addObject:c];

    [AllTypesObject createInRealm:realm withValue:@[@YES, @506, @7.7f, @8.8, @"banach", bin2,
                                                     timeNow, @YES, @(-20), NSNull.null, @85, @7]];
    [realm commitWriteTransaction];

    AllTypesObject *row1 = [AllTypesObject allObjects][0];
    AllTypesObject *row2 = [AllTypesObject allObjects][1];

    XCTAssertEqual(row1.boolCol, NO,                    @"row1.BoolCol");
    XCTAssertEqual(row2.boolCol, YES,                   @"row2.BoolCol");
    XCTAssertEqual(row1.intCol, 54,                     @"row1.IntCol");
    XCTAssertEqual(row2.intCol, 506,                    @"row2.IntCol");
    XCTAssertEqual(row1.floatCol, 0.7f,                 @"row1.FloatCol");
    XCTAssertEqual(row2.floatCol, 7.7f,                 @"row2.FloatCol");
    XCTAssertEqual(row1.doubleCol, 0.8,                 @"row1.DoubleCol");
    XCTAssertEqual(row2.doubleCol, 8.8,                 @"row2.DoubleCol");
    XCTAssertTrue([row1.stringCol isEqual:@"foo"],      @"row1.StringCol");
    XCTAssertTrue([row2.stringCol isEqual:@"banach"],   @"row2.StringCol");
    XCTAssertTrue([row1.binaryCol isEqual:bin1],        @"row1.BinaryCol");
    XCTAssertTrue([row2.binaryCol isEqual:bin2],        @"row2.BinaryCol");
    XCTAssertTrue(([row1.dateCol isEqual:timeZero]),    @"row1.DateCol");
    XCTAssertTrue(([row2.dateCol isEqual:timeNow]),     @"row2.DateCol");
    XCTAssertEqual(row1.cBoolCol, false,                @"row1.cBoolCol");
    XCTAssertEqual(row2.cBoolCol, true,                 @"row2.cBoolCol");
    XCTAssertEqual(row1.longCol, 99L,                   @"row1.IntCol");
    XCTAssertEqual(row2.longCol, -20L,                  @"row2.IntCol");
    XCTAssertTrue([row1.objectCol.stringCol isEqual:@"c"], @"row1.objectCol");
    XCTAssertNil(row2.objectCol,                        @"row2.objectCol");
    XCTAssertEqualObjects(row1.realmIntCol.value, @900,         @"row1.realmIntCol");
    XCTAssertEqualObjects(row2.realmIntCol.value, @85,          @"row2.realmIntCol");
    XCTAssertEqualObjects(row1.realmNullableIntCol.value, @14, @"row1.nullableRealmIntCol");
    XCTAssertEqualObjects(row2.realmNullableIntCol.value, @7,  @"row2.nullableRealmIntCol");


    [realm transactionWithBlock:^{
        row1.boolCol = NO;
        row1.cBoolCol = false;
        row1.boolCol = (BOOL)6;
        row1.cBoolCol = (BOOL)6;
    }];
    XCTAssertEqual(row1.boolCol, true);
    XCTAssertEqual(row1.cBoolCol, true);

    AllTypesObject *o = [[AllTypesObject alloc] initWithValue:row1];
    o.floatCol = NAN;
    o.doubleCol = NAN;
    [realm transactionWithBlock:^{
        [realm addObject:o];
    }];
    XCTAssertTrue(isnan(o.floatCol));
    XCTAssertTrue(isnan(o.doubleCol));
}

- (void)testObjectSubclass {
    // test className methods
    XCTAssertEqualObjects(@"StringObject", [StringObject className]);
    XCTAssertEqualObjects(@"StringSubclassObject", [StringSubclassObject className]);

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [StringObject createInDefaultRealmWithValue:@[@"string"]];
    StringSubclassObject *obj = [StringSubclassObject createInDefaultRealmWithValue:@[@"string", @"string2"]];

    // ensure property ordering
    XCTAssertEqualObjects([obj.objectSchema.properties[0] name], @"stringCol");
    XCTAssertEqualObjects([obj.objectSchema.properties[1] name], @"stringCol2");

    [realm commitWriteTransaction];

    // ensure creation in proper table
    RLMResults *results = StringSubclassObject.allObjects;
    XCTAssertEqual(1U, results.count);
    XCTAssertEqual(1U, StringObject.allObjects.count);

    // ensure exceptions on when using polymorphism
    [realm beginWriteTransaction];
    StringLinkObject *linkObject = [StringLinkObject createInDefaultRealmWithValue:@[NSNull.null, @[]]];
    RLMAssertThrowsWithReasonMatching(linkObject.stringObjectCol = obj,
                                      @"Can't .*StringSubclassObject.*StringObject");
    RLMAssertThrowsWithReasonMatching([linkObject.stringObjectArrayCol addObject:obj],
                                      @"Object of type .*StringSubclassObject.*does not match.*StringObject.*");
    [realm commitWriteTransaction];
}

- (void)testDateDistantFuture {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    DateObject *dateObject = [DateObject createInRealm:realm withValue:@[NSDate.distantFuture]];
    [realm commitWriteTransaction];
    XCTAssertEqualObjects(NSDate.distantFuture, dateObject.dateCol);
}

- (void)testDateDistantPast {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    DateObject *dateObject = [DateObject createInRealm:realm withValue:@[NSDate.distantPast]];
    [realm commitWriteTransaction];
    XCTAssertEqualObjects(NSDate.distantPast, dateObject.dateCol);
}

- (void)testDate50kYears {
    NSCalendarUnit units = (NSCalendarUnit)(NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitDay);
    NSDateComponents *components = [[NSCalendar currentCalendar] components:units fromDate:NSDate.date];
    components.calendar = [NSCalendar currentCalendar];
    components.year += 50000;

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    DateObject *dateObject = [DateObject createInRealm:realm withValue:@[components.date]];
    [realm commitWriteTransaction];

    XCTAssertEqualObjects(components.date, dateObject.dateCol);
}

static void testDatesInRange(NSTimeInterval from, NSTimeInterval to, void (^check)(NSDate *, NSDate *)) {
    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:from];

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    DateObject *dateObject = [DateObject createInRealm:realm withValue:@[date]];

    while (from < to) @autoreleasepool {
        check(dateObject.dateCol, date);
        from = nextafter(from, DBL_MAX);
        date = [NSDate dateWithTimeIntervalSinceReferenceDate:from];
        dateObject.dateCol = date;
    }
    [realm commitWriteTransaction];
}

- (void)testExactRepresentationOfDatesAroundNow {
    NSDate *date = [NSDate date];
    NSTimeInterval time = date.timeIntervalSinceReferenceDate;
    testDatesInRange(time - .001, time + .001, ^(NSDate *d1, NSDate *d2) {
        XCTAssertEqualObjects(d1, d2);
    });
}

- (void)testExactRepresentationOfDatesAroundDistantFuture {
    NSDate *date = [NSDate distantFuture];
    NSTimeInterval time = date.timeIntervalSinceReferenceDate;
    testDatesInRange(time - .001, time + .001, ^(NSDate *d1, NSDate *d2) {
        XCTAssertEqualObjects(d1, d2);
    });
}

- (void)testExactRepresentationOfDatesAroundEpoch {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
    NSTimeInterval time = date.timeIntervalSinceReferenceDate;
    testDatesInRange(time - .001, time + .001, ^(NSDate *d1, NSDate *d2) {
        XCTAssertEqualObjects(d1, d2);
    });
}

- (void)testExactRepresentationOfDatesAroundReferenceDate {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];

    NSDate *zero = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    DateObject *dateObject = [DateObject createInRealm:realm withValue:@[zero]];
    XCTAssertEqualObjects(dateObject.dateCol, zero);

    // Just shy of 1ns should still be zero
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:nextafter(1e-9, -DBL_MAX)];
    XCTAssertEqualObjects(dateObject.dateCol, zero);

    // Very slightly over 1ns (since 1e-9 can't be exactly represented by a double)
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:1e-9];
    XCTAssertNotEqualObjects(dateObject.dateCol, zero);

    // Round toward zero, so -1ns + epsilon is zero
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:nextafter(0, -DBL_MAX)];
    XCTAssertEqualObjects(dateObject.dateCol, zero);
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:nextafter(-1e-9, DBL_MAX)];
    XCTAssertEqualObjects(dateObject.dateCol, zero);

    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:-1e-9];
    XCTAssertNotEqualObjects(dateObject.dateCol, zero);

    [realm commitWriteTransaction];
}

- (void)testDatesOutsideOfTimestampRange {
    NSDate *date = [NSDate date];
    NSDate *maxDate = [NSDate dateWithTimeIntervalSince1970:(double)(1ULL << 63) + .999999999];
    NSDate *minDate = [NSDate dateWithTimeIntervalSince1970:-(double)(1ULL << 63) - .999999999];
    NSDate *justOverMaxDate = [NSDate dateWithTimeIntervalSince1970:nextafter(maxDate.timeIntervalSince1970, DBL_MAX)];
    NSDate *justUnderMaxDate = [NSDate dateWithTimeIntervalSince1970:nextafter(maxDate.timeIntervalSince1970, -DBL_MAX)];
    NSDate *justOverMinDate = [NSDate dateWithTimeIntervalSince1970:nextafter(minDate.timeIntervalSince1970, DBL_MAX)];
    NSDate *justUnderMinDate = [NSDate dateWithTimeIntervalSince1970:nextafter(minDate.timeIntervalSince1970, -DBL_MAX)];

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    DateObject *dateObject = [DateObject createInRealm:realm withValue:@[date]];

    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0/0.0];
    XCTAssertEqualObjects(dateObject.dateCol, [NSDate dateWithTimeIntervalSince1970:0]);

    dateObject.dateCol = maxDate;
    XCTAssertEqualObjects(dateObject.dateCol, maxDate);
    dateObject.dateCol = justOverMaxDate;
    XCTAssertEqualObjects(dateObject.dateCol, maxDate);
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:DBL_MAX];
    XCTAssertEqualObjects(dateObject.dateCol, maxDate);
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:1.0/0.0];
    XCTAssertEqualObjects(dateObject.dateCol, maxDate);

    dateObject.dateCol = minDate;
    XCTAssertEqualObjects(dateObject.dateCol, minDate);
    dateObject.dateCol = justUnderMinDate;
    XCTAssertEqualObjects(dateObject.dateCol, minDate);
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:-DBL_MAX];
    XCTAssertEqualObjects(dateObject.dateCol, minDate);
    dateObject.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:-1.0/0.0];
    XCTAssertEqualObjects(dateObject.dateCol, minDate);

    dateObject.dateCol = justUnderMaxDate;
    XCTAssertEqualObjects(dateObject.dateCol, justUnderMaxDate);

    dateObject.dateCol = justOverMinDate;
    XCTAssertEqualObjects(dateObject.dateCol, justOverMinDate);

    [realm commitWriteTransaction];
}

- (void)testDataSizeLimits {
    RLMRealm *realm = [RLMRealm defaultRealm];

    // Allocation must be < 16 MB, with an 8-byte header and the allocation size
    // 8-byte aligned
    static const int maxSize = 0xFFFFFF - 15;

    // Multiple 16 MB blobs should be fine
    void *buffer = malloc(maxSize);
    strcpy((char *)buffer + maxSize - sizeof("hello") - 1, "hello");
    DataObject *obj = [[DataObject alloc] init];
    obj.data1 = obj.data2 = [NSData dataWithBytesNoCopy:buffer length:maxSize freeWhenDone:YES];

    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];

    XCTAssertEqual(maxSize, obj.data1.length);
    XCTAssertEqual(maxSize, obj.data2.length);
    XCTAssertTrue(strcmp((const char *)obj.data1.bytes + obj.data1.length - sizeof("hello") - 1, "hello") == 0);
    XCTAssertTrue(strcmp((const char *)obj.data2.bytes + obj.data2.length - sizeof("hello") - 1, "hello") == 0);

    // A blob over 16 MB should throw (and not crash)
    [realm beginWriteTransaction];
    RLMAssertThrowsWithReason(obj.data1 = [NSData dataWithBytesNoCopy:malloc(maxSize + 1)
                                                               length:maxSize + 1 freeWhenDone:YES],
                              @"Binary too big");
    [realm commitWriteTransaction];
}

- (void)testStringSizeLimits {
    RLMRealm *realm = [RLMRealm defaultRealm];

    // Allocation must be < 16 MB, with an 8-byte header, trailing NUL,  and the
    // allocation size 8-byte aligned
    static const int maxSize = 0xFFFFFF - 16;

    void *buffer = calloc(maxSize, 1);
    strcpy((char *)buffer + maxSize - sizeof("hello") - 1, "hello");
    NSString *str = [[NSString alloc] initWithBytesNoCopy:buffer length:maxSize
                                                 encoding:NSUTF8StringEncoding freeWhenDone:YES];
    StringObject *obj = [[StringObject alloc] init];
    obj.stringCol = str;

    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];

    XCTAssertEqualObjects(str, obj.stringCol);

    // A blob over 16 MB should throw (and not crash)
    [realm beginWriteTransaction];
    XCTAssertThrows(obj.stringCol = [[NSString alloc] initWithBytesNoCopy:calloc(maxSize + 1, 1)
                                                                   length:maxSize + 1
                                                                 encoding:NSUTF8StringEncoding
                                                             freeWhenDone:YES]);
    [realm commitWriteTransaction];
}

- (void)testAddingObjectNotInSchemaThrows {
    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.objectClasses = @[StringObject.class];
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];

    [realm beginWriteTransaction];
    RLMAssertThrowsWithReasonMatching([realm addObject:[[IntObject alloc] initWithValue:@[@1]]],
                                      @"Object type 'IntObject' is not managed by the Realm.*custom `objectClasses`");
    RLMAssertThrowsWithReasonMatching([IntObject createInRealm:realm withValue:@[@1]],
                                      @"Object type 'IntObject' is not managed by the Realm.*custom `objectClasses`");
    XCTAssertNoThrow([realm addObject:[[StringObject alloc] initWithValue:@[@"A"]]]);
    XCTAssertNoThrow([StringObject createInRealm:realm withValue:@[@"A"]]);
    [realm cancelWriteTransaction];
}

static void addProperty(Class cls, const char *name, const char *type, size_t size, size_t align, id getter) {
    objc_property_attribute_t objectColAttrs[] = {
        {"T", type},
        {"V", name},
    };
    class_addIvar(cls, name, size, align, type);
    class_addProperty(cls, name, objectColAttrs, sizeof(objectColAttrs) / sizeof(objc_property_attribute_t));

    char encoding[4] = " @:";
    encoding[0] = *type;
    class_addMethod(cls, sel_registerName(name), imp_implementationWithBlock(getter), encoding);
}

- (void)testObjectSubclassAddedAtRuntime {
    Class objectClass = objc_allocateClassPair(RLMObject.class, "RuntimeGeneratedObject", 0);
    addProperty(objectClass, "objectCol", "@\"RuntimeGeneratedObject\"", sizeof(id), alignof(id), ^(__unused id obj) { return nil; });
    addProperty(objectClass, "intCol", "i", sizeof(int), alignof(int), ^int(__unused id obj) { return 0; });
    objc_registerClassPair(objectClass);
    XCTAssertEqualObjects([objectClass className], @"RuntimeGeneratedObject");

    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.objectClasses = @[objectClass];
    XCTAssertEqualObjects([objectClass className], @"RuntimeGeneratedObject");

    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];
    [realm beginWriteTransaction];
    id object = [objectClass createInRealm:realm withValue:@{@"objectCol": [[objectClass alloc] init], @"intCol": @17}];
    RLMObjectSchema *schema = [object objectSchema];
    XCTAssertNotNil(schema[@"objectCol"]);
    XCTAssertNotNil(schema[@"intCol"]);
    XCTAssert([[object objectCol] isKindOfClass:objectClass]);
    XCTAssertEqual([object intCol], 17);
    [realm commitWriteTransaction];
}

#pragma mark - Realm integers

- (void)testRealmIntBasicFunctionality {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmIntObject *obj = [[RealmIntObject alloc] init];
    obj.realmInt.value = @100;
    XCTAssertEqual(obj.realmInt.value.integerValue, 100);

    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 100);

    // Increment the int
    [realm beginWriteTransaction];
    [obj.realmInt incrementValueBy:8901];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 9001);

    // Set the int
    [realm beginWriteTransaction];
    obj.realmInt.value = @123;
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 123);
}

- (void)testCreateRealmIntFromValue {
    RLMRealm *realm = [RLMRealm defaultRealm];

    // Required Realm integer
    [realm beginWriteTransaction];
    [RealmIntObject createInRealm:realm withValue:@[@100]];
    [realm commitWriteTransaction];

    RealmIntObject *object = [[RealmIntObject allObjectsInRealm:realm] firstObject];
    XCTAssertNotNil(object);
    XCTAssertEqual(object.realmInt.value.integerValue, 100);

    // Non-required Realm integer with non-nil value
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [RealmNullableIntObject createInRealm:realm withValue:@[@200]];
    [realm commitWriteTransaction];

    RealmIntObject *object2 = [[RealmNullableIntObject allObjectsInRealm:realm] firstObject];
    XCTAssertNotNil(object2);
    XCTAssertEqual(object2.realmInt.value.integerValue, 200);

    // Non-required Realm integer with nil value
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [RealmNullableIntObject createInRealm:realm withValue:@[NSNull.null]];
    [realm commitWriteTransaction];

    RealmIntObject *object3 = [[RealmNullableIntObject allObjectsInRealm:realm] firstObject];
    XCTAssertNotNil(object3);
    XCTAssertNil(object3.realmInt.value);
}

/// Check that calling `RLMInteger` APIs works as expected throughout the object lifecycle.
- (void)testRealmIntManagementLifecycle {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmIntObject *obj = [[RealmIntObject alloc] init];
    obj.realmInt.value = @100;
    XCTAssertEqual(obj.realmInt.value.integerValue, 100);

    // Before attachment:
    obj.realmInt.value = @200;
    XCTAssertEqual(obj.realmInt.value.integerValue, 200);

    obj.realmInt = [[RLMInteger alloc] initWithValue:@300];
    XCTAssertEqual(obj.realmInt.value.integerValue, 300);

    // When attached:
    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 300);

    // When not in a write transaction:
    XCTAssertThrows(obj.realmInt.value = @400);
    XCTAssertThrows([obj.realmInt incrementValueBy:123]);

    // When unattached:
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [realm commitWriteTransaction];

    XCTAssertThrows(obj.realmInt.value);
}

/// Check that assigning to a `RLMInteger` property works as expected throughout the object lifecycle.
- (void)testReassignmentToRealmIntProperty {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmIntObject *obj = [[RealmIntObject alloc] init];
    // Getting a RLMInteger property that wasn't initialized should work fine.
    XCTAssertNotNil(obj.realmInt);
    XCTAssertEqual(obj.realmInt.value.integerValue, 0);

    // Before attachment:
    obj.realmInt = [[RLMInteger alloc] initWithValue:@101];
    XCTAssertEqual(obj.realmInt.value.integerValue, 101);

    // When attached:
    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 101);

    [realm beginWriteTransaction];
    obj.realmInt = [[RLMInteger alloc] initWithValue:@201];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 201);

    // When not in a write transaction:
    XCTAssertThrows(obj.realmInt = [[RLMInteger alloc] initWithValue:@301]);

    // When unattached:
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [realm commitWriteTransaction];

    XCTAssertThrows(obj.realmInt = [[RLMInteger alloc] initWithValue:@401]);
}

- (void)testNullableRealmIntBasicFunctionality {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmNullableIntObject *obj = [[RealmNullableIntObject alloc] init];
    obj.realmInt.value = @100;
    XCTAssertEqual(obj.realmInt.value.integerValue, 100);

    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 100);

    // Increment the int
    [realm beginWriteTransaction];
    [obj.realmInt incrementValueBy:8901];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 9001);

    // Set the int
    [realm beginWriteTransaction];
    obj.realmInt.value = @123;
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 123);
}

- (void)testCreateNullableRealmIntFromValue {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    [RealmNullableIntObject createInRealm:realm withValue:@[@100]];
    [realm commitWriteTransaction];

    RealmNullableIntObject *object = [[RealmNullableIntObject allObjectsInRealm:realm] firstObject];
    XCTAssertNotNil(object);
    XCTAssertEqual(object.realmInt.value.integerValue, 100);

    // Now try with a null.
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [RealmNullableIntObject createInRealm:realm withValue:@[[NSNull null]]];
    [realm commitWriteTransaction];

    object = [[RealmNullableIntObject allObjectsInRealm:realm] firstObject];
    XCTAssertNotNil(object);
    XCTAssertNil(object.realmInt.value);
}

/// Check that calling `RLMInteger` APIs works as expected throughout the object lifecycle.
- (void)testRealmNullableIntManagementLifecycle {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmNullableIntObject *obj = [[RealmNullableIntObject alloc] init];
    obj.realmInt.value = @100;
    XCTAssertEqual(obj.realmInt.value.integerValue, 100);

    // Before attachment:
    obj.realmInt.value = @200;
    XCTAssertEqual(obj.realmInt.value.integerValue, 200);

    obj.realmInt.value = nil;
    XCTAssertNil(obj.realmInt.value);

    obj.realmInt = [[RLMInteger alloc] initWithValue:@300];
    XCTAssertEqual(obj.realmInt.value.integerValue, 300);

    // When attached:
    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 300);

    [realm beginWriteTransaction];
    obj.realmInt.value = nil;
    [realm commitWriteTransaction];
    XCTAssertNil(obj.realmInt.value);

    // When not in a write transaction:
    XCTAssertThrows(obj.realmInt.value = @400);
    XCTAssertThrows([obj.realmInt incrementValueBy:123]);

    // When unattached:
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [realm commitWriteTransaction];

    XCTAssertThrows(obj.realmInt.value);
}

/// Adding a nil Realm integer, or setting a Realm integer to nil, should fail if the integer is required.
- (void)testAddingRequiredRealmIntRejectsNil {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmIntObject *obj = [[RealmIntObject alloc] init];
    obj.realmInt.value = nil;

    // Try adding the object.
    [realm beginWriteTransaction];
    XCTAssertThrows([realm addObject:obj]);
    [realm cancelWriteTransaction];

    // Create another object and successfully add it.
    RealmIntObject *obj2 = [[RealmIntObject alloc] init];
    obj2.realmInt.value = @10;
    [realm beginWriteTransaction];
    [realm addObject:obj2];
    [realm commitWriteTransaction];

    // Now try changing its value to nil.
    [realm beginWriteTransaction];
    XCTAssertThrows(obj2.realmInt.value = nil);
    [realm cancelWriteTransaction];
}

/// Check that assigning to a `RLMInteger` property works as expected throughout the object lifecycle.
- (void)testReassignmentToNullableRealmIntProperty {
    RLMRealm *realm = [RLMRealm defaultRealm];

    RealmNullableIntObject *obj = [[RealmNullableIntObject alloc] init];
    // Getting a RLMInteger property that wasn't initialized should work fine.
    XCTAssertNotNil(obj.realmInt);
    XCTAssertEqual(obj.realmInt.value.integerValue, 0);

    // Before attachment:
    obj.realmInt = nil;
    XCTAssertNotNil(obj.realmInt);
    XCTAssertEqual(obj.realmInt.value.integerValue, 0);
    obj.realmInt = [[RLMInteger alloc] initWithValue:@101];
    XCTAssertEqual(obj.realmInt.value.integerValue, 101);

    // When attached:
    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 101);

    [realm beginWriteTransaction];
    obj.realmInt = nil;
    [realm commitWriteTransaction];
    XCTAssertNotNil(obj.realmInt);
    XCTAssertNil(obj.realmInt.value);

    [realm beginWriteTransaction];
    obj.realmInt = [[RLMInteger alloc] initWithValue:@201];
    [realm commitWriteTransaction];
    XCTAssertEqual(obj.realmInt.value.integerValue, 201);

    // When not in a write transaction:
    XCTAssertThrows(obj.realmInt = nil);
    XCTAssertThrows(obj.realmInt = [[RLMInteger alloc] initWithValue:@301]);

    // When unattached:
    [realm beginWriteTransaction];
    [realm deleteAllObjects];
    [realm commitWriteTransaction];
    
    XCTAssertThrows(obj.realmInt = nil);
    XCTAssertThrows(obj.realmInt = [[RLMInteger alloc] initWithValue:@401]);
}

#pragma mark - Default Property Values

- (NSDictionary *)defaultValuesDictionary {
    return @{@"intCol"    : @98,
             @"floatCol"  : @231.0f,
             @"doubleCol": @123732.9231,
             @"boolCol"   : @NO,
             @"dateCol"   : [NSDate dateWithTimeIntervalSince1970:454321],
             @"stringCol": @"Westeros",
             @"binaryCol": [@"inputData" dataUsingEncoding:NSUTF8StringEncoding]};
}

- (void)testDefaultValuesFromNoValuePresent {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];

    NSDictionary *inputValues = [self defaultValuesDictionary];
    NSArray *keys = [inputValues allKeys]; // To ensure iteration order is stable
    for (NSString *key in keys) {
        NSMutableDictionary *dict = [inputValues mutableCopy];
        [dict removeObjectForKey:key];
        [DefaultObject createInRealm:realm withValue:dict];
    }

    [realm commitWriteTransaction];

    // Test allObject for DefaultObject
    NSDictionary *defaultValues = [DefaultObject defaultPropertyValues];
    RLMResults *allObjects = [DefaultObject allObjectsInRealm:realm];
    for (NSUInteger i = 0; i < keys.count; ++i) {
        DefaultObject *object = allObjects[i];
        for (NSUInteger j = 0; j < keys.count; ++j) {
            NSString *key = keys[j];
            if (i == j) {
                XCTAssertEqualObjects(object[key], defaultValues[key]);
            }
            else {
                XCTAssertEqualObjects(object[key], inputValues[key]);
            }
        }
    }
}

- (void)testDefaultValuesFromNSNull {
    RLMRealm *realm = [RLMRealm defaultRealm];

    NSDictionary *defaultValues = [DefaultObject defaultPropertyValues];
    NSDictionary *inputValues = [self defaultValuesDictionary];
    NSArray *keys = [inputValues allKeys]; // To ensure iteration order is stable
    for (NSString *key in keys) {
        NSMutableDictionary *dict = [inputValues mutableCopy];
        dict[key] = NSNull.null;
        RLMProperty *prop = realm.schema[@"DefaultObject"][key];
        if (prop.optional) {
            [realm beginWriteTransaction];
            [DefaultObject createInRealm:realm withValue:dict];
            [realm commitWriteTransaction];

            DefaultObject *object = DefaultObject.allObjects.lastObject;
            for (NSUInteger j = 0; j < keys.count; ++j) {
                NSString *key2 = keys[j];
                if ([key isEqualToString:key2]) {
                    XCTAssertEqualObjects(object[key2], prop.optional ? nil : defaultValues[key2]);
                }
                else {
                    XCTAssertEqualObjects(object[key2], inputValues[key2]);
                }
            }
        }
        else {
            [realm beginWriteTransaction];
            RLMAssertThrowsWithReason([DefaultObject createInRealm:realm withValue:dict],
                                      @"Invalid value '<null>' of type 'NSNull' for ");
            [realm commitWriteTransaction];
        }
    }
}

- (void)testDefaultNSNumberPropertyValues {
    void (^assertDefaults)(NumberObject *) = ^(NumberObject *no) {
        XCTAssertEqualObjects(no.intObj, @1);
        XCTAssertEqualObjects(no.floatObj, @2.2f);
        XCTAssertEqualObjects(no.doubleObj, @3.3);
        XCTAssertEqualObjects(no.boolObj, @NO);
    };

    assertDefaults([[NumberDefaultsObject alloc] init]);

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    assertDefaults([NumberDefaultsObject createInRealm:realm withValue:@{}]);
    [realm cancelWriteTransaction];
}

- (void)testDynamicDefaultPropertyValues {
    void (^assertDifferentPropertyValues)(DynamicDefaultObject *, DynamicDefaultObject *) = ^(DynamicDefaultObject *obj1, DynamicDefaultObject *obj2) {
        XCTAssertNotEqual(obj1.intCol, obj2.intCol);
        XCTAssertNotEqual(obj1.floatCol, obj2.floatCol);
        XCTAssertNotEqual(obj1.doubleCol, obj2.doubleCol);
        XCTAssertNotEqualWithAccuracy(obj1.dateCol.timeIntervalSinceReferenceDate, obj2.dateCol.timeIntervalSinceReferenceDate, 0.01f);
        XCTAssertNotEqualObjects(obj1.stringCol, obj2.stringCol);
        XCTAssertNotEqualObjects(obj1.binaryCol, obj2.binaryCol);
    };
    assertDifferentPropertyValues([[DynamicDefaultObject alloc] init], [[DynamicDefaultObject alloc] init]);
    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.objectClasses = @[[DynamicDefaultObject class]];
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];
    [realm beginWriteTransaction];
    assertDifferentPropertyValues([DynamicDefaultObject createInRealm:realm withValue:@{}], [DynamicDefaultObject createInRealm:realm withValue:@{}]);
    [realm cancelWriteTransaction];
}

#pragma mark - Ignored Properties

- (void)testCanUseIgnoredProperty {
    NSURL *url = [NSURL URLWithString:@"http://realm.io"];
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];

    IgnoredURLObject *obj = [IgnoredURLObject new];
    obj.name = @"Realm";
    obj.url = url;
    [realm addObject:obj];
    XCTAssertEqual(obj.url, url, @"ignored properties should still be assignable and gettable inside a write block");

    [realm commitWriteTransaction];

    XCTAssertEqual(obj.url, url, @"ignored properties should still be assignable and gettable outside a write block");

    IgnoredURLObject *obj2 = [[IgnoredURLObject objectsWithPredicate:nil] firstObject];
    XCTAssertNotNil(obj2, @"object with ignored property should still be stored and accessible through the realm");

    XCTAssertEqualObjects(obj2.name, obj.name, @"managed property should be the same");
    XCTAssertNil(obj2.url, @"ignored property should be nil when getting from realm");
}

- (void)testCreateInRealmValidationForDictionary {
    RLMRealm *realm = [RLMRealm defaultRealm];

    const char bin[4] = { 0, 1, 2, 3 };
    NSData *bin1 = [[NSData alloc] initWithBytes:bin length:sizeof bin / 2];
    NSDate *timeNow = [NSDate dateWithTimeIntervalSince1970:1000000];
    NSDictionary * const dictValidAllTypes = @{@"boolCol"   : @NO,
                                               @"intCol"    : @54,
                                               @"floatCol"  : @0.7f,
                                               @"doubleCol": @0.8,
                                               @"stringCol": @"foo",
                                               @"binaryCol": bin1,
                                               @"dateCol"   : timeNow,
                                               @"cBoolCol"  : @NO,
                                               @"longCol"   : @(99),
                                               @"objectCol" : NSNull.null,
                                               @"realmIntCol"           : @50,
                                               @"realmNullableIntCol"   : NSNull.null};

    [realm beginWriteTransaction];

    // Test NSDictonary
    XCTAssertNoThrow(([AllTypesObject createInRealm:realm withValue:dictValidAllTypes]),
                     @"Creating object with valid value types should not throw exception");

    for (NSString *keyToInvalidate in dictValidAllTypes.allKeys) {
        NSMutableDictionary *invalidInput = [dictValidAllTypes mutableCopy];
        id obj = @"invalid";
        if ([keyToInvalidate isEqualToString:@"stringCol"]) {
            obj = @1;
        }

        invalidInput[keyToInvalidate] = obj;

        RLMAssertThrowsWithReasonMatching([AllTypesObject createInRealm:realm withValue:invalidInput],
                                          @"Invalid value '.*'");
    }


    [realm commitWriteTransaction];
}

- (void)testCreateInRealmValidationForArray {
    RLMRealm *realm = [RLMRealm defaultRealm];

    // add test/link object to realm
    [realm beginWriteTransaction];
    StringObject *to = [StringObject createInRealm:realm withValue:@[@"c"]];
    [realm commitWriteTransaction];

    const char bin[4] = { 0, 1, 2, 3 };
    NSData *bin1 = [[NSData alloc] initWithBytes:bin length:sizeof bin / 2];
    NSDate *timeNow = [NSDate dateWithTimeIntervalSince1970:1000000];
    NSArray *const arrayValidAllTypes = @[@NO, @54, @0.7f, @0.8, @"foo", bin1, timeNow, @NO, @(99), to, @3, NSNull.null];

    [realm beginWriteTransaction];

    // Test NSArray
    XCTAssertNoThrow(([AllTypesObject createInRealm:realm withValue:arrayValidAllTypes]),
                     @"Creating object with valid value types should not throw exception");

    const NSInteger stringColIndex = 4;
    for (NSUInteger i = 0; i < arrayValidAllTypes.count; i++) {
        NSMutableArray *invalidInput = [arrayValidAllTypes mutableCopy];

        id obj = @"invalid";
        if (i == stringColIndex) {
            obj = @1;
        }

        invalidInput[i] = obj;

        RLMAssertThrowsWithReasonMatching([AllTypesObject createInRealm:realm withValue:invalidInput],
                                          @"Invalid value '.*'");
    }

    [realm commitWriteTransaction];
}

- (void)testCreateInRealmReusesExistingObjects {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];

    DogObject *dog = [DogObject createInDefaultRealmWithValue:@[@"Fido", @5]];
    OwnerObject *owner = [OwnerObject createInDefaultRealmWithValue:@[@"name", dog]];
    XCTAssertTrue([owner.dog isEqualToObject:dog]);
    XCTAssertEqual(1U, DogObject.allObjects.count);

    DogArrayObject *dogArray = [DogArrayObject createInDefaultRealmWithValue:@[@[dog]]];
    XCTAssertTrue([dogArray.dogs[0] isEqualToObject:dog]);
    XCTAssertEqual(1U, DogObject.allObjects.count);

    [realm commitWriteTransaction];
}

- (void)testCreateInRealmReusesExistingNestedObjectsByPrimaryKey {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    PrimaryEmployeeObject *eo = [PrimaryEmployeeObject createInRealm:realm withValue:@[@"Samuel", @19, @NO]];
    PrimaryCompanyObject *co = [PrimaryCompanyObject createInRealm:realm withValue:@[@"Realm", @[eo], eo, @[eo]]];
    [realm commitWriteTransaction];

    [realm beginWriteTransaction];
    [PrimaryCompanyObject createOrUpdateInRealm:realm withValue:@{
                                                                   @"name": @"Realm",
                                                                   @"intern": @{@"name":@"Samuel", @"hired":@YES},
                                                                   }];
    [realm commitWriteTransaction];

    XCTAssertEqual(1U, co.employees.count);
    XCTAssertEqual(1U, [PrimaryEmployeeObject allObjectsInRealm:realm].count);
    XCTAssertEqualObjects(@"Samuel", eo.name);
    XCTAssertEqual(YES, eo.hired);
    XCTAssertEqual(19, eo.age);

    [realm beginWriteTransaction];
    [PrimaryCompanyObject createOrUpdateInRealm:realm withValue:@{
                                                                   @"name": @"Realm",
                                                                   @"employees": @[@{@"name":@"Samuel", @"hired":@NO}],
                                                                   @"intern": @{@"name":@"Samuel", @"age":@20},
                                                                   }];
    [realm commitWriteTransaction];

    XCTAssertEqual(1U, co.employees.count);
    XCTAssertEqual(1U, [PrimaryEmployeeObject allObjectsInRealm:realm].count);
    XCTAssertEqualObjects(@"Samuel", eo.name);
    XCTAssertEqual(NO, eo.hired);
    XCTAssertEqual(20, eo.age);

    [realm beginWriteTransaction];
    [PrimaryCompanyObject createOrUpdateInRealm:realm withValue:@{@"name": @"Realm",
                                                                  @"wrappedIntern": @[eo]}];
    [realm commitWriteTransaction];
    XCTAssertEqual(1U, [[PrimaryEmployeeObject allObjectsInRealm:realm] count]);
}

- (void)testCreateInRealmCopiesFromOtherRealm {
    RLMRealm *realm1 = [RLMRealm defaultRealm];
    RLMRealm *realm2 = [self realmWithTestPath];
    [realm1 beginWriteTransaction];
    [realm2 beginWriteTransaction];

    DogObject *dog = [DogObject createInDefaultRealmWithValue:@[@"Fido", @5]];
    OwnerObject *owner = [OwnerObject createInRealm:realm2 withValue:@[@"name", dog]];
    XCTAssertFalse([owner.dog isEqualToObject:dog]);
    XCTAssertEqual(1U, DogObject.allObjects.count);
    XCTAssertEqual(1U, [DogObject allObjectsInRealm:realm2].count);

    DogArrayObject *dogArray = [DogArrayObject createInRealm:realm2 withValue:@[@[dog]]];
    XCTAssertFalse([dogArray.dogs[0] isEqualToObject:dog]);
    XCTAssertEqual(1U, DogObject.allObjects.count);
    XCTAssertEqual(2U, [DogObject allObjectsInRealm:realm2].count);

    [realm1 commitWriteTransaction];
    [realm2 commitWriteTransaction];
}

- (void)testCreateInRealmWithOtherObjects {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    DateObjectNoThrow *object = [DateObjectNoThrow createInDefaultRealmWithValue:@[NSDate.date, NSDate.date]];

    // create subclass with instance of base class with/without default objects
    XCTAssertNoThrow([DateSubclassObject createInDefaultRealmWithValue:object]);
    XCTAssertNoThrow([DateObjectNoThrow createInDefaultRealmWithValue:object]);

    // create using non-realm object with custom getter
    SubclassDateObject *obj = [SubclassDateObject new];
    obj.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:1000];
    obj.date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:2000];
    obj.date3 = [NSDate dateWithTimeIntervalSinceReferenceDate:3000];
    [DateDefaultsObject createInDefaultRealmWithValue:obj];

    XCTAssertEqual(2U, DateObjectNoThrow.allObjects.count);
    [realm commitWriteTransaction];
}

- (void)testObjectDescription {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];

    // Init object before adding to realm
    EmployeeObject *soInit = [[EmployeeObject alloc] init];
    soInit.name = @"Peter";
    soInit.age = 30;
    soInit.hired = YES;
    [realm addObject:soInit];

    // description asserts block
    void (^descriptionAsserts)(NSString *) = ^(NSString *description) {
        XCTAssertTrue([description rangeOfString:@"name"].location != NSNotFound,
                      @"column names should be displayed when calling \"description\" on RLMObject subclasses");
        XCTAssertTrue([description rangeOfString:@"Peter"].location != NSNotFound,
                      @"column values should be displayed when calling \"description\" on RLMObject subclasses");

        XCTAssertTrue([description rangeOfString:@"age"].location != NSNotFound,
                      @"column names should be displayed when calling \"description\" on RLMObject subclasses");
        XCTAssertTrue([description rangeOfString:[@30 description]].location != NSNotFound,
                      @"column values should be displayed when calling \"description\" on RLMObject subclasses");

        XCTAssertTrue([description rangeOfString:@"hired"].location != NSNotFound,
                      @"column names should be displayed when calling \"description\" on RLMObject subclasses");
        XCTAssertTrue([description rangeOfString:[@YES description]].location != NSNotFound,
                      @"column values should be displayed when calling \"description\" on RLMObject subclasses");
    };

    // Test description in write block
    descriptionAsserts(soInit.description);

    [realm commitWriteTransaction];

    // Test description in read block
    NSString *objDescription = [[[EmployeeObject objectsWithPredicate:nil] firstObject] description];
    descriptionAsserts(objDescription);

    soInit = [[EmployeeObject alloc] init];
    soInit.age = 20;
    XCTAssert([soInit.description rangeOfString:@"(null)"].location != NSNotFound);
}

- (void)testObjectCycleDescription {
    CycleObject *obj = [[CycleObject alloc] init];
    [RLMRealm.defaultRealm transactionWithBlock:^{
        [RLMRealm.defaultRealm addObject:obj];
        [obj.objects addObject:obj];
    }];
    XCTAssertNoThrow(obj.description);
}

- (void)testDataObjectDescription {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    char longData[200];
    [DataObject createInRealm:realm withValue:@[[NSData dataWithBytes:&longData length:200], [NSData dataWithBytes:&longData length:2]]];
    [realm commitWriteTransaction];

    DataObject *obj = [DataObject allObjectsInRealm:realm].firstObject;
    XCTAssertTrue([obj.description rangeOfString:@"200 total bytes"].location != NSNotFound);
    XCTAssertTrue([obj.description rangeOfString:@"2 total bytes"].location != NSNotFound);
}

- (void)testDeletedObjectDescription {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    EmployeeObject *obj = [EmployeeObject createInRealm:realm withValue:@[@"Peter", @30, @YES]];
    [realm deleteObject:obj];
    [realm commitWriteTransaction];

    XCTAssertNoThrow(obj.description);
}

- (void)testManagedObjectUnknownKey {
    IntObject *obj = [[IntObject alloc] init];
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];
    RLMAssertThrowsWithReason([obj objectForKeyedSubscript:@""],
                              @"Invalid property name '' for class 'IntObject'");
    RLMAssertThrowsWithReason([obj setObject:@0 forKeyedSubscript:@""],
                              @"Invalid property name '' for class 'IntObject'");
}

- (void)testUnmanagedRealmObjectUnknownKey {
    IntObject *obj = [[IntObject alloc] init];
    XCTAssertThrows([obj objectForKeyedSubscript:@""]);
    XCTAssertThrows([obj setObject:@0 forKeyedSubscript:@""]);
}

- (void)testEquality {
    IntObject *obj = [[IntObject alloc] init];
    IntObject *otherObj = [[IntObject alloc] init];

    RLMRealm *realm = [RLMRealm defaultRealm];
    RLMRealm *otherRealm = [self realmWithTestPath];

    XCTAssertFalse([obj isEqual:[NSObject new]], @"Comparing an RLMObject to a non-RLMObject should be false.");
    XCTAssertFalse([obj isEqualToObject:(RLMObject *)[NSObject new]], @"Comparing an RLMObject to a non-RLMObject should be false.");
    XCTAssertTrue([obj isEqual:obj], @"Same instance.");
    XCTAssertTrue([obj isEqualToObject:obj], @"Same instance.");
    XCTAssertFalse([obj isEqualToObject:otherObj], @"Comparison outside of realm.");

    [realm beginWriteTransaction];
    [realm addObject:obj];
    [realm commitWriteTransaction];

    XCTAssertFalse([obj isEqualToObject:otherObj], @"One in realm, the other is not.");
    XCTAssertTrue([obj isEqualToObject:[IntObject allObjects][0]], @"Same table and index.");

    [otherRealm beginWriteTransaction];
    [otherRealm addObject:otherObj];
    [otherRealm commitWriteTransaction];

    XCTAssertFalse([obj isEqualToObject:otherObj], @"Different realms.");

    [realm beginWriteTransaction];
    [realm addObject:[[IntObject alloc] init]];
    [realm addObject:[[BoolObject alloc] init]];
    [realm commitWriteTransaction];

    XCTAssertFalse([obj isEqualToObject:[IntObject allObjects][1]], @"Same table, different index.");
    XCTAssertFalse([obj isEqualToObject:[BoolObject allObjects][0]], @"Different tables.");
}

- (void)testCrossThreadAccess {
    IntObject *obj = [[IntObject alloc] init];

    // Unmanaged object can be accessed from other threads
    [self dispatchAsyncAndWait:^{ XCTAssertNoThrow(obj.intCol = 5); }];

    [RLMRealm.defaultRealm beginWriteTransaction];
    [RLMRealm.defaultRealm addObject:obj];
    [RLMRealm.defaultRealm commitWriteTransaction];

    [self dispatchAsyncAndWait:^{ RLMAssertThrowsWithReason(obj.intCol, @"incorrect thread"); }];
}

- (void)testIsDeleted {
    StringObject *obj1 = [[StringObject alloc] initWithValue:@[@"a"]];
    XCTAssertEqual(obj1.invalidated, NO);

    RLMRealm *realm = [self realmWithTestPath];
    [realm beginWriteTransaction];
    [realm addObject:obj1];
    StringObject *obj2 = [StringObject createInRealm:realm withValue:@[@"b"]];

    XCTAssertEqual([obj1 isInvalidated], NO);
    XCTAssertEqual(obj2.invalidated, NO);

    [realm commitWriteTransaction];

    // delete
    [realm beginWriteTransaction];
    // Delete directly
    [realm deleteObject:obj1];
    // Delete as result of query since then obj2's realm could point to a different instance
    [realm deleteObject:[[StringObject allObjectsInRealm:realm] firstObject]];

    XCTAssertEqual(obj1.invalidated, YES);
    XCTAssertEqual(obj2.invalidated, YES);

    RLMAssertThrowsWithReason([realm addObject:obj1], @"deleted or invalidated");

    NSArray *propObject = @[@"", @[obj2], @[]];
    RLMAssertThrowsWithReason([ArrayPropertyObject createInRealm:realm withValue:propObject],
                              @"deleted or invalidated");

    [realm commitWriteTransaction];

    XCTAssertEqual(obj1.invalidated, YES);
    XCTAssertNil(obj1.realm, @"Realm should be nil after deletion");
}

- (void)testPrimaryKey {
    [[RLMRealm defaultRealm] beginWriteTransaction];

    [PrimaryStringObject createInDefaultRealmWithValue:(@[@"string", @1])];
    [PrimaryStringObject createInDefaultRealmWithValue:(@[@"string2", @1])];
    RLMAssertThrowsWithReason([PrimaryStringObject createInDefaultRealmWithValue:(@[@"string", @1])],
                              @"existing primary key value");

    [PrimaryIntObject createInDefaultRealmWithValue:(@[@1])];
    [PrimaryIntObject createInDefaultRealmWithValue:(@{@"intCol": @2})];
    RLMAssertThrowsWithReason([PrimaryIntObject createInDefaultRealmWithValue:(@[@1])],
                              @"existing primary key value");

    [PrimaryInt64Object createInDefaultRealmWithValue:(@[@(1LL << 40)])];
    [PrimaryInt64Object createInDefaultRealmWithValue:(@[@(1LL << 41)])];
    RLMAssertThrowsWithReason([PrimaryInt64Object createInDefaultRealmWithValue:(@[@(1LL << 40)])],
                              @"existing primary key value");

    [PrimaryNullableIntObject createInDefaultRealmWithValue:@[@1]];
    [PrimaryNullableIntObject createInDefaultRealmWithValue:(@{@"optIntCol": @2, @"value": @0})];
    [PrimaryNullableIntObject createInDefaultRealmWithValue:@[NSNull.null]];
    RLMAssertThrowsWithReason([PrimaryNullableIntObject createInDefaultRealmWithValue:(@[@1, @0])],
                              @"existing primary key value");
    RLMAssertThrowsWithReason([PrimaryNullableIntObject createInDefaultRealmWithValue:(@[NSNull.null, @0])],
                              @"existing primary key value");

    [[RLMRealm defaultRealm] commitWriteTransaction];
}

- (void)testCreateOrUpdate {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];

    [PrimaryNullableStringObject createOrUpdateInDefaultRealmWithValue:@[@"string", @1]];
    RLMResults *objects = [PrimaryNullableStringObject allObjects];
    XCTAssertEqual([objects count], 1U, @"Should have 1 object");
    XCTAssertEqual([(PrimaryNullableStringObject *)objects[0] intCol], 1, @"Value should be 1");

    [PrimaryNullableStringObject createOrUpdateInRealm:realm withValue:@{@"stringCol": @"string2", @"intCol": @2}];
    XCTAssertEqual([objects count], 2U, @"Should have 2 objects");

    [PrimaryNullableStringObject createOrUpdateInRealm:realm withValue:@{@"intCol": @5}];
    [PrimaryNullableStringObject createOrUpdateInRealm:realm withValue:@{@"intCol": @7}];
    XCTAssertEqual([PrimaryNullableStringObject objectInRealm:realm forPrimaryKey:NSNull.null].intCol, 7);
    [PrimaryNullableStringObject createOrUpdateInRealm:realm withValue:@{@"stringCol": NSNull.null, @"intCol": @11}];
    XCTAssertEqual([PrimaryNullableStringObject objectInRealm:realm forPrimaryKey:nil].intCol, 11);

    // upsert with new secondary property
    [PrimaryNullableStringObject createOrUpdateInDefaultRealmWithValue:@[@"string", @3]];
    XCTAssertEqual([objects count], 3U, @"Should have 3 objects");
    XCTAssertEqual([(PrimaryNullableStringObject *)objects[0] intCol], 3, @"Value should be 3");

    [realm commitWriteTransaction];
}

- (void)testCreateOrUpdateNestedObjects {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];

    [PrimaryNestedObject createOrUpdateInDefaultRealmWithValue:@[@0, @[@"string", @1], @[@[@"string", @1]], @[@"string"], @[@[@1]], @""]];
    XCTAssertEqual([[PrimaryNestedObject allObjects] count], 1U, @"Should have 1 object");
    XCTAssertEqual([[PrimaryStringObject allObjects] count], 1U, @"Should have 1 object");
    XCTAssertEqual([[PrimaryIntObject allObjects] count], 1U, @"Should have 1 object");

    // update parent and nested object
    [PrimaryNestedObject createOrUpdateInDefaultRealmWithValue:@{@"primaryCol": @0,
                                                                  @"primaryStringObject": @[@"string", @2],
                                                                  @"primaryStringObjectWrapper": @[@[@"string", @2]],
                                                                  @"stringObject": @[@"string2"]}];
    XCTAssertEqual([[PrimaryNestedObject allObjects] count], 1U, @"Should have 1 object");
    XCTAssertEqual([[PrimaryStringObject allObjects] count], 1U, @"Should have 1 object");
    XCTAssertEqual([PrimaryStringObject.allObjects.lastObject intCol], 2, @"intCol should be 2");
    XCTAssertEqualObjects([PrimaryNestedObject.allObjects.lastObject stringCol], @"", @"stringCol should not have been updated");
    XCTAssertEqual(1U, [PrimaryNestedObject.allObjects.lastObject primaryIntArray].count, @"intArray should not have been overwritten");
    XCTAssertEqual([[StringObject allObjects] count], 2U, @"Should have 2 objects");

    // test partial update nulling out object/array properties
    [PrimaryNestedObject createOrUpdateInDefaultRealmWithValue:@{@"primaryCol": @0,
                                                                  @"stringCol": @"updated",
                                                                  @"stringObject": NSNull.null,
                                                                  @"primaryIntArray": NSNull.null}];
    PrimaryNestedObject *obj = PrimaryNestedObject.allObjects.lastObject;
    XCTAssertEqual(2, obj.primaryStringObject.intCol, @"primaryStringObject should not have changed");
    XCTAssertEqualObjects(obj.stringCol, @"updated", @"stringCol should have been updated");
    XCTAssertEqual(0U, obj.primaryIntArray.count, @"intArray should not have been emptied");
    XCTAssertNil(obj.stringObject, @"stringObject should be nil");

    // inserting new object should update nested
    obj = [PrimaryNestedObject createOrUpdateInDefaultRealmWithValue:@[@1, @[@"string", @3], @[@[@"string", @3]], @[@"string"], @[], @""]];
    XCTAssertEqual([[PrimaryNestedObject allObjects] count], 2U, @"Should have 2 objects");
    XCTAssertEqual([[PrimaryStringObject allObjects] count], 1U, @"Should have 1 object");
    XCTAssertEqual([(PrimaryStringObject *)[[PrimaryStringObject allObjects] lastObject] intCol], 3, @"intCol should be 3");

    // test addOrUpdateObject
    obj.primaryStringObject = [PrimaryStringObject createInDefaultRealmWithValue:@[@"string2", @1]];
    PrimaryNestedObject *obj1 = [[PrimaryNestedObject alloc] initWithValue:@[@1, @[@"string2", @4], @[@[@"string2", @4]], @[@"string"], @[@[@1], @[@2]], @""]];
    [realm addOrUpdateObject:obj1];
    XCTAssertEqual([[PrimaryNestedObject allObjects] count], 2U, @"Should have 2 objects");
    XCTAssertEqual([[PrimaryStringObject allObjects] count], 2U, @"Should have 2 objects");
    XCTAssertEqual([[PrimaryIntObject allObjects] count], 2U, @"Should have 2 objects");
    XCTAssertEqual([(PrimaryStringObject *)[[PrimaryStringObject allObjects] lastObject] intCol], 4, @"intCol should be 4");

    [realm commitWriteTransaction];
}

- (void)testCreateOrUpdateWithReorderedColumns {
    @autoreleasepool {
        // Create a Realm file with the properties in reverse order
        RLMObjectSchema *objectSchema = [RLMObjectSchema schemaForObjectClass:PrimaryStringObject.class];
        objectSchema.properties = @[objectSchema.properties[1], objectSchema.properties[0]];
        RLMSchema *schema = [RLMSchema new];
        schema.objectSchema = @[objectSchema];

        RLMRealm *realm = [self realmWithTestPathAndSchema:schema];
        [realm beginWriteTransaction];
        [PrimaryStringObject createOrUpdateInRealm:realm withValue:@[@5, @"a"]];
        [realm commitWriteTransaction];
    }

    RLMRealm *realm = [self realmWithTestPath];
    [realm beginWriteTransaction];

    XCTAssertEqual([PrimaryStringObject objectInRealm:realm forPrimaryKey:@"a"].intCol, 5);

    // Values in array are used in property declaration order, not table column order
    [PrimaryStringObject createOrUpdateInRealm:realm withValue:@[@"a", @6]];
    XCTAssertEqual([PrimaryStringObject objectInRealm:realm forPrimaryKey:@"a"].intCol, 6);

    [PrimaryStringObject createOrUpdateInRealm:realm withValue:@{@"stringCol": @"a", @"intCol": @7}];
    XCTAssertEqual([PrimaryStringObject objectInRealm:realm forPrimaryKey:@"a"].intCol, 7);
    [realm commitWriteTransaction];
}

- (void)testObjectInSet {
    [[RLMRealm defaultRealm] beginWriteTransaction];

    // set object with primary and non primary keys as they both override isEqual and hash
    PrimaryStringObject *obj = [PrimaryStringObject createInDefaultRealmWithValue:(@[@"string2", @1])];
    StringObject *strObj = [StringObject createInDefaultRealmWithValue:@[@"string"]];
    NSMutableSet *dict = [NSMutableSet set];
    [dict addObject:obj];
    [dict addObject:strObj];

    // primary key objects should match even with duplicate instances of the same object
    XCTAssertTrue([dict containsObject:obj]);
    XCTAssertTrue([dict containsObject:[[PrimaryStringObject allObjects] firstObject]]);

    // non-primary key objects should only match when comparing identical instances
    XCTAssertTrue([dict containsObject:strObj]);
    XCTAssertFalse([dict containsObject:[[StringObject allObjects] firstObject]]);

    [[RLMRealm defaultRealm] commitWriteTransaction];
}

- (void)testObjectForKey {
    [RLMRealm.defaultRealm beginWriteTransaction];
    PrimaryStringObject *strObj = [PrimaryStringObject createInDefaultRealmWithValue:@[@"key", @0]];
    PrimaryNullableStringObject *nullStrObj = [PrimaryNullableStringObject createInDefaultRealmWithValue:@[NSNull.null, @0]];
    PrimaryIntObject *intObj = [PrimaryIntObject createInDefaultRealmWithValue:@[@0]];
    PrimaryNullableIntObject *nonNullIntObj = [PrimaryNullableIntObject createInDefaultRealmWithValue:@[@0]];
    PrimaryNullableIntObject *nullIntObj = [PrimaryNullableIntObject createInDefaultRealmWithValue:@[NSNull.null]];
    [RLMRealm.defaultRealm commitWriteTransaction];

    // no PK
    RLMAssertThrowsWithReason([StringObject objectForPrimaryKey:@""],
                              @"does not have a primary key");
    RLMAssertThrowsWithReason([IntObject objectForPrimaryKey:@0],
                              @"does not have a primary key");
    RLMAssertThrowsWithReason([StringObject objectForPrimaryKey:NSNull.null],
                              @"does not have a primary key");
    RLMAssertThrowsWithReason([StringObject objectForPrimaryKey:nil],
                              @"does not have a primary key");
    RLMAssertThrowsWithReason([IntObject objectForPrimaryKey:nil],
                              @"does not have a primary key");

    // wrong PK type
    RLMAssertThrowsWithReasonMatching([PrimaryStringObject objectForPrimaryKey:@0],
                                      @"Invalid value '0' of type '.*Number.*' for 'string' property 'PrimaryStringObject.stringCol'.");
    RLMAssertThrowsWithReasonMatching([PrimaryStringObject objectForPrimaryKey:@[]],
                                      @"of type '.*Array.*' for 'string' property 'PrimaryStringObject.stringCol'.");
    RLMAssertThrowsWithReasonMatching([PrimaryIntObject objectForPrimaryKey:@""],
                                      @"Invalid value '' of type '.*String.*' for 'int' property 'PrimaryIntObject.intCol'.");
    RLMAssertThrowsWithReason([PrimaryIntObject objectForPrimaryKey:NSNull.null],
                              @"Invalid value '<null>' of type 'NSNull' for 'int' property 'PrimaryIntObject.intCol'.");
    RLMAssertThrowsWithReason([PrimaryIntObject objectForPrimaryKey:nil],
                              @"Invalid value '(null)' of type '(null)' for 'int' property 'PrimaryIntObject.intCol'.");
   RLMAssertThrowsWithReason([PrimaryStringObject objectForPrimaryKey:NSNull.null],
                             @"Invalid value '<null>' of type 'NSNull' for 'string' property 'PrimaryStringObject.stringCol'.");
   RLMAssertThrowsWithReason([PrimaryStringObject objectForPrimaryKey:nil],
                             @"Invalid value '(null)' of type '(null)' for 'string' property 'PrimaryStringObject.stringCol'.");

    // no object with key
    XCTAssertNil([PrimaryStringObject objectForPrimaryKey:@"bad key"]);
    XCTAssertNil([PrimaryIntObject objectForPrimaryKey:@1]);

    // object with key exists
    XCTAssertEqualObjects(strObj, [PrimaryStringObject objectForPrimaryKey:@"key"]);
    XCTAssertEqualObjects(nullStrObj, [PrimaryNullableStringObject objectForPrimaryKey:NSNull.null]);
    XCTAssertEqualObjects(nullStrObj, [PrimaryNullableStringObject objectForPrimaryKey:nil]);
    XCTAssertEqualObjects(intObj, [PrimaryIntObject objectForPrimaryKey:@0]);
    XCTAssertEqualObjects(nonNullIntObj, [PrimaryNullableIntObject objectForPrimaryKey:@0]);
    XCTAssertEqualObjects(nullIntObj, [PrimaryNullableIntObject objectForPrimaryKey:NSNull.null]);
    XCTAssertEqualObjects(nullIntObj, [PrimaryNullableIntObject objectForPrimaryKey:nil]);

    // nil realm throws
    RLMAssertThrowsWithReason([PrimaryIntObject objectInRealm:self.nonLiteralNil forPrimaryKey:@0],
                              @"Realm must not be nil");
}

- (void)testClassExtension {
    RLMRealm *realm = [RLMRealm defaultRealm];

    [realm beginWriteTransaction];
    BaseClassStringObject *bObject = [[BaseClassStringObject alloc ] init];
    bObject.intCol = 1;
    bObject.stringCol = @"stringVal";
    [realm addObject:bObject];
    [realm commitWriteTransaction];

    BaseClassStringObject *objectFromRealm = [BaseClassStringObject allObjects][0];
    XCTAssertEqual(1, objectFromRealm.intCol);
    XCTAssertEqualObjects(@"stringVal", objectFromRealm.stringCol);
}

@end
