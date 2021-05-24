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

@interface DictionaryPropertyTests : RLMTestCase
@end

@implementation DictionaryPropertyTests

-(void)testPopulateEmptyDictionary {
    RLMRealm *realm = [self realmWithTestPath];

    [realm beginWriteTransaction];
    DictionaryPropertyObject *dict = [DictionaryPropertyObject createInRealm:realm withValue:@[@{}, @{}]];
    XCTAssertNotNil(dict.stringDictionary, @"Should be able to get an empty dictionary");
    XCTAssertEqual(dict.stringDictionary.count, 0U, @"Should start with no dictionary elements");

    StringObject *obj = [[StringObject alloc] init];
    obj.stringCol = @"a";

    dict.stringDictionary[@"one"] = obj;
    dict.stringDictionary[@"two"] = [StringObject createInRealm:realm withValue:@[@"b"]];
    dict.stringDictionary[@"three"] = obj;

    [realm commitWriteTransaction];

    XCTAssertEqual(dict.stringDictionary.count, 3U, @"Should have three elements in the dictionary");
    XCTAssertEqualObjects([dict.stringDictionary[@"one"] stringCol], @"a", @"First element should have property value 'a'");
    XCTAssertEqualObjects([dict.stringDictionary[@"two"] stringCol], @"b", @"Second element should have property value 'b'");
    XCTAssertEqualObjects([dict.stringDictionary[@"three"] stringCol], @"a", @"Third element should have property value 'a'");

    RLMDictionary *dictionaryProp = dict.stringDictionary;
    RLMAssertThrowsWithReasonMatching([dictionaryProp setObject:obj forKey:@"four"], @"write transaction");

    for (NSString *key in dictionaryProp) {
        XCTAssertTrue(((RLMDictionary *)dictionaryProp[key]).description.length, @"Object should have description");
    }
}

-(void)testModifyDetatchedDictionary {
    RLMRealm *realm = [self realmWithTestPath];

    [realm beginWriteTransaction];
    DictionaryPropertyObject *dictObj = [DictionaryPropertyObject createInRealm:realm withValue:@[]];
    XCTAssertNotNil(dictObj.stringDictionary, @"Should be able to get an empty dictionary");
    XCTAssertEqual(dictObj.stringDictionary.count, 0U, @"Should start with no dictionary elements");

    StringObject *obj = [[StringObject alloc] init];
    obj.stringCol = @"a";
    RLMDictionary *dict = dictObj.stringDictionary;
    dict[@"one"] = obj;
    [dict setObject:[StringObject createInRealm:realm withValue:@[@"b"]] forKey:@"two"];
    [realm commitWriteTransaction];

    XCTAssertEqual(dictObj.stringDictionary.count, 2U, @"Should have two elements in dictionary");
    XCTAssertEqualObjects([dictObj.stringDictionary[@"one"] stringCol], @"a", @"First element should have property value 'a'");
    XCTAssertEqualObjects([dictObj.stringDictionary[@"two"] stringCol], @"b", @"Second element should have property value 'b'");

    RLMAssertThrowsWithReasonMatching([dictObj.stringDictionary setObject:obj forKey:@"one"], @"write transaction");
}

- (void)testDeleteUnmanagedObjectWithDictionaryProperty {
    DictionaryPropertyObject *dictObj = [[DictionaryPropertyObject alloc] initWithValue:@[]];
    RLMDictionary *stringDictionary = dictObj.stringDictionary;
    XCTAssertFalse(stringDictionary.isInvalidated, @"stringDictionary should be valid after creation.");
    dictObj = nil;
    XCTAssertFalse(stringDictionary.isInvalidated, @"stringDictionary should still be valid after parent deletion.");
}

- (void)testDeleteObjectWithDictionaryProperty {
    RLMRealm *realm = [self realmWithTestPath];

    [realm beginWriteTransaction];
    DictionaryPropertyObject *dictObj = [DictionaryPropertyObject createInRealm:realm withValue:@[]];
    RLMDictionary *dictArray = dictObj.stringDictionary;
    XCTAssertFalse(dictArray.isInvalidated, @"dictArray should be valid after creation.");
    [realm deleteObject:dictObj];
    XCTAssertTrue(dictArray.isInvalidated, @"dictArray should be invalid after parent deletion.");
    [realm commitWriteTransaction];
}

