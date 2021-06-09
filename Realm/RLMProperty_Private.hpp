////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import <Realm/RLMProperty_Private.h>

namespace realm {
    struct Property;
}

@class RLMSchema;

@interface RLMProperty ()

+ (instancetype)propertyForObjectStoreProperty:(const realm::Property&)property RLM_OBJC_DIRECT;

- (realm::Property)objectStoreCopy:(RLMSchema *)schema RLM_OBJC_DIRECT;

@end
