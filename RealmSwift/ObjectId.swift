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

import Foundation
import Realm

/**
 A 12-byte (probably) unique object identifier.

 ObjectIds are similar to a GUID or a UUID, and can be used to uniquely identify objects without a centralized ID generator. An ObjectID consists of:

 1. A 4 byte timestamp measuring the creation time of the ObjectId in seconds since the Unix epoch.
 2. A 5 byte random value
 3. A 3 byte counter, initialized to a random value.

 ObjectIds are intended to be fast to generate. Sorting by an ObjectId field will typically result in the objects being sorted in creation order.
 */
@objc(RealmSwiftObjectId)
public final class ObjectId: RLMObjectId, Decodable {
    // MARK: Initializers

    /// Creates a new zero-initialized ObjectId.
    public override required init() {
        super.init()
    }

    /// Creates a new randomly-initialized ObjectId.
    public override class func generate() -> ObjectId {
        return unsafeDowncast(super.generate(), to: ObjectId.self)
    }

    /// Creates a new ObjectId from the given 24-byte hexadecimal string.
    ///
    /// Throws if the string is not 24 characters or contains any characters other than 0-9a-fA-F.
    /// - Parameter string: The string to parse.
    public override required init(string: String) throws {
        try super.init(string: string)
    }

    /// Creates a new ObjectId using the given date, machine identifier, process identifier.
    ///
    /// - Parameters:
    ///   - timestamp: A timestamp as NSDate.
    ///   - machineId: The machine identifier.
    ///   - processId: The process identifier.
    public required init(timestamp: Date, machineId: Int, processId: Int) {
        super.init(timestamp: timestamp,
                   machineIdentifier: Int32(machineId),
                   processIdentifier: Int32(processId))
    }

    /// Creates a new ObjectId from the given 24-byte hexadecimal static string.
    ///
    /// Aborts if the string is not 24 characters or contains any characters other than 0-9a-fA-F. Use the initializer which takes a String to handle invalid strings at runtime.
    public required init(_ str: StaticString) {
        try! super.init(string: str.withUTF8Buffer { String(decoding: $0, as: UTF8.self) })
    }

	enum CodingKeys: String, CodingKey {
		case oid = "$oid"
	}
	
    /// Creates a new ObjectId by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		if let str = try? container.decode(String.self, forKey: .oid) {
			try super.init(string: str)
		} else {
			let container = try decoder.singleValueContainer()
			try super.init(string: container.decode(String.self))
		}
    }
}

extension ObjectId: Encodable {
    /// Encodes this ObjectId into the given encoder.
    ///
    /// This function throws an error if the given encoder is unable to encode a string.
    ///
    /// - Parameter encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        try self.stringValue.encode(to: encoder)
    }
}

extension ObjectId: Comparable {
    /// Returns a Boolean value indicating whether the value of the first
    /// argument is less than that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: An ObjectId value to compare.
    ///   - rhs: Another ObjectId value to compare.
    public static func < (lhs: ObjectId, rhs: ObjectId) -> Bool {
        lhs.isLessThan(rhs)
    }

    /// Returns a Boolean value indicating whether the ObjectId of the first
    /// argument is less than or equal to that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: An ObjectId value to compare.
    ///   - rhs: Another ObjectId value to compare.
    public static func <= (lhs: ObjectId, rhs: ObjectId) -> Bool {
        lhs.isLessThanOrEqual(to: rhs)
    }

    /// Returns a Boolean value indicating whether the ObjectId of the first
    /// argument is greater than or equal to that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: An ObjectId value to compare.
    ///   - rhs: Another ObjectId value to compare.
    public static func >= (lhs: ObjectId, rhs: ObjectId) -> Bool {
        lhs.isGreaterThanOrEqual(to: rhs)
    }

    /// Returns a Boolean value indicating whether the ObjectId of the first
    /// argument is greater than that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: An ObjectId value to compare.
    ///   - rhs: Another ObjectId value to compare.
    public static func > (lhs: ObjectId, rhs: ObjectId) -> Bool {
        lhs.isGreaterThan(rhs)
    }
}
