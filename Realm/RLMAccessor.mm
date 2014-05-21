////////////////////////////////////////////////////////////////////////////
//
// TIGHTDB CONFIDENTIAL
// __________________
//
//  [2011] - [2014] TightDB Inc
//  All Rights Reserved.
//
// NOTICE:  All information contained herein is, and remains
// the property of TightDB Incorporated and its suppliers,
// if any.  The intellectual and technical concepts contained
// herein are proprietary to TightDB Incorporated
// and its suppliers and may be covered by U.S. and Foreign Patents,
// patents in process, and are protected by trade secret or copyright law.
// Dissemination of this information or reproduction of this material
// is strictly forbidden unless prior written permission is obtained
// from TightDB Incorporated.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMAccessor.h"
#import "RLMUtil.h"
#import "RLMProperty_Private.h"
#import "RLMObject.h"
#import "RLMObjectSchema.h"
#import "RLMObjectStore.h"
#import "NSData+RLMGetBinaryData.h"

#import <objc/runtime.h>

static NSMapTable *s_accessorCache;
static NSMapTable *s_readOnlyAccessorCache;
static NSMapTable *s_invalidAccessorCache;
static NSMapTable *s_insertionAccessorCache;

// initialize statics
void RLMAccessorCacheInitialize() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_accessorCache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaquePersonality
                                                valueOptions:NSPointerFunctionsOpaquePersonality];
        s_invalidAccessorCache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaquePersonality
                                                       valueOptions:NSPointerFunctionsOpaquePersonality];
        s_readOnlyAccessorCache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaquePersonality
                                                        valueOptions:NSPointerFunctionsOpaquePersonality];
        s_insertionAccessorCache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaquePersonality
                                                         valueOptions:NSPointerFunctionsOpaquePersonality];
    });
}

// dynamic getter with column closure
IMP RLMAccessorGetter(NSUInteger col, char accessorCode, NSString *) {
    switch (accessorCode) {
        case 'i':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return (int)obj.backingTable->get_int(col, obj.objectIndex);
            });
        case 'l':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return obj.backingTable->get_int(col, obj.objectIndex);
            });
        case 'f':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return obj.backingTable->get_float(col, obj.objectIndex);
            });
        case 'd':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return obj.backingTable->get_double(col, obj.objectIndex);
            });
        case 'B':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return obj.backingTable->get_bool(col, obj.objectIndex);
            });
        case 'c':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return obj.backingTable->get_bool(col, obj.objectIndex);
            });
        case 's':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                tightdb::StringData strData = obj.backingTable->get_string(col, obj.objectIndex);
                return [[NSString alloc] initWithBytes:strData.data()
                                                length:strData.size()
                                              encoding:NSUTF8StringEncoding];
            });
        case 'a':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                tightdb::DateTime dt = obj.backingTable->get_datetime(col, obj.objectIndex);
                return [NSDate dateWithTimeIntervalSince1970:dt.get_datetime()];
            });
        case 'e':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                tightdb::BinaryData data = obj.backingTable->get_binary(col, obj.objectIndex);
                return [NSData dataWithBytes:data.data() length:data.size()];
            });
        case 'k':
//            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
//                NSUInteger index = obj.backingTable->get_link(col, obj.objectIndex);
//                return RLMCreateObjectAccessor(obj.realm, objectClassName, index);
//            });
            @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                           reason:@"Links not yet supported" userInfo:nil];
        case '@':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                return RLMGetAnyProperty(*obj.backingTable, obj.objectIndex, col);
            });
        case 't':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj) {
                RLMArray *array = obj[col];
                return array;
            });
        default:
            @throw [NSException exceptionWithName:@"RLMException" reason:@"Invalid accessor code" userInfo:nil];
    }
}

// dynamic setter with column closure
IMP RLMAccessorSetter(NSUInteger col, char accessorCode) {
    switch (accessorCode) {
        case 'i':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, int val) {
                obj.backingTable->set_int(col, obj.objectIndex, val);
            });
        case 'l':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, long val) {
                obj.backingTable->set_int(col, obj.objectIndex, val);
            });
        case 'f':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, float val) {
                obj.backingTable->set_float(col, obj.objectIndex, val);
            });
        case 'd':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, double val) {
                obj.backingTable->set_double(col, obj.objectIndex, val);
            });
        case 'B':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, bool val) {
                obj.backingTable->set_bool(col, obj.objectIndex, val);
            });
        case 'c':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, BOOL val) {
                obj.backingTable->set_bool(col, obj.objectIndex, val);
            });
        case 's':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, NSString *val) {
                tightdb::StringData strData = tightdb::StringData(val.UTF8String, val.length);
                obj.backingTable->set_string(col, obj.objectIndex, strData);
            });
        case 'a':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, NSDate *date) {
                std::time_t time = date.timeIntervalSince1970;
                obj.backingTable->set_datetime(col, obj.objectIndex, tightdb::DateTime(time));
            });
        case 'e':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, NSData *data) {
                obj.backingTable->set_binary(col, obj.objectIndex, data.rlmBinaryData);
            });
        case 'k':
