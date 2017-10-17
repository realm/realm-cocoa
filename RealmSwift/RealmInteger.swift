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

import Foundation
import Realm

/**
 A `RealmInteger` represents an integer property on an `Object` subclass
 that supports advanced Realm-specific functionality.

 `RealmInteger` properties should be declared as `@objc dynamic`.
 
 You may either work with the APIs of a `RealmInteger` instance, or you may
 directly assign to a `RealmInteger` property on a model object. If a
 `RealmInteger` is directly assigned to, it takes on the integer value of
 the other `RealmInteger` instance at the time the assignment takes place.

 A property of `RealmInteger` type represents a required Realm integer. To
 make the integer optional, define it as a `RealmInteger?`.

 - see: `RLMInteger`
 */
@objc(RLMSwiftInteger)
public final class RealmInteger: RLMInteger {

    /**
     Get or set the underlying value of the Realm integer.
     */
    public var value: Int? {
        get {
            return __value?.intValue ?? nil
        }
        set {
            guard let newValue = newValue else {
                __value = nil
                return
            }
            __value = NSNumber(value: newValue)
        }
    }

    /**
     Create a new instance set to the provided numeric value (or 0 if none
     is provided).
     */
    public init(value: Int? = 0) {
        if let value = value {
            super.init(__value: NSNumber(value: value))
        } else {
            super.init(__value: nil)
        }
    }
}

/// :nodoc:
extension RealmInteger : ExpressibleByIntegerLiteral {
    public convenience init(integerLiteral value: Int) {
        self.init(value: value)
    }
}
