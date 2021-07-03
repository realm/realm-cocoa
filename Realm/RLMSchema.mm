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

#import "RLMSchema_Private.h"

#import "RLMAccessor.h"
#import "RLMObjectBase_Private.h"
#import "RLMObject_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMRealm_Private.hpp"
#import "RLMSwiftSupport.h"
#import "RLMUtil.hpp"

#import <realm/group.hpp>
#import <realm/object-store/object_schema.hpp>
#import <realm/object-store/object_store.hpp>
#import <realm/object-store/schema.hpp>

#import <mutex>
#import <objc/runtime.h>

using namespace realm;

const uint64_t RLMNotVersioned = realm::ObjectStore::NotVersioned;

// RLMSchema private properties
@interface RLMSchema ()
@property (nonatomic, readwrite) NSMutableDictionary *objectSchemaByName;
@end

// Private RLMSchema subclass that skips class registration on lookup
@interface RLMPrivateSchema : RLMSchema
@end
@implementation RLMPrivateSchema
- (RLMObjectSchema *)schemaForClassName:(NSString *)className {
    return self.objectSchemaByName[className];
}

- (RLMObjectSchema *)objectForKeyedSubscript:(__unsafe_unretained NSString *const)className {
    return [self schemaForClassName:className];
}
@end

static RLMSchema *s_sharedSchema = [[RLMSchema alloc] init];
static NSMutableDictionary *s_localNameToClass = [[NSMutableDictionary alloc] init];
static RLMSchema *s_privateSharedSchema = [[RLMPrivateSchema alloc] init];

static enum class SharedSchemaState {
    Uninitialized,
    Initializing,
    Initialized
} s_sharedSchemaState = SharedSchemaState::Uninitialized;

@implementation RLMSchema {
    NSArray *_objectSchema;
    realm::Schema _objectStoreSchema;
}

// Caller must @synchronize on s_localNameToClass
static RLMObjectSchema *RLMRegisterClass(Class cls) {
    if (RLMObjectSchema *schema = s_privateSharedSchema[[cls className]]) {
        return schema;
    }

    auto prevState = s_sharedSchemaState;
    s_sharedSchemaState = SharedSchemaState::Initializing;
    RLMObjectSchema *schema = [RLMObjectSchema schemaForObjectClass:cls];
    s_sharedSchemaState = prevState;

    // set unmanaged class on shared schema for unmanaged object creation
    schema.unmanagedClass = RLMUnmanagedAccessorClassForObjectClass(schema.objectClass, schema);

    // override sharedSchema class methods for performance
    RLMReplaceSharedSchemaMethod(cls, schema);

    s_privateSharedSchema.objectSchemaByName[schema.className] = schema;
    if ([cls shouldIncludeInDefaultSchema] && prevState != SharedSchemaState::Initialized) {
        s_sharedSchema.objectSchemaByName[schema.className] = schema;
    }

    return schema;
}

// Caller must @synchronize on s_localNameToClass
static void RLMRegisterClassLocalNames(Class *classes, NSUInteger count) {
    for (NSUInteger i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!RLMIsObjectSubclass(cls)) {
            continue;
        }
        if ([cls _realmIgnoreClass]) {
            continue;
        }

        NSString *className = NSStringFromClass(cls);
        if ([className hasPrefix:@"RLM:"] || [className hasPrefix:@"NSKVONotifying"]) {
            continue;
        }

        if ([RLMSwiftSupport isSwiftClassName:className]) {
            className = [RLMSwiftSupport demangleClassName:className];
        }
        // NSStringFromClass demangles the names for top-level Swift classes
        // but not for nested classes. _T indicates it's a Swift symbol, t
        // indicates it's a type, and C indicates it's a class.
        else if ([className hasPrefix:@"_TtC"]) {
            @throw RLMException(@"Object subclass '%@' must explicitly set the class's objective-c name with @objc(ClassName) because it is not a top-level public class.", className);
        }

        if (Class existingClass = s_localNameToClass[className]) {
            if (existingClass != cls) {
                @throw RLMException(@"RLMObject subclasses with the same name cannot be included twice in the same target. "
                                    @"Please make sure '%@' is only linked once to your current target.", className);
            }
            continue;
        }

        s_localNameToClass[className] = cls;
        RLMReplaceClassNameMethod(cls, className);
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _objectSchemaByName = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSArray *)objectSchema {
    if (!_objectSchema) {
        _objectSchema = [_objectSchemaByName allValues];
    }
    return _objectSchema;
}

