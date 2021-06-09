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

#import "RLMResults_Private.h"

#import "RLMIvarStorage.hpp"

#import <realm/object-store/results.hpp>

class RLMClassInfo;

NS_ASSUME_NONNULL_BEGIN

@interface RLMResults () {
@protected
    RLMIvar<realm::Results> _results;
}

/**
 Initialize a 'raw' `RLMResults` using only an object store level Results.
 This is only meant for applications where a results collection is being backed
 by an object store object class that has no binding-level equivalent. The
 consumer is responsible for bridging between the underlying objects and whatever
 binding-level class is being vended out.
 */
- (instancetype)initWithResults:(realm::Results)results;

- (instancetype)initWithObjectInfo:(RLMClassInfo&)info results:(realm::Results&&)results;
+ (instancetype)resultsWithObjectInfo:(RLMClassInfo&)info results:(realm::Results&&)results;

- (instancetype)subresultsWithResults:(realm::Results)results;
@end

NS_ASSUME_NONNULL_END

// Utility functions

[[gnu::noinline]]
[[noreturn]]
void RLMThrowResultsError(NSString * _Nullable aggregateMethod);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"
template<typename Function>
static auto translateRLMResultsErrors(Function&& f, NSString *aggregateMethod=nil) {
    try {
        return f();
    }
    catch (...) {
        RLMThrowResultsError(aggregateMethod);
    }
}
#pragma clang diagnostic pop