- (void)testDeleteObjectInDictionaryProperty {
    RLMRealm *realm = [self realmWithTestPath];
    StringObject *obj = [[StringObject alloc] init];
    [realm beginWriteTransaction];
    DictionaryPropertyObject *dictObj = [DictionaryPropertyObject createInRealm:realm withValue: @{@"stringDictionary": @{@"one": obj}}];
    RLMDictionary *stringDictionary = dictObj.stringDictionary;
    StringObject *one = stringDictionary[@"one"];
    [realm deleteObjects:[StringObject allObjectsInRealm:realm]];
    XCTAssertFalse(stringDictionary.isInvalidated, @"stringDictionary should be valid after member object deletion.");
    XCTAssertTrue(one.isInvalidated, @"firstObject should be invalid after deletion.");
    XCTAssertEqual(stringDictionary.count, 1U, @"stringDictionary.count should be one as it holds onto the invalidated object.");
    [realm commitWriteTransaction];
}

-(void)testKeyedSubscript {
    RLMRealm *realm = [self realmWithTestPath];

    [realm beginWriteTransaction];
    DictionaryPropertyObject *obj = [DictionaryPropertyObject createInRealm:realm withValue:@[]];
    StringObject *child1 = [StringObject createInRealm:realm withValue:@[@"a"]];
    StringObject *child2 = [[StringObject alloc] init];
    StringObject *child3 = [StringObject createInRealm:realm withValue:@[@"c"]];

    obj.stringDictionary[@"one"] = child1;
    XCTAssertTrue([[obj.stringDictionary[@"one"] stringCol] isEqualToString:@"a"]);
    obj.stringDictionary[@"two"] = child2;
    XCTAssertNil([obj.stringDictionary[@"two"] stringCol]);
    // reassign
    obj.stringDictionary[@"two"] = child3;
    XCTAssertTrue([[obj.stringDictionary[@"two"] stringCol] isEqualToString:@"c"]);
    [realm commitWriteTransaction];
}

// TODO: = nil erase value for key
-(void)testRemoveObject {
    RLMRealm *realm = [self realmWithTestPath];

    [realm beginWriteTransaction];
    DictionaryPropertyObject *obj = [DictionaryPropertyObject createInRealm:realm withValue:@[]];
    StringObject *child1 = [StringObject createInRealm:realm withValue:@[@"a"]];
    StringObject *child2 = [[StringObject alloc] init];
    StringObject *child3 = [StringObject createInRealm:realm withValue:@[@"c"]];

    obj.stringDictionary[@"one"] = child1;
    XCTAssertTrue([[obj.stringDictionary[@"one"] stringCol] isEqualToString:@"a"]);
    obj.stringDictionary[@"two"] = child2;
    XCTAssertNil([obj.stringDictionary[@"two"] stringCol]);
    // reassign
    obj.stringDictionary[@"two"] = child3;
    XCTAssertTrue([[obj.stringDictionary[@"two"] stringCol] isEqualToString:@"c"]);
    [realm commitWriteTransaction];
    [realm beginWriteTransaction];
    [obj.stringDictionary removeObjectForKey:@"one"];
    XCTAssertNil(obj.stringDictionary[@"one"]);
    [obj.stringDictionary removeObjectForKey:@"two"];
    XCTAssertNil(obj.stringDictionary[@"two"]);
    obj.stringDictionary[@"three"] = child3;
    XCTAssertTrue([[obj.stringDictionary[@"three"] stringCol] isEqualToString:@"c"]);
    [obj.stringDictionary removeAllObjects];
    XCTAssertNil(obj.stringDictionary[@"three"]);

    obj.stringDictionary[@"one"] = child1;
    XCTAssertTrue([[obj.stringDictionary[@"one"] stringCol] isEqualToString:@"a"]);
    obj.stringDictionary[@"two"] = child2;
    XCTAssertNil([obj.stringDictionary[@"two"] stringCol]);
    [obj.stringDictionary removeObjectsForKeys:@[@"one", @"two"]];
    XCTAssertNil(obj.stringDictionary[@"one"]);
    XCTAssertNil(obj.stringDictionary[@"two"]);
    [realm commitWriteTransaction];
}

