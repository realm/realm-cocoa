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

#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMRealmConfiguration_Private.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"

#import "shared_realm.hpp"

#import <realm/descriptor.hpp>
#import <realm/group.hpp>

#import <atomic>
#import <memory>
#import <objc/runtime.h>
#import <vector>

RLM_ARRAY_TYPE(KVOObject)
RLM_ARRAY_TYPE(KVOLinkObject1)

@interface KVOObject : RLMObject
@property int pk; // Primary key for isEqual:
@property int ignored;

@property BOOL                 boolCol;
@property int16_t              int16Col;
@property int32_t              int32Col;
@property int64_t              int64Col;
@property float                floatCol;
@property double               doubleCol;
@property bool                 cBoolCol;
@property NSString            *stringCol;
@property NSData              *binaryCol;
@property NSDate              *dateCol;
@property KVOObject           *objectCol;

@property RLMInteger *realmIntCol;
@property RLMInteger *realmNullableIntCol;

@property RLMArray<RLMBool>   *boolArray;
@property RLMArray<RLMInt>    *intArray;
@property RLMArray<RLMFloat>  *floatArray;
@property RLMArray<RLMDouble> *doubleArray;
@property RLMArray<RLMString> *stringArray;
@property RLMArray<RLMData>   *dataArray;
@property RLMArray<RLMDate>   *dateArray;
@property RLMArray<KVOObject> *objectArray;

@property NSNumber<RLMInt> *optIntCol;
@property NSNumber<RLMFloat> *optFloatCol;
@property NSNumber<RLMDouble> *optDoubleCol;
@property NSNumber<RLMBool> *optBoolCol;

@end
@implementation KVOObject
+ (NSString *)primaryKey {
    return @"pk";
}
+ (NSArray *)ignoredProperties {
    return @[@"ignored"];
}
+ (NSArray *)requiredProperties {
    return @[@"realmIntCol"];
}
@end

@interface KVOLinkObject1 : RLMObject
@property int pk; // Primary key for isEqual:
@property KVOObject *obj;
@property RLMArray<KVOObject> *array;
@end
@implementation KVOLinkObject1
+ (NSString *)primaryKey {
    return @"pk";
}
@end

@interface KVOLinkObject2 : RLMObject
@property int pk; // Primary key for isEqual:
@property KVOLinkObject1 *obj;
@property RLMArray<KVOLinkObject1> *array;
@end
@implementation KVOLinkObject2
+ (NSString *)primaryKey {
    return @"pk";
}
@end

@interface PlainKVOObject : NSObject
@property int ignored;

@property BOOL            boolCol;
@property int16_t         int16Col;
@property int32_t         int32Col;
@property int64_t         int64Col;
@property float           floatCol;
@property double          doubleCol;
@property bool            cBoolCol;
@property NSString       *stringCol;
@property NSData         *binaryCol;
@property NSDate         *dateCol;
@property PlainKVOObject *objectCol;

@property NSMutableArray *boolArray;
@property NSMutableArray *intArray;
@property NSMutableArray *floatArray;
@property NSMutableArray *doubleArray;
@property NSMutableArray *stringArray;
@property NSMutableArray *dataArray;
@property NSMutableArray *dateArray;
@property NSMutableArray *objectArray;

@property NSNumber<RLMInt> *optIntCol;
@property NSNumber<RLMFloat> *optFloatCol;
@property NSNumber<RLMDouble> *optDoubleCol;
@property NSNumber<RLMBool> *optBoolCol;
@end
@implementation PlainKVOObject
@end

@interface PlainLinkObject1 : NSObject
@property PlainKVOObject *obj;
@property NSMutableArray *array;
@end
@implementation PlainLinkObject1
@end

@interface PlainLinkObject2 : NSObject
@property PlainLinkObject1 *obj;
@property NSMutableArray *array;
@end
@implementation PlainLinkObject2
@end

// Tables with no links (or backlinks) preserve the order of rows on
// insertion/deletion, while tables with links do not, so we need an object
// class known to have no links to test the ordered case
@interface ObjectWithNoLinksToOrFrom : RLMObject
@property int value;
@end
@implementation ObjectWithNoLinksToOrFrom
@end

// An object which removes a KVO registration when it's deallocated, for use
// as an associated object
@interface KVOUnregisterHelper : NSObject
@end
@implementation KVOUnregisterHelper {
    __unsafe_unretained id _obj;
    __unsafe_unretained id _observer;
    NSString *_keyPath;
}

+ (void)automaticallyUnregister:(id)observer object:(id)obj keyPath:(NSString *)keyPath {
    KVOUnregisterHelper *helper = [self new];
    helper->_observer = observer;
    helper->_obj = obj;
    helper->_keyPath = keyPath;
    objc_setAssociatedObject(obj, (__bridge void *)helper, helper, OBJC_ASSOCIATION_RETAIN);
}

- (void)dealloc {
    [_obj removeObserver:_observer forKeyPath:_keyPath];
}
@end

// A KVO observer which retains the given object until it observes a change
@interface ReleaseOnObservation : NSObject
@property (strong) id object;
@end
@implementation ReleaseOnObservation
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(__unused NSDictionary *)change
                       context:(void *)context
{
    [object removeObserver:self forKeyPath:keyPath context:context];
    _object = nil;
}
@end


@interface KVOTests : RLMTestCase
// get an object that should be observed for the given object being mutated
// used by some of the subclasses to observe a different accessor for the same row
- (id)observableForObject:(id)obj;
@end

// subscribes to kvo notifications on the passed object on creation, records
// all change notifications sent and makes them available in `notifications`,
// and automatically unsubscribes on destruction
class KVORecorder {
    id _observer;
    id _obj;
    NSString *_keyPath;
    RLMRealm *_mutationRealm;
    RLMRealm *_observationRealm;
    NSMutableArray *_notifications;

public:
    // construct a new recorder for the given `keyPath` on `obj`, using `observer`
    // as the NSObject helper to actually add as an observer
    KVORecorder(id observer, id obj, NSString *keyPath,
                int options = NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew)
    : _observer(observer)
    , _obj([observer observableForObject:obj])
    , _keyPath(keyPath)
    , _mutationRealm([obj respondsToSelector:@selector(realm)] ? (RLMRealm *)[obj realm] : nil)
    , _observationRealm([_obj respondsToSelector:@selector(realm)] ? (RLMRealm *)[_obj realm] : nil)
    , _notifications([NSMutableArray new])
    {
        [_obj addObserver:observer forKeyPath:keyPath options:options context:this];
    }

    ~KVORecorder() {
        id self = _observer;
        @try {
            [_obj removeObserver:_observer forKeyPath:_keyPath context:this];
        }
        @catch (NSException *e) {
            XCTFail(@"%@", e.description);
        }
        XCTAssertEqual(0U, _notifications.count);
    }

    // record a single notification
    void operator()(NSString *key, id obj, NSDictionary *changeDictionary) {
        id self = _observer;
        XCTAssertEqual(obj, _obj);
        XCTAssertEqualObjects(key, _keyPath);
        [_notifications addObject:changeDictionary.copy];
    }

    // ensure that the observed object is updated for any changes made to the
    // object being mutated if they are different
    void refresh() {
        if (_mutationRealm != _observationRealm) {
            [_mutationRealm commitWriteTransaction];
            [_observationRealm refresh];
            [_mutationRealm beginWriteTransaction];
        }
    }

    NSDictionary *pop_front() {
        NSDictionary *value = [_notifications firstObject];
        if (value) {
            [_notifications removeObjectAtIndex:0U];
        }
        return value;
    }

    NSUInteger size() const {
        return _notifications.count;
    }

    bool empty() const {
        return _notifications.count == 0;
    }
};

// Assert that `recorder` has a notification at `index` and return it if so
#define AssertNotification(recorder) ([&]{ \
    (recorder).refresh(); \
    NSDictionary *value = recorder.pop_front(); \
    XCTAssertNotNil(value, @"Did not get a notification when expected"); \
    return value; \
})()

// Validate that `recorder` has at least one notification, and that the first
// notification is the expected one
#define AssertChanged(recorder, from, to) do { \
    if (NSDictionary *note = AssertNotification((recorder))) { \
        XCTAssertEqualObjects(@(NSKeyValueChangeSetting), note[NSKeyValueChangeKindKey]); \
        XCTAssertEqualObjects((from), note[NSKeyValueChangeOldKey]); \
        XCTAssertEqualObjects((to), note[NSKeyValueChangeNewKey]); \
    } \
    else { \
        return; \
    } \
} while (false)

