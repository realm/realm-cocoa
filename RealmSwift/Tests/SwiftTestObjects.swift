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

import Foundation
import RealmSwift
import Realm

class SwiftStringObject: Object {
    @objc dynamic var stringCol = ""
}

class SwiftBoolObject: Object {
    @objc dynamic var boolCol = false
}

class SwiftIntObject: Object {
    @objc dynamic var intCol = 0
}

class SwiftInt8Object: Object {
    @objc dynamic var int8Col = 0
}

class SwiftInt16Object: Object {
    @objc dynamic var int16Col = 0
}

class SwiftInt32Object: Object {
    @objc dynamic var int32Col = 0
}

class SwiftInt64Object: Object {
    @objc dynamic var int64Col = 0
}

class SwiftLongObject: Object {
    @objc dynamic var longCol: Int64 = 0
}

@objc enum IntEnum: Int, RealmEnum, Codable {
    case value1 = 1
    case value2 = 3
}

class SwiftObject: Object {
    @objc dynamic var boolCol = false
    @objc dynamic var intCol = 123
    @objc dynamic var int8Col: Int8 = 123
    @objc dynamic var int16Col: Int16 = 123
    @objc dynamic var int32Col: Int32 = 123
    @objc dynamic var int64Col: Int64 = 123
    @objc dynamic var intEnumCol = IntEnum.value1
    @objc dynamic var floatCol = 1.23 as Float
    @objc dynamic var doubleCol = 12.3
    @objc dynamic var stringCol = "a"
    @objc dynamic var binaryCol = "a".data(using: String.Encoding.utf8)!
    @objc dynamic var dateCol = Date(timeIntervalSince1970: 1)
    @objc dynamic var decimalCol = Decimal128("123e4")
    @objc dynamic var objectIdCol = ObjectId("1234567890ab1234567890ab")
    @objc dynamic var objectCol: SwiftBoolObject? = SwiftBoolObject()
    @objc dynamic var uuidCol: UUID = UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!
    let anyCol = RealmProperty<AnyRealmValue>()

    let arrayCol = List<SwiftBoolObject>()
    let setCol = MutableSet<SwiftBoolObject>()
    let mapCol = Map<String, SwiftBoolObject?>()

