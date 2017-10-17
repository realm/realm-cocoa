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

#import "RLMObservation.hpp"

#import "RLMAccessor.h"
#import "RLMArray_Private.hpp"
#import "RLMInteger_Private.h"
#import "RLMListBase.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObject_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMRealm_Private.hpp"

#import <realm/group.hpp>

using namespace realm;

namespace {
    template<typename Iterator>
    struct IteratorPair {
        Iterator first;
        Iterator second;
    };
    template<typename Iterator>
    Iterator begin(IteratorPair<Iterator> const& p) {
        return p.first;
    }
    template<typename Iterator>
    Iterator end(IteratorPair<Iterator> const& p) {
        return p.second;
    }

    template<typename Container>
    auto reverse(Container const& c) {
        return IteratorPair<typename Container::const_reverse_iterator>{c.rbegin(), c.rend()};
    }
}

RLMObservationInfo::RLMObservationInfo(RLMClassInfo &objectSchema, std::size_t row, id object)
: object(object)
, objectSchema(&objectSchema)
{
    setRow(*objectSchema.table(), row);
}

RLMObservationInfo::RLMObservationInfo(id object)
: object(object)
{
}

RLMObservationInfo::~RLMObservationInfo() {
    if (prev) {
        // Not the head of the linked list, so just detach from the list
        REALM_ASSERT_DEBUG(prev->next == this);
        prev->next = next;
        if (next) {
            REALM_ASSERT_DEBUG(next->prev == this);
            next->prev = prev;
        }
    }
    else if (objectSchema) {
        // The head of the list, so remove self from the object schema's array
        // of observation info, either replacing self with the next info or
        // removing entirely if there is no next
        auto end = objectSchema->observedObjects.end();
        auto it = find(objectSchema->observedObjects.begin(), end, this);
        if (it != end) {
            if (next) {
                *it = next;
                next->prev = nullptr;
            }
            else {
                iter_swap(it, std::prev(end));
                objectSchema->observedObjects.pop_back();
            }
        }
    }
    // Otherwise the observed object was unmanaged, so nothing to do

#ifdef DEBUG
    // ensure that incorrect cleanup fails noisily
    object = (__bridge id)(void *)-1;
    prev = (RLMObservationInfo *)-1;
    next = (RLMObservationInfo *)-1;
#endif
}

NSString *RLMObservationInfo::columnName(size_t col) const noexcept {
    return objectSchema->propertyForTableColumn(col).name;
}

void RLMObservationInfo::willChange(NSString *key, NSKeyValueChange kind, NSIndexSet *indexes) const {
    if (indexes) {
        forEach([=](__unsafe_unretained auto o) {
            [o willChange:kind valuesAtIndexes:indexes forKey:key];
        });
    }
    else {
        forEach([=](__unsafe_unretained auto o) {
            [o willChangeValueForKey:key];
        });
    }
}

void RLMObservationInfo::didChange(NSString *key, NSKeyValueChange kind, NSIndexSet *indexes) const {
    if (indexes) {
        forEach([=](__unsafe_unretained auto o) {
            [o didChange:kind valuesAtIndexes:indexes forKey:key];
        });
    }
    else {
        forEach([=](__unsafe_unretained auto o) {
            [o didChangeValueForKey:key];
        });
    }
}

void RLMObservationInfo::prepareForInvalidation() {
    REALM_ASSERT_DEBUG(objectSchema);
    REALM_ASSERT_DEBUG(!prev);
    for (auto info = this; info; info = info->next)
        info->invalidated = true;
}

void RLMObservationInfo::setRow(realm::Table &table, size_t newRow) {
    REALM_ASSERT_DEBUG(!row);
    REALM_ASSERT_DEBUG(objectSchema);
    row = table[newRow];
    for (auto info : objectSchema->observedObjects) {
        if (info->row && info->row.get_index() == row.get_index()) {
            prev = info;
            next = info->next;
            if (next)
                next->prev = this;
            info->next = this;
            return;
        }
    }
    objectSchema->observedObjects.push_back(this);
}

