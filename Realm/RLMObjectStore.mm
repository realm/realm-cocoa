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

#import "RLMObjectStore.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMArray_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObject_Private.h"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMUtil.hpp"

#import <objc/runtime.h>

static void RLMVerifyAndAlignColumns(RLMObjectSchema *tableSchema, RLMObjectSchema *objectSchema) {
    // FIXME - this method should calculate all mismatched columns, and missing/extra columns, and include
    //         all of this information in a single exception
    // FIXME - verify property attributes

    // check count
    if (tableSchema.properties.count != objectSchema.properties.count) {
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Column count does not match interface - migration required"
                                     userInfo:nil];
    }

    NSMutableArray *properties = [NSMutableArray arrayWithCapacity:objectSchema.properties.count];

    // check to see if properties are the same
    for (RLMProperty *tableProp in tableSchema.properties) {
        RLMProperty *schemaProp = objectSchema[tableProp.name];
        if (![tableProp.name isEqualToString:schemaProp.name]) {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Existing property does not match interface - migration required"
                                         userInfo:@{@"property num": @(tableProp.column),
                                                    @"existing property name": tableProp.name,
                                                    @"new property name": schemaProp.name}];
        }
        if (tableProp.type != schemaProp.type) {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Property types do not match - migration required"
                                         userInfo:@{@"property name": tableProp.name,
                                                    @"existing property type": RLMTypeToString(tableProp.type),
                                                    @"new property type": RLMTypeToString(schemaProp.type)}];
        }
        if (tableProp.type == RLMPropertyTypeObject || tableProp.type == RLMPropertyTypeArray) {
            if (![tableProp.objectClassName isEqualToString:schemaProp.objectClassName]) {
                @throw [NSException exceptionWithName:@"RLMException"
                                               reason:@"Property objectClass does not match - migration required"
                                             userInfo:@{@"property name": tableProp.name,
                                                        @"existign objectClass": tableProp.objectClassName,
                                                        @"new property name": schemaProp.objectClassName}];
            }
        }
        if (tableProp.isPrimary != schemaProp.isPrimary) {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Property primary key designation does not match - migration required"
                                         userInfo:@{@"property name": tableProp.name}];
        }

        // align
        schemaProp.column = tableProp.column;
        [properties addObject:schemaProp];
    }

    // ensure the order of the properties matches the column order in the table
    objectSchema.properties = properties;
}

// create a column for a property in a table
// NOTE: must be called from within write transaction
static void RLMCreateColumn(RLMRealm *realm, tightdb::Table &table, RLMProperty *prop) {
    switch (prop.type) {
            // for objects and arrays, we have to specify target table
        case RLMPropertyTypeObject:
        case RLMPropertyTypeArray: {
            tightdb::TableRef linkTable = RLMTableForObjectClass(realm, prop.objectClassName);
            prop.column = table.add_column_link(tightdb::DataType(prop.type), prop.name.UTF8String, *linkTable);
            break;
        }
        default: {
            prop.column = table.add_column(tightdb::DataType(prop.type), prop.name.UTF8String);
            if (prop.attributes & RLMPropertyAttributeIndexed) {
                switch (prop.type) {
                    // Core currently supports Date as well, but won't be able
                    // to if we switch to storing dates as doubles
                    case RLMPropertyTypeBool:
                    case RLMPropertyTypeInt:
                    case RLMPropertyTypeString:
                        table.add_search_index(prop.column);
                        break;
                    default:
                        NSLog(@"RLMPropertyAttributeIndexed only supported for string, int and bool properties");
                }
            }
        }
    }
}

void RLMRealmInitializeReadOnlyWithSchema(RLMRealm *realm, RLMSchema *targetSchema) {
    if (RLMRealmSchemaVersion(realm) == RLMNotVersioned) {
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Cannot open an uninitialized realm in read-only mode"
                                     userInfo:nil];
    }

    realm.schema = [targetSchema copy];

    for (RLMObjectSchema *objectSchema in realm.schema.objectSchema) {
        // read-only realms may be missing tables entirely
        objectSchema->_table = RLMTableForObjectClass(realm, objectSchema.className);
        if (objectSchema->_table) {
            RLMObjectSchema *tableSchema = [RLMObjectSchema schemaFromTableForClassName:objectSchema.className realm:realm];
            RLMVerifyAndAlignColumns(tableSchema, objectSchema);
        }
        objectSchema.accessorClass = RLMAccessorClassForObjectClass(objectSchema.objectClass, objectSchema);
    }
}

