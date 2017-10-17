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

#import "RLMObjectSchema_Private.hpp"

#import "RLMArray.h"
#import "RLMListBase.h"
#import "RLMObject_Private.h"
#import "RLMProperty_Private.hpp"
#import "RLMRealm_Dynamic.h"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMSwiftSupport.h"
#import "RLMUtil.hpp"

#import "object_store.hpp"

using namespace realm;

// private properties
@interface RLMObjectSchema ()
@property (nonatomic, readwrite) NSDictionary<id, RLMProperty *> *allPropertiesByName;
@property (nonatomic, readwrite) NSString *className;
@end

@implementation RLMObjectSchema {
    NSArray *_swiftGenericProperties;
}

- (instancetype)initWithClassName:(NSString *)objectClassName objectClass:(Class)objectClass properties:(NSArray *)properties {
    self = [super init];
    self.className = objectClassName;
    self.properties = properties;
    self.objectClass = objectClass;
    self.accessorClass = objectClass;
    self.unmanagedClass = objectClass;
    return self;
}

// return properties by name
- (RLMProperty *)objectForKeyedSubscript:(__unsafe_unretained NSString *const)key {
    return _allPropertiesByName[key];
}

// create property map when setting property array
- (void)setProperties:(NSArray *)properties {
    _properties = properties;
    [self _propertiesDidChange];
}

- (void)setComputedProperties:(NSArray *)computedProperties {
    _computedProperties = computedProperties;
    [self _propertiesDidChange];
}

- (void)_propertiesDidChange {
    NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:_properties.count + _computedProperties.count];
    NSUInteger index = 0;
    for (RLMProperty *prop in _properties) {
        prop.index = index++;
        map[prop.name] = prop;
        if (prop.isPrimary) {
            self.primaryKeyProperty = prop;
        }
    }
    for (RLMProperty *prop in _computedProperties) {
        map[prop.name] = prop;
    }
    _allPropertiesByName = map;
}


- (void)setPrimaryKeyProperty:(RLMProperty *)primaryKeyProperty {
    _primaryKeyProperty.isPrimary = NO;
    primaryKeyProperty.isPrimary = YES;
    _primaryKeyProperty = primaryKeyProperty;
}

+ (instancetype)schemaForObjectClass:(Class)objectClass {
    RLMObjectSchema *schema = [RLMObjectSchema new];

    // determine classname from objectclass as className method has not yet been updated
    NSString *className = NSStringFromClass(objectClass);
    bool hasSwiftName = [RLMSwiftSupport isSwiftClassName:className];
    if (hasSwiftName) {
        className = [RLMSwiftSupport demangleClassName:className];
    }

    static Class s_swiftObjectClass = NSClassFromString(@"RealmSwiftObject");
    bool isSwift = hasSwiftName || [objectClass isSubclassOfClass:s_swiftObjectClass];

    schema.className = className;
    schema.objectClass = objectClass;
    schema.accessorClass = objectClass;
    schema.isSwiftClass = isSwift;

    // create array of RLMProperties, inserting properties of superclasses first
    Class cls = objectClass;
    Class superClass = class_getSuperclass(cls);
    NSArray *allProperties = @[];
    while (superClass && superClass != RLMObjectBase.class) {
        allProperties = [[RLMObjectSchema propertiesForClass:cls isSwift:isSwift]
                         arrayByAddingObjectsFromArray:allProperties];
        cls = superClass;
        superClass = class_getSuperclass(superClass);
    }
    NSArray *persistedProperties = [allProperties filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RLMProperty *property, NSDictionary *) {
        return !RLMPropertyTypeIsComputed(property.type);
    }]];
    schema.properties = persistedProperties;

    NSArray *computedProperties = [allProperties filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RLMProperty *property, NSDictionary *) {
        return RLMPropertyTypeIsComputed(property.type);
    }]];
    schema.computedProperties = computedProperties;

    // verify that we didn't add any properties twice due to inheritance
    if (allProperties.count != [NSSet setWithArray:[allProperties valueForKey:@"name"]].count) {
        NSCountedSet *countedPropertyNames = [NSCountedSet setWithArray:[allProperties valueForKey:@"name"]];
        NSArray *duplicatePropertyNames = [countedPropertyNames filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *) {
            return [countedPropertyNames countForObject:object] > 1;
        }]].allObjects;

        if (duplicatePropertyNames.count == 1) {
            @throw RLMException(@"Property '%@' is declared multiple times in the class hierarchy of '%@'", duplicatePropertyNames.firstObject, className);
        } else {
            @throw RLMException(@"Object '%@' has properties that are declared multiple times in its class hierarchy: '%@'", className, [duplicatePropertyNames componentsJoinedByString:@"', '"]);
        }
    }

    if (NSString *primaryKey = [objectClass primaryKey]) {
        for (RLMProperty *prop in schema.properties) {
            if ([primaryKey isEqualToString:prop.name]) {
                prop.indexed = YES;
                schema.primaryKeyProperty = prop;
                break;
            }
        }

        if (!schema.primaryKeyProperty) {
            @throw RLMException(@"Primary key property '%@' does not exist on object '%@'", primaryKey, className);
        }
        if ((schema.primaryKeyProperty.type != RLMPropertyTypeInt
             && schema.primaryKeyProperty.type != RLMPropertyTypeString)
            || schema.primaryKeyProperty.subtype == RLMPropertySubtypeInteger) {
            @throw RLMException(@"Property '%@' cannot be made the primary key of '%@' because it is not a 'string' or 'int' property.",
                                primaryKey, className);
        }
    }

    for (RLMProperty *prop in schema.properties) {
        if (prop.optional && prop.array && (prop.type == RLMPropertyTypeObject || prop.type == RLMPropertyTypeLinkingObjects)) {
            // FIXME: message is awkward
            @throw RLMException(@"Property '%@.%@' cannot be made optional because optional '%@' properties are not supported.",
                                className, prop.name, RLMTypeToString(prop.type));
        }
    }

    return schema;
}