-(void)testAddInvalidated {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    CompanyObject *company = [CompanyObject createInDefaultRealmWithValue:@[@"company", @[]]];
    EmployeeObject *person = [[EmployeeObject alloc] init];
    person.name = @"Mary";
    [realm addObject:person];
    [realm deleteObjects:[EmployeeObject allObjects]];
    RLMAssertThrowsWithReasonMatching([company.employeeDict setObject:person forKey:@"person1"], @"invalidated");
    [realm cancelWriteTransaction];
}

- (void)testAddNil {
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    CompanyObject *company = [CompanyObject createInDefaultRealmWithValue:@[@"company", @[]]];
    RLMAssertThrowsWithReason([company.employeeDict setObject:self.nonLiteralNil forKey:@"blah"],
                              @"Must provide a non-nil value.");
    [realm cancelWriteTransaction];
}

- (void)testUnmanaged {
    RLMRealm *realm = [self realmWithTestPath];

    DictionaryPropertyObject *dict = [[DictionaryPropertyObject alloc] init];
    XCTAssertNotNil(dict.stringDictionary, @"RLMDictionary property should get created on access");

    XCTAssertEqual(dict.stringDictionary.allValues.count, 0U, @"No objects added yet");
    XCTAssertEqual(dict.stringDictionary.allKeys.count, 0U, @"No objects added yet");

    StringObject *obj1 = [[StringObject alloc] init];
    obj1.stringCol = @"a";
    StringObject *obj2 = [[StringObject alloc] init];
    obj2.stringCol = @"b";
    StringObject *obj3 = [[StringObject alloc] init];
    obj3.stringCol = @"c";
    dict.stringDictionary[@"one"] = obj1;
    dict.stringDictionary[@"two"] = obj2;
    dict.stringDictionary[@"three"] = obj3;

    XCTAssertEqual(dict.stringDictionary.allValues.count, 3U);
    XCTAssertEqual(dict.stringDictionary.allKeys.count, 3U);

    XCTAssertEqualObjects(dict.stringDictionary[@"one"], obj1, @"Objects should be equal");
    XCTAssertEqualObjects(dict.stringDictionary[@"three"], obj3, @"Objects should be equal");
    XCTAssertEqualObjects(dict.stringDictionary.allValues[1], obj2, @"Objects should be equal");

    [realm beginWriteTransaction];
    [realm addObject:dict];
    [realm commitWriteTransaction];

    XCTAssertEqual(dict.stringDictionary.allValues.count, 3U);
    XCTAssertEqual(dict.stringDictionary.allKeys.count, 3U);

    XCTAssertEqual(dict.stringDictionary.count, 3U, @"Should have two elements in dictionary");
    XCTAssertEqualObjects([dict.stringDictionary[@"one"] stringCol], @"a", @"First element should have property value 'a'");
    XCTAssertEqualObjects([dict.stringDictionary[@"two"] stringCol], @"b", @"Second element should have property value 'b'");

    [realm beginWriteTransaction];
    dict.stringDictionary[@"one"] = obj3;
    XCTAssertTrue([dict.stringDictionary[@"one"] isEqualToObject:obj3], @"Objects should be replaced");
    dict.stringDictionary[@"one"] = obj1;
    XCTAssertTrue([obj1 isEqualToObject:dict.stringDictionary[@"one"]], @"Objects should be replaced");
    [dict.stringDictionary removeObjectForKey:@"one"];
    XCTAssertEqual(dict.stringDictionary.count, 2U, @"2 objects left");
    [dict.stringDictionary removeAllObjects];
    XCTAssertEqual(dict.stringDictionary.count, 0U, @"All objects removed");
    [realm commitWriteTransaction];

    DictionaryPropertyObject *intDictionary = [[DictionaryPropertyObject alloc] init];
    IntObject *intObj = [[IntObject alloc] init];
    intObj.intCol = 1;
    [intDictionary.intDictionary setObject:intObj forKey:@"one"];
    [intDictionary.intDictionary setObject:intObj forKey:@"two"];

    XCTAssertThrows([intDictionary.intDictionary objectsWhere:@"intCol == 1"], @"Should throw on unmanaged RLMDictionary");
    XCTAssertThrows(([intDictionary.intDictionary objectsWithPredicate:[NSPredicate predicateWithFormat:@"intCol == %i", 1]]), @"Should throw on unmanaged RLMDictionary");
    XCTAssertThrows([intDictionary.intDictionary sortedResultsUsingKeyPath:@"intCol" ascending:YES], @"Should throw on unmanaged RLMDictionary");

    // test unmanaged with literals
    __unused DictionaryPropertyObject *obj = [[DictionaryPropertyObject alloc] initWithValue:@[@{}, @{@"one": [[IntObject alloc] initWithValue:@[@1]]}, @{}]];
}

