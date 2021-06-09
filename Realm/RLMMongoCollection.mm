////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

#import "RLMMongoCollection_Private.hpp"

#import "RLMApp_Private.hpp"
#import "RLMBSON_Private.hpp"
#import "RLMFindOneAndModifyOptions_Private.hpp"
#import "RLMFindOptions_Private.hpp"
#import "RLMIvarStorage.hpp"
#import "RLMNetworkTransport_Private.hpp"
#import "RLMUpdateResult_Private.hpp"
#import "RLMUser_Private.hpp"

#import <realm/object-store/sync/mongo_client.hpp>
#import <realm/object-store/sync/mongo_collection.hpp>
#import <realm/object-store/sync/mongo_database.hpp>

@implementation RLMChangeStream {
    RLMIvar<realm::app::WatchStream> _watchStream;
    id<RLMChangeEventDelegate> _subscriber;
    __weak NSURLSession *_session;
    _Nonnull dispatch_queue_t _queue;
}

- (instancetype)initWithChangeEventSubscriber:(id<RLMChangeEventDelegate>)subscriber
                                delegateQueue:(nullable dispatch_queue_t)queue {
    if (self = [super init]) {
        _subscriber = subscriber;
        _queue = queue ?: dispatch_get_main_queue();
        return self;
    }
    return nil;
}

- (void)didCloseWithError:(NSError *)error {
    dispatch_async(_queue, ^{
        [_subscriber changeStreamDidCloseWithError:error];
    });
}

- (void)didOpen {
    dispatch_async(_queue, ^{
        [_subscriber changeStreamDidOpen:self];
    });
}

- (void)didReceiveError:(nonnull NSError *)error {
    dispatch_async(_queue, ^{
        [_subscriber changeStreamDidReceiveError:error];
    });
}

- (void)didReceiveEvent:(nonnull NSData *)event {
    std::string_view str = [[NSString alloc] initWithData:event encoding:NSUTF8StringEncoding].UTF8String;
    if (!str.empty() && _watchStream->state() == realm::app::WatchStream::State::NEED_DATA) {
        _watchStream->feed_buffer(str);
    }

    while (_watchStream->state() == realm::app::WatchStream::State::HAVE_EVENT) {
        id<RLMBSON> event = RLMConvertBsonToRLMBSON(_watchStream->next_event());
        dispatch_async(_queue, ^{
            [_subscriber changeStreamDidReceiveChangeEvent:event];
        });
    }

    if (_watchStream->state() == realm::app::WatchStream::State::HAVE_ERROR) {
        [self didReceiveError:RLMAppErrorToNSError(_watchStream->error())];
    }
}

- (void)attachURLSession:(NSURLSession *)urlSession {
    _session = urlSession;
}

- (void)close {
    [_session invalidateAndCancel];
}

@end

@implementation RLMMongoCollection

static realm::bson::BsonDocument toBsonDocument(id<RLMBSON> bson) {
    return realm::bson::BsonDocument(RLMConvertRLMBSONToBson(bson));
}
static realm::bson::BsonArray toBsonArray(id<RLMBSON> bson) {
    return realm::bson::BsonArray(RLMConvertRLMBSONToBson(bson));
}

- (instancetype)initWithUser:(RLMUser *)user
                 serviceName:(NSString *)serviceName
                databaseName:(NSString *)databaseName
              collectionName:(NSString *)collectionName {
    if (self = [super init]) {
        _user = user;
        _serviceName = serviceName;
        _databaseName = databaseName;
        _name = collectionName;
    }
    return self;
}

- (realm::app::MongoCollection)collection:(NSString *)name {
    return _user._syncUser->mongo_client(self.serviceName.UTF8String)
        .db(self.databaseName.UTF8String).collection(name.UTF8String);
}

- (realm::app::MongoCollection)collection {
    return [self collection:self.name];
}

template<typename T>
static std::function<void(realm::util::Optional<T>, realm::util::Optional<realm::app::AppError>)>
wrapCompletion(void (^completion)(id, NSError *)) {
    return ^(realm::util::Optional<T> documents,
             realm::util::Optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, RLMAppErrorToNSError(*error));
        }
        completion(RLMConvertBsonToRLMBSON(*documents), nil);
    };
}

static std::function<void(uint64_t, realm::util::Optional<realm::app::AppError>)>
wrapCompletion(void (^completion)(NSInteger, NSError *)) {
    return [=](uint64_t count, realm::util::Optional<realm::app::AppError> error) {
        if (error) {
            return completion(0, RLMAppErrorToNSError(*error));
        }
        completion(static_cast<NSInteger>(count), nil);
    };
}