// Validate that `r` has a notification with the given kind and changed indexes,
// remove it, and verify that there are no more notifications
#define AssertIndexChange(kind, indexes) do { \
    if (NSDictionary *note = AssertNotification(r)) { \
        XCTAssertEqual([note[NSKeyValueChangeKindKey] intValue], kind); \
        XCTAssertEqualObjects(note[NSKeyValueChangeIndexesKey], indexes); \
    } \
    XCTAssertTrue(r.empty()); \
} while (0)

// Tests for plain Foundation key-value observing to verify that we correctly
// match the standard semantics. Each of the subclasses of KVOTests runs the
// same set of tests on RLMObjects in difference scenarios
@implementation KVOTests
// forward a KVO notification to the KVORecorder stored in the context
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    (*static_cast<KVORecorder *>(context))(keyPath, object, change);
}

// overridden in the multiple accessors, one realm and multiple realms cases
- (id)observableForObject:(id)obj {
    return obj;
}

// overridden in the multiple realms case because `-refresh` does not send
// notifications for intermediate states
- (bool)collapsesNotifications {
    return false;
}

// overridden in all subclases to return the appropriate object
// base class runs the tests on a plain NSObject using stock KVO to ensure that
// the tests are actually covering the correct behavior, since there's a great
// deal that the documentation doesn't specify
- (id)createObject {
    PlainKVOObject *obj = [PlainKVOObject new];
    obj.int16Col = 1;
    obj.int32Col = 2;
    obj.int64Col = 3;
    obj.binaryCol = NSData.data;
    obj.stringCol = @"";
    obj.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    obj.boolArray = [NSMutableArray array];
    obj.intArray = [NSMutableArray array];
    obj.floatArray = [NSMutableArray array];
    obj.doubleArray = [NSMutableArray array];
    obj.stringArray = [NSMutableArray array];
    obj.dataArray = [NSMutableArray array];
    obj.dateArray = [NSMutableArray array];
    obj.objectArray = [NSMutableArray array];
    return obj;
}

- (id)createLinkObject {
    PlainLinkObject1 *obj1 = [PlainLinkObject1 new];
    obj1.obj = [self createObject];
    obj1.array = [NSMutableArray new];

    PlainLinkObject2 *obj2 = [PlainLinkObject2 new];
    obj2.obj = obj1;
    obj2.array = [NSMutableArray new];

    return obj2;
}

// actual tests follow

- (void)testRegisterForUnknownProperty {
    KVOObject *obj = [self createObject];

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"non-existent" options:0 context:nullptr]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"non-existent"]);

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"non-existent" options:NSKeyValueObservingOptionOld context:nullptr]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"non-existent"]);

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"non-existent" options:NSKeyValueObservingOptionPrior context:nullptr]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"non-existent"]);
}

- (void)testRemoveObserver {
    KVOObject *obj = [self createObject];
    XCTAssertThrowsSpecificNamed([obj removeObserver:self forKeyPath:@"int32Col"], NSException, NSRangeException);
    XCTAssertThrowsSpecificNamed([obj removeObserver:self forKeyPath:@"int32Col" context:nullptr], NSException, NSRangeException);
    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:nullptr]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col"]);
    XCTAssertThrowsSpecificNamed([obj removeObserver:self forKeyPath:@"int32Col"], NSException, NSRangeException);

    // `context` parameter must match if it's passed, but the overload that doesn't
    // take one will unregister any context
    void *context1 = (void *)1;
    void *context2 = (void *)2;
    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context1]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col" context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col" context:context1]);

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col" context:context2]);

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col"]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col"]);

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context1]);
    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col" context:context1]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col" context:context1]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col" context:context2]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col" context:context2]);

    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context1]);
    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col" context:context2]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col" context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col" context:context1]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col" context:context1]);

    // no context version should only unregister one (unspecified) observer
    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context1]);
    XCTAssertNoThrow([obj addObserver:self forKeyPath:@"int32Col" options:0 context:context2]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col"]);
    XCTAssertNoThrow([obj removeObserver:self forKeyPath:@"int32Col"]);
    XCTAssertThrows([obj removeObserver:self forKeyPath:@"int32Col"]);
}

- (void)testRemoveObserverInObservation {
    auto helper = [ReleaseOnObservation new];

    __unsafe_unretained id obj;
    __weak id weakObj;
    @autoreleasepool {
        obj = weakObj = helper.object = [self createObject];
        [obj addObserver:helper forKeyPath:@"int32Col" options:NSKeyValueObservingOptionOld context:nullptr];
    }

    [obj setInt32Col:0];
    XCTAssertNil(helper.object);
    XCTAssertNil(weakObj);
}

- (void)testSimple {
    KVOObject *obj = [self createObject];
    {
        KVORecorder r(self, obj, @"int32Col");
        obj.int32Col = 10;
        AssertChanged(r, @2, @10);
    }
    {
        KVORecorder r(self, obj, @"int32Col");
        obj.int32Col = 1;
        AssertChanged(r, @10, @1);
    }
}

- (void)testSelfAssignmentNotifies {
    KVOObject *obj = [self createObject];
    {
        KVORecorder r(self, obj, @"int32Col");
        obj.int32Col = obj.int32Col;
        AssertChanged(r, @2, @2);
    }
}

- (void)testMultipleObserversAreNotified {
    KVOObject *obj = [self createObject];
    {
        KVORecorder r1(self, obj, @"int32Col");
        KVORecorder r2(self, obj, @"int32Col");
        KVORecorder r3(self, obj, @"int32Col");
        obj.int32Col = 10;
        AssertChanged(r1, @2, @10);
        AssertChanged(r2, @2, @10);
        AssertChanged(r3, @2, @10);
    }
}

- (void)testOnlyObserversForTheCorrectPropertyAreNotified {
    KVOObject *obj = [self createObject];
    {
        KVORecorder r16(self, obj, @"int16Col");
        KVORecorder r32(self, obj, @"int32Col");
        KVORecorder r64(self, obj, @"int64Col");

        obj.int16Col = 2;
        AssertChanged(r16, @1, @2);
        XCTAssertTrue(r16.empty());
        XCTAssertTrue(r32.empty());
        XCTAssertTrue(r64.empty());

        obj.int32Col = 2;
        AssertChanged(r32, @2, @2);
        XCTAssertTrue(r16.empty());
        XCTAssertTrue(r32.empty());
        XCTAssertTrue(r64.empty());

        obj.int64Col = 2;
        AssertChanged(r64, @3, @2);
        XCTAssertTrue(r16.empty());
        XCTAssertTrue(r32.empty());
        XCTAssertTrue(r64.empty());
    }
}

- (void)testMultipleChangesWithSingleObserver {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, @"int32Col");

    obj.int32Col = 1;
    obj.int32Col = 2;
    obj.int32Col = 3;
    obj.int32Col = 3;

    if (self.collapsesNotifications) {
        AssertChanged(r, @2, @3);
    }
    else {
        AssertChanged(r, @2, @1);
        AssertChanged(r, @1, @2);
        AssertChanged(r, @2, @3);
        AssertChanged(r, @3, @3);
    }
}

- (void)testOnlyObserversForTheCorrectObjectAreNotified {
    KVOObject *obj1 = [self createObject];
    KVOObject *obj2 = [self createObject];

    KVORecorder r1(self, obj1, @"int32Col");
    KVORecorder r2(self, obj2, @"int32Col");

    obj1.int32Col = 10;
    AssertChanged(r1, @2, @10);
    XCTAssertEqual(0U, r2.size());

    obj2.int32Col = 5;
    AssertChanged(r2, @2, @5);
}

- (void)testOptionsInitial {
    KVOObject *obj = [self createObject];

    {
        KVORecorder r(self, obj, @"int32Col", 0);
        XCTAssertEqual(0U, r.size());
    }
    {
        KVORecorder r(self, obj, @"int32Col", NSKeyValueObservingOptionInitial);
        r.pop_front();
    }
}

- (void)testOptionsOld {
    KVOObject *obj = [self createObject];

    {
        KVORecorder r(self, obj, @"int32Col", 0);
        obj.int32Col = 0;
        if (NSDictionary *note = AssertNotification(r)) {
            XCTAssertNil(note[NSKeyValueChangeOldKey]);
        }
    }
    {
        KVORecorder r(self, obj, @"int32Col", NSKeyValueObservingOptionOld);
        obj.int32Col = 0;
        if (NSDictionary *note = AssertNotification(r)) {
            XCTAssertNotNil(note[NSKeyValueChangeOldKey]);
        }
    }
}

