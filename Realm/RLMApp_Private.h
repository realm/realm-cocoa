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

#import <Realm/RLMApp.h>

NS_ASSUME_NONNULL_BEGIN

/// Observer block for app notifications.
typedef void(^RLMAppNotificationBlock)(RLMApp *);

/// Token that identifies an observer. Unsubscribes when deconstructed to
/// avoid dangling observers, therefore this must be retained to hold
/// onto a subscription.
@interface RLMAppSubscriptionToken : NSObject

/// The underlying value of the subscription token.
@property (nonatomic, readonly) NSUInteger value;

@end

@interface RLMApp ()
/// Returns all Apps which have been initialized in the current run of the application.
+ (NSMutableDictionary *)apps;
/// Subscribe to notifications for this RLMApp.
- (RLMAppSubscriptionToken *)subscribe:(RLMAppNotificationBlock)block;
/// Unsubscribe to notifications for this RLMApp.
- (void)unsubscribe:(RLMAppSubscriptionToken *)token;

@end

NS_ASSUME_NONNULL_END
