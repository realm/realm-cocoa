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

#import "RLMNetworkTransport.h"

namespace realm {
namespace app {
struct GenericEventSubscriber;
struct Request;
}
}

@interface RLMEventSubscriber : NSObject<RLMEventDelegate>
- (void)didReceiveEvent:(NSData *)event;
- (void)didReceiveError:(NSError *)error;
- (void)didOpen;
- (void)didCloseWithError:(NSError *)error;

@end

@interface RLMNetworkTransport()

- (RLMRequest *)RLMRequestFromRequest:(realm::app::Request)request RLM_OBJC_DIRECT;

@end

