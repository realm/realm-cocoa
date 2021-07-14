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

#import <realm/object-store/collection_notifications.hpp>

#import <vector>
#import <mutex>

namespace realm {
    class List;
    class Obj;
    class Results;
    class TableView;
    struct CollectionChangeSet;
    struct ColKey;
    namespace object_store {
        class Collection;
        class Dictionary;
        class Set;
    }
}
class RLMClassInfo;
@class RLMFastEnumerator, RLMManagedArray, RLMManagedSet, RLMManagedDictionary, RLMProperty, RLMObjectBase;

@protocol RLMFastEnumerable
@property (nonatomic, readonly) RLMRealm *realm;
@property (nonatomic, readonly) RLMClassInfo *objectInfo;
@property (nonatomic, readonly) NSUInteger count;

- (realm::TableView)tableView;
- (RLMFastEnumerator *)fastEnumerator;
@end

// An object which encapsulates the shared logic for fast-enumerating RLMArray
// RLMSet and RLMResults, and has a buffer to store strong references to the current
// set of enumerated items
@interface RLMFastEnumerator : NSObject

- (instancetype)initWithBackingCollection:(realm::object_store::Collection const&)backingCollection
                               collection:(id)collection
                                classInfo:(RLMClassInfo&)info;

- (instancetype)initWithBackingDictionary:(realm::object_store::Dictionary const&)backingDictionary
                               dictionary:(RLMManagedDictionary *)dictionary
                                classInfo:(RLMClassInfo&)info;

- (instancetype)initWithResults:(realm::Results&)results
                     collection:(id)collection
                      classInfo:(RLMClassInfo&)info;

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

@interface RLMCollectionChange ()
- (instancetype)initWithChanges:(realm::CollectionChangeSet)indices;
@end

@interface RLMCancellationToken : RLMNotificationToken {
@public
    __unsafe_unretained RLMRealm *_realm;
    realm::NotificationToken _token;
    std::mutex _mutex;
}
@end

realm::object_store::Set& RLMGetBackingCollection(RLMManagedSet *);
realm::object_store::Dictionary& RLMGetBackingCollection(RLMManagedDictionary *);
realm::List& RLMGetBackingCollection(RLMManagedArray *);
realm::Results& RLMGetBackingCollection(RLMResults *);

template<typename RLMCollection>
RLMNotificationToken *RLMAddNotificationBlock(RLMCollection *collection,
                                              NSArray<NSString *> *keyPaths,
                                              void (^block)(id, RLMCollectionChange *, NSError *),
                                              dispatch_queue_t queue);

template<typename Collection>
NSArray *RLMCollectionValueForKey(Collection& collection, NSString *key, RLMClassInfo& info);

std::vector<std::pair<std::string, bool>> RLMSortDescriptorsToKeypathArray(NSArray<RLMSortDescriptor *> *properties);

realm::ColKey columnForProperty(NSString *propertyName,
                                realm::object_store::Collection const& backingCollection,
                                RLMClassInfo *objectInfo,
                                RLMPropertyType propertyType,
                                RLMCollectionType collectionType);

static inline bool canAggregate(RLMPropertyType type, bool allowDate) {
    switch (type) {
        case RLMPropertyTypeInt:
        case RLMPropertyTypeFloat:
        case RLMPropertyTypeDouble:
        case RLMPropertyTypeDecimal128:
        case RLMPropertyTypeAny:
            return true;
        case RLMPropertyTypeDate:
            return allowDate;
        default:
            return false;
    }
}