- (void)setObjectSchema:(NSArray *)objectSchema {
    _objectSchema = objectSchema;
    _objectSchemaByName = [NSMutableDictionary dictionaryWithCapacity:objectSchema.count];
    for (RLMObjectSchema *object in objectSchema) {
        [_objectSchemaByName setObject:object forKey:object.className];
    }
}

- (RLMObjectSchema *)schemaForClassName:(NSString *)className {
    if (RLMObjectSchema *schema = _objectSchemaByName[className]) {
        return schema; // fast path for already-initialized schemas
    } else if (Class cls = [RLMSchema classForString:className]) {
        [cls sharedSchema];                    // initialize the schema
        return _objectSchemaByName[className]; // try again
    } else {
        return nil;
    }
}

- (RLMObjectSchema *)objectForKeyedSubscript:(__unsafe_unretained NSString *const)className {
    RLMObjectSchema *schema = [self schemaForClassName:className];
    if (!schema) {
        @throw RLMException(@"Object type '%@' not managed by the Realm", className);
    }
    return schema;
}

+ (instancetype)schemaWithObjectClasses:(NSArray *)classes {
    NSUInteger count = classes.count;
    auto classArray = std::make_unique<__unsafe_unretained Class[]>(count);
    [classes getObjects:classArray.get() range:NSMakeRange(0, count)];

    RLMSchema *schema = [[self alloc] init];
    @synchronized(s_localNameToClass) {
        RLMRegisterClassLocalNames(classArray.get(), count);

        schema->_objectSchemaByName = [NSMutableDictionary dictionaryWithCapacity:count];
        for (Class cls in classes) {
            if (!RLMIsObjectSubclass(cls)) {
                @throw RLMException(@"Can't add non-Object type '%@' to a schema.", cls);
            }
            schema->_objectSchemaByName[[cls className]] = RLMRegisterClass(cls);
        }
    }

    NSMutableArray *errors = [NSMutableArray new];
    // Verify that all of the targets of links are included in the class list
    [schema->_objectSchemaByName enumerateKeysAndObjectsUsingBlock:^(id, RLMObjectSchema *objectSchema, BOOL *) {
        for (RLMProperty *prop in objectSchema.properties) {
            if (prop.type != RLMPropertyTypeObject) {
                continue;
            }
            if (!schema->_objectSchemaByName[prop.objectClassName]) {
                [errors addObject:[NSString stringWithFormat:@"- '%@.%@' links to class '%@', which is missing from the list of classes managed by the Realm", objectSchema.className, prop.name, prop.objectClassName]];
            }
        }
    }];
    if (errors.count) {
        @throw RLMException(@"Invalid class subset list:\n%@", [errors componentsJoinedByString:@"\n"]);
    }

    return schema;
}

+ (RLMObjectSchema *)sharedSchemaForClass:(Class)cls {
    @synchronized(s_localNameToClass) {
        // We create instances of Swift objects during schema init, and they
        // obviously need to not also try to initialize the schema
        if (s_sharedSchemaState == SharedSchemaState::Initializing) {
            return nil;
        }

        RLMRegisterClassLocalNames(&cls, 1);
        RLMObjectSchema *objectSchema = RLMRegisterClass(cls);
        [cls initializeLinkedObjectSchemas];
        return objectSchema;
    }
}

+ (instancetype)partialSharedSchema {
    return s_sharedSchema;
}

+ (instancetype)partialPrivateSharedSchema {
    return s_privateSharedSchema;
}

// schema based on runtime objects
+ (instancetype)sharedSchema {
    @synchronized(s_localNameToClass) {
        // We replace this method with one which just returns s_sharedSchema
        // once initialization is complete, but we still need to check if it's
        // already complete because it may have been done by another thread
        // while we were waiting for the lock
        if (s_sharedSchemaState == SharedSchemaState::Initialized) {
            return s_sharedSchema;
        }

        if (s_sharedSchemaState == SharedSchemaState::Initializing) {
            @throw RLMException(@"Illegal recursive call of +[%@ %@]. Note: Properties of Swift `Object` classes must not be prepopulated with queried results from a Realm.", self, NSStringFromSelector(_cmd));
        }

        s_sharedSchemaState = SharedSchemaState::Initializing;
        try {
            // Make sure we've discovered all classes
            {
                unsigned int numClasses;
                using malloc_ptr = std::unique_ptr<__unsafe_unretained Class[], decltype(&free)>;
                malloc_ptr classes(objc_copyClassList(&numClasses), &free);
                RLMRegisterClassLocalNames(classes.get(), numClasses);
            }

            [s_localNameToClass enumerateKeysAndObjectsUsingBlock:^(NSString *, Class cls, BOOL *) {
                RLMRegisterClass(cls);
            }];
        }
        catch (...) {
            s_sharedSchemaState = SharedSchemaState::Uninitialized;
            throw;
        }

        // Replace this method with one that doesn't need to acquire a lock
        Class metaClass = objc_getMetaClass(class_getName(self));
        IMP imp = imp_implementationWithBlock(^{ return s_sharedSchema; });
        class_replaceMethod(metaClass, @selector(sharedSchema), imp, "@@:");

        s_sharedSchemaState = SharedSchemaState::Initialized;
    }

    return s_sharedSchema;
}

