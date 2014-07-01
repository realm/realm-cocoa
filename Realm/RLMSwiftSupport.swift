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

//
// Support Swift enumeration
//
extension RLMArray: Sequence {

    func generate() -> GeneratorOf<RLMObject> {
        var i  = 0
        return GeneratorOf<RLMObject>({
            if (i >= self.count) {
                return .None
            } else {
                return self[i++] as? RLMObject
            }
        })
    }
}

// index subscripting for ranges on string
// FIXME - put in an extension file
extension String {
    subscript (r: Range<Int>) -> String {
        get {
            let startIndex = advance(self.startIndex, r.startIndex)
            let endIndex = advance(startIndex, r.endIndex)

            return self[Range(start: startIndex, end: endIndex)]
        }
    }
}

@objc class RLMSwiftSupport {

    class func isSwiftClassName(className: NSString) -> Bool {
        return className.rangeOfString("^_T\\w{2}\\d+\\w+$", options: .RegularExpressionSearch).location != NSNotFound
    }

    class func demangleClassName(className: NSString) -> NSString {
        // Swift mangling details found here: http://www.eswick.com/2014/06/inside-swift
        // Swift class names look like _TFC9swifttest5Shape
        // Format: _T{2 characters}{module length}{module}{class length}{class}

        let originalName:String = className
        let originalNameLength = originalName.utf16count
        var cursor = 4
        var substring = originalName[cursor..originalNameLength-cursor]

        // Module
        let moduleLength = substring.bridgeToObjectiveC().integerValue
        let moduleLengthLength = "\(moduleLength)".utf16count
        let moduleName = substring[moduleLengthLength..moduleLength]

        // Update cursor and substring
        cursor += moduleLengthLength + moduleName.utf16count
        substring = originalName[cursor..originalNameLength-cursor]

        // Class name
        let classLength = substring.bridgeToObjectiveC().integerValue
        let classLengthLength = "\(classLength)".utf16count
        let className = substring[classLengthLength..classLength]

        return className
    }

    class func schemaForObjectClass(aClass: AnyClass) -> RLMObjectSchema {
        let className = demangleClassName(NSStringFromClass(aClass))

        let swiftObject = (aClass as RLMObject.Type)(emptyInRealm: nil)
        let reflection = reflect(swiftObject)
        let ignoredPropertiesForClass = aClass.ignoredProperties() as NSArray?

        var properties = RLMProperty[]()

        // Skip the first property (super):
        // super is an implicit property on Swift objects
        for i in 1..reflection.count {
            let propertyName = reflection[i].0
            if ignoredPropertiesForClass?.containsObject(propertyName) {
                continue
            }

            properties += createPropertyForClass(aClass,
                valueType: reflection[i].1.valueType,
                name: propertyName,
                column: properties.count,
                attr: aClass.attributesForProperty(propertyName))
        }

        return RLMObjectSchema(className: className as NSString?, objectClass: aClass, properties: properties)
    }

    class func createPropertyForClass(aClass: AnyClass,
                                      valueType: Any.Type,
                                      name: String,
                                      column: Int,
                                      attr: RLMPropertyAttributes) -> RLMProperty {
        var p:RLMProperty?
        var t:String?
        switch valueType {
            // Detect basic types (including optional versions)
            case is Bool.Type, is Bool?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Bool, column: column, objectClassName: nil, attributes: attr), "c")
            case is Int.Type, is Int?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Int, column: column, objectClassName: nil, attributes: attr), "i")
            case is Float.Type, is Float?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Float, column: column, objectClassName: nil, attributes: attr), "f")
            case is Double.Type, is Double?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Double, column: column, objectClassName: nil, attributes: attr), "d")
            case is String.Type, is String?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.String, column: column, objectClassName: nil, attributes: attr), "S")
            case is NSData.Type, is NSData?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Data, column: column, objectClassName: nil, attributes: attr), "@\"NSData\"")
            case is NSDate.Type, is NSDate?.Type:
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Date, column: column, objectClassName: nil, attributes: attr), "@\"NSDate\"")
            case let objectType as RLMObject.Type:
                assert(objectType.isKindOfClass(RLMObject))
                let mangledClassName = NSStringFromClass(objectType.self)
                let objectClassName = demangleClassName(mangledClassName)
                let typeEncoding = "@\"\(mangledClassName))\""
                (p, t) = (RLMProperty(name: name, type: RLMPropertyType.Object, column: column, objectClassName: objectClassName, attributes: attr), typeEncoding)
            case let c as RLMArray.Type:
                assert(false, "Not implemented")
            default:
                println("Can't persist property '\(name)' with incompatible type.\nAdd to ignoredPropertyNames: method to ignore.")
                assert(false)
        }

        // create objc property
        let attr = objc_property_attribute_t(name: "T", value: t!.bridgeToObjectiveC().UTF8String)
        class_addProperty(aClass, p!.name.bridgeToObjectiveC().UTF8String, [attr], 1)
        return p!
    }
}
