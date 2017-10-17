////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

#import "RLMInteger_Private.h"

#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMRealm_Private.h"
#import "RLMUtil.hpp"

#import "object_schema.hpp"
#import "property.hpp"

template<typename T> static inline void verifyAttached(__unsafe_unretained T const obj) {
    if (!obj->_row.is_attached()) {
        @throw RLMException(@"Integer has been deleted or invalidated.");
    }
    [obj->_realm verifyThread];
}

template<typename T> static inline void verifyInWriteTransaction(__unsafe_unretained T const obj) {
    verifyAttached(obj);
    if (!obj->_realm.inWriteTransaction) {
        @throw RLMException(@"Attempting to modify integer outside of a write transaction - call beginWriteTransaction on an RLMRealm instance first.");
    }
}

namespace {

template <typename TableType>
void increment_int(TableType table, size_t colIndex, size_t rowIndex, NSInteger delta) {
    if (table->is_null(colIndex, rowIndex)) {
        @throw RLMException(@"Cannot increment a RLMInteger property whose value is nil. Set its value first.");
    }
    table->add_int(colIndex, rowIndex, delta);
}
    
}

@interface RLMInteger () {
@public
    size_t _colIndex;
}
@end

@implementation RLMInteger

// Unmanaged initializers
- (instancetype)init {
    return [self initWithValue:@0];
}

- (instancetype)initWithValue:(NSNumber<RLMInt> *)value {
    if (self = [super init]) {
        self.value = value;
    }
    return self;
}

// Managed initializer
- (instancetype)initWithObject:(RLMObjectBase *)obj property:(RLMProperty *)prop {
    if (self = [super init]) {
        self.object = obj;
        self.property = prop;
        _colIndex = obj->_info->objectSchema->persisted_properties[prop.index].table_column;
    }
    return self;
}

- (NSNumber<RLMInt> *)value {
    return RLMDynamicCast<NSNumber>(self.underlyingValue);
}

- (void)setValue:(NSNumber<RLMInt> *)value {
    self.underlyingValue = value;
}

- (void)incrementValueBy:(NSInteger)delta {
    RLMObjectBase *object = self.object;
    NSString *propertyName = self.property.name;
    if ((object && object->_realm) || object.isInvalidated) {
        // Object is managed.
        verifyInWriteTransaction(object);
        auto table = object->_row.get_table();
        size_t rowIndex = object->_row.get_index();
        if (RLMObservationInfo *info = RLMGetObservationInfo(object->_observationInfo, rowIndex, *object->_info)) {
            info->willChange(propertyName);
            increment_int(table, _colIndex, rowIndex, delta);
            info->didChange(propertyName);
        } else {
            increment_int(table, _colIndex, rowIndex, delta);
        }
    }
    else {
        // Object is unmanaged.
        if (!self.value) {
            @throw RLMException(@"Cannot increment a RLMInteger property whose value is nil. Set its value first.");
        }
        self.value = @(self.value.integerValue + delta);
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"RLMInteger (value: %@)", self.value ?: @"nil"];
}

@end