void RLMRealmInitializeWithSchema(RLMRealm *realm, RLMSchema *targetSchema) {
    [realm beginWriteTransaction];

    @try {
        // check to see if this is the first time loading this realm
        bool firstInitialization = RLMRealmSchemaVersion(realm) == RLMNotVersioned;
        if (firstInitialization) {
            // set initial version
            RLMRealmSetSchemaVersion(realm, 0);
        }

        // set the schema, mutating if we are initializing the db for the first time
        RLMRealmSetSchema(realm, targetSchema, firstInitialization);
    }
    @finally {
        // FIXME: should rollback on exceptions rather than commit once that's implemented
        [realm commitWriteTransaction];
    }
}

bool RLMRealmSetSchema(RLMRealm *realm, RLMSchema *targetSchema, bool initializeSchema) {
    realm.schema = [targetSchema copy];

    bool changed = false;
    if (initializeSchema) {
        // first pass to create missing tables
        for (RLMObjectSchema *objectSchema in realm.schema.objectSchema) {
            bool created = false;
            objectSchema->_table = RLMTableForObjectClass(realm, objectSchema.className, created);
            changed |= created;
        }

        // second pass adds/removes columns appropriately
        for (RLMObjectSchema *objectSchema in realm.schema.objectSchema) {
            RLMObjectSchema *tableSchema = [RLMObjectSchema schemaFromTableForClassName:objectSchema.className realm:realm];

            // add missing columns
            for (RLMProperty *prop in objectSchema.properties) {
                // add any new properties (new name or different type)
                if (!tableSchema[prop.name] || ![prop isEqualToProperty:tableSchema[prop.name]]) {
                    RLMCreateColumn(realm, *objectSchema->_table, prop);
                    changed = true;
                }
            }

            // remove extra columns
            for (int i = (int)tableSchema.properties.count - 1; i >= 0; i--) {
                RLMProperty *prop = tableSchema.properties[i];
                if (!objectSchema[prop.name] || ![prop isEqualToProperty:objectSchema[prop.name]]) {
                    objectSchema->_table->remove_column(prop.column);
                    changed = true;
                }
            }

            // update table metadata
            if (objectSchema.primaryKeyProperty != nil) {
                // if there is a primary key set, check if it is the same as the old key
                if (tableSchema.primaryKeyProperty == nil || ![tableSchema.primaryKeyProperty isEqual:objectSchema.primaryKeyProperty]) {
                    RLMRealmSetPrimaryKeyForObjectClass(realm, objectSchema);
                    changed = true;
                }
            }
            else if (tableSchema.primaryKeyProperty) {
                // there is no primary key, so if thre was one nil out
                RLMRealmSetPrimaryKeyForObjectClass(realm, objectSchema);
                changed = true;
            }
        }

        // FIXME - remove deleted tables
    }

    for (RLMObjectSchema *objectSchema in realm.schema.objectSchema) {
        // cache table instances on objectSchema
        objectSchema->_table = RLMTableForObjectClass(realm, objectSchema.className);

        RLMObjectSchema *tableSchema = [RLMObjectSchema schemaFromTableForClassName:objectSchema.className realm:realm];
        RLMVerifyAndAlignColumns(tableSchema, objectSchema);

        // create accessors
        // FIXME - we need to generate different accessors keyed by the hash of the objectSchema (to preserve column ordering)
        //         it's possible to have multiple realms with different on-disk layouts, which requires
        //         us to have multiple accessors for each type/instance combination
        objectSchema.accessorClass = RLMAccessorClassForObjectClass(objectSchema.objectClass, objectSchema);
    }

    return changed;
}

static inline void RLMVerifyInWriteTransaction(RLMRealm *realm) {
    // if realm is not writable throw
    if (!realm.inWriteTransaction) {
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Can only add an object to a Realm in a write transaction - call beginWriteTransaction on an RLMRealm instance first."
                                     userInfo:nil];
    }
    RLMCheckThread(realm);
}

