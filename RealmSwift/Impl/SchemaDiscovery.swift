////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
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
import Realm.Private

// A type which we can get the runtime schema information from
public protocol _RealmSchemaDiscoverable {
    // The Realm property type associated with this type
    static var _rlmType: PropertyType { get }
    static var _rlmOptional: Bool { get }
    // Does this type require @objc for legacy declarations? Not used for modern
    // declarations as no types use @objc.
    static var _rlmRequireObjc: Bool { get }

    // Set any fields of the property applicable to this type other than type/optional.
    // There are both static and non-static versions of this function because
    // some times need data from an instance (e.g. LinkingObjects, where the
    // source property name is runtime data and not part of the type), while
    // wrappers like Optional need to be able to recur to the wrapped type
    // without creating an instance of that.
    func _rlmPopulateProperty(_ prop: RLMProperty)
    static func _rlmPopulateProperty(_ prop: RLMProperty)
    // Iterating over collections requires mapping NSNull to nil, but we can't
    // just do `nil as T` because of non-nullable collections. RealmProperty also
    // relies on this for the same reason.
    static func _nilValue() -> Self
}

extension _RealmSchemaDiscoverable {
    public static func _nilValue() -> Self {
        fatalError("Should never have nil value")
    }
}

internal protocol SchemaDiscoverable: _RealmSchemaDiscoverable {}
extension SchemaDiscoverable {
    public static var _rlmOptional: Bool { false }
    public static var _rlmRequireObjc: Bool { true }
    public func _rlmPopulateProperty(_ prop: RLMProperty) { }
    public static func _rlmPopulateProperty(_ prop: RLMProperty) { }
}

internal extension RLMProperty {
    convenience init(name: String, value: _RealmSchemaDiscoverable) {
        let valueType = Swift.type(of: value)
        self.init()
        self.name = name
        self.type = valueType._rlmType
        self.optional = valueType._rlmOptional
        value._rlmPopulateProperty(self)
        valueType._rlmPopulateProperty(self)
        if valueType._rlmRequireObjc {
            self.updateAccessors()
        }
    }
}

private func getModernProperties(_ object: ObjectBase) -> [RLMProperty] {
    return Mirror(reflecting: object).children.compactMap { prop in
        guard let label = prop.label else { return nil }
        guard let value = prop.value as? DiscoverablePersistedProperty else {
            return nil
        }
        let property = RLMProperty(name: label, value: value)
        property.swiftIvar = ivar_getOffset(class_getInstanceVariable(type(of: object), label)!)
        return property
    }
}

// If the property is a storage property for a lazy Swift property, return
// the base property name (e.g. `foo.storage` becomes `foo`). Otherwise, nil.
private func baseName(forLazySwiftProperty name: String) -> String? {
    // A Swift lazy var shows up as two separate children on the reflection tree:
    // one named 'x', and another that is optional and is named "$__lazy_storage_$_propName"
    if let storageRange = name.range(of: "$__lazy_storage_$_", options: [.anchored]) {
        return String(name[storageRange.upperBound...])
    }
    return nil
}

