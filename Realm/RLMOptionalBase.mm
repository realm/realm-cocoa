////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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
#import "RLMOptionalBase_Private.h"
#import "RLMObject_Private.h"
#import "RLMObjectStore.h"
#import "RLMProperty_Private.h"
#import "RLMUtil.hpp"

#import <objc/runtime.h>

@interface RLMOptionalBase ()
@property (nonatomic) id unmanagedValue;
@end

@implementation RLMOptionalBase

- (instancetype)init {
    return self;
}

- (id)underlyingValue {
    if ((_object && _object->_realm) || _object.isInvalidated) {
        return RLMDynamicGet(_object, _property);
    }
    else {
        return _unmanagedValue;
    }
}

- (void)setUnderlyingValue:(id)underlyingValue {
    if ((_object && _object->_realm) || _object.isInvalidated) {
        if (_property.isPrimary) {
            @throw RLMException(@"Primary key can't be changed after an object is inserted.");
        }
        RLMDynamicSet(_object, _property, underlyingValue);
    }
    else {
        NSString *propertyName = _property.name;
        [_object willChangeValueForKey:propertyName];
        _unmanagedValue = underlyingValue;
        [_object didChangeValueForKey:propertyName];
    }
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [self.underlyingValue isKindOfClass:aClass] || RLMIsKindOfClass(object_getClass(self), aClass);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [self.underlyingValue methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.underlyingValue];
}

- (id)forwardingTargetForSelector:(__unused SEL)sel {
    return self.underlyingValue;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (id val = self.underlyingValue) {
        return [val respondsToSelector:aSelector];
    }
    return NO;
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    [self.underlyingValue doesNotRecognizeSelector:aSelector];
}

@end