template<typename F>
static inline NSUInteger RLMCreateOrGetRowForObject(RLMObjectSchema *schema, F primaryValueGetter, RLMSetFlag options) {
    tightdb::Table &table = *schema->_table;
    RLMProperty *primaryProperty = schema.primaryKeyProperty;
    if (!primaryProperty) {
        return table.add_empty_row();
    }

    id primaryValue = primaryValueGetter(primaryProperty);

    // try to get existing row if updating
    size_t rowIndex = tightdb::not_found;
    if (options & RLMSetFlagUpdateOrCreate) {
        if (primaryProperty.type == RLMPropertyTypeString) {
            rowIndex = table.find_pkey_string(RLMStringDataWithNSString(primaryValue)).get_index();
        }
        else {
            rowIndex = table.find_pkey_int([primaryValue longLongValue]).get_index();
        }

        if (rowIndex != tightdb::not_found) {
            return rowIndex;
        }
    }

    // Can't use add_empty_row because a row may already exist with 0/"" in the
    // primary key column which will immediately fail uniqueness.
    // Instead make a row with everything but the primary key "empty", since we
    // can't set all columns for reals now (linklist has to happen after
    // insert_done() and mixed would involve a lot of duplicated code), and
    // setting only the ones we can gets really awkward.
    rowIndex = table.size();
    for (RLMProperty *prop in schema.properties) {
        NSUInteger col = prop.column;
        switch (prop.type) {
            case RLMPropertyTypeAny:
                table.insert_mixed(col, table.size(), tightdb::Mixed(false));
                break;
            case RLMPropertyTypeArray:
                table.insert_linklist(col, table.size());
                break;
            case RLMPropertyTypeBool:
                table.insert_bool(col, rowIndex, false);
                break;
            case RLMPropertyTypeData:
                table.insert_binary(col, rowIndex, tightdb::BinaryData(0, 0));
                break;
            case RLMPropertyTypeDate:
                table.insert_datetime(col, table.size(), 0);
                break;
            case RLMPropertyTypeDouble:
                table.insert_double(col, table.size(), 0.0);
                break;
            case RLMPropertyTypeFloat:
                table.insert_float(col, table.size(), 0.0f);
                break;
            case RLMPropertyTypeInt:
                if (prop == primaryProperty) {
                    table.insert_int(col, rowIndex, [primaryValue longLongValue]);
                }
                else {
                    table.insert_int(col, rowIndex, 0);
                }
                break;
            case RLMPropertyTypeObject:
                table.insert_link(col, table.size(), tightdb::npos);
                break;
            case RLMPropertyTypeString:
                if (prop == primaryProperty) {
                    table.insert_string(col, table.size(), RLMStringDataWithNSString(primaryValue));
                }
                else {
                    table.insert_string(col, table.size(), tightdb::StringData(0, 0));
                }
                break;
        }
    }

    table.insert_done();
    return rowIndex;
}

void RLMAddObjectToRealm(RLMObject *object, RLMRealm *realm, RLMSetFlag options) {
    RLMVerifyInWriteTransaction(realm);

    // verify that object is standalone
    if (object.deletedFromRealm) {
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Adding a deleted object to a Realm is not permitted"
                                     userInfo:nil];
    }
    if (object.realm) {
        if (object.realm == realm) {
            // no-op
            return;
        }
        // for differing realms users must explicitly create the object in the second realm
        @throw [NSException exceptionWithName:@"RLMException"
                                       reason:@"Object is already persisted in a Realm"
                                     userInfo:nil];
    }

    // set the realm and schema
    NSString *objectClassName = object.objectSchema.className;
    RLMObjectSchema *schema = realm.schema[objectClassName];
    object.objectSchema = schema;
    object.realm = realm;

    // get or create row
    auto primaryGetter = [=](RLMProperty *p) { return [object valueForKey:p.getterName]; };
    object->_row = (*schema->_table)[RLMCreateOrGetRowForObject(schema, primaryGetter, options)];

    // populate all properties
    for (RLMProperty *prop in schema.properties) {
        // get object from ivar using key value coding
        id value = nil;
        if ([object respondsToSelector:prop.getterSel]) {
            value = [object valueForKey:prop.getterName];
        }

        // FIXME: Add condition to check for Mixed once it can support a nil value.
        if (!value && prop.type != RLMPropertyTypeObject) {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:[NSString stringWithFormat:@"No value or default value specified for property '%@' in '%@'",
                                                   prop.name, schema.className]
                                         userInfo:nil];
        }

        // set in table with out validation
        // skip primary key when updating since it doesn't change
        if (!prop.isPrimary) {
            RLMDynamicSet(object, prop, value, options);
        }
    }

    // switch class to use table backed accessor
    object_setClass(object, schema.accessorClass);
}