- (void)testUnmanagedComparision {
    RLMRealm *realm = [self realmWithTestPath];

    DictionaryPropertyObject *dict = [[DictionaryPropertyObject alloc] init];
    DictionaryPropertyObject *dict2 = [[DictionaryPropertyObject alloc] init];

    XCTAssertNotNil(dict.stringDictionary, @"RLMDictionary property should get created on access");
    XCTAssertNotNil(dict2.stringDictionary, @"RLMDictionary property should get created on access");
    XCTAssertTrue([dict.stringDictionary isEqual:dict2.stringDictionary], @"Empty dictionaries should be equal");

    XCTAssertEqual(dict.stringDictionary.count, 0U);
    XCTAssertEqual(dict2.stringDictionary.count, 0U);

    StringObject *obj1 = [[StringObject alloc] init];
    obj1.stringCol = @"a";
    StringObject *obj2 = [[StringObject alloc] init];
    obj2.stringCol = @"b";
    StringObject *obj3 = [[StringObject alloc] init];
    obj3.stringCol = @"c";
    [dict.stringDictionary setObject:obj1 forKey:@"one"];
    dict.stringDictionary[@"two"] = obj2;
    [dict.stringDictionary setObject:obj3 forKey:@"three"];

    [dict2.stringDictionary setObject:obj1 forKey:@"one"];
    dict2.stringDictionary[@"two"] = obj2;
    [dict2.stringDictionary setObject:obj3 forKey:@"three"];

    XCTAssertTrue([dict.stringDictionary isEqual:dict2.stringDictionary], @"Dictionaries should be equal");
    [dict2.stringDictionary removeObjectForKey:@"three"];
    XCTAssertFalse([dict.stringDictionary isEqual:dict2.stringDictionary], @"Dictionaries should not be equal");
    dict2.stringDictionary[@"three"] = obj3;
    XCTAssertTrue([dict.stringDictionary isEqual:dict2.stringDictionary], @"Dictionaries should be equal");

    [realm beginWriteTransaction];
    [realm addObject:dict];
    [realm commitWriteTransaction];

    XCTAssertFalse([dict.stringDictionary isEqual:dict2.stringDictionary], @"Comparing a managed dictionary to an unmanaged one should fail");
    XCTAssertFalse([dict2.stringDictionary isEqual:dict.stringDictionary], @"Comparing a managed dictionary to an unmanaged one should fail");
}

- (void)testUnmanagedPrimitive {
    AllPrimitiveDictionaries *obj = [[AllPrimitiveDictionaries alloc] init];
    XCTAssertTrue([obj.intObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.floatObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.doubleObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.boolObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.stringObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.dataObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.dateObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.uuidObj isKindOfClass:[RLMDictionary class]]);

    [obj.intObj setObject:@1 forKey:@"one"];
    XCTAssertEqualObjects(obj.intObj[@"one"], @1);
    id nilValue;
    XCTAssertThrows([obj.intObj setObject:nilValue forKey:@"one"]);

    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    obj = [AllPrimitiveDictionaries createInRealm:realm withValue:@[]];

    XCTAssertTrue([obj.intObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.floatObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.doubleObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.boolObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.stringObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.dataObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.dateObj isKindOfClass:[RLMDictionary class]]);
    XCTAssertTrue([obj.uuidObj isKindOfClass:[RLMDictionary class]]);

    obj.intObj[@"two"] = @2;
    XCTAssertEqualObjects(obj.intObj[@"two"], @2);
    [realm cancelWriteTransaction];
}

