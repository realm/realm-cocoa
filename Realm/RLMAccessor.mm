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

#import "RLMAccessor.hpp"

#import "RLMArray_Private.hpp"
#import "RLMInteger_Private.h"
#import "RLMListBase.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMRealm_Private.hpp"
#import "RLMResults_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMUtil.hpp"
#import "results.hpp"
#import "property.hpp"

#import <objc/runtime.h>
#import <objc/message.h>
#import <realm/descriptor.hpp>

#pragma mark - Helper functions

namespace {
template<typename T>
T get(__unsafe_unretained RLMObjectBase *const obj, NSUInteger index) {
    RLMVerifyAttached(obj);
    return obj->_row.get<T>(obj->_info->objectSchema->persisted_properties[index].table_column);
}

template<typename T>
id getBoxed(__unsafe_unretained RLMObjectBase *const obj, NSUInteger index) {
    RLMVerifyAttached(obj);
    auto& prop = obj->_info->objectSchema->persisted_properties[index];
    auto col = prop.table_column;
    if (obj->_row.is_null(col)) {
        return nil;
    }

    RLMAccessorContext ctx(obj, &prop);
    return ctx.box(obj->_row.get<T>(col));
}

template<typename T>
void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, T val) {
    RLMVerifyInWriteTransaction(obj);
    obj->_row.set(colIndex, val);
}

template<typename Fn>
void translateError(Fn&& fn) {
    try {
        fn();
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained NSString *const val) {
    RLMVerifyInWriteTransaction(obj);
    translateError([&] {
        obj->_row.set(colIndex, RLMStringDataWithNSString(val));
    });
}

[[gnu::noinline]]
void setNull(realm::Row& row, size_t col) {
    translateError([&] { row.set_null(col); });
}

void setValue(__unsafe_unretained RLMObjectBase *const obj,
              NSUInteger colIndex, __unsafe_unretained NSDate *const date) {
    RLMVerifyInWriteTransaction(obj);
    if (date) {
        obj->_row.set(colIndex, RLMTimestampForNSDate(date));
    }
    else {
        setNull(obj->_row, colIndex);
    }
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained NSData *const data) {
    RLMVerifyInWriteTransaction(obj);
    translateError([&] {
        obj->_row.set(colIndex, RLMBinaryDataForNSData(data));
    });
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained RLMObjectBase *const val) {
    if (!val) {
        RLMVerifyInWriteTransaction(obj);
        obj->_row.nullify_link(colIndex);
        return;
    }

    RLMAddObjectToRealm(val, obj->_realm, false);

    // make sure it is the correct type
    if (val->_row.get_table() != obj->_row.get_table()->get_link_target(colIndex)) {
        @throw RLMException(@"Can't set object of type '%@' to property of type '%@'",
                            val->_objectSchema.className,
                            obj->_info->propertyForTableColumn(colIndex).objectClassName);
    }
    obj->_row.set_link(colIndex, val->_row.get_index());
}

// array getter/setter
RLMArray *getArray(__unsafe_unretained RLMObjectBase *const obj, NSUInteger propIndex) {
    RLMVerifyAttached(obj);
    auto prop = obj->_info->rlmObjectSchema.properties[propIndex];
    return [[RLMManagedArray alloc] initWithParent:obj property:prop];
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained id<NSFastEnumeration> const value) {
    RLMVerifyInWriteTransaction(obj);
    auto prop = obj->_info->propertyForTableColumn(colIndex);
    RLMValidateValueForProperty(value, obj->_info->rlmObjectSchema, prop, true);

    realm::List list(obj->_realm->_realm, *obj->_row.get_table(), colIndex, obj->_row.get_index());
    RLMClassInfo *info = obj->_info;
    if (list.get_type() == realm::PropertyType::Object) {
        info = &obj->_info->linkTargetType(prop.index);
    }
    RLMAccessorContext ctx(obj->_realm, *info);
    translateError([&] { list.assign(ctx, value, false); });
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained NSNumber<RLMInt> *const intObject) {
    RLMVerifyInWriteTransaction(obj);

    if (intObject) {
        obj->_row.set(colIndex, intObject.longLongValue);
    }
    else {
        setNull(obj->_row, colIndex);
    }
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained NSNumber<RLMFloat> *const floatObject) {
    RLMVerifyInWriteTransaction(obj);

    if (floatObject) {
        obj->_row.set(colIndex, floatObject.floatValue);
    }
    else {
        setNull(obj->_row, colIndex);
    }
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained NSNumber<RLMDouble> *const doubleObject) {
    RLMVerifyInWriteTransaction(obj);

    if (doubleObject) {
        obj->_row.set(colIndex, doubleObject.doubleValue);
    }
    else {
        setNull(obj->_row, colIndex);
    }
}

void setValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
              __unsafe_unretained NSNumber<RLMBool> *const boolObject) {
    RLMVerifyInWriteTransaction(obj);

    if (boolObject) {
        obj->_row.set(colIndex, (bool)boolObject.boolValue);
    }
    else {
        setNull(obj->_row, colIndex);
    }
}