RLMObject *RLMCreateObjectInRealmWithValue(RLMRealm *realm, NSString *className, id value, RLMSetFlag options) {
    // verify writable
    RLMVerifyInWriteTransaction(realm);

    // create the object
    RLMSchema *schema = realm.schema;
    RLMObjectSchema *objectSchema = schema[className];
    RLMObject *object = [[objectSchema.objectClass alloc] initWithRealm:realm schema:objectSchema defaultValues:NO];

    // validate values, create row, and populate
    if (NSArray *array = RLMDynamicCast<NSArray>(value)) {
        array = RLMValidatedArrayForObjectSchema(value, objectSchema, schema);

        // get or create our accessor
        auto primaryGetter = [=](RLMProperty *p) { return array[p.column]; };
        object->_row = (*objectSchema->_table)[RLMCreateOrGetRowForObject(objectSchema, primaryGetter, options)];

        // populate
        NSArray *props = objectSchema.properties;
        for (NSUInteger i = 0; i < array.count; i++) {
            RLMProperty *prop = props[i];
            // skip primary key when updating since it doesn't change
            if (!prop.isPrimary) {
                RLMDynamicSet(object, prop, array[i], options | RLMSetFlagUpdateOrCreate);
            }
        }
    }
    else {
        // assume dictionary or object with kvc properties
        NSDictionary *dict = RLMValidatedDictionaryForObjectSchema(value, objectSchema, schema);

        // get or create our accessor
        auto primaryGetter = [=](RLMProperty *p) { return dict[p.name]; };
        object->_row = (*objectSchema->_table)[RLMCreateOrGetRowForObject(objectSchema, primaryGetter, options)];

        // populate
        for (RLMProperty *prop in objectSchema.properties) {
            // skip primary key when updating since it doesn't change
            if (!prop.isPrimary) {
                RLMDynamicSet(object, prop, dict[prop.name], options | RLMSetFlagUpdateOrCreate);
            }
        }
    }

    // switch class to use table backed accessor
    object_setClass(object, objectSchema.accessorClass);

    return object;
}

void RLMDeleteObjectFromRealm(RLMObject *object) {
    RLMVerifyInWriteTransaction(object.realm);

    // move last row to row we are deleting
    object->_row.get_table()->move_last_over(object->_row.get_index());

    // set realm to nil
    object.realm = nil;
}

void RLMDeleteAllObjectsFromRealm(RLMRealm *realm) {
    RLMVerifyInWriteTransaction(realm);

    // clear table for each object schema
    for (RLMObjectSchema *objectSchema in realm.schema.objectSchema) {
        objectSchema->_table->clear();
    }
}

RLMResults *RLMGetObjects(RLMRealm *realm, NSString *objectClassName, NSPredicate *predicate) {
    RLMCheckThread(realm);

    // create view from table and predicate
    RLMObjectSchema *objectSchema = realm.schema[objectClassName];
    if (!objectSchema->_table) {
        // read-only realms may be missing tables since we can't add any
        // missing ones on init
        return [RLMEmptyResults emptyResultsWithObjectClassName:objectClassName realm:realm];
    }
    tightdb::Query query = objectSchema->_table->where();
    RLMUpdateQueryWithPredicate(&query, predicate, realm.schema, objectSchema);
    
    // create and populate array
    __autoreleasing RLMResults * results = [RLMResults resultsWithObjectClassName:objectClassName
                                                                            query:std::make_unique<Query>(query)
                                                                            realm:realm];
    return results;
}

id RLMGetObject(RLMRealm *realm, NSString *objectClassName, id key) {
    RLMCheckThread(realm);

    RLMObjectSchema *objectSchema = realm.schema[objectClassName];

    RLMProperty *primaryProperty = objectSchema.primaryKeyProperty;
    if (!primaryProperty) {
        NSString *msg = [NSString stringWithFormat:@"%@ does not have a primary key", objectClassName];
        @throw [NSException exceptionWithName:@"RLMException" reason:msg userInfo:nil];
    }

    if (!objectSchema->_table) {
        // read-only realms may be missing tables since we can't add any
        // missing ones on init
        return nil;
    }

    size_t row = tightdb::not_found;
    if (primaryProperty.type == RLMPropertyTypeString) {
        if (NSString *str = RLMDynamicCast<NSString>(key)) {
            row = objectSchema->_table->find_pkey_string(RLMStringDataWithNSString(str)).get_index();
        }
        else {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:[NSString stringWithFormat:@"Invalid value '%@' for primary key", key]
                                         userInfo:nil];
        }
    }
    else {
        if (NSNumber *number = RLMDynamicCast<NSNumber>(key)) {
            row = objectSchema->_table->find_pkey_int(number.longLongValue).get_index();
        }
        else {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:[NSString stringWithFormat:@"Invalid value '%@' for primary key", key]
                                         userInfo:nil];
        }
    }

    if (row == tightdb::not_found) {
        return nil;
    }

    return RLMCreateObjectAccessor(realm, objectClassName, row);
}

// Create accessor and register with realm
RLMObject *RLMCreateObjectAccessor(RLMRealm *realm, NSString *objectClassName, NSUInteger index) {
    RLMCheckThread(realm);

    RLMObjectSchema *objectSchema = realm.schema[objectClassName];
    
    // get accessor for the object class
    RLMObject *accessor = [[objectSchema.accessorClass alloc] initWithRealm:realm schema:objectSchema defaultValues:NO];
    tightdb::Table &table = *objectSchema->_table;
    accessor->_row = table[index];
    return accessor;
}

