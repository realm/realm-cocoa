//
//  RLMTestCase.m
//  Realm
//
//  Created by JP Simard on 4/22/14.
//  Copyright (c) 2014 Realm. All rights reserved.
//

#import "RLMTestCase.h"

NSString *const RLMTestRealmPath = @"test.realm";
NSString *const RLMTestRealmPathLock = @"test.realm.lock";

@implementation RLMTestCase

- (void)setUp {
    // This method is run before every test method
    [super setUp];
    [[NSFileManager defaultManager] removeItemAtPath:RLMTestRealmPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:RLMTestRealmPathLock error:nil];
}

+ (void)tearDown {
    [super tearDown];

    // This method is run after all tests in a test method have run
    [[NSFileManager defaultManager] removeItemAtPath:RLMTestRealmPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:RLMTestRealmPathLock error:nil];

}

- (RLMRealm *)realmWithTestPath {
    return [RLMRealm realmWithPath:RLMTestRealmPath error:nil];
}

- (void)createTestTableWithWriteBlock:(void(^)(RLMTable *table))block {
    RLMRealm *realm = [RLMRealm realmWithPath:RLMTestRealmPath];
    [realm beginWriteTransaction];
    block([realm createTableWithName:@"table"]);
    [realm commitWriteTransaction];
}

@end