RLMLinkingObjects *getLinkingObjects(__unsafe_unretained RLMObjectBase *const obj,
                                     __unsafe_unretained RLMProperty *const property) {
    RLMVerifyAttached(obj);
    auto& objectInfo = obj->_realm->_info[property.objectClassName];
    auto linkingProperty = objectInfo.objectSchema->property_for_name(property.linkOriginPropertyName.UTF8String);
    auto backlinkView = obj->_row.get_table()->get_backlink_view(obj->_row.get_index(), objectInfo.table(), linkingProperty->table_column);
    realm::Results results(obj->_realm->_realm, std::move(backlinkView));
    return [RLMLinkingObjects resultsWithObjectInfo:objectInfo results:std::move(results)];
}

// any getter/setter
template<typename Type, typename StorageType=Type>
id makeGetter(NSUInteger index) {
    return ^(__unsafe_unretained RLMObjectBase *const obj) {
        return static_cast<Type>(get<StorageType>(obj, index));
    };
}

template<typename Type>
id makeBoxedGetter(NSUInteger index) {
    return ^(__unsafe_unretained RLMObjectBase *const obj) {
        return getBoxed<Type>(obj, index);
    };
}
template<typename Type>
id makeOptionalGetter(NSUInteger index) {
    return ^(__unsafe_unretained RLMObjectBase *const obj) {
        return getBoxed<realm::util::Optional<Type>>(obj, index);
    };
}
template<typename Type>
id makeNumberGetter(NSUInteger index, bool boxed, bool optional) {
    if (optional) {
        return makeOptionalGetter<Type>(index);
    }
    if (boxed) {
        return makeBoxedGetter<Type>(index);
    }
    return makeGetter<Type>(index);
}

// dynamic getter with column closure
id managedGetter(RLMProperty *prop, const char *type) {
    NSUInteger index = prop.index;
    if (prop.array && prop.type != RLMPropertyTypeLinkingObjects) {
        return ^id(__unsafe_unretained RLMObjectBase *const obj) {
            return getArray(obj, index);
        };
    }

    bool boxed = *type == '@';
    switch (prop.type) {
        case RLMPropertyTypeInt:
            if (prop.subtype == RLMPropertySubtypeInteger) {
                return ^RLMInteger *(__unsafe_unretained RLMObjectBase *const obj) {
                    RLMVerifyAttached(obj);
                    return [[RLMInteger alloc] initWithObject:obj property:prop];
                };
            }
            if (prop.optional || boxed) {
                return makeNumberGetter<long long>(index, boxed, prop.optional);
            }
            switch (*type) {
                case 'c': return makeGetter<char, int64_t>(index);
                case 's': return makeGetter<short, int64_t>(index);
                case 'i': return makeGetter<int, int64_t>(index);
                case 'l': return makeGetter<long, int64_t>(index);
                case 'q': return makeGetter<long long, int64_t>(index);
                default:
                    @throw RLMException(@"Unexpected property type for Objective-C type code");
            }
        case RLMPropertyTypeFloat:
            return makeNumberGetter<float>(index, boxed, prop.optional);
        case RLMPropertyTypeDouble:
            return makeNumberGetter<double>(index, boxed, prop.optional);
        case RLMPropertyTypeBool:
            return makeNumberGetter<bool>(index, boxed, prop.optional);
        case RLMPropertyTypeString:
            return makeBoxedGetter<realm::StringData>(index);
        case RLMPropertyTypeDate:
            return makeBoxedGetter<realm::Timestamp>(index);
        case RLMPropertyTypeData:
            return makeBoxedGetter<realm::BinaryData>(index);
        case RLMPropertyTypeObject:
            return makeBoxedGetter<realm::RowExpr>(index);
        case RLMPropertyTypeAny:
            @throw RLMException(@"Cannot create accessor class for schema with Mixed properties");
        case RLMPropertyTypeLinkingObjects:
            return ^(__unsafe_unretained RLMObjectBase *const obj) {
                return getLinkingObjects(obj, prop);
            };
    }
}