void RLMObservationInfo::recordObserver(realm::Row& objectRow, RLMClassInfo *objectInfo,
                                        __unsafe_unretained RLMObjectSchema *const objectSchema,
                                        __unsafe_unretained NSString *const keyPath) {
    ++observerCount;
    if (row) {
        return;
    }

    // add ourselves to the list of observed objects if this is the first time
    // an observer is being added to a managed object
    if (objectRow) {
        this->objectSchema = objectInfo;
        setRow(*objectRow.get_table(), objectRow.get_index());
        return;
    }

    // Arrays need a reference to their containing object to avoid having to
    // go through the awful proxy object from mutableArrayValueForKey.
    // For managed objects we do this when the object is added or created
    // (and have to to support notifications from modifying an object which
    // was never observed), but for Swift classes (both RealmSwift and
    // RLMObject) we can't do it then because we don't know what the parent
    // object is.

    NSUInteger sep = [keyPath rangeOfString:@"."].location;
    NSString *key = sep == NSNotFound ? keyPath : [keyPath substringToIndex:sep];
    RLMProperty *prop = objectSchema[key];
    if (prop && prop.array) {
        id value = valueForKey(key);
        RLMArray *array = [value isKindOfClass:[RLMListBase class]] ? [value _rlmArray] : value;
        array->_key = key;
        array->_parentObject = object;
    }
    else if (auto swiftIvar = prop.swiftIvar) {
        if (auto optional = RLMDynamicCast<RLMOptionalBase>(object_getIvar(object, swiftIvar))) {
            optional.property = prop;
            optional.object = object;
        }
    }
}

void RLMObservationInfo::removeObserver() {
    --observerCount;
}

id RLMObservationInfo::valueForKey(NSString *key) {
    if (invalidated) {
        if ([key isEqualToString:RLMInvalidatedKey]) {
            return @YES;
        }
        return cachedObjects[key];
    }

    if (key != lastKey) {
        lastKey = key;
        lastProp = objectSchema ? objectSchema->rlmObjectSchema[key] : nil;
    }

    static auto superValueForKey = reinterpret_cast<id(*)(id, SEL, NSString *)>([NSObject methodForSelector:@selector(valueForKey:)]);
    if (!lastProp) {
        // Not a managed property, so use NSObject's implementation of valueForKey:
        id value = RLMCoerceToNil(superValueForKey(object, @selector(valueForKey:), key));
        return value;
    }

    auto getSuper = [&] {
        return row ? RLMDynamicGet(object, lastProp) : RLMCoerceToNil(superValueForKey(object, @selector(valueForKey:), key));
    };

    // We need to return the same object each time for observing over keypaths
    // to work, so we store a cache of them here. We can't just cache them on
    // the object as that leads to retain cycles.
    if (lastProp.array) {
        RLMArray *value = cachedObjects[key];
        if (!value) {
            value = getSuper();
            if (!cachedObjects) {
                cachedObjects = [NSMutableDictionary new];
            }
            cachedObjects[key] = value;
        }
        return value;
    }

    if (lastProp.type == RLMPropertyTypeObject) {
        size_t col = row.get_column_index(lastProp.name.UTF8String);
        if (row.is_null_link(col)) {
            [cachedObjects removeObjectForKey:key];
            return nil;
        }

        RLMObjectBase *value = cachedObjects[key];
        if (value && value->_row.get_index() == row.get_link(col)) {
            return value;
        }
        value = getSuper();
        if (!cachedObjects) {
            cachedObjects = [NSMutableDictionary new];
        }
        cachedObjects[key] = value;
        return value;
    }

    return getSuper();
}

