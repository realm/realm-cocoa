////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#if swift(>=3.0)

/**
 An object which is bound to a thread-specific Realm instance, and so cannot be passed between threads.

 Objects of classes conforming to this protocol can be packaged for transport between threads by calling
 `Realm.exportThreadHandover(packaging:)`. Note that only types defined by Realm can meaningfully conform
 to this protocol, and defining new classes which attempt to conform to it will not make them work with
 `exportThreadHandover`.
 */
@objc public protocol ThreadConfined {
    // FIXME: Remove `@objc` from protocol once SR-55 allows Swift protocol existentials to conform to themselves

    // Runtime-enforced requirement that type also conforms to `_ThreadConfined`
}

// Conformance to `_ThreadConfined` by `ThreadConfined` types cannot be verified by the typechecker or tests
internal protocol _ThreadConfined {
    var realm: Realm? { get }
    var bridgedData: RLMThreadConfined { get }
    var bridgedMetadata: Any? { get }
    static func bridge(data: RLMThreadConfined, metadata: Any?) -> Self
}

extension ThreadConfined {
    internal var backing: _ThreadConfined {
        if let object = self as? _ThreadConfined {
            return object
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(type(of: self))")
        }
    }

    static internal var backing: _ThreadConfined.Type {
        if let type = self as? _ThreadConfined.Type {
            return type
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self)")
        }
    }

    // Note: cannot be a protocol requirement since `Realm` is not an Objective-C type.
    /// The `Realm` the object is associated with.
    public var realm: Realm? {
        return backing.realm
    }
}

/// An object intended to be passed between threads containing information about objects being handed over
public class ThreadHandover<T: ThreadConfined> {
    private var metadata: [Any?]
    private var types: [ThreadConfined.Type]
    private let package: RLMThreadHandover

    internal init(realm: Realm, objects: [T]) {
        self.metadata = objects.map { $0.backing.bridgedMetadata }
        self.types = objects.map { type(of: $0) }
        self.package = realm.rlmRealm.exportThreadHandover(containing: objects.map { $0.backing.bridgedData })
    }

    /**
     Imports the handover package, creating an instance of the realm and objects on the current thread.

     - warning: This method may be not be called more than once on a given handover package. The realm version will
              remain pinned until this method is called or the object is deinitialized.

     - throws: An `NSError` if the Realm could not be initialized.

     - returns: A tuple containing a `Realm` instance and an `Array` of handed over objects associated with that `Realm`.
     */
    public func importOnCurrentThread() throws -> (Realm, [T]) {
        defer {
            metadata = []
            types = []
        }

        let handoverImport = try package.importOnCurrentThread()
        // Swift Arrays must be properly typed on index access, and `Object` does not conform to `RLMThreadConfined`
        let handoverables = unsafeBitCast(handoverImport.objects, to: [AnyObject].self)

        let objects: [T] = zip(types, zip(handoverables, metadata)).map { type, arguments in
            let handoverable = unsafeBitCast(arguments.0, to: RLMThreadConfined.self)
            let metadata = arguments.1
            return type.backing.bridge(data: handoverable, metadata: metadata) as! T
        }
        return (Realm(handoverImport.realm), objects)
    }
}

#else

/**
 An object which is bound to a thread-specific Realm instance, and so cannot be passed between threads.

 Objects of classes conforming to this protocol can be packaged for transport between threads by calling
 `Realm.exportThreadHandover(packaging:)`. Note that only types defined by Realm can meaningfully conform
 to this protocol, and defining new classes which attempt to conform to it will not make them work with
 `exportThreadHandover`.
 */
@objc public protocol ThreadConfined {
    // FIXME: Remove `@objc` from protocol once SR-55 allows Swift protocol existentials to conform to themselves

    // Runtime-enforced requirement that type also conforms to `_ThreadConfined`
}

// Conformance to `_ThreadConfined` by `ThreadConfined` types cannot be verified by the typechecker or tests
internal protocol _ThreadConfined {
    var realm: Realm? { get }
    var bridgedData: RLMThreadConfined { get }
    var bridgedMetadata: Any? { get }
    static func bridge(data: RLMThreadConfined, metadata: Any?) -> Self
}

extension ThreadConfined {
    internal var backing: _ThreadConfined {
        if let object = self as? _ThreadConfined {
            return object
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self.dynamicType)")
        }
    }

    static internal var backing: _ThreadConfined.Type {
        if let type = self as? _ThreadConfined.Type {
            return type
        } else {
            fatalError("Illegal custom conformances to `RLMThreadConfined` by \(self)")
        }
    }

    // Note: cannot be a protocol requirement since `Realm` is not an Objective-C type.
    /// The `Realm` the object is associated with.
    public var realm: Realm? {
        return backing.realm
    }
}

/// An object intended to be passed between threads containing information about objects being handed over
public class ThreadHandover<T: ThreadConfined> {
    private var metadata: [Any?]
    private var types: [ThreadConfined.Type]
    private let package: RLMThreadHandover

    internal init(realm: Realm, objects: [T]) {
        self.metadata = objects.map { $0.backing.bridgedMetadata }
        self.types = objects.map { $0.dynamicType }
        self.package = realm.rlmRealm.exportThreadHandover(containing: objects.map { $0.backing.bridgedData })
    }

    /**
     Imports the handover package, creating an instance of the realm and objects on the current thread.

     - warning: This method may be not be called more than once on a given handover package. The realm version will
     remain pinned until this method is called or the object is deinitialized.

     - throws: An `NSError` if the Realm could not be initialized.

     - returns: A tuple containing a `Realm` instance and an `Array` of handed over objects associated with that `Realm`.
     */
    public func importOnCurrentThread() throws -> (Realm, [T]) {
        defer {
            metadata = []
            types = []
        }

        let handoverImport = try package.importOnCurrentThread()
        // Swift Arrays must be properly typed on index access, and `Object` does not conform to `RLMThreadConfined`
        let handoverables = unsafeBitCast(handoverImport.objects, [AnyObject].self)

        let objects: [T] = zip(types, zip(handoverables, metadata)).map { type, arguments in
            let handoverable = unsafeBitCast(arguments.0, RLMThreadConfined.self)
            let metadata = arguments.1
            return type.backing.bridge(handoverable, metadata: metadata) as! T
        }
        return (Realm(handoverImport.realm), objects)
    }
}

#endif