template<typename ArgType, typename StorageType=ArgType>
id makeSetter(__unsafe_unretained RLMProperty *const prop) {
    NSUInteger index = prop.index;
    NSString *name = prop.name;
    if (prop.isPrimary) {
        return ^(__unused RLMObjectBase *obj, __unused ArgType val) {
            @throw RLMException(@"Primary key can't be changed after an object is inserted.");
        };
    }

    return ^(__unsafe_unretained RLMObjectBase *const obj, ArgType val) {
        auto set = [&] {
            setValue(obj, obj->_info->objectSchema->persisted_properties[index].table_column,
                     static_cast<StorageType>(val));
        };
        if (RLMObservationInfo *info = RLMGetObservationInfo(obj->_observationInfo,
                                                             obj->_row.get_index(), *obj->_info)) {
            info->willChange(name);
            set();
            info->didChange(name);
        }
        else {
            set();
        }
    };
}

static inline NSNumber<RLMInt> *RLMCoerceToNSNumber(__unsafe_unretained id obj) {
    REALM_ASSERT_DEBUG(obj == nil || RLMDynamicCast<NSNumber>(obj));
    return obj;
}

id makeRealmIntegerSetter(__unsafe_unretained RLMProperty *const prop) {
    // FIXME: move this into the `makeSetter` method once we support `if constexpr`
    NSUInteger index = prop.index;
    NSString *name = prop.name;
    REALM_ASSERT(!prop.isPrimary);
    return ^(__unsafe_unretained RLMObjectBase *const obj, id val) {
        auto set = [&] {
            setValue(obj, obj->_info->objectSchema->persisted_properties[index].table_column,
                     RLMCoerceToNSNumber(val));
        };
        if (RLMObservationInfo *info = RLMGetObservationInfo(obj->_observationInfo,
                                                             obj->_row.get_index(), *obj->_info)) {
            info->willChange(name);
            set();
            info->didChange(name);
        }
        else {
            set();
        }
    };
}

// dynamic setter with column closure
id managedSetter(RLMProperty *prop, const char *type) {
    if (prop.array && prop.type != RLMPropertyTypeLinkingObjects) {
        return makeSetter<id<NSFastEnumeration>>(prop);
    }

    bool boxed = prop.optional || *type == '@';
    switch (prop.type) {
        case RLMPropertyTypeInt:
            if (prop.subtype == RLMPropertySubtypeInteger) {
                return makeRealmIntegerSetter(prop);
            }
            if (boxed) {
                return makeSetter<NSNumber<RLMInt> *>(prop);
            }
            switch (*type) {
                case 'c': return makeSetter<char, long long>(prop);
                case 's': return makeSetter<short, long long>(prop);
                case 'i': return makeSetter<int, long long>(prop);
                case 'l': return makeSetter<long, long long>(prop);
                case 'q': return makeSetter<long long>(prop);
                default:
                    @throw RLMException(@"Unexpected property type for Objective-C type code");
            }
        case RLMPropertyTypeFloat:
            return boxed ? makeSetter<NSNumber<RLMFloat> *>(prop) : makeSetter<float>(prop);
        case RLMPropertyTypeDouble:
            return boxed ? makeSetter<NSNumber<RLMDouble> *>(prop) : makeSetter<double>(prop);
        case RLMPropertyTypeBool:
            return boxed ? makeSetter<NSNumber<RLMBool> *>(prop) : makeSetter<BOOL, bool>(prop);
        case RLMPropertyTypeString:         return makeSetter<NSString *>(prop);
        case RLMPropertyTypeDate:           return makeSetter<NSDate *>(prop);
        case RLMPropertyTypeData:           return makeSetter<NSData *>(prop);
        case RLMPropertyTypeAny:            return nil;
        case RLMPropertyTypeLinkingObjects: return nil;
        case RLMPropertyTypeObject:         return makeSetter<RLMObjectBase *>(prop);
    }
}