    class func defaultValues() -> [String: Any] {
        return  [
            "boolCol": false,
            "intCol": 123,
            "int8Col": 123 as Int8,
            "int16Col": 123 as Int16,
            "int32Col": 123 as Int32,
            "int64Col": 123 as Int64,
            "floatCol": 1.23 as Float,
            "doubleCol": 12.3,
            "stringCol": "a",
            "binaryCol": "a".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 1),
            "decimalCol": Decimal128("123e4"),
            "objectIdCol": ObjectId("1234567890ab1234567890ab"),
            "objectCol": [false],
            "uuidCol": UUID(uuidString: "137decc8-b300-4954-a233-f89909f4fd89")!,
            "arrayCol": [],
            "setCol": [],
            "mapCol": [:]
        ]
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftOptionalObject: Object {
    @objc dynamic var optNSStringCol: NSString?
    @objc dynamic var optStringCol: String?
    @objc dynamic var optBinaryCol: Data?
    @objc dynamic var optDateCol: Date?
    @objc dynamic var optDecimalCol: Decimal128?
    @objc dynamic var optObjectIdCol: ObjectId?
    @objc dynamic var optUuidCol: UUID?
    let optIntCol = RealmOptional<Int>()
    let optInt8Col = RealmOptional<Int8>()
    let optInt16Col = RealmOptional<Int16>()
    let optInt32Col = RealmOptional<Int32>()
    let optInt64Col = RealmOptional<Int64>()
    let optFloatCol = RealmOptional<Float>()
    let optDoubleCol = RealmOptional<Double>()
    let optBoolCol = RealmOptional<Bool>()
    let optEnumCol = RealmOptional<IntEnum>()
    let otherIntCol = RealmProperty<Int?>()
    @objc dynamic var optObjectCol: SwiftBoolObject?
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftOptionalPrimaryObject: SwiftOptionalObject {
    let id = RealmOptional<Int>()

    override class func primaryKey() -> String? { return "id" }
}

class SwiftListObject: Object {
    let int = List<Int>()
    let int8 = List<Int8>()
    let int16 = List<Int16>()
    let int32 = List<Int32>()
    let int64 = List<Int64>()
    let float = List<Float>()
    let double = List<Double>()
    let string = List<String>()
    let data = List<Data>()
    let date = List<Date>()
    let decimal = List<Decimal128>()
    let objectId = List<ObjectId>()
    let uuid = List<UUID>()
    let any = List<AnyRealmValue>()

    let intOpt = List<Int?>()
    let int8Opt = List<Int8?>()
    let int16Opt = List<Int16?>()
    let int32Opt = List<Int32?>()
    let int64Opt = List<Int64?>()
    let floatOpt = List<Float?>()
    let doubleOpt = List<Double?>()
    let stringOpt = List<String?>()
    let dataOpt = List<Data?>()
    let dateOpt = List<Date?>()
    let decimalOpt = List<Decimal128?>()
    let objectIdOpt = List<ObjectId?>()
    let uuidOpt = List<UUID?>()
}

class SwiftMutableSetObject: Object {
    let int = MutableSet<Int>()
    let int8 = MutableSet<Int8>()
    let int16 = MutableSet<Int16>()
    let int32 = MutableSet<Int32>()
    let int64 = MutableSet<Int64>()
    let float = MutableSet<Float>()
    let double = MutableSet<Double>()
    let string = MutableSet<String>()
    let data = MutableSet<Data>()
    let date = MutableSet<Date>()
    let decimal = MutableSet<Decimal128>()
    let objectId = MutableSet<ObjectId>()
    let uuid = MutableSet<UUID>()
    let any = MutableSet<AnyRealmValue>()

    let intOpt = MutableSet<Int?>()
    let int8Opt = MutableSet<Int8?>()
    let int16Opt = MutableSet<Int16?>()
    let int32Opt = MutableSet<Int32?>()
    let int64Opt = MutableSet<Int64?>()
    let floatOpt = MutableSet<Float?>()
    let doubleOpt = MutableSet<Double?>()
    let stringOpt = MutableSet<String?>()
    let dataOpt = MutableSet<Data?>()
    let dateOpt = MutableSet<Date?>()
    let decimalOpt = MutableSet<Decimal128?>()
    let objectIdOpt = MutableSet<ObjectId?>()
    let uuidOpt = MutableSet<UUID?>()
}

class SwiftMapObject: Object {
    let int = Map<String, Int>()
    let int8 = Map<String, Int8>()
    let int16 = Map<String, Int16>()
    let int32 = Map<String, Int32>()
    let int64 = Map<String, Int64>()
    let float = Map<String, Float>()
    let double = Map<String, Double>()
    let bool = Map<String, Bool>()
    let string = Map<String, String>()
    let data = Map<String, Data>()
    let date = Map<String, Date>()
    let decimal = Map<String, Decimal128>()
    let objectId = Map<String, ObjectId>()
    let uuid = Map<String, UUID>()
    let object = Map<String, SwiftStringObject?>()
    let any = Map<String, AnyRealmValue>()

    let intOpt = Map<String, Int?>()
    let int8Opt = Map<String, Int8?>()
    let int16Opt = Map<String, Int16?>()
    let int32Opt = Map<String, Int32?>()
    let int64Opt = Map<String, Int64?>()
    let floatOpt = Map<String, Float?>()
    let doubleOpt = Map<String, Double?>()
    let boolOpt = Map<String, Bool?>()
    let stringOpt = Map<String, String?>()
    let dataOpt = Map<String, Data?>()
    let dateOpt = Map<String, Date?>()
    let decimalOpt = Map<String, Decimal128?>()
    let objectIdOpt = Map<String, ObjectId?>()
    let uuidOpt = Map<String, UUID?>()
}

class SwiftImplicitlyUnwrappedOptionalObject: Object {
    @objc dynamic var optNSStringCol: NSString!
    @objc dynamic var optStringCol: String!
    @objc dynamic var optBinaryCol: Data!
    @objc dynamic var optDateCol: Date!
    @objc dynamic var optDecimalCol: Decimal128!
    @objc dynamic var optObjectIdCol: ObjectId!
    @objc dynamic var optObjectCol: SwiftBoolObject!
    @objc dynamic var optUuidCol: UUID!
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftOptionalDefaultValuesObject: Object {
    @objc dynamic var optNSStringCol: NSString? = "A"
    @objc dynamic var optStringCol: String? = "B"
    @objc dynamic var optBinaryCol: Data? = "C".data(using: String.Encoding.utf8)! as Data
    @objc dynamic var optDateCol: Date? = Date(timeIntervalSince1970: 10)
    @objc dynamic var optDecimalCol: Decimal128? = "123"
    @objc dynamic var optObjectIdCol: ObjectId? = ObjectId("1234567890ab1234567890ab")
    @objc dynamic var optUuidCol: UUID? = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
    let optIntCol = RealmOptional<Int>(1)
    let optInt8Col = RealmOptional<Int8>(1)
    let optInt16Col = RealmOptional<Int16>(1)
    let optInt32Col = RealmOptional<Int32>(1)
    let optInt64Col = RealmOptional<Int64>(1)
    let optFloatCol = RealmOptional<Float>(2.2)
    let optDoubleCol = RealmOptional<Double>(3.3)
    let optBoolCol = RealmOptional<Bool>(true)
    @objc dynamic var optObjectCol: SwiftBoolObject? = SwiftBoolObject(value: [true])
    //    let arrayCol = List<SwiftBoolObject?>()

    class func defaultValues() -> [String: Any] {
        return [
            "optNSStringCol": "A",
            "optStringCol": "B",
            "optBinaryCol": "C".data(using: String.Encoding.utf8)!,
            "optDateCol": Date(timeIntervalSince1970: 10),
            "optDecimalCol": Decimal128("123"),
            "optObjectIdCol": ObjectId("1234567890ab1234567890ab"),
            "optIntCol": 1,
            "optInt8Col": Int8(1),
            "optInt16Col": Int16(1),
            "optInt32Col": Int32(1),
            "optInt64Col": Int64(1),
            "optFloatCol": 2.2 as Float,
            "optDoubleCol": 3.3,
            "optBoolCol": true,
            "optUuidCol": UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        ]
    }
}

class SwiftOptionalIgnoredPropertiesObject: Object {
    @objc dynamic var id = 0

    @objc dynamic var optNSStringCol: NSString? = "A"
    @objc dynamic var optStringCol: String? = "B"
    @objc dynamic var optBinaryCol: Data? = "C".data(using: String.Encoding.utf8)! as Data
    @objc dynamic var optDateCol: Date? = Date(timeIntervalSince1970: 10)
    @objc dynamic var optDecimalCol: Decimal128? = "123"
    @objc dynamic var optObjectIdCol: ObjectId? = ObjectId("1234567890ab1234567890ab")
    @objc dynamic var optObjectCol: SwiftBoolObject? = SwiftBoolObject(value: [true])

    override class func ignoredProperties() -> [String] {
        return [
            "optNSStringCol",
            "optStringCol",
            "optBinaryCol",
            "optDateCol",
            "optDecimalCol",
            "optObjectIdCol",
            "optObjectCol"
        ]
    }
}

class SwiftDogObject: Object {
    @objc dynamic var dogName = ""
    let owners = LinkingObjects(fromType: SwiftOwnerObject.self, property: "dog")
}

class SwiftOwnerObject: Object {
    @objc dynamic var name = ""
    @objc dynamic var dog: SwiftDogObject? = SwiftDogObject()
}

class SwiftAggregateObject: Object {
    @objc dynamic var intCol = 0
    @objc dynamic var int8Col: Int8 = 0
    @objc dynamic var int16Col: Int16 = 0
    @objc dynamic var int32Col: Int32 = 0
    @objc dynamic var int64Col: Int64 = 0
    @objc dynamic var floatCol = 0 as Float
    @objc dynamic var doubleCol = 0.0
    @objc dynamic var decimalCol = 0.0 as Decimal128
    @objc dynamic var boolCol = false
    @objc dynamic var dateCol = Date()
    @objc dynamic var trueCol = true
    let stringListCol = List<SwiftStringObject>()
}

class SwiftAllIntSizesObject: Object {
    @objc dynamic var int8: Int8  = 0
    @objc dynamic var int16: Int16 = 0
    @objc dynamic var int32: Int32 = 0
    @objc dynamic var int64: Int64 = 0
}

class SwiftEmployeeObject: Object {
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var hired = false
}

class SwiftCompanyObject: Object {
    let employees = List<SwiftEmployeeObject>()
    let employeeSet = MutableSet<SwiftEmployeeObject>()
    let employeeMap = Map<String, SwiftEmployeeObject?>()
}

class SwiftArrayPropertyObject: Object {
    @objc dynamic var name = ""
    let array = List<SwiftStringObject>()
    let intArray = List<SwiftIntObject>()
}

class SwiftMutableSetPropertyObject: Object {
    @objc dynamic var name = ""
    let set = MutableSet<SwiftStringObject>()
    let intSet = MutableSet<SwiftIntObject>()
}

class SwiftMapPropertyObject: Object {
    @objc dynamic var name = ""
    let map = Map<String, SwiftStringObject?>()
    let intMap = Map<String, SwiftIntObject?>()
}

class SwiftDoubleListOfSwiftObject: Object {
    let array = List<SwiftListOfSwiftObject>()
}

class SwiftListOfSwiftObject: Object {
    let array = List<SwiftObject>()
}

class SwiftMutableSetOfSwiftObject: Object {
    let set = MutableSet<SwiftObject>()
}

class SwiftMapOfSwiftObject: Object {
    let map = Map<String, SwiftObject?>()
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftMapOfSwiftOptionalObject: Object {
    let map = Map<String, SwiftOptionalObject?>()
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftListOfSwiftOptionalObject: Object {
    let array = List<SwiftOptionalObject>()
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftMutableSetOfSwiftOptionalObject: Object {
    let set = MutableSet<SwiftOptionalObject>()
}

class SwiftArrayPropertySubclassObject: SwiftArrayPropertyObject {
    let boolArray = List<SwiftBoolObject>()
}

class SwiftLinkToPrimaryStringObject: Object {
    @objc dynamic var pk = ""
    @objc dynamic var object: SwiftPrimaryStringObject?
    let objects = List<SwiftPrimaryStringObject>()

    override class func primaryKey() -> String? {
        return "pk"
    }
}

class SwiftUTF8Object: Object {
    // swiftlint:disable:next identifier_name
    @objc dynamic var 柱колоéнǢкƱаم👍 = "值значен™👍☞⎠‱௹♣︎☐▼❒∑⨌⧭иеمرحبا"
}

class SwiftIgnoredPropertiesObject: Object {
    @objc dynamic var name = ""
    @objc dynamic var age = 0
    @objc dynamic var runtimeProperty: AnyObject?
    @objc dynamic var runtimeDefaultProperty = "property"
    @objc dynamic var readOnlyProperty: Int { return 0 }

    override class func ignoredProperties() -> [String] {
        return ["runtimeProperty", "runtimeDefaultProperty"]
    }
}

class SwiftRecursiveObject: Object {
    let objects = List<SwiftRecursiveObject>()
    let objectSet = MutableSet<SwiftRecursiveObject>()
}

protocol SwiftPrimaryKeyObjectType {
    associatedtype PrimaryKey
    static func primaryKey() -> String?
}

class SwiftPrimaryStringObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var intCol = 0

    typealias PrimaryKey = String
    override class func primaryKey() -> String? {
        return "stringCol"
    }
}

class SwiftPrimaryOptionalStringObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol: String? = ""
    @objc dynamic var intCol = 0

    typealias PrimaryKey = String?
    override class func primaryKey() -> String? {
        return "stringCol"
    }
}

class SwiftPrimaryIntObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var intCol = 0

    typealias PrimaryKey = Int
    override class func primaryKey() -> String? {
        return "intCol"
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftPrimaryOptionalIntObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let intCol = RealmOptional<Int>()

    typealias PrimaryKey = RealmOptional<Int>
    override class func primaryKey() -> String? {
        return "intCol"
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftPrimaryInt8Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var int8Col: Int8 = 0

    typealias PrimaryKey = Int8
    override class func primaryKey() -> String? {
        return "int8Col"
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftPrimaryOptionalInt8Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let int8Col = RealmOptional<Int8>()

    typealias PrimaryKey = RealmOptional<Int8>
    override class func primaryKey() -> String? {
        return "int8Col"
    }
}

class SwiftPrimaryInt16Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var int16Col: Int16 = 0

    typealias PrimaryKey = Int16
    override class func primaryKey() -> String? {
        return "int16Col"
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftPrimaryOptionalInt16Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let int16Col = RealmOptional<Int16>()

    typealias PrimaryKey = RealmOptional<Int16>
    override class func primaryKey() -> String? {
        return "int16Col"
    }
}

class SwiftPrimaryInt32Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var int32Col: Int32 = 0

    typealias PrimaryKey = Int32
    override class func primaryKey() -> String? {
        return "int32Col"
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftPrimaryOptionalInt32Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let int32Col = RealmOptional<Int32>()

    typealias PrimaryKey = RealmOptional<Int32>
    override class func primaryKey() -> String? {
        return "int32Col"
    }
}

class SwiftPrimaryInt64Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var int64Col: Int64 = 0

    typealias PrimaryKey = Int64
    override class func primaryKey() -> String? {
        return "int64Col"
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftPrimaryOptionalInt64Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let int64Col = RealmOptional<Int64>()

    typealias PrimaryKey = RealmOptional<Int64>
    override class func primaryKey() -> String? {
        return "int64Col"
    }
}

class SwiftPrimaryUUIDObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var uuidCol: UUID = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!
    @objc dynamic var stringCol = ""

    typealias PrimaryKey = Int64
    override class func primaryKey() -> String? {
        return "uuidCol"
    }
}

class SwiftPrimaryObjectIdObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var objectIdCol: ObjectId = ObjectId.generate()
    @objc dynamic var intCol = 0

    typealias PrimaryKey = Int64
    override class func primaryKey() -> String? {
        return "objectIdCol"
    }
}

class SwiftIndexedPropertiesObject: Object {
    @objc dynamic var stringCol = ""
    @objc dynamic var intCol = 0
    @objc dynamic var int8Col: Int8 = 0
    @objc dynamic var int16Col: Int16 = 0
    @objc dynamic var int32Col: Int32 = 0
    @objc dynamic var int64Col: Int64 = 0
    @objc dynamic var boolCol = false
    @objc dynamic var dateCol = Date()
    @objc dynamic var uuidCol = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!

    @objc dynamic var floatCol: Float = 0.0
    @objc dynamic var doubleCol: Double = 0.0
    @objc dynamic var dataCol = Data()

    let anyCol = RealmProperty<AnyRealmValue>()

    override class func indexedProperties() -> [String] {
        return ["stringCol", "intCol", "int8Col", "int16Col",
                "int32Col", "int64Col", "boolCol", "dateCol", "anyCol", "uuidCol"]
    }
}

@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftIndexedOptionalPropertiesObject: Object {
    @objc dynamic var optionalStringCol: String? = ""
    let optionalIntCol = RealmOptional<Int>()
    let optionalInt8Col = RealmOptional<Int8>()
    let optionalInt16Col = RealmOptional<Int16>()
    let optionalInt32Col = RealmOptional<Int32>()
    let optionalInt64Col = RealmOptional<Int64>()
    let optionalBoolCol = RealmOptional<Bool>()
    @objc dynamic var optionalDateCol: Date? = Date()
    @objc dynamic var optionalUUIDCol: UUID? = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")

    let optionalFloatCol = RealmOptional<Float>()
    let optionalDoubleCol = RealmOptional<Double>()
    @objc dynamic var optionalDataCol: Data? = Data()

    override class func indexedProperties() -> [String] {
        return ["optionalStringCol", "optionalIntCol", "optionalInt8Col", "optionalInt16Col",
            "optionalInt32Col", "optionalInt64Col", "optionalBoolCol", "optionalDateCol", "optionalUUIDCol"]
    }
}

class SwiftCustomInitializerObject: Object {
    @objc dynamic var stringCol: String

    init(stringVal: String) {
        stringCol = stringVal
        super.init()
    }

    required override init() {
        stringCol = ""
        super.init()
    }
}

class SwiftConvenienceInitializerObject: Object {
    @objc dynamic var stringCol = ""

    convenience init(stringCol: String) {
        self.init()
        self.stringCol = stringCol
    }
}

class SwiftObjectiveCTypesObject: Object {
    @objc dynamic var stringCol: NSString?
    @objc dynamic var dateCol: NSDate?
    @objc dynamic var dataCol: NSData?
}

class SwiftComputedPropertyNotIgnoredObject: Object {
    // swiftlint:disable:next identifier_name
    @objc dynamic var _urlBacking = ""

    // Dynamic; no ivar
    @objc dynamic var dynamicURL: URL? {
        get {
            return URL(string: _urlBacking)
        }
        set {
            _urlBacking = newValue?.absoluteString ?? ""
        }
    }

    // Non-dynamic; no ivar
    var url: URL? {
        get {
            return URL(string: _urlBacking)
        }
        set {
            _urlBacking = newValue?.absoluteString ?? ""
        }
    }
}

@objc(SwiftObjcRenamedObject)
class SwiftObjcRenamedObject: Object {
    @objc dynamic var stringCol = ""
}

@objc(SwiftObjcRenamedObjectWithTotallyDifferentName)
class SwiftObjcArbitrarilyRenamedObject: Object {
    @objc dynamic var boolCol = false
}

class SwiftCircleObject: Object {
    @objc dynamic var obj: SwiftCircleObject?
    let array = List<SwiftCircleObject>()
}

// Exists to serve as a superclass to `SwiftGenericPropsOrderingObject`
class SwiftGenericPropsOrderingParent: Object {
    var implicitlyIgnoredComputedProperty: Int { return 0 }
    let implicitlyIgnoredReadOnlyProperty: Int = 1
    let parentFirstList = List<SwiftIntObject>()
    let parentFirstSet = MutableSet<SwiftIntObject>()
    @objc dynamic var parentFirstNumber = 0
    func parentFunction() -> Int { return parentFirstNumber + 1 }
    @objc dynamic var parentSecondNumber = 1
    var parentComputedProp: String { return "hello world" }
}

// Used to verify that Swift properties (generic and otherwise) are detected properly and
// added to the schema in the correct order.
@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftGenericPropsOrderingObject: SwiftGenericPropsOrderingParent {
    func myFunction() -> Int { return firstNumber + secondNumber + thirdNumber }
    @objc dynamic var dynamicComputed: Int { return 999 }
    var firstIgnored = 999
    @objc dynamic var dynamicIgnored = 999
    @objc dynamic var firstNumber = 0                   // Managed property
    class func myClassFunction(x: Int, y: Int) -> Int { return x + y }
    var secondIgnored = 999
    lazy var lazyIgnored = 999
    let firstArray = List<SwiftStringObject>()          // Managed property
    let firstSet = MutableSet<SwiftStringObject>()          // Managed property
    @objc dynamic var secondNumber = 0                  // Managed property
    var computedProp: String { return "\(firstNumber), \(secondNumber), and \(thirdNumber)" }
    let secondArray = List<SwiftStringObject>()         // Managed property
    let secondSet = MutableSet<SwiftStringObject>()         // Managed property
    override class func ignoredProperties() -> [String] {
        return ["firstIgnored", "dynamicIgnored", "secondIgnored", "thirdIgnored", "lazyIgnored", "dynamicLazyIgnored"]
    }
    let firstOptionalNumber = RealmOptional<Int>()      // Managed property
    var thirdIgnored = 999
    @objc dynamic lazy var dynamicLazyIgnored = 999
    let firstLinking = LinkingObjects(fromType: SwiftGenericPropsOrderingHelper.self, property: "first")
    let secondLinking = LinkingObjects(fromType: SwiftGenericPropsOrderingHelper.self, property: "second")
    @objc dynamic var thirdNumber = 0                   // Managed property
    let secondOptionalNumber = RealmOptional<Int>()     // Managed property
}

// Only exists to allow linking object properties on `SwiftGenericPropsNotLastObject`.
@available(*, deprecated) // Silence deprecation warnings for RealmOptional
class SwiftGenericPropsOrderingHelper: Object {
    @objc dynamic var first: SwiftGenericPropsOrderingObject?
    @objc dynamic var second: SwiftGenericPropsOrderingObject?
}

class SwiftRenamedProperties1: Object {
    @objc dynamic var propA = 0
    @objc dynamic var propB = ""
    let linking1 = LinkingObjects(fromType: LinkToSwiftRenamedProperties1.self, property: "linkA")
    let linking2 = LinkingObjects(fromType: LinkToSwiftRenamedProperties2.self, property: "linkD")

    override class func _realmObjectName() -> String { return "Swift Renamed Properties" }
    override class func _realmColumnNames() -> [String: String] {
        return ["propA": "prop 1", "propB": "prop 2"]
    }
}

class SwiftRenamedProperties2: Object {
    @objc dynamic var propC = 0
    @objc dynamic var propD = ""
    let linking1 = LinkingObjects(fromType: LinkToSwiftRenamedProperties1.self, property: "linkA")
    let linking2 = LinkingObjects(fromType: LinkToSwiftRenamedProperties2.self, property: "linkD")

    override class func _realmObjectName() -> String { return "Swift Renamed Properties" }
    override class func _realmColumnNames() -> [String: String] {
        return ["propC": "prop 1", "propD": "prop 2"]
    }
}

class LinkToSwiftRenamedProperties1: Object {
    @objc dynamic var linkA: SwiftRenamedProperties1?
    @objc dynamic var linkB: SwiftRenamedProperties2?
    let array1 = List<SwiftRenamedProperties1>()
    let set1 = MutableSet<SwiftRenamedProperties1>()

    override class func _realmObjectName() -> String { return "Link To Swift Renamed Properties" }
    override class func _realmColumnNames() -> [String: String] {
        return ["linkA": "link 1", "linkB": "link 2", "array1": "array", "set1": "set"]
    }
}

class LinkToSwiftRenamedProperties2: Object {
    @objc dynamic var linkC: SwiftRenamedProperties1?
    @objc dynamic var linkD: SwiftRenamedProperties2?
    let array2 = List<SwiftRenamedProperties2>()
    let set2 = MutableSet<SwiftRenamedProperties2>()

    override class func _realmObjectName() -> String { return "Link To Swift Renamed Properties" }
    override class func _realmColumnNames() -> [String: String] {
        return ["linkC": "link 1", "linkD": "link 2", "array2": "array", "set2": "set"]
    }
}

class EmbeddedParentObject: Object {
    @objc dynamic var object: EmbeddedTreeObject1?
    let array = List<EmbeddedTreeObject1>()
    let map = Map<String, EmbeddedTreeObject1?>()
}

class EmbeddedPrimaryParentObject: Object {
    @objc dynamic var pk: Int = 0
    @objc dynamic var object: EmbeddedTreeObject1?
    let array = List<EmbeddedTreeObject1>()

    override class func primaryKey() -> String? {
        return "pk"
    }
}

protocol EmbeddedTreeObject: EmbeddedObject {
    var value: Int { get set }
}

class EmbeddedTreeObject1: EmbeddedObject, EmbeddedTreeObject {
    @objc dynamic var value = 0
    @objc dynamic var child: EmbeddedTreeObject2?
    let children = List<EmbeddedTreeObject2>()

    let parent1 = LinkingObjects(fromType: EmbeddedParentObject.self, property: "object")
    let parent2 = LinkingObjects(fromType: EmbeddedParentObject.self, property: "array")
}

class EmbeddedTreeObject2: EmbeddedObject, EmbeddedTreeObject {
    @objc dynamic var value = 0
    @objc dynamic var child: EmbeddedTreeObject3?
    let children = List<EmbeddedTreeObject3>()

    let parent3 = LinkingObjects(fromType: EmbeddedTreeObject1.self, property: "child")
    let parent4 = LinkingObjects(fromType: EmbeddedTreeObject1.self, property: "children")
}

class EmbeddedTreeObject3: EmbeddedObject, EmbeddedTreeObject {
    @objc dynamic var value = 0

    let parent3 = LinkingObjects(fromType: EmbeddedTreeObject2.self, property: "child")
    let parent4 = LinkingObjects(fromType: EmbeddedTreeObject2.self, property: "children")
}

class ObjectWithNestedEmbeddedObject: Object {
    @objc dynamic var value = 0
    @objc dynamic var inner: NestedInnerClass?

    @objc(NestedInnerClass)
    class NestedInnerClass: EmbeddedObject {
        @objc dynamic var value = 0
    }
}

@objc(PrivateObjectSubclass)
private class PrivateObjectSubclass: Object {
    @objc dynamic var value = 0
}
