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

#import "RLMUtil.hpp"

#import "RLMArray_Private.hpp"
#import "RLMInteger.h"
#import "RLMListBase.h"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMProperty_Private.h"
#import "RLMSchema_Private.h"
#import "RLMSwiftSupport.h"

#import "shared_realm.hpp"

#import <realm/mixed.hpp>
#import <realm/table_view.hpp>

#include <sys/sysctl.h>
#include <sys/types.h>

#if !defined(REALM_COCOA_VERSION)
#import "RLMVersion.h"
#endif

static inline bool numberIsInteger(__unsafe_unretained NSNumber *const obj) {
    char data_type = [obj objCType][0];
    return data_type == *@encode(bool) ||
           data_type == *@encode(char) ||
           data_type == *@encode(short) ||
           data_type == *@encode(int) ||
           data_type == *@encode(long) ||
           data_type == *@encode(long long) ||
           data_type == *@encode(unsigned short) ||
           data_type == *@encode(unsigned int) ||
           data_type == *@encode(unsigned long) ||
           data_type == *@encode(unsigned long long);
}

static inline bool numberIsBool(__unsafe_unretained NSNumber *const obj) {
    // @encode(BOOL) is 'B' on iOS 64 and 'c'
    // objcType is always 'c'. Therefore compare to "c".
    if ([obj objCType][0] == 'c') {
        return true;
    }

    if (numberIsInteger(obj)) {
        int value = [obj intValue];
        return value == 0 || value == 1;
    }

    return false;
}

static inline bool numberIsFloat(__unsafe_unretained NSNumber *const obj) {
    char data_type = [obj objCType][0];
    return data_type == *@encode(float) ||
           data_type == *@encode(short) ||
           data_type == *@encode(int) ||
           data_type == *@encode(long) ||
           data_type == *@encode(long long) ||
           data_type == *@encode(unsigned short) ||
           data_type == *@encode(unsigned int) ||
           data_type == *@encode(unsigned long) ||
           data_type == *@encode(unsigned long long) ||
           // A double is like float if it fits within float bounds or is NaN.
           (data_type == *@encode(double) && (ABS([obj doubleValue]) <= FLT_MAX || isnan([obj doubleValue])));
}

static inline bool numberIsDouble(__unsafe_unretained NSNumber *const obj) {
    char data_type = [obj objCType][0];
    return data_type == *@encode(double) ||
           data_type == *@encode(float) ||
           data_type == *@encode(short) ||
           data_type == *@encode(int) ||
           data_type == *@encode(long) ||
           data_type == *@encode(long long) ||
           data_type == *@encode(unsigned short) ||
           data_type == *@encode(unsigned int) ||
           data_type == *@encode(unsigned long) ||
           data_type == *@encode(unsigned long long);
}

static inline RLMArray *asRLMArray(__unsafe_unretained id const value) {
    return RLMDynamicCast<RLMArray>(value) ?: RLMDynamicCast<RLMListBase>(value)._rlmArray;
}

static inline bool checkArrayType(__unsafe_unretained RLMArray *const array,
                                  RLMPropertyType type, bool optional,
                                  __unsafe_unretained NSString *const objectClassName) {
    return array.type == type && array.optional == optional
        && (type != RLMPropertyTypeObject || [array.objectClassName isEqualToString:objectClassName]);
}

BOOL RLMValidateValue(__unsafe_unretained id const value,
                      RLMPropertyType type, bool optional, bool array,
                      __unsafe_unretained NSString *const objectClassName) {
    if (optional && !RLMCoerceToNil(value)) {
        return YES;
    }
    if (array) {
        if (auto rlmArray = asRLMArray(value)) {
            return checkArrayType(rlmArray, type, optional, objectClassName);
        }
        if ([value conformsToProtocol:@protocol(NSFastEnumeration)]) {
            // check each element for compliance
            for (id el in (id<NSFastEnumeration>)value) {
                if (!RLMValidateValue(el, type, optional, false, objectClassName)) {
                    return NO;
                }
            }
            return YES;
        }
        if (!value || value == NSNull.null) {
            return YES;
        }
        return NO;
    }

    switch (type) {
        case RLMPropertyTypeString:
            return [value isKindOfClass:[NSString class]];
        case RLMPropertyTypeBool:
            if ([value isKindOfClass:[NSNumber class]]) {
                return numberIsBool(value);
            }
            return NO;
        case RLMPropertyTypeDate:
            return [value isKindOfClass:[NSDate class]];
        case RLMPropertyTypeInt:
            if ([value isKindOfClass:[RLMInteger class]]) {
                return YES;
            }
            if (NSNumber *number = RLMDynamicCast<NSNumber>(value)) {
                return numberIsInteger(number);
            }
            return NO;
        case RLMPropertyTypeFloat:
            if (NSNumber *number = RLMDynamicCast<NSNumber>(value)) {
                return numberIsFloat(number);
            }
            return NO;
        case RLMPropertyTypeDouble:
            if (NSNumber *number = RLMDynamicCast<NSNumber>(value)) {
                return numberIsDouble(number);
            }
            return NO;
        case RLMPropertyTypeData:
            return [value isKindOfClass:[NSData class]];
        case RLMPropertyTypeAny:
            return NO;
        case RLMPropertyTypeLinkingObjects:
            return YES;
        case RLMPropertyTypeObject: {
            // only NSNull, nil, or objects which derive from RLMObject and match the given
            // object class are valid
            RLMObjectBase *objBase = RLMDynamicCast<RLMObjectBase>(value);
            return objBase && [objBase->_objectSchema.className isEqualToString:objectClassName];
        }
    }
    @throw RLMException(@"Invalid RLMPropertyType specified");
}