// call getter for superclass for property at colIndex
id superGet(RLMObjectBase *obj, NSString *propName) {
    typedef id (*getter_type)(RLMObjectBase *, SEL);
    RLMProperty *prop = obj->_objectSchema[propName];
    Class superClass = class_getSuperclass(obj.class);
    getter_type superGetter = (getter_type)[superClass instanceMethodForSelector:prop.getterSel];
    return superGetter(obj, prop.getterSel);
}

// call setter for superclass for property at colIndex
void superSet(RLMObjectBase *obj, NSString *propName, id val) {
    typedef void (*setter_type)(RLMObjectBase *, SEL, RLMArray *ar);
    RLMProperty *prop = obj->_objectSchema[propName];
    Class superClass = class_getSuperclass(obj.class);
    setter_type superSetter = (setter_type)[superClass instanceMethodForSelector:prop.setterSel];
    superSetter(obj, prop.setterSel, val);
}

// getter/setter for unmanaged object
id unmanagedGetter(RLMProperty *prop, const char *) {
    // only override getters for RLMArray and linking objects properties
    if (prop.type == RLMPropertyTypeLinkingObjects) {
        return ^(RLMObjectBase *) { return [RLMResults emptyDetachedResults]; };
    }
    NSString *propName = prop.name;
    if (prop.subtype == RLMPropertySubtypeInteger) {
        return ^(RLMObjectBase *obj){
            id val = superGet(obj, propName);
            if (!val) {
                val = [[RLMInteger alloc] initWithValue:(prop.optional ? nil : @0)];
                superSet(obj, propName, val);
            }
            return val;
        };
    }
    if (prop.array) {
        if (prop.type == RLMPropertyTypeObject) {
            NSString *objectClassName = prop.objectClassName;
            return ^(RLMObjectBase *obj) {
                id val = superGet(obj, propName);
                if (!val) {
                    val = [[RLMArray alloc] initWithObjectClassName:objectClassName];
                    superSet(obj, propName, val);
                }
                return val;
            };
        }
        auto type = prop.type;
        auto optional = prop.optional;
        return ^(RLMObjectBase *obj) {
            id val = superGet(obj, propName);
            if (!val) {
                val = [[RLMArray alloc] initWithObjectType:type optional:optional];
                superSet(obj, propName, val);
            }
            return val;
        };
    }
    return nil;
}

id unmanagedSetter(RLMProperty *prop, const char *) {
    // Only RLMArray needs special handling for the unmanaged setter
    if (!prop.array) {
        return nil;
    }

    NSString *propName = prop.name;
    return ^(RLMObjectBase *obj, id<NSFastEnumeration> values) {
        auto prop = obj->_objectSchema[propName];
        RLMValidateValueForProperty(values, obj->_objectSchema, prop, true);

        // make copy when setting (as is the case for all other variants)
        RLMArray *ar;
        if (prop.type == RLMPropertyTypeObject)
            ar = [[RLMArray alloc] initWithObjectClassName:prop.objectClassName];
        else
            ar = [[RLMArray alloc] initWithObjectType:prop.type optional:prop.optional];
        [ar addObjects:values];
        superSet(obj, propName, ar);
    };
}