- (void)testDeleteObjectInUnmanagedDictionary {
    DictionaryPropertyObject *dict = [[DictionaryPropertyObject alloc] init];

    StringObject *stringObj1 = [[StringObject alloc] init];
    stringObj1.stringCol = @"a";
    StringObject *stringObj2 = [[StringObject alloc] init];
    stringObj2.stringCol = @"b";
    StringObject *stringObj3 = [[StringObject alloc] init];
    stringObj3.stringCol = @"c";
    dict.stringDictionary[@"one"] = stringObj1;
    dict.stringDictionary[@"two"] = stringObj2;
    [dict.stringDictionary setObject:stringObj3 forKey:@"three"];

    IntObject *intObj1 = [[IntObject alloc] init];
    intObj1.intCol = 0;
    IntObject *intObj2 = [[IntObject alloc] init];
    intObj2.intCol = 1;
    IntObject *intObj3 = [[IntObject alloc] init];
    intObj3.intCol = 2;
    dict.intDictionary[@"one"] = intObj1;
    dict.intDictionary[@"two"] = intObj2;
    [dict.intDictionary setObject:intObj3 forKey:@"three"];

    XCTAssertEqualObjects(dict.stringDictionary[@"one"], stringObj1, @"Objects should be equal");
    XCTAssertEqualObjects([dict.stringDictionary objectForKey:@"two"], stringObj2, @"Objects should be equal");
    XCTAssertEqualObjects(dict.stringDictionary[@"three"], stringObj3, @"Objects should be equal");
    XCTAssertEqual(dict.stringDictionary.count, 3U, @"Should have 3 elements in string dictionary");

    XCTAssertEqualObjects(dict.intDictionary[@"one"], intObj1, @"Objects should be equal");
    XCTAssertEqualObjects([dict.intDictionary objectForKey:@"two"], intObj2, @"Objects should be equal");
    XCTAssertEqualObjects(dict.intDictionary[@"three"], intObj3, @"Objects should be equal");
    XCTAssertEqual(dict.intDictionary.count, 3U, @"Should have 3 elements in int dictionary");

    [dict.stringDictionary removeObjectForKey:@"three"];

    XCTAssertEqualObjects(dict.stringDictionary[@"one"], stringObj1, @"Objects should be equal");
    XCTAssertEqualObjects([dict.stringDictionary objectForKey:@"two"], stringObj2, @"Objects should be equal");
    XCTAssertEqual(dict.stringDictionary.count, 2U, @"Should have 2 elements in string dictionary");

    [dict.stringDictionary removeObjectForKey:@"three"]; // already deleted

    [dict.stringDictionary removeObjectForKey:@"two"];

    XCTAssertEqualObjects(dict.stringDictionary[@"one"], stringObj1, @"Objects should be equal");
    XCTAssertEqualObjects([dict.stringDictionary objectForKey:@"one"], stringObj1, @"Objects should be equal");
    XCTAssertEqual(dict.stringDictionary.count, 1U, @"Should have 1 elements in string dictionary");

    [dict.stringDictionary removeAllObjects];

    XCTAssertEqual(dict.stringDictionary.count, 0U, @"Should have 0 elements in string dictionary");

    [dict.intDictionary removeObjectsForKeys:@[@"one", @"two", @"three"]];
    XCTAssertEqual(dict.intDictionary.count, 0U, @"Should have 0 elements in int dictionary");
}

- (void)testFastEnumeration {
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];
    CompanyObject *company = [[CompanyObject alloc] init];
    company.name = @"name";
    [realm addObject:company];
    [realm commitWriteTransaction];

    // enumerate empty dictionary
    for (__unused id obj in company.employeeDict) {
        XCTFail(@"Should be empty");
    }

    [company.employeeDict enumerateKeysAndObjectsUsingBlock:^(id<RLMDictionaryKey>  _Nonnull key,
                                                              id  _Nonnull obj,
                                                              BOOL * _Nonnull stop) {
        XCTFail(@"Should be empty");
    }];

    [realm beginWriteTransaction];
    for (int i = 0; i < 30; ++i) {
        EmployeeObject *eo = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @40, @"hired": @YES}];
        NSString *key = [NSString stringWithFormat:@"item%d", i];
        company.employeeDict[key] = eo;
    }
    [realm commitWriteTransaction];

    XCTAssertEqual(company.employeeDict.count, 30U);

    __weak id objects[30];
    NSInteger count = 0;
    for (EmployeeObject *e in company.employeeDict) {
        XCTAssertNotNil(e, @"Object is not nil and accessible");
        if (count > 16) {
            // 16 is the size of blocks fast enumeration happens to ask for at
            // the moment, but of course that's just an implementation detail
            // that may change
            XCTAssertNil(objects[count - 16]);
        }
        objects[count++] = e;
    }

    XCTAssertEqual(count, 30, @"should have enumerated 30 objects");

    for (int i = 0; i < count; i++) {
        XCTAssertNil(objects[i], @"Object should have been released");
    }

    @autoreleasepool {
        for (EmployeeObject *e in company.employees) {
            objects[0] = e;
            break;
        }
    }
    XCTAssertNil(objects[0], @"Object should have been released");

    [company.employeeDict enumerateKeysAndObjectsUsingBlock:^(id<RLMDictionaryKey>  _Nonnull key,
                                                              id  _Nonnull obj,
                                                              BOOL * _Nonnull stop) {
        XCTAssertEqual(company.employeeDict[key], obj);
    }];
}

