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

#import "RLMAccessor.h"

#import "RLMArray_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMUtil.hpp"

#import <objc/runtime.h>

typedef NS_ENUM(char, RLMAccessorCode) {
    RLMAccessorCodeByte,
    RLMAccessorCodeShort,
    RLMAccessorCodeInt,
    RLMAccessorCodeLong,
    RLMAccessorCodeLongLong,
    RLMAccessorCodeFloat,
    RLMAccessorCodeDouble,
    RLMAccessorCodeBool,
    RLMAccessorCodeString,
    RLMAccessorCodeDate,
    RLMAccessorCodeData,
    RLMAccessorCodeLink,
    RLMAccessorCodeArray,
    RLMAccessorCodeAny,
};

// verify attached
static inline void RLMVerifyAttached(__unsafe_unretained RLMObjectBase *const obj) {
    if (!obj->_row.is_attached()) {
        @throw RLMException(@"Object has been deleted or invalidated.");
    }
    RLMCheckThread(obj->_realm);
}

// verify writable
static inline void RLMVerifyInWriteTransaction(__unsafe_unretained RLMObjectBase *const obj) {
    // first verify is attached
    RLMVerifyAttached(obj);

    if (!obj->_realm->_inWriteTransaction) {
        @throw RLMException(@"Attempting to modify object outside of a write transaction - call beginWriteTransaction on an RLMRealm instance first.");
    }
}

template<typename FunctionType>
static FunctionType RLMGetImpForSelector(Class cls, SEL selector) {
    return reinterpret_cast<FunctionType>(method_getImplementation(class_getInstanceMethod(cls, selector)));
}

namespace {
// Helper for calling superclass methods outside the context of a method
class RLMSuperImpl {
public:
    RLMSuperImpl() { }

    RLMSuperImpl(__unsafe_unretained RLMProperty *const prop, Class superClass)
    : getterSel(prop.getterSel)
    , getter(RLMGetImpForSelector<id (*)(id, SEL)>(superClass, getterSel))
    , setterSel(prop.setterSel)
    , setter(RLMGetImpForSelector<void (*)(id, SEL, id)>(superClass, setterSel))
    {
    }


    id get(__unsafe_unretained id const obj) const {
        return getter ? getter(obj, getterSel) : nil;
    }

    void set(__unsafe_unretained id const obj, __unsafe_unretained id const value) const {
        if (setter) {
            setter(obj, setterSel, value);
        }
    }

private:
    SEL getterSel;
    id (*getter)(id, SEL) = nullptr;
    SEL setterSel;
    void (*setter)(id, SEL, id) = nullptr;
};
}

// long getter/setter
static inline long long RLMGetLong(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    return obj->_row.get_int(colIndex);
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, long long val) {
    RLMVerifyInWriteTransaction(obj);
    obj->_row.set_int(colIndex, val);
}
static inline void RLMSetValueUnique(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, NSString *propName, long long val) {
    RLMVerifyInWriteTransaction(obj);
    size_t row = obj->_row.get_table()->find_first_int(colIndex, val);
    if (row == obj->_row.get_index()) {
        return;
    }
    if (row != realm::not_found) {
        NSString *reason = [NSString stringWithFormat:@"Can't set primary key property '%@' to existing value '%lld'.", propName, val];
        @throw RLMException(reason);
    }
    obj->_row.set_int(colIndex, val);
}

// float getter/setter
static inline float RLMGetFloat(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    return obj->_row.get_float(colIndex);
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, float val) {
    RLMVerifyInWriteTransaction(obj);
    obj->_row.set_float(colIndex, val);
}

// double getter/setter
static inline double RLMGetDouble(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    return obj->_row.get_double(colIndex);
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, double val) {
    RLMVerifyInWriteTransaction(obj);
    obj->_row.set_double(colIndex, val);
}

