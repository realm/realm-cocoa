////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "RLMMultiProcessTestCase.h"

@class RLMAppConfiguration;
typedef NS_ENUM(NSUInteger, RLMSyncStopPolicy);
typedef void(^RLMSyncBasicErrorReportingBlock)(NSError * _Nullable);

NS_ASSUME_NONNULL_BEGIN

@interface Dog : RLMObject

@property RLMObjectId *_id;
@property NSString *breed;
@property NSString *name;
@end

@interface Person : RLMObject

@property RLMObjectId *_id;
@property NSInteger age;
@property NSString *firstName;
@property NSString *lastName;

- (instancetype) initWithPrimaryKey:(RLMObjectId *)primaryKey age:(NSInteger)strCol firstName:(NSString *)intCol lastName:(NSString *)intCol;
+ (instancetype)john;
+ (instancetype)paul;
+ (instancetype)ringo;
+ (instancetype)george;
+ (instancetype)stuart;

@end

@interface HugeSyncObject : RLMObject
@property RLMObjectId *_id;
@property NSData *dataProp;
+ (instancetype)hugeSyncObject;
@end

@interface UUIDPrimaryKeyObject : RLMObject
@property NSUUID *_id;
@property NSString *strCol;
@property NSInteger intCol;
- (instancetype) initWithPrimaryKey:(NSUUID *)primaryKey strCol:(NSString *)strCol intCol:(NSInteger)intCol;
@end

@interface StringPrimaryKeyObject : RLMObject
@property NSString *_id;
@property NSString *strCol;
@property NSInteger intCol;
- (instancetype) initWithPrimaryKey:(NSString *)primaryKey strCol:(NSString *)strCol intCol:(NSInteger)intCol;
@end

@interface IntPrimaryKeyObject : RLMObject
@property NSInteger _id;
@property NSString *strCol;
@property NSInteger intCol;
- (instancetype) initWithPrimaryKey:(NSInteger)primaryKey strCol:(NSString *)strCol intCol:(NSInteger)intCol;
@end

@interface AllTypesSyncObject : RLMObject
@property RLMObjectId *_id;
@property BOOL boolCol;
@property bool cBoolCol;
@property int intCol;
@property double doubleCol;
@property NSString *stringCol;
@property NSData *binaryCol;
@property NSDate *dateCol;
@property int64_t longCol;
@property RLMDecimal128 *decimalCol;
@property NSUUID *uuidCol;
@property id<RLMValue> anyCol;
@property Person *objectCol;
+ (NSDictionary *)values:(int)i;
@end

RLM_COLLECTION_TYPE(Person);
@interface RLMArraySyncObject : RLMObject
@property RLMObjectId *_id;
@property RLMArray<RLMInt> *intArray;
@property RLMArray<RLMBool> *boolArray;
@property RLMArray<RLMString> *stringArray;
@property RLMArray<RLMData> *dataArray;
@property RLMArray<RLMDouble> *doubleArray;
@property RLMArray<RLMObjectId> *objectIdArray;
@property RLMArray<RLMDecimal128> *decimalArray;
@property RLMArray<RLMUUID> *uuidArray;
@property RLMArray<RLMValue> *anyArray;
@property RLM_GENERIC_ARRAY(Person) *objectArray;
@end

@interface RLMSetSyncObject : RLMObject
@property RLMObjectId *_id;
@property RLMSet<RLMInt> *intSet;
@property RLMSet<RLMBool> *boolSet;
@property RLMSet<RLMString> *stringSet;
@property RLMSet<RLMData> *dataSet;
@property RLMSet<RLMDouble> *doubleSet;
@property RLMSet<RLMObjectId> *objectIdSet;
@property RLMSet<RLMDecimal128> *decimalSet;
@property RLMSet<RLMUUID> *uuidSet;
@property RLMSet<RLMValue> *anySet;
@property RLM_GENERIC_SET(Person) *objectSet;

@property RLMSet<RLMInt> *otherIntSet;
@property RLMSet<RLMBool> *otherBoolSet;
@property RLMSet<RLMString> *otherStringSet;
@property RLMSet<RLMData> *otherDataSet;
@property RLMSet<RLMDouble> *otherDoubleSet;
@property RLMSet<RLMObjectId> *otherObjectIdSet;
@property RLMSet<RLMDecimal128> *otherDecimalSet;
@property RLMSet<RLMUUID> *otherUuidSet;
@property RLMSet<RLMValue> *otherAnySet;
@property RLM_GENERIC_SET(Person) *otherObjectSet;
@end


@interface RLMDictionarySyncObject : RLMObject
@property RLMObjectId *_id;
@property RLMDictionary<NSString *, NSNumber *><RLMString, RLMInt> *intDictionary;
@property RLMDictionary<NSString *, NSNumber *><RLMString, RLMBool> *boolDictionary;
@property RLMDictionary<NSString *, NSString *><RLMString, RLMString> *stringDictionary;
@property RLMDictionary<NSString *, NSData *><RLMString, RLMData> *dataDictionary;
@property RLMDictionary<NSString *, NSNumber *><RLMString, RLMDouble> *doubleDictionary;
@property RLMDictionary<NSString *, RLMObjectId *><RLMString, RLMObjectId> *objectIdDictionary;
@property RLMDictionary<NSString *, RLMDecimal128 *><RLMString, RLMDecimal128> *decimalDictionary;
@property RLMDictionary<NSString *, NSUUID *><RLMString, RLMUUID> *uuidDictionary;
@property RLMDictionary<NSString *, NSObject *><RLMString, RLMValue> *anyDictionary;
@property RLMDictionary<NSString *, Person *><RLMString, Person> *objectDictionary;

@end

@interface AsyncOpenConnectionTimeoutTransport : RLMNetworkTransport
@end

