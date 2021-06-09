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

#import <Realm/RLMCollection_Private.h>

#import <Realm/RLMConstants.h>

#import <vector>

namespace realm {
    class List;
    class Results;
    class TableView;
    struct CollectionChangeSet;
    struct NotificationToken;
}
class RLMClassInfo;
@class RLMFastEnumerator, RLMManagedArray;

@protocol RLMFastEnumerable
@property (nonatomic, readonly) RLMRealm *realm;
@property (nonatomic, readonly) RLMClassInfo *objectInfo;
@property (nonatomic, readonly) NSUInteger count;

- (realm::TableView)tableView;
- (RLMFastEnumerator *)fastEnumerator;
@end

// An object which encapulates the shared logic for fast-enumerating RLMArray
// and RLMResults, and has a buffer to store strong references to the current
// set of enumerated items
@interface RLMFastEnumerator : NSObject
- (instancetype)initWithList:(realm::List&)list
                  collection:(id)collection
                   classInfo:(RLMClassInfo&)info RLM_OBJC_DIRECT;
- (instancetype)initWithResults:(realm::Results&)results
                     collection:(id)collection
                      classInfo:(RLMClassInfo&)info RLM_OBJC_DIRECT;

// Detach this enumerator from the source collection. Must be called before the
// source collection is changed.
- (void)detach;

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len;
@end
NSUInteger RLMFastEnumerate(NSFastEnumerationState *state, NSUInteger len, id<RLMFastEnumerable> collection);

@interface RLMNotificationToken ()
- (void)suppressNextNotification;
- (RLMRealm *)realm;
@end

realm::List& RLMGetBackingCollection(RLMManagedArray *);
realm::Results& RLMGetBackingCollection(RLMResults *);

template<typename RLMCollection>
RLMNotificationToken *RLMAddNotificationBlock(RLMCollection *collection,
                                              void (^block)(id, RLMCollectionChange *, NSError *),
                                              dispatch_queue_t queue);

template<typename Collection>
NSArray *RLMCollectionValueForKey(Collection& collection, NSString *key, RLMClassInfo& info);

std::vector<std::pair<std::string, bool>> RLMSortDescriptorsToKeypathArray(NSArray<RLMSortDescriptor *> *properties);