- (void)testModifyDuringEnumeration {
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];
    CompanyObject *company = [[CompanyObject alloc] init];
    company.name = @"name";
    [realm addObject:company];

    const size_t totalCount = 40;
    for (size_t i = 0; i < totalCount; ++i) {
        NSString *key = [NSString stringWithFormat:@"item%zu", i];
        company.employeeDict[key] = [EmployeeObject createInRealm:realm
                                                        withValue:@[@"name", @(i), @NO]];
    }

    size_t count = 0;
    for (EmployeeObject *eo in company.employeeDict) {
        NSString *key = [NSString stringWithFormat:@"item%zu", count];
        ++count;
        [company.employeeDict setObject:eo forKey:key];
    }
    XCTAssertEqual(totalCount, count);
    XCTAssertEqual(totalCount * 2, company.employeeDict.count);

    [realm cancelWriteTransaction];

    // Unmanaged dictionary
    company = [[CompanyObject alloc] init];
    for (size_t i = 0; i < totalCount; ++i) {
        NSString *key = [NSString stringWithFormat:@"item%zu", i];
        company.employeeDict[key] = [[EmployeeObject alloc] initWithValue:@[@"name", @(i), @NO]];
    }

    count = 0;
    for (EmployeeObject *eo in company.employeeDict) {
        NSString *key = [NSString stringWithFormat:@"item%zu", count];
        ++count;
        [company.employeeDict setObject:eo forKey:key];
    }
    XCTAssertEqual(totalCount, count);
    XCTAssertEqual(totalCount * 2, company.employeeDict.count);

    [company.employeeDict enumerateKeysAndObjectsUsingBlock:^(id<RLMDictionaryKey>  _Nonnull key,
                                                              id  _Nonnull obj,
                                                              BOOL * _Nonnull stop) {
        [company.employeeDict setObject:company forKey:key];
    }];
    XCTAssertEqual(totalCount * 2, company.employeeDict.count);
}

- (void)testDeleteDuringEnumeration {
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];
    CompanyObject *company = [[CompanyObject alloc] init];
    company.name = @"name";
    [realm addObject:company];

    const size_t totalCount = 40;
    for (size_t i = 0; i < totalCount; ++i) {
        NSString *key = [NSString stringWithFormat:@"item%zu", i];
        company.employeeDict[key] = [EmployeeObject createInRealm:realm withValue:@[@"name", @(i), @NO]];
    }

    [realm commitWriteTransaction];

    [realm beginWriteTransaction];
    for (__unused EmployeeObject *eo in company.employeeDict) {
        [realm deleteObjects:company.employeeDict];
    }
    [realm commitWriteTransaction];

    [realm beginWriteTransaction];
    for (size_t i = 0; i < totalCount; ++i) {
        NSString *key = [NSString stringWithFormat:@"item%zu", i];
        company.employeeDict[key] = [EmployeeObject createInRealm:realm withValue:@[@"name", @(i), @NO]];
    }
    [realm commitWriteTransaction];

    [realm beginWriteTransaction];
    [company.employeeDict enumerateKeysAndObjectsUsingBlock:^(id<RLMDictionaryKey>  _Nonnull key,
                                                              id  _Nonnull obj,
                                                              BOOL * _Nonnull stop) {
        [realm deleteObjects:company.employees];
    }];
    [realm commitWriteTransaction];
}