RLMObservationInfo *RLMGetObservationInfo(RLMObservationInfo *info, size_t row,
                                          RLMClassInfo& objectSchema) {
    if (info) {
        return info;
    }

    for (RLMObservationInfo *info : objectSchema.observedObjects) {
        if (info->isForRow(row)) {
            return info;
        }
    }

    return nullptr;
}

void RLMClearTable(RLMClassInfo &objectSchema) {
    for (auto info : objectSchema.observedObjects) {
        info->willChange(RLMInvalidatedKey);
    }

    RLMTrackDeletions(objectSchema.realm, ^{
        objectSchema.table()->clear();

        for (auto info : objectSchema.observedObjects) {
            info->prepareForInvalidation();
        }
    });

    for (auto info : reverse(objectSchema.observedObjects)) {
        info->didChange(RLMInvalidatedKey);
    }

    objectSchema.observedObjects.clear();
}

void RLMTrackDeletions(__unsafe_unretained RLMRealm *const realm, dispatch_block_t block) {
    std::vector<std::vector<RLMObservationInfo *> *> observers;

    // Build up an array of observation info arrays which is indexed by table
    // index (the object schemata may be in an entirely different order)
    for (auto& info : realm->_info) {
        if (info.second.observedObjects.empty()) {
            continue;
        }
        size_t ndx = info.second.table()->get_index_in_group();
        if (ndx >= observers.size()) {
            observers.resize(std::max(observers.size() * 2, ndx + 1));
        }
        observers[ndx] = &info.second.observedObjects;
    }

    // No need for change tracking if no objects are observed
    if (observers.empty()) {
        block();
        return;
    }

    struct change {
        RLMObservationInfo *info;
        __unsafe_unretained NSString *property;
        NSMutableIndexSet *indexes;
    };

    std::vector<change> changes;
    std::vector<RLMObservationInfo *> invalidated;

    // This callback is called by core with a list of row deletions and
    // resulting link nullifications immediately before things are deleted and nullified
    realm.group.set_cascade_notification_handler([&](realm::Group::CascadeNotification const& cs) {
        for (auto const& link : cs.links) {
            size_t table_ndx = link.origin_table->get_index_in_group();
            if (table_ndx >= observers.size() || !observers[table_ndx]) {
                // The modified table has no observers
                continue;
            }

            for (auto observer : *observers[table_ndx]) {
                if (!observer->isForRow(link.origin_row_ndx)) {
                    continue;
                }

                NSString *name = observer->columnName(link.origin_col_ndx);
                if (observer->getRow().get_table()->get_column_type(link.origin_col_ndx) != type_LinkList) {
                    changes.push_back({observer, name});
                    continue;
                }

                auto c = find_if(begin(changes), end(changes), [&](auto const& c) {
                    return c.info == observer && c.property == name;
                });
                if (c == end(changes)) {
                    changes.push_back({observer, name, [NSMutableIndexSet new]});
                    c = prev(end(changes));
                }

                // We know what row index is being removed from the LinkView,
                // but what we actually want is the indexes in the LinkView that
                // are going away
                auto linkview = observer->getRow().get_linklist(link.origin_col_ndx);
                size_t start = 0, index;
                while ((index = linkview->find(link.old_target_row_ndx, start)) != realm::not_found) {
                    [c->indexes addIndex:index];
                    start = index + 1;
                }
            }
        }

        for (auto const& row : cs.rows) {
            if (row.table_ndx >= observers.size() || !observers[row.table_ndx]) {
                // The modified table has no observers
                continue;
            }

            for (auto observer : *observers[row.table_ndx]) {
                if (observer->isForRow(row.row_ndx)) {
                    invalidated.push_back(observer);
                    break;
                }
            }
        }

        // The relative order of these loops is very important
        for (auto info : invalidated) {
            info->willChange(RLMInvalidatedKey);
        }
        for (auto const& change : changes) {
            change.info->willChange(change.property, NSKeyValueChangeRemoval, change.indexes);
        }
        for (auto info : invalidated) {
            info->prepareForInvalidation();
        }
    });

    try {
        block();
    }
    catch (...) {
        realm.group.set_cascade_notification_handler(nullptr);
        throw;
    }

    for (auto const& change : reverse(changes)) {
        change.info->didChange(change.property, NSKeyValueChangeRemoval, change.indexes);
    }
    for (auto info : reverse(invalidated)) {
        info->didChange(RLMInvalidatedKey);
    }

    realm.group.set_cascade_notification_handler(nullptr);
}

