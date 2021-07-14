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

#import "RLMEmbeddedObject.h"
#import "RLMObject_Private.h"
#import "RLMProperty_Private.hpp"
#import "RLMRealm_Dynamic.h"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMSwiftCollectionBase.h"
#import "RLMSwiftSupport.h"
#import "RLMUtil.hpp"

#import <realm/object-store/object_schema.hpp>
#import <realm/object-store/object_store.hpp>

using namespace realm;

// private properties
@interface RLMObjectSchema ()
@property (nonatomic, readwrite) NSDictionary<id, RLMProperty *> *allPropertiesByName;
@property (nonatomic, readwrite) NSString *className;
@end

@implementation RLMObjectSchema {
    std::string _objectStoreName;
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
    _primaryKeyProperty = nil;
    NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:_properties.count + _computedProperties.count];
    NSUInteger index = 0;
    for (RLMProperty *prop in _properties) {
        prop.index = index++;
        map[prop.name] = prop;
        if (prop.isPrimary) {
            if (_primaryKeyProperty) {
                @throw RLMException(@"Properties '%@' and '%@' are both marked as the primary key of '%@'",
                                    prop.name, _primaryKeyProperty.name, _className);
            }
            _primaryKeyProperty = prop;
        }
    }
    index = 0;
    for (RLMProperty *prop in _computedProperties) {
        prop.index = index++;
        map[prop.name] = prop;
    }
    _allPropertiesByName = map;

    if (RLMIsSwiftObjectClass(_accessorClass)) {
        NSMutableArray *genericProperties = [NSMutableArray new];
        for (RLMProperty *prop in _properties) {
            if (prop.swiftAccessor) {
                [genericProperties addObject:prop];
            }
        }
        // Currently all computed properties are Swift generics
        [genericProperties addObjectsFromArray:_computedProperties];

        if (genericProperties.count) {
            _swiftGenericProperties = genericProperties;
        }
        else {
            _swiftGenericProperties = nil;
        }
    }
}


- (void)setPrimaryKeyProperty:(RLMProperty *)primaryKeyProperty {
    _primaryKeyProperty.isPrimary = NO;
    primaryKeyProperty.isPrimary = YES;
    _primaryKeyProperty = primaryKeyProperty;
    _primaryKeyProperty.indexed = YES;
}

+ (instancetype)schemaForObjectClass:(Class)objectClass {
    RLMObjectSchema *schema = [RLMObjectSchema new];

    // determine classname from objectclass as className method has not yet been updated
    NSString *className = NSStringFromClass(objectClass);
    bool hasSwiftName = [RLMSwiftSupport isSwiftClassName:className];
    if (hasSwiftName) {
        className = [RLMSwiftSupport demangleClassName:className];
    }

    bool isSwift = hasSwiftName || RLMIsSwiftObjectClass(objectClass);

    schema.className = className;
    schema.objectClass = objectClass;
    schema.accessorClass = objectClass;
    schema.unmanagedClass = objectClass;
    schema.isSwiftClass = isSwift;
    schema.isEmbedded = [(id)objectClass isEmbedded];

    // create array of RLMProperties, inserting properties of superclasses first
    Class cls = objectClass;
    Class superClass = class_getSuperclass(cls);
    NSArray *allProperties = @[];
    while (superClass && superClass != RLMObjectBase.class) {
        allProperties = [[RLMObjectSchema propertiesForClass:cls isSwift:isSwift]
                         arrayByAddingObjectsFromArray:allProperties];
        cls = superClass;
        superClass = class_getSuperclass(superClass);
        
        NSString *clsName = NSStringFromClass(cls);
        isSwift = [RLMSwiftSupport isSwiftClassName:clsName] || [cls isSubclassOfClass:s_swiftObjectClass];
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
        if (schema.primaryKeyProperty.type != RLMPropertyTypeInt &&
            schema.primaryKeyProperty.type != RLMPropertyTypeString &&
            schema.primaryKeyProperty.type != RLMPropertyTypeObjectId &&
            schema.primaryKeyProperty.type != RLMPropertyTypeUUID) {
            @throw RLMException(@"Property '%@' cannot be made the primary key of '%@' because it is not a 'string', 'int', 'objectId', or 'uuid' property.",
                                primaryKey, className);
        }
    }

    for (RLMProperty *prop in schema.properties) {
        if (prop.optional && prop.collection && !prop.dictionary && (prop.type == RLMPropertyTypeObject || prop.type == RLMPropertyTypeLinkingObjects)) {
            // FIXME: message is awkward
            @throw RLMException(@"Property '%@.%@' cannot be made optional because optional '%@' properties are not supported.",
                                className, prop.name, RLMTypeToString(prop.type));
        }
    }

    if ([objectClass shouldIncludeInDefaultSchema]
        && schema.isSwiftClass
        && schema.properties.count == 0) {
        @throw RLMException(@"No properties are defined for '%@'. Did you remember to mark them with '@objc' in your model?", schema.className);
    }
    return schema;
}