- (void)testOptionsNew {
    KVOObject *obj = [self createObject];

    {
        KVORecorder r(self, obj, @"int32Col", 0);
        obj.int32Col = 0;
        if (NSDictionary *note = AssertNotification(r)) {
            XCTAssertNil(note[NSKeyValueChangeNewKey]);
        }
    }
    {
        KVORecorder r(self, obj, @"int32Col", NSKeyValueObservingOptionNew);
        obj.int32Col = 0;
        if (NSDictionary *note = AssertNotification(r)) {
            XCTAssertNotNil(note[NSKeyValueChangeNewKey]);
        }
    }
}

- (void)testOptionsPrior {
    KVOObject *obj = [self createObject];

    KVORecorder r(self, obj, @"int32Col", NSKeyValueObservingOptionNew|NSKeyValueObservingOptionPrior);
    obj.int32Col = 0;
    r.refresh();

    XCTAssertEqual(2U, r.size());
    if (NSDictionary *note = AssertNotification(r)) {
        XCTAssertNil(note[NSKeyValueChangeNewKey]);
        XCTAssertEqualObjects(@YES, note[NSKeyValueChangeNotificationIsPriorKey]);
    }
    if (NSDictionary *note = AssertNotification(r)) {
        XCTAssertNotNil(note[NSKeyValueChangeNewKey]);
        XCTAssertNil(note[NSKeyValueChangeNotificationIsPriorKey]);
    }
}

- (void)checkRealmIntegerTypesWithObject:(__unused KVOObject *)obj {
    // Do nothing. Realm Integer types are unsupported on non-Realm objects.
}

- (void)checkRealmIntegerTypesKVCWithObject:(__unused KVOObject *)obj {
    // Do nothing. Realm Integer types are unsupported on non-Realm objects.
}

- (void)testAllPropertyTypes {
    KVOObject *obj = [self createObject];

    {
        KVORecorder r(self, obj, @"boolCol");
        obj.boolCol = YES;
        AssertChanged(r, @NO, @YES);
    }

    {
        KVORecorder r(self, obj, @"int16Col");
        obj.int16Col = 0;
        AssertChanged(r, @1, @0);
    }

    {
        KVORecorder r(self, obj, @"int32Col");
        obj.int32Col = 0;
        AssertChanged(r, @2, @0);
    }

    {
        KVORecorder r(self, obj, @"int64Col");
        obj.int64Col = 0;
        AssertChanged(r, @3, @0);
    }

    {
        KVORecorder r(self, obj, @"floatCol");
        obj.floatCol = 1.0f;
        AssertChanged(r, @0, @1);
    }

    {
        KVORecorder r(self, obj, @"doubleCol");
        obj.doubleCol = 1.0;
        AssertChanged(r, @0, @1);
    }

    {
        KVORecorder r(self, obj, @"cBoolCol");
        obj.cBoolCol = YES;
        AssertChanged(r, @NO, @YES);
    }

    {
        KVORecorder r(self, obj, @"stringCol");
        obj.stringCol = @"abc";
        AssertChanged(r, @"", @"abc");
        obj.stringCol = nil;
        AssertChanged(r, @"abc", NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"binaryCol");
        NSData *data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
        obj.binaryCol = data;
        AssertChanged(r, NSData.data, data);
        obj.binaryCol = nil;
        AssertChanged(r, data, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"dateCol");
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:1];
        obj.dateCol = date;
        AssertChanged(r, [NSDate dateWithTimeIntervalSinceReferenceDate:0], date);
        obj.dateCol = nil;
        AssertChanged(r, date, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"objectCol");
        obj.objectCol = obj;
        AssertChanged(r, NSNull.null, [self observableForObject:obj]);
        obj.objectCol = nil;
        AssertChanged(r, [self observableForObject:obj], NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"intArray");
        obj.intArray = obj.intArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"boolArray");
        obj.boolArray = obj.boolArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"floatArray");
        obj.floatArray = obj.floatArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"doubleArray");
        obj.doubleArray = obj.doubleArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"stringArray");
        obj.stringArray = obj.stringArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"dataArray");
        obj.dataArray = obj.dataArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"dateArray");
        obj.dateArray = obj.dateArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"objectArray");
        obj.objectArray = obj.objectArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"optIntCol");
        obj.optIntCol = @1;
        AssertChanged(r, NSNull.null, @1);
        obj.optIntCol = nil;
        AssertChanged(r, @1, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optFloatCol");
        obj.optFloatCol = @1.1f;
        AssertChanged(r, NSNull.null, @1.1f);
        obj.optFloatCol = nil;
        AssertChanged(r, @1.1f, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optDoubleCol");
        obj.optDoubleCol = @1.1;
        AssertChanged(r, NSNull.null, @1.1);
        obj.optDoubleCol = nil;
        AssertChanged(r, @1.1, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optBoolCol");
        obj.optBoolCol = @YES;
        AssertChanged(r, NSNull.null, @YES);
        obj.optBoolCol = nil;
        AssertChanged(r, @YES, NSNull.null);
    }

    [self checkRealmIntegerTypesWithObject:obj];
}

- (void)testAllPropertyTypesKVC {
    KVOObject *obj = [self createObject];

    {
        KVORecorder r(self, obj, @"boolCol");
        [obj setValue:@YES forKey:@"boolCol"];
        AssertChanged(r, @NO, @YES);
    }

    {
        KVORecorder r(self, obj, @"int16Col");
        [obj setValue:@0 forKey:@"int16Col"];
        AssertChanged(r, @1, @0);
    }

    {
        KVORecorder r(self, obj, @"int32Col");
        [obj setValue:@0 forKey:@"int32Col"];
        AssertChanged(r, @2, @0);
    }

    {
        KVORecorder r(self, obj, @"int64Col");
        [obj setValue:@0 forKey:@"int64Col"];
        AssertChanged(r, @3, @0);
    }

    {
        KVORecorder r(self, obj, @"floatCol");
        [obj setValue:@1.0f forKey:@"floatCol"];
        AssertChanged(r, @0, @1);
    }

    {
        KVORecorder r(self, obj, @"doubleCol");
        [obj setValue:@1.0 forKey:@"doubleCol"];
        AssertChanged(r, @0, @1);
    }

    {
        KVORecorder r(self, obj, @"cBoolCol");
        [obj setValue:@YES forKey:@"cBoolCol"];
        AssertChanged(r, @NO, @YES);
    }

    {
        KVORecorder r(self, obj, @"stringCol");
        [obj setValue:@"abc" forKey:@"stringCol"];
        AssertChanged(r, @"", @"abc");
        [obj setValue:nil forKey:@"stringCol"];
        AssertChanged(r, @"abc", NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"binaryCol");
        NSData *data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
        [obj setValue:data forKey:@"binaryCol"];
        AssertChanged(r, NSData.data, data);
        [obj setValue:nil forKey:@"binaryCol"];
        AssertChanged(r, data, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"dateCol");
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:1];
        [obj setValue:date forKey:@"dateCol"];
        AssertChanged(r, [NSDate dateWithTimeIntervalSinceReferenceDate:0], date);
        [obj setValue:nil forKey:@"dateCol"];
        AssertChanged(r, date, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"objectCol");
        [obj setValue:obj forKey:@"objectCol"];
        AssertChanged(r, NSNull.null, [self observableForObject:obj]);
        [obj setValue:nil forKey:@"objectCol"];
        AssertChanged(r, [self observableForObject:obj], NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"objectArray");
        [obj setValue:obj.objectArray forKey:@"objectArray"];
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"optIntCol");
        [obj setValue:@1 forKey:@"optIntCol"];
        AssertChanged(r, NSNull.null, @1);
        [obj setValue:nil forKey:@"optIntCol"];
        AssertChanged(r, @1, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optFloatCol");
        [obj setValue:@1.1f forKey:@"optFloatCol"];
        AssertChanged(r, NSNull.null, @1.1f);
        [obj setValue:nil forKey:@"optFloatCol"];
        AssertChanged(r, @1.1f, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optDoubleCol");
        [obj setValue:@1.1 forKey:@"optDoubleCol"];
        AssertChanged(r, NSNull.null, @1.1);
        [obj setValue:nil forKey:@"optDoubleCol"];
        AssertChanged(r, @1.1, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optBoolCol");
        [obj setValue:@YES forKey:@"optBoolCol"];
        AssertChanged(r, NSNull.null, @YES);
        [obj setValue:nil forKey:@"optBoolCol"];
        AssertChanged(r, @YES, NSNull.null);
    }

    [self checkRealmIntegerTypesKVCWithObject:obj];
}

- (void)testAllPropertyTypesDynamic {
    KVOObject *obj = [self createObject];
    if (![obj respondsToSelector:@selector(setObject:forKeyedSubscript:)]) {
        return;
    }

    {
        KVORecorder r(self, obj, @"boolCol");
        obj[@"boolCol"] = @YES;
        AssertChanged(r, @NO, @YES);
    }

    {
        KVORecorder r(self, obj, @"int16Col");
        obj[@"int16Col"] = @0;
        AssertChanged(r, @1, @0);
    }

    {
        KVORecorder r(self, obj, @"int32Col");
        obj[@"int32Col"] = @0;
        AssertChanged(r, @2, @0);
    }

    {
        KVORecorder r(self, obj, @"int64Col");
        obj[@"int64Col"] = @0;
        AssertChanged(r, @3, @0);
    }

    {
        KVORecorder r(self, obj, @"floatCol");
        obj[@"floatCol"] = @1.0f;
        AssertChanged(r, @0, @1);
    }

    {
        KVORecorder r(self, obj, @"doubleCol");
        obj[@"doubleCol"] = @1.0;
        AssertChanged(r, @0, @1);
    }

    {
        KVORecorder r(self, obj, @"cBoolCol");
        obj[@"cBoolCol"] = @YES;
        AssertChanged(r, @NO, @YES);
    }

    {
        KVORecorder r(self, obj, @"stringCol");
        obj[@"stringCol"] = @"abc";
        AssertChanged(r, @"", @"abc");
        obj[@"stringCol"] = nil;
        AssertChanged(r, @"abc", NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"binaryCol");
        NSData *data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
        obj[@"binaryCol"] = data;
        AssertChanged(r, NSData.data, data);
        obj[@"binaryCol"] = nil;
        AssertChanged(r, data, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"dateCol");
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:1];
        obj[@"dateCol"] = date;
        AssertChanged(r, [NSDate dateWithTimeIntervalSinceReferenceDate:0], date);
        obj[@"dateCol"] = nil;
        AssertChanged(r, date, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"objectCol");
        obj[@"objectCol"] = obj;
        AssertChanged(r, NSNull.null, [self observableForObject:obj]);
        obj[@"objectCol"] = nil;
        AssertChanged(r, [self observableForObject:obj], NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"objectArray");
        obj[@"objectArray"] = obj.objectArray;
        r.refresh();
        r.pop_front(); // asserts that there's something to pop
    }

    {
        KVORecorder r(self, obj, @"optIntCol");
        obj[@"optIntCol"] = @1;
        AssertChanged(r, NSNull.null, @1);
        obj[@"optIntCol"] = nil;
        AssertChanged(r, @1, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optFloatCol");
        obj[@"optFloatCol"] = @1.1f;
        AssertChanged(r, NSNull.null, @1.1f);
        obj[@"optFloatCol"] = nil;
        AssertChanged(r, @1.1f, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optDoubleCol");
        obj[@"optDoubleCol"] = @1.1;
        AssertChanged(r, NSNull.null, @1.1);
        obj[@"optDoubleCol"] = nil;
        AssertChanged(r, @1.1, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"optBoolCol");
        obj[@"optBoolCol"] = @YES;
        AssertChanged(r, NSNull.null, @YES);
        obj[@"optBoolCol"] = nil;
        AssertChanged(r, @YES, NSNull.null);
    }

    {
        KVORecorder r(self, obj, @"realmIntCol");
        obj[@"realmIntCol"] = @30;
        AssertChanged(r, @10, @30);
    }

    {
        KVORecorder r(self, obj, @"realmNullableIntCol");
        obj[@"realmNullableIntCol"] = @31;
        AssertChanged(r, @10, @31);
        obj[@"realmNullableIntCol"] = nil;
        AssertChanged(r, @31, NSNull.null);
    }
}

- (void)testArrayDiffs {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVORecorder r(self, obj, @"array");

    id mutator = [obj mutableArrayValueForKey:@"array"];

    [mutator addObject:obj.obj];
    AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);

    [mutator addObject:obj.obj];
    AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:1]);

    [mutator removeObjectAtIndex:0];
    AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:0]);

    [mutator replaceObjectAtIndex:0 withObject:obj.obj];
    AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndex:0]);

    NSMutableIndexSet *indexes = [NSMutableIndexSet new];
    [indexes addIndex:0];
    [indexes addIndex:2];
    [mutator insertObjects:@[obj.obj, obj.obj] atIndexes:indexes];
    AssertIndexChange(NSKeyValueChangeInsertion, indexes);

    [mutator removeObjectsAtIndexes:indexes];
    AssertIndexChange(NSKeyValueChangeRemoval, indexes);

    if (![obj.array isKindOfClass:[NSArray class]]) {
        // We deliberately diverge from NSMutableArray for `removeAllObjects` and
        // `addObjectsFromArray:`, because generating a separate notification for
        // each object added or removed is needlessly pessimal.
        [mutator addObjectsFromArray:@[obj.obj, obj.obj]];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)]);

        // NSArray sends multiple notifications for exchange, which we can't do
        // on refresh
        [mutator exchangeObjectAtIndex:0 withObjectAtIndex:1];
        AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]);

        // NSArray doesn't have move
        [mutator moveObjectAtIndex:1 toIndex:0];
        AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]);

        [mutator removeLastObject];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:2]);

        [mutator removeAllObjects];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]);
    }
}