static std::function<void(realm::app::MongoCollection::UpdateResult, realm::util::Optional<realm::app::AppError>)>
wrapCompletion(void (^completion)(id, NSError *)) {
    return [completion](realm::app::MongoCollection::UpdateResult result,
                        realm::util::Optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, RLMAppErrorToNSError(*error));
        }
        completion([[RLMUpdateResult alloc] initWithUpdateResult:result], nil);
    };
}


- (void)findWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
          options:(RLMFindOptions *)options
       completion:(RLMMongoFindBlock)completion {
    self.collection.find(toBsonDocument(document), options._findOptions,
                         wrapCompletion<realm::bson::BsonArray>(completion));
}

- (void)findWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
       completion:(RLMMongoFindBlock)completion {
    [self findWhere:document options:[[RLMFindOptions alloc] init] completion:completion];
}

- (void)findOneDocumentWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
                     options:(RLMFindOptions *)options
                  completion:(RLMMongoFindOneBlock)completion {
    self.collection.find_one(toBsonDocument(document), options._findOptions,
                             wrapCompletion<realm::bson::BsonDocument>(completion));
}

- (void)findOneDocumentWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
                  completion:(RLMMongoFindOneBlock)completion {
    [self findOneDocumentWhere:document options:[[RLMFindOptions alloc] init] completion:completion];
}

- (void)insertOneDocument:(NSDictionary<NSString *, id<RLMBSON>> *)document
               completion:(RLMMongoInsertBlock)completion {
    self.collection.insert_one(toBsonDocument(document),
                             wrapCompletion<realm::bson::Bson>(completion));
}

- (void)insertManyDocuments:(NSArray<NSDictionary<NSString *, id<RLMBSON>> *> *)documents
                 completion:(RLMMongoInsertManyBlock)completion {
    self.collection.insert_many(toBsonArray(documents),
                                [completion](std::vector<realm::bson::Bson> insertedIds,
                                             realm::util::Optional<realm::app::AppError> error) {
        if (error) {
            return completion(nil, RLMAppErrorToNSError(*error));
        }
        NSMutableArray *insertedArr = [[NSMutableArray alloc] initWithCapacity:insertedIds.size()];
        for (auto& objectId : insertedIds) {
            [insertedArr addObject:RLMConvertBsonToRLMBSON(objectId)];
        }
        completion(insertedArr, nil);
    });
}

- (void)aggregateWithPipeline:(NSArray<NSDictionary<NSString *, id<RLMBSON>> *> *)pipeline
                   completion:(RLMMongoFindBlock)completion {
    self.collection.aggregate(toBsonArray(pipeline),
                              wrapCompletion<realm::bson::BsonArray>(completion));
}

- (void)countWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
             limit:(NSInteger)limit
        completion:(RLMMongoCountBlock)completion {
    self.collection.count(toBsonDocument(document), limit,
                          wrapCompletion(completion));
}

- (void)countWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
        completion:(RLMMongoCountBlock)completion {
    [self countWhere:document limit:0 completion:completion];
}

- (void)deleteOneDocumentWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
                    completion:(RLMMongoCountBlock)completion {
    self.collection.delete_one(toBsonDocument(document), wrapCompletion(completion));
}

- (void)deleteManyDocumentsWhere:(NSDictionary<NSString *, id<RLMBSON>> *)document
                      completion:(RLMMongoCountBlock)completion {
    self.collection.delete_many(toBsonDocument(document), wrapCompletion(completion));
}

- (void)updateOneDocumentWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
                updateDocument:(NSDictionary<NSString *, id<RLMBSON>> *)updateDocument
                        upsert:(BOOL)upsert
                    completion:(RLMMongoUpdateBlock)completion {
    self.collection.update_one(toBsonDocument(filterDocument), toBsonDocument(updateDocument),
                               upsert,
                               wrapCompletion(completion));
}

- (void)updateOneDocumentWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
                updateDocument:(NSDictionary<NSString *, id<RLMBSON>> *)updateDocument
                    completion:(RLMMongoUpdateBlock)completion {
    [self updateOneDocumentWhere:filterDocument
                  updateDocument:updateDocument
                          upsert:NO
                      completion:completion];
}

- (void)updateManyDocumentsWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
                  updateDocument:(NSDictionary<NSString *, id<RLMBSON>> *)updateDocument
                          upsert:(BOOL)upsert
                      completion:(RLMMongoUpdateBlock)completion {
    self.collection.update_many(toBsonDocument(filterDocument), toBsonDocument(updateDocument),
                                upsert,
                                wrapCompletion(completion));
}

- (void)updateManyDocumentsWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
                  updateDocument:(NSDictionary<NSString *, id<RLMBSON>> *)updateDocument
                      completion:(RLMMongoUpdateBlock)completion {
    [self updateManyDocumentsWhere:filterDocument
                    updateDocument:updateDocument
                            upsert:NO
                        completion:completion];
}

