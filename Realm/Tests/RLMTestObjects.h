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

#import <Realm/Realm.h>

#if __has_extension(objc_generics)
#define RLM_GENERIC_ARRAY(CLASS) RLMArray<CLASS *><CLASS>
#else
#define RLM_GENERIC_ARRAY(CLASS) RLMArray<CLASS>
#endif

#pragma mark - Abstract Objects
#pragma mark -

#pragma mark SingleTypeObjects

@interface StringObject : RLMObject

@property NSString *stringCol;

@end

@interface IntObject : RLMObject

@property int intCol;

@end

@interface RealmIntObject : RLMObject
@property RLMInteger *realmInt;
@end

@interface RealmNullableIntObject : RLMObject
@property RLMInteger *realmInt;
@end

@interface AllIntSizesObject : RLMObject
// int8_t not supported due to being ambiguous with BOOL

@property int16_t int16;
@property int32_t int32;
@property int64_t int64;

@end

@interface FloatObject : RLMObject

@property float floatCol;

@end

@interface DoubleObject : RLMObject

@property double doubleCol;

@end

@interface BoolObject : RLMObject

@property BOOL boolCol;

@end

@interface DateObject : RLMObject

@property NSDate *dateCol;

@end

@interface BinaryObject : RLMObject

@property NSData *binaryCol;

@end

@interface UTF8Object : RLMObject
@property NSString *柱колоéнǢкƱаم;
@end

@interface IndexedStringObject : RLMObject
@property NSString *stringCol;
@end

RLM_ARRAY_TYPE(StringObject)
RLM_ARRAY_TYPE(IntObject)

@interface LinkStringObject : RLMObject
@property StringObject *objectCol;
@end

@interface LinkIndexedStringObject : RLMObject
@property IndexedStringObject *objectCol;
@end

@interface RequiredPropertiesObject : RLMObject
@property NSString *stringCol;
@property NSData *binaryCol;
@property NSDate *dateCol;
@end

@interface IgnoredURLObject : RLMObject
@property NSString *name;
@property NSURL *url;
@end

#pragma mark AllTypesObject

@interface AllTypesObject : RLMObject

@property BOOL          boolCol;
@property int           intCol;
@property float         floatCol;
@property double        doubleCol;
@property NSString     *stringCol;
@property NSData       *binaryCol;
@property NSDate       *dateCol;
@property bool          cBoolCol;
@property int64_t     longCol;
@property StringObject *objectCol;
@property (readonly) RLMLinkingObjects *linkingObjectsCol;
@property RLMInteger *realmIntCol;
@property RLMInteger *realmNullableIntCol;
@end

RLM_ARRAY_TYPE(AllTypesObject)

@interface LinkToAllTypesObject : RLMObject
@property AllTypesObject *allTypesCol;
@end

@interface ArrayOfAllTypesObject : RLMObject
@property RLM_GENERIC_ARRAY(AllTypesObject) *array;
@end

@interface AllOptionalTypes : RLMObject
@property NSNumber<RLMInt> *intObj;
@property NSNumber<RLMFloat> *floatObj;
@property NSNumber<RLMDouble> *doubleObj;
@property NSNumber<RLMBool> *boolObj;
@property NSString *string;
@property NSData *data;
@property NSDate *date;
@end

@interface AllOptionalTypesPK : RLMObject
@property int pk;

@property NSNumber<RLMInt> *intObj;
@property NSNumber<RLMFloat> *floatObj;
@property NSNumber<RLMDouble> *doubleObj;
@property NSNumber<RLMBool> *boolObj;
@property NSString *string;
@property NSData *data;
@property NSDate *date;
@end

@interface AllPrimitiveArrays : RLMObject
@property RLMArray<RLMInt> *intObj;
@property RLMArray<RLMFloat> *floatObj;
@property RLMArray<RLMDouble> *doubleObj;
@property RLMArray<RLMBool> *boolObj;
@property RLMArray<RLMString> *stringObj;
@property RLMArray<RLMDate> *dateObj;
@property RLMArray<RLMData> *dataObj;
@end

@interface AllOptionalPrimitiveArrays : RLMObject
@property RLMArray<RLMInt> *intObj;
@property RLMArray<RLMFloat> *floatObj;
@property RLMArray<RLMDouble> *doubleObj;
@property RLMArray<RLMBool> *boolObj;
@property RLMArray<RLMString> *stringObj;
@property RLMArray<RLMDate> *dateObj;
@property RLMArray<RLMData> *dataObj;
@end

#pragma mark - Real Life Objects
#pragma mark -

#pragma mark EmployeeObject

@interface EmployeeObject : RLMObject

@property NSString *name;
@property int age;
@property BOOL hired;

@end

RLM_ARRAY_TYPE(EmployeeObject)

#pragma mark CompanyObject

@interface CompanyObject : RLMObject

@property NSString *name;
@property RLM_GENERIC_ARRAY(EmployeeObject) *employees;

@end

#pragma mark LinkToCompanyObject

@interface LinkToCompanyObject : RLMObject

@property CompanyObject *company;

@end

#pragma mark DogObject

@interface DogObject : RLMObject
@property NSString *dogName;
@property int age;
@property (readonly) RLMLinkingObjects *owners;
@end