- (void)testPrimitiveArrayDiffs {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, @"intArray");

    id mutator = [obj mutableArrayValueForKey:@"intArray"];

    [mutator addObject:@1];
    AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);

    [mutator addObject:@2];
    AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:1]);

    [mutator removeObjectAtIndex:0];
    AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:0]);

    [mutator replaceObjectAtIndex:0 withObject:@3];
    AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndex:0]);

    NSMutableIndexSet *indexes = [NSMutableIndexSet new];
    [indexes addIndex:0];
    [indexes addIndex:2];
    [mutator insertObjects:@[@4, @5] atIndexes:indexes];
    AssertIndexChange(NSKeyValueChangeInsertion, indexes);

    [mutator removeObjectsAtIndexes:indexes];
    AssertIndexChange(NSKeyValueChangeRemoval, indexes);

    if (![obj.intArray isKindOfClass:[NSArray class]]) {
        // We deliberately diverge from NSMutableArray for `removeAllObjects` and
        // `addObjectsFromArray:`, because generating a separate notification for
        // each object added or removed is needlessly pessimal.
        [mutator addObjectsFromArray:@[@6, @7]];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)]);

        // NSArray sends multiple notifications for exchange, which we can't do
        // on refresh
        [mutator exchangeObjectAtIndex:0 withObjectAtIndex:1];
        AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]);

        // NSArray doesn't have move
        [mutator moveObjectAtIndex:1 toIndex:0];
        AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]);

        [mutator removeLastObject];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:2]);

        [mutator removeAllObjects];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]);
    }
}

- (void)testIgnoredProperty {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, @"ignored");
    obj.ignored = 10;
    AssertChanged(r, @0, @10);
}

- (void)testChangeEndOfKeyPath {
    KVOLinkObject2 *obj = [self createLinkObject];
    std::unique_ptr<KVORecorder> r;
    @autoreleasepool {
        r = std::make_unique<KVORecorder>(self, obj, @"obj.obj.boolCol");
    }
    obj.obj.obj.boolCol = YES;
    AssertChanged(*r, @NO, @YES);
}

- (void)testChangeMiddleOfKeyPath {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOObject *oldObj = obj.obj.obj;
    KVOObject *newObj = [self createObject];
    newObj.boolCol = YES;

    KVORecorder r(self, obj, @"obj.obj.boolCol");
    obj.obj.obj = newObj;
    AssertChanged(r, @NO, @YES);
    newObj.boolCol = NO;
    AssertChanged(r, @YES, @NO);
    oldObj.boolCol = YES;
}

- (void)testNullifyMiddleOfKeyPath {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVORecorder r(self, obj, @"obj.obj.boolCol");
    obj.obj = nil;
    AssertChanged(r, @NO, NSNull.null);
}

- (void)testChangeMiddleOfKeyPathToNonNil {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject1 *obj2 = obj.obj;
    obj.obj = nil;
    obj2.obj.boolCol = YES;

    KVORecorder r(self, obj, @"obj.obj.boolCol");
    obj.obj = obj2;
    AssertChanged(r, NSNull.null, @YES);
}

- (void)testArrayKVC {
    KVOObject *obj = [self createObject];
    [obj.objectArray addObject:obj];

    KVORecorder r(self, obj, @"boolCol");
    [obj.objectArray setValue:@YES forKey:@"boolCol"];
    AssertChanged(r, @NO, @YES);
}