private func getLegacyProperties(_ object: ObjectBase, _ cls: ObjectBase.Type) -> [RLMProperty] {
    let indexedProperties: Set<String>
    let ignoredPropNames: Set<String>
    let columnNames = cls._realmColumnNames()
    if let realmObject = object as? Object {
        indexedProperties = Set(type(of: realmObject).indexedProperties())
        ignoredPropNames = Set(type(of: realmObject).ignoredProperties())
    } else if let realmEmbeddedObject = object as? EmbeddedObject {
        indexedProperties = Set()
        ignoredPropNames = Set(type(of: realmEmbeddedObject).ignoredProperties())
    } else {
        indexedProperties = Set()
        ignoredPropNames = Set()
    }
    return Mirror(reflecting: object).children.filter { (prop: Mirror.Child) -> Bool in
        guard let label = prop.label else { return false }
        if ignoredPropNames.contains(label) {
            return false
        }
        if let lazyBaseName = baseName(forLazySwiftProperty: label) {
            if ignoredPropNames.contains(lazyBaseName) {
                return false
            }
            throwRealmException("Lazy managed property '\(lazyBaseName)' is not allowed on a Realm Swift object"
                + " class. Either add the property to the ignored properties list or make it non-lazy.")
        }
        return true
    }.compactMap { prop in
        guard let label = prop.label else { return nil }
        var rawValue = prop.value
        if let value = rawValue as? RealmEnum {
            rawValue = type(of: value)._rlmToRawValue(value)
        }

        guard let value = rawValue as? _RealmSchemaDiscoverable else {
            if class_getProperty(cls, label) != nil {
                throwRealmException("Property \(cls).\(label) is declared as \(type(of: prop.value)), which is not a supported managed Object property type. If it is not supposed to be a managed property, either add it to `ignoredProperties()` or do not declare it as `@objc dynamic`. See https://realm.io/docs/swift/latest/api/Classes/Object.html for more information.")
            }
            if prop.value as? RealmOptionalProtocol != nil {
                throwRealmException("Property \(cls).\(label) has unsupported RealmOptional type \(type(of: prop.value)). Extending RealmOptionalType with custom types is not currently supported. ")
            }
            return nil
        }

        RLMValidateSwiftPropertyName(label)
        let valueType = type(of: value)

        let property = RLMProperty(name: label, value: value)
        property.indexed = indexedProperties.contains(property.name)
        property.columnName = columnNames?[property.name]

        if let objcProp = class_getProperty(cls, label) {
            var count: UInt32 = 0
            let attrs = property_copyAttributeList(objcProp, &count)!
            defer {
                free(attrs)
            }
            var computed = true
            for i in 0..<Int(count) {
                let attr = attrs[i]
                switch attr.name[0] {
                case Int8(UInt8(ascii: "R")): // Read only
                    return nil
                case Int8(UInt8(ascii: "V")): // Ivar name
                    computed = false
                case Int8(UInt8(ascii: "G")): // Getter name
                    property.getterName = String(cString: attr.value)
                case Int8(UInt8(ascii: "S")): // Setter name
                    property.setterName = String(cString: attr.value)
                default:
                    break
                }
            }

            // If there's no ivar name and no ivar with the same name as
            // the property then this is a computed property and we should
            // implicitly ignore it
            if computed && class_getInstanceVariable(cls, label) == nil {
                return nil
            }
        } else if valueType._rlmRequireObjc {
            // Implicitly ignore non-@objc dynamic properties
            return nil
        } else {
            property.swiftIvar = ivar_getOffset(class_getInstanceVariable(cls, label)!)
        }

        property.isLegacy = true
        property.updateAccessors()
        return property
    }
}

private func getProperties(_ cls: RLMObjectBase.Type) -> [RLMProperty] {
    // Check for any modern properties and only scan for legacy properties if
    // none are found.
    let object = cls.init()
    let props = getModernProperties(object)
    if props.count > 0 {
        return props
    }
    return getLegacyProperties(object, cls)
}

internal class ObjectUtil {
    private static let runOnce: Void = {
        RLMSwiftAsFastEnumeration = { (obj: Any) -> Any? in
            // Intermediate cast to AnyObject due to https://bugs.swift.org/browse/SR-8651
            if let collection = obj as AnyObject as? UntypedCollection {
                return collection.asNSFastEnumerator()
            }
            return nil
        }
        RLMSwiftBridgeValue = { (value: Any) -> Any? in
            if let value = value as? CustomObjectiveCBridgeable {
                return value.objCValue
            }
            if let value = value as? RealmEnum {
                return type(of: value)._rlmToRawValue(value)
            }
            return nil
        }
    }()

    internal class func getSwiftProperties(_ cls: RLMObjectBase.Type) -> [RLMProperty] {
        _ = ObjectUtil.runOnce
        return getProperties(cls)
    }
}