//            return imp_implementationWithBlock(^(id<RLMAccessor> obj, RLMObject *link) {
//                if (!link || link.class == NSNull.class) {
//                    // if null
//                    obj.backingTable->nullify_link(col, obj.objectIndex);
//                }
//                else {
//                    // add to Realm if not it it.
//                    if (link.realm != obj.realm) {
//                        [obj.realm addObject:link];
//                    }
//                    // set link
//                    obj.backingTable->set_link(col, obj.objectIndex, link.objectIndex);
//                }
//            });
            @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                           reason:@"Links not yet supported" userInfo:nil];
        case '@':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, id val) {
                RLMSetAnyProperty(*obj.backingTable, obj.objectIndex, col, val);
            });
        case 't':
            return imp_implementationWithBlock(^(id<RLMAccessor> obj, id val) {
                obj[col] = val;
            });
        default:
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Invalid accessor code"
                                         userInfo:nil];
    }
}


// setter which throws exception
IMP RLMAccessorExceptionSetter(NSUInteger, char accessorCode, NSString *message) {
    switch (accessorCode) {
        case 'i':
            return imp_implementationWithBlock(^(id<RLMAccessor>, int) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        case 'l':
            return imp_implementationWithBlock(^(id<RLMAccessor>, long) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        case 'f':
            return imp_implementationWithBlock(^(id<RLMAccessor>, float) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        case 'd':
            return imp_implementationWithBlock(^(id<RLMAccessor>, double) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        case 'B':
            return imp_implementationWithBlock(^(id<RLMAccessor>, bool) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        case 'c':
            return imp_implementationWithBlock(^(id<RLMAccessor>, BOOL) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        case 's':
        case 'a':
        case 'k':
        case 'e':
        case '@':
        case 't':
            return imp_implementationWithBlock(^(id<RLMAccessor>, id) {
                @throw [NSException exceptionWithName:@"RLMException" reason:message userInfo:nil]; });
        default:
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Invalid accessor code"
                                         userInfo:nil];
    }
}

// getter for invalid objects
NSString *const c_invalidObjectMessage = @"Object is no longer valid.";
IMP RLMAccessorInvalidGetter(NSUInteger, char, NSString *) {
    return imp_implementationWithBlock(^(id<RLMAccessor>) {
        @throw [NSException exceptionWithName:@"RLMException" reason:c_invalidObjectMessage userInfo:nil];
    });
}

// setter for invalid objects
IMP RLMAccessorInvalidSetter(NSUInteger col, char accessorCode) {
    return RLMAccessorExceptionSetter(col, accessorCode, c_invalidObjectMessage);
}

// setter for readonly objects
IMP RLMAccessorReadOnlySetter(NSUInteger col, char accessorCode) {
    return RLMAccessorExceptionSetter(col, accessorCode, @"Trying to set a property on a read-only object.");
}


// macros/helpers to generate objc type strings for registering methods
#define GETTER_TYPES(C) C ":@"
#define SETTER_TYPES(C) "v:@" C

// getter type strings
// NOTE: this typecode is really the the first charachter of the objc/runtime.h type
//       the @ type maps to multiple tightdb types (string, date, array, mixed, any which are id in objc)
const char * getterTypeStringForObjcCode(char code) {
    switch (code) {
        case 'i': return GETTER_TYPES("i");
        case 'l': return GETTER_TYPES("l");
        case 'f': return GETTER_TYPES("f");
        case 'd': return GETTER_TYPES("d");
        case 'B': return GETTER_TYPES("B");
        case 'c': return GETTER_TYPES("c");
        case '@': return GETTER_TYPES("@");
        default: @throw [NSException exceptionWithName:@"RLMException" reason:@"Invalid accessor code" userInfo:nil];
    }
}

// setter type strings
// NOTE: this typecode is really the the first charachter of the objc/runtime.h type
//       the @ type maps to multiple tightdb types (string, date, array, mixed, any which are id in objc)
const char * setterTypeStringForObjcCode(char code) {
    switch (code) {
        case 'i': return SETTER_TYPES("i");
        case 'l': return SETTER_TYPES("l");
        case 'f': return SETTER_TYPES("f");
        case 'd': return SETTER_TYPES("d");
        case 'B': return SETTER_TYPES("B");
        case 'c': return SETTER_TYPES("c");
        case '@': return SETTER_TYPES("@");
        default: @throw [NSException exceptionWithName:@"RLMException" reason:@"Invalid accessor code" userInfo:nil];
    }
}

// get accessor lookup code based on objc type and rlm type
char accessorCodeForType(char objcTypeCode, RLMPropertyType rlmType) {
    switch (objcTypeCode) {
        case 'q': return 'l';   // long long same as long
        case '@':               // custom accessors for strings and subtables
            switch (rlmType) {  // custom accessor codes for types that map to objc objects
                case RLMPropertyTypeObject: return 'k';
                case RLMPropertyTypeString: return 's';
                case RLMPropertyTypeArray: return 't';
                case RLMPropertyTypeDate: return 'a';
                case RLMPropertyTypeData: return 'e';
                case RLMPropertyTypeAny: return '@';
                default: @throw [NSException exceptionWithName:@"RLMException" reason:@"Invalid type for objc typecode" userInfo:nil];
            }
        default:
            return objcTypeCode;
    }
}

Class RLMCreateAccessorClass(Class objectClass,
                             RLMObjectSchema *schema,
                             NSString *accessorClassPrefix,
                             IMP (*getterGetter)(NSUInteger, char, NSString *),
                             IMP (*setterGetter)(NSUInteger, char),
                             NSMapTable *cache) {
    // return cached
    if (Class cls = [cache objectForKey:objectClass]) {
        return cls;
    }
    
    // throw if no schema, prefix, or object class
    if (!objectClass || !schema || !accessorClassPrefix) {
        @throw [NSException exceptionWithName:@"RLMInternalException" reason:@"Missing arguments" userInfo:nil];
    }
    
    // if objectClass is a dicrect RLMSubclass use it, otherwise use proxy class
    if (class_getSuperclass(objectClass) != RLMObject.class) {
        @throw [NSException exceptionWithName:@"RLMException" reason:@"objectClass must derive from RLMObject" userInfo:nil];
    }
    
    // create and register proxy class which derives from object class
    NSString *objectClassName = NSStringFromClass(objectClass);
    NSString *accessorClassName = [accessorClassPrefix stringByAppendingString:objectClassName];
    Class accClass = objc_allocateClassPair(objectClass, accessorClassName.UTF8String, 0);
    objc_registerClassPair(accClass);
    
    // override getters/setters for each propery
    for (unsigned int propNum = 0; propNum < schema.properties.count; propNum++) {
        RLMProperty *prop = schema.properties[propNum];
        char accessorCode = accessorCodeForType(prop.objcType, prop.type);
        if (getterGetter) {
            SEL getterSel = NSSelectorFromString(prop.getterName);
            IMP getterImp = getterGetter(prop.column, accessorCode, prop.objectClassName);
            class_replaceMethod(accClass, getterSel, getterImp, getterTypeStringForObjcCode(prop.objcType));
        }
        if (setterGetter) {
            SEL setterSel = NSSelectorFromString(prop.setterName);
            IMP setterImp = setterGetter(prop.column, accessorCode);
            class_replaceMethod(accClass, setterSel, setterImp, setterTypeStringForObjcCode(prop.objcType));
        }
    }
    
    // cache and return
    [cache setObject:accClass forKey:objectClass];
    return accClass;
}

Class RLMAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema) {
    return RLMCreateAccessorClass(objectClass, schema, @"RLMAccessor_",
                                  RLMAccessorGetter, RLMAccessorSetter, s_accessorCache);
}

Class RLMReadOnlyAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema) {
    return RLMCreateAccessorClass(objectClass, schema, @"RLMReadOnly_",
                                  RLMAccessorGetter, RLMAccessorReadOnlySetter, s_readOnlyAccessorCache);
}

Class RLMInvalidAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema) {
    return RLMCreateAccessorClass(objectClass, schema, @"RLMInvalid_",
                                  RLMAccessorInvalidGetter, RLMAccessorInvalidSetter, s_invalidAccessorCache);
}

Class RLMInsertionAccessorClassForObjectClass(Class objectClass, RLMObjectSchema *schema) {
    return RLMCreateAccessorClass(objectClass, schema, @"RLMInserter_",
                                  NULL, RLMAccessorSetter, s_insertionAccessorCache);
}


// Dynamic accessor name for a classname
inline NSString *RLMDynamicClassName(NSString *className, NSUInteger version) {
    return [NSString stringWithFormat:@"RLMDynamic_%@_Version_%lu", className, (unsigned long)version];
}

// Get or generate a dynamic class from a table and classname
Class RLMDynamicClassForSchema(RLMObjectSchema *schema, NSUInteger version) {
    // generate our new classname, and check if it exists
    NSString *dynamicName = RLMDynamicClassName(schema.className, version);
    Class dynamicClass = NSClassFromString(dynamicName);
    if (!dynamicClass) {
        // if we don't have this class, create a subclass or RLMObject
        dynamicClass = objc_allocateClassPair(RLMObject.class, dynamicName.UTF8String, 0);
        objc_registerClassPair(dynamicClass);
    }
    return dynamicClass;
}

