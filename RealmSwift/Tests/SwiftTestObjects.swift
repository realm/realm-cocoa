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

class SwiftLongObject: Object {
    @objc dynamic var longCol: Int64 = 0
}

class SwiftObject: Object {
    @objc dynamic var boolCol = false
    @objc dynamic var intCol = 123
    @objc dynamic var floatCol = 1.23 as Float
    @objc dynamic var doubleCol = 12.3
    @objc dynamic var stringCol = "a"
    @objc dynamic var binaryCol = "a".data(using: String.Encoding.utf8)!
    @objc dynamic var dateCol = Date(timeIntervalSince1970: 1)
    @objc dynamic var objectCol: SwiftBoolObject? = SwiftBoolObject()
    // FIXME: Move this after `arrayCol` once the bug with generating object schemas is fixed
    var realmIntCol = RealmInteger()
    let arrayCol = List<SwiftBoolObject>()

    class func defaultValues() -> [String: Any] {
        return  [
            "boolCol": false,
            "intCol": 123,
            "floatCol": 1.23 as Float,
            "doubleCol": 12.3,
            "stringCol": "a",
            "binaryCol": "a".data(using: String.Encoding.utf8)!,
            "dateCol": Date(timeIntervalSince1970: 1),
            "objectCol": [false],
            "realmIntCol": RealmInteger(),
            "arrayCol": []
        ]
    }
}

class SwiftOptionalObject: Object {
    @objc dynamic var optNSStringCol: NSString?
    @objc dynamic var optStringCol: String?
    @objc dynamic var optBinaryCol: Data?
    @objc dynamic var optDateCol: Date?
    let optIntCol = RealmOptional<Int>()
    let optInt8Col = RealmOptional<Int8>()
    let optInt16Col = RealmOptional<Int16>()
    let optInt32Col = RealmOptional<Int32>()
    let optInt64Col = RealmOptional<Int64>()
    let optFloatCol = RealmOptional<Float>()
    let optDoubleCol = RealmOptional<Double>()
    let optBoolCol = RealmOptional<Bool>()
    @objc dynamic var optObjectCol: SwiftBoolObject?
    var optRealmIntCol: RealmInteger?
}

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
}

class SwiftImplicitlyUnwrappedOptionalObject: Object {
    @objc dynamic var optNSStringCol: NSString!
    @objc dynamic var optStringCol: String!
    @objc dynamic var optBinaryCol: Data!
    @objc dynamic var optDateCol: Date!
    @objc dynamic var optObjectCol: SwiftBoolObject!
}

class SwiftOptionalDefaultValuesObject: Object {
    @objc dynamic var optNSStringCol: NSString? = "A"
    @objc dynamic var optStringCol: String? = "B"
    @objc dynamic var optBinaryCol: Data? = "C".data(using: String.Encoding.utf8)! as Data
    @objc dynamic var optDateCol: Date? = Date(timeIntervalSince1970: 10)
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
            "optIntCol": 1,
            "optInt8Col": 1,
            "optInt16Col": 1,
            "optInt32Col": 1,
            "optInt64Col": 1,
            "optFloatCol": 2.2 as Float,
            "optDoubleCol": 3.3,
            "optBoolCol": true
        ]
    }
}

class SwiftOptionalIgnoredPropertiesObject: Object {
    @objc dynamic var id = 0

    @objc dynamic var optNSStringCol: NSString? = "A"
    @objc dynamic var optStringCol: String? = "B"
    @objc dynamic var optBinaryCol: Data? = "C".data(using: String.Encoding.utf8)! as Data
    @objc dynamic var optDateCol: Date? = Date(timeIntervalSince1970: 10)
    @objc dynamic var optObjectCol: SwiftBoolObject? = SwiftBoolObject(value: [true])

