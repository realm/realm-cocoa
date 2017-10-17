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

#import <Realm/RLMConstants.h>
#import <Realm/RLMOptionalBase_Private.h>
#import <objc/runtime.h>

#import <realm/array.hpp>
#import <realm/binary_data.hpp>
#import <realm/string_data.hpp>
#import <realm/timestamp.hpp>
#import <realm/util/file.hpp>

namespace realm {
    class Mixed;
}

@class RLMObjectSchema;
@class RLMProperty;

namespace realm {
    class RealmFileException;
}

__attribute__((format(NSString, 1, 2)))
NSException *RLMException(NSString *fmt, ...);
NSException *RLMException(std::exception const& exception);

NSError *RLMMakeError(RLMError code, std::exception const& exception);
NSError *RLMMakeError(RLMError code, const realm::util::File::AccessError&);
NSError *RLMMakeError(RLMError code, const realm::RealmFileException&);
NSError *RLMMakeError(std::system_error const& exception);

void RLMSetErrorOrThrow(NSError *error, NSError **outError);

// returns if the object can be inserted as the given type
BOOL RLMIsObjectValidForProperty(id obj, RLMProperty *prop);
// throw an exception if the object is not a valid value for the property
void RLMValidateValueForProperty(id obj, RLMObjectSchema *objectSchema,
                                 RLMProperty *prop, bool validateObjects=false);
BOOL RLMValidateValue(id value, RLMPropertyType type, bool optional, bool array,
                      NSString *objectClassName);

void RLMThrowTypeError(id obj, RLMObjectSchema *objectSchema, RLMProperty *prop);

// gets default values for the given schema (+defaultPropertyValues)
// merges with native property defaults if Swift class
NSDictionary *RLMDefaultValuesForObjectSchema(RLMObjectSchema *objectSchema);

BOOL RLMIsDebuggerAttached();
BOOL RLMIsRunningInPlayground();

// C version of isKindOfClass
static inline BOOL RLMIsKindOfClass(Class class1, Class class2) {
    while (class1) {
        if (class1 == class2) return YES;
        class1 = class_getSuperclass(class1);
    }
    return NO;
}

template<typename T>
static inline T *RLMDynamicCast(__unsafe_unretained id obj) {
    if ([obj isKindOfClass:[T class]]) {
        return obj;
    }
    return nil;
}

template<typename T>
static inline T RLMCoerceToNil(__unsafe_unretained T obj) {
    if (static_cast<id>(obj) == NSNull.null) {
        return nil;
    }
    else if (__unsafe_unretained auto optional = RLMDynamicCast<RLMOptionalBase>(obj)) {
        return RLMCoerceToNil(optional.underlyingValue);
    }
    return obj;
}

// String conversion utilities
static inline NSString * RLMStringDataToNSString(realm::StringData stringData) {
    static_assert(sizeof(NSUInteger) >= sizeof(size_t),
                  "Need runtime overflow check for size_t to NSUInteger conversion");
    if (stringData.is_null()) {
        return nil;
    }
    else {
        return [[NSString alloc] initWithBytes:stringData.data()
                                        length:stringData.size()
                                      encoding:NSUTF8StringEncoding];
    }
}

static inline realm::StringData RLMStringDataWithNSString(__unsafe_unretained NSString *const string) {
    static_assert(sizeof(size_t) >= sizeof(NSUInteger),
                  "Need runtime overflow check for NSUInteger to size_t conversion");
    return realm::StringData(string.UTF8String,
                             [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

// Binary conversion utilities
static inline NSData *RLMBinaryDataToNSData(realm::BinaryData binaryData) {
    return binaryData ? [NSData dataWithBytes:binaryData.data() length:binaryData.size()] : nil;
}

static inline realm::BinaryData RLMBinaryDataForNSData(__unsafe_unretained NSData *const data) {
    // this is necessary to ensure that the empty NSData isn't treated by core as the null realm::BinaryData
    // because data.bytes == 0 when data.length == 0
    // the casting bit ensures that we create a data with a non-null pointer
    auto bytes = static_cast<const char *>(data.bytes) ?: static_cast<char *>((__bridge void *)data);
    return realm::BinaryData(bytes, data.length);
}

// Date conversion utilities
// These use the reference date and shift the seconds rather than just getting
// the time interval since the epoch directly to avoid losing sub-second precision
static inline NSDate *RLMTimestampToNSDate(realm::Timestamp ts) NS_RETURNS_RETAINED {
    if (ts.is_null())
        return nil;
    auto timeInterval = ts.get_seconds() - NSTimeIntervalSince1970 + ts.get_nanoseconds() / 1'000'000'000.0;
    return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:timeInterval];
}

static inline realm::Timestamp RLMTimestampForNSDate(__unsafe_unretained NSDate *const date) {
    if (!date)
        return {};
    auto timeInterval = date.timeIntervalSinceReferenceDate;
    if (isnan(timeInterval))
        return {0, 0}; // Arbitrary choice

    // Clamp dates that we can't represent as a Timestamp to the maximum value
    if (timeInterval >= std::numeric_limits<int64_t>::max() - NSTimeIntervalSince1970)
        return {std::numeric_limits<int64_t>::max(), 1'000'000'000 - 1};
    if (timeInterval - NSTimeIntervalSince1970 < std::numeric_limits<int64_t>::min())
        return {std::numeric_limits<int64_t>::min(), -1'000'000'000 + 1};

    auto seconds = static_cast<int64_t>(timeInterval);
    auto nanoseconds = static_cast<int32_t>((timeInterval - seconds) * 1'000'000'000.0);
    seconds += static_cast<int64_t>(NSTimeIntervalSince1970);

    // Seconds and nanoseconds have to have the same sign
    if (nanoseconds < 0 && seconds > 0) {
        nanoseconds += 1'000'000'000;
        --seconds;
    }
    return {seconds, nanoseconds};
}

static inline NSUInteger RLMConvertNotFound(size_t index) {
    return index == realm::not_found ? NSNotFound : index;
}

id RLMMixedToObjc(realm::Mixed const& value);

// Given a bundle identifier, return the base directory on the disk within which Realm database and support files should
// be stored.
NSString *RLMDefaultDirectoryForBundleIdentifier(NSString *bundleIdentifier);
