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

#import "RLMRealm_Private.h"

#import "RLMClassInfo.hpp"
#import "RLMIvarStorage.hpp"

#import <realm/object-store/object_schema.hpp>

namespace realm {
    class Group;
    class Realm;
}
struct RLMResultsSetInfo {
    realm::ObjectSchema osObjectSchema;
    RLMObjectSchema *rlmObjectSchema;
    RLMClassInfo info;

    RLMResultsSetInfo(__unsafe_unretained RLMRealm *const realm);
    static RLMClassInfo& get(__unsafe_unretained RLMRealm *const realm);
};

@interface RLMRealm () {
    @public
    std::shared_ptr<realm::Realm> _realm;
    RLMSchemaInfo _info;
    std::unique_ptr<RLMResultsSetInfo> _resultsSetInfo;
}

// FIXME - group should not be exposed
@property (nonatomic, readonly RLM_DIRECT) realm::Group &group;
@end
