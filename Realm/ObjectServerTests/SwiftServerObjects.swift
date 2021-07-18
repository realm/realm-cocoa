//
//  SwiftServerObjects.swift
//  Realm
//
//  Created by Diana Maria Perez Afanador on 1/7/21.
//  Copyright © 2021 Realm. All rights reserved.
//

import Foundation
import RealmSwift

public class SwiftPerson: Object, ObjectKeyIdentifiable {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    @objc public dynamic var firstName: String = ""
    @objc public dynamic var lastName: String = ""
    @objc public dynamic var age: Int = 30

    public convenience init(firstName: String, lastName: String) {
        self.init()
        self.firstName = firstName
        self.lastName = lastName
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftTypesSyncObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    @objc public dynamic var boolCol: Bool = true
    @objc public dynamic var intCol: Int = 1
    @objc public dynamic var doubleCol: Double = 1.1
    @objc public dynamic var stringCol: String = "string"
    @objc public dynamic var binaryCol: Data = "string".data(using: String.Encoding.utf8)!
    @objc public dynamic var dateCol: Date = Date(timeIntervalSince1970: -1)
    @objc public dynamic var longCol: Int64 = 1
    @objc public dynamic var decimalCol: Decimal128 = Decimal128(1)
    @objc public dynamic var uuidCol: UUID = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!
    @objc public dynamic var objectIdCol: ObjectId = .generate()
    @objc public dynamic var objectCol: SwiftPerson?
    public var anyCol = RealmProperty<AnyRealmValue>()

    public convenience init(person: SwiftPerson) {
        self.init()
        self.anyCol.value = .int(1)
        self.objectCol = person
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftCollectionSyncObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    public let intList = List<Int>()
    public let boolList = List<Bool>()
    public let stringList = List<String>()
    public let dataList = List<Data>()
    public let dateList = List<Date>()
    public let doubleList = List<Double>()
    public let objectIdList = List<ObjectId>()
    public let decimalList = List<Decimal128>()
    public let uuidList = List<UUID>()
    public let anyList = List<AnyRealmValue>()
    public let objectList = List<SwiftPerson>()

    public let intSet = MutableSet<Int>()
    public let stringSet = MutableSet<String>()
    public let dataSet = MutableSet<Data>()
    public let dateSet = MutableSet<Date>()
    public let doubleSet = MutableSet<Double>()
    public let objectIdSet = MutableSet<ObjectId>()
    public let decimalSet = MutableSet<Decimal128>()
    public let uuidSet = MutableSet<UUID>()
    public let anySet = MutableSet<AnyRealmValue>()
    public let objectSet = MutableSet<SwiftPerson>()

    public let otherIntSet = MutableSet<Int>()
    public let otherStringSet = MutableSet<String>()
    public let otherDataSet = MutableSet<Data>()
    public let otherDateSet = MutableSet<Date>()
    public let otherDoubleSet = MutableSet<Double>()
    public let otherObjectIdSet = MutableSet<ObjectId>()
    public let otherDecimalSet = MutableSet<Decimal128>()
    public let otherUuidSet = MutableSet<UUID>()
    public let otherAnySet = MutableSet<AnyRealmValue>()
    public let otherObjectSet = MutableSet<SwiftPerson>()

    public let intMap = Map<String, Int>()
    public let stringMap = Map<String, String>()
    public let dataMap = Map<String, Data>()
    public let dateMap = Map<String, Date>()
    public let doubleMap = Map<String, Double>()
    public let objectIdMap = Map<String, ObjectId>()
    public let decimalMap = Map<String, Decimal128>()
    public let uuidMap = Map<String, UUID>()
    public let anyMap = Map<String, AnyRealmValue>()
    public let objectMap = Map<String, SwiftPerson?>()

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftAnyRealmValueObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    public let anyCol = RealmProperty<AnyRealmValue>()
    public let otherAnyCol = RealmProperty<AnyRealmValue>()
    public override class func primaryKey() -> String? {
        return "_id"
    }
}

public class SwiftMissingObject: Object {
    @objc public dynamic var _id: ObjectId? = ObjectId.generate()
    @objc public dynamic var objectCol: SwiftPerson?
    public let anyCol = RealmProperty<AnyRealmValue>()
    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftUUIDPrimaryKeyObject: Object {
    public dynamic var _id: UUID? = UUID(uuidString: "85d4fbee-6ec6-47df-bfa1-615931903d7e")!
    public dynamic var strCol: String = ""
    public dynamic var intCol: Int = 0

    public convenience init(id: UUID?, strCol: String, intCol: Int) {
        self.init()
        self._id = id
        self.strCol = strCol
        self.intCol = intCol
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftStringPrimaryKeyObject: Object {
    public dynamic var _id: String? = "1234567890ab1234567890ab"
    public dynamic var strCol: String = ""
    public dynamic var intCol: Int = 0

    public convenience init(id: String, strCol: String, intCol: Int) {
        self.init()
        self._id = id
        self.strCol = strCol
        self.intCol = intCol
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftIntPrimaryKeyObject: Object {
    public dynamic var _id: Int = 1234567890
    public dynamic var strCol: String = ""
    public dynamic var intCol: Int = 0

    public convenience init(id: Int, strCol: String, intCol: Int) {
        self.init()
        self._id = id
        self.strCol = strCol
        self.intCol = intCol
    }

    public override class func primaryKey() -> String? {
        return "_id"
    }
}

@objcMembers public class SwiftHugeSyncObject: Object, ObjectKeyIdentifiable {
    dynamic var _id = ObjectId.generate()
    dynamic var data: Data?

    public override class func primaryKey() -> String? {
        return "_id"
    }

    public class func create() -> SwiftHugeSyncObject {
        let fakeDataSize = 1000000
        return SwiftHugeSyncObject(value: ["data": Data(repeating: 16, count: fakeDataSize)])
    }
}