+ (NSArray *)propertiesForClass:(Class)objectClass isSwift:(bool)isSwiftClass {
    Class objectUtil = [objectClass objectUtilClass:isSwiftClass];
    NSArray *ignoredProperties = [objectUtil ignoredPropertiesForClass:objectClass];
    NSDictionary *linkingObjectsProperties = [objectUtil linkingObjectsPropertiesForClass:objectClass];

    // For Swift classes we need an instance of the object when parsing properties
    id swiftObjectInstance = isSwiftClass ? [[objectClass alloc] init] : nil;

    unsigned int count;
    std::unique_ptr<objc_property_t[], decltype(&free)> props(class_copyPropertyList(objectClass, &count), &free);
    NSMutableArray *propArray = [NSMutableArray arrayWithCapacity:count];
    NSSet *indexed = [[NSSet alloc] initWithArray:[objectUtil indexedPropertiesForClass:objectClass]];
    for (unsigned int i = 0; i < count; i++) {
        NSString *propertyName = @(property_getName(props[i]));
        if ([ignoredProperties containsObject:propertyName]) {
            continue;
        }

        RLMProperty *prop = nil;
        if (isSwiftClass) {
            prop = [[RLMProperty alloc] initSwiftPropertyWithName:propertyName
                                                      objectClass:objectClass
                                                          indexed:[indexed containsObject:propertyName]
                                           linkPropertyDescriptor:linkingObjectsProperties[propertyName]
                                                         property:props[i]
                                                         instance:swiftObjectInstance];
        }
        else {
            prop = [[RLMProperty alloc] initWithName:propertyName
                                         objectClass:objectClass
                                             indexed:[indexed containsObject:propertyName]
                              linkPropertyDescriptor:linkingObjectsProperties[propertyName]
                                            property:props[i]];
        }

        if (prop) {
            [propArray addObject:prop];
        }
    }

    auto existingPropertyIndex = [=](NSString *name) -> NSUInteger {
        return [propArray indexOfObjectPassingTest:^BOOL(RLMProperty *obj, NSUInteger, BOOL *) {
            return [obj.name isEqualToString:name];
        }];
    };
    auto addProperty = [=](RLMProperty *prop, NSInteger index) {
        NSUInteger existing = existingPropertyIndex(prop.name);
        if (existing != NSNotFound) {
            propArray[existing] = prop;
        }
        else {
            [propArray insertObject:prop atIndex:index];
        }
    };

    if (isSwiftClass) {
        // List<> and LinkingObjects<> properties don't show up as Objective-C
        // properties due to being generic, so use Swift reflection to get a list
        // of them, and then access their ivars directly.
        NSArray<RLMGenericPropertyMetadata *> *props = [objectUtil getSwiftGenericProperties:swiftObjectInstance];
        if (props) {
            // Types like String? are reported as properties to the obj-c runtime,
            // but with no indication as to whether or not they're optional. We deal
            // with this by marking them as required, and then using Swift
            // reflection to re-check it.
            for (RLMProperty *property in propArray) {
                if (!property.array) {
                    property.optional = false;
                }
            }
        }
        for (RLMGenericPropertyMetadata *md in props) {
            switch (md.kind) {
                case RLMGenericPropertyKindList:
                    addProperty([[RLMProperty alloc] initSwiftListPropertyWithName:md.propertyName
                                                                          instance:swiftObjectInstance],
                                md.index);
                    break;
                case RLMGenericPropertyKindLinkingObjects: {
                    Ivar ivar = class_getInstanceVariable(objectClass, md.propertyName.UTF8String);
                    addProperty([[RLMProperty alloc] initSwiftLinkingObjectsPropertyWithName:md.propertyName
                                                                                        ivar:ivar
                                                                             objectClassName:md.className
                                                                      linkOriginPropertyName:md.linkedPropertyName],
                                md.index);
                    break;
                }
                case RLMGenericPropertyKindOptional: {
                    NSUInteger existing = existingPropertyIndex(md.propertyName);
                    if (existing != NSNotFound) {
                        // This optional property corresponds to a property we found
                        // earlier, while enumerating the Objective-C visible properties.
                        RLMProperty *property = propArray[existing];
                        property.optional = true;
                        property.type = RLMPropertyType(md.propertyType);
                    } else {
                        // This property wasn't detected earlier.
                        Ivar ivar = class_getInstanceVariable(objectClass, md.propertyName.UTF8String);
                        RLMPropertyType type = RLMPropertyType(md.propertyType);
                        BOOL isIndexed = [indexed containsObject:md.propertyName];
                        addProperty([[RLMProperty alloc] initSwiftOptionalPropertyWithName:md.propertyName
                                                                                   indexed:isIndexed
                                                                                      ivar:ivar
                                                                              propertyType:type],
                                    md.index);
                    }
                    break;
                }
                case RLMGenericPropertyKindNilLiteralOptional: {
                    NSUInteger existing = existingPropertyIndex(md.propertyName);
                    if (existing != NSNotFound) {
                        RLMProperty *property = propArray[existing];
                        property.optional = true;
                    }
                    break;
                }
            }
        }
    }

    if (auto requiredProperties = [objectUtil requiredPropertiesForClass:objectClass]) {
        for (RLMProperty *property in propArray) {
            bool required = [requiredProperties containsObject:property.name];
            if (required && property.type == RLMPropertyTypeObject && !property.array) {
                @throw RLMException(@"Object properties cannot be made required, "
                                    "but '+[%@ requiredProperties]' included '%@'", objectClass, property.name);
            }
            property.optional &= !required;
        }
    }

    for (RLMProperty *property in propArray) {
        if (!property.optional && property.type == RLMPropertyTypeObject && !property.array) {
            @throw RLMException(@"The `%@.%@` property must be marked as being optional.",
                                [objectClass className], property.name);
        }
    }

    return propArray;
}

