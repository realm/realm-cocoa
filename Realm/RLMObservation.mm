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
#import "RLMObjectSchema_Private.hpp"
#import "RLMObject_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMSet_Private.hpp"
#import "RLMSwiftCollectionBase.h"
#import "RLMSwiftValueStorage.h"

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

RLMObservationInfo::RLMObservationInfo(RLMClassInfo &objectSchema, realm::ObjKey row, id object)
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

NSString *RLMObservationInfo::columnName(realm::ColKey col) const noexcept {
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

void RLMObservationInfo::setRow(realm::Table const& table, realm::ObjKey key) {
    REALM_ASSERT_DEBUG(!row);
    REALM_ASSERT_DEBUG(objectSchema);
    row = table.get_object(key);
    for (auto info : objectSchema->observedObjects) {
        if (info->row && info->row.get_key() == key) {
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

void RLMObservationInfo::recordObserver(realm::Obj& objectRow, RLMClassInfo *objectInfo,
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
        setRow(*objectRow.get_table(), objectRow.get_key());
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
    if (auto swiftAccessor = prop.swiftAccessor) {
        [swiftAccessor observe:prop on:object];
    }
    else if (prop.collection) {
        [valueForKey(key) setParent:object property:prop];
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
        return RLMCoerceToNil(superValueForKey(object, @selector(valueForKey:), key));
    }

    auto getSuper = [&] {
        return row ? RLMDynamicGet(object, lastProp) : RLMCoerceToNil(superValueForKey(object, @selector(valueForKey:), key));
    };

    // We need to return the same object each time for observing over keypaths
    // to work, so we store a cache of them here. We can't just cache them on
    // the object as that leads to retain cycles.
    if (lastProp.collection) {
        id value = cachedObjects[key];
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
        auto col = row.get_table()->get_column_key(lastProp.name.UTF8String);
        if (row.is_null(col)) {
            [cachedObjects removeObjectForKey:key];
            return nil;
        }

        RLMObjectBase *value = cachedObjects[key];
        if (value && value->_row.get_key() == row.get<realm::ObjKey>(col)) {
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

RLMObservationInfo *RLMGetObservationInfo(RLMObservationInfo *info, realm::ObjKey row,
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
    if (!objectSchema.table()) {
        // Orphaned embedded object types are included in the schema but do not
        // create a table at all, so we may not have a table here and just
        // don't need to do anything
        return;
    }

    for (auto info : objectSchema.observedObjects) {
        info->willChange(RLMInvalidatedKey);
    }

    {
        RLMObservationTracker tracker(objectSchema.realm, true);
        Results(objectSchema.realm->_realm, objectSchema.table()).clear();

        for (auto info : objectSchema.observedObjects) {
            info->prepareForInvalidation();
        }
    }

    for (auto info : reverse(objectSchema.observedObjects)) {
        info->didChange(RLMInvalidatedKey);
    }

    objectSchema.observedObjects.clear();
}

RLMObservationTracker::RLMObservationTracker(__unsafe_unretained RLMRealm *const realm, bool trackDeletions)
: _realm(realm)
, _group(realm.group)
{
    if (trackDeletions) {
        this->trackDeletions();
    }
}

RLMObservationTracker::~RLMObservationTracker() {
    didChange();
}

void RLMObservationTracker::willChange(RLMObservationInfo *info, NSString *key,
                                       NSKeyValueChange kind, NSIndexSet *indexes) {
    _key = key;
    _kind = kind;
    _indexes = indexes;
    _info = info;
    if (_info) {
        _info->willChange(key, kind, indexes);
    }
}

void RLMObservationTracker::trackDeletions() {
    if (_group.has_cascade_notification_handler()) {
        // We're nested inside another call which will handle any cascaded changes for us
        return;
    }

    for (auto& info : _realm->_info) {
        if (!info.second.observedObjects.empty()) {
            _observedTables.push_back(&info.second.observedObjects);
        }
    }

    // No need for change tracking if no objects are observed
    if (_observedTables.empty()) {
        return;
    }

    _group.set_cascade_notification_handler([=](realm::Group::CascadeNotification const& cs) {
        cascadeNotification(cs);
    });
}

template<typename CascadeNotification>
void RLMObservationTracker::cascadeNotification(CascadeNotification const& cs) {
    if (cs.rows.empty() && cs.links.empty()) {
        return;
    }

    size_t invalidatedCount = _invalidated.size();
    size_t changeCount = _changes.size();

    auto tableKey = [](RLMObservationInfo *info) {
        return info->getRow().get_table()->get_key();
    };
    std::sort(begin(_observedTables), end(_observedTables),
              [=](auto a, auto b) { return tableKey(a->front()) < tableKey(b->front()); });
    for (auto const& link : cs.links) {
        auto table = std::find_if(_observedTables.begin(), _observedTables.end(), [&](auto table) {
            return tableKey(table->front()) == link.origin_table;
        });
        if (table == _observedTables.end()) {
            continue;
        }

        for (auto observer : **table) {
            if (!observer->isForRow(link.origin_key)) {
                continue;
            }

            NSString *name = observer->columnName(link.origin_col_key);
            if (observer->getRow().get_table()->get_column_type(link.origin_col_key) != type_LinkList) {
                _changes.push_back({observer, name});
                continue;
            }

            auto c = find_if(begin(_changes), end(_changes), [&](auto const& c) {
                return c.info == observer && c.property == name;
            });
            if (c == end(_changes)) {
                _changes.push_back({observer, name, [NSMutableIndexSet new]});
                c = prev(end(_changes));
            }

            // We know what row index is being removed from the LinkView,
            // but what we actually want is the indexes in the LinkView that
            // are going away
            auto linkview = observer->getRow().get_linklist(link.origin_col_key);
            linkview.find_all(link.old_target_key, [&](size_t index) {
                [c->indexes addIndex:index];
            });
        }
    }
    if (!cs.rows.empty()) {
        using Row = realm::Group::CascadeNotification::row;
        auto begin = cs.rows.begin();
        for (auto table : _observedTables) {
            auto currentTableKey = tableKey(table->front());
            if (begin->table_key < currentTableKey) {
                // Find the first deleted object in or after this table
                begin = std::lower_bound(begin, cs.rows.end(), Row{currentTableKey, realm::ObjKey(0)});
            }
            if (begin == cs.rows.end()) {
                // No more deleted objects
                break;
            }
            if (currentTableKey < begin->table_key) {
                // Next deleted object is in a table after this one
                continue;
            }

            // Find the end of the deletions in this table
            auto end = std::lower_bound(begin, cs.rows.end(), Row{realm::TableKey(currentTableKey.value + 1), realm::ObjKey(0)});

            // Check each observed object to see if it's in the deleted rows
            for (auto info : *table) {
                if (std::binary_search(begin, end, Row{currentTableKey, info->getRow().get_key()})) {
                    _invalidated.push_back(info);
                }
            }

            // Advance the begin iterator to the start of the next table
            begin = end;
            if (begin == cs.rows.end()) {
                break;
            }
        }
    }

    // The relative order of these loops is very important
    for (size_t i = invalidatedCount; i < _invalidated.size(); ++i) {
        _invalidated[i]->willChange(RLMInvalidatedKey);
    }
    for (size_t i = changeCount; i < _changes.size(); ++i) {
        auto const& change = _changes[i];
        change.info->willChange(change.property, NSKeyValueChangeRemoval, change.indexes);
    }
    for (size_t i = invalidatedCount; i < _invalidated.size(); ++i) {
        _invalidated[i]->prepareForInvalidation();
    }
}

void RLMObservationTracker::didChange() {
    if (_info) {
        _info->didChange(_key, _kind, _indexes);
        _info = nullptr;
    }
    if (_observedTables.empty()) {
        return;
    }
    _group.set_cascade_notification_handler(nullptr);

    for (auto const& change : reverse(_changes)) {
        change.info->didChange(change.property, NSKeyValueChangeRemoval, change.indexes);
    }
    for (auto info : reverse(_invalidated)) {
        info->didChange(RLMInvalidatedKey);
    }
    _observedTables.clear();
    _changes.clear();
    _invalidated.clear();
}

namespace {
template<typename Func>
void forEach(realm::BindingContext::ObserverState const& state, Func&& func) {
    for (auto& change : state.changes) {
        func(realm::ColKey(change.first), change.second, static_cast<RLMObservationInfo *>(state.info));
    }
}
}

std::vector<realm::BindingContext::ObserverState> RLMGetObservedRows(RLMSchemaInfo const& schema) {
    std::vector<realm::BindingContext::ObserverState> observers;
    for (auto& table : schema) {
        for (auto info : table.second.observedObjects) {
            auto const& row = info->getRow();
            if (!row.is_valid())
                continue;
            observers.push_back({
                row.get_table()->get_key(),
                row.get_key().value,
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
            forEach(o, [&](realm::ColKey colKey, auto const& change, RLMObservationInfo *info) {
                info->willChange(info->columnName(colKey),
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
            forEach(o, [&](realm::ColKey col, auto const& change, RLMObservationInfo *info) {
                info->didChange(info->columnName(col), convert(change.kind), convert(change.indices, indexes));
            });
        }
    }
    for (auto const& info : reverse(invalidated)) {
        static_cast<RLMObservationInfo *>(info)->didChange(RLMInvalidatedKey);
    }
}

KeyPath KeyPathFromString(RLMRealm *realm,
                          RLMSchema *schema,
                          RLMObjectSchema *rlmObjectSchema,
                          RLMClassInfo *info,
                          NSString *keyPath) {
    RLMProperty *property;
    KeyPath keyPairs;

    NSUInteger start = 0, length = keyPath.length, end = NSNotFound;
    do {
        end = [keyPath rangeOfString:@"." options:0 range:{start, length - start}].location;
        NSString *propertyName = [keyPath substringWithRange:{start, end == NSNotFound ? length - start : end - start}];
        property = rlmObjectSchema[propertyName];
        RLMPrecondition(property, @"Invalid property name",
                        @"Property '%@' not found in object of type '%@'",
                        propertyName, rlmObjectSchema.className);

        if (end != NSNotFound) {
            RLMPrecondition(property.type == RLMPropertyTypeObject || property.type == RLMPropertyTypeLinkingObjects,
                            @"Invalid value", @"Property '%@' is not a link in object of type '%@'",
                            propertyName, rlmObjectSchema.className);
            REALM_ASSERT(property.objectClassName);

            TableKey tk = info->objectSchema->table_key;
            ColKey ck;
            if (property.type == RLMPropertyTypeObject) {
                ck = info->tableColumn(property.columnName);
                info = &realm->_info[property.objectClassName];
            } else if (property.type == RLMPropertyTypeLinkingObjects) {
                ck = info->computedTableColumn(property);
                info = &realm->_info[property.objectClassName];
            } else {
                // This branch should never be reached. This case should be
                // caught by the precondition above.
                RLMException(@"Property '%@' is not a link in object of type '%@'",
                             propertyName, rlmObjectSchema.className);
            }

            keyPairs.push_back(std::make_pair(tk, ck));
            rlmObjectSchema = schema[property.objectClassName];
        }

        start = end + 1;
    } while (end != NSNotFound);

    TableKey tk = info->objectSchema->table_key;
    ColKey ck;
    if (property.type == RLMPropertyTypeLinkingObjects) {
        ck = info->computedTableColumn(property);
    } else {
        ck = info->tableColumn(property.columnName);
    }
    keyPairs.push_back(std::make_pair(tk, ck));
    return keyPairs;
}

// Some parameters ultimately not used.
// TODO: clean up unused parameters
KeyPathArray KeyPathArrayFromStringArray(RLMRealm *realm,
                                         RLMSchema *schema,
                                         RLMObjectSchema *objectSchema,
                                         RLMClassInfo *info,
                                         NSArray<NSString *> *keyPaths) {
    KeyPathArray keyPathArray;
    for (NSString *keyPath in keyPaths) {
        keyPathArray.push_back(KeyPathFromString(realm ,schema, objectSchema, info, keyPath));
    }
    return keyPathArray;
}

