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

#import <Foundation/Foundation.h>

#import <realm/obj.hpp>
#import <realm/object-store/binding_context.hpp>
#import <realm/object-store/impl/deep_change_checker.hpp>
#import <realm/table.hpp>

@class RLMObjectBase, RLMRealm, RLMSchema, RLMProperty, RLMObjectSchema;
class RLMClassInfo;
class RLMSchemaInfo;

namespace realm {
    class History;
    class SharedGroup;
    struct TableKey;
    struct ColKey;
}

// RLMObservationInfo stores all of the KVO-related data for RLMObjectBase and
// RLMSet/Array. There is a one-to-one relationship between observed objects and
// RLMObservationInfo instances, so it could be folded into RLMObjectBase, and
// is a separate class mostly to avoid making all accessor objects far larger.
//
// RLMClassInfo stores a vector of pointers to the first observation info
// created for each row. If there are multiple observation infos for a single
// row (such as if there are multiple observed objects backed by a single row,
// or if both an object and an array property of that object are observed),
// they're stored in an intrusive doubly-linked-list in the `next` and `prev`
// members. This is done primarily to make it simpler and faster to loop over
// all of the observed objects for a single row, as that needs to be done for
// every change.
class RLMObservationInfo {
public:
    RLMObservationInfo(id object);
    RLMObservationInfo(RLMClassInfo &objectSchema, realm::ObjKey row, id object);
    ~RLMObservationInfo();

    realm::Obj const& getRow() const {
        return row;
    }

    NSString *columnName(realm::ColKey col) const noexcept;

    // Send willChange/didChange notifications to all observers for this object/row
    // Sends the array versions if indexes is non-nil, normal versions otherwise
    void willChange(NSString *key, NSKeyValueChange kind=NSKeyValueChangeSetting, NSIndexSet *indexes=nil) const;
    void didChange(NSString *key, NSKeyValueChange kind=NSKeyValueChangeSetting, NSIndexSet *indexes=nil) const;

    bool isForRow(realm::ObjKey key) const {
        return row.get_key() == key;
    }

    void recordObserver(realm::Obj& row, RLMClassInfo *objectInfo, RLMObjectSchema *objectSchema, NSString *keyPath);
    void removeObserver();
    bool hasObservers() const { return observerCount > 0; }

    // valueForKey: on observed object and array properties needs to return the
    // same object each time for KVO to work at all. Doing this all the time
    // requires some odd semantics to avoid reference cycles, so instead we do
    // it only to the extent specifically required by KVO. In addition, we
    // need to continue to return the same object even if this row is deleted,
    // or deleting an object with active observers will explode horribly.
    // Once prepareForInvalidation() is called, valueForKey() will always return
    // the cached value for object and array properties without checking the
    // backing row to verify it's up-to-date.
    //
    // prepareForInvalidation() must be called on the head of the linked list
    // (i.e. on the object pointed to directly by the object schema)
    id valueForKey(NSString *key);

    void prepareForInvalidation();
private:
    // Doubly-linked-list of observed objects for the same row as this
    RLMObservationInfo *next = nullptr;
    RLMObservationInfo *prev = nullptr;

    // Row being observed
    realm::Obj row;
    RLMClassInfo *objectSchema = nullptr;

    // Object doing the observing
    __unsafe_unretained id object = nil;

    // valueForKey: hack
    bool invalidated = false;
    size_t observerCount = 0;
    NSString *lastKey = nil;
    __unsafe_unretained RLMProperty *lastProp = nil;

    // objects returned from valueForKey() to keep them alive in case observers
    // are added and so that they can still be accessed after row is detached
    NSMutableDictionary *cachedObjects;

    void setRow(realm::Table const& table, realm::ObjKey newRow);

    template<typename F>
    void forEach(F&& f) const {
        // The user's observation handler may release their last reference to
        // the object being observed, which will result in the RLMObservationInfo
        // being destroyed. As a result, we need to retain the object which owns
        // both `this` and the current info we're looking at.
        __attribute__((objc_precise_lifetime)) id self = object, current;
        for (auto info = prev; info; info = info->prev) {
            current = info->object;
            f(info->object);
        }
        for (auto info = this; info; info = info->next) {
            current = info->object;
            f(info->object);
        }
    }

    // Default move/copy constructors don't work due to the intrusive linked
    // list and we don't need them
    RLMObservationInfo(RLMObservationInfo const&) = delete;
    RLMObservationInfo(RLMObservationInfo&&) = delete;
    RLMObservationInfo& operator=(RLMObservationInfo const&) = delete;
    RLMObservationInfo& operator=(RLMObservationInfo&&) = delete;
};

// Get the the observation info chain for the given row
// Will simply return info if it's non-null, and will search ojectSchema's array
// for a matching one otherwise, and return null if there are none
RLMObservationInfo *RLMGetObservationInfo(RLMObservationInfo *info, realm::ObjKey row, RLMClassInfo& objectSchema);

// delete all objects from a single table with change notifications
void RLMClearTable(RLMClassInfo &realm);

class RLMObservationTracker {
public:
    RLMObservationTracker(RLMRealm *realm, bool trackDeletions=false);
    ~RLMObservationTracker();

    void trackDeletions();

    void willChange(RLMObservationInfo *info, NSString *key,
                    NSKeyValueChange kind=NSKeyValueChangeSetting,
                    NSIndexSet *indexes=nil);
    void didChange();

private:
    std::vector<std::vector<RLMObservationInfo *> *> _observedTables;
    __unsafe_unretained RLMRealm const*_realm;
    realm::Group& _group;
    RLMObservationInfo *_info = nullptr;

    NSString *_key;
    NSKeyValueChange _kind = NSKeyValueChangeSetting;
    NSIndexSet *_indexes;

    struct Change {
        RLMObservationInfo *info;
        __unsafe_unretained NSString *property;
        NSMutableIndexSet *indexes;
    };
    std::vector<Change> _changes;
    std::vector<RLMObservationInfo *> _invalidated;

    template<typename CascadeNotification>
    void cascadeNotification(CascadeNotification const&);
};

std::vector<realm::BindingContext::ObserverState> RLMGetObservedRows(RLMSchemaInfo const& schema);
void RLMWillChange(std::vector<realm::BindingContext::ObserverState> const& observed, std::vector<void *> const& invalidated);
void RLMDidChange(std::vector<realm::BindingContext::ObserverState> const& observed, std::vector<void *> const& invalidated);

// ???: Will not using RLM conflict with other libraries?
realm::KeyPath KeyPathFromString(RLMRealm *realm,
                                 RLMSchema *schema,
                                 RLMObjectSchema *objectSchema,
                                 RLMClassInfo *info,
                                 NSString *keyPath);

// KeyPathFromString converts a string keypath to a vector of key
// pairs to be used for deep change checking across links.
realm::KeyPathArray KeyPathArrayFromStringArray(RLMRealm *realm,
                                                RLMSchema *schema,
                                                RLMObjectSchema *objectSchema,
                                                RLMClassInfo *info,
                                                NSArray<NSString *> *keyPath);