// bool getter/setter
static inline bool RLMGetBool(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    return obj->_row.get_bool(colIndex);
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, BOOL val) {
    RLMVerifyInWriteTransaction(obj);
    obj->_row.set_bool(colIndex, val);
}

// string getter/setter
static inline NSString *RLMGetString(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    return RLMStringDataToNSString(obj->_row.get_string(colIndex));
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, __unsafe_unretained NSString *const val) {
    RLMVerifyInWriteTransaction(obj);
    try {
        obj->_row.set_string(colIndex, RLMStringDataWithNSString(val));
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}
static inline void RLMSetValueUnique(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, NSString *propName,
                                     __unsafe_unretained NSString *const val) {
    RLMVerifyInWriteTransaction(obj);
    realm::StringData str = RLMStringDataWithNSString(val);
    size_t row = obj->_row.get_table()->find_first_string(colIndex, str);
    if (row == obj->_row.get_index()) {
        return;
    }
    if (row != realm::not_found) {
        NSString *reason = [NSString stringWithFormat:@"Can't set primary key property '%@' to existing value '%@'.", propName, val];
        @throw RLMException(reason);
    }
    try {
        obj->_row.set_string(colIndex, str);
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}

// date getter/setter
static inline NSDate *RLMGetDate(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    realm::DateTime dt = obj->_row.get_datetime(colIndex);
    return [NSDate dateWithTimeIntervalSince1970:dt.get_datetime()];
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, __unsafe_unretained NSDate *const date) {
    RLMVerifyInWriteTransaction(obj);
    std::time_t time = date.timeIntervalSince1970;
    obj->_row.set_datetime(colIndex, realm::DateTime(time));
}

// data getter/setter
static inline NSData *RLMGetData(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex) {
    RLMVerifyAttached(obj);
    realm::BinaryData data = obj->_row.get_binary(colIndex);
    return [NSData dataWithBytes:data.data() length:data.size()];
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex, __unsafe_unretained NSData *const data) {
    RLMVerifyInWriteTransaction(obj);

    try {
        obj->_row.set_binary(colIndex, RLMBinaryDataForNSData(data));
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}

static inline RLMObjectBase *RLMGetLinkedObjectForValue(__unsafe_unretained RLMRealm *const realm,
                                                        __unsafe_unretained NSString *const className,
                                                        __unsafe_unretained id const value,
                                                        RLMCreationOptions creationOptions) NS_RETURNS_RETAINED;
static inline RLMObjectBase *RLMGetLinkedObjectForValue(__unsafe_unretained RLMRealm *const realm,
                                                        __unsafe_unretained NSString *const className,
                                                        __unsafe_unretained id const value,
                                                        RLMCreationOptions creationOptions) {
    RLMObjectBase *link = RLMDynamicCast<RLMObjectBase>(value);
    if (!link || ![link->_objectSchema.className isEqualToString:className]) {
        // create from non-rlmobject
        return RLMCreateObjectInRealmWithValue(realm, className, value, creationOptions & RLMCreationOptionsCreateOrUpdate);
    }

    if (link.isInvalidated) {
        @throw RLMException(@"Adding a deleted or invalidated object to a Realm is not permitted");
    }

    if (link->_realm == realm) {
        return link;
    }

    if (creationOptions & RLMCreationOptionsPromoteStandalone) {
        if (!link->_realm) {
            RLMAddObjectToRealm(link, realm, creationOptions & RLMCreationOptionsCreateOrUpdate);
            return link;
        }
        @throw RLMException(@"Can not add objects from a different Realm");
    }

    // copy from another realm or copy from standalone
    return RLMCreateObjectInRealmWithValue(realm, className, link, creationOptions & RLMCreationOptionsCreateOrUpdate);
}

// link getter/setter
static inline RLMObjectBase *RLMGetLink(__unsafe_unretained RLMObjectBase *const obj,
                                        NSUInteger colIndex,
                                        __unsafe_unretained NSString *const objectClassName,
                                        RLMSuperImpl const& super) {
    RLMVerifyAttached(obj);
    Row const& row = obj->_row;
    __unsafe_unretained RLMObjectBase *value = super.get(obj);
    if (row.is_null_link(colIndex)) {
        if (value) {
            super.set(obj, nil);
        }
        return nil;
    }

    size_t dstRow = row.get_link(colIndex);
    if (value && value->_row.get_index() == dstRow) {
        return value;
    }

    __unsafe_unretained RLMRealm *realm = obj->_realm;
    id newValue = RLMCreateObjectAccessor(realm, realm.schema[objectClassName], dstRow);
    super.set(obj, newValue);
    return newValue;
}

static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
                               __unsafe_unretained RLMObjectBase *const val,
                               RLMSuperImpl const& super) {
    RLMVerifyInWriteTransaction(obj);

    if (!val) {
        obj->_row.nullify_link(colIndex);
        super.set(obj, nil);
    }
    else {
        // make sure it is the correct type
        RLMObjectSchema *valSchema = val->_objectSchema;
        RLMObjectSchema *objSchema = obj->_objectSchema;
        if (![[objSchema.properties[colIndex] objectClassName] isEqualToString:valSchema.className]) {
            NSString *reason = [NSString stringWithFormat:@"Can't set object of type '%@' to property of type '%@'",
                                valSchema.className, [objSchema.properties[colIndex] objectClassName]];
            @throw RLMException(reason);
        }

        RLMObjectBase *link = RLMGetLinkedObjectForValue(obj->_realm, valSchema.className, val, RLMCreationOptionsPromoteStandalone);
        obj->_row.set_link(colIndex, link->_row.get_index());
        super.set(obj, link);
    }
}

// array getter/setter
static inline RLMArray *RLMGetArray(__unsafe_unretained RLMObjectBase *const obj,
                                    NSUInteger colIndex,
                                    __unsafe_unretained NSString *const objectClassName,
                                    RLMSuperImpl const& super) {
    RLMVerifyAttached(obj);

    if (RLMArray *value = super.get(obj)) {
        return value;
    }

    realm::LinkViewRef linkView = obj->_row.get_linklist(colIndex);
    RLMArray *ar = [RLMArrayLinkView arrayWithObjectClassName:objectClassName
                                                         view:linkView
                                                        realm:obj->_realm];
    super.set(obj, ar);
    return ar;
}

static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger colIndex,
                               __unsafe_unretained id<NSFastEnumeration> const array) {
    RLMVerifyInWriteTransaction(obj);

    realm::LinkViewRef linkView = obj->_row.get_linklist(colIndex);
    // remove all old
    // FIXME: make sure delete rules don't purge objects
    linkView->clear();
    for (RLMObjectBase *link in array) {
        RLMObjectBase *addedLink = RLMGetLinkedObjectForValue(obj->_realm, link->_objectSchema.className, link, RLMCreationOptionsPromoteStandalone);
        linkView->add(addedLink->_row.get_index());
    }
}

// any getter/setter
static inline id RLMGetAnyProperty(__unsafe_unretained RLMObjectBase *const obj, NSUInteger col_ndx) {
    RLMVerifyAttached(obj);

    realm::Mixed mixed = obj->_row.get_mixed(col_ndx);
    switch (mixed.get_type()) {
        case RLMPropertyTypeString:
            return RLMStringDataToNSString(mixed.get_string());
        case RLMPropertyTypeInt: {
            return @(mixed.get_int());
        case RLMPropertyTypeFloat:
            return @(mixed.get_float());
        case RLMPropertyTypeDouble:
            return @(mixed.get_double());
        case RLMPropertyTypeBool:
            return @(mixed.get_bool());
        case RLMPropertyTypeDate:
            return [NSDate dateWithTimeIntervalSince1970:mixed.get_datetime().get_datetime()];
        case RLMPropertyTypeData: {
            return RLMBinaryDataToNSData(mixed.get_binary());
        }
        case RLMPropertyTypeArray:
            @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                           reason:@"RLMArray not yet supported" userInfo:nil];

            // for links and other unsupported types throw
        case RLMPropertyTypeObject:
        default:
            @throw RLMException(@"Invalid data type for RLMPropertyTypeAny property.");
        }
    }
}
static inline void RLMSetValue(__unsafe_unretained RLMObjectBase *const obj, NSUInteger col_ndx, __unsafe_unretained id val) {
    RLMVerifyInWriteTransaction(obj);

    // FIXME - enable when Any supports links
    //    if (obj == nil) {
    //        table.nullify_link(col_ndx, row_ndx);
    //        return;
    //    }
    if (NSString *str = RLMDynamicCast<NSString>(val)) {
        obj->_row.set_mixed(col_ndx, RLMStringDataWithNSString(str));
        return;
    }
    if (NSDate *date = RLMDynamicCast<NSDate>(val)) {
        obj->_row.set_mixed(col_ndx, realm::DateTime(time_t([date timeIntervalSince1970])));
        return;
    }
    if (NSData *data = RLMDynamicCast<NSData>(val)) {
        obj->_row.set_mixed(col_ndx, RLMBinaryDataForNSData(data));
        return;
    }
    if (NSNumber *number = RLMDynamicCast<NSNumber>(val)) {
        switch (number.objCType[0]) {
            case 'i':
            case 's':
            case 'l':
            case 'q':
                obj->_row.set_mixed(col_ndx, number.longLongValue);
                return;
            case 'f':
                obj->_row.set_mixed(col_ndx, number.floatValue);
                return;
            case 'd':
                obj->_row.set_mixed(col_ndx, number.doubleValue);
                return;
            case 'B':
            case 'c':
                obj->_row.set_mixed(col_ndx, (bool)number.boolValue);
                return;
        }
    }
    @throw RLMException([NSString stringWithFormat:@"Inserting invalid object of class %@ for an RLMPropertyTypeAny property (%@).", [val class], [obj->_objectSchema.properties[col_ndx] name]]);
}

