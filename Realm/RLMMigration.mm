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

#import "RLMMigration_Private.h"
#import "RLMRealm_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMSchema_Private.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObject_Private.h"
#import "RLMObjectStore.hpp"
#import "RLMArray.h"

// The source realm for a migration has to use a SharedGroup to be able to share
// the file with the destination realm, but we don't want to let the user call
// beginWriteTransaction on it as that would make no sense.
@interface RLMMigrationRealm : RLMRealm
@end

@implementation RLMMigrationRealm
- (BOOL)readonly {
    return YES;
}

- (void)beginWriteTransaction {
    @throw [NSException exceptionWithName:@"RLMException"
                                   reason:@"Cannot modify the source Realm in a migration"
                                 userInfo:nil];
}
@end

@implementation RLMMigration

+ (instancetype)migrationAtPath:(NSString *)path error:(NSError **)error {
    RLMMigration *migration = [RLMMigration new];
    
    // create rw realm to migrate with current on disk table
    migration->_realm = [RLMRealm realmWithPath:path readOnly:NO dynamic:YES schema:nil error:error];
    if (error && *error) {
        return nil;
    }
    
    // create read only realm used during migration with current on disk schema
    migration->_oldRealm = [[RLMMigrationRealm alloc] initWithPath:path readOnly:NO error:error];
    if (migration->_oldRealm) {
        RLMRealmInitializeReadOnlyWithSchema(migration->_oldRealm, [RLMSchema dynamicSchemaFromRealm:migration->_oldRealm]);
    }
    if (error && *error) {
        return nil;
    }
    
    return migration;
}

- (RLMSchema *)oldSchema {
    return self.oldRealm.schema;
}

- (RLMSchema *)newSchema {
    return [RLMSchema sharedSchema];
}

- (void)enumerateObjects:(NSString *)className block:(RLMObjectMigrationBlock)block {
    // get all objects
    RLMResults *objects = [_realm.schema schemaForClassName:className] ? [_realm allObjects:className] : nil;
    RLMResults *oldObjects = [_oldRealm.schema schemaForClassName:className] ? [_oldRealm allObjects:className] : nil;
    if (objects && oldObjects) {
        for (NSUInteger i = 0; i < oldObjects.count; i++) {
            block(oldObjects[i], objects[i]);
        }
    }
    else if (objects) {
        for (NSUInteger i = 0; i < objects.count; i++) {
            block(nil, objects[i]);
        }
    }
    else if (oldObjects) {
        for (NSUInteger i = 0; i < oldObjects.count; i++) {
            block(oldObjects[i], nil);
        }
    }
}

- (void)migrateWithBlock:(RLMMigrationBlock)block {
    // start write transaction
    [_realm beginWriteTransaction];

    @try {
        // add new tables/columns for the current shared schema
        bool changed = RLMRealmSetSchema(_realm, [RLMSchema sharedSchema], true);

        // disable all primary keys for migration
        for (RLMObjectSchema *objectSchema in _realm.schema.objectSchema) {
            objectSchema.primaryKeyProperty.isPrimary = NO;
            if (objectSchema->_table->has_primary_key()) {
                objectSchema->_table->remove_primary_key();
            }
        }

        // apply block and set new schema version
        NSUInteger oldVersion = RLMRealmSchemaVersion(_realm);
        NSUInteger newVersion = block(self, oldVersion);
        RLMRealmSetSchemaVersion(_realm, newVersion);

        // make sure a new version was provided if changes were made
        if (changed && oldVersion >= newVersion) {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Migration block should return a higher version after a schema update"
                                         userInfo:@{@"path" : _realm.path}];
        }

        // re-enable the primary keys
        for (RLMObjectSchema *objectSchema in _realm.schema.objectSchema) {
            if (RLMProperty *primary = objectSchema.primaryKeyProperty) {
                primary.isPrimary = YES;

                // should already have it, but may not if coming from an older
                // version of Realm
                if (!objectSchema->_table->has_search_index(primary.column)) {
                    objectSchema->_table->add_search_index(primary.column);
                }

                if (!objectSchema->_table->try_add_primary_key(primary.column)) {
                    NSString *reason = [NSString stringWithFormat:@"Primary key property '%@' has duplicate values after migration.",
                                        primary.name];
                    @throw [NSException exceptionWithName:@"RLMException" reason:reason userInfo:nil];
                }
            }
        }
    }
    @finally {
        // end transaction
        [_realm commitWriteTransaction];
    }
}

@end