void addMethod(Class cls, __unsafe_unretained RLMProperty *const prop,
               id (*getter)(RLMProperty *, const char *),
               id (*setter)(RLMProperty *, const char *)) {
    SEL sel = prop.getterSel;
    auto getterMethod = class_getInstanceMethod(cls, sel);
    if (!getterMethod) {
        return;
    }

    const char *getterType = method_getTypeEncoding(getterMethod);
    if (id block = getter(prop, getterType)) {
        class_addMethod(cls, sel, imp_implementationWithBlock(block), getterType);
    }

    if (!(sel = prop.setterSel)) {
        return;
    }
    auto setterMethod = class_getInstanceMethod(cls, sel);
    if (!setterMethod) {
        return;
    }
    if (id block = setter(prop, getterType)) { // note: deliberately getterType as it's easier to grab the relevant type from
        class_addMethod(cls, sel, imp_implementationWithBlock(block), method_getTypeEncoding(setterMethod));
    }
}

Class createAccessorClass(Class objectClass,
                          RLMObjectSchema *schema,
                          const char *accessorClassName,
                          id (*getterGetter)(RLMProperty *, const char *),
                          id (*setterGetter)(RLMProperty *, const char *)) {
    REALM_ASSERT_DEBUG(RLMIsObjectOrSubclass(objectClass));

    // create and register proxy class which derives from object class
    Class accClass = objc_allocateClassPair(objectClass, accessorClassName, 0);
    if (!accClass) {
        // Class with that name already exists, so just return the pre-existing one
        // This should only happen for our standalone "accessors"
        return objc_lookUpClass(accessorClassName);
    }

    // override getters/setters for each propery
    for (RLMProperty *prop in schema.properties) {
        addMethod(accClass, prop, getterGetter, setterGetter);
    }
    for (RLMProperty *prop in schema.computedProperties) {
        addMethod(accClass, prop, getterGetter, setterGetter);
    }

    objc_registerClassPair(accClass);

    return accClass;
}
} // anonymous namespace

#pragma mark - Public Interface

Class RLMManagedAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema, const char *name) {
    return createAccessorClass(objectClass, schema, name, managedGetter, managedSetter);
}

Class RLMUnmanagedAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema) {
    return createAccessorClass(objectClass, schema,
                               [@"RLM:Unmanaged " stringByAppendingString:schema.className].UTF8String,
                               unmanagedGetter, unmanagedSetter);
}

// implement the class method className on accessors to return the className of the
// base object
void RLMReplaceClassNameMethod(Class accessorClass, NSString *className) {
    Class metaClass = object_getClass(accessorClass);
    IMP imp = imp_implementationWithBlock(^(Class){ return className; });
    class_addMethod(metaClass, @selector(className), imp, "@@:");
}

// implement the shared schema method
void RLMReplaceSharedSchemaMethod(Class accessorClass, RLMObjectSchema *schema) {
    Class metaClass = object_getClass(accessorClass);
    IMP imp = imp_implementationWithBlock(^(Class cls) {
        if (cls == accessorClass) {
            return schema;
        }

        // If we aren't being called directly on the class this was overriden
        // for, the class is either a subclass which we haven't initialized yet,
        // or it's a runtime-generated class which should use the parent's
        // schema. We check for the latter by checking if the immediate
        // descendent of the desired class is a class generated by us (there
        // may be further subclasses not generated by us for things like KVO).
        Class parent = class_getSuperclass(cls);
        while (parent != accessorClass) {
            cls = parent;
            parent = class_getSuperclass(cls);
        }

        static const char accessorClassPrefix[] = "RLM:";
        if (!strncmp(class_getName(cls), accessorClassPrefix, sizeof(accessorClassPrefix) - 1)) {
            return schema;
        }

        return [RLMSchema sharedSchemaForClass:cls];
    });
    class_addMethod(metaClass, @selector(sharedSchema), imp, "@@:");
}