// dynamic getter with column closure
static IMP RLMAccessorGetter(RLMProperty *prop, RLMAccessorCode accessorCode, Class superClass) {
    NSUInteger colIndex = prop.column;
    switch (accessorCode) {
        case RLMAccessorCodeByte:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return (char)RLMGetLong(obj, colIndex);
            });
        case RLMAccessorCodeShort:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return (short)RLMGetLong(obj, colIndex);
            });
        case RLMAccessorCodeInt:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return (int)RLMGetLong(obj, colIndex);
            });
        case RLMAccessorCodeLongLong:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetLong(obj, colIndex);
            });
        case RLMAccessorCodeLong:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return (long)RLMGetLong(obj, colIndex);
            });
        case RLMAccessorCodeFloat:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetFloat(obj, colIndex);
            });
        case RLMAccessorCodeDouble:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetDouble(obj, colIndex);
            });
        case RLMAccessorCodeBool:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetBool(obj, colIndex);
            });
        case RLMAccessorCodeString:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetString(obj, colIndex);
            });
        case RLMAccessorCodeDate:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetDate(obj, colIndex);
            });
        case RLMAccessorCodeData:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetData(obj, colIndex);
            });
        case RLMAccessorCodeLink: {
            NSString *objectClassName = prop.objectClassName;
            RLMSuperImpl super(prop, superClass);

            return imp_implementationWithBlock(^id(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetLink(obj, colIndex, objectClassName, super);
            });
        }
        case RLMAccessorCodeArray: {
            NSString *objectClassName = prop.objectClassName;
            RLMSuperImpl super(prop, superClass);

            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetArray(obj, colIndex, objectClassName, super);
            });
        }
        case RLMAccessorCodeAny:
            return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj) {
                return RLMGetAnyProperty(obj, colIndex);
            });
    }
}