// RLMArray doesn't support @count at all
//- (void)testObserveArrayCount {
//    KVOObject *obj = [self createObject];
//    KVORecorder r(self, obj, @"objectArray.@count");
//    id mutator = [obj mutableArrayValueForKey:@"objectArray"];
//    [mutator addObject:obj];
//    AssertChanged(r, @0, @1);
//}
@end

// Run tests on an unmanaged RLMObject instance
@interface KVOUnmanagedObjectTests : KVOTests
@end
@implementation KVOUnmanagedObjectTests
- (id)createObject {
    static int pk = 0;
    KVOObject *obj = [KVOObject new];
    obj.pk = pk++;
    obj.int16Col = 1;
    obj.int32Col = 2;
    obj.int64Col = 3;
    obj.binaryCol = NSData.data;
    obj.stringCol = @"";
    obj.dateCol = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    obj.realmIntCol = [[RLMInteger alloc] initWithValue:@10];
    obj.realmNullableIntCol = [[RLMInteger alloc] initWithValue:@10];
    return obj;
}

- (id)createLinkObject {
    static int pk = 0;
    KVOLinkObject1 *obj1 = [KVOLinkObject1 new];
    obj1.pk = pk++;
    obj1.obj = [self createObject];
    KVOLinkObject2 *obj2 = [KVOLinkObject2 new];
    obj2.pk = pk++;
    obj2.obj = obj1;
    return obj2;
}

- (void)checkRealmIntegerTypesWithObject:(KVOObject *)obj {
    {
        KVORecorder r(self, obj, @"realmIntCol");
        obj.realmIntCol.value = @100;
        AssertChanged(r, @10, @100);
        [obj.realmIntCol incrementValueBy:1];
        AssertChanged(r, @100, @101);
    }
    
    {
        KVORecorder r(self, obj, @"realmNullableIntCol");
        obj.realmNullableIntCol.value = @101;
        AssertChanged(r, @10, @101);
        [obj.realmNullableIntCol incrementValueBy:1];
        AssertChanged(r, @101, @102);
        obj.realmNullableIntCol.value = nil;
        AssertChanged(r, @102, NSNull.null);
        obj.realmNullableIntCol.value = @103;
        AssertChanged(r, NSNull.null, @103);
    }
}

- (void)checkRealmIntegerTypesKVCWithObject:(KVOObject *)obj {
    {
        KVORecorder r(self, obj, @"realmIntCol");
        [obj setValue:@20 forKey:@"realmIntCol"];
        AssertChanged(r, @10, @20);
    }

    {
        KVORecorder r(self, obj, @"realmNullableIntCol");
        [obj setValue:@21 forKey:@"realmNullableIntCol"];
        AssertChanged(r, @10, @21);
        [obj setValue:nil forKey:@"realmNullableIntCol"];
        AssertChanged(r, @21, NSNull.null);
    }
}

- (void)testAllPropertyTypes {
    [super testAllPropertyTypes];
}

- (void)testAddToRealmAfterAddingObservers {
    RLMRealm *realm = RLMRealm.defaultRealm;
    [realm beginWriteTransaction];

    KVOObject *obj = [self createObject];
    {
        KVORecorder r(self, obj, @"int32Col");
        XCTAssertThrows([realm addObject:obj]);
    }
    XCTAssertNoThrow([realm addObject:obj]);
    [realm cancelWriteTransaction];
}

- (void)testObserveInvalidArrayProperty {
    KVOObject *obj = [self createObject];
    XCTAssertThrows([obj.objectArray addObserver:self forKeyPath:@"self" options:0 context:0]);
    XCTAssertNoThrow([obj.objectArray addObserver:self forKeyPath:RLMInvalidatedKey options:0 context:0]);
    XCTAssertNoThrow([obj.objectArray removeObserver:self forKeyPath:RLMInvalidatedKey context:0]);
}

- (void)testUnregisteringViaAnAssociatedObject {
    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) KVOObject *obj = [self createObject];
        [obj addObserver:self forKeyPath:@"boolCol" options:0 context:0];
        [KVOUnregisterHelper automaticallyUnregister:self object:obj keyPath:@"boolCol"];
    }
    // Throws if the unregistration doesn't succeed
}

@end

// Run tests on a managed object, modifying the actual object instance being
// observed
@interface KVOManagedObjectTests : KVOTests
@property (nonatomic, strong) RLMRealm *realm;
@end

@implementation KVOManagedObjectTests
- (void)setUp {
    [super setUp];
    _realm = [self getRealm];
    [_realm beginWriteTransaction];
}

- (void)tearDown {
    [self.realm cancelWriteTransaction];
    self.realm = nil;
    [super tearDown];
}

- (RLMRealm *)getRealm {
    RLMRealmConfiguration *configuration = [[RLMRealmConfiguration alloc] init];
    configuration.inMemoryIdentifier = @"test";
    configuration.schemaMode = realm::SchemaMode::Additive;
    return [RLMRealm realmWithConfiguration:configuration error:nil];
}

- (id)createObject {
    static std::atomic<int> pk{0};
    return [KVOObject createInRealm:_realm withValue:@[@(++pk),
                                                       @NO, @1, @2, @3, @0, @0, @NO, @"",
                                                       NSData.data, [NSDate dateWithTimeIntervalSinceReferenceDate:0],
                                                       [NSNull null],
                                                       @10, @10]];
}

- (id)createLinkObject {
    static std::atomic<int> pk{0};
    return [KVOLinkObject2 createInRealm:_realm withValue:@[@(++pk), @[@(++pk), [self createObject], @[]], @[]]];
}

- (void)checkRealmIntegerTypesWithObject:(KVOObject *)obj {
    {
        KVORecorder r(self, obj, @"realmIntCol");
        obj.realmIntCol.value = @100;
        AssertChanged(r, @10, @100);
        [obj.realmIntCol incrementValueBy:1];
        AssertChanged(r, @100, @101);
    }
    
    {
        KVORecorder r(self, obj, @"realmNullableIntCol");
        obj.realmNullableIntCol.value = @101;
        AssertChanged(r, @10, @101);
        [obj.realmNullableIntCol incrementValueBy:1];
        AssertChanged(r, @101, @102);
        obj.realmNullableIntCol.value = nil;
        AssertChanged(r, @102, NSNull.null);
        obj.realmNullableIntCol.value = @103;
        AssertChanged(r, NSNull.null, @103);
    }
}

- (void)checkRealmIntegerTypesKVCWithObject:(KVOObject *)obj {
    {
        KVORecorder r(self, obj, @"realmIntCol");
        [obj setValue:@20 forKey:@"realmIntCol"];
        AssertChanged(r, @10, @20);
    }

    {
        KVORecorder r(self, obj, @"realmNullableIntCol");
        [obj setValue:@21 forKey:@"realmNullableIntCol"];
        AssertChanged(r, @10, @21);
        [obj setValue:nil forKey:@"realmNullableIntCol"];
        AssertChanged(r, @21, NSNull.null);
    }
}

- (void)testDeleteObservedObject {
    KVOObject *obj = [self createObject];
    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, RLMInvalidatedKey);
    [self.realm deleteObject:obj];
    AssertChanged(r2, @NO, @YES);
    // should not crash
}

- (void)testDeleteMiddleOfKeyPath {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVORecorder r(self, obj, @"obj.obj.boolCol");
    [self.realm deleteObject:obj.obj];
    AssertChanged(r, @NO, NSNull.null);
}

- (void)testDeleteParentOfObservedRLMArray {
    KVOObject *obj = [self createObject];
    KVORecorder r1(self, obj, @"objectArray");
    KVORecorder r2(self, obj, @"objectArray.invalidated");
    KVORecorder r3(self, obj.objectArray, RLMInvalidatedKey);
    [self.realm deleteObject:obj];
    AssertChanged(r2, @NO, @YES);
    AssertChanged(r3, @NO, @YES);
}

- (void)testDeleteAllObjects {
    KVOObject *obj = [self createObject];
    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, RLMInvalidatedKey);
    [self.realm deleteAllObjects];
    AssertChanged(r2, @NO, @YES);
    // should not crash
}

- (void)testClearTable {
    KVOObject *obj = [self createObject];
    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, RLMInvalidatedKey);
    [self.realm deleteObjects:[KVOObject allObjectsInRealm:self.realm]];
    AssertChanged(r2, @NO, @YES);
    // should not crash
}

- (void)testClearQuery {
    KVOObject *obj = [self createObject];
    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, RLMInvalidatedKey);
    [self.realm deleteObjects:[KVOObject objectsInRealm:self.realm where:@"TRUEPREDICATE"]];
    AssertChanged(r2, @NO, @YES);
    // should not crash
}