void RLMThrowTypeError(__unsafe_unretained id const obj,
                       __unsafe_unretained RLMObjectSchema *const objectSchema,
                       __unsafe_unretained RLMProperty *const prop) {
    @throw RLMException(@"Invalid value '%@' of type '%@' for '%@%s'%s property '%@.%@'.",
                        obj, [obj class],
                        prop.objectClassName ?: RLMTypeToString(prop.type), prop.optional ? "?" : "",
                        prop.array ? " array" : "", objectSchema.className, prop.name);
}

void RLMValidateValueForProperty(__unsafe_unretained id const obj,
                                 __unsafe_unretained RLMObjectSchema *const objectSchema,
                                 __unsafe_unretained RLMProperty *const prop,
                                 bool validateObjects) {
    // This duplicates a lot of the checks in RLMIsObjectValidForProperty()
    // for the sake of more specific error messages
    if (prop.array) {
        // nil is considered equivalent to an empty array for historical reasons
        // since we don't support null arrays (only arrays containing null),
        // it's not worth the BC break to change this
        if (!obj || obj == NSNull.null) {
            return;
        }
        if (![obj conformsToProtocol:@protocol(NSFastEnumeration)]) {
            @throw RLMException(@"Invalid value (%@) for '%@%s' array property '%@.%@': value is not enumerable.",
                                obj, prop.objectClassName ?: RLMTypeToString(prop.type), prop.optional ? "?" : "",
                                objectSchema.className, prop.name);
        }
        if (!validateObjects && prop.type == RLMPropertyTypeObject) {
            return;
        }

        if (RLMArray *array = asRLMArray(obj)) {
            if (!checkArrayType(array, prop.type, prop.optional, prop.objectClassName)) {
                @throw RLMException(@"RLMArray<%@%s> does not match expected type '%@%s' for property '%@.%@'.",
                                    array.objectClassName ?: RLMTypeToString(array.type), array.optional ? "?" : "",
                                    prop.objectClassName ?: RLMTypeToString(prop.type), prop.optional ? "?" : "",
                                    objectSchema.className, prop.name);
            }
            return;
        }

        for (id value in obj) {
            if (!RLMValidateValue(value, prop.type, prop.optional, false, prop.objectClassName)) {
                RLMThrowTypeError(value, objectSchema, prop);
            }
        }
        return;
    }

    // For create() we want to skip the validation logic for objects because
    // we allow much fuzzier matching (any KVC-compatible object with at least
    // all the non-defaulted fields), and all the logic for that lives in the
    // object store rather than here
    if (prop.type == RLMPropertyTypeObject && !validateObjects) {
        return;
    }
    if (RLMIsObjectValidForProperty(obj, prop)) {
        return;
    }

    RLMThrowTypeError(obj, objectSchema, prop);
}

BOOL RLMIsObjectValidForProperty(__unsafe_unretained id const obj,
                                 __unsafe_unretained RLMProperty *const property) {
    return RLMValidateValue(obj, property.type, property.optional, property.array, property.objectClassName);
}

NSDictionary *RLMDefaultValuesForObjectSchema(__unsafe_unretained RLMObjectSchema *const objectSchema) {
    if (!objectSchema.isSwiftClass) {
        return [objectSchema.objectClass defaultPropertyValues];
    }

    NSMutableDictionary *defaults = nil;
    if ([objectSchema.objectClass isSubclassOfClass:RLMObject.class]) {
        defaults = [NSMutableDictionary dictionaryWithDictionary:[objectSchema.objectClass defaultPropertyValues]];
    }
    else {
        defaults = [NSMutableDictionary dictionary];
    }
    RLMObject *defaultObject = [[objectSchema.objectClass alloc] init];
    for (RLMProperty *prop in objectSchema.properties) {
        if (!defaults[prop.name] && defaultObject[prop.name]) {
            defaults[prop.name] = defaultObject[prop.name];
        }
    }
    return defaults;
}