template<typename ArgType, typename StorageType=ArgType>
static IMP RLMMakeSetter(RLMProperty *prop) {
    NSUInteger colIndex = prop.column;
    if (prop.isPrimary) {
        return imp_implementationWithBlock(^(__unused RLMObjectBase *obj, __unused ArgType val) {
            @throw RLMException(@"Primary key can't be changed after an object is inserted.");
        });
    }
    return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj, ArgType val) {
        RLMSetValue(obj, colIndex, static_cast<StorageType>(val));
    });
}

template<typename T>
static IMP RLMMakeSetter(RLMProperty *prop, Class parentClass) {
    NSUInteger colIndex = prop.column;
    RLMSuperImpl super(prop, parentClass);
    return imp_implementationWithBlock(^(__unsafe_unretained RLMObjectBase *const obj, T val) {
        RLMSetValue(obj, colIndex, val, super);
    });
}

// dynamic setter with column closure
static IMP RLMAccessorSetter(RLMProperty *prop, RLMAccessorCode accessorCode, Class parentClass) {
    switch (accessorCode) {
        case RLMAccessorCodeByte:     return RLMMakeSetter<char, long long>(prop);
        case RLMAccessorCodeShort:    return RLMMakeSetter<short, long long>(prop);
        case RLMAccessorCodeInt:      return RLMMakeSetter<int, long long>(prop);
        case RLMAccessorCodeLong:     return RLMMakeSetter<long, long long>(prop);
        case RLMAccessorCodeLongLong: return RLMMakeSetter<long long>(prop);
        case RLMAccessorCodeFloat:    return RLMMakeSetter<float>(prop);
        case RLMAccessorCodeDouble:   return RLMMakeSetter<double>(prop);
        case RLMAccessorCodeBool:     return RLMMakeSetter<BOOL>(prop);
        case RLMAccessorCodeString:   return RLMMakeSetter<NSString *>(prop);
        case RLMAccessorCodeDate:     return RLMMakeSetter<NSDate *>(prop);
        case RLMAccessorCodeData:     return RLMMakeSetter<NSData *>(prop);
        case RLMAccessorCodeLink:     return RLMMakeSetter<RLMObjectBase *>(prop, parentClass);
        case RLMAccessorCodeArray:    return RLMMakeSetter<RLMArray *>(prop);
        case RLMAccessorCodeAny:      return RLMMakeSetter<id>(prop);
    }
}