- (void)testClearLinkView {
    KVOObject *obj = [self createObject];
    KVOObject *obj2 = [self createObject];
    [obj2.objectArray addObject:obj];

    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, RLMInvalidatedKey);
    [self.realm deleteObjects:obj2.objectArray];
    AssertChanged(r2, @NO, @YES);
    // should not crash
}

- (void)testCreateObserverAfterDealloc {
    @autoreleasepool {
        KVOObject *obj = [self createObject];
        KVORecorder r(self, obj, @"boolCol");
        obj.boolCol = YES;
        AssertChanged(r, @NO, @YES);
    }
    @autoreleasepool {
        KVOObject *obj = [self createObject];
        KVORecorder r(self, obj, @"boolCol");
        obj.boolCol = YES;
        AssertChanged(r, @NO, @YES);
    }
}

- (void)testDirectlyDeleteLinkedToObject {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject1 *linked = obj.obj;
    KVORecorder r(self, obj, @"obj");
    KVORecorder r2(self, obj, @"obj.invalidated");
    [self.realm deleteObject:linked];

    if (NSDictionary *note = AssertNotification(r)) {
        XCTAssertTrue([note[NSKeyValueChangeOldKey] isKindOfClass:[RLMObjectBase class]]);
        XCTAssertEqualObjects(note[NSKeyValueChangeNewKey], NSNull.null);
    }
    AssertChanged(r2, @NO, NSNull.null);
}

- (void)testDeleteLinkedToObjectViaTableClear {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVORecorder r(self, obj, @"obj");
    KVORecorder r2(self, obj, @"obj.invalidated");
    [self.realm deleteObjects:[KVOLinkObject1 allObjectsInRealm:self.realm]];

    if (NSDictionary *note = AssertNotification(r)) {
        XCTAssertTrue([note[NSKeyValueChangeOldKey] isKindOfClass:[RLMObjectBase class]]);
        XCTAssertEqualObjects(note[NSKeyValueChangeNewKey], NSNull.null);
    }
    AssertChanged(r2, @NO, NSNull.null);
}

- (void)testDeleteLinkedToObjectViaQueryClear {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVORecorder r(self, obj, @"obj");
    KVORecorder r2(self, obj, @"obj.invalidated");
    [self.realm deleteObjects:[KVOLinkObject1 objectsInRealm:self.realm where:@"TRUEPREDICATE"]];

    if (NSDictionary *note = AssertNotification(r)) {
        XCTAssertTrue([note[NSKeyValueChangeOldKey] isKindOfClass:[RLMObjectBase class]]);
        XCTAssertEqualObjects(note[NSKeyValueChangeNewKey], NSNull.null);
    }
    AssertChanged(r2, @NO, NSNull.null);
}

- (void)testDeleteObjectInArray {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject1 *linked = obj.obj;
    [obj.array addObject:linked];
    KVORecorder r(self, obj, @"array");
    [self.realm deleteObject:linked];
    AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:0]);
}

- (void)testDeleteObjectsInArrayViaTableClear {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject2 *obj2 = [self createLinkObject];
    [obj.array addObject:obj.obj];
    [obj.array addObject:obj.obj];
    [obj.array addObject:obj2.obj];

    KVORecorder r(self, obj, @"array");
    [self.realm deleteObjects:[KVOLinkObject1 allObjectsInRealm:self.realm]];
    AssertIndexChange(NSKeyValueChangeRemoval, ([NSIndexSet indexSetWithIndexesInRange:{0, 3}]));
}

- (void)testDeleteObjectsInArrayViaTableViewClear {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject2 *obj2 = [self createLinkObject];
    [obj.array addObject:obj.obj];
    [obj.array addObject:obj.obj];
    [obj.array addObject:obj2.obj];

    KVORecorder r(self, obj, @"array");
    RLMResults *results = [KVOLinkObject1 objectsInRealm:self.realm where:@"TRUEPREDICATE"];
    [results lastObject];
    [self.realm deleteObjects:results];
    AssertIndexChange(NSKeyValueChangeRemoval, ([NSIndexSet indexSetWithIndexesInRange:{0, 3}]));
}

- (void)testDeleteObjectsInArrayViaQueryClear {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject2 *obj2 = [self createLinkObject];
    [obj.array addObject:obj.obj];
    [obj.array addObject:obj.obj];
    [obj.array addObject:obj2.obj];

    KVORecorder r(self, obj, @"array");
    [self.realm deleteObjects:[KVOLinkObject1 objectsInRealm:self.realm where:@"TRUEPREDICATE"]];
    AssertIndexChange(NSKeyValueChangeRemoval, ([NSIndexSet indexSetWithIndexesInRange:{0, 3}]));
}

- (void)testObserveInvalidArrayProperty {
    KVOObject *obj = [self createObject];
    RLMArray *array = obj.objectArray;
    XCTAssertThrows([array addObserver:self forKeyPath:@"self" options:0 context:0]);
    XCTAssertNoThrow([array addObserver:self forKeyPath:RLMInvalidatedKey options:0 context:0]);
    XCTAssertNoThrow([array removeObserver:self forKeyPath:RLMInvalidatedKey context:0]);
}

- (void)testInvalidOperationOnObservedArray {
    KVOLinkObject2 *obj = [self createLinkObject];
    KVOLinkObject1 *linked = obj.obj;
    [obj.array addObject:linked];
    KVORecorder r(self, obj, @"array");
    XCTAssertThrows([obj.array exchangeObjectAtIndex:2 withObjectAtIndex:3]);
    // A KVO notification is still sent to observers on the same thread since we
    // can't cancel willChange, but the data is not very meaningful so don't check it
    if (!self.collapsesNotifications) {
        AssertNotification(r);
    }
}
@end

// Mutate a different accessor backed by the same row as the accessor being observed
@interface KVOMultipleAccessorsTests : KVOManagedObjectTests
@end
@implementation KVOMultipleAccessorsTests
- (id)observableForObject:(id)value {
    if (RLMObject *obj = RLMDynamicCast<RLMObject>(value)) {
        RLMObject *copy = RLMCreateManagedAccessor(obj.objectSchema.accessorClass, obj.realm, obj->_info);
        copy->_row = obj->_row;
        return copy;
    }
    else if (RLMArray *array = RLMDynamicCast<RLMArray>(value)) {
        return array;
    }
    else {
        XCTFail(@"unsupported type");
        return nil;
    }
}

- (void)testIgnoredProperty {
    // ignored properties do not notify other accessors for the same row
}

- (void)testAddOrUpdate {
    KVOObject *obj = [self createObject];
    KVOObject *obj2 = [[KVOObject alloc] initWithValue:obj];

    KVORecorder r(self, obj, @"boolCol");
    obj2.boolCol = true;
    XCTAssertTrue(r.empty());
    [self.realm addOrUpdateObject:obj2];
    AssertChanged(r, @NO, @YES);
}

- (void)testCreateOrUpdate {
    KVOObject *obj = [self createObject];
    KVOObject *obj2 = [[KVOObject alloc] initWithValue:obj];

    KVORecorder r(self, obj, @"boolCol");
    obj2.boolCol = true;
    XCTAssertTrue(r.empty());
    [KVOObject createOrUpdateInRealm:self.realm withValue:obj2];
    AssertChanged(r, @NO, @YES);
}

// The following tests aren't really multiple-accessor-specific, but they're
// conceptually similar and don't make sense in the multiple realm instances case
- (void)testCancelWriteTransactionWhileObservingNewObject {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, RLMInvalidatedKey);
    KVORecorder r2(self, obj, @"boolCol");
    [self.realm cancelWriteTransaction];
    AssertChanged(r, @NO, @YES);
    r2.pop_front();
    [self.realm beginWriteTransaction];
}

- (void)testCancelWriteTransactionWhileObservingChangedProperty {
    KVOObject *obj = [self createObject];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];

    obj.boolCol = YES;

    KVORecorder r(self, obj, @"boolCol");
    [self.realm cancelWriteTransaction];
    AssertChanged(r, @YES, @NO);

    [self.realm beginWriteTransaction];
}

- (void)testCancelWriteTransactionWhileObservingLinkToExistingObject {
    KVOObject *obj = [self createObject];
    KVOObject *obj2 = [self createObject];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];

    obj.objectCol = obj2;

    KVORecorder r(self, obj, @"objectCol");
    [self.realm cancelWriteTransaction];
    AssertChanged(r, obj2, NSNull.null);

    [self.realm beginWriteTransaction];
}