    override class func ignoredProperties() -> [String] {
        return [
            "optNSStringCol",
            "optStringCol",
            "optBinaryCol",
            "optDateCol",
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
    @objc dynamic var floatCol = 0 as Float
    @objc dynamic var doubleCol = 0.0
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
}

class SwiftArrayPropertyObject: Object {
    @objc dynamic var name = ""
    let array = List<SwiftStringObject>()
    let intArray = List<SwiftIntObject>()
}

class SwiftDoubleListOfSwiftObject: Object {
    let array = List<SwiftListOfSwiftObject>()
}

class SwiftListOfSwiftObject: Object {
    let array = List<SwiftObject>()
}

class SwiftListOfSwiftOptionalObject: Object {
    let array = List<SwiftOptionalObject>()
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

class SwiftPrimaryOptionalIntObject: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let intCol = RealmOptional<Int>()

    typealias PrimaryKey = RealmOptional<Int>
    override class func primaryKey() -> String? {
        return "intCol"
    }
}

class SwiftPrimaryInt8Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    @objc dynamic var int8Col: Int8 = 0

    typealias PrimaryKey = Int8
    override class func primaryKey() -> String? {
        return "int8Col"
    }
}

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

class SwiftPrimaryOptionalInt64Object: Object, SwiftPrimaryKeyObjectType {
    @objc dynamic var stringCol = ""
    let int64Col = RealmOptional<Int64>()

    typealias PrimaryKey = RealmOptional<Int64>
    override class func primaryKey() -> String? {
        return "int64Col"
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

    @objc dynamic var floatCol: Float = 0.0
    @objc dynamic var doubleCol: Double = 0.0
    @objc dynamic var dataCol = Data()

    override class func indexedProperties() -> [String] {
        return ["stringCol", "intCol", "int8Col", "int16Col", "int32Col", "int64Col", "boolCol", "dateCol"]
    }
}

class SwiftIndexedOptionalPropertiesObject: Object {
    @objc dynamic var optionalStringCol: String? = ""
    let optionalIntCol = RealmOptional<Int>()
    let optionalInt8Col = RealmOptional<Int8>()
    let optionalInt16Col = RealmOptional<Int16>()
    let optionalInt32Col = RealmOptional<Int32>()
    let optionalInt64Col = RealmOptional<Int64>()
    let optionalBoolCol = RealmOptional<Bool>()
    @objc dynamic var optionalDateCol: Date? = Date()

    let optionalFloatCol = RealmOptional<Float>()
    let optionalDoubleCol = RealmOptional<Double>()
    @objc dynamic var optionalDataCol: Data? = Data()

    override class func indexedProperties() -> [String] {
        return ["optionalStringCol", "optionalIntCol", "optionalInt8Col", "optionalInt16Col",
            "optionalInt32Col", "optionalInt64Col", "optionalBoolCol", "optionalDateCol"]
    }
}

class SwiftCustomInitializerObject: Object {
    @objc dynamic var stringCol: String

    init(stringVal: String) {
        stringCol = stringVal
        super.init()
    }

    required init() {
        stringCol = ""
        super.init()
    }

    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        stringCol = ""
        super.init(realm: realm, schema: schema)
    }

    required init(value: Any, schema: RLMSchema) {
        stringCol = ""
        super.init(value: value, schema: schema)
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
    @objc dynamic var numCol: NSNumber? = 0
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
    let parentFirstList = List<SwiftIntObject>()
    @objc dynamic var parentFirstNumber = 0
    func parentFunction() -> Int { return parentFirstNumber + 1 }
    @objc dynamic var parentSecondNumber = 1
    var parentComputedProp: String { return "hello world" }
}

// Used to verify that Swift properties (generic and otherwise) are detected properly and
// added to the schema in the correct order.
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
    @objc dynamic var secondNumber = 0                  // Managed property
    var computedProp: String { return "\(firstNumber), \(secondNumber), and \(thirdNumber)" }
    let secondArray = List<SwiftStringObject>()         // Managed property
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
class SwiftGenericPropsOrderingHelper: Object {
    @objc dynamic var first: SwiftGenericPropsOrderingObject?
    @objc dynamic var second: SwiftGenericPropsOrderingObject?
}

class SwiftRealmIntObject: Object {
    var realmInt = RealmInteger()
}

class SwiftNullableRealmIntObject: Object {
    var nullableRealmInt: RealmInteger? = RealmInteger()
}