// getter/setter for standalone
static IMP RLMAccessorStandaloneGetter(RLMProperty *prop, RLMAccessorCode accessorCode, Class superClass) {
    // only override getters for RLMArray properties
    if (accessorCode == RLMAccessorCodeArray) {
        NSString *objectClassName = prop.objectClassName;
        RLMSuperImpl super(prop, superClass);

        return imp_implementationWithBlock(^(RLMObjectBase *obj) {
            id val = super.get(obj);
            if (!val) {
                val = [[RLMArray alloc] initWithObjectClassName:objectClassName standalone:YES];
                super.set(obj, val);
            }
            return val;
        });
    }
    return nil;
}
static IMP RLMAccessorStandaloneSetter(RLMProperty *prop, RLMAccessorCode accessorCode, Class superClass) {
    // only override getters for RLMArray properties
    if (accessorCode == RLMAccessorCodeArray) {
        NSString *objectClassName = prop.objectClassName;
        RLMSuperImpl super(prop, superClass);

        return imp_implementationWithBlock(^(RLMObjectBase *obj, id<NSFastEnumeration> ar) {
            if (ar == nil || ar == (id)NSNull.null) {
                super.set(obj, nil);
            }
            else {
                // make copy when setting (as is the case for all other variants)
                RLMArray *standaloneAr = [[RLMArray alloc] initWithObjectClassName:objectClassName standalone:YES];
                [standaloneAr addObjects:ar];
                super.set(obj, standaloneAr);
            }
        });
    }
    return nil;
}