static NSException *RLMException(NSString *reason, NSDictionary *additionalUserInfo) {
    NSMutableDictionary *userInfo = @{RLMRealmVersionKey: REALM_COCOA_VERSION,
                                      RLMRealmCoreVersionKey: @REALM_VERSION}.mutableCopy;
    if (additionalUserInfo != nil) {
        [userInfo addEntriesFromDictionary:additionalUserInfo];
    }
    NSException *e = [NSException exceptionWithName:RLMExceptionName
                                             reason:reason
                                           userInfo:userInfo];
    return e;
}

NSException *RLMException(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSException *e = RLMException([[NSString alloc] initWithFormat:fmt arguments:args], @{});
    va_end(args);
    return e;
}

NSException *RLMException(std::exception const& exception) {
    return RLMException(@"%s", exception.what());
}

NSError *RLMMakeError(RLMError code, std::exception const& exception) {
    return [NSError errorWithDomain:RLMErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what()),
                                      @"Error Code": @(code)}];
}

NSError *RLMMakeError(RLMError code, const realm::util::File::AccessError& exception) {
    return [NSError errorWithDomain:RLMErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what()),
                                      NSFilePathErrorKey: @(exception.get_path().c_str()),
                                      @"Error Code": @(code)}];
}

NSError *RLMMakeError(RLMError code, const realm::RealmFileException& exception) {
    NSString *underlying = @(exception.underlying().c_str());
    return [NSError errorWithDomain:RLMErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what()),
                                      NSFilePathErrorKey: @(exception.path().c_str()),
                                      @"Error Code": @(code),
                                      @"Underlying": underlying.length == 0 ? @"n/a" : underlying}];
}

NSError *RLMMakeError(std::system_error const& exception) {
    BOOL isGenericCategoryError = (exception.code().category() == std::generic_category());
    NSString *category = @(exception.code().category().name());
    NSString *errorDomain = isGenericCategoryError ? NSPOSIXErrorDomain : RLMUnknownSystemErrorDomain;

    return [NSError errorWithDomain:errorDomain
                               code:exception.code().value()
                           userInfo:@{NSLocalizedDescriptionKey: @(exception.what()),
                                      @"Error Code": @(exception.code().value()),
                                      @"Category": category}];
}

void RLMSetErrorOrThrow(NSError *error, NSError **outError) {
    if (outError) {
        *outError = error;
    }
    else {
        NSString *msg = error.localizedDescription;
        if (error.userInfo[NSFilePathErrorKey]) {
            msg = [NSString stringWithFormat:@"%@: %@", error.userInfo[NSFilePathErrorKey], error.localizedDescription];
        }
        @throw RLMException(msg, @{NSUnderlyingErrorKey: error});
    }
}

BOOL RLMIsDebuggerAttached()
{
    int name[] = {
        CTL_KERN,
        KERN_PROC,
        KERN_PROC_PID,
        getpid()
    };

    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    if (sysctl(name, sizeof(name)/sizeof(name[0]), &info, &info_size, NULL, 0) == -1) {
        NSLog(@"sysctl() failed: %s", strerror(errno));
        return false;
    }

    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

BOOL RLMIsRunningInPlayground() {
    return [[NSBundle mainBundle].bundleIdentifier hasPrefix:@"com.apple.dt.playground."];
}

id RLMMixedToObjc(realm::Mixed const& mixed) {
    switch (mixed.get_type()) {
        case realm::type_String:
            return RLMStringDataToNSString(mixed.get_string());
        case realm::type_Int:
            return @(mixed.get_int());
        case realm::type_Float:
            return @(mixed.get_float());
        case realm::type_Double:
            return @(mixed.get_double());
        case realm::type_Bool:
            return @(mixed.get_bool());
        case realm::type_Timestamp:
            return RLMTimestampToNSDate(mixed.get_timestamp());
        case realm::type_Binary:
            return RLMBinaryDataToNSData(mixed.get_binary());
        case realm::type_Link:
        case realm::type_LinkList:
        default:
            @throw RLMException(@"Invalid data type for RLMPropertyTypeAny property.");
    }
}

NSString *RLMDefaultDirectoryForBundleIdentifier(NSString *bundleIdentifier) {
#if TARGET_OS_TV
    (void)bundleIdentifier;
    // tvOS prohibits writing to the Documents directory, so we use the Library/Caches directory instead.
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
#elif TARGET_OS_IPHONE
    (void)bundleIdentifier;
    // On iOS the Documents directory isn't user-visible, so put files there
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
#else
    // On OS X it is, so put files in Application Support. If we aren't running
    // in a sandbox, put it in a subdirectory based on the bundle identifier
    // to avoid accidentally sharing files between applications
    NSString *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
    if (![[NSProcessInfo processInfo] environment][@"APP_SANDBOX_CONTAINER_ID"]) {
        if (!bundleIdentifier) {
            bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        }
        if (!bundleIdentifier) {
            bundleIdentifier = [NSBundle mainBundle].executablePath.lastPathComponent;
        }

        path = [path stringByAppendingPathComponent:bundleIdentifier];

        // create directory
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return path;
#endif
}