- (id)copyWithZone:(NSZone *)zone {
    RLMObjectSchema *schema = [[RLMObjectSchema allocWithZone:zone] init];
    schema->_objectClass = _objectClass;
    schema->_className = _className;
    schema->_objectClass = _objectClass;
    schema->_accessorClass = _objectClass;
    schema->_unmanagedClass = _unmanagedClass;
    schema->_isSwiftClass = _isSwiftClass;

    // call property setter to reset map and primary key
    schema.properties = [[NSArray allocWithZone:zone] initWithArray:_properties copyItems:YES];
    schema.computedProperties = [[NSArray allocWithZone:zone] initWithArray:_computedProperties copyItems:YES];

    return schema;
}

- (BOOL)isEqualToObjectSchema:(RLMObjectSchema *)objectSchema {
    if (objectSchema.properties.count != _properties.count) {
        return NO;
    }

    if (![_properties isEqualToArray:objectSchema.properties]) {
        return NO;
    }
    if (![_computedProperties isEqualToArray:objectSchema.computedProperties]) {
        return NO;
    }

    return YES;
}

- (NSString *)description {
    NSMutableString *propertiesString = [NSMutableString string];
    for (RLMProperty *property in self.properties) {
        [propertiesString appendFormat:@"\t%@\n", [property.description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    for (RLMProperty *property in self.computedProperties) {
        [propertiesString appendFormat:@"\t%@\n", [property.description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];
    }
    return [NSString stringWithFormat:@"%@ {\n%@}", self.className, propertiesString];
}

- (NSString *)objectName {
    return [self.objectClass _realmObjectName] ?: _className;
}

- (realm::ObjectSchema)objectStoreCopy {
    ObjectSchema objectSchema;
    objectSchema.name = self.objectName.UTF8String;
    objectSchema.primary_key = _primaryKeyProperty ? _primaryKeyProperty.name.UTF8String : "";
    for (RLMProperty *prop in _properties) {
        Property p = [prop objectStoreCopy];
        p.is_primary = (prop == _primaryKeyProperty);
        objectSchema.persisted_properties.push_back(std::move(p));
    }
    for (RLMProperty *prop in _computedProperties) {
        objectSchema.computed_properties.push_back([prop objectStoreCopy]);
    }
    return objectSchema;
}

+ (instancetype)objectSchemaForObjectStoreSchema:(realm::ObjectSchema const&)objectSchema {
    RLMObjectSchema *schema = [RLMObjectSchema new];
    schema.className = @(objectSchema.name.c_str());

    // create array of RLMProperties
    NSMutableArray *properties = [NSMutableArray arrayWithCapacity:objectSchema.persisted_properties.size()];
    for (const Property &prop : objectSchema.persisted_properties) {
        RLMProperty *property = [RLMProperty propertyForObjectStoreProperty:prop];
        property.isPrimary = (prop.name == objectSchema.primary_key);
        [properties addObject:property];
    }
    schema.properties = properties;

    NSMutableArray *computedProperties = [NSMutableArray arrayWithCapacity:objectSchema.computed_properties.size()];
    for (const Property &prop : objectSchema.computed_properties) {
        [computedProperties addObject:[RLMProperty propertyForObjectStoreProperty:prop]];
    }
    schema.computedProperties = computedProperties;

    // get primary key from realm metadata
    if (objectSchema.primary_key.length()) {
        NSString *primaryKeyString = [NSString stringWithUTF8String:objectSchema.primary_key.c_str()];
        schema.primaryKeyProperty = schema[primaryKeyString];
        if (!schema.primaryKeyProperty) {
            @throw RLMException(@"No property matching primary key '%@'", primaryKeyString);
        }
    }

    // for dynamic schema use vanilla RLMDynamicObject accessor classes
    schema.objectClass = RLMObject.class;
    schema.accessorClass = RLMDynamicObject.class;
    schema.unmanagedClass = RLMObject.class;

    return schema;
}

- (NSArray *)swiftGenericProperties {
    if (_swiftGenericProperties) {
        return _swiftGenericProperties;
    }

    // This check isn't semantically required, but avoiding accessing the local
    // static helps perf in the obj-c case
    if (!_isSwiftClass) {
        return _swiftGenericProperties = @[];
    }

    // Check if it's a swift class using the obj-c API
    static Class s_swiftObjectClass = NSClassFromString(@"RealmSwiftObject");
    if (![_accessorClass isSubclassOfClass:s_swiftObjectClass]) {
        return _swiftGenericProperties = @[];
    }

    NSMutableArray *genericProperties = [NSMutableArray new];
    for (RLMProperty *prop in _properties) {
        if (prop->_swiftIvar) {
            [genericProperties addObject:prop];
        }
    }
    // Currently all computed properties are Swift generics
    [genericProperties addObjectsFromArray:_computedProperties];

    return _swiftGenericProperties = genericProperties;
}

@end