// macros/helpers to generate objc type strings for registering methods
#define GETTER_TYPES(C) C ":@"
#define SETTER_TYPES(C) "v:@" C

// getter type strings
// NOTE: this typecode is really the the first charachter of the objc/runtime.h type
//       the @ type maps to multiple core types (string, date, array, mixed, any which are id in objc)
static const char *getterTypeStringForObjcCode(char code) {
    switch (code) {
        case 's': return GETTER_TYPES("s");
        case 'i': return GETTER_TYPES("i");
        case 'l': return GETTER_TYPES("l");
        case 'q': return GETTER_TYPES("q");
        case 'f': return GETTER_TYPES("f");
        case 'd': return GETTER_TYPES("d");
        case 'B': return GETTER_TYPES("B");
        case 'c': return GETTER_TYPES("c");
        case '@': return GETTER_TYPES("@");
        default: @throw RLMException(@"Invalid accessor code");
    }
}

// setter type strings
// NOTE: this typecode is really the the first charachter of the objc/runtime.h type
//       the @ type maps to multiple core types (string, date, array, mixed, any which are id in objc)
static const char *setterTypeStringForObjcCode(char code) {
    switch (code) {
        case 's': return SETTER_TYPES("s");
        case 'i': return SETTER_TYPES("i");
        case 'l': return SETTER_TYPES("l");
        case 'q': return SETTER_TYPES("q");
        case 'f': return SETTER_TYPES("f");
        case 'd': return SETTER_TYPES("d");
        case 'B': return SETTER_TYPES("B");
        case 'c': return SETTER_TYPES("c");
        case '@': return SETTER_TYPES("@");
        default: @throw RLMException(@"Invalid accessor code");
    }
}

// get accessor lookup code based on objc type and rlm type
static RLMAccessorCode accessorCodeForType(char objcTypeCode, RLMPropertyType rlmType) {
    switch (objcTypeCode) {
        case 't': return RLMAccessorCodeArray;
        case '@':               // custom accessors for strings and subtables
            switch (rlmType) {  // custom accessor codes for types that map to objc objects
                case RLMPropertyTypeObject: return RLMAccessorCodeLink;
                case RLMPropertyTypeString: return RLMAccessorCodeString;
                case RLMPropertyTypeArray: return RLMAccessorCodeArray;
                case RLMPropertyTypeDate: return RLMAccessorCodeDate;
                case RLMPropertyTypeData: return RLMAccessorCodeData;
                case RLMPropertyTypeAny: return RLMAccessorCodeAny;
                    
                // throw for all primitive types
                case RLMPropertyTypeBool:
                case RLMPropertyTypeDouble:
                case RLMPropertyTypeFloat:
                case RLMPropertyTypeInt:
                    break;
            }
        case 'c':
            switch (rlmType) {
                case RLMPropertyTypeInt: return RLMAccessorCodeByte;
                case RLMPropertyTypeBool: return RLMAccessorCodeBool;
                default: break;
            }
        case 'B': return RLMAccessorCodeBool;
        case 's': return RLMAccessorCodeShort;
        case 'i': return RLMAccessorCodeInt;
        case 'l': return RLMAccessorCodeLong;
        case 'q': return RLMAccessorCodeLongLong;
        case 'f': return RLMAccessorCodeFloat;
        case 'd': return RLMAccessorCodeDouble;
        default:
            @throw RLMException(@"Invalid type for objc typecode");
    }
}

// implement the class method className on accessors to return the className of the
// base object
void RLMReplaceClassNameMethod(Class accessorClass, NSString *className) {
    Class metaClass = objc_getMetaClass(class_getName(accessorClass));
    IMP imp = imp_implementationWithBlock(^{ return className; });
    class_addMethod(metaClass, @selector(className), imp, "@:");
}