- (void)findOneAndUpdateWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
               updateDocument:(NSDictionary<NSString *, id<RLMBSON>> *)updateDocument
                      options:(RLMFindOneAndModifyOptions *)options
                   completion:(RLMMongoFindOneBlock)completion {
    self.collection.find_one_and_update(toBsonDocument(filterDocument), toBsonDocument(updateDocument),
                                        [options _findOneAndModifyOptions],
                                        wrapCompletion<realm::bson::BsonDocument>(completion));
}

- (void)findOneAndUpdateWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
               updateDocument:(NSDictionary<NSString *, id<RLMBSON>> *)updateDocument
                   completion:(RLMMongoFindOneBlock)completion {
    [self findOneAndUpdateWhere:filterDocument
                 updateDocument:updateDocument
                        options:[[RLMFindOneAndModifyOptions alloc] init]
                     completion:completion];
}

- (void)findOneAndReplaceWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
           replacementDocument:(NSDictionary<NSString *, id<RLMBSON>> *)replacementDocument
                       options:(RLMFindOneAndModifyOptions *)options
                    completion:(RLMMongoFindOneBlock)completion {
    self.collection.find_one_and_replace(toBsonDocument(filterDocument), toBsonDocument(replacementDocument),
                                         [options _findOneAndModifyOptions],
                                         wrapCompletion<realm::bson::BsonDocument>(completion));
}

- (void)findOneAndReplaceWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
           replacementDocument:(NSDictionary<NSString *, id<RLMBSON>> *)replacementDocument
                    completion:(RLMMongoFindOneBlock)completion {
    [self findOneAndReplaceWhere:filterDocument
             replacementDocument:replacementDocument
                         options:[[RLMFindOneAndModifyOptions alloc] init]
                      completion:completion];
}

- (void)findOneAndDeleteWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
                      options:(RLMFindOneAndModifyOptions *)options
                   completion:(RLMMongoDeleteBlock)completion {
    self.collection.find_one_and_delete(toBsonDocument(filterDocument),
                                        [options _findOneAndModifyOptions],
                                        wrapCompletion<realm::bson::BsonDocument>(completion));
}

- (void)findOneAndDeleteWhere:(NSDictionary<NSString *, id<RLMBSON>> *)filterDocument
                   completion:(RLMMongoDeleteBlock)completion {
    [self findOneAndDeleteWhere:filterDocument
                        options:[[RLMFindOneAndModifyOptions alloc] init]
                     completion:completion];
}

- (RLMChangeStream *)watchWithDelegate:(id<RLMChangeEventDelegate>)delegate
                         delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    return [self watchWithMatchFilter:nil
                             idFilter:nil
                             delegate:delegate
                        delegateQueue:delegateQueue];
}

- (RLMChangeStream *)watchWithFilterIds:(NSArray<RLMObjectId *> *)filterIds
                               delegate:(id<RLMChangeEventDelegate>)delegate
                          delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    return [self watchWithMatchFilter:nil
                             idFilter:filterIds
                             delegate:delegate
                        delegateQueue:delegateQueue];
}

- (RLMChangeStream *)watchWithMatchFilter:(NSDictionary<NSString *, id<RLMBSON>> *)matchFilter
                                 delegate:(id<RLMChangeEventDelegate>)delegate
                            delegateQueue:(nullable dispatch_queue_t)delegateQueue {
    return [self watchWithMatchFilter:matchFilter
                             idFilter:nil
                             delegate:delegate
                        delegateQueue:delegateQueue];
}

- (RLMChangeStream *)watchWithMatchFilter:(nullable id<RLMBSON>)matchFilter
                                 idFilter:(nullable id<RLMBSON>)idFilter
                                 delegate:(id<RLMChangeEventDelegate>)delegate
                            delegateQueue:(nullable dispatch_queue_t)queue {
    realm::bson::BsonDocument baseArgs = {
        {"database", self.databaseName.UTF8String},
        {"collection", self.name.UTF8String}
    };

    if (matchFilter) {
        baseArgs["filter"] = RLMConvertRLMBSONToBson(matchFilter);
    }
    if (idFilter) {
        baseArgs["ids"] = RLMConvertRLMBSONToBson(idFilter);
    }
    auto args = realm::bson::BsonArray{baseArgs};
    auto app = self.user.app._realmApp;
    auto request = app->make_streaming_request(app->current_user(), "watch", args,
                                               realm::util::Optional<std::string>(self.serviceName.UTF8String));
    RLMChangeStream *changeStream = [[RLMChangeStream alloc] initWithChangeEventSubscriber:delegate delegateQueue:queue];
    RLMNetworkTransport *transport = self.user.app.configuration.transport;
    RLMRequest *rlmRequest = [transport RLMRequestFromRequest:request];
    NSURLSession *watchSession = [transport doStreamRequest:rlmRequest
                                            eventSubscriber:changeStream];
    [changeStream attachURLSession:watchSession];
    return changeStream;
}

@end