namespace {
template<typename Func>
void forEach(realm::BindingContext::ObserverState const& state, Func&& func) {
    for (size_t i = 0, size = state.changes.size(); i < size; ++i) {
        if (state.changes[i].kind != realm::BindingContext::ColumnInfo::Kind::None) {
            func(i, state.changes[i], static_cast<RLMObservationInfo *>(state.info));
        }
    }
}
}

std::vector<realm::BindingContext::ObserverState> RLMGetObservedRows(RLMSchemaInfo const& schema) {
    std::vector<realm::BindingContext::ObserverState> observers;
    for (auto& table : schema) {
        for (auto info : table.second.observedObjects) {
            auto const& row = info->getRow();
            if (!row.is_attached())
                continue;
            observers.push_back({
                row.get_table()->get_index_in_group(),
                row.get_index(),
                info});
        }
    }
    sort(begin(observers), end(observers));
    return observers;
}

static NSKeyValueChange convert(realm::BindingContext::ColumnInfo::Kind kind) {
    switch (kind) {
        case realm::BindingContext::ColumnInfo::Kind::None:
        case realm::BindingContext::ColumnInfo::Kind::SetAll:
            return NSKeyValueChangeSetting;
        case realm::BindingContext::ColumnInfo::Kind::Set:
            return NSKeyValueChangeReplacement;
        case realm::BindingContext::ColumnInfo::Kind::Insert:
            return NSKeyValueChangeInsertion;
        case realm::BindingContext::ColumnInfo::Kind::Remove:
            return NSKeyValueChangeRemoval;
    }
}

static NSIndexSet *convert(realm::IndexSet const& in, NSMutableIndexSet *out) {
    if (in.empty()) {
        return nil;
    }

    [out removeAllIndexes];
    for (auto range : in) {
        [out addIndexesInRange:{range.first, range.second - range.first}];
    }
    return out;
}

void RLMWillChange(std::vector<realm::BindingContext::ObserverState> const& observed,
                   std::vector<void *> const& invalidated) {
    for (auto info : invalidated) {
        static_cast<RLMObservationInfo *>(info)->willChange(RLMInvalidatedKey);
    }
    if (!observed.empty()) {
        NSMutableIndexSet *indexes = [NSMutableIndexSet new];
        for (auto const& o : observed) {
            forEach(o, [&](size_t, auto const& change, RLMObservationInfo *info) {
                info->willChange(info->columnName(change.initial_column_index),
                                 convert(change.kind), convert(change.indices, indexes));
            });
        }
    }
    for (auto info : invalidated) {
        static_cast<RLMObservationInfo *>(info)->prepareForInvalidation();
    }
}

void RLMDidChange(std::vector<realm::BindingContext::ObserverState> const& observed,
                  std::vector<void *> const& invalidated) {
    if (!observed.empty()) {
        // Loop in reverse order to avoid O(N^2) behavior in Foundation
        NSMutableIndexSet *indexes = [NSMutableIndexSet new];
        for (auto const& o : reverse(observed)) {
            forEach(o, [&](size_t i, auto const& change, RLMObservationInfo *info) {
                info->didChange(info->columnName(i), convert(change.kind), convert(change.indices, indexes));
            });
        }
    }
    for (auto const& info : reverse(invalidated)) {
        static_cast<RLMObservationInfo *>(info)->didChange(RLMInvalidatedKey);
    }
}
