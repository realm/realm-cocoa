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

import Foundation
import Realm

/**
 A `SortDescriptor` stores a key path and a sort order for use with `sorted(sortDescriptors:)`. It is similar to
 `NSSortDescriptor`, but supports only the subset of functionality which can be efficiently run by Realm's query engine.
 */
@frozen public struct SortDescriptor {

    // MARK: Properties

    /// The key path which the sort descriptor orders results by.
    public let keyPath: String

    /// Whether this descriptor sorts in ascending or descending order.
    public let ascending: Bool

    /// Converts the receiver to an `RLMSortDescriptor`.
    internal var rlmSortDescriptorValue: RLMSortDescriptor {
        return RLMSortDescriptor(keyPath: keyPath, ascending: ascending)
    }

    // MARK: Initializers

    /**
     Creates a sort descriptor with the given key path and sort order values.

     - parameter keyPath:   The key path which the sort descriptor orders results by.
     - parameter ascending: Whether the descriptor sorts in ascending or descending order.
     */
    public init(keyPath: String, ascending: Bool = true) {
        self.keyPath = keyPath
        self.ascending = ascending
    }

    /**
     Creates a sort descriptor with the given key path and sort order values.

     - parameter keyPath:   The key path which the sort descriptor orders results by.
     - parameter ascending: Whether the descriptor sorts in ascending or descending order.
     */
    public init<Element: ObjectBase>(keyPath: PartialKeyPath<Element>, ascending: Bool = true) {
        self.keyPath = _name(for: keyPath)
        self.ascending = ascending
    }

    // MARK: Functions

    /// Returns a copy of the sort descriptor with the sort order reversed.
    public func reversed() -> SortDescriptor {
        return SortDescriptor(keyPath: keyPath, ascending: !ascending)
    }
}

// MARK: CustomStringConvertible

extension SortDescriptor: CustomStringConvertible {
    /// A human-readable description of the sort descriptor.
    public var description: String {
        let direction = ascending ? "ascending" : "descending"
        return "SortDescriptor(keyPath: \(keyPath), direction: \(direction))"
    }
}

// MARK: Equatable

extension SortDescriptor: Equatable {
    /// Returns whether the two sort descriptors are equal.
    public static func == (lhs: SortDescriptor, rhs: SortDescriptor) -> Bool {
        return lhs.keyPath == rhs.keyPath &&
            lhs.ascending == rhs.ascending
    }
}

// MARK: StringLiteralConvertible

extension SortDescriptor: ExpressibleByStringLiteral {

    public typealias UnicodeScalarLiteralType = StringLiteralType
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType

    /**
     Creates a `SortDescriptor` out of a string literal.

     - parameter stringLiteral: Property name literal.
     */
    public init(stringLiteral value: StringLiteralType) {
        self.init(keyPath: value)
    }
}