// implement the shared schema method
void RLMReplaceSharedSchemaMethod(Class accessorClass, RLMObjectSchema *schema) {
    Class metaClass = objc_getMetaClass(class_getName(accessorClass));
    IMP imp = imp_implementationWithBlock(^{ return schema; });
    class_replaceMethod(metaClass, @selector(sharedSchema), imp, "@:");
}

static Class RLMCreateAccessorClass(Class objectClass,
                                    RLMObjectSchema *schema,
                                    NSString *accessorClassPrefix,
                                    IMP (*getterGetter)(RLMProperty *, RLMAccessorCode, Class),
                                    IMP (*setterGetter)(RLMProperty *, RLMAccessorCode, Class)) {
    // throw if no schema, prefix, or object class
    if (!objectClass || !schema || !accessorClassPrefix) {
        @throw RLMException(@"Missing arguments");
    }
    if (!RLMIsKindOfClass(objectClass, RLMObjectBase.class)) {
        @throw RLMException(@"objectClass must derive from RLMObject or Object");
    }
    
    // create and register proxy class which derives from object class
    NSString *accessorClassName = [accessorClassPrefix stringByAppendingString:schema.className];
    Class accClass = objc_getClass(accessorClassName.UTF8String);
    if (!accClass) {
        accClass = objc_allocateClassPair(objectClass, accessorClassName.UTF8String, 0);
        objc_registerClassPair(accClass);
    }
    
    // override getters/setters for each propery
    for (unsigned int propNum = 0; propNum < schema.properties.count; propNum++) {
        RLMProperty *prop = schema.properties[propNum];
        RLMAccessorCode accessorCode = accessorCodeForType(prop.objcType, prop.type);
        if (prop.getterSel && getterGetter) {
            IMP getterImp = getterGetter(prop, accessorCode, objectClass);
            if (getterImp) {
                class_replaceMethod(accClass, prop.getterSel, getterImp, getterTypeStringForObjcCode(prop.objcType));
            }
        }
        if (prop.setterSel && setterGetter) {
            IMP setterImp = setterGetter(prop, accessorCode, objectClass);
            if (setterImp) {
                class_replaceMethod(accClass, prop.setterSel, setterImp, setterTypeStringForObjcCode(prop.objcType));
            }
        }
    }
    
    // implement className for accessor to return base className
    RLMReplaceClassNameMethod(accClass, schema.className);

    return accClass;
}

Class RLMAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema, NSString *prefix) {
    return RLMCreateAccessorClass(objectClass, schema, prefix, RLMAccessorGetter, RLMAccessorSetter);
}

Class RLMStandaloneAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema) {
    return RLMCreateAccessorClass(objectClass, schema, @"RLMStandalone_",
                                  RLMAccessorStandaloneGetter, RLMAccessorStandaloneSetter);
}

void RLMDynamicValidatedSet(RLMObjectBase *obj, NSString *propName, id val) {
    RLMObjectSchema *schema = obj->_objectSchema;
    RLMProperty *prop = schema[propName];
    if (!prop) {
        @throw RLMException(@"Invalid property name",
                            @{@"Property name:" : propName ?: @"nil",
                              @"Class name": obj->_objectSchema.className});
    }
    if (!RLMIsObjectValidForProperty(val, prop)) {
        @throw RLMException(@"Invalid property name",
                            @{@"Property name:" : propName ?: @"nil",
                              @"Value": val ? [val description] : @"nil"});
    }
    RLMDynamicSet(obj, prop, val, RLMCreationOptionsPromoteStandalone);
}