- (void)testCancelWriteTransactionWhileObservingLinkToNewObject {
    KVOObject *obj = [self createObject];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];

    obj.objectCol = [self createObject];

    KVORecorder r(self, obj, @"objectCol");
    [self.realm cancelWriteTransaction];

    if (NSDictionary *note = AssertNotification(r)) {
        XCTAssertTrue([note[NSKeyValueChangeOldKey] isKindOfClass:[RLMObjectBase class]]);
        XCTAssertEqualObjects(note[NSKeyValueChangeNewKey], NSNull.null);
    }

    [self.realm beginWriteTransaction];
}

- (void)testCancelWriteTransactionWhileObservingNewObjectLinkingToNewObject {
    KVOObject *obj = [self createObject];
    obj.objectCol = [self createObject];
    KVORecorder r(self, obj, RLMInvalidatedKey);
    KVORecorder r2(self, obj, @"objectCol");
    KVORecorder r3(self, obj, @"objectCol.boolCol");
    [self.realm cancelWriteTransaction];
    AssertChanged(r, @NO, @YES);
    [self.realm beginWriteTransaction];
}

- (void)testCancelWriteWithArrayChanges {
    KVOObject *obj = [self createObject];
    [obj.objectArray addObject:obj];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];

    {
        [obj.objectArray addObject:obj];
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:1]);
    }
    {
        [obj.objectArray removeLastObject];
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
    }
    {
        obj.objectArray[0] = obj;
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndex:0]);
    }

    // test batching with multiple items changed
    [obj.objectArray addObject:obj];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];
    {
        [obj.objectArray removeAllObjects];
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, ([NSIndexSet indexSetWithIndexesInRange:{0, 2}]));
    }
    {
        [obj.objectArray removeLastObject];
        [obj.objectArray removeLastObject];
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, ([NSIndexSet indexSetWithIndexesInRange:{0, 2}]));
    }
    {
        [obj.objectArray insertObject:obj atIndex:1];
        [obj.objectArray insertObject:obj atIndex:0];
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        NSMutableIndexSet *expected = [NSMutableIndexSet new];
        [expected addIndex:0];
        [expected addIndex:2]; // shifted due to inserting at 0 after 1
        AssertIndexChange(NSKeyValueChangeRemoval, expected);
    }
    {
        [obj.objectArray insertObject:obj atIndex:0];
        [obj.objectArray removeLastObject];
        KVORecorder r(self, obj, @"objectArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertChanged(r, obj.objectArray, obj.objectArray);
    }
}

- (void)testCancelWriteWithPrimitiveArrayChanges {
    KVOObject *obj = [self createObject];
    [obj.intArray addObject:@1];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];

    {
        [obj.intArray addObject:@2];
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:1]);
    }
    {
        [obj.intArray removeLastObject];
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
    }
    {
        obj.intArray[0] = @3;
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeReplacement, [NSIndexSet indexSetWithIndex:0]);
    }

    // test batching with multiple items changed
    [obj.intArray addObject:@4];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];
    {
        [obj.intArray removeAllObjects];
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, ([NSIndexSet indexSetWithIndexesInRange:{0, 2}]));
    }
    {
        [obj.intArray removeLastObject];
        [obj.intArray removeLastObject];
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, ([NSIndexSet indexSetWithIndexesInRange:{0, 2}]));
    }
    {
        [obj.intArray insertObject:@5 atIndex:1];
        [obj.intArray insertObject:@6 atIndex:0];
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        NSMutableIndexSet *expected = [NSMutableIndexSet new];
        [expected addIndex:0];
        [expected addIndex:2]; // shifted due to inserting at 0 after 1
        AssertIndexChange(NSKeyValueChangeRemoval, expected);
    }
    {
        [obj.intArray insertObject:@7 atIndex:0];
        [obj.intArray removeLastObject];
        KVORecorder r(self, obj, @"intArray");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertChanged(r, obj.intArray, obj.intArray);
    }
}

- (void)testCancelWriteWithLinkedObjectedRemoved {
    KVOLinkObject2 *obj = [self createLinkObject];
    [obj.array addObject:obj.obj];
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];

    {
        [self.realm deleteObject:obj.obj];

        KVORecorder r(self, obj, @"array");
        KVORecorder r2(self, obj, @"obj");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
        AssertChanged(r2, NSNull.null, [KVOLinkObject1 allObjectsInRealm:self.realm].firstObject);
    }
    {
        [self.realm deleteObjects:[KVOLinkObject1 allObjectsInRealm:self.realm]];

        KVORecorder r(self, obj, @"array");
        KVORecorder r2(self, obj, @"obj");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
        AssertChanged(r2, NSNull.null, [KVOLinkObject1 allObjectsInRealm:self.realm].firstObject);
    }
    {
        [self.realm deleteObjects:obj.array];

        KVORecorder r(self, obj, @"array");
        KVORecorder r2(self, obj, @"obj");
        [self.realm cancelWriteTransaction];
        [self.realm beginWriteTransaction];
        AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
        AssertChanged(r2, NSNull.null, [KVOLinkObject1 allObjectsInRealm:self.realm].firstObject);
    }
}

- (void)testInvalidateRealm {
    KVOObject *obj = [self createObject];
    [self.realm commitWriteTransaction];

    KVORecorder r1(self, obj, RLMInvalidatedKey);
    KVORecorder r2(self, obj, @"objectArray.invalidated");
    [self.realm invalidate];
    [self.realm beginWriteTransaction];

    AssertChanged(r1, @NO, @YES);
    AssertChanged(r2, @NO, @YES);
}
@end

// Observing an object from a different RLMRealm instance backed by the same
// row as the managed object being mutated
@interface KVOMultipleRealmsTests : KVOManagedObjectTests
@property RLMRealm *secondaryRealm;
@end

@implementation KVOMultipleRealmsTests
- (void)setUp {
    [super setUp];
    RLMRealmConfiguration *config = self.realm.configuration;
    config.cache = false;
    self.secondaryRealm = [RLMRealm realmWithConfiguration:config error:nil];
}

- (void)tearDown {
    self.secondaryRealm = nil;
    [super tearDown];
}

- (id)observableForObject:(id)value {
    [self.realm commitWriteTransaction];
    [self.realm beginWriteTransaction];
    [self.secondaryRealm refresh];

    if (RLMObject *obj = RLMDynamicCast<RLMObject>(value)) {
        RLMObject *copy = RLMCreateManagedAccessor(obj.objectSchema.accessorClass, self.secondaryRealm,
                                                   &self.secondaryRealm->_info[obj.objectSchema.className]);
        copy->_row = (*copy->_info->table())[obj->_row.get_index()];
        return copy;
    }
    else if (RLMArray *array = RLMDynamicCast<RLMArray>(value)) {
        return array;
    }
    else {
        XCTFail(@"unsupported type");
        return nil;
    }

}

- (bool)collapsesNotifications {
    return true;
}

- (void)testIgnoredProperty {
    // ignored properties do not notify other accessors for the same row
}

- (void)testBatchArrayChanges {
    KVOObject *obj = [self createObject];
    [obj.objectArray addObject:obj];
    [obj.objectArray addObject:obj];
    [obj.objectArray addObject:obj];

    {
        KVORecorder r(self, obj, @"objectArray");
        [obj.objectArray insertObject:obj atIndex:1];
        [obj.objectArray insertObject:obj atIndex:0];

        NSMutableIndexSet *expected = [NSMutableIndexSet new];
        [expected addIndex:0];
        [expected addIndex:2]; // shifted due to inserting at 0 after 1
        AssertIndexChange(NSKeyValueChangeInsertion, expected);
    }

    {
        KVORecorder r(self, obj, @"objectArray");
        [obj.objectArray removeObjectAtIndex:3];
        [obj.objectArray removeObjectAtIndex:3];
        AssertIndexChange(NSKeyValueChangeRemoval, ([NSIndexSet indexSetWithIndexesInRange:{3, 2}]));
    }

    {
        KVORecorder r(self, obj, @"objectArray");
        [obj.objectArray removeObjectAtIndex:0];
        [obj.objectArray removeAllObjects];
        AssertIndexChange(NSKeyValueChangeRemoval, ([NSIndexSet indexSetWithIndexesInRange:{0, 3}]));
    }

    [obj.objectArray addObject:obj];
    {
        KVORecorder r(self, obj, @"objectArray");
        [obj.objectArray addObject:obj];
        [obj.objectArray removeAllObjects];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:0]);
    }

    [obj.objectArray addObject:obj];
    {
        KVORecorder r(self, obj, @"objectArray");
        obj.objectArray[0] = obj;
        [obj.objectArray removeAllObjects];
        AssertIndexChange(NSKeyValueChangeRemoval, [NSIndexSet indexSetWithIndex:0]);
    }
}

