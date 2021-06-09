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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Swift 5 considers NS_ENUM to be "open", meaning there could be values present
// other than the defined cases (which allows adding more cases later without
// it being a breaking change), while older versions consider it "closed".
#ifdef NS_CLOSED_ENUM
#define RLM_CLOSED_ENUM NS_CLOSED_ENUM
#else
#define RLM_CLOSED_ENUM NS_ENUM
#endif

#if __has_attribute(ns_error_domain) && (!defined(__cplusplus) || !__cplusplus || __cplusplus >= 201103L)
#define RLM_ERROR_ENUM(type, name, domain) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wignored-attributes\"") \
    NS_ENUM(type, __attribute__((ns_error_domain(domain))) name) \
    _Pragma("clang diagnostic pop")
#else
#define RLM_ERROR_ENUM(type, name, domain) NS_ENUM(type, name)
#endif

#if __has_attribute(objc_direct)
#define RLM_OBJC_DIRECT __attribute__((objc_direct))
#define RLM_DIRECT , direct
#else
#define RLM_OBJC_DIRECT
#define RLM_DIRECT
#endif

#pragma mark - Enums

/**
 `RLMPropertyType` is an enumeration describing all property types supported in Realm models.

 For more information, see [Realm Models](https://realm.io/docs/objc/latest/#models).
 */
typedef RLM_CLOSED_ENUM(int32_t, RLMPropertyType) {

#pragma mark - Primitive types

    /** Integers: `NSInteger`, `int`, `long`, `Int` (Swift) */
    RLMPropertyTypeInt    = 0,
    /** Booleans: `BOOL`, `bool`, `Bool` (Swift) */
    RLMPropertyTypeBool   = 1,
    /** Floating-point numbers: `float`, `Float` (Swift) */
    RLMPropertyTypeFloat  = 5,
    /** Double-precision floating-point numbers: `double`, `Double` (Swift) */
    RLMPropertyTypeDouble = 6,

#pragma mark - Object types

    /** Strings: `NSString`, `String` (Swift) */
    RLMPropertyTypeString = 2,
    /** Binary data: `NSData` */
    RLMPropertyTypeData   = 3,
    /**
     Any object: `id`.

     This property type is no longer supported for new models. However, old files
     with any-typed properties are still supported for migration purposes.
     */
    RLMPropertyTypeAny    = 9,
    /** Dates: `NSDate` */
    RLMPropertyTypeDate   = 4,

#pragma mark - Linked object types

    /** Realm model objects. See [Realm Models](https://realm.io/docs/objc/latest/#models) for more information. */
    RLMPropertyTypeObject = 7,
    /** Realm linking objects. See [Realm Models](https://realm.io/docs/objc/latest/#models) for more information. */
    RLMPropertyTypeLinkingObjects = 8,

    RLMPropertyTypeObjectId = 10,
    RLMPropertyTypeDecimal128 = 11,
};

/** An error domain identifying Realm-specific errors. */
extern NSString * const RLMErrorDomain;

/** An error domain identifying non-specific system errors. */
extern NSString * const RLMUnknownSystemErrorDomain;

/**
 `RLMError` is an enumeration representing all recoverable errors. It is associated with the
 Realm error domain specified in `RLMErrorDomain`.
 */
typedef RLM_ERROR_ENUM(NSInteger, RLMError, RLMErrorDomain) {
    /** Denotes a general error that occurred when trying to open a Realm. */
    RLMErrorFail                  = 1,

    /** Denotes a file I/O error that occurred when trying to open a Realm. */
    RLMErrorFileAccess            = 2,

    /**
     Denotes a file permission error that ocurred when trying to open a Realm.

     This error can occur if the user does not have permission to open or create
     the specified file in the specified access mode when opening a Realm.
     */
    RLMErrorFilePermissionDenied  = 3,

    /** Denotes an error where a file was to be written to disk, but another file with the same name already exists. */
    RLMErrorFileExists            = 4,

    /**
     Denotes an error that occurs if a file could not be found.

     This error may occur if a Realm file could not be found on disk when trying to open a
     Realm as read-only, or if the directory part of the specified path was not found when
     trying to write a copy.
     */
    RLMErrorFileNotFound          = 5,

    /**
     Denotes an error that occurs if a file format upgrade is required to open the file,
     but upgrades were explicitly disabled.
     */
    RLMErrorFileFormatUpgradeRequired = 6,

    /**
     Denotes an error that occurs if the database file is currently open in another
     process which cannot share with the current process due to an
     architecture mismatch.

     This error may occur if trying to share a Realm file between an i386 (32-bit) iOS
     Simulator and the Realm Browser application. In this case, please use the 64-bit
     version of the iOS Simulator.
     */
    RLMErrorIncompatibleLockFile  = 8,

    /** Denotes an error that occurs when there is insufficient available address space. */
    RLMErrorAddressSpaceExhausted = 9,

    /** Denotes an error that occurs if there is a schema version mismatch, so that a migration is required. */
    RLMErrorSchemaMismatch = 10,
    // Error code 11 is obsolete
    // RLMErrorIncompatibleSyncedFile = 11,
    /**
     Denotates an error where an operation was requested which cannot be performed on an open file.
     */
    RLMErrorAlreadyOpen = 12,

    /// Denotates an error where an input value was invalid.
    RLMErrorInvalidInput = 13,
};

#pragma mark - Constants

#pragma mark - Notification Constants

/**
 A notification indicating that changes were made to a Realm.
*/
typedef NSString * RLMNotification NS_EXTENSIBLE_STRING_ENUM;

/**
 This notification is posted when a write transaction has been committed to a Realm on a different thread for
 the same file.

 It is not posted if `autorefresh` is enabled, or if the Realm is refreshed before the notification has a chance
 to run.

 Realms with autorefresh disabled should normally install a handler for this notification which calls
 `-[RLMRealm refresh]` after doing some work. Refreshing the Realm is optional, but not refreshing the Realm may lead to
 large Realm files. This is because an extra copy of the data must be kept for the stale Realm.
 */
extern RLMNotification const RLMRealmRefreshRequiredNotification NS_SWIFT_NAME(RefreshRequired);

/**
 This notification is posted by a Realm when a write transaction has been
 committed to a Realm on a different thread for the same file.

 It is not posted if `-[RLMRealm autorefresh]` is enabled, or if the Realm is
 refreshed before the notification has a chance to run.

 Realms with autorefresh disabled should normally install a handler for this
 notification which calls `-[RLMRealm refresh]` after doing some work. Refreshing
 the Realm is optional, but not refreshing the Realm may lead to large Realm
 files. This is because Realm must keep an extra copy of the data for the stale
 Realm.
 */
extern RLMNotification const RLMRealmDidChangeNotification NS_SWIFT_NAME(DidChange);

#pragma mark - Error keys

/** Key to identify the associated backup Realm configuration in an error's `userInfo` dictionary */
extern NSString * const RLMBackupRealmConfigurationErrorKey;

#pragma mark - Other Constants

/** The schema version used for uninitialized Realms */
extern const uint64_t RLMNotVersioned;

/** The corresponding value is the name of an exception thrown by Realm. */
extern NSString * const RLMExceptionName;

/** The corresponding value is a Realm file version. */
extern NSString * const RLMRealmVersionKey;

/** The corresponding key is the version of the underlying database engine. */
extern NSString * const RLMRealmCoreVersionKey;

/** The corresponding key is the Realm invalidated property name. */
extern NSString * const RLMInvalidatedKey;

NS_ASSUME_NONNULL_END