+ (NSArray *)propertiesForClass:(Class)objectClass isSwift:(bool)isSwiftClass {
    if (NSArray<RLMProperty *> *props = [objectClass _getProperties]) {
        return props;
    }

    // For Swift subclasses of RLMObject we need an instance of the object when parsing properties
    id swiftObjectInstance = isSwiftClass ? [[objectClass alloc] init] : nil;

    NSArray *ignoredProperties = [objectClass ignoredProperties];
    NSDictionary *linkingObjectsProperties = [objectClass linkingObjectsProperties];
    NSDictionary *columnNameMap = [objectClass _realmColumnNames];

    unsigned int count;
    std::unique_ptr<objc_property_t[], decltype(&free)> props(class_copyPropertyList(objectClass, &count), &free);
    NSMutableArray<RLMProperty *> *propArray = [NSMutableArray arrayWithCapacity:count];
    NSSet *indexed = [[NSSet alloc] initWithArray:[objectClass indexedProperties]];
    for (unsigned int i = 0; i < count; i++) {
        NSString *propertyName = @(property_getName(props[i]));
        if ([ignoredProperties containsObject:propertyName]) {
            continue;
        }

        RLMProperty *prop = nil;
        if (isSwiftClass) {
            prop = [[RLMProperty alloc] initSwiftPropertyWithName:propertyName
                                                          indexed:[indexed containsObject:propertyName]
                                           linkPropertyDescriptor:linkingObjectsProperties[propertyName]
                                                         property:props[i]
                                                         instance:swiftObjectInstance];
        }
        else {
            prop = [[RLMProperty alloc] initWithName:propertyName
                                             indexed:[indexed containsObject:propertyName]
                              linkPropertyDescriptor:linkingObjectsProperties[propertyName]
                                            property:props[i]];
        }

        if (prop) {
            if (columnNameMap) {
                prop.columnName = columnNameMap[prop.name];
            }
            [propArray addObject:prop];
        }
    }

    if (auto requiredProperties = [objectClass requiredProperties]) {
        for (RLMProperty *property in propArray) {
            bool required = [requiredProperties containsObject:property.name];
            if (required && property.type == RLMPropertyTypeObject && (!property.collection || property.dictionary)) {
                @throw RLMException(@"Object properties cannot be made required, "
                                    "but '+[%@ requiredProperties]' included '%@'", objectClass, property.name);
            }
            property.optional &= !required;
        }
    }

    for (RLMProperty *property in propArray) {
        if (!property.optional && property.type == RLMPropertyTypeObject && !property.collection) {
            @throw RLMException(@"The `%@.%@` property must be marked as being optional.",
                                [objectClass className], property.name);
        }
        if (property.type == RLMPropertyTypeAny) {
            property.optional = NO;
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
    schema->_isEmbedded = _isEmbedded;

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
    return [NSString stringWithFormat:@"%@ %@{\n%@}",
            self.className, _isEmbedded ? @"(embedded) " : @"", propertiesString];
}

- (NSString *)objectName {
    return [self.objectClass _realmObjectName] ?: _className;
}

- (std::string const&)objectStoreName {
    if (_objectStoreName.empty()) {
        _objectStoreName = self.objectName.UTF8String;
    }
    return _objectStoreName;
}

- (realm::ObjectSchema)objectStoreCopy:(RLMSchema *)schema {
    ObjectSchema objectSchema;
    objectSchema.name = self.objectStoreName;
    objectSchema.primary_key = _primaryKeyProperty ? _primaryKeyProperty.columnName.UTF8String : "";
    objectSchema.is_embedded = ObjectSchema::IsEmbedded(_isEmbedded);
    for (RLMProperty *prop in _properties) {
        Property p = [prop objectStoreCopy:schema];
        p.is_primary = (prop == _primaryKeyProperty);
        objectSchema.persisted_properties.push_back(std::move(p));
    }
    for (RLMProperty *prop in _computedProperties) {
        objectSchema.computed_properties.push_back([prop objectStoreCopy:schema]);
    }
    return objectSchema;
}

+ (instancetype)objectSchemaForObjectStoreSchema:(realm::ObjectSchema const&)objectSchema {
    RLMObjectSchema *schema = [RLMObjectSchema new];
    schema.className = @(objectSchema.name.c_str());
    schema.isEmbedded = objectSchema.is_embedded;

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

@end