void RLMDynamicIntegerAdd(RLMObjectBase *obj, NSString *propName, NSInteger delta) {
    RLMObjectSchema *schema = obj->_objectSchema;
    RLMProperty *prop = schema[propName];
    if (!prop) {
        @throw RLMException(@"Invalid property name '%@' for class '%@'.", propName, obj->_objectSchema.className);
    }
    if (prop.isPrimary) {
        @throw RLMException(@"Primary key can't be incremented.");
    }
    if (prop.type != RLMPropertyTypeInt) {
        @throw RLMException(@"Cannot increment a non-integer property.");
    }
    RLMVerifyInWriteTransaction(obj);
    auto col = obj->_info->tableColumn(prop);
    auto table = obj->_row.get_table();
    if (table->is_null(col, obj->_row.get_index())) {
        @throw RLMException(@"Cannot increment an integer property whose value is nil. Set its value first.");
    }
    table->add_int(col, obj->_row.get_index(), delta);
}

void RLMDynamicValidatedSet(RLMObjectBase *obj, NSString *propName, id val) {
    RLMObjectSchema *schema = obj->_objectSchema;
    RLMProperty *prop = schema[propName];
    if (!prop) {
        @throw RLMException(@"Invalid property name '%@' for class '%@'.",
                            propName, obj->_objectSchema.className);
    }
    if (prop.isPrimary) {
        @throw RLMException(@"Primary key can't be changed to '%@' after an object is inserted.", val);
    }
    RLMValidateValueForProperty(val, schema, prop, true);
    RLMDynamicSet(obj, prop, RLMCoerceToNil(val));
}

// Precondition: the property is not a primary key
void RLMDynamicSet(__unsafe_unretained RLMObjectBase *const obj,
                   __unsafe_unretained RLMProperty *const prop,
                   __unsafe_unretained id const val) {
    REALM_ASSERT_DEBUG(!prop.isPrimary);
    realm::Object o(obj->_info->realm->_realm, *obj->_info->objectSchema, obj->_row);
    RLMAccessorContext c(obj);
    translateError([&] {
        o.set_property_value(c, prop.name.UTF8String, val ?: NSNull.null, false);
    });
}

id RLMDynamicGet(__unsafe_unretained RLMObjectBase *const obj, __unsafe_unretained RLMProperty *const prop) {
    realm::Object o(obj->_realm->_realm, *obj->_info->objectSchema, obj->_row);
    RLMAccessorContext c(obj);
    c.currentProperty = prop;
    return RLMCoerceToNil(o.get_property_value<id>(c, prop.name.UTF8String));
}

id RLMDynamicGetByName(__unsafe_unretained RLMObjectBase *const obj,
                       __unsafe_unretained NSString *const propName, bool asList) {
    RLMProperty *prop = obj->_objectSchema[propName];
    if (!prop) {
        @throw RLMException(@"Invalid property name '%@' for class '%@'.",
                            propName, obj->_objectSchema.className);
    }
    if (asList && prop.array && prop.swiftIvar) {
        RLMListBase *list = object_getIvar(obj, prop.swiftIvar);
        if (!list._rlmArray) {
            list._rlmArray = RLMDynamicGet(obj, prop);
        }
        return list;
    }

    return RLMDynamicGet(obj, prop);
}

RLMAccessorContext::RLMAccessorContext(RLMAccessorContext& parent, realm::Property const& property)
: _realm(parent._realm)
, _info(property.type == realm::PropertyType::Object ? parent._info.linkTargetType(property) : parent._info)
, _promote_existing(parent._promote_existing)
{
}

RLMAccessorContext::RLMAccessorContext(RLMRealm *realm, RLMClassInfo& info, bool promote)
: _realm(realm), _info(info), _promote_existing(promote)
{
}

RLMAccessorContext::RLMAccessorContext(__unsafe_unretained RLMObjectBase *const parent,
                                       const realm::Property *prop)
: _realm(parent->_realm)
, _info(prop && prop->type == realm::PropertyType::Object ? parent->_info->linkTargetType(*prop)
                                                          : *parent->_info)