RLM_ARRAY_TYPE(DogObject)

@interface DogArrayObject : RLMObject
@property RLM_GENERIC_ARRAY(DogObject) *dogs;
@end


#pragma mark OwnerObject

@interface OwnerObject : RLMObject

@property NSString *name;
@property DogObject *dog;

@end

#pragma mark - Specific Use Objects
#pragma mark -

#pragma mark CustomAccessorsObject

@interface CustomAccessorsObject : RLMObject

@property (getter = getThatName) NSString *name;
@property (setter = setTheInt:)  int age;

@end

#pragma mark BaseClassStringObject

@interface BaseClassStringObject : RLMObject

@property int intCol;

@end

@interface BaseClassStringObject ()

@property NSString *stringCol;

@end

#pragma mark CircleObject

@interface CircleObject : RLMObject

@property NSString *data;
@property CircleObject *next;

@end

RLM_ARRAY_TYPE(CircleObject);

#pragma mark CircleArrayObject

@interface CircleArrayObject : RLMObject
@property RLM_GENERIC_ARRAY(CircleObject) *circles;
@end

#pragma mark ArrayPropertyObject

@interface ArrayPropertyObject : RLMObject

@property NSString *name;
@property RLM_GENERIC_ARRAY(StringObject) *array;
@property RLM_GENERIC_ARRAY(IntObject) *intArray;

@end

#pragma mark DynamicObject

@interface DynamicObject : RLMObject

@property NSString *stringCol;
@property int intCol;

@end

#pragma mark AggregateObject

@interface AggregateObject : RLMObject

@property int     intCol;
@property float   floatCol;
@property double  doubleCol;
@property BOOL    boolCol;
@property NSDate *dateCol;

@end

RLM_ARRAY_TYPE(AggregateObject)
@interface AggregateArrayObject : RLMObject
@property RLMArray<AggregateObject *><AggregateObject> *array;
@end

#pragma mark PrimaryStringObject

@interface PrimaryStringObject : RLMObject
@property NSString *stringCol;
@property int intCol;
@end

@interface PrimaryNullableStringObject : RLMObject
@property NSString *stringCol;
@property int intCol;
@end

@interface PrimaryIntObject : RLMObject
@property int intCol;
@end
RLM_ARRAY_TYPE(PrimaryIntObject);

@interface PrimaryInt64Object : RLMObject
@property int64_t int64Col;
@end

@interface PrimaryNullableIntObject : RLMObject
@property NSNumber<RLMInt> *optIntCol;
@property int value;
@end

@interface ReadOnlyPropertyObject : RLMObject
@property (readonly) NSNumber *readOnlyUnsupportedProperty;
@property (readonly) int readOnlySupportedProperty;
@property (readonly) int readOnlyPropertyMadeReadWriteInClassExtension;
@end

#pragma mark IntegerArrayPropertyObject

@interface IntegerArrayPropertyObject : RLMObject

@property NSInteger number;
@property RLM_GENERIC_ARRAY(IntObject) *array;

@end

@interface NumberObject : RLMObject
@property NSNumber<RLMInt> *intObj;
@property NSNumber<RLMFloat> *floatObj;
@property NSNumber<RLMDouble> *doubleObj;
@property NSNumber<RLMBool> *boolObj;
@end

@interface NumberDefaultsObject : NumberObject
@end

@interface RequiredNumberObject : RLMObject
@property NSNumber<RLMInt> *intObj;
@property NSNumber<RLMFloat> *floatObj;
@property NSNumber<RLMDouble> *doubleObj;
@property NSNumber<RLMBool> *boolObj;
@end

#pragma mark CustomInitializerObject

@interface CustomInitializerObject : RLMObject
@property NSString *stringCol;
@end

#pragma mark AbstractObject

@interface AbstractObject : RLMObject
@end

#pragma mark PersonObject

@class PersonObject;
RLM_ARRAY_TYPE(PersonObject);

@interface PersonObject : RLMObject
@property NSString *name;
@property NSInteger age;
@property RLMArray<PersonObject> *children;
@property (readonly) RLMLinkingObjects *parents;
@end

@interface PrimaryEmployeeObject : EmployeeObject
@end
RLM_ARRAY_TYPE(PrimaryEmployeeObject);

@interface LinkToPrimaryEmployeeObject : RLMObject
@property PrimaryEmployeeObject *wrapped;
@end

@interface PrimaryCompanyObject : RLMObject
@property NSString *name;
@property RLM_GENERIC_ARRAY(PrimaryEmployeeObject) *employees;
@property PrimaryEmployeeObject *intern;
@property LinkToPrimaryEmployeeObject *wrappedIntern;
@end
RLM_ARRAY_TYPE(PrimaryCompanyObject);

@interface ArrayOfPrimaryCompanies : RLMObject
@property RLM_GENERIC_ARRAY(PrimaryCompanyObject) *companies;
@end

#pragma mark ComputedPropertyNotExplicitlyIgnoredObject

@interface ComputedPropertyNotExplicitlyIgnoredObject : RLMObject
@property NSString *_URLBacking;
@property NSURL *URL;
@end

#pragma mark FakeObject

@interface FakeObject : NSObject
@end