@interface RLMSyncTestCase : RLMMultiProcessTestCase

@property (nonatomic, readonly) NSString *appId;
@property (nonatomic, readonly) RLMApp *app;
@property (nonatomic, readonly) RLMUser *anonymousUser;
@property (nonatomic, readonly) RLMAppConfiguration *defaultAppConfiguration;

/// Any stray app ids passed between processes
@property (nonatomic, readonly) NSArray<NSString *> *appIds;

- (RLMCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister;

- (RLMCredentials *)basicCredentialsWithName:(NSString *)name register:(BOOL)shouldRegister app:(nullable RLMApp*) app;

/// Synchronously open a synced Realm via asyncOpen and return the Realm.
- (RLMRealm *)asyncOpenRealmWithConfiguration:(RLMRealmConfiguration *)configuration;

/// Synchronously open a synced Realm via asyncOpen and return the expected error.
- (NSError *)asyncOpenErrorWithConfiguration:(RLMRealmConfiguration *)configuration;

/// Synchronously open a synced Realm and wait for downloads.
- (RLMRealm *)openRealmForPartitionValue:(nullable id<RLMBSON>)partitionValue
                                    user:(RLMUser *)user;

/// Synchronously open a synced Realm with encryption key and stop policy and wait for downloads.
- (RLMRealm *)openRealmForPartitionValue:(nullable id<RLMBSON>)partitionValue
                                    user:(RLMUser *)user
                           encryptionKey:(nullable NSData *)encryptionKey
                              stopPolicy:(RLMSyncStopPolicy)stopPolicy;

/// Synchronously open a synced Realm.
- (RLMRealm *)openRealmWithConfiguration:(RLMRealmConfiguration *)configuration;

/// Immediately open a synced Realm.
- (RLMRealm *)immediatelyOpenRealmForPartitionValue:(nullable id<RLMBSON>)partitionValue user:(RLMUser *)user;

/// Immediately open a synced Realm with encryption key and stop policy.
- (RLMRealm *)immediatelyOpenRealmForPartitionValue:(nullable id<RLMBSON>)partitionValue
                                               user:(RLMUser *)user
                                      encryptionKey:(nullable NSData *)encryptionKey
                                         stopPolicy:(RLMSyncStopPolicy)stopPolicy;

/// Synchronously create, log in, and return a user.
- (RLMUser *)logInUserForCredentials:(RLMCredentials *)credentials;
- (RLMUser *)logInUserForCredentials:(RLMCredentials *)credentials app:(RLMApp *)app;

/// Synchronously, log out.
- (void)logOutUser:(RLMUser *)user;

- (void)addPersonsToRealm:(RLMRealm *)realm persons:(NSArray<Person *> *)persons;

- (void)addAllTypesSyncObjectToRealm:(RLMRealm *)realm values:(NSDictionary *)dictionary person:(Person *)person;

/// Synchronously wait for downloads to complete for any number of Realms, and then check their `SyncObject` counts.
- (void)waitForDownloadsForUser:(RLMUser *)user
                         realms:(NSArray<RLMRealm *> *)realms
                partitionValues:(NSArray<NSString *> *)partitionValues
                 expectedCounts:(NSArray<NSNumber *> *)counts;

/// Wait for downloads to complete; drop any error.
- (void)waitForDownloadsForRealm:(RLMRealm *)realm;
- (void)waitForDownloadsForRealm:(RLMRealm *)realm error:(NSError **)error;

/// Wait for uploads to complete; drop any error.
- (void)waitForUploadsForRealm:(RLMRealm *)realm;
- (void)waitForUploadsForRealm:(RLMRealm *)realm error:(NSError **)error;

/// Wait for downloads to complete while spinning the runloop. This method uses expectations.
- (void)waitForDownloadsForUser:(RLMUser *)user
                 partitionValue:(NSString *)partitionValue
                    expectation:(nullable XCTestExpectation *)expectation
                          error:(NSError **)error;

/// Manually set the access token for a user. Used for testing invalid token conditions.
- (void)manuallySetAccessTokenForUser:(RLMUser *)user value:(NSString *)tokenValue;

/// Manually set the refresh token for a user. Used for testing invalid token conditions.
- (void)manuallySetRefreshTokenForUser:(RLMUser *)user value:(NSString *)tokenValue;

- (void)resetSyncManager;

- (NSString *)badAccessToken;

- (void)cleanupRemoteDocuments:(RLMMongoCollection *)collection;

- (nonnull NSURL *)clientDataRoot;

- (NSString *)partitionBsonType:(id<RLMBSON>)bson;

- (RLMApp *)appFromAppId:(NSString *)appId;

- (void)resetAppCache;

@end

NS_ASSUME_NONNULL_END

#define WAIT_FOR_SEMAPHORE(macro_semaphore, macro_timeout) \
{                                                                                                                      \
    int64_t delay_in_ns = (int64_t)(macro_timeout * NSEC_PER_SEC);                                                     \
    BOOL sema_success = dispatch_semaphore_wait(macro_semaphore, dispatch_time(DISPATCH_TIME_NOW, delay_in_ns)) == 0;  \
    XCTAssertTrue(sema_success, @"Semaphore timed out.");                                                              \
}

#define CHECK_COUNT(d_count, macro_object_type, macro_realm) \
{                                                                                                         \
    [macro_realm refresh];                                                                                \
    RLMResults *r = [macro_object_type allObjectsInRealm:macro_realm];                                    \
    NSInteger c = r.count;                                                                                \
    NSString *w = self.isParent ? @"parent" : @"child";                                                   \
    XCTAssert(d_count == c, @"Expected %@ items, but actually got %@ (%@) (%@)", @(d_count), @(c), r, w); \
}
