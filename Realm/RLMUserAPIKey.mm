////////////////////////////////////////////////////////////////////////////
//
// Copyright 2020 Realm Inc.
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

#import "RLMUserAPIKey_Private.hpp"

#import "RLMIvarStorage.hpp"
#import "RLMObjectId_Private.hpp"
#import "RLMUtil.hpp"

@implementation RLMUserAPIKey {
    RLMIvar<realm::app::App::UserAPIKey> _userAPIKey;
}

- (instancetype)initWithUserAPIKey:(realm::app::App::UserAPIKey)userAPIKey {
    if (self = [super init]) {
        _userAPIKey = userAPIKey;
        return self;
    }
    
    return nil;
}

// Indicates if the API key is disabled or not
- (BOOL)disabled {
    return _userAPIKey->disabled;
}

// The name of the key.
- (NSString *)name {
    return @(_userAPIKey->name.c_str());
}

// The actual key. Will only be included in
// the response when an API key is first created.
- (NSString *)key {
    if (_userAPIKey->key) {
        return @(_userAPIKey->name.c_str());
    }
    
    return nil;
}

- (RLMObjectId *)objectId {
    return [[RLMObjectId alloc] initWithValue:_userAPIKey->id];
}

- (realm::app::App::UserAPIKey)_apiKey {
    return _userAPIKey;
}

@end
