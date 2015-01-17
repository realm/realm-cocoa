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

import Realm

// These types don't change when wrapping in Swift
// so we just typealias them to remove the 'RLM' prefix

// MARK: Aliases

/// An enum of the different property types supported by Realm.
public typealias PropertyType = RLMPropertyType

/// A token that holds onto the Realm and the notification block.
public typealias NotificationToken = RLMNotificationToken

/// A block that is used to migrate objects from one version of a Realm to a newer version.
public typealias ObjectMigrationBlock = RLMObjectMigrationBlock