- (void)testValueForKey {
    RLMRealm *realm = self.realmWithTestPath;

    [realm beginWriteTransaction];
    CompanyObject *company = [[CompanyObject alloc] init];
    [realm addObject:company];
    [realm commitWriteTransaction];

    XCTAssertEqualObjects([company.employeeDict valueForKey:@"age"], @[]);

    // managed
    NSMutableArray *ages = [NSMutableArray array];
    [realm beginWriteTransaction];
    for (int i = 0; i < 30; ++i) {
        [ages addObject:@(i)];
        EmployeeObject *eo = [EmployeeObject createInRealm:realm withValue:@{@"name": @"Joe",  @"age": @(i), @"hired": @YES}];
        NSString *key = [NSString stringWithFormat:@"item%d", i];
        company.employeeDict[key] = eo;
    }
    [realm commitWriteTransaction];

    RLM_GENERIC_DICTIONARY(RLMString, EmployeeObject) *employeeObjects = [company valueForKey:@"employeeDict"];
    NSMutableArray *kvcAgeProperties = [NSMutableArray array];
    for (EmployeeObject *employee in employeeObjects) {
        [kvcAgeProperties addObject:@(employee.age)];
    }
    XCTAssertEqualObjects([kvcAgeProperties sortedArrayUsingSelector: @selector(compare:)], ages);

    XCTAssertEqualObjects([[company.employeeDict valueForKey:@"age"]
                           sortedArrayUsingSelector: @selector(compare:)], ages);
//    XCTAssertTrue([[[company.employeeDict valueForKey:@"self"] firstObject] isEqualToObject:company.employeeDict.firstObject]);
//    XCTAssertTrue([[[company.employeeDict valueForKey:@"self"] lastObject] isEqualToObject:company.employeeDict.lastObject]);

    XCTAssertEqual([[company.employeeDict valueForKeyPath:@"@count"] integerValue], 30);
    XCTAssertEqual([[company.employeeDict valueForKeyPath:@"@min.age"] integerValue], 0);
    XCTAssertEqual([[company.employeeDict valueForKeyPath:@"@max.age"] integerValue], 29);
    XCTAssertEqualWithAccuracy([[company.employeeDict valueForKeyPath:@"@avg.age"] doubleValue], 14.5, 0.1f);

    XCTAssertEqualObjects([company.employeeDict valueForKeyPath:@"@unionOfObjects.age"],
                          (@[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11, @12, @13, @14, @15, @16, @17, @18, @19, @20, @21, @22, @23, @24, @25, @26, @27, @28, @29]));
    XCTAssertEqualObjects([company.employeeDict valueForKeyPath:@"@distinctUnionOfObjects.name"], (@[@"Joe"]));

    RLMAssertThrowsWithReasonMatching([company.employeeDict valueForKeyPath:@"@sum.dogs.@sum.age"], @"Nested key paths.*not supported");

    // unmanaged object
    company = [[CompanyObject alloc] init];
    ages = [NSMutableArray array];
    for (int i = 0; i < 30; ++i) {
        [ages addObject:@(i)];
        EmployeeObject *eo = [[EmployeeObject alloc] initWithValue:@{@"name": @"Joe",  @"age": @(i), @"hired": @YES}];
        NSString *key = [NSString stringWithFormat:@"item%d", i];
        [company.employeeDict setObject:eo forKey:key];
    }

    XCTAssertEqualObjects([company.employeeDict valueForKey:@"age"], ages);
//    XCTAssertTrue([[[company.employeeDict valueForKey:@"self"] firstObject] isEqualToObject:company.employees.firstObject]);
//    XCTAssertTrue([[[company.employees valueForKey:@"self"] lastObject] isEqualToObject:company.employees.lastObject]);

    XCTAssertEqual([[company.employeeDict valueForKeyPath:@"@count"] integerValue], 30);
    XCTAssertEqual([[company.employeeDict valueForKeyPath:@"@min.age"] integerValue], 0);
    XCTAssertEqual([[company.employeeDict valueForKeyPath:@"@max.age"] integerValue], 29);
    XCTAssertEqualWithAccuracy([[company.employeeDict valueForKeyPath:@"@avg.age"] doubleValue], 14.5, 0.1f);

    XCTAssertEqualObjects([company.employeeDict valueForKeyPath:@"@unionOfObjects.age"],
                          (@[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11, @12, @13, @14, @15, @16, @17, @18, @19, @20, @21, @22, @23, @24, @25, @26, @27, @28, @29]));
    XCTAssertEqualObjects([company.employeeDict valueForKeyPath:@"@distinctUnionOfObjects.name"], (@[@"Joe"]));

    RLMAssertThrowsWithReasonMatching([company.employeeDict valueForKeyPath:@"@sum.dogs.@sum.age"], @"Nested key paths.*not supported");
}

@end