- (void)testOrderedErase {
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 10; ++i) @autoreleasepool {
        [objects addObject:[ObjectWithNoLinksToOrFrom createInRealm:self.realm withValue:@[@(i)]]];
    }

    // deleteObject: always uses move_last_over(), but TableView::clear() uses
    // erase() if there's no links
    auto deleteObject = ^(int value) {
        [self.realm deleteObjects:[ObjectWithNoLinksToOrFrom objectsInRealm:self.realm where:@"value = %d", value]];
    };

    { // delete object before observed, then observed
        KVORecorder r(self, objects[2], @"invalidated");
        deleteObject(1);
        deleteObject(2);
        AssertChanged(r, @NO, @YES);
    }

    { // delete object after observed, then observed
        KVORecorder r(self, objects[3], @"invalidated");
        deleteObject(4);
        deleteObject(3);
        AssertChanged(r, @NO, @YES);
    }

    { // delete observed, then object before observed
        KVORecorder r(self, objects[6], @"invalidated");
        deleteObject(6);
        deleteObject(5);
        AssertChanged(r, @NO, @YES);
    }

    { // delete observed, then object after observed
        KVORecorder r(self, objects[7], @"invalidated");
        deleteObject(7);
        deleteObject(8);
        AssertChanged(r, @NO, @YES);
    }
}

- (void)testInsertNewTables {
    KVOObject *obj = [self createObject];

    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, @"int32Col");

    obj.boolCol = YES;

    // Add tables before the observed one so that the observed one's index changes
    realm::Group &group = self.realm->_realm->read_group();
    realm::TableRef table1 = group.insert_table(5, "new table");
    realm::TableRef table2 = group.insert_table(0, "new table 2");
    table1->add_column(realm::type_Int, "col");
    table2->add_column(realm::type_Int, "col");

    obj.int32Col = 3;
    AssertChanged(r1, @NO, @YES);
    AssertChanged(r2, @2, @3);
}

- (void)testMoveObservedTableBeforeChange {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, @"boolCol");
    realm::Group &group = self.realm->_realm->read_group();
    group.move_table(obj->_info->table()->get_index_in_group(), 0);
    obj.boolCol = YES;
    AssertChanged(r, @NO, @YES);
}

- (void)testMoveObservedTableAfterChange {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, @"boolCol");
    obj.boolCol = YES;
    realm::Group &group = self.realm->_realm->read_group();
    group.move_table(obj->_info->table()->get_index_in_group(), group.size() - 1);
    AssertChanged(r, @NO, @YES);
}

- (void)testShiftObservedTableBeforeChange {
    KVOObject *obj = [self createObject];
    KVORecorder r(self, obj, @"boolCol");
    realm::Group &group = self.realm->_realm->read_group();
    group.move_table(0, group.size() - 1);
    obj.boolCol = YES;
    AssertChanged(r, @NO, @YES);
}

- (void)testShiftObservedTableAfterChange {
    KVOObject *obj = [self createObject];

    KVORecorder r(self, obj, @"boolCol");
    obj.boolCol = YES;
    realm::Group &group = self.realm->_realm->read_group();
    group.move_table(group.size() - 1, 0);
    AssertChanged(r, @NO, @YES);
}

- (void)testInsertNewColumns {
    KVOObject *obj = [self createObject];

    KVORecorder r1(self, obj, @"boolCol");
    KVORecorder r2(self, obj, @"int32Col");
    auto ndx = obj->_info->tableColumn(@"int32Col");

    // Add a column before the observed one so that the observed one's index changes
    obj.boolCol = YES;
    auto& table = *obj->_info->table();
    table.insert_column(0, realm::type_Binary, "new col");
    table.insert_column(ndx, realm::type_Binary, "new col 2");
    obj->_row.set_int(ndx + 2, 3); // can't use the accessor after a local schema change

    AssertChanged(r1, @NO, @YES);
    AssertChanged(r2, @2, @3);
}

- (void)testMoveObservedColumnBeforeChange {
    KVOObject *obj = [self createObject];
    auto ndx = obj->_info->tableColumn(@"boolCol");

    KVORecorder r(self, obj, @"boolCol");
    auto& table = *obj->_info->table();
    realm::_impl::TableFriend::move_column(*table.get_descriptor(), ndx, 0);
    obj->_row.set_bool(0, true); // can't use the accessor after a local schema change
    AssertChanged(r, @NO, @YES);
}

- (void)testMoveObservedColumnAfterChange {
    KVOObject *obj = [self createObject];
    auto ndx = obj->_info->tableColumn(@"boolCol");

    KVORecorder r(self, obj, @"boolCol");
    obj.boolCol = YES;
    realm::_impl::TableFriend::move_column(*obj->_info->table()->get_descriptor(), ndx, 0);
    AssertChanged(r, @NO, @YES);
}

- (void)testShiftObservedColumnBeforeChange {
    KVOObject *obj = [self createObject];
    auto ndx = obj->_info->tableColumn(@"boolCol");

    KVORecorder r(self, obj, @"boolCol");
    obj->_info->table()->insert_column(0, realm::type_Binary, "new col");
    obj->_row.set_bool(ndx + 1, true); // can't use the accessor after a local schema change
    AssertChanged(r, @NO, @YES);
}

- (void)testShiftObservedColumnAfterChange {
    KVOObject *obj = [self createObject];

    KVORecorder r(self, obj, @"boolCol");
    obj.boolCol = YES;
    obj->_info->table()->insert_column(0, realm::type_Binary, "new col");
    AssertChanged(r, @NO, @YES);
}

- (void)testSwapRowsIsNotAChange {
    KVOObject *obj = [self createObject];
    [self createObject];

    KVORecorder r(self, obj, @"boolCol");
    obj->_info->table()->swap_rows(0, 1);
    r.refresh();
    XCTAssertTrue(r.empty());
}

- (void)testSwapRowsBeforeChange {
    KVOObject *obj = [self createObject];
    [self createObject];

    KVORecorder r(self, obj, @"boolCol");
    obj->_info->table()->swap_rows(0, 1);
    obj.boolCol = YES;
    AssertChanged(r, @NO, @YES);
}

- (void)testSwapRowsAfterChange {
    KVOObject *obj = [self createObject];
    [self createObject];

    KVORecorder r(self, obj, @"boolCol");
    obj.boolCol = YES;
    obj->_info->table()->swap_rows(0, 1);
    AssertChanged(r, @NO, @YES);
}

- (void)testSwapRowsBeforeArrayChange {
    KVOObject *obj = [self createObject];
    [self createObject];

    KVORecorder r(self, obj, @"objectArray");
    obj->_info->table()->swap_rows(0, 1);
    [obj.objectArray addObject:obj];
    AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
}

- (void)testSwapRowsAfterArrayChange {
    KVOObject *obj = [self createObject];
    [self createObject];

    KVORecorder r(self, obj, @"objectArray");
    [obj.objectArray addObject:obj];
    obj->_info->table()->swap_rows(0, 1);
    AssertIndexChange(NSKeyValueChangeInsertion, [NSIndexSet indexSetWithIndex:0]);
}
@end

// Test with the table column order not matching the order of the properties
@interface KVOManagedObjectWithReorderedPropertiesTests : KVOManagedObjectTests
@end

@implementation KVOManagedObjectWithReorderedPropertiesTests
- (RLMRealm *)getRealm {
    // Initialize the file with the properties in reverse order, then re-open
    // with it in the normal order while the reversed one is still open (as
    // otherwise it'll recreate the file due to being in-memory)
    RLMSchema *schema = [RLMSchema new];
    schema.objectSchema = @[[self reverseProperties:KVOObject.sharedSchema],
                            [self reverseProperties:KVOLinkObject1.sharedSchema],
                            [self reverseProperties:KVOLinkObject2.sharedSchema]];

    RLMRealmConfiguration *configuration = [[RLMRealmConfiguration alloc] init];
    configuration.cache = false;
    configuration.inMemoryIdentifier = @"test";
    configuration.customSchema = schema;
    RLMRealm *reversedRealm = [RLMRealm realmWithConfiguration:configuration error:nil];

    configuration.customSchema = nil;
    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:nil];
    XCTAssertNotEqualObjects(realm.schema, reversedRealm.schema);
    return realm;
}

- (RLMObjectSchema *)reverseProperties:(RLMObjectSchema *)source {
    RLMObjectSchema *objectSchema = [source copy];
    objectSchema.properties = objectSchema.properties.reverseObjectEnumerator.allObjects;
    return objectSchema;
}
@end