void RLMDynamicSet(__unsafe_unretained RLMObjectBase *const obj,
                   __unsafe_unretained RLMProperty *const prop,
                   __unsafe_unretained id const val,
                   RLMCreationOptions creationOptions) {
    NSUInteger col = prop.column;
    switch (accessorCodeForType(prop.objcType, prop.type)) {
        case RLMAccessorCodeByte:
        case RLMAccessorCodeShort:
        case RLMAccessorCodeInt:
        case RLMAccessorCodeLong:
        case RLMAccessorCodeLongLong:
            if (prop.isPrimary) {
                RLMSetValueUnique(obj, col, prop.name, [val longLongValue]);
            }
            else {
                RLMSetValue(obj, col, [val longLongValue]);
            }
            break;
        case RLMAccessorCodeFloat:
            RLMSetValue(obj, col, [val floatValue]);
            break;
        case RLMAccessorCodeDouble:
            RLMSetValue(obj, col, [val doubleValue]);
            break;
        case RLMAccessorCodeBool:
            RLMSetValue(obj, col, [val boolValue]);
            break;
        case RLMAccessorCodeString:
            if (prop.isPrimary) {
                RLMSetValueUnique(obj, col, prop.name, (NSString *)val);
            }
            else {
                RLMSetValue(obj, col, (NSString *)val);
            }
            break;
        case RLMAccessorCodeDate:
            RLMSetValue(obj, col, (NSDate *)val);
            break;
        case RLMAccessorCodeData:
            RLMSetValue(obj, col, (NSData *)val);
            break;
        case RLMAccessorCodeLink: {
            if (!val || val == NSNull.null) {
                RLMSetValue(obj, col, (RLMObjectBase *)nil, {});
            }
            else {
                RLMSetValue(obj, col, RLMGetLinkedObjectForValue(obj->_realm, prop.objectClassName, val, creationOptions), {});
            }
            break;
        }
        case RLMAccessorCodeArray:
            if (!val || val == NSNull.null) {
                RLMSetValue(obj, col, (id<NSFastEnumeration>)nil);
            }
            else {
                id<NSFastEnumeration> rawLinks = val;
                NSMutableArray *links = [NSMutableArray array];
                for (id rawLink in rawLinks) {
                    [links addObject:RLMGetLinkedObjectForValue(obj->_realm, prop.objectClassName, rawLink, creationOptions)];
                }
                RLMSetValue(obj, col, links);
            }
            break;
        case RLMAccessorCodeAny:
            RLMSetValue(obj, col, val);
            break;
    }
}

id RLMDynamicGet(__unsafe_unretained RLMObjectBase *obj, __unsafe_unretained NSString *propName) {
    RLMProperty *prop = obj->_objectSchema[propName];
    if (!prop) {
        @throw RLMException(@"Invalid property name",
                            @{@"Property name:": propName ?: @"nil",
                              @"Class name": obj->_objectSchema.className});
    }
    NSUInteger col = prop.column;
    switch (accessorCodeForType(prop.objcType, prop.type)) {
        case RLMAccessorCodeByte:     return @((char)RLMGetLong(obj, col));
        case RLMAccessorCodeShort:    return @((short)RLMGetLong(obj, col));
        case RLMAccessorCodeInt:      return @((int)RLMGetLong(obj, col));
        case RLMAccessorCodeLong:     return @((long)RLMGetLong(obj, col));
        case RLMAccessorCodeLongLong: return @(RLMGetLong(obj, col));
        case RLMAccessorCodeFloat:    return @(RLMGetFloat(obj, col));
        case RLMAccessorCodeDouble:   return @(RLMGetDouble(obj, col));
        case RLMAccessorCodeBool:     return @(RLMGetBool(obj, col));
        case RLMAccessorCodeString:   return RLMGetString(obj, col);
        case RLMAccessorCodeDate:     return RLMGetDate(obj, col);
        case RLMAccessorCodeData:     return RLMGetData(obj, col);
        case RLMAccessorCodeLink:     return RLMGetLink(obj, col, prop.objectClassName, {});
        case RLMAccessorCodeArray:    return RLMGetArray(obj, col, prop.objectClassName, {});
        case RLMAccessorCodeAny:      return RLMGetAnyProperty(obj, col);
    }
}