, _parentObject(parent)
{
}

id RLMAccessorContext::defaultValue(__unsafe_unretained NSString *const key) {
    if (!_defaultValues) {
        _defaultValues = RLMDefaultValuesForObjectSchema(_info.rlmObjectSchema);
    }
    return _defaultValues[key];
}

id RLMAccessorContext::propertyValue(__unsafe_unretained id const obj, size_t propIndex,
                                     __unsafe_unretained RLMProperty *const prop) {
    // Property value from an NSArray
    if ([obj respondsToSelector:@selector(objectAtIndex:)]) {
        return propIndex < [obj count] ? [obj objectAtIndex:propIndex] : nil;
    }

    // Property value from an NSDictionary
    if ([obj respondsToSelector:@selector(objectForKey:)]) {
        return [obj objectForKey:prop.name];
    }

    // Property value from an instance of this object type
    id value;
    if (prop.subtype != RLMPropertySubtypeInteger
        && [obj isKindOfClass:_info.rlmObjectSchema.objectClass]
        && prop.swiftIvar) {
        if (prop.array) {
            return static_cast<RLMListBase *>(object_getIvar(obj, prop.swiftIvar))._rlmArray;
        }
        else { // optional
            value = static_cast<RLMOptionalBase *>(object_getIvar(obj, prop.swiftIvar)).underlyingValue;
        }
    }
    else {
        // Property value from some object that's KVC-compatible
        value = RLMValidatedValueForProperty(obj, [obj respondsToSelector:prop.getterSel] ? prop.getterName : prop.name,
                                             _info.rlmObjectSchema.className);
    }
    return value ?: NSNull.null;
}

id RLMAccessorContext::box(realm::List&& l) {
    REALM_ASSERT(_parentObject);
    REALM_ASSERT(currentProperty);
    return [[RLMManagedArray alloc] initWithList:std::move(l) realm:_realm
                                      parentInfo:_parentObject->_info
                                        property:currentProperty];
}

id RLMAccessorContext::box(realm::Object&& o) {
    REALM_ASSERT(currentProperty);
    return RLMCreateObjectAccessor(_realm, _info.linkTargetType(currentProperty.index), o.row());
}

id RLMAccessorContext::box(realm::RowExpr r) {
    return RLMCreateObjectAccessor(_realm, _info, r);
}

id RLMAccessorContext::box(realm::Results&& r) {
    REALM_ASSERT(currentProperty);
    return [RLMResults resultsWithObjectInfo:_realm->_info[currentProperty.objectClassName]
                                     results:std::move(r)];
}

template<>
realm::Timestamp RLMAccessorContext::unbox(__unsafe_unretained id const value, bool, bool) {
    id v = RLMCoerceToNil(value);
    return RLMTimestampForNSDate(v);
}

template<>
bool RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return [v boolValue];
}
template<>
double RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return [v doubleValue];
}
template<>
float RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return [v floatValue];
}
template<>
long long RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return [v longLongValue];
}
template<>
realm::BinaryData RLMAccessorContext::unbox(id v, bool, bool) {
    v = RLMCoerceToNil(v);
    return RLMBinaryDataForNSData(v);
}
template<>
realm::StringData RLMAccessorContext::unbox(id v, bool, bool) {
    v = RLMCoerceToNil(v);
    return RLMStringDataWithNSString(v);
}

template<typename Fn>
static auto to_optional(__unsafe_unretained id const value, Fn&& fn) {
    id v = RLMCoerceToNil(value);
    return v && v != NSNull.null ? realm::util::make_optional(fn(v)) : realm::util::none;
}

template<>
realm::util::Optional<bool> RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return to_optional(v, [&](__unsafe_unretained id v) { return (bool)[v boolValue]; });
}
template<>
realm::util::Optional<double> RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return to_optional(v, [&](__unsafe_unretained id v) { return [v doubleValue]; });
}
template<>
realm::util::Optional<float> RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return to_optional(v, [&](__unsafe_unretained id v) { return [v floatValue]; });
}
template<>
realm::util::Optional<int64_t> RLMAccessorContext::unbox(__unsafe_unretained id const v, bool, bool) {
    return to_optional(v, [&](__unsafe_unretained id v) { return [v longLongValue]; });
}

