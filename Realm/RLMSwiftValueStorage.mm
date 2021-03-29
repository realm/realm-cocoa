////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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

#import "RLMSwiftValueStorage.h"

#import "RLMAccessor.hpp"
#import "RLMObject_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMProperty_Private.hpp"
#import "RLMUtil.hpp"
#import "RLMValue.h"

#import <realm/object-store/object.hpp>

@implementation RLMSwiftValueStorage {
    id<RLMValue> _backingValue;
    __weak RLMObjectBase *_parent;
    NSString *_propertyName;
    BOOL _managed;
}

- (void)setValue:(id<RLMValue>)value {
    @autoreleasepool {
        if (_managed) {
            try {
                RLMAccessorContext ctx(*_parent->_info);
                auto object = realm::Object(_parent->_realm->_realm,
                                            *_parent->_info->objectSchema, _parent->_row);
                object.set_property_value(ctx, _propertyName.UTF8String, value);
            }
            catch (std::exception const& err) {
                @throw RLMException(err);
            }
        }
        else {
            [_parent willChangeValueForKey:_propertyName];
            _backingValue = value;
            [_parent didChangeValueForKey:_propertyName];
        }
    }
}

- (nullable id<RLMValue>)value {
    if (_managed) {
        try {
            @autoreleasepool {
                RLMAccessorContext ctx(*_parent->_info);
                auto object = realm::Object(_parent->_realm->_realm,
                                            *_parent->_info->objectSchema, _parent->_row);
                return RLMCoerceToNil(object.get_property_value<id<RLMValue>>(ctx, _propertyName.UTF8String));
            }
        }
        catch (std::exception const& err) {
            @throw RLMException(err);
        }
    }
    else {
        return _backingValue;
    }
}

- (BOOL)isEqual:(id)other
{
    return [self.value isEqual:other];
}

- (void)attachWithParent:(RLMObjectBase *)parent
                property:(RLMProperty *)property {
    _parent = parent;
    _propertyName = property.name;
    _managed = !(parent->_realm == nil);
}

@end

@interface RLMSwiftValueStorage (RLMValue)<RLMValue>
@end

@implementation RLMSwiftValueStorage (RLMValue)

- (RLMPropertyType)rlm_valueType {
    return [_backingValue rlm_valueType];
}

@end