// schema based on tables in a realm
+ (instancetype)dynamicSchemaFromObjectStoreSchema:(Schema const&)objectStoreSchema {
    // cache descriptors for all subclasses of RLMObject
    NSMutableArray *schemaArray = [NSMutableArray arrayWithCapacity:objectStoreSchema.size()];
    for (auto &objectSchema : objectStoreSchema) {
        RLMObjectSchema *schema = [RLMObjectSchema objectSchemaForObjectStoreSchema:objectSchema];
        [schemaArray addObject:schema];
    }

    // set class array and mapping
    RLMSchema *schema = [RLMSchema new];
    schema.objectSchema = schemaArray;
    return schema;
}

+ (Class)classForString:(NSString *)className {
    if (Class cls = s_localNameToClass[className]) {
        return cls;
    }

    if (Class cls = NSClassFromString(className)) {
        return RLMIsObjectSubclass(cls) ? cls : nil;
    }

    // className might be the local name of a Swift class we haven't registered
    // yet, so scan them all then recheck
    {
        unsigned int numClasses;
        std::unique_ptr<__unsafe_unretained Class[], decltype(&free)> classes(objc_copyClassList(&numClasses), &free);
        RLMRegisterClassLocalNames(classes.get(), numClasses);
    }

    return s_localNameToClass[className];
}

- (id)copyWithZone:(NSZone *)zone {
    RLMSchema *schema = [[RLMSchema allocWithZone:zone] init];
    schema->_objectSchemaByName = [[NSMutableDictionary allocWithZone:zone]
                                   initWithDictionary:_objectSchemaByName copyItems:YES];
    return schema;
}

- (BOOL)isEqualToSchema:(RLMSchema *)schema {
    if (_objectSchemaByName.count != schema->_objectSchemaByName.count) {
        return NO;
    }
    __block BOOL matches = YES;
    [_objectSchemaByName enumerateKeysAndObjectsUsingBlock:^(NSString *name, RLMObjectSchema *objectSchema, BOOL *stop) {
        if (![schema->_objectSchemaByName[name] isEqualToObjectSchema:objectSchema]) {
            *stop = YES;
            matches = NO;
        }
    }];
    return matches;
}

- (NSString *)description {
    NSMutableString *objectSchemaString = [NSMutableString string];
    NSArray *sort = @[[NSSortDescriptor sortDescriptorWithKey:@"className" ascending:YES]];
    for (RLMObjectSchema *objectSchema in [self.objectSchema sortedArrayUsingDescriptors:sort]) {
        [objectSchemaString appendFormat:@"\t%@\n",
         [objectSchema.description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    return [NSString stringWithFormat:@"Schema {\n%@}", objectSchemaString];
}

- (Schema)objectStoreCopy {
    if (_objectStoreSchema.size() == 0) {
        std::vector<realm::ObjectSchema> schema;
        schema.reserve(_objectSchemaByName.count);
        [_objectSchemaByName enumerateKeysAndObjectsUsingBlock:[&](NSString *, RLMObjectSchema *objectSchema, BOOL *) {
            schema.push_back([objectSchema objectStoreCopy:self]);
        }];

        // Having both obj-c and Swift classes for the same tables results in
        // duplicate ObjectSchemas that we need to filter out
        std::sort(begin(schema), end(schema), [](auto&& a, auto&& b) { return a.name < b.name; });
        schema.erase(std::unique(begin(schema), end(schema), [](auto&& a, auto&& b) {
            if (a.name == b.name) {
                // If we make _realmObjectName public this needs to be turned into an exception
                REALM_ASSERT_DEBUG(a.persisted_properties == b.persisted_properties);
                return true;
            }
            return false;
        }), end(schema));

        _objectStoreSchema = std::move(schema);
    }
    return _objectStoreSchema;
}

@end