template<>
realm::RowExpr RLMAccessorContext::unbox(__unsafe_unretained id const v, bool create, bool update) {
    RLMObjectBase *link = RLMDynamicCast<RLMObjectBase>(v);
    if (!link) {
        if (!create)
            return realm::RowExpr();
        return RLMCreateObjectInRealmWithValue(_realm, _info.rlmObjectSchema.className, v, update)->_row;
    }

    if (link.isInvalidated) {
        if (create) {
            @throw RLMException(@"Adding a deleted or invalidated object to a Realm is not permitted");
        }
        else {
            @throw RLMException(@"Object has been invalidated");
        }
    }

    if (![link->_objectSchema.className isEqualToString:_info.rlmObjectSchema.className]) {
        if (create && !_promote_existing)
            return RLMCreateObjectInRealmWithValue(_realm, _info.rlmObjectSchema.className, link, update)->_row;
        return link->_row;
    }

    if (!link->_realm) {
        if (!create)
            return realm::RowExpr();
        if (!_promote_existing)
            return RLMCreateObjectInRealmWithValue(_realm, _info.rlmObjectSchema.className, link, update)->_row;
        RLMAddObjectToRealm(link, _realm, update);
    }
    else if (link->_realm != _realm) {
        if (_promote_existing)
            @throw RLMException(@"Object is already managed by another Realm. Use create instead to copy it into this Realm.");
        return RLMCreateObjectInRealmWithValue(_realm, _info.rlmObjectSchema.className, v, update)->_row;
    }
    return link->_row;
}

bool RLMAccessorContext::is_null(id v) {
    if ([v isKindOfClass:[RLMInteger class]]) {
        return ![(RLMInteger *)v value];
    }
    return v == NSNull.null;
}

void RLMAccessorContext::will_change(realm::Row const& row, realm::Property const& prop) {
    _observationInfo = RLMGetObservationInfo(nullptr, row.get_index(), _info);
    if (_observationInfo) {
        _kvoPropertyName = @(prop.name.c_str());
        _observationInfo->willChange(_kvoPropertyName);
    }
}

void RLMAccessorContext::did_change() {
    if (_observationInfo) {
        _observationInfo->didChange(_kvoPropertyName);
        _kvoPropertyName = nil;
        _observationInfo = nullptr;
    }
}

RLMOptionalId RLMAccessorContext::value_for_property(__unsafe_unretained id const obj,
                                                     std::string const&, size_t propIndex) {
    auto prop = _info.rlmObjectSchema.properties[propIndex];
    id value = propertyValue(obj, propIndex, prop);
    if (value) {
        RLMValidateValueForProperty(value, _info.rlmObjectSchema, prop);
    }

    if (_promote_existing && [obj isKindOfClass:_info.rlmObjectSchema.objectClass] && !prop.swiftIvar) {
        // set the ivars for object, array, and Realm integer properties to nil as otherwise the
        // accessors retain objects that are no longer accessible via the properties
        // this is mainly an issue when the object graph being added has cycles,
        // as it's not obvious that the user has to set the *ivars* to nil to
        // avoid leaking memory
        if (prop.type == RLMPropertyTypeObject || prop.subtype == RLMPropertySubtypeInteger) {
            ((void(*)(id, SEL, id))objc_msgSend)(obj, prop.setterSel, nil);
        }
    }

    return RLMOptionalId{value};
}

RLMOptionalId RLMAccessorContext::default_value_for_property(realm::ObjectSchema const&,
                                                             std::string const& prop)
{
    return RLMOptionalId{defaultValue(@(prop.c_str()))};
}

bool RLMAccessorContext::is_same_list(realm::List const& list, __unsafe_unretained id const v) const noexcept {
    return [v respondsToSelector:@selector(isBackedByList:)] && [v isBackedByList:list];
}
