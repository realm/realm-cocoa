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

#import <vector>

namespace realm {
    class Group;
    class Query;
    class SortDescriptor;
}

@class RLMObjectSchema, RLMProperty, RLMSchema, RLMSortDescriptor;
class RLMClassInfo;

extern NSString * const RLMPropertiesComparisonTypeMismatchException;
extern NSString * const RLMUnsupportedTypesFoundInPropertyComparisonException;

realm::Query RLMPredicateToQuery(NSPredicate *predicate, RLMObjectSchema *objectSchema,
                                 RLMSchema *schema, realm::Group &group);

// return property - throw for invalid column name
RLMProperty *RLMValidatedProperty(RLMObjectSchema *objectSchema, NSString *columnName);

void RLMPrecondition(bool condition, NSString *name, NSString *format, ...);
