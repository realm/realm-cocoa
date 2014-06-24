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

#import "RLMRealm_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMObject.h"
#import "RLMUtil.hpp"

#import <objc/runtime.h>

// RLMSchema private properties
@interface RLMSchema ()
@property (nonatomic, readwrite) NSArray *objectSchema;
@property (nonatomic, readwrite) NSMutableDictionary *objectSchemaByName;
@property (nonatomic, readwrite) NSMutableDictionary *objectClassByName;
@end

static RLMSchema *s_sharedSchema;
static NSMutableDictionary *s_mangledClassMap;

@implementation RLMSchema

- (RLMObjectSchema *)schemaForObject:(NSString *)className {
    return _objectSchemaByName[className];
}

- (RLMProperty *)objectForKeyedSubscript:(id <NSCopying>)className {
    return _objectSchemaByName[className];
}

- (Class)objectClassForClassName:(NSString *)className {
    return _objectClassByName[className];
}

- (id)init {
    self = [super init];
    if (self) {
        // setup name mapping for object tables
        _tableNamesForClass = [NSMutableDictionary dictionary];
        _objectClassByName = [NSMutableDictionary dictionary];
        _objectSchemaByName = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // load object schemas for all RLMObject subclasses
        unsigned int numClasses;
        Class *classes = objc_copyClassList(&numClasses);
        NSMutableArray *schemaArray = [NSMutableArray array];
        
        // cache descriptors for all subclasses of RLMObject
        RLMSchema *schema = [[RLMSchema alloc] init];
        for (unsigned int i = 0; i < numClasses; i++) {
            // if direct subclass
            if (class_getSuperclass(classes[i]) == RLMObject.class) {
#ifdef REALM_SWIFT
                // Convert Swift properties to Objective-C properties
                // to enable object schema generation and Realm custom accessors
                ParsedClass *parsedClass = [RLMSwiftSupport parseClass:classes[i]];
                if (parsedClass.swift) {
                    [RLMSwiftSupport convertSwiftPropertiesToObjC:classes[i]];
                    RLMSchema.mangledClassMap[parsedClass.name] = parsedClass.mangledName;
                }
#endif
                // add to class list
                RLMObjectSchema *object = [RLMObjectSchema schemaForObjectClass:classes[i]];
                [schemaArray addObject:object];
                
                // set table name and mappings
                NSString *tableName = RLMTableNameForClassName(object.className);
                schema.tableNamesForClass[object.className] = tableName;
                schema.objectClassByName[object.className] = classes[i];
                [(NSMutableDictionary *)schema.objectSchemaByName setObject:object forKey:object.className];
            }
        }
        free(classes);
        
        // set class array
        schema.objectSchema = schemaArray;
        
        s_sharedSchema = schema;
    });
}

// schema based on runtime objects
+(instancetype)sharedSchema {
    return s_sharedSchema;
}

// schema based on tables in a realm
+(instancetype)dynamicSchemaFromRealm:(RLMRealm *)realm {
    // generate object schema and class mapping for all tables in the realm
    unsigned long numTables = realm.group->size();
    NSMutableArray *schemaArray = [NSMutableArray arrayWithCapacity:numTables];
    
    // cache descriptors for all subclasses of RLMObject
    RLMSchema *schema = [[RLMSchema alloc] init];
    for (unsigned long i = 0; i < numTables; i++) {
        NSString *tableName = [NSString stringWithUTF8String:realm.group->get_table_name(i).data()];
        NSString *className = RLMClassForTableName(tableName);
        if (className) {
            tightdb::TableRef table = realm.group->get_table(i);
            RLMObjectSchema *object = [RLMObjectSchema schemaForTable:table.get() className:className];
            [schemaArray addObject:object];

            // add object and set mappings
            schema.tableNamesForClass[object.className] = tableName;
            [(NSMutableDictionary *)schema.objectSchemaByName setObject:object forKey:object.className];

            // generate dynamic class and set class mapping
            Class dynamicClass = RLMDynamicClassForSchema(object, realm.schemaVersion);
            schema.objectClassByName[object.className] = dynamicClass;
        }
    }
    
    // set class array and mapping
    schema.objectSchema = schemaArray;
    return schema;
}

+ (NSMutableDictionary *)mangledClassMap {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_mangledClassMap = [NSMutableDictionary dictionary];
    });
    return s_mangledClassMap;
}

@end
