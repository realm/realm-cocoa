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

/**
 Attributes which can be returned when implementing attributesForProperty:
 */

typedef NS_ENUM(NSUInteger, RLMPropertyAttributes) {
/**
 Create an index for this property for improved search performance.
 */
    RLMPropertyAttributeIndexed = 1 << 2,
    
/**
 Store this property inline (de-normalization) which in some cases can improve performance. Setting this
 attribute will result in objects being copied (rather than linked) when setting this property.
 */
//    RLMPropertyAttributeInlined = 1 << 3,
    
/**
 The value for a property with this attribute must be unique across all objects of this type. An exception
 will be thrown when setting a property with this attribute to a non-unique value.
 */
//    RLMPropertyAttributeUnique = 1 << 4,
    
/**
 This property value must be set before the object can be added to a Realm. If not set an
 exception will be thrown if no default value for this property is specified. If a default
 value is specified it is set upon insertion into a Realm
 
 @see [RLMObject defaultPropertyValues]
 */
//    RLMPropertyAttributeRequired = 1 << 5,
    
/**
 When a parent object is deleted or a child property is nullified nothing is done.
 This is the default delete rule.
 
 Set this attribute on RLMPropertyTypeObject or RLMPropertyTypeArray properties
 to customize the properties’ delete rule. This rule is mutually exclusive with
 `RLMPropertyAttributeDeleteIfOnlyOwner` and `RLMPropertyAttributeDeleteAlways`.
 */
//    RLMPropertyAttributeDeleteNever = 0,
    
/**
 Delete a child object (or object in an RLMArray) when the parent is deleted or the object is
 nullified only if no other objects in the realm reference the object.
 
 Set this attribute on RLMPropertyTypeObject or RLMPropertyTypeArray properties
 to customize the properties’ delete rule. This rule is mutually exclusive with
 `RLMPropertyAttributeDeleteNever` and `RLMPropertyAttributeDeleteAlways`.
 */
//    RLMPropertyAttributeDeleteIfOnlyOwner = 1 << 0,
    
/**
 Always delete a child object or object in a child array when the parent is deleted or the
 reference in nullified. If other objects reference the same child object those references are
 nullified.
 
 Set this attribute on RLMPropertyTypeObject or RLMPropertyTypeArray properties
 to customize the properties’ delete rule. This rule is mutually exclusive with
 `RLMPropertyAttributeDeleteNever` and `RLMPropertyAttributeDeleteIfOnlyOwner`.
 */
//    RLMPropertyAttributeDeleteAlways = 1 << 1
};

// Make sure numbers match those in <tightdb/data_type.hpp>
typedef NS_ENUM(int32_t, RLMPropertyType) {    
    // Primitive types
    RLMPropertyTypeInt      = 0,
    RLMPropertyTypeBool     = 1,
    RLMPropertyTypeFloat    = 9,
    RLMPropertyTypeDouble   = 10,
    
    // Object types
    RLMPropertyTypeString   = 2,
    RLMPropertyTypeData     = 4,
    RLMPropertyTypeAny      = 6,
    RLMPropertyTypeDate     = 7,
    
    // Array/Linked object types
    RLMPropertyTypeObject   = 12,
    RLMPropertyTypeArray    = 13,
};


typedef NS_ENUM(NSInteger, RLMSortOrder) {
    RLMSortOrderAscending =  0,
    RLMSortOrderDescending =  1,
};

// Posted by RLMRealm when it changes, that is when a table is
// added, removed, or changed in any way.

extern NSString *const RLMRealmDidChangeNotification;

typedef NS_ENUM(NSInteger, RLMError) {
    RLMErrorOk                    = 0,
    RLMErrorFail                  = 1,
    RLMErrorFailRdOnly            = 2,
    RLMErrorFileAccessError       = 3,
    RLMErrorFilePermissionDenied  = 4,
    RLMErrorFileExists            = 5,
    RLMErrorFileNotFound          = 6,
    RLMErrorRollback              = 7,
    RLMErrorInvalidDatabase       = 8,
    RLMErrorTableNotFound         = 9,
    RLMErrorStaleLockFile         = 10,
    RLMErrorLockFileButNoData     = 11
};
