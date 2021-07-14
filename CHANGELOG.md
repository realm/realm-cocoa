x.y.z Release notes (yyyy-MM-dd)
=============================================================
### Enhancements
* Add two new property wrappers for opening a Realm asynchronously in a 
  SwiftUI View
    - `AsyncOpen` is a property wrapped that initiates Realm.asyncOpen 
       for the current user, notifying the view when there is a change in Realm asyncOpen state.
    - `AutoOpen` behaves similar to `AsyncOpen` but in case of no internet
       connection this will return an opened realm. 

### Fixed
* `RealmProperty<T?>` would crash when decoding a `null` json value.
  ([Cocoa #7323](https://github.com/realm/realm-cocoa/issues/7323), since v10.8.0)
* `@Persisted<T?>` would crash when decoding a `null` value.
  ([#7332](https://github.com/realm/realm-cocoa/issues/7332), since v10.10.0).

<!-- ### Breaking Changes - ONLY INCLUDE FOR NEW MAJOR version -->

### Compatibility
* Realm Studio: 11.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.1.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 2.

### Internal
* Upgraded realm-core from ? to ?

10.10.0 Release notes (2021-07-07)
=============================================================

### Enhancements

* Add a new property wrapper-based declaration syntax for properties on Realm
  Swift object classes. Rather than using `@objc dynamic` or the
  `RealmProperty` wrapper type, properties can now be declared with `@Persisted
  var property: T`, where `T` is any of the supported property types, including
  optional numbers and collections. This has a few benefits:

    - All property types are now declared in the same way. No more remembering
      that this type requires `@objc dynamic var` while this other type
      requires `let`, and the `RealmProperty` or `RealmOptional` helper is no
      longer needed for types not supported by Objective-C.
    - No more overriding class methods like `primaryKey()`,
      `indexedProperties()` or `ignoredProperties()`. The primary key and
      indexed flags are set directly in the property declaration with
      `@Persisted(primaryKey: true) _id: ObjectId` or `@Persisted(indexed:
      true) indexedProperty: Int`. If any `@Persisted` properties are present,
      all other properties are implicitly ignored.
    - Some performance problems have been fixed. Declaring collection
      properties as `let listProp = List<T>()` resulted in the `List<T>` object
      being created eagerly when the parent object is read, which could cause
      performance problems if a class has a large number of `List` or
      `RealmOptional` properties. `@Persisted var list: List<T>` allows us to
      defer creating the `List<T>` until it's accessed, improving performance
      when looping over objects and using only some of the properties.

      Similarly, `let _id = ObjectId.generate()` was a convenient way to
      declare a sync-compatible primary key, but resulted in new ObjectIds
      being generated in some scenarios where the value would never actually be
      used. `@Persisted var _id: ObjectId` has the same behavior of
      automatically generating primary keys, but allows us to only generate it
      when actually needed.
    - More types of enums are supported. Any `RawRepresentable` enum whose raw
      type is a type supported by Realm can be stored in an `@Persisted`
      project, rather than just `@objc` enums. Enums must be declared as
      conforming to the `PersistableEnum` protocol, and still cannot (yet) be
      used in collections.
    - `willSet` and `didSet` can be used with `@Persistable` properties, while
      they previously did not work on managed Realm objects.

  While we expect the switch to the new syntax to be very simple for most
  users, we plan to support the existing objc-based declaration syntax for the
  foreseeable future. The new style and old style cannot be mixed within a
  single class, but new classes can use the new syntax while existing classes
  continue to use the old syntax. Updating an existing class to the new syntax
  does not change what data is stored in the Realm file and so does not require
  a migration (as long as you don't also change the schema in the process, of
  course).
* Add `Map.merge()`, which adds the key-value pairs from another Map or
  Dictionary to the map.
* Add `Map.asKeyValueSequence()` which returns an adaptor that can be used with
  generic functions that operate on Dictionary-styled sequences.

### Fixed
* AnyRealmValue enum values are now supported in more places when creating
  objects.
* Declaring a property as `RealmProperty<AnyRealmValue?>` will now report an
  error during schema discovery rather than doing broken things when the
  property is used.
* Observing the `invalidated` property of `RLMDictionary`/`Map` via KVO did not
  set old/new values correctly in the notification (since 10.8.0).

### Compatibility

* Realm Studio: 11.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.1.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 2.

10.9.0 Release notes (2021-07-01)
=============================================================

### Enhancements

* Add `App.emailPasswordAuth.retryCustomConfirmation(email:completion:)` and
  `[App.emailPasswordAuth retryCustomConfirmation:completion:]`. These
  functions support retrying a [custom confirmation](https://docs.mongodb.com/realm/authentication/email-password/#run-a-confirmation-function)
  function.
* Improve performance of many Dictionary operations, especially when KVO is being used.

### Fixed

* Calling `-[RLMRealm deleteObjects:]` on a `RLMDictionary` cleared the
  dictionary but did not actually delete the objects in the dictionary (since v10.8.0).
* Rix an assertion failure when observing a `List<AnyRealmValue>` contains
  object links. ([Core #4767](https://github.com/realm/realm-core/issues/4767), since v10.8.0)
* Fix an assertion failure when observing a `RLMDictionary`/`Map` which links
  to an object which was deleting by a different sync client.
  ([Core #4770](https://github.com/realm/realm-core/pull/4770), since v10.8.0)
* Fix an endless recursive loop that could cause a stack overflow when
  computing changes on a set of objects which contained cycles.
  ([Core #4770](https://github.com/realm/realm-core/pull/4770), since v10.8.0).
* Hash collisions in dictionaries were not handled properly.
  ([Core #4776](https://github.com/realm/realm-core/issues/4776), since v10.8.0).
* Fix a crash after clearing a list or set of AnyRealmValue containing links to
  objects ([Core #4774](https://github.com/realm/realm-core/issues/4774), since v10.8.0)
* Trying to refresh a user token which had been revoked by an admin lead to an
  infinite loop and then a crash. This situation now properly logs the user out
  and reports an error. ([Core #4745](https://github.com/realm/realm-core/issues/4745), since v10.0.0).

### Compatibility

* Realm Studio: 11.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.1.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 2.

### Internal

* Upgraded realm-core from v11.0.3 to v11.0.4

10.8.1 Release notes (2021-06-22)
=============================================================

### Enhancements

* Update Xcode 12.5 to Xcode 12.5.1.
* Create fewer dynamic classes at runtime, improving memory usage and startup time slightly.

### Fixed

* Importing the Realm swift package produced several warnings about excluded
  files not existing. Note that one warning will still remain after this change.
  ([#7295](https://github.com/realm/realm-cocoa/issues/7295), since v10.8.0).
* Update the root URL for the API docs so that the links go to the place where
  new versions of the docs are being published.
  ([#7299](https://github.com/realm/realm-cocoa/issues/7299), since v10.6.0).

### Compatibility

* Realm Studio: 11.0.0 or later. Note that this version of Realm Studio has not
  yet been released at the time of this release.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.1.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 1.

10.8.0 Release notes (2021-06-14)
=============================================================

NOTE: This version upgrades the Realm file format version to add support for
the new data types and to adjust how primary keys are handled. Realm files
opened will be automatically upgraded and cannot be read by versions older than
v10.8.0. This upgrade should be a fairly fast one. Note that we now
automatically create a backup of the pre-upgrade Realm.

### Enhancements

* Add support for the `UUID` and `NSUUID` data types. These types can be used
  for the primary key property of Object classes.
* Add two new collection types to complement the existing `RLMArray`/`List` type:
  - `RLMSet<T>` in Objective-C and `MutableSet<T>` in Swift are mutable
    unordered collections of distinct objects, similar to the built-in
    `NSMutableSet` and `Set`. The values in a set may be any non-collection
    type which can be stored as a Realm property. Sets are guaranteed to never
    contain two objects which compare equal to each other, including when
    conflicting writes are merged by sync.
  - `RLMDictionary<NSString *, T>` in Objective-C and `Map<String, T>` are
    mutable key-value dictionaries, similar to the built-in
    `NSMutableDictionary` and `Dictionary`. The values in a dictionary may be
    any non-collection type which can be stored as a Realm property. The keys
    must currently always be a string.
* Add support for dynamically typed properties which can store a value of any
  of the non-collection types supported by Realm, including Object subclasses
  (but not EmbeddedObject subclasses). These are declared with
  `@property id<RLMValue> propertyName;` in Objective-C and
  `let propertyName = RealmProperty<AnyRealmValue>()` in Swift.

### Fixed

* Setting a collection with a nullable value type to null via one of the
  dynamic interfaces would hit an assertion failure instead of clearing the
  collection.
* Fixed an incorrect detection of multiple incoming links in a migration when
  changing a table to embedded and removing a link to it at the same time.
  ([#4694](https://github.com/realm/realm-core/issues/4694) since v10.0.0-beta.2)
* Fixed a divergent merge on Set when one client clears the Set and another
  client inserts and deletes objects.
  ([#4720](https://github.com/realm/realm-core/issues/4720))
* Partially revert to pre-v5.0.0 handling of primary keys to fix a performance
  regression. v5.0.0 made primary keys determine the position in the low-level
  table where newly added objects would be inserted, which eliminated the need
  for a separate index on the primary key. This made some use patterns slightly
  faster, but also made some reasonable things dramatically slower.
  ([#4522](https://github.com/realm/realm-core/issues/4522))
* Fixed an incorrect detection of multiple incoming links in a migration when
  changing a table to embedded and removing a link to it at the same time.
  ([#4694](https://github.com/realm/realm-core/issues/4694) since v10.0.0-beta.2)
* Fix collection notification reporting for modifications. This could be
  observed by receiving the wrong indices of modifications on sorted or
  distinct results, or notification blocks sometimes not being called when only
  modifications have occured.
  ([#4573](https://github.com/realm/realm-core/pull/4573) since v5.0.0).
* Fix incorrect sync instruction emission when replacing an existing embedded
  object with another embedded object.([Core #4740](https://github.com/realm/realm-core/issues/4740)

### Deprecations

* `RealmOptional<T>` has been deprecated in favor of `RealmProperty<T?>`.
  `RealmProperty` is functionality identical to `RealmOptional` when storing
  optional numeric types, but can also store the new `AnyRealmValue` type.

### Compatibility

* Realm Studio: 11.0.0 or later. Note that this version of Realm Studio has not
  yet been released at the time of this release.
* Carthage release for Swift is built with Xcode 12.5.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 1.

### Internal

* Upgraded realm-core from v10.7.2 to v11.0.3

10.8.0-beta.2 Release notes (2021-06-01)
=============================================================

### Enhancements

* Add `RLMDictionary`/`Map<>` datatype. This is a Dictionary collection type used for storing key-value pairs in a collection.

### Compatibility

* Realm Studio: 11.0.0-beta.1 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v11.0.0-beta.4 to v11.0.0-beta.6

10.8.0-beta.0 Release notes (2021-05-07)
=============================================================

### Enhancements

* Add `RLMSet`/`MutableSet<>` datatype. This is a Set collection type used for storing distinct values in a collection.
* Add support for `id<RLMValue>`/`AnyRealmValue`.
* Add support for `UUID`/`NSUUID` data type.

### Fixed

* None.

### Deprecations

* `RealmOptional` has been deprecated in favor of `RealmProperty`.

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.7.2 to v10.8.0-beta.5

10.7.7 Release notes (2021-06-10)
=============================================================

Xcode 12.2 is now the minimum supported version.

### Enhancements

* Add Xcode 13 beta 1 binaries to the release package.

### Fixed

* Fix a runtime crash which happens in some Xcode version (Xcode < 12, reported
  in Xcode 12.5), where SwiftUI is not weak linked by default. This fix only
  works for Cocoapods projects.
  ([#7234](https://github.com/realm/realm-cocoa/issues/7234)
* Fix warnings when building with Xcode 13 beta 1.

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.
* CocoaPods: 1.10 or later.
* Xcode: 12.2-13.0 beta 1.

10.7.6 Release notes (2021-05-13)
=============================================================

### Enhancements

* Realms opened in read-only mode can now be invalidated (although it is
  unlikely to be useful to do so).

### Fixed

* Fix an availability warning when building Realm. The code path which gave the
  warning can not currently be hit, so this did not cause any runtime problems
  ([#7219](https://github.com/realm/realm-cocoa/issues/7219), since 10.7.3).
* Proactively check the expiry time on the access token and refresh it before
  attempting to initiate a sync session. This prevents some error logs from
  appearing on the client such as: "ERROR: Connection[1]: Websocket: Expected
  HTTP response 101 Switching Protocols, but received: HTTP/1.1 401
  Unauthorized" ([RCORE-473](https://jira.mongodb.org/browse/RCORE-473), since v10.0.0)
* Fix a race condition which could result in a skipping notifications failing
  to skip if several commits using notification skipping were made in
  succession (since v5.0.0).
* Fix a crash on exit inside TableRecycler which could happen if Realms were
  open on background threads when the app exited.
  ([Core #4600](https://github.com/realm/realm-core/issues/4600), since v5.0.0)
* Fix errors related to "uncaught exception in notifier thread:
  N5realm11KeyNotFoundE: No such object" which could happen on sycnronized
  Realms if a linked object was deleted by another client.
  ([JS #3611](https://github.com/realm/realm-js/issues/3611), since v10.0.0).
* Reading a link to an object which has been deleted by a different client via
  a string-based interface (such as value(forKey:) or the subscript operator on
  DynamicObject) could return an invalid object rather than nil.
  ([Core #4687](https://github.com/realm/realm-core/pull/4687), since v10.0.0)
* Recreate the sync metadata Realm if the encryption key for it is missing from
  the keychain rather than crashing. This can happen if a device is restored
  from an unencrypted backup, which restores app data but not the app's
  keychain entries, and results in all cached logics for sync users being
  discarded but no data being lost.
  [Core #4285](https://github.com/realm/realm-core/pull/4285)
* Thread-safe references can now be created for read-only Realms.
  ([#5475](https://github.com/realm/realm-cocoa/issues/5475)).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.6.0 to v10.7.2

10.7.5 Release notes (2021-05-07)
=============================================================

### Fixed

* Iterating over frozen collections on multiple threads at the same time could
  throw a "count underflow" NSInternalInconsistencyException.
  ([#7237](https://github.com/realm/realm-cocoa/issues/7237), since v5.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.
* CocoaPods: 1.10 or later.

10.7.4 Release notes (2021-04-26)
=============================================================

### Enhancements

* Add Xcode 12.5 binaries to the release package.

### Fixed

* Add the Info.plist file to the XCFrameworks in the Carthage xcframwork
  package ([#7216](https://github.com/realm/realm-cocoa/issues/7216), since 10.7.3).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.5.
* CocoaPods: 1.10 or later.

10.7.3 Release notes (2021-04-22)
=============================================================

### Enhancements

* Package a prebuilt XCFramework for Carthage. Carthage 0.38 and later will
  download this instead of the old frameworks when using `--use-xcframeworks`.
* We now make a backup of the realm file prior to any file format upgrade. The
  backup is retained for 3 months. Backups from before a file format upgrade
  allows for better analysis of any upgrade failure. We also restore a backup,
  if a) an attempt is made to open a realm file whith a "future" file format
  and b) a backup file exist that fits the current file format.
  ([Core #4166](https://github.com/realm/realm-core/pull/4166))
* The error message when the intial steps of opening a Realm file fails is now
  more descriptive.
* Make conversion of Decimal128 to/from string work for numbers with more than
  19 significant digits. This means that Decimal128's initializer which takes a
  string will now never throw, as it previously threw only for out-of-bounds
  values. The initializer is still marked as `throws` for
  backwards compatibility.
  ([#4548](https://github.com/realm/realm-core/issues/4548))

### Fixed

* Adjust the header paths for the podspec to avoid accidentally finding a file
  which isn't part of the pod that produced warnings when importing the
  framework. ([#7113](https://github.com/realm/realm-cocoa/issues/7113), since 10.5.2).
* Fixed a crash that would occur when observing unmanaged Objects in multiple
  views in SwiftUI. When using `@StateRealmObject` or `@ObservedObject` across
  multiple views with an unmanaged object, each view would subscribe to the
  object. As each view unsubscribed (generally when trailing back through the
  view stack), our propertyWrappers would attempt to remove the KVOs for each
  cancellation, when it should only be done once. We now correctly remove KVOs
  only once. ([#7131](https://github.com/realm/realm-cocoa/issues/7131))
* Fixed `isInvalidated` not returning correct value after object deletion from
  Realm when using a custom schema. The object's Object Schema was not updated
  when the object was added to the realm. We now correctly update the object
  schema when adding it to the realm.
  ([#7181](https://github.com/realm/realm-cocoa/issues/7181))
* Syncing large Decimal128 values would cause "Assertion failed: cx.w[1] == 0"
  ([Core #4519](https://github.com/realm/realm-core/issues/4519), since v10.0.0).
* Potential/unconfirmed fix for crashes associated with failure to memory map
  (low on memory, low on virtual address space). For example
  ([#4514](https://github.com/realm/realm-core/issues/4514), since v5.0.0).
* Fix assertion failures such as "!m_notifier_skip_version.version" or
  "m_notifier_sg->get_version() + 1 == new_version.version" when performing
  writes inside change notification callbacks. Previously refreshing the Realm
  by beginning a write transaction would skip delivering notifications, leaving
  things in an inconsistent state. Notifications are now delivered recursively
  when needed instead. ([Cocoa #7165](https://github.com/realm/realm-cocoa/issues/7165)).
* Fix collection notification reporting for modifications. This could be
  observed by receiving the wrong indices of modifications on sorted or
  distinct results, or notification blocks sometimes not being called when only
  modifications have occured.
  ([#4573](https://github.com/realm/realm-core/pull/4573) since v5.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.5.5 to v10.6.0
* Add additional debug validation to file map management that will hopefully
  catch cases where we unmap something which is still in use.

10.7.2 Release notes (2021-03-08)
=============================================================

### Fixed

* During integration of a large amount of data from the server, you may get
  "Assertion failed: !fields.has_missing_parent_update()"
  ([Core #4497](https://github.com/realm/realm-core/issues/4497), since v6.0.0)

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.5.4 to v10.5.5

10.7.1 Release notes (2021-03-05)
=============================================================

### Fixed

* Queries of the form "a.b.c == nil" would match objects where `b` is `nil` if
  `c` did not have an index and did not if `c` was indexed. Both will now match
  to align with NSPredicate's behavior. ([Core #4460]https://github.com/realm/realm-core/pull/4460), since 4.3.0).
* Restore support for upgrading files from file format 5 (Realm Cocoa 1.x).
  ([Core #7089](https://github.com/realm/realm-cocoa/issues/7089), since v5.0.0)
* On 32bit devices you may get exception with "No such object" when upgrading
  to v10.* ([Java #7314](https://github.com/realm/realm-java/issues/7314), since v5.0.0)
* The notification worker thread would rerun queries after every commit rather
  than only commits which modified tables which could effect the query results
  if the table had any outgoing links to tables not used in the query.
  ([Core #4456](https://github.com/realm/realm-core/pull/4456), since v5.0.0).
* Fix "Invalid ref translation entry [16045690984833335023, 78187493520]"
  assertion failure which could occur when using sync or multiple processes
  writing to a single Realm file.
  ([#7086](https://github.com/realm/realm-cocoa/issues/7086), since v5.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.5.3 to v10.5.4

10.7.0 Release notes (2021-02-23)
=============================================================

### Enhancements

* Add support for some missing query operations on data propertys:
  - Data properties can be compared to other data properties
    (e.g. "dataProperty1 == dataProperty2").
  - Case and diacritic-insensitive queries can be performed on data properties.
    This will only have meaningful results if the data property contains UTF-8
    string data.
  - Data properties on linked objects can be queried
    (e.g. "link.dataProperty CONTAINS %@")
* Implement queries which filter on lists other than object links (lists of
  objects were already supported). All supported operators for normal
  properties are now supported for lists (e.g. "ANY intList = 5" or "ANY
  stringList BEGINSWITH 'prefix'"), as well as aggregate operations on the
  lists (such as "intArray.@sum > 100").
* Performance of sorting on more than one property has been improved.
  Especially important if many elements match on the first property. Mitigates
  ([#7092](https://github.com/realm/realm-cocoa/issues/7092))

### Fixed

* Fixed a bug that prevented an object type with incoming links from being
  marked as embedded during migrations. ([Core #4414](https://github.com/realm/realm-core/pull/4414))
* The Realm notification listener thread could sometimes hit the assertion
  failure "!skip_version.version" if a write transaction was committed at a
  very specific time (since v10.5.0).
* Added workaround for a case where upgrading an old file with illegal string
  would crash ([#7111](https://github.com/realm/realm-cocoa/issues/7111))
* Fixed a conflict resolution bug related to the ArrayMove instruction, which
  could sometimes cause an "Invalid prior_size" exception to prevent
  synchronization (since v10.5.0).
* Skipping a change notification in the first write transaction after the
  observer was added could potentially fail to skip the notification (since v10.5.1).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.5.0 to v10.5.3

10.6.0 Release notes (2021-02-15)
=============================================================

### Enhancements

* Add `@StateRealmObject` for SwiftUI support. This property wrapper type instantiates an observable object on a View. 
  Use in place of `SwiftUI.StateObject` for Realm `Object`, `List`, and `EmbeddedObject` types.
* Add `@ObservedRealmObject` for SwiftUI support. This property wrapper type subscribes to an observable object
  and invalidates a view whenever the observable object changes. Use in place of `SwiftUI.ObservedObject` for
  Realm `Object`, `List`, or `EmbeddedObject` types.
* Add `@ObservedResults` for SwiftUI support. This property wrapper type retrieves results from a Realm.
  The results use the realm configuration provided by the environment value `EnvironmentValues.realmConfiguration`.
* Add `EnvironmentValues.realm` and `EnvironmentValues.realmConfiguration` for `Realm`
  and `Realm.Configuration` types respectively. Values can be injected into views using the `View.environment` method, e.g., `MyView().environment(\.realmConfiguration, Realm.Configuration(fileURL: URL(fileURLWithPath: "myRealmPath.realm")))`. 
  The value can then be declared on the example `MyView` as `@Environment(\.realm) var realm`.
* Add `SwiftUI.Binding` extensions where `Value` is of type `Object`, `List`, or `EmbeddedObject`. 
  These extensions expose methods for wrapped write transactions, to avoid boilerplate within 
  views, e.g., `TextField("name", $personObject.name)` or `$personList.append(Person())`.
* Add `Object.bind` and `EmbeddedObject.bind` for SwiftUI support. This allows you to create 
  bindings of realm properties when a propertyWrapper is not available for you to do so, e.g., `TextField("name", personObject.bind(\.name))`.
* The Sync client now logs error messages received from server rather than just
  the size of the error message.
* Errors returned from the server when sync WebSockets get closed are now
  captured and surfaced as a SyncError.
* Improve performance of sequential reads on a Results backed directly by a
  Table (i.e. `realm.object(ClasSName.self)` with no filter/sort/etc.) by 50x.
* Orphaned embedded object types which are not linked to by any top-level types
  are now better handled. Previously the server would reject the schema,
  resulting in delayed and confusing error reporting. Explicitly including an
  orphan in `objectTypes` is now immediately reported as an error when opening
  the Realm, and orphans are automatically excluded from the auto-discovered
  schema when `objectTypes` is not specified.

### Fixed

* Reading from a Results backed directly by a Table (i.e.
  `realm.object(ClasSName.self)` with no filter/sort/etc.) would give incorrect
  results if the Results was constructed and accessed before creating a new
  object with a primary key less than the smallest primary key which previously
  existed. ([#7014](https://github.com/realm/realm-cocoa/issues/7014), since v5.0.0).
* During synchronization you might experience crash with
  "Assertion failed: ref + size <= next->first".
  ([Core #4388](https://github.com/realm/realm-core/issues/4388))

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.4.0 to v10.5.0

10.5.2 Release notes (2021-02-09)
=============================================================

### Enhancements

* Add support for "thawing" objects. `Realm`, `Results`, `List` and `Object`
  now have `thaw()` methods which return a live copy of the frozen object. This
  enables app behvaior where a frozen object can be made live again in order to
  mutate values. For example, first freezing an object passed into UI view,
  then thawing the object in the view to update values.
* Add Xcode 12.4 binaries to the release package.

### Fixed

* Inserting a date into a synced collection via `AnyBSON.datetime(...)` would
  be of type `Timestamp` and not `Date`. This could break synced objects with a
  `Date` property.
  ([#6654](https://github.com/realm/realm-cocoa/issues/6654), since v10.0.0).
* Fixed an issue where creating an object after file format upgrade may fail
  with assertion "Assertion failed: lo() <= std::numeric_limits<uint32_t>::max()"
  ([#4295](https://github.com/realm/realm-core/issues/4295), since v5.0.0)
* Allow enumerating objects in migrations with types which are no longer
  present in the schema.
* Add `RLMResponse.customStatusCode`. This fixes timeout exceptions that were
  occuring with a poor connection. ([#4188](https://github.com/realm/realm-core/issues/4188))
* Limit availability of ObjectKeyIdentifiable to platforms which support
  Combine to match the change made in the Xcode 12.5 SDK.
  ([#7083](https://github.com/realm/realm-cocoa/issues/7083))

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.4.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.3.3 to v10.4.0

10.5.1 Release notes (2021-01-15)
=============================================================

### Enhancements

* Add Xcode 12.3 binary to release package.
* Add support for queries which have nil on the left side and a keypath on the
  right side (e.g. "nil == name" rather than "name == nil" as was previously
  required).

### Fixed
* Timeouts when calling server functions via App would sometimes crash rather
  than report an error.
* Fix a race condition which would lead to "uncaught exception in notifier
  thread: N5realm15InvalidTableRefE: transaction_ended" and a crash when the
  source Realm was closed or invalidated at a very specific time during the
  first run of a collection notifier
  ([#3761](https://github.com/realm/realm-core/issues/3761), since v5.0.0).
* Deleting and recreating objects with embedded objects may fail.
  ([Core PR #4240](https://github.com/realm/realm-core/pull/4240), since v10.0.0)
* Fast-enumerating a List after deleting the parent object would crash with an
  assertion failure rather than a more appropriate exception.
  ([Core #4114](https://github.com/realm/realm-core/issues/4114), since v5.0.0).
* Fix an issue where calling a MongoDB Realm Function would never be performed as the reference to the weak `User` was lost.

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.3.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.3.2 to v10.3.3

10.5.0 Release notes (2020-12-14)
=============================================================

### Enhancements

* MongoDB Realm is now supported when installing Realm via Swift Package Manager.

### Fixed

* The user identifier was added to the file path for synchronized Realms twice
  and an extra level of escaping was performed on the partition value. This did
  not cause functional problems, but made file names more confusing than they
  needed to be. Existing Realm files will continue to be located at the old
  path, while newly created files will be created at a shorter path. (Since v10.0.0).
* Fix a race condition which could potentially allow queries on frozen Realms
  to access an uninitialized structure for search indexes (since v5.0.0).
* Fix several data races in App and SyncSession initialization. These could
  possibly have caused strange errors the first time a synchronized Realm was
  opened (since v10.0.0).
* Fix a use of a dangling reference when refreshing a user’s custom data that
  could lead to a crash (since v10.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.2.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.1.4 to v10.3.2

10.4.0 Release notes (2020-12-10)
=============================================================

### Enhancements

* Add Combine support for App and User. These two types now have a
  `objectWillChange` property that emits each time the state of the object has
  changed (such as due to the user logging in or out). ([PR #6977](https://github.com/realm/realm-cocoa/pull/6977)).

### Fixed

* Integrating changsets from the server would sometimes hit the assertion
  failure "n != realm::npos" inside Table::create_object_with_primary_key()
  when creating an object with a primary key which previously had been used and
  had incoming links. ([Core PR #4180](https://github.com/realm/realm-core/pull/4180), since v10.0.0).
* The arm64 simulator slices were not actually included in the XCFramework
  release package. ([PR #6982](https://github.com/realm/realm-cocoa/pull/6982), since v10.2.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.2.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.1.3 to v10.1.4
* Upgraded realm-sync from v10.1.4 to v10.1.5

10.3.0 Release notes (2020-12-08)
=============================================================

### Enhancements

* Add Google OpenID Connect Credentials, an alternative login credential to the
  Google OAuth 2.0 credential.

### Fixed

* Fixed a bug that would prevent eventual consistency during conflict
  resolution. Affected clients would experience data divergence and potentially
  consistency errors as a result if they experienced conflict resolution
  between cycles of Create-Erase-Create for objects with primary keys (since v10.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.2.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-sync from v10.1.3 to v10.1.4

10.2.0 Release notes (2020-12-02)
=============================================================

### Enhancements

* The prebuilt binaries are now packaged as XCFrameworks. This adds support for
  Catalyst and arm64 simulators when using them to install Realm, removes the
  need for the strip-frameworks build step, and should simplify installation.
* The support functionality for using the Objective C API from Swift is now
  included in Realm Swift and now includes all of the required wrappers for
  MongoDB Realm types. In mixed Objective C/Swift projects, we recommend
  continuing to use the Objective C types, but import both Realm and RealmSwift
  in your Swift files.

### Fixed

* The user identifier was added to the file path for synchronized Realms twice
  and an extra level of escaping was performed on the partition value. This did
  not cause functional problems, but made file names more confusing than they
  needed to be. Existing Realm files will continue to be located at the old
  path, while newly created files will be created at a shorter path. (Since v10.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.2.
* CocoaPods: 1.10 or later.

10.1.4 Release notes (2020-11-16)
=============================================================

### Enhancements

* Add arm64 slices to the macOS builds.

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.2.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.0.1 to v10.1.3
* Upgraded realm-sync from v10.0.1 to v10.1.3

10.1.3 Release notes (2020-11-13)
=============================================================

### Enhancements

* Add Xcode 12.2 binaries to the release package.

### Fixed

* Disallow setting
  `RLMRealmConfiguration.deleteRealmIfMigrationNeeded`/`Realm.Config.deleteRealmIfMigrationNeeded`
  when sync is enabled. This did not actually work as it does not delete the
  relevant server state and broke in confusing ways ([PR #6931](https://github.com/realm/realm-cocoa/pull/6931)).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.1.
* CocoaPods: 1.10 or later.

10.1.2 Release notes (2020-11-06)
=============================================================

### Enhancements

* Some error states which previously threw a misleading "NoSuchTable" exception
  now throw a more descriptive exception.

### Fixed

* One of the Swift packages did not have the minimum deployment target set,
  resulting in errors when archiving an app which imported Realm via SPM.
* Reenable filelock emulation on watchOS so that the OS does not kill the app
  when it is suspended while a Realm is open on watchOS 7 ([#6861](https://github.com/realm/realm-cocoa/issues/6861), since v5.4.8
* Fix crash in case insensitive query on indexed string columns when nothing
  matches ([#6836](https://github.com/realm/realm-cocoa/issues/6836), since v5.0.0).
* Null values in a `List<Float?>` or `List<Double?>` were incorrectly treated
  as non-null in some places. It is unknown if this caused any functional
  problems when using the public API. ([Core PR #3987](https://github.com/realm/realm-core/pull/3987), since v5.0.0).
* Deleting an entry in a list in two different clients could end deleting the
  wrong entry in one client when the changes are merged (since v10.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.1.
* CocoaPods: 1.10 or later.

### Internal

* Upgraded realm-core from v10.0.0 to v10.1.1
* Upgraded realm-sync from v10.0.0 to v10.1.1

10.1.1 Release notes (2020-10-27)
=============================================================

### Enhancements

* Set the minimum CocoaPods version in the podspec so that trying to install
  with older versions gives a more useful error ([PR #6892](https://github.com/realm/realm-cocoa/pull/6892)).

### Fixed

* Embedded objects could not be marked as `ObjectKeyIdentifable`
  ([PR #6890](https://github.com/realm/realm-cocoa/pull/6890), since v10.0.0).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.1.
* CocoaPods: 1.10 or later.

10.1.0 Release notes (2020-10-22)
=============================================================

CocoaPods 1.10 or later is now required to install Realm.

### Enhancements

* Throw an exception for Objects that have none of its properties marked with @objc.
* Mac Catalyst and arm64 simulators are now supported when integrating via Cocoapods.
* Add Xcode 12.1 binaries to the release package.
* Add Combine support for `Realm.asyncOpen()`.

### Fixed

* Implement precise and unbatched notification of sync completion events. This
  avoids a race condition where an earlier upload completion event will notify
  a later waiter whose changes haven't been uploaded yet.
  ([#1118](https://github.com/realm/realm-object-store/pull/1118)).

### Compatibility

* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.1.

10.0.0 Release notes (2020-10-16)
=============================================================

This release is functionally identical to v10.0.0-rc.2.

NOTE: This version upgrades the Realm file format version to add support for
new data types. Realm files opened will be automatically upgraded and cannot be
read by versions older than v10.0.0.

### Breaking Changes

* Rename Realm.Publishers to RealmPublishers to avoid confusion with Combine.Publishers.
* Remove `[RLMSyncManager shared]`. This is now instatiated as a property on App/RLMApp.
* `RLMSyncManager.pinnedCertificatePaths` has been removed.
* Classes `RLMUserAccountInfo` & `RLMUserInfo` (swift: `UserInfo`, `UserAccountInfo`) have been removed.
* `RLMSyncUser`/`SyncUser` has been renamed to `RLMUser`/`User`.
* We no longer support Realm Cloud (legacy), but instead the new "MongoDB
  Realm" Cloud. MongoDB Realm is a serverless platform that enables developers
  to quickly build applications without having to set up server infrastructure.
  MongoDB Realm is built on top of MongoDB Atlas, automatically integrating the
  connection to your database.
* Remove support for Query-based sync, including the configuration parameters
  and the `RLMSyncSubscription` and `SyncSubscription` types ([#6437](https://github.com/realm/realm-cocoa/pull/6437)).
* Remove everything related to sync permissions, including both the path-based
  permission system and the object-level privileges for query-based sync.
  Permissions are now configured via MongoDB Atlas.
  ([#6445](https://github.com/realm/realm-cocoa/pulls/6445))
* Remove support for Realm Object Server.
* Non-embedded objects in synchronized Realms must always have a primary key
  named "_id".
* All Swift callbacks for asynchronous operations which can fail are now passed
  a `Result<Value, Error>` parameter instead of two separate `Value?` and
  `Error?` parameters.

### Enhancements

* Add support for next generation sync. Support for syncing to MongoDB instead
  of Realm Object Server. Applications must be created at realm.mongodb.com
* The memory mapping scheme for Realm files has changed to better support
  opening very large files.
* Add support for the ObjectId data type. This is an automatically-generated
  unique identifier similar to a GUID or a UUID.
  ([PR #6450](https://github.com/realm/realm-cocoa/pull/6450)).
* Add support for the Decimal128 data type. This is a 128-bit IEEE 754 decimal
  floating point number similar to NSDecimalNumber.
  ([PR #6450](https://github.com/realm/realm-cocoa/pull/6450)).
* Add support for embedded objects. Embedded objects are objects which are
  owned by a single parent object, and are deleted when that parent object is
  deleted. They are defined by subclassing `EmbeddedObject` /
  `RLMEmbeddedObject` rather than `Object` / `RLMObject`.
* Add `-[RLMUser customData]`/`User.customData`. Custom data is
  configured in your MongoDB Realm App.
* Add `-[RLMUser callFunctionNamed:arguments:completion:]`/`User.functions`.
  This is the entry point for calling Remote MongoDB Realm functions. Functions
  allow you to define and execute server-side logic for your application.
  Functions are written in modern JavaScript (ES6+) and execute in a serverless
  manner. When you call a function, you can dynamically access components of
  the current application as well as information about the request to execute
  the function and the logged in user that sent the request.
* Add `-[RLMUser mongoClientWithServiceName:]`/`User.mongoClient`. This is
  the entry point for calling your Remote MongoDB Service. The read operations
  are `-[RLMMongoCollection findWhere:completion:]`, `-[RLMMongoCollection
  countWhere:completion:]`and `-[RLMMongoCollection
  aggregateWithPipeline:completion:]`. The write operations are
  `-[RLMMongoCollection insertOneDocument:completion:]`, `-[RLMMongoCollection
  insertManyDocuments:completion:]`, `-[RLMMongoCollection
  updateOneDocument:completion:]`, `-[RLMMongoCollection
  updateManyDocuments:completion:]`, `-[RLMMongoCollection
  deleteOneDocument:completion:]`, and `-[RLMMongoCollection
  deleteManyDocuments:completion:]`. If you are already familiar with MongoDB
  drivers, it is important to understand that the remote MongoCollection only
  provides access to the operations available in MongoDB Realm.
* Obtaining a Realm configuration from a user is now done with `[RLMUser
  configurationWithPartitionValue:]`/`User.configuration(partitionValue:)`.
  Partition values can currently be of types `String`, `Int`, or `ObjectId`,
  and fill a similar role to Realm URLs did with Realm Cloud.  The main
  difference is that partitions are meant to be more closely associated with
  your data.  For example, if you are running a `Dog` kennel, and have a field
  `breed` that acts as your partition key, you could open up realms based on
  the breed of the dogs.
* Add ability to stream change events on a remote MongoDB collection with
  `[RLMMongoCollection watch:delegate:delegateQueue:]`,
  `MongoCollection.watch(delegate:)`. When calling `watch(delegate:)` you will be
  given a `RLMChangeStream` (`ChangeStream`) which can be used to end watching
  by calling `close()`. Change events can also be streamed using the
  `MongoCollection.watch` Combine publisher that will stream change events each
  time the remote MongoDB collection is updated.
* Add the ability to listen for when a Watch Change Stream is opened when using
  Combine. Use `onOpen(event:)` directly after opening a `WatchPublisher` to
  register a callback to be invoked once the change stream is opened.
* Objects with integer primary keys no longer require a separate index for the
* primary key column, improving insert performance and slightly reducing file
  size.

### Compatibility

* Realm Studio: 10.0.0 or later.
* Carthage release for Swift is built with Xcode 12

### Internal

* Upgraded realm-core from v6.1.4 to v10.0.0
* Upgraded realm-sync from v5.0.29 to v10.0.0

10.0.0-rc.2 Release notes (2020-10-15)
=============================================================

### Enhancements

* Add the ability to listen for when a Watch Change Stream is opened when using
  Combine. Use `onOpen(event:)` directly after opening a `WatchPublisher` to
  register a callback to be invoked once the change stream is opened.

### Breaking Changes

* The insert operations on Mongo collections now report the inserted documents'
  IDs as BSON rather than ObjectId.
* Embedded objects can no longer form cycles at the schema level. For example,
  type A can no longer have an object property of type A, or an object property
  of type B if type B links to type A. This was always rejected by the server,
  but previously was allowed in non-synchronized Realms.
* Primary key properties are once again marked as being indexed. This reflects
  an internal change to how primary keys are handled that should not have any
  other visible effects.
* Change paired return types from Swift completion handlers to return `Result<Value, Error>`.
* Adjust how RealmSwift.Object is defined to add support for Swift Library
  Evolution mode. This should normally not have any effect, but you may need to
  add `override` to initializers of object subclasses.
* Add `.null` type to AnyBSON. This creates a distinction between null values
  and properly absent BSON types.

### Fixed

* Set the precision correctly when serializing doubles in extended json.
* Reading the `objectTypes` array from a Realm Configuration would not include
  the embedded object types which were set in the array.
* Reject loops in embedded objects as part of local schema validation rather
  than as a server error.
* Although MongoClient is obtained from a User, it was actually using the
  User's App's current user rather than the User it was obtained from to make
  requests.


This release also contains the following changes from 5.4.7 - 5.5.0

### Enhancements

* Add the ability to capture a NotificationToken when using a Combine publisher
  that observes a Realm Object or Collection. The user will call
  `saveToken(on:at:)` directly after invoking the publisher to use the feature.

### Fixed

* When using `Realm.write(withoutNotifying:)` there was a chance that the
  supplied observation blocks would not be skipped when in a write transaction.
  ([Object Store #1103](https://github.com/realm/realm-object-store/pull/1103))
* Comparing two identical unmanaged `List<>`/`RLMArray` objects would fail.
  ([#5665](https://github.com/realm/realm-cocoa/issues/5665)).
* Case-insensitive equality queries on indexed string properties failed to
  clear some internal state when rerunning the query. This could manifest as
  duplicate results or "key not found" errors.
  ([#6830](https://github.com/realm/realm-cocoa/issues/6830), [#6694](https://github.com/realm/realm-cocoa/issues/6694), since 5.0.0).
* Equality queries on indexed string properties would sometimes throw "key not
  found" exceptions if the hash of the string happened to have bit 62 set.
  ([.NET #2025](https://github.com/realm/realm-dotnet/issues/2025), since v5.0.0).
* Queries comparing non-optional int properties to nil would behave as if they
  were comparing against zero instead (since v5.0.0).

### Compatibility

* File format: Generates Realms with format v12 (Reads and upgrades all previous formats)
* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-core from v10.0.0-beta.9 to v10.0.0
* Upgraded realm-sync from v10.0.0-beta.14 to v10.0.0

10.0.0-rc.1 Release notes (2020-10-01)
=============================================================

### Breaking Changes

* Change the following methods on RLMUser to properties:
  - `[RLMUser emailPasswordAuth]` => `RLMUser.emailPasswordAuth`
  - `[RLMUser identities]` => `RLMUser.identities`
  - `[RLMUser allSessions]` => `RLMUser.allSessions`
  - `[RLMUser apiKeysAuth]` => `RLMUser.apiKeysAuth`
* Other changes to RLMUser:
  - `nullable` has been removed from `RLMUser.identifier`
  - `nullable` has been removed from `RLMUser.customData`
* Change the following methods on RLMApp to properties:
  - `[RLMApp allUsers]` => `RLMApp.allUsers`
  - `[RLMApp currentUser]` => `RLMApp.currentUser`
  - `[RLMApp emailPasswordAuth]` => `RLMApp.emailPasswordAuth`
* Define `RealmSwift.Credentials` as an enum instead of a `typealias`. Example
  usage has changed from `Credentials(googleAuthCode: "token")` to
  `Credentials.google(serverAuthCode: "serverAuthCode")`, and
  `Credentials(facebookToken: "token")` to `Credentials.facebook(accessToken: "accessToken")`, etc.
* Remove error parameter and redefine payload in
  `+ (instancetype)credentialsWithFunctionPayload:(NSDictionary *)payload error:(NSError **)error;`.
  It is now defined as `+ (instancetype)credentialsWithFunctionPayload:(NSDictionary<NSString *, id<RLMBSON>> *)payload;`

### Compatibility

* File format: Generates Realms with format v12 (Reads and upgrades all previous formats)
* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 10.x.y series.
* Carthage release for Swift is built with Xcode 12.

10.0.0-beta.6 Release notes (2020-09-30)
=============================================================

### Breaking Changes

* Change Google Credential parameter names to better reflect the required auth code:
    - `Credentials(googleToken:)` => `Credentials(googleAuthCode:)`
    - `[RLMCredentials credentialsWithGoogleToken:]` => `[RLMCredentials credentialsWithGoogleAuthCode:]`
* Rename Realm.Publishers to RealmPublishers to avoid confusion with Combine.Publishers

### Fixed

* Deleting objects could sometimes change the ObjectId remaining objects from
  null to ObjectId("deaddeaddeaddeaddeaddead") when there are more than 1000
  objects. (Since v10.0.0-alpha.1)
* Fixed an assertion failure when adding an index to a nullable ObjectId
  property that contains nulls. (since v10.0.0-alpha.1).

This release also contains the following changes from 5.4.0 - 5.4.6:

### Enhancements

* Add prebuilt binary for Xcode 11.7 to the release package.
* Add prebuilt binary for Xcode 12 to the release package.
* Improve the asymtotic performance of NOT IN queries on indexed properties. It
  is now O(Number of Rows) rather than O(Number of Rows \* Number of values in IN clause.)
* Slightly (<5%) improve the performance of most operations which involve
  reading from a Realm file.

### Fixed

* Upgrading pre-5.x files with string primary keys would result in a file where
  `realm.object(ofType:forPrimaryKey:)` would fail to find the object.
  ([#6716](https://github.com/realm/realm-cocoa/issues/6716), since 5.2.0)
* A write transaction which modifies an object with more than 16 managed
  properties and causes the Realm file to grow larger than 2 GB could cause an
  assertion failure mentioning "m_has_refs". ([JS #3194](https://github.com/realm/realm-js/issues/3194), since 5.0.0).
* Objects with more than 32 properties could corrupt the Realm file and result
  in a variety of crashes. ([Java #7057](https://github.com/realm/realm-java/issues/7057), since 5.0.0).
* Fix deadlocks when opening a Realm file in both the iOS simulator and Realm
  Studio ([#6743](https://github.com/realm/realm-cocoa/issues/6743), since 5.3.6).
* Fix Springboard deadlocking when an app is unsuspended while it has an open
  Realm file which is stored in an app group on iOS 10-12
  ([#6749](https://github.com/realm/realm-cocoa/issues/6749), since 5.3.6).
* If you use encryption your application cound crash with a message like
  "Opening Realm files of format version 0 is not supported by this version of
  Realm". ([#6889](https://github.com/realm/realm-java/issues/6889) among others, since 5.0.0)
* Confining a Realm to a serial queue would throw an error claiming that the
  queue was not a serial queue on iOS versions older than 12.
  ([#6735](https://github.com/realm/realm-cocoa/issues/6735), since 5.0.0).
* Results would sometimes give stale results inside a write transaction if a
  write which should have updated the Results was made before the first access
  of a pre-existing Results object.
  ([#6721](https://github.com/realm/realm-cocoa/issues/6721), since 5.0.0)
* Fix Archiving the Realm and RealmSwift frameworks with Xcode 12.
  ([#6774](https://github.com/realm/realm-cocoa/issues/6774))
* Fix compilation via Carthage when using Xcode 12 ([#6717](https://github.com/realm/realm-cocoa/issues/6717)).
* Fix a crash inside `realm::Array(Type)::init_from_mem()` which would
  sometimes occur when running a query over links immediately after creating
  objects of the queried type.
  ([#6789](https://github.com/realm/realm-cocoa/issues/6789) and possibly others, since 5.0.0).
* Possibly fix problems when changing the type of the primary key of an object
  from optional to non-optional.
* Rerunning a equality query on an indexed string property would give incorrect
  results if a previous run of the query matched multiple objects and it now
  matches one object. This could manifest as either finding a non-matching
  object or a "key not found" exception being thrown.
  ([#6536](https://github.com/realm/realm-cocoa/issues/6536), since 5.0.0).

### Compatibility

* File format: Generates Realms with format v12 (Reads and upgrades all previous formats)
* Realm Studio: 10.0.0 or later.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-core from v10.0.0-beta.7 to v10.0.0-beta.9
* Upgraded realm-sync from v10.0.0-beta.11 to v10.0.0-beta.14

10.0.0-beta.5 Release notes (2020-09-15)
=============================================================

### Enhancements

* Add `User.loggedIn`.
* Add support for multiple Realm Apps.
* Remove `[RLMSyncManager shared]`. This is now instatiated as a property on
  the app itself.
* Add Combine support for:
    * PushClient
    * APIKeyAuth
    * User
    * MongoCollection
    * EmailPasswordAuth
    * App.login

### Fixed

* Fix `MongoCollection.watch` to consistently deliver events on a given queue.
* Fix `[RLMUser logOutWithCompletion]` and `User.logOut` to now log out the
  correct user.
* Fix crash on startup on iOS versions older than 13 (since v10.0.0-beta.3).

### Breaking Changes

* `RLMSyncManager.pinnedCertificatePaths` has been removed.
* Classes `RLMUserAccountInfo` & `RLMUserInfo` (swift: `UserInfo`,
  `UserAccountInfo`) have been removed.
* The following functionality has been renamed to align Cocoa with the other
  Realm SDKs:

| Old API                                                      | New API                                                        |
|:-------------------------------------------------------------|:---------------------------------------------------------------|
| `RLMUser.identity`                                           | `RLMUser.identifier`                                           |
| `User.identity`                                              | `User.id`                                                      |
| `-[RLMCredentials credentialsWithUsername:password:]`        | `-[RLMCredentials credentialsWithEmail:password:]`             |
| `Credentials(username:password:)`                            | `Credentials(email:password:)`                                 |
| -`[RLMUser apiKeyAuth]`                                      | `-[RLMUser apiKeysAuth]`                                       |
| `User.apiKeyAuth()`                                          | `User.apiKeysAuth()`                                           |
| `-[RLMEmailPasswordAuth registerEmail:password:completion:]` | `-[RLMEmailPasswordAuth registerUserWithEmail:password:completion:]` |
| `App.emailPasswordAuth().registerEmail(email:password:)`     | `App.emailPasswordAuth().registerUser(email:password:)`        |

### Compatibility

* File format: Generates Realms with format v12 (Reads and upgrades all previous formats)
* Realm Studio: 10.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v10.0.0-beta.6 to v10.0.0-beta.7
* Upgraded realm-sync from v10.0.0-beta.10 to v10.0.0-beta.11

10.0.0-beta.4 Release notes (2020-08-28)
=============================================================

### Enhancements

* Add support for the 64-bit watchOS simulator added in Xcode 12.
* Add ability to stream change events on a remote MongoDB collection with
  `[RLMMongoCollection watch:delegate:delegateQueue]`,
  `MongoCollection.watch(delegate)`. When calling `watch(delegate)` you will be
  given a `RLMChangeStream` (`ChangeStream`), this will be used to invalidate
  and stop the streaming session by calling `[RLMChangeStream close]`
  (`ChangeStream.close()`) when needed.
* Add `MongoCollection.watch`, which is a Combine publisher that will stream
  change events each time the remote MongoDB collection is updated.
* Add ability to open a synced Realm with a `nil` partition value.

### Fixed

* Realm.Configuration.objectTypes now accepts embedded objects
* Ports fixes from 5.3.5

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the v10.0.0-beta.x series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal

* Upgraded realm-core from v10.0.0-beta.1 to v10.0.0-beta.6
* Upgraded realm-sync from v10.0.0-beta.2 to v10.0.0-beta.10

10.0.0-beta.3 Release notes (2020-08-17)
=============================================================

This release also contains all changes from 5.3.2.

### Breaking Changes
* The following classes & aliases have been renamed to align Cocoa with the other Realm SDKs:

| Old API                                                     | New API                                                        |
|:------------------------------------------------------------|:---------------------------------------------------------------|
| `RLMSyncUser`                                               | `RLMUser`                                                      |
| `SyncUser`                                                  | `User`                                                         |
| `RLMAppCredential`                                          | `RLMCredential`                                                |
| `AppCredential`                                             | `Credential`                                                   |
| `RealmApp`                                                  | `App`                                                          |
| `RLMUserAPIKeyProviderClient`                               | `RLMAPIKeyAuth`                                                |
| `RLMUsernamePasswordProviderClient`                         | `RLMEmailPasswordAuth`                                         |
| `UsernamePasswordProviderClient`                            | `EmailPasswordAuth`                                            |
| `UserAPIKeyProviderClient`                                  | `APIKeyAuth`                                                   |

* The following functionality has also moved to the User

| Old API                                                      | New API                                                       |
|:-------------------------------------------------------------|:--------------------------------------------------------------|
| `[RLMApp callFunctionNamed:]`                                | `[RLMUser callFunctionNamed:]`                                |
| `App.functions`                                              | `User.functions`                                              |
| `[RLMApp mongoClientWithServiceName:]`                       | `[RLMUser mongoClientWithServiceName:]`                       |
| `App.mongoClient(serviceName)`                               | `User.mongoClient(serviceName)`                               |
| `[RLMApp userAPIKeyProviderClient]`                          | `[RLMUser apiKeyAuth]`                                        |
| `App.userAPIKeyProviderClient`                               | `App.apiKeyAuth()`                                            |
| `[RLMApp logOut:]`                                           | `[RLMUser logOut]`                                            |
| `App.logOut(user)`                                           | `User.logOut()`                                               |
| `[RLMApp removeUser:]`                                       | `[RLMUser remove]`                                            |
| `App.remove(user)`                                           | `User.remove()`                                               |
| `[RLMApp linkUser:credentials:]`                             | `[RLMUser linkWithCredentials:]`                              |
| `App.linkUser(user, credentials)`                            | `User.link(credentials)`                                      |

*  `refreshCustomData()` on User now returns void and passes the custom data to the callback on success.

### Compatibility
* This release introduces breaking changes w.r.t some sync classes and MongoDB Realm Cloud functionality.
(See the breaking changes section for the full list)
* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Studio: 10.0.0 or later.
* Carthage release for Swift is built with Xcode 11.5.

### Internal
* Upgraded realm-core from ? to ?
* Upgraded realm-sync from ? to ?

10.0.0-beta.2 Release notes (2020-06-09)
=============================================================
Xcode 11.3 and iOS 9 are now the minimum supported versions.

### Enhancements
* Add support for building with Xcode 12 beta 1. watchOS currently requires
  removing x86_64 from the supported architectures. Support for the new 64-bit
  watch simulator will come in a future release.

### Fixed
* Opening a SyncSession with LOCAL app deployments would not use the correct endpoints.
* Linking from embedded objects to top-level objects was incorrectly disallowed.
* Opening a Realm file in file format v6 (created by Realm Cocoa versions
  between 2.4 and 2.10) would crash. (Since 5.0.0, [Core #3764](https://github.com/realm/realm-core/issues/3764)).
* Upgrading v9 (pre-5.0) Realm files would create a redundant search index for
  primary key properties. This index would then be removed the next time the
  Realm was opened, resulting in some extra i/o in the upgrade process.
  (Since 5.0.0, [Core #3787](https://github.com/realm/realm-core/issues/3787)).
* Fixed a performance issue with upgrading v9 files with search indexes on
  non-primary-key properties. (Since 5.0.0, [Core #3767](https://github.com/realm/realm-core/issues/3767)).

### Compatibility
* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* MongoDB Realm: 84893c5 or later.
* APIs are backwards compatible with all previous releases in the 10.0.0-alpha series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal
* Upgraded realm-core from v6.0.3 to v10.0.0-beta.1
* Upgraded realm-sync from v5.0.1 to v10.0.0-beta.2

10.0.0-beta.1 Release notes (2020-06-08)
=============================================================

NOTE: This version bumps the Realm file format to version 11. It is not
possible to downgrade to earlier versions. Older files will automatically be
upgraded to the new file format. Only [Realm Studio
10.0.0](https://github.com/realm/realm-studio/releases/tag/v10.0.0-beta.1) or
later will be able to open the new file format.

### Enhancements

* Add support for next generation sync. Support for syncing to MongoDB instead
  of Realm Object Server. Applications must be created at realm.mongodb.com
* The memory mapping scheme for Realm files has changed to better support
  opening very large files.
* Add support for the ObjectId data type. This is an automatically-generated
  unique identifier similar to a GUID or a UUID.
  ([PR #6450](https://github.com/realm/realm-cocoa/pull/6450)).
* Add support for the Decimal128 data type. This is a 128-bit IEEE 754 decimal
  floating point number similar to NSDecimalNumber.
  ([PR #6450](https://github.com/realm/realm-cocoa/pull/6450)).
* Add support for embedded objects. Embedded objects are objects which are
  owned by a single parent object, and are deleted when that parent object is
  deleted. They are defined by subclassing `EmbeddedObject` /
  `RLMEmbeddedObject` rather than `Object` / `RLMObject`.
* Add `-[RLMSyncUser customData]`/`SyncUser.customData`.  Custom data is 
  configured in your MongoDB Realm App.
* Add `-[RLMApp callFunctionNamed:arguments]`/`RealmApp.functions`. This is the
  entry point for calling Remote MongoDB Realm functions. Functions allow you
  to define and execute server-side logic for your application. Functions are
  written in modern JavaScript (ES6+) and execute in a serverless manner. When
  you call a function, you can dynamically access components of the current
  application as well as information about the request to execute the function
  and the logged in user that sent the request.
* Add `-[RLMApp mongoClientWithServiceName]`/`RealmApp.mongoClient`. This is
  the entry point for calling your Remote MongoDB Service. The read operations
  are `-[RLMMongoCollection findWhere:completion:]`, `-[RLMMongoCollection
  countWhere:completion:]`and `-[RLMMongoCollection
  aggregateWithPipeline:completion:]`. The write operations are
  `-[RLMMongoCollection insertOneDocument:completion:]`, `-[RLMMongoCollection
  insertManyDocuments:completion:]`, `-[RLMMongoCollection
  updateOneDocument:completion:]`, `-[RLMMongoCollection
  updateManyDocuments:completion:]`, `-[RLMMongoCollection
  deleteOneDocument:completion:]`, and `-[RLMMongoCollection
  deleteManyDocuments:completion:]`. If you are already familiar with MongoDB
  drivers, it is important to understand that the remote MongoCollection only
  provides access to the operations available in MongoDB Realm.
* Change `[RLMSyncUser
  configurationWithPartitionValue:]`/`SyncUser.configuration(with:)` to accept
  all BSON types. Partition values can currently be of types `String`, `Int`,
  or `ObjectId`. Opening a realm by partition value is the equivalent of
  previously opening a realm by URL. In this case, partitions are meant to be
  more closely associated with your data. E.g., if you are running a `Dog`
  kennel, and have a field `breed` that acts as your partition key, you could
  open up realms based on the breed of the dogs.

### Breaking Changes

* We no longer support Realm Cloud (legacy), but instead the new "MongoDB
  Realm" Cloud. MongoDB Realm is a serverless platform that enables developers
  to quickly build applications without having to set up server infrastructure.
  MongoDB Realm is built on top of MongoDB Atlas, automatically integrating the
  connection to your database.
* Remove support for Query-based sync, including the configuration parameters
  and the `RLMSyncSubscription` and `SyncSubscription` types ([#6437](https://github.com/realm/realm-cocoa/pull/6437)).
* Primary key properties are no longer marked as being indexed. This reflects
  an internal change to how primary keys are handled that should not have any
  other visible effects. ([#6440](https://github.com/realm/realm-cocoa/pull/6440)).
* Remove everything related to sync permissions, including both the path-based
  permission system and the object-level privileges for query-based sync. ([#6445](https://github.com/realm/realm-cocoa/pulls/6445))
* Primary key uniqueness is now enforced when creating new objects during
  migrations, rather than only at the end of migrations. Previously new objects
  could be created with duplicate primary keys during a migration as long as
  the property was changed to a unique value before the end of the migration,
  but now a unique value must be supplied when creating the object.
* Remove support for Realm Object Server.

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* MongoDB Realm: 84893c5 or later.
* APIs are backwards compatible with all previous releases in the 10.0.0-alpha series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal

* Upgraded realm-core from v6.0.3 to v10.0.0-beta.1
* Upgraded realm-sync from v5.0.1 to v10.0.0-beta.2

5.5.0 Release notes (2020-10-12)
=============================================================

### Enhancements

* Add the ability to capture a NotificationToken when using a Combine publisher
  that observes a Realm Object or Collection. The user will call
  `saveToken(on:at:)` directly after invoking the publisher to use the feature.

### Fixed

* When using `Realm.write(withoutNotifying:)` there was a chance that the
  supplied observation blocks would not be skipped when in a write transaction.
  ([Object Store #1103](https://github.com/realm/realm-object-store/pull/1103))
* Comparing two identical unmanaged `List<>`/`RLMArray` objects would fail.
  ([#5665](https://github.com/realm/realm-cocoa/issues/5665)).

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 5.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

5.4.8 Release notes (2020-10-05)
=============================================================

### Fixed

* Case-insensitive equality queries on indexed string properties failed to
  clear some internal state when rerunning the query. This could manifest as
  duplicate results or "key not found" errors.
  ([#6830](https://github.com/realm/realm-cocoa/issues/6830), [#6694](https://github.com/realm/realm-cocoa/issues/6694), since 5.0.0).

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 5.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-core from v6.1.3 to v6.1.4
* Upgraded realm-sync from v5.0.28 to v5.0.29

5.4.7 Release notes (2020-09-30)
=============================================================

### Fixed

* Equality queries on indexed string properties would sometimes throw "key not
  found" exceptions if the hash of the string happened to have bit 62 set.
  ([.NET #2025](https://github.com/realm/realm-dotnet/issues/2025), since v5.0.0).
* Queries comparing non-optional int properties to nil would behave as if they
  were comparing against zero instead (since v5.0.0).

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 5.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-core from v6.1.2 to v6.1.3
* Upgraded realm-sync from v5.0.27 to v5.0.28

5.4.6 Release notes (2020-09-29)
=============================================================

5.4.5 failed to actually update the core version for installation methods other
than SPM. All changes listed there actually happened in this version for
non-SPM installation methods.

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 5.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-sync from v5.0.26 to v5.0.27

5.4.5 Release notes (2020-09-28)
=============================================================

### Enhancements

* Slightly (<5%) improve the performance of most operations which involve
  reading from a Realm file.

### Fixed

* Rerunning a equality query on an indexed string property would give incorrect
  results if a previous run of the query matched multiple objects and it now
  matches one object. This could manifest as either finding a non-matching
  object or a "key not found" exception being thrown.
  ([#6536](https://github.com/realm/realm-cocoa/issues/6536), since 5.0.0).

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 5.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-core from v6.1.1 to v6.1.2
* Upgraded realm-sync from v5.0.25 to v5.0.26

5.4.4 Release notes (2020-09-25)
=============================================================

### Enhancements
* Improve the asymtotic performance of NOT IN queries on indexed properties. It
  is now O(Number of Rows) rather than O(Number of Rows \* Number of values in IN clause.)

### Fixed

* Fix a crash inside `realm::Array(Type)::init_from_mem()` which would
  sometimes occur when running a query over links immediately after creating
  objects of the queried type.
  ([#6789](https://github.com/realm/realm-cocoa/issues/6789) and possibly others, since 5.0.0).
* Possibly fix problems when changing the type of the primary key of an object
  from optional to non-optional.

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 5.0.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

### Internal

* Upgraded realm-core from v6.0.26 to v6.1.1
* Upgraded realm-sync from v5.0.23 to v5.0.25

5.4.3 Release notes (2020-09-21)
=============================================================

### Fixed

* Fix compilation via Carthage when using Xcode 12 ([#6717](https://github.com/realm/realm-cocoa/issues/6717)).

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.12 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

5.4.2 Release notes (2020-09-17)
=============================================================

### Enhancements

* Add prebuilt binary for Xcode 12 to the release package.

### Fixed

* Fix Archiving the Realm and RealmSwift frameworks with Xcode 12.
  ([#6774](https://github.com/realm/realm-cocoa/issues/6774))

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.12 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 12.

5.4.1 Release notes (2020-09-16)
=============================================================

### Enhancements

* Add prebuilt binary for Xcode 11.7 to the release package.

### Fixed

* Fix deadlocks when opening a Realm file in both the iOS simulator and Realm
  Studio ([#6743](https://github.com/realm/realm-cocoa/issues/6743), since 5.3.6).
* Fix Springboard deadlocking when an app is unsuspended while it has an open
  Realm file which is stored in an app group on iOS 10-12
  ([#6749](https://github.com/realm/realm-cocoa/issues/6749), since 5.3.6).
* If you use encryption your application cound crash with a message like
  "Opening Realm files of format version 0 is not supported by this version of
  Realm". ([#6889](https://github.com/realm/realm-java/issues/6889) among others, since 5.0.0)
* Confining a Realm to a serial queue would throw an error claiming that the
  queue was not a serial queue on iOS versions older than 12.
  ([#6735](https://github.com/realm/realm-cocoa/issues/6735), since 5.0.0).
* Results would sometimes give stale results inside a write transaction if a
  write which should have updated the Results was made before the first access
  of a pre-existing Results object.
  ([#6721](https://github.com/realm/realm-cocoa/issues/6721), since 5.0.0)

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.12 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.7.

### Internal

* Upgraded realm-core from v6.0.25 to v6.0.26
* Upgraded realm-sync from v5.0.22 to v5.0.23

5.4.0 Release notes (2020-09-09)
=============================================================

This version bumps the Realm file format version. This means that older
versions of Realm will be unable to open Realm files written by this version,
and a new version of Realm Studio will be required. There are no actual format
changes and the version bump is just to force a re-migration of incorrectly
upgraded Realms.

### Fixed

* Upgrading pre-5.x files with string primary keys would result in a file where
  `realm.object(ofType:forPrimaryKey:)` would fail to find the object.
  ([#6716](https://github.com/realm/realm-cocoa/issues/6716), since 5.2.0)
* A write transaction which modifies an object with more than 16 managed
  properties and causes the Realm file to grow larger than 2 GB could cause an
  assertion failure mentioning "m_has_refs". ([JS #3194](https://github.com/realm/realm-js/issues/3194), since 5.0.0).
* Objects with more than 32 properties could corrupt the Realm file and result
  in a variety of crashes. ([Java #7057](https://github.com/realm/realm-java/issues/7057), since 5.0.0).

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.12 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.23 to v6.0.25
* Upgraded realm-sync from v5.0.20 to v5.0.22

5.3.6 Release notes (2020-09-02)
=============================================================

### Fixed

* Work around iOS 14 no longer allowing the use of file locks in shared
  containers, which resulted in the OS killing an app which entered the
  background while a Realm was open ([#6671](https://github.com/realm/realm-cocoa/issues/6671)).
* If an attempt to upgrade a realm has ended with a crash with "migrate_links()"
  in the call stack, the realm was left in an invalid state. The migration
  logic now handles this state and can complete upgrading files which were
  incompletely upgraded by pre-5.3.4 versions.
* Fix deadlocks when writing to a Realm file on an exFAT partition from macOS.
  ([#6691](https://github.com/realm/realm-cocoa/issues/6691)).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.19 to v6.0.23
* Upgraded realm-sync from v5.0.16 to v5.0.20

5.3.5 Release notes (2020-08-20)
=============================================================

### Fixed

* Opening Realms on background threads could produce spurious Incorrect Thread
  exceptions when a cached Realm existed for a previously existing thread with
  the same thread ID as the current thread.
  ([#6659](https://github.com/realm/realm-cocoa/issues/6659),
  [#6689](https://github.com/realm/realm-cocoa/issues/6689),
  [#6712](https://github.com/realm/realm-cocoa/issues/6712), since 5.0.0).
* Upgrading a table with incoming links but no properties would crash. This was
  probably not possible to hit in practice as we reject object types with no
  properties.
* Upgrading a non-nullable List which nonetheless contained null values would
  crash. This was possible due to missing error-checking in some older versions
  of Realm.

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.18 to v6.0.19
* Upgraded realm-sync from v5.0.15 to v5.0.16

5.3.4 Release notes (2020-08-17)
=============================================================

### Fixed

* Accessing a Realm after calling `deleteAll()` would sometimes throw an
  exception with the reason 'ConstIterator copy failed'. ([#6597](https://github.com/realm/realm-cocoa/issues/6597), since 5.0.0).
* Fix an assertion failure inside the `migrate_links()` function when upgrading
  a pre-5.0 Realm file.
* Fix a bug in memory mapping management. This bug could result in multiple
  different asserts as well as segfaults. In many cases stack backtraces would
  include members of the EncyptedFileMapping near the top - even if encryption
  was not used at all. In other cases asserts or crashes would be in methods
  reading an array header or array element. In all cases the application would
  terminate immediately. ([Core #3838](https://github.com/realm/realm-core/pull/3838), since v5.0.0).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.14 to v6.0.18
* Upgraded realm-sync from v5.0.14 to v5.0.15

5.3.3 Release notes (2020-07-30)
=============================================================

### Enhancements

* Add support for the x86_64 watchOS simulator added in Xcode 12.

### Fixed

* (RLM)Results objects would incorrectly pin old read transaction versions
  until they were accessed after a Realm was refreshed, resulting in the Realm
  file growing to large sizes if a Results was retained but not accessed after
  every write. ([#6677](https://github.com/realm/realm-cocoa/issues/6677), since 5.0.0).
* Fix linker errors when using SwiftUI previews with Xcode 12 when Realm was
  installed via Swift Package Manager. ([#6625](https://github.com/realm/realm-cocoa/issues/6625))

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.12 to v6.0.14
* Upgraded realm-sync from v5.0.12 to v5.0.14

5.3.2 Release notes (2020-07-21)
=============================================================

### Fixed

* Fix a file format upgrade bug when opening older Realm files. Could cause
  assertions like "Assertion failed: ref != 0" during opning of a Realm.
  ([Core #6644](https://github.com/realm/realm-cocoa/issues/6644), since 5.2.0)
* A use-after-free would occur if a Realm was compacted, opened on multiple
  threads prior to the first write, then written to while reads were happening
  on other threads. This could result in a variety of crashes, often inside
  realm::util::EncryptedFileMapping::read_barrier.
  (Since v5.0.0, [#6626](https://github.com/realm/realm-cocoa/issues/6626),
  [#6628](https://github.com/realm/realm-cocoa/issues/6628),
  [#6652](https://github.com/realm/realm-cocoa/issues/6652),
  [#6655](https://github.com/realm/realm-cocoa/issues/6555),
  [#6656](https://github.com/realm/realm-cocoa/issues/6656)).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.11 to v6.0.12
* Upgraded realm-sync from v5.0.11 to v5.0.12

5.3.1 Release notes (2020-07-17)
=============================================================

### Enhancements

* Add prebuilt binary for Xcode 11.6 to the release package.

### Fixed

* Creating an object inside migration which changed that object type's primary
  key would hit an assertion failure mentioning primary_key_col
  ([#6613](https://github.com/realm/realm-cocoa/issues/6613), since 5.0.0).
* Modifying the value of a string primary key property inside a migration with
  a Realm file which was upgraded from pre-5.0 would corrupt the property's
  index, typically resulting in crashes. ([Core #3765](https://github.com/realm/realm-core/issues/3765), since 5.0.0).
* Some Realm files which hit assertion failures when upgrading from the pre-5.0
  file format should now upgrade correctly (Since 5.0.0).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.6.

### Internal

* Upgraded realm-core from v6.0.9 to v6.0.11
* Upgraded realm-sync from v5.0.8 to v5.0.11

5.3.0 Release notes (2020-07-14)
=============================================================

### Enhancements

* Add `Realm.objectWillChange`, which is a Combine publisher that will emit a
  notification each time the Realm is refreshed or a write transaction is
  commited.

### Fixed

* Fix the spelling of `ObjectKeyIdentifiable`. The old spelling is available
  and deprecated for compatiblity.
* Rename `RealmCollection.publisher` to `RealmCollection.collectionPublisher`.
  The old name interacted with the `publisher` defined by `Sequence` in very
  confusing ways, so we need to use a different name. The `publisher` name is
  still available for compatiblity. ([#6516](https://github.com/realm/realm-cocoa/issues/6516))
* Work around "xcodebuild timed out while trying to read
  SwiftPackageManagerExample.xcodeproj" errors when installing Realm via
  Carthage. ([#6549](https://github.com/realm/realm-cocoa/issues/6549)).
* Fix a performance regression when using change notifications. (Since 5.0.0,
  [#6629](https://github.com/realm/realm-cocoa/issues/6629)).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal

* Upgraded realm-core from v6.0.8 to v6.0.9
* Upgraded realm-sync from v5.0.7 to v5.0.8

5.2.0 Release notes (2020-06-30)
=============================================================

### Fixed
* Opening a SyncSession with LOCAL app deployments would not use the correct endpoints.
This release also contains all changes from 5.0.3 and 5.1.0.

### Breaking Changes
* The following classes & aliases have been renamed to align Cocoa with the other Realm SDKs:

| Old API                                                     | New API                                                        |
|:------------------------------------------------------------|:---------------------------------------------------------------|
| `RLMSyncUser`                                               | `RLMUser`                                                      |
| `SyncUser`                                                  | `User`                                                         |
| `RLMAppCredential`                                          | `RLMCredential`                                                |
| `AppCredential`                                             | `Credential`                                                   |
| `RealmApp`                                                  | `App`                                                          |
| `RLMUserAPIKeyProviderClient`                               | `RLMAPIKeyAuth`                                                |
| `RLMUsernamePasswordProviderClient`                         | `RLMEmailPasswordAuth`                                         |
| `UsernamePasswordProviderClient`                            | `EmailPasswordAuth`                                            |
| `UserAPIKeyProviderClient`                                  | `APIKeyAuth`                                                   |

* The following functionality has also moved to the User:

| Old API                                                      | New API                                                       |
|:-------------------------------------------------------------|:--------------------------------------------------------------|
| `[RLMApp callFunctionNamed:]`                                | `[RLMUser callFunctionNamed:]`                                |
| `App.functions`                                              | `User.functions`                                              |
| `[RLMApp mongoClientWithServiceName:]`                       | `[RLMUser mongoClientWithServiceName:]`                       |
| `App.mongoClient(serviceName)`                               | `User.mongoClient(serviceName)`                               |
| `[RLMApp userAPIKeyProviderClient]`                          | `[RLMUser apiKeyAuth]`                                        |
| `App.userAPIKeyProviderClient`                               | `App.apiKeyAuth()`                                            |
| `[RLMApp logOut:]`                                           | `[RLMUser logOut]`                                            |
| `App.logOut(user)`                                           | `User.logOut()`                                               |
| `[RLMApp removeUser:]`                                       | `[RLMUser remove]`                                            |
| `App.remove(user)`                                           | `User.remove()`                                               |
| `[RLMApp linkUser:credentials:]`                             | `[RLMUser linkWithCredentials:]`                              |
| `App.linkUser(user, credentials)`                            | `User.link(credentials)`                                      |

* The argument labels in Swift have changed for several methods:
| Old API                                                      | New API                                                       |
|:-------------------------------------------------------------|:--------------------------------------------------------------|
| `APIKeyAuth.createApiKey(withName:completion:)`              | `APIKeyAuth.createApiKey(named:completion:)`                  |
| `App.login(withCredential:completion:)                       | `App.login(credentials:completion:)`                          |
| `App.pushClient(withServiceName:)`                           | `App.pushClient(serviceName:)`                                |
| `MongoClient.database(withName:)`                            | `MongoClient.database(named:)`                                |

* `refreshCustomData()` on User now returns void and passes the custom data to the callback on success.

### Compatibility
* This release introduces breaking changes w.r.t some sync classes and MongoDB Realm Cloud functionality.
  (See the breaking changes section for the full list)
* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* MongoDB Realm: 84893c5 or later.
* APIs are backwards compatible with all previous releases in the 10.0.0-alpha series.
* Realm Studio: 10.0.0 or later.
* Carthage release for Swift is built with Xcode 11.5.

### Internal
* Upgraded realm-core from v6.0.3 to v10.0.0-beta.1
* Upgraded realm-sync from v5.0.1 to v10.0.0-beta.2

10.0.0-beta.2 Release notes (2020-06-09)
=============================================================
Xcode 11.3 and iOS 9 are now the minimum supported versions.

### Enhancements

* Add support for building with Xcode 12 beta 1. watchOS currently requires
  removing x86_64 from the supported architectures. Support for the new 64-bit
  watch simulator will come in a future release.

### Fixed
* Opening a SyncSession with LOCAL app deployments would not use the correct endpoints.
* Linking from embedded objects to top-level objects was incorrectly disallowed.

* Opening a Realm file in file format v6 (created by Realm Cocoa versions
  between 2.4 and 2.10) would crash. (Since 5.0.0, [Core #3764](https://github.com/realm/realm-core/issues/3764)).
* Upgrading v9 (pre-5.0) Realm files would create a redundant search index for
  primary key properties. This index would then be removed the next time the
  Realm was opened, resulting in some extra i/o in the upgrade process.
  (Since 5.0.0, [Core #3787](https://github.com/realm/realm-core/issues/3787)).
* Fixed a performance issue with upgrading v9 files with search indexes on
  non-primary-key properties. (Since 5.0.0, [Core #3767](https://github.com/realm/realm-core/issues/3767)).

### Compatibility
* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* MongoDB Realm: 84893c5 or later.
* APIs are backwards compatible with all previous releases in the 10.0.0-alpha series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal
* Upgraded realm-core from v6.0.3 to v10.0.0-beta.1
* Upgraded realm-sync from v5.0.1 to v10.0.0-beta.2

10.0.0-beta.1 Release notes (2020-06-08)
=============================================================

NOTE: This version bumps the Realm file format to version 11. It is not
possible to downgrade to earlier versions. Older files will automatically be
upgraded to the new file format. Only [Realm Studio
10.0.0](https://github.com/realm/realm-studio/releases/tag/v10.0.0-beta.1) or
later will be able to open the new file format.

### Enhancements

* Add support for next generation sync. Support for syncing to MongoDB instead
  of Realm Object Server. Applications must be created at realm.mongodb.com
* The memory mapping scheme for Realm files has changed to better support
  opening very large files.
* Add support for the ObjectId data type. This is an automatically-generated
  unique identifier similar to a GUID or a UUID.
  ([PR #6450](https://github.com/realm/realm-cocoa/pull/6450)).
* Add support for the Decimal128 data type. This is a 128-bit IEEE 754 decimal
  floating point number similar to NSDecimalNumber.
  ([PR #6450](https://github.com/realm/realm-cocoa/pull/6450)).
* Add support for embedded objects. Embedded objects are objects which are
  owned by a single parent object, and are deleted when that parent object is
  deleted. They are defined by subclassing `EmbeddedObject` /
  `RLMEmbeddedObject` rather than `Object` / `RLMObject`.
* Add `-[RLMSyncUser customData]`/`SyncUser.customData`.  Custom data is 
  configured in your MongoDB Realm App.
* Add `-[RLMApp callFunctionNamed:arguments]`/`RealmApp.functions`. This is the
  entry point for calling Remote MongoDB Realm functions. Functions allow you
  to define and execute server-side logic for your application. Functions are
  written in modern JavaScript (ES6+) and execute in a serverless manner. When
  you call a function, you can dynamically access components of the current
  application as well as information about the request to execute the function
  and the logged in user that sent the request.
* Add `-[RLMApp mongoClientWithServiceName]`/`RealmApp.mongoClient`. This is
  the entry point for calling your Remote MongoDB Service. The read operations
  are `-[RLMMongoCollection findWhere:completion:]`, `-[RLMMongoCollection
  countWhere:completion:]`and `-[RLMMongoCollection
  aggregateWithPipeline:completion:]`. The write operations are
  `-[RLMMongoCollection insertOneDocument:completion:]`, `-[RLMMongoCollection
  insertManyDocuments:completion:]`, `-[RLMMongoCollection
  updateOneDocument:completion:]`, `-[RLMMongoCollection
  updateManyDocuments:completion:]`, `-[RLMMongoCollection
  deleteOneDocument:completion:]`, and `-[RLMMongoCollection
  deleteManyDocuments:completion:]`. If you are already familiar with MongoDB
  drivers, it is important to understand that the remote MongoCollection only
  provides access to the operations available in MongoDB Realm.
* Change `[RLMSyncUser
  configurationWithPartitionValue:]`/`SyncUser.configuration(with:)` to accept
  all BSON types. Partition values can currently be of types `String`, `Int`,
  or `ObjectId`. Opening a realm by partition value is the equivalent of
  previously opening a realm by URL. In this case, partitions are meant to be
  more closely associated with your data. E.g., if you are running a `Dog`
  kennel, and have a field `breed` that acts as your partition key, you could
  open up realms based on the breed of the dogs.

### Breaking Changes

* We no longer support Realm Cloud (legacy), but instead the new "MongoDB
  Realm" Cloud. MongoDB Realm is a serverless platform that enables developers
  to quickly build applications without having to set up server infrastructure.
  MongoDB Realm is built on top of MongoDB Atlas, automatically integrating the
  connection to your database.
* Remove support for Query-based sync, including the configuration parameters
  and the `RLMSyncSubscription` and `SyncSubscription` types ([#6437](https://github.com/realm/realm-cocoa/pull/6437)).
* Primary key properties are no longer marked as being indexed. This reflects
  an internal change to how primary keys are handled that should not have any
  other visible effects. ([#6440](https://github.com/realm/realm-cocoa/pull/6440)).
* Remove everything related to sync permissions, including both the path-based
  permission system and the object-level privileges for query-based sync. ([#6445](https://github.com/realm/realm-cocoa/pulls/6445))
* Primary key uniqueness is now enforced when creating new objects during
  migrations, rather than only at the end of migrations. Previously new objects
  could be created with duplicate primary keys during a migration as long as
  the property was changed to a unique value before the end of the migration,
  but now a unique value must be supplied when creating the object.
* Remove support for Realm Object Server.

### Compatibility

* File format: Generates Realms with format v11 (Reads and upgrades all previous formats)
* MongoDB Realm: 84893c5 or later.
* APIs are backwards compatible with all previous releases in the 10.0.0-alpha series.
* `List.index(of:)` would give incorrect results if it was the very first thing
  called on that List after a Realm was refreshed following a write which
  modified the List. (Since 5.0.0, [#6606](https://github.com/realm/realm-cocoa/issues/6606)).
* If a ThreadSafeReference was the only remaining reference to a Realm,
  multiple copies of the file could end up mapped into memory at once. This
  probably did not have any symptoms other than increased memory usage. (Since 5.0.0).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal

* Upgraded realm-core from v6.0.3 to v10.0.0-beta.1
* Upgraded realm-sync from v5.0.1 to v10.0.0-beta.2
* Upgraded realm-core from v6.0.6 to v6.0.7
* Upgraded realm-sync from v5.0.5 to v5.0.6
* Upgraded realm-core from v6.0.6 to v6.0.8
* Upgraded realm-sync from v5.0.5 to v5.0.7

5.1.0 Release notes (2020-06-22)
=============================================================

### Enhancements

* Allow opening full-sync Realms in read-only mode. This disables local schema
  initialization, which makes it possible to open a Realm which the user does
  not have write access to without using asyncOpen. In addition, it will report
  errors immediately when an operation would require writing to the Realm
  rather than reporting it via the sync error handler only after the server
  rejects the write.

### Fixed

* Opening a Realm using a configuration object read from an existing Realm
  would incorrectly bind the new Realm to the original Realm's thread/queue,
  resulting in "Realm accessed from incorrect thread." exceptions.
  ([#6574](https://github.com/realm/realm-cocoa/issues/6574),
  [#6559](https://github.com/realm/realm-cocoa/issues/6559), since 5.0.0).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.5.

5.0.3 Release notes (2020-06-10)
=============================================================

### Fixed

* `-[RLMObject isFrozen]` always returned false. ([#6568](https://github.com/realm/realm-cocoa/issues/6568), since 5.0.0).
* Freezing an object within the write transaction that the object was created
  in now throws an exception rather than crashing when the object is first
  used.
* The schema for frozen Realms was not properly initialized, leading to crashes
  when accessing a RLMLinkingObjects property.
  ([#6568](https://github.com/realm/realm-cocoa/issues/6568), since 5.0.0).
* Observing `Object.isInvalidated` via a keypath literal would produce a
  warning in Swift 5.2 due to the property not being marked as @objc.
  ([#6554](https://github.com/realm/realm-cocoa/issues/6554))

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.5.

5.0.2 Release notes (2020-06-02)
=============================================================

### Fixed

* Fix errSecDuplicateItem (-25299) errors when opening a synchronized Realm
  when upgrading from pre-5.0 versions of Realm.
  ([#6538](https://github.com/realm/realm-cocoa/issues/6538), [#6494](https://github.com/realm/realm-cocoa/issues/6494), since 5.0.0).
* Opening Realms stored on filesystems which do not support preallocation (such
  as ExFAT) would give "Operation not supported" exceptions.
  ([#6508](https://github.com/realm/realm-cocoa/issues/6508), since 3.2.0).
* 'NoSuchTable' exceptions would sometimes be thrown after upgrading a Relam
  file to the v10 format. ([Core #3701](https://github.com/realm/realm-core/issues/3701), since 5.0.0)
* If the upgrade process was interrupted/killed for various reasons, the
  following run could stop with some assertions failing. No instances of this
  happening were reported to us. (Since 5.0.0).
* Queries filtering a `List` where the query was on an indexed property over a
  link would sometimes give incomplete results.
  ([#6540](https://github.com/realm/realm-cocoa/issues/6540), since 4.1.0 but
  more common since 5.0.0)
* Opening a file in read-only mode would attempt to make a spurious write to
  the file, causing errors if the file was in read-only storage (since 5.0.0).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.5.

### Internal

* Upgraded realm-core from v6.0.4 to v6.0.6
* Upgraded realm-sync from v5.0.3 to v5.0.5

5.0.1 Release notes (2020-05-27)
=============================================================

### Enhancements

* Add prebuilt binary for Xcode 11.5 to the release package.

### Fixed

* Fix linker error when building a xcframework for Catalyst.
  ([#6511](https://github.com/realm/realm-cocoa/issues/6511), since 4.3.1).
* Fix building for iOS devices when using Swift Package Manager
  ([#6522](https://github.com/realm/realm-cocoa/issues/6522), since 5.0.0).
* `List` and `RealmOptional` properties on frozen objects were not initialized
  correctly and would always report `nil` or an empty list.
  ([#6527](https://github.com/realm/realm-cocoa/issues/6527), since 5.0.0).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.5.

5.0.0 Release notes (2020-05-15)
=============================================================

NOTE: This version bumps the Realm file format to version 10. It is not
possible to downgrade version 9 or earlier. Files created with older versions
of Realm will be automatically upgraded. Only 
[Studio 3.11](https://github.com/realm/realm-studio/releases/tag/v3.11.0) or later will be able
to open the new file format.

### Enhancements

* Storing large binary blobs in Realm files no longer forces the file to be at
  least 8x the size of the largest blob.
* Reduce the size of transaction logs stored inside the Realm file, reducing
  file size growth from large transactions.
* Add support for frozen objects. `Realm`, `Results`, `List` and `Object` now
  have `freeze()` methods which return a frozen copy of the object. These
  objects behave similarly to creating unmanaged deep copies of the source
  objects. They can be read from any thread and do not update when writes are
  made to the Realm, but creating frozen objects does not actually copy data
  out of the Realm and so can be much faster and use less memory. Frozen
  objects cannot be mutated or observed for changes (as they never change).
  ([PR #6427](https://github.com/realm/realm-cocoa/pull/6427)).
* Add the `isFrozen` property to `Realm`, `Results`, `List` and `Object`.
* Add `Realm.Configuration.maxNumberOfActiveVersions`. Each time a write
  transaction is performed, a new version is created inside the Realm, and then
  any versions which are no longer in use are cleaned up. If too many versions
  are kept alive while performing writes (either due to a background thread
  performing a long operation that doesn't let the Realm on that thread
  refresh, or due to holding onto frozen versions for a long time) the Realm
  file will grow in size, potentially to the point where it is too large to be
  opened. Setting this configuration option will make write transactions which
  would cause the live version count to exceed the limit to instead fail.
* Add support for queue-confined Realms. Rather than being bound to a specific
  thread, queue-confined Realms are bound to a serial dispatch queue and can be
  used within blocks dispatched to that queue regardless of what thread they
  happen to run on. In addition, change notifications will be delivered to that
  queue rather than the thread's run loop. ([PR #6478](https://github.com/realm/realm-cocoa/pull/6478)).
* Add an option to deliver object and collection notifications to a specific
  serial queue rather than the current thread. ([PR #6478](https://github.com/realm/realm-cocoa/pull/6478)).
* Add Combine publishers for Realm types. Realm collections have a `.publisher`
  property which publishes the collection each time it changes, and a
  `.changesetPublisher` which publishes a `RealmCollectionChange` each time the
  collection changes. Corresponding publishers for Realm Objects can be
  obtained with the `publisher()` and `changesetPublisher()` global functions.
* Extend Combine publishers which output Realm types with a `.freeze()`
  function which will make the publisher instead output frozen objects.
* String primary keys no longer require a separate index, improving insertion
  and deletion performance without hurting lookup performance.
* Reduce the encrypted page reclaimer's impact on battery life when encryption
  is used. ([Core #3461](https://github.com/realm/realm-core/pull/3461)).

### Fixed

* The uploaded bytes in sync progress notifications was sometimes incorrect and
  wouldn't exactly equal the uploadable bytes when the uploaded completed.
* macOS binaries were built with the incorrect deployment target (10.14 rather
  than 10.9), resulting in linker warnings. ([#6299](https://github.com/realm/realm-cocoa/issues/6299), since 3.18.0).
* An internal datastructure for List properties could be double-deleted if the
  last reference was released from a thread other than the one which the List
  was created on at the wrong time. This would typically manifest as
  "pthread_mutex_destroy() failed", but could also result in other kinds of
  crashes. ([#6333](https://github.com/realm/realm-cocoa/issues/6333)).
* Sorting on float or double properties containing NaN values had inconsistent
  results and would sometimes crash due to out-of-bounds memory accesses.
  ([#6357](https://github.com/realm/realm-cocoa/issues/6357)).

### Breaking Changes

* The ObjectChange type in Swift is now generic and includes a reference to the
  object which changed. When using `observe(on:)` to receive notifications on a
  dispatch queue, the object will be confined to that queue.
* The Realm instance passed in the callback to asyncOpen() is now confined to
  the callback queue passed to asyncOpen() rather than the thread which the
  callback happens to be called on. This means that the Realm instance may be
  stored and reused in further blocks dispatched to that queue, but the queue
  must now be a serial queue.
* Files containing Date properties written by version of Realm prior to 1.0 can
  no longer be opened.
* Files containing Any properties can no longer be opened. This property type
  was never documented and was deprecated in 1.0.
* Deleting objects now preserves the order of objects reported by unsorted
  Results rather than performing a swap operation before the delete. Note that
  it is still not safe to assume that the order of objects in an unsorted
  Results is the order that the objects were created in.
* The minimum supported deployment target for iOS when using Swift Package
  Manager to install Realm is now iOS 11.

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Realm Studio: 3.11 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.4.1.

### Internal

* Upgraded realm-core from v5.23.8 to v6.0.4
* Upgraded realm-sync from v4.9.5 to v5.0.3

5.0.0-beta.6 Release notes (2020-05-08)
=============================================================

### Enhancements

* Add support for queue-confined Realms. Rather than being bound to a specific
  thread, queue-confined Realms are bound to a serial dispatch queue and can be
  used within blocks dispatched to that queue regardless of what thread they
  happen to run on. In addition, change notifications will be delivered to that
  queue rather than the thread's run loop. ([PR #6478](https://github.com/realm/realm-cocoa/pull/6478)).
* Add an option to deliver object and collection notifications to a specific
  serial queue rather than the current thread. ([PR #6478](https://github.com/realm/realm-cocoa/pull/6478)).

### Fixed

* The uploaded bytes in sync progress notifications was sometimes incorrect and
  wouldn't exactly equal the uploadable bytes when the uploaded completed.

### Breaking Changes

* The Realm instance passed in the callback to asyncOpen() is now confined to
  the callback queue passed to asyncOpen() rather than the thread which the
  callback happens to be called on. This means that the Realm instance may be
  stored and reused in further blocks dispatched to that queue, but the queue
  must now be a serial queue.

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.4.1.

### Internal

* Upgraded realm-core from v6.0.3 to v6.0.4
* Upgraded realm-sync from v5.0.1 to v5.0.3

4.4.1 Release notes (2020-04-16)
=============================================================

### Enhancements

* Upgrade Xcode 11.4 binaries to Xcode 11.4.1.

### Fixed

* Fix a "previous <= m_schema_transaction_version_max" assertion failure caused
  by a race condition that could occur after performing a migration. (Since 3.0.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.4.1.

5.0.0-beta.3 Release notes (2020-02-26)
=============================================================

Based on 4.3.2 and also includes all changes since 4.3.0.

### Enhancements

* Add support for frozen objects. `Realm`, `Results`, `List` and `Object` now
  have `freeze()` methods which return a frozen copy of the object. These
  objects behave similarly to creating unmanaged deep copies of the source
  objects. They can be read from any thread and do not update when writes are
  made to the Realm, but creating frozen objects does not actually copy data
  out of the Realm and so can be much faster and use less memory. Frozen
  objects cannot be mutated or observed for changes (as they never change).
  ([PR #6427](https://github.com/realm/realm-cocoa/pull/6427)).
* Add the `isFrozen` property to `Realm`, `Results`, `List` and `Object`.
* Add `Realm.Configuration.maxNumberOfActiveVersions`. Each time a write
  transaction is performed, a new version is created inside the Realm, and then
  any versions which are no longer in use are cleaned up. If too many versions
  are kept alive while performing writes (either due to a background thread
  performing a long operation that doesn't let the Realm on that thread
  refresh, or due to holding onto frozen versions for a long time) the Realm
  file will grow in size, potentially to the point where it is too large to be
  opened. Setting this configuration option will make write transactions which
  would cause the live version count to exceed the limit to instead fail.


### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.3.

### Internal

* Upgraded realm-core from v6.0.0-beta.3 to v6.0.3
* Upgraded realm-sync from v5.0.0-beta.2 to v5.0.1

5.0.0-beta.2 Release notes (2020-01-13)
=============================================================

Based on 4.3.0 and also includes all changes since 4.1.1.

### Fixed

* Fix compilation when using CocoaPods targeting iOS versions older than 11 (since 5.0.0-alpha).

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.3.

### Internal

* Upgraded realm-core from v6.0.0-beta.2 to v6.0.0-beta.3
* Upgraded realm-sync from v5.0.0-beta.1 to v5.0.0-beta.2

5.0.0-beta.1 Release notes (2019-12-13)
=============================================================

Based on 4.1.1 and also includes all changes since 4.1.0.

NOTE: This version bumps the Realm file format to version 10. It is not possible to downgrade version 9 or earlier. Files created with older versions of Realm will be automatically upgraded.

### Enhancements

* String primary keys no longer require a separate index, improving insertion
  and deletion performance without hurting lookup performance.
* Reduce the encrypted page reclaimer's impact on battery life when encryption
  is used. ([Core #3461](https://github.com/realm/realm-core/pull/3461)).

### Fixed

* Fix an error when a table-backed Results was accessed immediately after
  deleting the object previously at the index being accessed (since
  5.0.0-alpha.1).
* macOS binaries were built with the incorrect deployment target (10.14 rather
  than 10.9), resulting in linker warnings. ([#6299](https://github.com/realm/realm-cocoa/issues/6299), since 3.18.0).
* An internal datastructure for List properties could be double-deleted if the
  last reference was released from a thread other than the one which the List
  was created on at the wrong time. This would typically manifest as
  "pthread_mutex_destroy() failed", but could also result in other kinds of
  crashes. ([#6333](https://github.com/realm/realm-cocoa/issues/6333)).
* Sorting on float or double properties containing NaN values had inconsistent
  results and would sometimes crash due to out-of-bounds memory accesses.
  ([#6357](https://github.com/realm/realm-cocoa/issues/6357)).

### Known Issues

* Changing which property of an object is the primary key in a migration will
  break incoming links to objects of that type.
* Changing the primary key of an object with Data properties in a migration
  will crash.

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* APIs are backwards compatible with all previous releases in the 5.x.y series.
* Carthage release for Swift is built with Xcode 11.3.

### Internal

* Upgraded realm-core from v6.0.0-alpha.24 to v6.0.0-beta.2
* Upgraded realm-sync from 4.7.1-core6.5 to v5.0.0-beta.1

5.0.0-alpha.1 Release notes (2019-11-14)
=============================================================

Based on 4.1.0.

### Enhancements

* Add `-[RLMRealm fileExistsForConfiguration:]`/`Realm.fileExists(for:)`,
  which checks if a local Realm file exists for the given configuration.
* Add `-[RLMRealm deleteFilesForConfiguration:]`/`Realm.deleteFiles(for:)`
  to delete the Realm file and all auxiliary files for the given configuration.
* Storing large binary blobs in Realm files no longer forces the file to be at
  least 8x the size of the largest blob.
* Reduce the size of transaction logs stored inside the Realm file, reducing
  file size growth from large transactions.

NOTE: This version bumps the Realm file format to version 10. It is not
possible to downgrade version 9 or earlier. Files created with older versions
of Realm will be automatically upgraded. This automatic upgrade process is not
yet well tested. Do not open Realm files with data you care about with this
alpha version.

### Breaking Changes

* Files containing Date properties written by version of Realm prior to 1.0 can
  no longer be opened.
* Files containing Any properties can no longer be opened. This property type
  was never documented and was deprecated in 1.0.

### Compatibility

* File format: Generates Realms with format v10 (Reads and upgrades v9)
* Realm Object Server: 3.21.0 or later.
* APIs are backwards compatible with all previous releases in the 4.x.y series.
* Carthage release for Swift is built with Xcode 11.3.
* Carthage release for Swift is built with Xcode 11.2.1.

### Internal

* Upgraded realm-core from 5.23.6 to v6.0.0-alpha.24.
* Upgraded realm-sync from 4.8.2 to 4.7.1-core6.5.

4.4.0 Release notes (2020-03-26)
=============================================================

Swift 4.0 and Xcode 10.3 are now the minimum supported versions.

### Enhancements

* Allow setting the `fileUrl` for synchronized Realms. An appropriate local
  path based on the sync URL will still be used if it is not overridden.
  ([PR #6454](https://github.com/realm/realm-cocoa/pull/6454)).
* Add Xcode 11.4 binaries to the release package.

### Fixed

* None.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.4.

4.3.2 Release notes (2020-02-06)
=============================================================

### Enhancements

* Similar to `autoreleasepool()`, `realm.write()` now returns the value which
  the block passed to it returns. Returning `Void` from the block is still allowed.

### Fixed

* Fix a memory leak attributed to `property_copyAttributeList` the first time a
  Realm is opened when using Realm Swift. ([#6409](https://github.com/realm/realm-cocoa/issues/6409), since 4.0.0).
* Connecting to a `realms:` sync URL would crash at runtime on iOS 11 (and no
  other iOS versions) inside the SSL validation code. (Since 4.3.1).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.3.

### Internal

* Upgraded realm-sync from 4.9.4 to 4.9.5.

4.3.1 Release notes (2020-01-16)
=============================================================

### Enhancements

* Reduce the encrypted page reclaimer's impact on battery life when encryption
  is used. ([Core #3461](https://github.com/realm/realm-core/pull/3461)).

### Fixed

* macOS binaries were built with the incorrect deployment target (10.14 rather
  than 10.9), resulting in linker warnings. ([#6299](https://github.com/realm/realm-cocoa/issues/6299), since 3.18.0).
* An internal datastructure for List properties could be double-deleted if the
  last reference was released from a thread other than the one which the List
  was created on at the wrong time. This would typically manifest as
  "pthread_mutex_destroy() failed", but could also result in other kinds of
  crashes. ([#6333](https://github.com/realm/realm-cocoa/issues/6333)).
* Sorting on float or double properties containing NaN values had inconsistent
  results and would sometimes crash due to out-of-bounds memory accesses.
  ([#6357](https://github.com/realm/realm-cocoa/issues/6357)).
* A NOT query on a `List<Object>` which happened to have the objects in a
  different order than the underlying table would sometimes include the object
  immediately before an object which matches the query. ([#6289](https://github.com/realm/realm-cocoa/issues/6289), since 0.90.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.3.

### Internal

* Upgraded realm-core from 5.23.6 to 5.23.8.
* Upgraded realm-sync from 4.9.0 to 4.9.4.

4.3.0 Release notes (2019-12-19)
=============================================================

### Enhancements

* Add the ability to set a custom logger function on `RLMSyncManager` which is
  called instead of the default NSLog-based logger.
* Expose configuration options for the various types of sync connection
  timeouts and heartbeat intervals on `RLMSyncManager`.
* Add an option to have `Realm.asyncOpen()` report an error if the connection
  times out rather than swallowing the error and attempting to reconnect until
  it succeeds.

### Fixed

* Fix a crash when using value(forKey:) on a LinkingObjects property (including
  when doing so indirectly, such as by querying on that property).
  ([#6366](https://github.com/realm/realm-cocoa/issues/6366), since 4.0.0).
* Fix a rare crash in `ClientHistoryImpl::integrate_server_changesets()` which
  would only happen in Debug builds (since v3.0.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.3.

### Internal

* Upgraded realm-sync from 4.8.2 to 4.9.0.

4.2.0 Release notes (2019-12-16)
=============================================================

### Enhancements

* Add `-[RLMRealm fileExistsForConfiguration:]`/`Realm.fileExists(for:)`,
  which checks if a local Realm file exists for the given configuration.
* Add `-[RLMRealm deleteFilesForConfiguration:]`/`Realm.deleteFiles(for:)`
  to delete the Realm file and all auxiliary files for the given configuration.

### Fixed

* None.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.3.

4.1.1 Release notes (2019-11-18)
=============================================================

### Fixed

* The UpdatePolicy passed to `realm.add()` or `realm.create()` was not properly
  propagated when adding objects within a `List`, which could result in
  spurious change notifications when using `.modified`.
  ([#6321](https://github.com/realm/realm-cocoa/issues/6321), since v3.16.0)
* Fix a rare deadlock when a Realm collection or object was observed, then
  `refresh()` was explicitly called, and then the NotificationToken from the
  observation was destroyed on a different thread (since 0.98.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.2.

4.1.0 Release notes (2019-11-13)
=============================================================

### Enhancements

* Improve performance of queries over a link where the final target property
  has an index.
* Restore support for storing `@objc enum` properties on RealmSwift.Object
  subclasses (broken in 4.0.0), and add support for storing them in
  RealmOptional properties.

### Fixed

* The sync client would fail to reconnect after failing to integrate a
  changeset. The bug would lead to further corruption of the client’s Realm
  file. ([RSYNC-48](https://jira.mongodb.org/browse/RSYNC-48), since v3.2.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.2.

### Internal

* Upgraded realm-core from 5.23.5 to 5.23.6.
* Upgraded realm-sync from 4.7.11 to 4.8.2

4.0.0 Release notes (2019-11-08)
=============================================================

### Breaking Changes

* All previously deprecated functionality has now been removed entirely.
* The schema discovery logic for RealmSwift.Object subclasses has been
  rewritten in Swift. This should not have any effect on valid class
  definitions, but there may be types of invalid definitions which previously
  worked by coincidence and no longer do.
* `SyncSubscription` no longer has a generic type parameter, as the type was
  not actually used for anything.
* The following Swift types have changed from `final class` to `struct`:
    - AnyRealmCollection
    - LinkingObjects
    - ObjectiveCSupport
    - Realm
    - Results
    - SyncSubscription
    - ThreadSafeReference
  There is no intended change in semantics from this, but certain edge cases
  may behave differently.
* The designated initializers defined by RLMObject and Object other than
  zero-argument `init` have been replaced with convenience initializers.
* The implementation of the path-based permissions API has been redesigned to
  accomodate changes to the server. This should be mostly a transparent change,
  with two main exceptions:
  1. SyncPermission objects are no longer live Realm objects, and retrieving
  permissions gives an Array<SyncPermission> rather than Results<SyncPermission>.
  Getting up-to-date permissions now requires calling retrievePermissions() again
  rather than observing the permissions.
  2. The error codes for permissions functions have changed. Rather than a
  separate error type and set of error codes, permission functions now produce
  SyncAuthErrors.

### Enhancements

* Improve performance of initializing Realm objects with List properties.

### Fixed

* None.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.2.

3.21.0 Release notes (2019-11-04)
=============================================================

### Enhancements

* Add prebuilt binaries for Xcode 11.2.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.2.

3.20.0 Release notes (2019-10-21)
=============================================================

### Enhancements

* Add support for custom refresh token authentication. This allows a user to be
  authorized with an externally-issued refresh token when ROS is configured to
  recognize the external issuer as a refresh token validator.
  ([PR #6311](https://github.com/realm/realm-cocoa/pull/6311)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.

3.19.1 Release notes (2019-10-17)
=============================================================

### Enhancements

* Improve performance of sync changeset integration. Transactions involving a
  very large number of objects and cheap operations on each object are as much
  as 20% faster.

### Fixed

* Fix a crash when a RLMArray/List of primitives was observed and then the
  containing object was deleted before the first time that the background
  notifier could run.
  ([Issue #6234](https://github.com/realm/realm-cocoa/issues/6234, since 3.0.0)).
* Remove an incorrect assertion that would cause crashes inside
  `TableInfoCache::get_table_info()`, with messages like "Assertion failed: info.object_id_index == 0 [3, 0]".
  (Since 3.18.0, [#6268](https://github.com/realm/realm-cocoa/issues/6268) and [#6257](https://github.com/realm/realm-cocoa/issues/6257)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.0.

### Internal

* Upgrade to REALM_SYNC_VERSION=4.7.11

3.19.0 Release notes (2019-09-27)
=============================================================

### Enhancements

* Expose ObjectSchema.objectClass in Swift as looking up the class via
  NSClassFromString() can be complicated for Swift types.
  ([PR #6244](https://github.com/realm/realm-cocoa/pull/6244)).
* Add support for suppressing notifications using closure-based write/transaction methods.
  ([PR #6252](https://github.com/realm/realm-cocoa/pull/6252)).

### Fixed

* IN or chained OR equals queries on an unindexed string column would fail to
  match some results if any of the strings were 64 bytes or longer.
  ([Core #3386](https://github.com/realm/realm-core/pull/3386), since 3.14.2).
* Query Based Sync subscriptions for queries involving a null timestamp were
  not sent to the server correctly and would match no objects.
  ([Core #3389](https://github.com/realm/realm-core/pull/3388), since 3.17.3).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.0.

### Internal

* Upgrade to REALM_CORE_VERSION=5.23.5
* Upgrade to REALM_SYNC_VERSION=4.7.8

3.18.0 Release notes (2019-09-13)
=============================================================

The file format for synchronized Realms has changed. Old Realms will be
automatically upgraded when they are opened. Once upgraded, the files will not
be openable by older versions of Realm. The upgrade should not take a
significant amount of time to run or run any risk of errors.

This does not effect non-synchronized Realms.

### Enhancements

* Improve performance of queries on Date properties
  ([Core #3344](https://github.com/realm/realm-core/pull/3344), [Core #3351](https://github.com/realm/realm-core/pull/3351)).
* Syncronized Realms are now more aggressive about trimming local history that
  is no longer needed. This should reduce file size growth in write-heavy
  workloads. ([Sync #3007](https://github.com/realm/realm-sync/issues/3007)).
* Add support for building Realm as an xcframework.
  ([PR #6238](https://github.com/realm/realm-cocoa/pull/6238)).
* Add prebuilt libraries for Xcode 11 to the release package.
  ([PR #6248](https://github.com/realm/realm-cocoa/pull/6248)).
* Add a prebuilt library for Catalyst/UIKit For Mac to the release package
  ([PR #6248](https://github.com/realm/realm-cocoa/pull/6248)).

### Fixed

* If a signal interrupted a msync() call, Realm would throw an exception and
  the write transaction would fail. This behavior has new been changed to retry
  the system call instead. ([Core #3352](https://github.com/realm/realm-core/issues/3352))
* Queries on the sum or average of an integer property would sometimes give
  incorrect results. ([Core #3356](https://github.com/realm/realm-core/pull/3356)).
* Opening query-based synchronized Realms with a small number of subscriptions
  performed an unneccesary write transaction. ([ObjectStore #815](https://github.com/realm/realm-object-store/pull/815)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 11.0

### Deprecations

* `RLMIdentityProviderNickname` has been deprecated in favor of `RLMIdentityProviderUsernamePassword`.
* `+[RLMIdentityProvider credentialsWithNickname]` has been deprecated in favor of `+[RLMIdentityProvider credentialsWithUsername]`.
* `Sync.nickname(String, Bool)` has been deprecated in favor of `Sync.usernamePassword(String, String, Bool)`.

3.17.3 Release notes (2019-07-24)
=============================================================

### Enhancements

* Add Xcode 10.3 binaries to the release package. Remove the Xcode 9.2 and 9.3 binaries.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.3.

3.17.1 Release notes (2019-07-10)
=============================================================

### Enhancements

* Add support for canceling asynchronous opens using a new AsyncOpenTask
  returned from the asyncOpen() call. ([PR #6193](https://github.com/realm/realm-cocoa/pull/6193)).
* Importing the Realm SPM package can now be done by pinning to a version
  rather than a branch.

### Fixed

* Queries on a List/RLMArray which checked an indexed int property would
  sometimes give incorrect results.
  ([#6154](https://github.com/realm/realm-cocoa/issues/6154)), since v3.15.0)
* Queries involving an indexed int property had a memory leak if run multiple
  times. ([#6186](https://github.com/realm/realm-cocoa/issues/6186)), since v3.15.0)
* Creating a subscription with `includeLinkingObjects:` performed unneccesary
  comparisons, making it extremely slow when large numbers of objects were
  involved. ([Core #3311](https://github.com/realm/realm-core/issues/3311), since v3.15.0)

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.17.0 Release notes (2019-06-28)
=============================================================

### Enhancements

* Add support for including Realm via Swift Package Manager. This currently
  requires depending on the branch "master" rather than pinning to a version
  (i.e. `.package(url: "https://github.com/realm/realm-cocoa", .branch("master"))`).
  ([#6187](https://github.com/realm/realm-cocoa/pull/6187)).
* Add Codable conformance to RealmOptional and List, and Encodable conformance to Results.
  ([PR #6172](https://github.com/realm/realm-cocoa/pull/6172)).

### Fixed

* Attempting to observe an unmanaged LinkingObjects object crashed rather than
  throwing an approriate exception (since v0.100.0).
* Opening an encrypted Realm could potentially report that a valid file was
  corrupted if the system was low on free memory.
  (since 3.14.0, [Core #3267](https://github.com/realm/realm-core/issues/3267))
* Calling `Realm.asyncOpen()` on multiple Realms at once would sometimes crash
  due to a `FileNotFound` exception being thrown on a background worker thread.
  (since 3.16.0, [ObjectStore #806](https://github.com/realm/realm-object-store/pull/806)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.16.2 Release notes (2019-06-14)
=============================================================

### Enhancements

* Add support for Xcode 11 Beta 1. Xcode betas are only supported when building
  from source, and not when using a prebuilt framework.
  ([PR #6164](https://github.com/realm/realm-cocoa/pull/6164)).

### Fixed

* Using asyncOpen on query-based Realms which didn't already exist on the local
  device would fail with error 214.
  ([#6178](https://github.com/realm/realm-cocoa/issues/6178), since 3.16.0).
* asyncOpen on query-based Realms did not wait for the server-created
  permission objects to be downloaded, resulting in crashes if modifications to
  the permissions were made before creating a subscription for the first time (since 3.0.0).
* EINTR was not handled correctly in the notification worker, which may have
  resulted in inconsistent and rare assertion failures in
  `ExternalCommitHelper::listen()` when building with assertions enabled.
  (PR: [#804](https://github.com/realm/realm-object-store/pull/804), since 0.91.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.16.1 Release notes (2019-05-31)
=============================================================

### Fixed

* The static type passed at compile time to `realm.create()` was checked for a
  primary key rather than the actual type passed at runtime, resulting in
  exceptions like "''RealmSwiftObject' does not have a primary key and can not
  be updated'" being thrown even if the object type being created has a primary
  key. (since 3.16.0, [#6159](https://github.com/realm/realm-cocoa/issues/6159)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.16.0 Release notes (2019-05-29)
=============================================================

### Enhancements

* Add an option to only set the properties which have values different from the
  existing ones when updating an existing object with
  `Realm.create()`/`-[RLMObject createOrUpdateInRealm:withValue:]`. This makes
  notifications report only the properties which have actually changed, and
  improves Object Server performance by reducing the number of operations to
  merge. (Issue: [#5970](https://github.com/realm/realm-cocoa/issues/5970),
  PR: [#6149](https://github.com/realm/realm-cocoa/pull/6149)).
* Using `-[RLMRealm asyncOpenWithConfiguration:callbackQueue:]`/`Realm.asyncOpen()` to open a
  synchronized Realm which does not exist on the local device now uses an
  optimized transfer method to download the initial data for the Realm, greatly
  speeding up the first start time for applications which use full
  synchronization. This is currently not applicable to query-based
  synchronization. (PR: [#6106](https://github.com/realm/realm-cocoa/pull/6106)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.15.0 Release notes (2019-05-06)
=============================================================

The minimum version of Realm Object Server has been increased to 3.21.0 and
attempting to connect to older versions will produce protocol mismatch errors.
Realm Cloud has already been upgraded to this version, and users using that do
not need to worry about this.

### Enhancements

* Add `createdAt`, `updatedAt`, `expiresAt` and `timeToLive` properties to
  `RLMSyncSubscription`/`SyncSubscription`. These properties will be `nil` for
  subscriptions created with older versions of Realm, but will be automatically
  populated for newly-created subscriptions.
* Add support for transient subscriptions by setting the `timeToLive` when
  creating the subscription. The next time a subscription is created or updated
  after that time has elapsed the subscription will be automatically removed.
* Add support for updating existing subscriptions with a new query or limit.
  This is done by passing `update: true` (in swift) or setting
  `options.overwriteExisting = YES` (in obj-c) when creating the subscription,
  which will make it update the existing subscription with the same name rather
  than failing if one already exists with that name.
* Add an option to include the objects from
  `RLMLinkingObjects`/`LinkingObjects` properties in sync subscriptions,
  similarly to how `RLMArray`/`List` automatically pull in the contained
  objects.
* Improve query performance for chains of OR conditions (or an IN condition) on
  an unindexed integer or string property.
  ([Core PR #2888](https://github.com/realm/realm-core/pull/2888) and
  [Core PR #3250](https://github.com/realm/realm-core/pull/3250)).
* Improve query performance for equality conditions on indexed integer properties.
  ([Core PR #3272](https://github.com/realm/realm-core/pull/3272)).
* Adjust the file allocation algorithm to reduce fragmentation caused by large
  numbers of small blocks.
* Improve file allocator logic to reduce fragmentation and improve commit
  performance after many writes. ([Core PR #3278](https://github.com/realm/realm-core/pull/3278)).

### Fixed

* Making a query that compares two integer properties could cause a
  segmentation fault on x86 (i.e. macOS only).
  ([Core PR #3253](https://github.com/realm/realm-core/pull/3256)).
* The `downloadable_bytes` parameter passed to sync progress callbacks reported
  a value which correlated to the amount of data left to download, but not
  actually the number of bytes which would be downloaded.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.21.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.14.2 Release notes (2019-04-25)
=============================================================

### Enhancements

* Updating `RLMSyncManager.customRequestHeaders` will immediately update all
  currently active sync session with the new headers rather than requiring
  manually closing the Realm and reopening it.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.
* Carthage release for Swift is built with Xcode 10.2.1.

3.14.1 Release notes (2019-04-04)
=============================================================

### Fixed

* Fix "Cannot find interface declaration for 'RealmSwiftObject', superclass of
  'MyRealmObjectClass'" errors when building for a simulator with Xcode 10.2
  with "Install Objective-C Compatibility Header" enabled.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.
* Carthage release for Swift is built with Xcode 10.2.

3.14.0 Release notes (2019-03-27)
=============================================================

### Enhancements

* Reduce memory usage when committing write transactions.
* Improve performance of compacting encrypted Realm files.
  ([PR #3221](https://github.com/realm/realm-core/pull/3221)).
* Add a Xcode 10.2 build to the release package.

### Fixed

* Fix a memory leak whenever Realm makes a HTTP(s) request to the Realm Object
  Server (Issue [#6058](https://github.com/realm/realm-cocoa/issues/6058), since 3.8.0).
* Fix an assertion failure when creating an object in a synchronized Realm
  after creating an object with a null int primary key in the same write
  transaction.
  ([PR #3227](https://github.com/realm/realm-core/pull/3227)).
* Fix some new warnings when building with Xcode 10.2 beta.
* Properly clean up sync sessions when the last Realm object using the session
  is deallocated while the session is explicitly suspended (since 3.9.0).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.
* Carthage release for Swift is built with Xcode 10.2.

### Internal

* Throw an exception rather than crashing with an assertion failure in more
  cases when opening invalid Realm files.
* Upgrade to REALM_CORE_VERSION=5.14.0
* Upgrade to REALM_SYNC_VERSION=3.15.1

3.13.1 Release notes (2019-01-03)
=============================================================

### Fixed

* Fix a crash when iterating over `Realm.subscriptions()` using for-in.
  (Since 3.13.0, PR [#6050](https://github.com/realm/realm-cocoa/pull/6050)).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.

3.13.0 Release notes (2018-12-14)
=============================================================

### Enhancements

* Add `Realm.subscriptions()`/`-[RLMRealm subscriptions]` and
  `Realm.subscription(named:)`/`-[RLMRealm subscriptionWithName:]` to enable
  looking up existing query-based sync subscriptions.
  (PR: https://github.com/realm/realm-cocoa/pull/6029).

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.

3.12.0 Release notes (2018-11-26)
=============================================================

### Enhancements

* Add a User-Agent header to HTTP requests made to the Realm Object Server. By
  default, this contains information about the Realm library version and your
  app's bundle ID. The application identifier can be customized by setting
  `RLMSyncManager.sharedManager.userAgent`/`SyncManager.shared.userAgent` prior
  to opening a synchronized Realm.
  (PR: https://github.com/realm/realm-cocoa/pull/6007).
* Add Xcode 10.1 binary to the prebuilt package.

### Fixed

* None.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.

### Internal

* None.


3.11.2 Release notes (2018-11-15)
=============================================================

### Enhancements

* Improve the performance of the merge algorithm used for integrating remote
  changes from the server. In particular, changesets involving many objects
  which all link to a single object should be greatly improved.

### Fixed

* Fix a memory leak when removing notification blocks from collections.
  PR: [#702](https://github.com/realm/realm-object-store/pull/702), since 1.1.0.
* Fix re-sorting or distincting an already-sorted Results using values from
  linked objects. Previously the unsorted order was used to read the values
  from the linked objects.
  PR [#3102](https://github.com/realm/realm-core/pull/3102), since 3.1.0.
* Fix a set of bugs which could lead to bad changeset assertions when using
  sync. The assertions would look something like the following:
  `[realm-core-5.10.0] Assertion failed: ndx < size() with (ndx, size()) =  [742, 742]`.

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.

### Internal

* None.


3.11.1 Release notes (2018-10-19)
=============================================================

### Enhancements

* None.

### Fixed

* Fix `SyncUser.requestEmailConfirmation` not triggering the email confirmation
  flow on ROS. (PR [#5953](https://github.com/realm/realm-cocoa/pull/5953), since 3.5.0)
* Add some missing validation in the getters and setters of properties on
  managed Realm objects, which would sometimes result in an application
  crashing with a segfault rather than the appropriate exception being thrown
  when trying to write to an object which has been deleted.
  (PR [#5952](https://github.com/realm/realm-cocoa/pull/5952), since 2.8.0)

### Compatibility

* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* Realm Object Server: 3.11.0 or later.

### Internal

* None.


3.11.0 Release notes (2018-10-04)
=============================================================

### Enhancements
* Reduce memory usage when integrating synchronized changes sent by ROS.
* Devices will now report download progress for read-only Realms, allowing the
  server to compact Realms more aggressively and reducing the amount of
  server-side storage space required.

### Fixed
* Fix a crash when adding an object with a non-`@objc` `String?` property which
  has not been explicitly ignored to a Realm on watchOS 5 (and possibly other
  platforms when building with Xcode 10).
  (Issue: [5929](https://github.com/realm/realm-cocoa/issues/5929)).
* Fix some merge algorithm bugs which could result in `BadChangesetError`
  being thrown when integrating changes sent by the server.

### Compatibility
* File format: Generates Realms with format v9 (Reads and upgrades all previous formats)
* **NOTE!!!
  You will need to upgrade your Realm Object Server to at least version 3.11.0
  or use [Realm Cloud](https://cloud.realm.io).
  If you try to connect to a ROS v3.10.x or previous, you will see an error
  like `Wrong protocol version in Sync HTTP request, client protocol version = 25,
  server protocol version = 24`.**

### Internal
* Update to Sync 3.12.2.


3.10.0 Release notes (2018-09-19)
=============================================================

Prebuilt binaries are now built for Xcode 9.2, 9.3, 9.4 and 10.0.

Older versions of Xcode are still supported when building from source, but you
should be migrating to at least Xcode 9.2 as soon as possible.

### Enhancements

* Add support for Watch Series 4 by adding an arm64_32 slice to the library.

3.9.0 Release notes (2018-09-10)
=============================================================

### Enhancements

* Expose RLMSyncUser.refreshToken publicly so that it can be used for custom
  HTTP requests to Realm Object Server.
* Add RLMSyncSession.connectionState, which reports whether the session is
  currently connected to the Realm Object Server or if it is offline.
* Add `-suspend` and `-resume` methods to `RLMSyncSession` to enable manually
  pausing data synchronization.
* Add support for limiting the number of objects matched by a query-based sync
  subscription. This requires a server running ROS 3.10.1 or newer.

### Bugfixes

* Fix crash when getting the description of a `MigrationObject` which has
  `List` properties.
* Fix crash when calling `dynamicList()` on a `MigrationObject`.

3.8.0 Release notes (2018-09-05)
=============================================================

### Enhancements

* Remove some old and no longer applicable migration logic which created an
  unencrypted file in the sync metadata directory containing a list of ROS URLs
  connected to.
* Add support for pinning SSL certificates used for https and realms
  connections by setting `RLMSyncManager.sharedManager.pinnedCertificatePaths`
  in obj-c and `SyncManager.shared.pinnedCertificatePaths` in Swift.

### Bugfixes

* Fix warnings when building Realm as a static framework with CocoaPods.

3.7.6 Release notes (2018-08-08)
=============================================================

### Enhancements

* Speed up the actual compaction when using compact-on-launch.
* Reduce memory usage when locally merging changes from sync.
* When first connecting to a server, wait to begin uploading changes until
  after all changes have been downloaded to reduce the server-side load for
  query-based sync.

3.7.5 Release notes (2018-07-23)
=============================================================

### Enhancements

* Improve performance of applying remote changesets from sync.
* Improve performance of creating objects with string primary keys.
* Improve performance of large write transactions.
* Adjust file space allocation strategy to reduce fragmentation, producing
  smaller Realm files and typically better performance.
* Close network connections immediately when a sync session is destroyed.
* Report more information in `InvalidDatabase` exceptions.

### Bugfixes

* Fix permission denied errors for RLMPlatform.h when building with CocoaPods
  and Xcode 10 beta 3.
* Fix a use-after-free when canceling a write transaction which could result in
  incorrect "before" values in KVO observations (typically `nil` when a non-nil
  value is expected).
* Fix several bugs in the merge algorithm that could lead to memory corruption
  and crashes with errors like "bad changeset" and "unreachable code".

3.7.4 Release notes (2018-06-19)
=============================================================

### Bugfixes

* Fix a bug which could potentially flood Realm Object Server with PING
  messages after a client device comes back online.

3.7.3 Release notes (2018-06-18)
=============================================================

### Enhancements

* Avoid performing potentially large amounts of pointless background work for
  LinkingObjects instances which are accessed and then not immediate deallocated.

### Bugfixes

* Fix crashes which could result from extremely fragmented Realm files.
* Fix a bug that could result in a crash with the message "bad changeset error"
  when merging changesets from the server.

3.7.2 Release notes (2018-06-13)
=============================================================

### Enhancements

* Add some additional consistency checks that will hopefully produce better
  errors when the "prev_ref + prev_size <= ref" assertion failure occurs.

### Bugfixes

* Fix a problem in the changeset indexing algorithm that would sometimes
  cause "bad permission object" and "bad changeset" errors.
* Fix a large number of linking warnings about symbol visibility by aligning
  compiler flags used.
* Fix large increase in size of files produced by `Realm.writeCopy()` introduced in 3.6.0.

3.7.1 Release notes (2018-06-07)
=============================================================

* Add support for compiling Realm Swift with Xcode 10 beta 1.

3.7.0 Release notes (2018-06-06)
=============================================================

The feature known as Partial Sync has been renamed to Query-based
Synchronization. This has impacted a number of API's. See below for the
details.

### Deprecations

* `+[RLMSyncConfiguration initWithUser] has been deprecated in favor of `-[RLMSyncUser configurationWithURL:url].
* `+[RLMSyncConfiguration automaticConfiguration] has been deprecated in favor of `-[RLMSyncUser configuration].
* `+[RLMSyncConfiguration automaticConfigurationForUser] has been deprecated in favor of `-[RLMSyncUser configuration].
* `-[RLMSyncConfiguration isPartial] has been deprecated in favor of `-[RLMSyncConfiguration fullSynchronization]`.

### Enhancements

* Add `-[RLMRealm syncSession]` and  `Realm.syncSession` to obtain the session used for a synchronized Realm.
* Add `-[RLMSyncUser configuration]`. Query-based sync is the default sync mode for this configuration.
* Add `-[RLMSyncUser configurationWithURL:url]`. Query-based sync is the default sync mode for this configuration.

3.6.0 Release notes (2018-05-29)
=============================================================

### Enhancements

* Improve performance of sync metadata operations and resolving thread-safe
  references.
* `shouldCompactOnLaunch` is now supported for compacting the local data of
  synchronized Realms.

### Bugfixes

* Fix a potential deadlock when a sync session progress callback held the last
  strong reference to the sync session.
* Fix some cases where comparisons to `nil` in queries were not properly
  serialized when subscribing to a query.
* Don't delete objects added during a migration after a call to `-[RLMMigration
  deleteDataForClassName:]`.
* Fix incorrect results and/or crashes when multiple `-[RLMMigration
  enumerateObjects:block:]` blocks deleted objects of the same type.
* Fix some edge-cases where `-[RLMMigration enumerateObjects:block:]`
  enumerated the incorrect objects following deletions.
* Restore the pre-3.5.0 behavior for Swift optional properties missing an ivar
  rather than crashing.

3.5.0 Release notes (2018-04-25)
=============================================================

### Enhancements

* Add wrapper functions for email confirmation and password reset to `SyncUser`.

### Bugfixes

* Fix incorrect results when using optional chaining to access a RealmOptional
  property in Release builds, or otherwise interacting with a RealmOptional
  object after the owning Object has been deallocated.

3.4.0 Release notes (2018-04-19)
=============================================================

The prebuilt binary for Carthage is now built for Swift 4.1.

### Enhancements

* Expose `RLMSyncManager.authorizationHeaderName`/`SyncManager.authorizationHeaderName`
  as a way to override the transport header for Realm Object Server authorization.
* Expose `RLMSyncManager.customRequestHeaders`/`SyncManager.customRequestHeaders`
  which allows custom HTTP headers to be appended on requests to the Realm Object Server.
* Expose `RLMSSyncConfiguration.urlPrefix`/`SyncConfiguration.urlPrefix` as a mechanism
  to replace the default path prefix in Realm Sync WebSocket requests.

3.3.2 Release notes (2018-04-03)
=============================================================

Add a prebuilt binary for Xcode 9.3.

3.3.1 Release notes (2018-03-28)
=============================================================

Realm Object Server v3.0.0 or newer is required when using synchronized Realms.

### Enhancements

* Expose `RLMObject.object(forPrimaryKey:)` as a factory method for Swift so
  that it is callable with recent versions of Swift.

### Bugfixes

* Exclude the RLMObject-derived Permissions classes from the types repored by
  `Realm.Configuration.defaultConfiguration.objectTypes` to avoid a failed
  cast.
* Cancel pending `Realm.asyncOpen()` calls when authentication fails with a
  non-transient error such as missing the Realm path in the URL.
* Fix "fcntl() inside prealloc()" errors on APFS.

3.3.0 Release notes (2018-03-19)
=============================================================

Realm Object Server v3.0.0 or newer is required when using synchronized Realms.

### Enhancements

* Add `Realm.permissions`, `Realm.permissions(forType:)`, and `Realm.permissions(forClassNamed:)` as convenience
  methods for accessing the permissions of the Realm or a type.

### Bugfixes

* Fix `+[RLMClassPermission objectInRealm:forClass:]` to work for classes that are part of the permissions API,
  such as `RLMPermissionRole`.
* Fix runtime errors when applications define an `Object` subclass with the
  same name as one of the Permissions object types.

3.2.0 Release notes (2018-03-15)
=============================================================

Realm Object Server v3.0.0 or newer is required when using synchronized Realms.

### Enhancements

* Added an improved API for adding subscriptions in partially-synchronized Realms. `Results.subscribe()` can be
  used to subscribe to any result set, and the returned `SyncSubscription` object can be used to observe the state
  of the subscription and ultimately to remove the subscription. See the documentation for more information
  (<https://docs.realm.io/platform/v/3.x/using-synced-realms/syncing-data>).
* Added a fine-grained permissions system for use with partially-synchronized Realms. This allows permissions to be
  defined at the level of individual objects or classes. See the documentation for more information
  (<https://docs.realm.io/platform/v/3.x/using-synced-realms/access-control>).
* Added `SyncConfiguration.automatic()` and `SyncConfiguration.automatic(user:)`.
  These methods return a `Realm.Configuration` appropriate for syncing with the default
  synced Realm for the current (or specified) user. These should be considered the preferred methods
  for accessing synced Realms going forwards.
* Added `+[RLMSyncSession sessionForRealm:]` to retrieve the sync session corresponding to a `RLMRealm`.

### Bugfixes

* Fix incorrect initalization of `RLMSyncManager` that made it impossible to
  set `errorHandler`.
* Fix compiler warnings when building with Xcode 9.3.
* Fix some warnings when running with UBsan.

3.2.0-rc.1 Release notes (2018-03-14)
=============================================================

Realm Object Server v3.0.0-rc.1 or newer is required when using synchronized Realms.

### Enhancements

* Added `SyncConfiguration.automatic()` and `SyncConfiguration.automatic(user:)`.
  These methods return a `Realm.Configuration` appropriate for syncing with the default
  synced Realm for the current (or specified). These should be considered the preferred methods
  for accessing synced Realms going forwards.
* A role is now automatically created for each user with that user as its only member.
  This simplifies the common use case of restricting access to specific objects to a single user.
  This role can be accessed at `PermissionUser.role`.
* Improved error reporting when the server rejects a schema change due to a lack of permissions.

### Bugfixes

* Fix incorrect initalization of `RLMSyncManager` that made it impossible to
  set `errorHandler`.
* Fix compiler warnings when building with Xcode 9.3.

3.2.0-beta.3 Release notes (2018-03-01)
=============================================================

Realm Object Server v3.0.0-alpha.9 or newer is required when using synchronized Realms.

### Bugfixes

* Fix a crash that would occur when using partial sync with Realm Object Server v3.0.0-alpha.9.

3.2.0-beta.2 Release notes (2018-02-28)
=============================================================

Realm Object Server v3.0.0-alpha.8 or newer is required when using synchronized Realms.

### Enhancements

* Added `findOrCreate(forRoleNamed:)` and `findOrCreate(forRole:)` to `List<Permission>`
  to simplify the process of adding permissions for a role.
* Added `+permissionForRoleNamed:inArray:`, `+permissionForRoleNamed:onRealm:`,
  `+permissionForRoleNamed:onClass:realm:`, `+permissionForRoleNamed:onClassNamed:realm:`,
  and `+permissionForRoleNamed:onObject:` to `RLMSyncPermission` to simplify the process
  of adding permissions for a role.
* Added `+[RLMSyncSession sessionForRealm:]` to retrieve the sync session corresponding to a `RLMRealm`.

### Bugfixes

* `PermissionRole.users` and `PermissionUser.roles` are now public as intended.
* Fixed the handling of `setPermissions` in `-[RLMRealm privilegesForRealm]` and related methods.

3.2.0-beta.1 Release notes (2018-02-19)
=============================================================

### Enhancements

* Added an improved API for adding subscriptions in partially-synchronized Realms. `Results.subscribe()` can be
  used to subscribe to any result set, and the returned `SyncSubscription` object can be used to observe the state
  of the subscription and ultimately to remove the subscription.
* Added a fine-grained permissions system for use with partially-synchronized Realms. This allows permissions to be
  defined at the level of individual objects or classes. See `Permission` and related types for more information.

### Bugfixes

* Fix some warnings when running with UBsan.

3.1.1 Release notes (2018-02-03)
=============================================================

Prebuilt Swift frameworks for Carthage are now built with Xcode 9.2.

### Bugfixes

* Fix a memory leak when opening Realms with an explicit `objectTypes` array
  from Swift.

3.1.0 Release notes (2018-01-16)
=============================================================

* Prebuilt frameworks are now included for Swift 3.2.3 and 4.0.3.
* Prebuilt frameworks are no longer included for Swift 3.0.x.
* Building from source with Xcode versions prior to Xcode 8.3 is no longer supported.

### Enhancements

* Add `Results.distinct(by:)` / `-[RLMResults distinctResultsUsingKeyPaths:]`, which return a `Results`
  containing only objects with unique values at the given key paths.
* Improve performance of change checking for notifications in certain cases.
* Realm Object Server errors not explicitly recognized by the client are now reported to the application
  regardless.
* Add support for JSON Web Token as a sync credential source.
* Add support for Nickname and Anonymous Auth as a sync credential source.
* Improve allocator performance when writing to a highly fragmented file. This
  should significantly improve performance when inserting large numbers of
  objects which have indexed properties.
* Improve write performance for complex object graphs involving many classes
  linking to each other.

### Bugfixes

* Add a missing check for a run loop in the permission API methods which
  require one.
* Fix some cases where non-fatal sync errors were being treated as fatal errors.

3.0.2 Release notes (2017-11-08)
=============================================================

Prebuilt frameworks are now included for Swift 3.2.2 and 4.0.2.

### Bugfixes

* Fix a crash when a linking objects property is retrieved from a model object instance via
  Swift subscripting.
* Fix incorrect behavior if a call to `posix_fallocate` is interrupted.

3.0.1 Release notes (2017-10-26)
=============================================================

### Bugfixes

* Explicitly exclude KVO-generated object subclasses from the schema.
* Fix regression where the type of a Realm model class is not properly determined, causing crashes
  when a type value derived at runtime by `type(of:)` is passed into certain APIs.
* Fix a crash when an `Object` subclass has implicitly ignored `let`
  properties.
* Fix several cases where adding a notification block from within a
  notification callback could produce incorrect results.

3.0.0 Release notes (2017-10-16)
=============================================================

### Breaking Changes
* iOS 7 is no longer supported.
* Synchronized Realms require a server running Realm Object Server v2.0 or higher.
* Computed properties on Realm object types are detected and no
  longer added to the automatically generated schema.
* The Objective-C and Swift `create(_:, value: update:)` APIs now
  correctly nil out nullable properties when updating an existing
  object when the `value` argument specifies nil or `NSNull` for
  the property value.
* `-[RLMRealm addOrUpdateObjects:]` and `-[RLMRealm deleteObjects:]` now
  require their argument to conform to `NSFastEnumeration`, to match similar
  APIs that also take collections.
* The way interactive sync errors (client reset and permission denied)
  are delivered to the user has been changed. Instead of a block which can
  be invoked to immediately delete the offending Realm file, an opaque
  token object of type `RLMSyncErrorActionToken` will be returned in the
  error object's `userInfo` dictionary. This error object can be passed
  into the new `+[RLMSyncSession immediatelyHandleError:]` API to delete
  the files.
* The return types of the `SyncError.clientResetInfo()` and
  `SyncError.deleteRealmUserInfo()` APIs have been changed. They now return
  `RLMSyncErrorActionToken`s or `SyncError.ActionToken`s instead of closures.
* The class methods `Object.className()`, `Object.objectUtilClass()`, and
  the property `Object.isInvalidated` can no longer be overriden.
* The callback which runs when a sync user login succeeds or fails
  now runs on the main queue by default, or can be explicitly specified
  by a new `callbackQueue` parameter on the `{RLM}SyncUser.logIn(...)` API.
* Fix empty strings, binary data, and null on the right side of `BEGINSWITH`,
  `ENDSWITH` and `CONTAINS` operators in predicates to match Foundation's
  semantics of never matching any strings or data.
* Swift `Object` comparison and hashing behavior now works the same way as
  that of `RLMObject` (objects are now only considered equatable if their
  model class defines a primary key).
* Fix the way the hash property works on `Object` when the object model has
  no primary key.
* Fix an issue where if a Swift model class defined non-generic managed
  properties after generic Realm properties (like `List<T>`), the schema
  would be constructed incorrectly. Fixes an issue where creating such
  models from an array could fail.
* Loosen `RLMArray` and `RLMResults`'s generic constraint from `RLMObject` to
  `NSObject`. This may result in having to add some casts to disambiguate
  types.
* Remove `RLMSyncPermissionResults`. `RLMSyncPermission`s are now vended out
  using a `RLMResults`. This results collection supports all normal collection
  operations except for setting values using key-value coding (since
  `RLMSyncPermission`s are immutable) and the property aggregation operations.
* `RLMSyncUserInfo` has been significantly enhanced. It now contains metadata
  about a user stored on the Realm Object Server, as well as a list of all user account
  data associated with that user.
* Starting with Swift 4, `List` now conforms to `MutableCollection` instead of
  `RangeReplaceableCollection`. For Swift 4, the empty collection initializer has been
  removed, and default implementations of range replaceable collection methods that
  make sense for `List` have been added.
* `List.removeLast()` now throws an exception if the list is empty, to more closely match
  the behavior of the standard library's `Collection.removeLast()` implementation.
* `RealmCollection`'s associated type `Element` has been renamed `ElementType`.
* The following APIs have been renamed:

| Old API                                                     | New API                                                        |
|:------------------------------------------------------------|:---------------------------------------------------------------|
| `NotificationToken.stop()`                                  | `NotificationToken.invalidate()`                               |
| `-[RLMNotificationToken stop]`                              | `-[RLMNotificationToken invalidate]`                           |
| `RealmCollection.addNotificationBlock(_:)`                  | `RealmCollection.observe(_:)`                                  |
| `RLMSyncProgress`                                           | `RLMSyncProgressMode`                                          |
| `List.remove(objectAtIndex:)`                               | `List.remove(at:)`                                             |
| `List.swap(_:_:)`                                           | `List.swapAt(_:_:)`                                            |
| `SyncPermissionValue`                                       | `SyncPermission`                                               |
| `RLMSyncPermissionValue`                                    | `RLMSyncPermission`                                            |
| `-[RLMSyncPermission initWithRealmPath:userID:accessLevel]` | `-[RLMSyncPermission initWithRealmPath:identity:accessLevel:]` |
| `RLMSyncPermission.userId`                                  | `RLMSyncPermission.identity`                                   |
| `-[RLMRealm addOrUpdateObjectsInArray:]`                    | `-[RLMRealm addOrUpdateObjects:]`                              |

* The following APIs have been removed:

| Removed API                                                  | Replacement                                                                               |
|:-------------------------------------------------------------|:------------------------------------------------------------------------------------------|
| `Object.className`                                           | None, was erroneously present.                                                            |
| `RLMPropertyTypeArray`                                       | `RLMProperty.array`                                                                       |
| `PropertyType.array`                                         | `Property.array`                                                                          |
| `-[RLMArray sortedResultsUsingProperty:ascending:]`          | `-[RLMArray sortedResultsUsingKeyPath:ascending:]`                                        |
| `-[RLMCollection sortedResultsUsingProperty:ascending:]`     | `-[RLMCollection sortedResultsUsingKeyPath:ascending:]`                                   |
| `-[RLMResults sortedResultsUsingProperty:ascending:]`        | `-[RLMResults sortedResultsUsingKeyPath:ascending:]`                                      |
| `+[RLMSortDescriptor sortDescriptorWithProperty:ascending:]` | `+[RLMSortDescriptor sortDescriptorWithKeyPath:ascending:]`                               |
| `RLMSortDescriptor.property`                                 | `RLMSortDescriptor.keyPath`                                                               |
| `AnyRealmCollection.sorted(byProperty:ascending:)`           | `AnyRealmCollection.sorted(byKeyPath:ascending:)`                                         |
| `List.sorted(byProperty:ascending:)`                         | `List.sorted(byKeyPath:ascending:)`                                                       |
| `LinkingObjects.sorted(byProperty:ascending:)`               | `LinkingObjects.sorted(byKeyPath:ascending:)`                                             |
| `Results.sorted(byProperty:ascending:)`                      | `Results.sorted(byKeyPath:ascending:)`                                                    |
| `SortDescriptor.init(property:ascending:)`                   | `SortDescriptor.init(keyPath:ascending:)`                                                 |
| `SortDescriptor.property`                                    | `SortDescriptor.keyPath`                                                                  |
| `+[RLMRealm migrateRealm:configuration:]`                    | `+[RLMRealm performMigrationForConfiguration:error:]`                                     |
| `RLMSyncManager.disableSSLValidation`                        | `RLMSyncConfiguration.enableSSLValidation`                                                |
| `SyncManager.disableSSLValidation`                           | `SyncConfiguration.enableSSLValidation`                                                   |
| `RLMSyncErrorBadResponse`                                    | `RLMSyncAuthErrorBadResponse`                                                             |
| `RLMSyncPermissionResults`                                   | `RLMResults`                                                                              |
| `SyncPermissionResults`                                      | `Results`                                                                                 |
| `RLMSyncPermissionChange`                                    | `-[RLMSyncUser applyPermission:callback]` / `-[RLMSyncUser deletePermission:callback:]`   |
| `-[RLMSyncUser permissionRealmWithError:]`                   | `-[RLMSyncUser retrievePermissionsWithCallback:]`                                         |
| `RLMSyncPermissionOffer`                                     | `-[RLMSyncUser createOfferForRealmAtURL:accessLevel:expiration:callback:]`                |
| `RLMSyncPermissionOfferResponse`                             | `-[RLMSyncUser acceptOfferForToken:callback:]`                                            |
| `-[NSError rlmSync_clientResetBlock]`                        | `-[NSError rlmSync_errorActionToken]` / `-[NSError rlmSync_clientResetBackedUpRealmPath]` |
| `-[NSError rlmSync_deleteRealmBlock]`                        | `-[NSError rlmSync_errorActionToken]`                                                     |

### Enhancements
* `List` can now contain values of types `Bool`, `Int`, `Int8`, `Int16`,
  `Int32`, `Int64`, `Float`, `Double`, `String`, `Data`, and `Date` (and
  optional versions of all of these) in addition to `Object` subclasses.
  Querying `List`s containing values other than `Object` subclasses is not yet
  implemented.
* `RLMArray` can now be constrained with the protocols `RLMBool`, `RLMInt`,
  `RLMFloat`, `RLMDouble`, `RLMString`, `RLMData`, and `RLMDate` in addition to
  protocols defined with `RLM_ARRAY_TYPE`. By default `RLMArray`s of
  non-`RLMObject` types can contain null. Indicating that the property is
  required (by overriding `+requiredProperties:`) will instead make the values
  within the array required. Querying `RLMArray`s containing values other than
  `RLMObject` subclasses is not yet implemented.
* Add a new error code to denote 'permission denied' errors when working
  with synchronized Realms, as well as an accompanying block that can be
  called to inform the binding that the offending Realm's files should be
  deleted immediately. This allows recovering from 'permission denied'
  errors in a more robust manner. See the documentation for
  `RLMSyncErrorPermissionDeniedError` for more information.
* Add Swift `Object.isSameObject(as:_)` API to perform the same function as
  the existing Objective-C API `-[RLMObject isEqualToObject:]`.
* Opening a synced Realm whose local copy was created with an older version of
  Realm Mobile Platfrom when a migration is not possible to the current version
  will result in an `RLMErrorIncompatibleSyncedFile` / `incompatibleSyncedFile`
  error. When such an error occurs, the original file is moved to a backup
  location, and future attempts to open the synchronized Realm will result in a new
  file being created. If you wish to migrate any data from the backup Realm you can
  open it using the backup Realm configuration available on the error object.
* Add a preview of partial synchronization. Partial synchronization allows a
  synchronized Realm to be opened in such a way that only objects requested by
  the user are synchronized to the device. You can use it by setting the
  `isPartial` property on a `SyncConfiguration`, opening the Realm, and then
  calling `Realm.subscribe(to:where:callback:)` with the type of object you're
  interested in, a string containing a query determining which objects you want
  to subscribe to, and a callback which will report the results. You may add as
  many subscriptions to a synced Realm as necessary.

### Bugfixes
* Realm no longer throws an "unsupported instruction" exception in some cases
  when opening a synced Realm asynchronously.
* Realm Swift APIs that filter or look up the index of an object based on a
  format string now properly handle optional arguments in their variadic argument
  list.
* `-[RLMResults<RLMSyncPermission *> indexOfObject:]` now properly accounts for access
  level.
* Fix a race condition that could lead to a crash accessing to the freed configuration object
  if a default configuration was set from a different thread.
* Fixed an issue that crash when enumerating after clearing data during migration.
* Fix a bug where a synced Realm couldn't be reopened even after a successful client reset
  in some cases.
* Fix a bug where the sync subsystem waited too long in certain cases to reconnect to the server.
* Fix a bug where encrypted sync-related metadata was incorrectly deleted from upgrading users,
  resulting in all users being logged out.
* Fix a bug where permission-related data continued to be synced to a client even after the user
  that data belonged to logged out.
* Fix an issue where collection notifications might be delivered inconsistently if a notification
  callback was added within another callback for the same collection.

3.0.0-rc.2 Release notes (2017-10-14)
=============================================================

### Enhancements
* Reinstate `RLMSyncPermissionSortPropertyUserID` to allow users to sort permissions
  to their own Realms they've granted to others.

### Bugfixes
* `-[RLMResults<RLMSyncPermission *> indexOfObject:]` now properly accounts for access
  level.
* Fix a race condition that could lead to a crash accessing to the freed configuration object
  if a default configuration was set from a different thread.
* Fixed an issue that crash when enumerating after clearing data during migration.
* Fix a bug where a synced Realm couldn't be reopened even after a successful client reset
  in some cases.
* Fix a bug where the sync subsystem waited too long in certain cases to reconnect to the server.
* Fix a bug where encrypted sync-related metadata was incorrectly deleted from upgrading users,
  resulting in all users being logged out.
* Fix a bug where permission-related data continued to be synced to a client even after the user
  that data belonged to logged out.
* Fix an issue where collection notifications might be delivered inconsistently if a notification
  callback was added within another callback for the same collection.

3.0.0-rc.1 Release notes (2017-10-03)
=============================================================

### Breaking Changes
* Remove `RLMSyncPermissionSortPropertyUserID` to reflect changes in how the
  Realm Object Server reports permissions for a user.
* Remove `RLMSyncPermissionOffer` and `RLMSyncPermissionOfferResponse` classes
  and associated helper methods and functions. Use the
  `-[RLMSyncUser createOfferForRealmAtURL:accessLevel:expiration:callback:]`
  and `-[RLMSyncUser acceptOfferForToken:callback:]` methods instead.

### Bugfixes

* The keychain item name used by Realm to manage the encryption keys for
  sync-related metadata is now set to a per-app name based on the bundle
  identifier. Keys that were previously stored within the single, shared Realm
  keychain item will be transparently migrated to the per-application keychain
  item.
* Fix downloading of the Realm core binaries when Xcode's command-line tools are
  set as the active developer directory for command-line interactions.
* Fix a crash that could occur when resolving a ThreadSafeReference to a `List`
  whose parent object had since been deleted.

3.0.0-beta.4 Release notes (2017-09-22)
=============================================================

### Breaking Changes

* Rename `List.remove(objectAtIndex:)` to `List.remove(at:)` to match the name
  used by 'RangeReplaceableCollection'.
* Rename `List.swap()` to `List.swapAt()` to match the name used by 'Array'.
* Loosen `RLMArray` and `RLMResults`'s generic constraint from `RLMObject` to
  `NSObject`. This may result in having to add some casts to disambiguate
  types.
* Remove `RLMPropertyTypeArray` in favor of a separate bool `array` property on
  `RLMProperty`/`Property`.
* Remove `RLMSyncPermissionResults`. `RLMSyncPermission`s are now vended out
  using a `RLMResults`. This results collection supports all normal collection
  operations except for setting values using KVO (since `RLMSyncPermission`s are
  immutable) and the property aggregation operations.
* `RealmCollection`'s associated type `Element` has been renamed `ElementType`.
* Realm Swift collection types (`List`, `Results`, `AnyRealmCollection`, and
  `LinkingObjects` have had their generic type parameter changed from `T` to
  `Element`).
* `RealmOptional`'s generic type parameter has been changed from `T` to `Value`.
* `RLMSyncUserInfo` has been significantly enhanced. It now contains metadata
  about a user stored on the Realm Object Server, as well as a list of all user account
  data associated with that user.
* Starting with Swift 4, `List` now conforms to `MutableCollection` instead of
  `RangeReplaceableCollection`. For Swift 4, the empty collection initializer has been
  removed, and default implementations of range replaceable collection methods that
  make sense for `List` have been added.
* `List.removeLast()` now throws an exception if the list is empty, to more closely match
  the behavior of the standard library's `Collection.removeLast()` implementation.

### Enhancements

* `List` can now contain values of types `Bool`, `Int`, `Int8`, `Int16`,
  `Int32`, `Int64`, `Float`, `Double`, `String`, `Data`, and `Date` (and
  optional versions of all of these) in addition to `Object` subclasses.
  Querying `List`s containing values other than `Object` subclasses is not yet
  implemented.
* `RLMArray` can now be constrained with the protocols `RLMBool`, `RLMInt`,
  `RLMFloat`, `RLMDouble`, `RLMString`, `RLMData`, and `RLMDate` in addition to
  protocols defined with `RLM_ARRAY_TYPE`. By default `RLMArray`s of
  non-`RLMObject` types can contain null. Indicating that the property is
  required (by overriding `+requiredProperties:`) will instead make the values
  within the array required. Querying `RLMArray`s containing values other than
  `RLMObject` subclasses is not yet implemented.
* Opening a synced Realm whose local copy was created with an older version of
  Realm Mobile Platfrom when a migration is not possible to the current version
  will result in an `RLMErrorIncompatibleSyncedFile` / `incompatibleSyncedFile`
  error. When such an error occurs, the original file is moved to a backup
  location, and future attempts to open the synchronized Realm will result in a new
  file being created. If you wish to migrate any data from the backup Realm you can
  open it using the backup Realm configuration available on the error object.
* Add preview support for partial synchronization. Partial synchronization is
  allows a synchronized Realm to be opened in such a way that only objects
  requested by the user are synchronized to the device. You can use it by setting
  the `isPartial` property on a `SyncConfiguration`, opening the Realm, and then
  calling `Realm.subscribe(to:where:callback:)` with the type of object you're
  interested in, a string containing a query determining which objects you want
  to subscribe to, and a callback which will report the results. You may add as
  many subscriptions to a synced Realm as necessary.

### Bugfixes

* Realm Swift APIs that filter or look up the index of an object based on a
  format string now properly handle optional arguments in their variadic argument
  list.

3.0.0-beta.3 Release notes (2017-08-23)
=============================================================

### Breaking Changes

* iOS 7 is no longer supported.
* Computed properties on Realm object types are detected and no
  longer added to the automatically generated schema.
* `-[RLMRealm addOrUpdateObjectsInArray:]` has been renamed to
  `-[RLMRealm addOrUpdateObjects:]` for consistency with similar methods
  that add or delete objects.
* `-[RLMRealm addOrUpdateObjects:]` and `-[RLMRealm deleteObjects:]` now
  require their argument to conform to `NSFastEnumeration`, to match similar
  APIs that also take collections.
* Remove deprecated `{RLM}SyncPermission` and `{RLM}SyncPermissionChange`
  classes.
* `{RLM}SyncPermissionValue` has been renamed to just `{RLM}SyncPermission`.
  Its `userId` property has been renamed `identity`, and its
  `-initWithRealmPath:userID:accessLevel:` initializer has been renamed
  `-initWithRealmPath:identity:accessLevel:`.
* Remove deprecated `-[RLMSyncUser permissionRealmWithError:]` and
  `SyncUser.permissionRealm()` APIs. Use the new permissions system.
* Remove deprecated error `RLMSyncErrorBadResponse`. Use
  `RLMSyncAuthErrorBadResponse` instead.
* The way interactive sync errors (client reset and permission denied)
  are delivered to the user has been changed. Instead of a block which can
  be invoked to immediately delete the offending Realm file, an opaque
  token object of type `RLMSyncErrorActionToken` will be returned in the
  error object's `userInfo` dictionary. This error object can be passed
  into the new `+[RLMSyncSession immediatelyHandleError:]` API to delete
  the files.
* Remove `-[NSError rlmSync_clientResetBlock]` and
  `-[NSError rlmSync_deleteRealmBlock]` APIs.
* The return types of the `SyncError.clientResetInfo()` and
  `SyncError.deleteRealmUserInfo()` APIs have been changed. They now return
  `RLMSyncErrorActionToken`s or `SyncError.ActionToken`s instead of closures.
* The (erroneously added) instance property `Object.className` has been
  removed.
* The class methods `Object.className()`, `Object.objectUtilClass()`, and
  the property `Object.isInvalidated` can no longer be overriden.
* The callback which runs when a sync user login succeeds or fails
  now runs on the main queue by default, or can be explicitly specified
  by a new `callbackQueue` parameter on the `{RLM}SyncUser.logIn(...)` API.
* Rename `{RLM}NotificationToken.stop()` to `invalidate()` and
  `{RealmCollection,SyncPermissionResults}.addNotificationBlock(_:)` to
  `observe(_:)` to mirror Foundation's new KVO APIs.
* The `RLMSyncProgress` enum has been renamed `RLMSyncProgressMode`.
* Remove deprecated `{RLM}SyncManager.disableSSLValidation` property. Disable
  SSL validation on a per-Realm basis by setting the `enableSSLValidation`
  property on `{RLM}SyncConfiguration` instead.
* Fix empty strings, binary data, and null on the right side of `BEGINSWITH`,
  `ENDSWITH` and `CONTAINS` operators in predicates to match Foundation's
  semantics of never matching any strings or data.
* Swift `Object` comparison and hashing behavior now works the same way as
  that of `RLMObject` (objects are now only considered equatable if their
  model class defines a primary key).
* Fix the way the hash property works on `Object` when the object model has
  no primary key.
* Fix an issue where if a Swift model class defined non-generic managed
  properties after generic Realm properties (like `List<T>`), the schema
  would be constructed incorrectly. Fixes an issue where creating such
  models from an array could fail.

### Enhancements

* Add Swift `Object.isSameObject(as:_)` API to perform the same function as
  the existing Objective-C API `-[RLMObject isEqualToObject:]`.
* Expose additional authentication-related errors that might be reported by
  a Realm Object Server.
* An error handler can now be registered on `{RLM}SyncUser`s in order to
  report authentication-related errors that affect the user.

### Bugfixes

* Sync users are now automatically logged out upon receiving certain types
  of errors that indicate they are no longer logged into the server. For
  example, users who are authenticated using third-party credentials will find
  themselves logged out of the Realm Object Server if the third-party identity
  service indicates that their credential is no longer valid.
* Address high CPU usage and hangs in certain cases when processing collection
  notifications in highly-connected object graphs.

3.0.0-beta.2 Release notes (2017-07-26)
=============================================================

### Breaking Changes

* Remove the following deprecated Objective-C APIs:
  `-[RLMArray sortedResultsUsingProperty:ascending:]`,
  `-[RLMCollection sortedResultsUsingProperty:ascending:]`,
  `-[RLMResults sortedResultsUsingProperty:ascending:]`,
  `+[RLMSortDescriptor sortDescriptorWithProperty:ascending:]`,
  `RLMSortDescriptor.property`.
  These APIs have been superseded by equivalent APIs that take
  or return key paths instead of property names.
* Remove the following deprecated Objective-C API:
  `+[RLMRealm migrateRealm:configuration:]`.
  Please use `+[RLMRealm performMigrationForConfiguration:error:]` instead.
* Remove the following deprecated Swift APIs:
  `AnyRealmCollection.sorted(byProperty:, ascending:)`,
  `LinkingObjects.sorted(byProperty:, ascending:)`,
  `List.sorted(byProperty:, ascending:)`,
  `Results.sorted(byProperty:, ascending:)`,
  `SortDescriptor.init(property:, ascending:)`,
  `SortDescriptor.property`.
  These APIs have been superseded by equivalent APIs that take
  or return key paths instead of property names.
* The Objective-C and Swift `create(_:, value: update:)` APIs now
  correctly nil out nullable properties when updating an existing
  object when the `value` argument specifies nil or `NSNull` for
  the property value.

### Enhancements

* It is now possible to create and log in multiple Realm Object Server users
  with the same identity if they originate from different servers. Note that
  if the URLs are different aliases for the same authentication server each
  user will still be treated as separate (e.g. they will have their own copy
  of each synchronized Realm opened using them). It is highly encouraged that
  users defined using the access token credential type be logged in with an
  authentication server URL specified; this parameter will become mandatory
  in a future version of the SDK.
* Add `-[RLMSyncUser retrieveInfoForUser:identityProvider:completion:]`
  API allowing administrator users to retrieve information about a user based
  on their provider identity (for example, a username). Requires any edition
  of the Realm Object Server 1.8.2 or later.

### Bugfixes

* Realm no longer throws an "unsupported instruction" exception in some cases
  when opening a synced Realm asynchronously.

3.0.0-beta Release notes (2017-07-14)
=============================================================

### Breaking Changes

* Synchronized Realms require a server running Realm Object Server v2.0 or higher.

### Enhancements

* Add a new error code to denote 'permission denied' errors when working
  with synchronized Realms, as well as an accompanying block that can be
  called to inform the binding that the offending Realm's files should be
  deleted immediately. This allows recovering from 'permission denied'
  errors in a more robust manner. See the documentation for
  `RLMSyncErrorPermissionDeniedError` for more information.
* Add `-[RLMSyncPermissionValue initWithRealmPath:username:accessLevel:]`
  API allowing permissions to be applied to a user based on their username
  (usually, an email address). Requires any edition of the Realm Object
  Server 1.6.0 or later.
* Improve performance of creating Swift objects which contain at least one List
  property.

### Bugfixes

* `List.description` now reports the correct types for nested lists.
* Fix unmanaged object initialization when a nested property type returned
  `false` from `Object.shouldIncludeInDefaultSchema()`.
* Don't clear RLMArrays on self-assignment.

2.10.2 Release notes (2017-09-27)
=============================================================

### Bugfixes

* The keychain item name used by Realm to manage the encryption keys for
  sync-related metadata is now set to a per-app name based on the bundle
  identifier. Keys that were previously stored within the single, shared Realm
  keychain item will be transparently migrated to the per-application keychain
  item.
* Fix downloading of the Realm core binaries when Xcode's command-line tools are
  set as the active developer directory for command-line interactions.
* Fix a crash that could occur when resolving a ThreadSafeReference to a `List`
  whose parent object had since been deleted.

2.10.1 Release notes (2017-09-14)
=============================================================

Swift binaries are now produced for Swift 3.0, 3.0.1, 3.0.2, 3.1, 3.2 and 4.0.

### Enhancements

* Auxiliary files are excluded from backup by default.

### Bugfixes

* Fix more cases where assigning an RLMArray property to itself would clear the
  RLMArray.

2.10.0 Release notes (2017-08-21)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Expose additional authentication-related errors that might be reported by
  a Realm Object Server.
* An error handler can now be registered on `{RLM}SyncUser`s in order to
  report authentication-related errors that affect the user.

### Bugfixes

* Sorting Realm collection types no longer throws an exception on iOS 7.
* Sync users are now automatically logged out upon receiving certain types
  of errors that indicate they are no longer logged into the server. For
  example, users who are authenticated using third-party credentials will find
  themselves logged out of the Realm Object Server if the third-party identity
  service indicates that their credential is no longer valid.
* Address high CPU usage and hangs in certain cases when processing collection
  notifications in highly-connected object graphs.

2.9.1 Release notes (2017-08-01)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* None.

### Bugfixes

* The `shouldCompactOnLaunch` block is no longer invoked if the Realm at that
  path is already open on other threads.
* Fix an assertion failure in collection notifications when changes are made to
  the schema via sync while the notification block is active.

2.9.0 Release notes (2017-07-26)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Add a new error code to denote 'permission denied' errors when working
  with synchronized Realms, as well as an accompanying block that can be
  called to inform the binding that the offending Realm's files should be
  deleted immediately. This allows recovering from 'permission denied'
  errors in a more robust manner. See the documentation for
  `RLMSyncErrorPermissionDeniedError` for more information.
* Add `-[RLMSyncPermissionValue initWithRealmPath:username:accessLevel:]`
  API allowing permissions to be applied to a user based on their username
  (usually, an email address). Requires any edition of the Realm Object
  Server 1.6.0 or later.
* Improve performance of creating Swift objects which contain at least one List
  property.
* It is now possible to create and log in multiple Realm Object Server users
  with the same identity if they originate from different servers. Note that
  if the URLs are different aliases for the same authentication server each
  user will still be treated as separate (e.g. they will have their own copy
  of each synchronized Realm opened using them). It is highly encouraged that
  users defined using the access token credential type be logged in with an
  authentication server URL specified; this parameter will become mandatory
  in a future version of the SDK.
* Add `-[RLMSyncUser retrieveInfoForUser:identityProvider:completion:]`
  API allowing administrator users to retrieve information about a user based
  on their provider identity (for example, a username). Requires any edition
  of the Realm Object Server 1.8.2 or later.

### Bugfixes

* `List.description` now reports the correct types for nested lists.
* Fix unmanaged object initialization when a nested property type returned
  `false` from `Object.shouldIncludeInDefaultSchema()`.
* Don't clear RLMArrays on self-assignment.

2.8.3 Release notes (2017-06-20)
=============================================================

### Bugfixes

* Properly update RealmOptional properties when adding an object with `add(update: true)`.
* Add some missing quotes in error messages.
* Fix a performance regression when creating objects with primary keys.

2.8.2 Release notes (2017-06-16)
=============================================================

### Bugfixes

* Fix an issue where synchronized Realms would eventually disconnect from the
  remote server if the user object used to define their sync configuration
  was destroyed.
* Restore support for changing primary keys in migrations (broken in 2.8.0).
* Revert handling of adding objects with nil properties to a Realm to the
  pre-2.8.0 behavior.

2.8.1 Release notes (2017-06-12)
=============================================================

Add support for building with Xcode 9 Beta 1.

### Bugfixes

* Fix setting a float property to NaN.
* Fix a crash when using compact on launch in combination with collection
  notifications.

2.8.0 Release notes (2017-06-02)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Enable encryption on watchOS.
* Add `-[RLMSyncUser changePassword:forUserID:completion:]` API to change an
  arbitrary user's password if the current user has administrative privileges
  and using Realm's 'password' authentication provider.
  Requires any edition of the Realm Object Server 1.6.0 or later.

### Bugfixes

* Suppress `-Wdocumentation` warnings in Realm C++ headers when using CocoaPods
  with Xcode 8.3.2.
* Throw an appropriate error rather than crashing when an RLMArray is assigned
  to an RLMArray property of a different type.
* Fix crash in large (>4GB) encrypted Realm files.
* Improve accuracy of sync progress notifications.
* Fix an issue where synchronized Realms did not connect to the remote server
  in certain situations, such as when an application was offline when the Realms
  were opened but later regained network connectivity.

2.7.0 Release notes (2017-05-03)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Use reachability API to minimize the reconnection delay if the network
  connection was lost.
* Add `-[RLMSyncUser changePassword:completion:]` API to change the current
  user's password if using Realm's 'password' authentication provider.
  Requires any edition of the Realm Object Server 1.4.0 or later.
* `{RLM}SyncConfiguration` now has an `enableSSLValidation` property
  (and default parameter in the Swift initializer) to allow SSL validation
  to be specified on a per-server basis.
* Transactions between a synced Realm and a Realm Object Server can now
  exceed 16 MB in size.
* Add new APIs for changing and retrieving permissions for synchronized Realms.
  These APIs are intended to replace the existing Realm Object-based permissions
  system. Requires any edition of the Realm Object Server 1.1.0 or later.

### Bugfixes

* Support Realm model classes defined in Swift with overridden Objective-C
  names (e.g. `@objc(Foo) class SwiftFoo: Object {}`).
* Fix `-[RLMMigration enumerateObjects:block:]` returning incorrect `oldObject`
  objects when enumerating a class name after previously deleting a `newObject`.
* Fix an issue where `Realm.asyncOpen(...)` would fail to work when opening a
  synchronized Realm for which the user only had read permissions.
* Using KVC to set a `List` property to `nil` now clears it to match the
  behavior of `RLMArray` properties.
* Fix crash from `!m_awaiting_pong` assertion failure when using synced Realms.
* Fix poor performance or hangs when performing case-insensitive queries on
  indexed string properties that contain many characters that don't differ
  between upper and lower case (e.g., numbers, punctuation).

2.6.2 Release notes (2017-04-21)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix an issue where calling `Realm.asyncOpen(...)` with a synchronized Realm
  configuration would fail with an "Operation canceled" error.
* Fix initial collection notification sometimes not being delivered for synced
  Realms.
* Fix circular links sometimes resulting in objects not being marked as
  modified in change notifications.

2.6.1 Release notes (2017-04-18)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix an issue where calling `Realm.asyncOpen(...)` with a synchronized Realm
  configuration would crash in error cases rather than report the error.
  This is a small source breaking change if you were relying on the error
  being reported to be a `Realm.Error`.

2.6.0 Release notes (2017-04-18)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Add a `{RLM}SyncUser.isAdmin` property indicating whether a user is a Realm
  Object Server administrator.
* Add an API to asynchronously open a Realm and deliver it to a block on a
  given queue. This performs all work needed to get the Realm to
  a usable state (such as running potentially time-consuming migrations) on a
  background thread before dispatching to the given queue. In addition,
  synchronized Realms wait for all remote content available at the time the
  operation began to be downloaded and available locally.
* Add `shouldCompactOnLaunch` block property when configuring a Realm to
  determine if it should be compacted before being returned.
* Speed up case-insensitive queries on indexed string properties.
* Add RLMResults's collection aggregate methods to RLMArray.
* Add support for calling the aggregate methods on unmanaged Lists.

### Bugfixes

* Fix a deadlock when multiple processes open a Realm at the same time.
* Fix `value(forKey:)`/`value(forKeyPath:)` returning incorrect values for `List` properties.

2.5.1 Release notes (2017-04-05)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix CocoaPods installation with static libraries and multiple platforms.
* Fix uncaught "Bad version number" exceptions on the notification worker thread
  followed by deadlocks when Realms refresh.

2.5.0 Release notes (2017-03-28)
=============================================================

Files written by Realm this version cannot be read by earlier versions of Realm.
Old files can still be opened and files open in read-only mode will not be
modified.

If using synchronized Realms, the Realm Object Server must be running version
1.3.0 or later.

Swift binaries are now produced for Swift 3.0, 3.0.1, 3.0.2 and 3.1.

### API Breaking Changes

* None.

### Enhancements

* Add support for multi-level object equality comparisons against `NULL`.
* Add support for the `[d]` modifier on string comparison operators to perform
  diacritic-insensitive comparisons.
* Explicitly mark `[[RLMRealm alloc] init]` as unavailable.
* Include the name of the problematic class in the error message when an
  invalid property type is marked as the primary key.

### Bugfixes

* Fix incorrect column type assertions which could occur after schemas were
  merged by sync.
* Eliminate an empty write transaction when opening a synced Realm.
* Support encrypting synchronized Realms by respecting the `encryptionKey` value
  of the Realm's configuration.
* Fix crash when setting an `{NS}Data` property close to 16MB.
* Fix for reading `{NS}Data` properties incorrectly returning `nil`.
* Reduce file size growth in cases where Realm versions were pinned while
  starting write transactions.
* Fix an assertion failure when writing to large `RLMArray`/`List` properties.
* Fix uncaught `BadTransactLog` exceptions when pulling invalid changesets from
  synchronized Realms.
* Fix an assertion failure when an observed `RLMArray`/`List` is deleted after
  being modified.

2.4.4 Release notes (2017-03-13)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Add `(RLM)SyncPermission` class to allow reviewing access permissions for
  Realms. Requires any edition of the Realm Object Server 1.1.0 or later.
* Further reduce the number of files opened per thread-specific Realm on macOS,
  iOS and watchOS.

### Bugfixes

* Fix a crash that could occur if new Realm instances were created while the
  application was exiting.
* Fix a bug that could lead to bad version number errors when delivering
  change notifications.
* Fix a potential use-after-free bug when checking validity of results.
* Fix an issue where a sync session might not close properly if it receives
  an error while being torn down.
* Fix some issues where a sync session might not reconnect to the server properly
  or get into an inconsistent state if revived after invalidation.
* Fix an issue where notifications might not fire when the children of an
  observed object are changed.
* Fix an issue where progress notifications on sync sessions might incorrectly
  report out-of-date values.
* Fix an issue where multiple threads accessing encrypted data could result in
  corrupted data or crashes.
* Fix an issue where certain `LIKE` queries could hang.
* Fix an issue where `-[RLMRealm writeCopyToURL:encryptionKey:error]` could create
  a corrupt Realm file.
* Fix an issue where incrementing a synced Realm's schema version without actually
  changing the schema could cause a crash.

2.4.3 Release notes (2017-02-20)
=============================================================

### API Breaking Changes

* None.

### Enhancements

* Avoid copying copy-on-write data structures, which can grow the file, when the
  write does not actually change existing values.
* Improve performance of deleting all objects in an RLMResults.
* Reduce the number of files opened per thread-specific Realm on macOS.
* Improve startup performance with large numbers of `RLMObject`/`Object`
  subclasses.

### Bugfixes

* Fix synchronized Realms not downloading remote changes when an access token
  expires and there are no local changes to upload.
* Fix an issue where values set on a Realm object using `setValue(value:, forKey:)`
  that were not themselves Realm objects were not properly converted into Realm
  objects or checked for validity.
* Fix an issue where `-[RLMSyncUser sessionForURL:]` could erroneously return a
  non-nil value when passed in an invalid URL.
* `SyncSession.Progress.fractionTransferred` now returns 1 if there are no
  transferrable bytes.
* Fix sync progress notifications registered on background threads by always
  dispatching on a dedicated background queue.
* Fix compilation issues with Xcode 8.3 beta 2.
* Fix incorrect sync progress notification values for Realms originally created
  using a version of Realm prior to 2.3.0.
* Fix LLDB integration to be able to display summaries of `RLMResults` once more.
* Reject Swift properties with names which cause them to fall in to ARC method
  families rather than crashing when they are accessed.
* Fix sorting by key path when the declared property order doesn't match the order
  of properties in the Realm file, which can happen when properties are added in
  different schema versions.

2.4.2 Release notes (2017-01-30)
=============================================================

### Bugfixes

* Fix an issue where RLMRealm instances could end up in the autorelease pool
  for other threads.

2.4.1 Release notes (2017-01-27)
=============================================================

### Bugfixes

* Fix an issue where authentication tokens were not properly refreshed
  automatically before expiring.

2.4.0 Release notes (2017-01-26)
=============================================================

This release drops support for compiling with Swift 2.x.
Swift 3.0.0 is now the minimum Swift version supported.

### API Breaking Changes

* None.

### Enhancements

* Add change notifications for individual objects with an API similar to that
  of collection notifications.

### Bugfixes

* Fix Realm Objective-C compilation errors with Xcode 8.3 beta 1.
* Fix several error handling issues when renewing expired authentication
  tokens for synchronized Realms.
* Fix a race condition leading to bad_version exceptions being thrown in
  Realm's background worker thread.

2.3.0 Release notes (2017-01-19)
=============================================================

### Sync Breaking Changes

* Make `PermissionChange`'s `id` property a primary key.

### API Breaking Changes

* None.

### Enhancements

* Add `SyncPermissionOffer` and `SyncPermissionOfferResponse` classes to allow
  creating and accepting permission change events to synchronized Realms between
  different users.
* Support monitoring sync transfer progress by registering notification blocks
  on `SyncSession`. Specify the transfer direction (`.upload`/`.download`) and
  mode (`.reportIndefinitely`/`.forCurrentlyOutstandingWork`) to monitor.

### Bugfixes

* Fix a call to `commitWrite(withoutNotifying:)` committing a transaction that
  would not have triggered a notification incorrectly skipping the next
  notification.
* Fix incorrect results and crashes when conflicting object insertions are
  merged by the synchronization mechanism when there is a collection
  notification registered for that object type.

2.2.0 Release notes (2017-01-12)
=============================================================

### Sync Breaking Changes (In Beta)

* Sync-related error reporting behavior has been changed. Errors not related
  to a particular user or session are only reported if they are classed as
  'fatal' by the underlying sync engine.
* Added `RLMSyncErrorClientResetError` to `RLMSyncError` enum.

### API Breaking Changes

* The following Objective-C APIs have been deprecated in favor of newer or preferred versions:

| Deprecated API                                              | New API                                                     |
|:------------------------------------------------------------|:------------------------------------------------------------|
| `-[RLMArray sortedResultsUsingProperty:]`                   | `-[RLMArray sortedResultsUsingKeyPath:]`                    |
| `-[RLMCollection sortedResultsUsingProperty:]`              | `-[RLMCollection sortedResultsUsingKeyPath:]`               |
| `-[RLMResults sortedResultsUsingProperty:]`                 | `-[RLMResults sortedResultsUsingKeyPath:]`                  |
| `+[RLMSortDescriptor sortDescriptorWithProperty:ascending]` | `+[RLMSortDescriptor sortDescriptorWithKeyPath:ascending:]` |
| `RLMSortDescriptor.property`                                | `RLMSortDescriptor.keyPath`                                 |

* The following Swift APIs have been deprecated in favor of newer or preferred versions:

| Deprecated API                                        | New API                                          |
|:------------------------------------------------------|:-------------------------------------------------|
| `LinkingObjects.sorted(byProperty:ascending:)`        | `LinkingObjects.sorted(byKeyPath:ascending:)`    |
| `List.sorted(byProperty:ascending:)`                  | `List.sorted(byKeyPath:ascending:)`              |
| `RealmCollection.sorted(byProperty:ascending:)`       | `RealmCollection.sorted(byKeyPath:ascending:)`   |
| `Results.sorted(byProperty:ascending:)`               | `Results.sorted(byKeyPath:ascending:)`           |
| `SortDescriptor(property:ascending:)`                 | `SortDescriptor(keyPath:ascending:)`             |
| `SortDescriptor.property`                             | `SortDescriptor.keyPath`                         |

### Enhancements

* Introduce APIs for safely passing objects between threads. Create a
  thread-safe reference to a thread-confined object by passing it to the
  `+[RLMThreadSafeReference referenceWithThreadConfined:]`/`ThreadSafeReference(to:)`
  constructor, which you can then safely pass to another thread to resolve in
  the new Realm with `-[RLMRealm resolveThreadSafeReference:]`/`Realm.resolve(_:)`.
* Realm collections can now be sorted by properties over to-one relationships.
* Optimized `CONTAINS` queries to use Boyer-Moore algorithm
  (around 10x speedup on large datasets).

### Bugfixes

* Setting `deleteRealmIfMigrationNeeded` now also deletes the Realm if a file
  format migration is required, such as when moving from a file last accessed
  with Realm 0.x to 1.x, or 1.x to 2.x.
* Fix queries containing nested `SUBQUERY` expressions.
* Fix spurious incorrect thread exceptions when a thread id happens to be
  reused while an RLMRealm instance from the old thread still exists.
* Fixed various bugs in aggregate methods (max, min, avg, sum).

2.1.2 Release notes (2016--12-19)
=============================================================

This release adds binary versions of Swift 3.0.2 frameworks built with Xcode 8.2.

### Sync Breaking Changes (In Beta)

* Rename occurences of "iCloud" with "CloudKit" in APIs and comments to match
  naming in the Realm Object Server.

### API Breaking Changes

* None.

### Enhancements

* Add support for 'LIKE' queries (wildcard matching).

### Bugfixes

* Fix authenticating with CloudKit.
* Fix linker warning about "Direct access to global weak symbol".

2.1.1 Release notes (2016-12-02)
=============================================================

### Enhancements

* Add `RealmSwift.ObjectiveCSupport.convert(object:)` methods to help write
  code that interoperates between Realm Objective-C and Realm Swift APIs.
* Throw exceptions when opening a Realm with an incorrect configuration, like:
    * `readOnly` set with a sync configuration.
    * `readOnly` set with a migration block.
    * migration block set with a sync configuration.
* Greatly improve performance of write transactions which make a large number of
  changes to indexed properties, including the automatic migration when opening
  files written by Realm 1.x.

### Bugfixes

* Reset sync metadata Realm in case of decryption error.
* Fix issue preventing using synchronized Realms in Xcode Playgrounds.
* Fix assertion failure when migrating a model property from object type to
  `RLMLinkingObjects` type.
* Fix a `LogicError: Bad version number` exception when using `RLMResults` with
  no notification blocks and explicitly called `-[RLMRealm refresh]` from that
  thread.
* Logged-out users are no longer returned from `+[RLMSyncUser currentUser]` or
  `+[RLMSyncUser allUsers]`.
* Fix several issues which could occur when the 1001st object of a given type
  was created or added to an RLMArray/List, including crashes when rerunning
  existing queries and possibly data corruption.
* Fix a potential crash when the application exits due to a race condition in
  the destruction of global static variables.
* Fix race conditions when waiting for sync uploads or downloads to complete
  which could result in crashes or the callback being called too early.

2.1.0 Release notes (2016-11-18)
=============================================================

### Sync Breaking Changes (In Beta)

* None.

### API breaking changes

* None.

### Enhancements

* Add the ability to skip calling specific notification blocks when committing
  a write transaction.

### Bugfixes

* Deliver collection notifications when beginning a write transaction which
  advances the read version of a Realm (previously only Realm-level
  notifications were sent).
* Fix some scenarios which would lead to inconsistent states when using
  collection notifications.
* Fix several race conditions in the notification functionality.
* Don't send Realm change notifications when canceling a write transaction.

2.0.4 Release notes (2016-11-14)
=============================================================

### Sync Breaking Changes (In Beta)

* Remove `RLMAuthenticationActions` and replace
  `+[RLMSyncCredential credentialWithUsername:password:actions:]` with
  `+[RLMSyncCredential credentialsWithUsername:password:register:]`.
* Rename `+[RLMSyncUser authenticateWithCredential:]` to
  `+[RLMSyncUser logInWithCredentials:]`.
* Rename "credential"-related types and methods to
  `RLMSyncCredentials`/`SyncCredentials` and consistently refer to credentials
  in the plural form.
* Change `+[RLMSyncUser all]` to return a dictionary of identifiers to users and
  rename to:
  * `+[RLMSyncUser allUsers]` in Objective-C.
  * `SyncUser.allUsers()` in Swift 2.
  * `SyncUser.all` in Swift 3.
* Rename `SyncManager.sharedManager()` to `SyncManager.shared` in Swift 3.
* Change `Realm.Configuration.syncConfiguration` to take a `SyncConfiguration`
  struct rather than a named tuple.
* `+[RLMSyncUser logInWithCredentials:]` now invokes its callback block on a
  background queue.

### API breaking changes

* None.

### Enhancements

* Add `+[RLMSyncUser currentUser]`.
* Add the ability to change read, write and management permissions for
  synchronized Realms using the management Realm obtained via the
  `-[RLMSyncUser managementRealmWithError:]` API and the
  `RLMSyncPermissionChange` class.

### Bugfixes

* None.

2.0.3 Release notes (2016-10-27)
=============================================================

This release adds binary versions of Swift 3.0.1 frameworks built with Xcode 8.1
GM seed.

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix a `BadVersion` exception caused by a race condition when delivering
  collection change notifications.
* Fix an assertion failure when additional model classes are added and
  `deleteRealmIfMigrationNeeded` is enabled.
* Fix a `BadTransactLog` exception when deleting an `RLMResults` in a synced
  Realm.
* Fix an assertion failure when a write transaction is in progress at the point
  of process termination.
* Fix a crash that could occur when working with a `RLMLinkingObject` property
  of an unmanaged object.

2.0.2 Release notes (2016-10-05)
=============================================================

This release is not protocol-compatible with previous version of the Realm
Mobile Platform.

### API breaking changes

* Rename Realm Swift's `User` to `SyncUser` to make clear that it relates to the
  Realm Mobile Platform, and to avoid potential conflicts with other `User` types.

### Bugfixes

* Fix Realm headers to be compatible with pre-C++11 dialects of Objective-C++.
* Fix incorrect merging of RLMArray/List changes when objects with the same
  primary key are created on multiple devices.
* Fix bad transaction log errors after deleting objects on a different device.
* Fix a BadVersion error when a background worker finishes running while older
  results from that worker are being delivered to a different thread.

2.0.1 Release notes (2016-09-29)
=============================================================

### Bugfixes

* Fix an assertion failure when opening a Realm file written by a 1.x version
  of Realm which has an indexed nullable int or bool property.

2.0.0 Release notes (2016-09-27)
=============================================================

This release introduces support for the Realm Mobile Platform!
See <https://realm.io/news/introducing-realm-mobile-platform/> for an overview
of these great new features.

### API breaking changes

* By popular demand, `RealmSwift.Error` has been moved from the top-level
  namespace into a `Realm` extension and is now `Realm.Error`, so that it no
  longer conflicts with `Swift.Error`.
* Files written by Realm 2.0 cannot be read by 1.x or earlier versions. Old
  files can still be opened.

### Enhancements

* The .log, .log_a and .log_b files no longer exist and the state tracked in
  them has been moved to the main Realm file. This reduces the number of open
  files needed by Realm, improves performance of both opening and writing to
  Realms, and eliminates a small window where committing write transactions
  would prevent other processes from opening the file.

### Bugfixes

* Fix an assertion failure when sorting by zero properties.
* Fix a mid-commit crash in one process also crashing all other processes with
  the same Realm open.
* Properly initialize new nullable float and double properties added to
  existing objects to null rather than 0.
* Fix a stack overflow when objects with indexed string properties had very
  long common prefixes.
* Fix a race condition which could lead to crashes when using async queries or
  collection notifications.
* Fix a bug which could lead to incorrect state when an object which links to
  itself is deleted from the Realm.

1.1.0 Release notes (2016-09-16)
=============================================================

This release brings official support for Xcode 8, Swift 2.3 and Swift 3.0.
Prebuilt frameworks are now built with Xcode 7.3.1 and Xcode 8.0.

### API breaking changes

* Deprecate `migrateRealm:` in favor of new `performMigrationForConfiguration:error:` method
  that follows Cocoa's NSError conventions.
* Fix issue where `RLMResults` used `id `instead of its generic type as the return
  type of subscript.

### Enhancements

* Improve error message when using NSNumber incorrectly in Swift models.
* Further reduce the download size of the prebuilt static libraries.
* Improve sort performance, especially on non-nullable columns.
* Allow partial initialization of object by `initWithValue:`, deferring
  required property checks until object is added to Realm.

### Bugfixes

* Fix incorrect truncation of the constant value for queries of the form
  `column < value` for `float` and `double` columns.
* Fix crash when an aggregate is accessed as an `Int8`, `Int16`, `Int32`, or `Int64`.
* Fix a race condition that could lead to a crash if an RLMArray or List was
  deallocated on a different thread than it was created on.
* Fix a crash when the last reference to an observed object is released from
  within the observation.
* Fix a crash when `initWithValue:` is used to create a nested object for a class
  with an uninitialized schema.
* Enforce uniqueness for `RealmOptional` primary keys when using the `value` setter.

1.0.2 Release notes (2016-07-13)
=============================================================

### API breaking changes

* Attempting to add an object with no properties to a Realm now throws rather than silently
  doing nothing.

### Enhancements

* Swift: A `write` block may now `throw`, reverting any changes already made in
  the transaction.
* Reduce address space used when committing write transactions.
* Significantly reduce the download size of prebuilt binaries and slightly
  reduce the final size contribution of Realm to applications.
* Improve performance of accessing RLMArray properties and creating objects
  with List properties.

### Bugfixes

* Fix a crash when reading the shared schema from an observed Swift object.
* Fix crashes or incorrect results when passing an array of values to
  `createOrUpdate` after reordering the class's properties.
* Ensure that the initial call of a Results notification block is always passed
  .Initial even if there is a write transaction between when the notification
  is added and when the first notification is delivered.
* Fix a crash when deleting all objects in a Realm while fast-enumerating query
  results from that Realm.
* Handle EINTR from flock() rather than crashing.
* Fix incorrect behavior following a call to `[RLMRealm compact]`.
* Fix live updating and notifications for Results created from a predicate involving
  an inverse relationship to be triggered when an object at the other end of the relationship
  is modified.

1.0.1 Release notes (2016-06-12)
=============================================================

### API breaking changes

* None.

### Enhancements

* Significantly improve performance of opening Realm files, and slightly
  improve performance of committing write transactions.

### Bugfixes

* Swift: Fix an error thrown when trying to create or update `Object` instances via
  `add(:_update:)` with a primary key property of type `RealmOptional`.
* Xcode playground in Swift release zip now runs successfully.
* The `key` parameter of `Realm.objectForPrimaryKey(_:key:)`/ `Realm.dynamicObjectForPrimaryKey(_:key:)`
 is now marked as optional.
* Fix a potential memory leak when closing Realms after a Realm file has been
  opened on multiple threads which are running in active run loops.
* Fix notifications breaking on tvOS after a very large number of write
  transactions have been committed.
* Fix a "Destruction of mutex in use" assertion failure after an error while
  opening a file.
* Realm now throws an exception if an `Object` subclass is defined with a managed Swift `lazy` property.
  Objects with ignored `lazy` properties should now work correctly.
* Update the LLDB script to work with recent changes to the implementation of `RLMResults`.
* Fix an assertion failure when a Realm file is deleted while it is still open,
  and then a new Realm is opened at the same path. Note that this is still not
  a supported scenario, and may break in other ways.

1.0.0 Release notes (2016-05-25)
=============================================================

No changes since 0.103.2.

0.103.2 Release notes (2016-05-24)
=============================================================

### API breaking changes

* None.

### Enhancements

* Improve the error messages when an I/O error occurs in `writeCopyToURL`.

### Bugfixes

* Fix an assertion failure which could occur when opening a Realm after opening
  that Realm failed previously in some specific ways in the same run of the
  application.
* Reading optional integers, floats, and doubles from within a migration block
  now correctly returns `nil` rather than 0 when the stored value is `nil`.

0.103.1 Release notes (2016-05-19)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix a bug that sometimes resulted in a single object's NSData properties
  changing from `nil` to a zero-length non-`nil` NSData when a different object
  of the same type was deleted.

0.103.0 Release notes (2016-05-18)
=============================================================

### API breaking changes

* All functionality deprecated in previous releases has been removed entirely.
* Support for Xcode 6.x & Swift prior to 2.2 has been completely removed.
* `RLMResults`/`Results` now become empty when a `RLMArray`/`List` or object
  they depend on is deleted, rather than throwing an exception when accessed.
* Migrations are no longer run when `deleteRealmIfMigrationNeeded` is set,
  recreating the file instead.

### Enhancements

* Added `invalidated` properties to `RLMResults`/`Results`, `RLMLinkingObjects`/`LinkingObjects`,
  `RealmCollectionType` and `AnyRealmCollection`. These properties report whether the Realm
  the object is associated with has been invalidated.
* Some `NSError`s created by Realm now have more descriptive user info payloads.

### Bugfixes

* None.

0.102.1 Release notes (2016-05-13)
=============================================================

### API breaking changes

* None.

### Enhancements

* Return `RLMErrorSchemaMismatch` error rather than the more generic `RLMErrorFail`
  when a migration is required.
* Improve the performance of allocating instances of `Object` subclasses
  that have `LinkingObjects` properties.

### Bugfixes

* `RLMLinkingObjects` properties declared in Swift subclasses of `RLMObject`
  now work correctly.
* Fix an assertion failure when deleting all objects of a type, inserting more
  objects, and then deleting some of the newly inserted objects within a single
  write transaction when there is an active notification block for a different
  object type which links to the objects being deleted.
* Fix crashes and/or incorrect results when querying over multiple levels of
  `LinkingObjects` properties.
* Fix opening read-only Realms on multiple threads at once.
* Fix a `BadTransactLog` exception when storing dates before the unix epoch (1970-01-01).

0.102.0 Release notes (2016-05-09)
=============================================================

### API breaking changes

* None.

### Enhancements

* Add a method to rename properties during migrations:
  * Swift: `Migration.renamePropertyForClass(_:oldName:newName:)`
  * Objective-C: `-[RLMMigration renamePropertyForClass:oldName:newName:]`
* Add `deleteRealmIfMigrationNeeded` to
  `RLMRealmConfiguration`/`Realm.Configuration`. When this is set to `true`,
  the Realm file will be automatically deleted and recreated when there is a
  schema mismatch rather than migrated to the new schema.

### Bugfixes

* Fix `BETWEEN` queries that traverse `RLMArray`/`List` properties to ensure that
  a single related object satisfies the `BETWEEN` criteria, rather than allowing
  different objects in the array to satisfy the lower and upper bounds.
* Fix a race condition when a Realm is opened on one thread while it is in the
  middle of being closed on another thread which could result in crashes.
* Fix a bug which could result in changes made on one thread being applied
  incorrectly on other threads when those threads are refreshed.
* Fix crash when migrating to the new date format introduced in 0.101.0.
* Fix crash when querying inverse relationships when objects are deleted.

0.101.0 Release notes (2016-05-04)
=============================================================

### API breaking changes

* Files written by this version of Realm cannot be read by older versions of
  Realm. Existing files will automatically be upgraded when they are opened.

### Enhancements

* Greatly improve performance of collection change calculation for complex
  object graphs, especially for ones with cycles.
* NSDate properties now support nanoseconds precision.
* Opening a single Realm file on multiple threads now shares a single memory
  mapping of the file for all threads, significantly reducing the memory
  required to work with large files.
* Crashing while in the middle of a write transaction no longer blocks other
  processes from performing write transactions on the same file.
* Improve the performance of refreshing a Realm (including via autorefresh)
  when there are live Results/RLMResults objects for that Realm.

### Bugfixes

* Fix an assertion failure of "!more_before || index >= std::prev(it)->second)"
  in `IndexSet::do_add()`.
* Fix a crash when an `RLMArray` or `List` object is destroyed from the wrong
  thread.

0.100.0 Release notes (2016-04-29)
=============================================================

### API breaking changes

* `-[RLMObject linkingObjectsOfClass:forProperty]` and `Object.linkingObjects(_:forProperty:)`
  are deprecated in favor of properties of type `RLMLinkingObjects` / `LinkingObjects`.

### Enhancements

* The automatically-maintained inverse direction of relationships can now be exposed as
  properties of type `RLMLinkingObjects` / `LinkingObjects`. These properties automatically
  update to reflect the objects that link to the target object, can be used in queries, and
  can be filtered like other Realm collection types.
* Queries that compare objects for equality now support multi-level key paths.

### Bugfixes

* Fix an assertion failure when a second write transaction is committed after a
  write transaction deleted the object containing an RLMArray/List which had an
  active notification block.
* Queries that compare `RLMArray` / `List` properties using != now give the correct results.

0.99.1 Release notes (2016-04-26)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix a scenario that could lead to the assertion failure
  "m_advancer_sg->get_version_of_current_transaction() ==
  new_notifiers.front()->version()".

0.99.0 Release notes (2016-04-22)
=============================================================

### API breaking changes

* Deprecate properties of type `id`/`AnyObject`. This type was rarely used,
  rarely useful and unsupported in every other Realm binding.
* The block for `-[RLMArray addNotificationBlock:]` and
  `-[RLMResults addNotificationBlock:]` now takes another parameter.
* The following Objective-C APIs have been deprecated in favor of newer or preferred versions:

| Deprecated API                                         | New API                                               |
|:-------------------------------------------------------|:------------------------------------------------------|
| `-[RLMRealm removeNotification:]`                      | `-[RLMNotificationToken stop]`                        |
| `RLMRealmConfiguration.path`                           | `RLMRealmConfiguration.fileURL`                       |
| `RLMRealm.path`                                        | `RLMRealmConfiguration.fileURL`                       |
| `RLMRealm.readOnly`                                    | `RLMRealmConfiguration.readOnly`                      |
| `+[RLMRealm realmWithPath:]`                           | `+[RLMRealm realmWithURL:]`                           |
| `+[RLMRealm writeCopyToPath:error:]`                   | `+[RLMRealm writeCopyToURL:encryptionKey:error:]`     |
| `+[RLMRealm writeCopyToPath:encryptionKey:error:]`     | `+[RLMRealm writeCopyToURL:encryptionKey:error:]`     |
| `+[RLMRealm schemaVersionAtPath:error:]`               | `+[RLMRealm schemaVersionAtURL:encryptionKey:error:]` |
| `+[RLMRealm schemaVersionAtPath:encryptionKey:error:]` | `+[RLMRealm schemaVersionAtURL:encryptionKey:error:]` |

* The following Swift APIs have been deprecated in favor of newer or preferred versions:

| Deprecated API                                | New API                                  |
|:----------------------------------------------|:-----------------------------------------|
| `Realm.removeNotification(_:)`                | `NotificationToken.stop()`               |
| `Realm.Configuration.path`                    | `Realm.Configuration.fileURL`            |
| `Realm.path`                                  | `Realm.Configuration.fileURL`            |
| `Realm.readOnly`                              | `Realm.Configuration.readOnly`           |
| `Realm.writeCopyToPath(_:encryptionKey:)`     | `Realm.writeCopyToURL(_:encryptionKey:)` |
| `schemaVersionAtPath(_:encryptionKey:error:)` | `schemaVersionAtURL(_:encryptionKey:)`   |

### Enhancements

* Add information about what rows were added, removed, or modified to the
  notifications sent to the Realm collections.
* Improve error when illegally appending to an `RLMArray` / `List` property from a default value
  or the standalone initializer (`init()`) before the schema is ready.

### Bugfixes

* Fix a use-after-free when an associated object's dealloc method is used to
  remove observers from an RLMObject.
* Fix a small memory leak each time a Realm file is opened.
* Return a recoverable `RLMErrorAddressSpaceExhausted` error rather than
  crash when there is insufficient available address space on Realm
  initialization or write commit.

0.98.8 Release notes (2016-04-15)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fixed a bug that caused some encrypted files created using
  `-[RLMRealm writeCopyToPath:encryptionKey:error:]` to fail to open.

0.98.7 Release notes (2016-04-13)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Mark further initializers in Objective-C as NS_DESIGNATED_INITIALIZER to prevent that these aren't
  correctly defined in Swift Object subclasses, which don't qualify for auto-inheriting the required initializers.
* `-[RLMResults indexOfObjectWithPredicate:]` now returns correct results
  for `RLMResults` instances that were created by filtering an `RLMArray`.
* Adjust how RLMObjects are destroyed in order to support using an associated
  object on an RLMObject to remove KVO observers from that RLMObject.
* `-[RLMResults indexOfObjectWithPredicate:]` now returns the index of the first matching object for a
  sorted `RLMResults`, matching its documented behavior.
* Fix a crash when canceling a transaction that set a relationship.
* Fix a crash when a query referenced a deleted object.

0.98.6 Release notes (2016-03-25)
=============================================================

Prebuilt frameworks are now built with Xcode 7.3.

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix running unit tests on iOS simulators and devices with Xcode 7.3.

0.98.5 Release notes (2016-03-14)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix a crash when opening a Realm on 32-bit iOS devices.

0.98.4 Release notes (2016-03-10)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Properly report changes made by adding an object to a Realm with
  addOrUpdate:/createOrUpdate: to KVO observers for existing objects with that
  primary key.
* Fix crashes and assorted issues when a migration which added object link
  properties is rolled back due to an error in the migration block.
* Fix assertion failures when deleting objects within a migration block of a
  type which had an object link property added in that migration.
* Fix an assertion failure in `Query::apply_patch` when updating certain kinds
  of queries after a write transaction is committed.

0.98.3 Release notes (2016-02-26)
=============================================================

### Enhancements

* Initializing the shared schema is 3x faster.

### Bugfixes

* Using Realm Objective-C from Swift while having Realm Swift linked no longer causes that the
  declared `ignoredProperties` are not taken into account.
* Fix assertion failures when rolling back a migration which added Object link
  properties to a class.
* Fix potential errors when cancelling a write transaction which modified
  multiple `RLMArray`/`List` properties.
* Report the correct value for inWriteTransaction after attempting to commit a
  write transaction fails.
* Support CocoaPods 1.0 beginning from prerelease 1.0.0.beta.4 while retaining
  backwards compatibility with 0.39.

0.98.2 Release notes (2016-02-18)
=============================================================

### API breaking changes

* None.

### Enhancements

* Aggregate operations (`ANY`, `NONE`, `@count`, `SUBQUERY`, etc.) are now supported for key paths
  that begin with an object relationship so long as there is a `RLMArray`/`List` property at some
  point in a key path.
* Predicates of the form `%@ IN arrayProperty` are now supported.

### Bugfixes

* Use of KVC collection operators on Swift collection types no longer throws an exception.
* Fix reporting of inWriteTransaction in notifications triggered by
  `beginWriteTransaction`.
* The contents of `List` and `Optional` properties are now correctly preserved when copying
  a Swift object from one Realm to another, and performing other operations that result in a
  Swift object graph being recursively traversed from Objective-C.
* Fix a deadlock when queries are performed within a Realm notification block.
* The `ANY` / `SOME` / `NONE` qualifiers are now required in comparisons involving a key path that
  traverse a `RLMArray`/`List` property. Previously they were only required if the first key in the
  key path was an `RLMArray`/`List` property.
* Fix several scenarios where the default schema would be initialized
  incorrectly if the first Realm opened used a restricted class subset (via
  `objectClasses`/`objectTypes`).

0.98.1 Release notes (2016-02-10)
=============================================================

### Bugfixes

* Fix crashes when deleting an object containing an `RLMArray`/`List` which had
  previously been queried.
* Fix a crash when deleting an object containing an `RLMArray`/`List` with
  active notification blocks.
* Fix duplicate file warnings when building via CocoaPods.
* Fix crash or incorrect results when calling `indexOfObject:` on an
  `RLMResults` derived from an `RLMArray`.

0.98.0 Release notes (2016-02-04)
=============================================================

### API breaking changes

* `+[RLMRealm realmWithPath:]`/`Realm.init(path:)` now inherits from the default
  configuration.
* Swift 1.2 is no longer supported.

### Enhancements

* Add `addNotificationBlock` to `RLMResults`, `Results`, `RLMArray`, and
  `List`, which calls the given block whenever the collection changes.
* Do a lot of the work for keeping `RLMResults`/`Results` up-to-date after
  write transactions on a background thread to help avoid blocking the main
  thread.
* `NSPredicate`'s `SUBQUERY` operator is now supported. It has the following limitations:
  * `@count` is the only operator that may be applied to the `SUBQUERY` expression.
  * The `SUBQUERY(…).@count` expression must be compared with a constant.
  * Correlated subqueries are not yet supported.

### Bugfixes

* None.

0.97.1 Release notes (2016-01-29)
=============================================================

### API breaking changes

* None.

### Enhancements

* Swift: Added `Error` enum allowing to catch errors e.g. thrown on initializing
  `RLMRealm`/`Realm` instances.
* Fail with `RLMErrorFileNotFound` instead of the more generic `RLMErrorFileAccess`,
  if no file was found when a realm was opened as read-only or if the directory part
  of the specified path was not found when a copy should be written.
* Greatly improve performance when deleting objects with one or more indexed
  properties.
* Indexing `BOOL`/`Bool` and `NSDate` properties are now supported.
* Swift: Add support for indexing optional properties.

### Bugfixes

* Fix incorrect results or crashes when using `-[RLMResults setValue:forKey:]`
  on an RLMResults which was filtered on the key being set.
* Fix crashes when an RLMRealm is deallocated from the wrong thread.
* Fix incorrect results from aggregate methods on `Results`/`RLMResults` after
  objects which were previously in the results are deleted.
* Fix a crash when adding a new property to an existing class with over a
  million objects in the Realm.
* Fix errors when opening encrypted Realm files created with writeCopyToPath.
* Fix crashes or incorrect results for queries that use relationship equality
  in cases where the `RLMResults` is kept alive and instances of the target class
  of the relationship are deleted.

0.97.0 Release notes (2015-12-17)
=============================================================

### API breaking changes

* All functionality deprecated in previous releases has been removed entirely.
* Add generic type annotations to NSArrays and NSDictionaries in public APIs.
* Adding a Realm notification block on a thread not currently running from
  within a run loop throws an exception rather than silently never calling the
  notification block.

### Enhancements

* Support for tvOS.
* Support for building Realm Swift from source when using Carthage.
* The block parameter of `-[RLMRealm transactionWithBlock:]`/`Realm.write(_:)` is
  now marked as `__attribute__((noescape))`/`@noescape`.
* Many forms of queries with key paths on both sides of the comparison operator
  are now supported.
* Add support for KVC collection operators in `RLMResults` and `RLMArray`.
* Fail instead of deadlocking in `+[RLMRealm sharedSchema]`, if a Swift property is initialized
  to a computed value, which attempts to open a Realm on its own.

### Bugfixes

* Fix poor performance when calling `-[RLMRealm deleteObjects:]` on an
  `RLMResults` which filtered the objects when there are other classes linking
  to the type of the deleted objects.
* An exception is now thrown when defining `Object` properties of an unsupported
  type.

0.96.3 Release notes (2015-12-04)
=============================================================

### Enhancements

* Queries are no longer limited to 16 levels of grouping.
* Rework the implementation of encrypted Realms to no longer interfere with
  debuggers.

### Bugfixes

* Fix crash when trying to retrieve object instances via `dynamicObjects`.
* Throw an exception when querying on a link providing objects, which are from a different Realm.
* Return empty results when querying on a link providing an unattached object.
* Fix crashes or incorrect results when calling `-[RLMRealm refresh]` during
  fast enumeration.
* Add `Int8` support for `RealmOptional`, `MinMaxType` and `AddableType`.
* Set the default value for newly added non-optional NSData properties to a
  zero-byte NSData rather than nil.
* Fix a potential crash when deleting all objects of a class.
* Fix performance problems when creating large numbers of objects with
  `RLMArray`/`List` properties.
* Fix memory leak when using Object(value:) for subclasses with
  `List` or `RealmOptional` properties.
* Fix a crash when computing the average of an optional integer property.
* Fix incorrect search results for some queries on integer properties.
* Add error-checking for nil realm parameters in many methods such as
  `+[RLMObject allObjectsInRealm:]`.
* Fix a race condition between commits and opening Realm files on new threads
  that could lead to a crash.
* Fix several crashes when opening Realm files.
* `-[RLMObject createInRealm:withValue:]`, `-[RLMObject createOrUpdateInRealm:withValue:]`, and
  their variants for the default Realm now always match the contents of an `NSArray` against properties
  in the same order as they are defined in the model.

0.96.2 Release notes (2015-10-26)
=============================================================

Prebuilt frameworks are now built with Xcode 7.1.

### Bugfixes

* Fix ignoring optional properties in Swift.
* Fix CocoaPods installation on case-sensitive file systems.

0.96.1 Release notes (2015-10-20)
=============================================================

### Bugfixes

* Support assigning `Results` to `List` properties via KVC.
* Honor the schema version set in the configuration in `+[RLMRealm migrateRealm:]`.
* Fix crash when using optional Int16/Int32/Int64 properties in Swift.

0.96.0 Release notes (2015-10-14)
=============================================================

* No functional changes since beta2.

0.96.0-beta2 Release notes (2015-10-08)
=============================================================

### Bugfixes

* Add RLMOptionalBase.h to the podspec.

0.96.0-beta Release notes (2015-10-07)
=============================================================

### API breaking changes

* CocoaPods v0.38 or greater is now required to install Realm and RealmSwift
  as pods.

### Enhancements

* Functionality common to both `List` and `Results` is now declared in a
  `RealmCollectionType` protocol that both types conform to.
* `Results.realm` now returns an `Optional<Realm>` in order to conform to
  `RealmCollectionType`, but will always return `.Some()` since a `Results`
  cannot exist independently from a `Realm`.
* Aggregate operations are now available on `List`: `min`, `max`, `sum`,
  `average`.
* Committing write transactions (via `commitWrite` / `commitWriteTransaction` and
  `write` / `transactionWithBlock`) now optionally allow for handling errors when
  the disk is out of space.
* Added `isEmpty` property on `RLMRealm`/`Realm` to indicate if it contains any
  objects.
* The `@count`, `@min`, `@max`, `@sum` and `@avg` collection operators are now
  supported in queries.

### Bugfixes

* Fix assertion failure when inserting NSData between 8MB and 16MB in size.
* Fix assertion failure when rolling back a migration which removed an object
  link or `RLMArray`/`List` property.
* Add the path of the file being opened to file open errors.
* Fix a crash that could be triggered by rapidly opening and closing a Realm
  many times on multiple threads at once.
* Fix several places where exception messages included the name of the wrong
  function which failed.

0.95.3 Release notes (2015-10-05)
=============================================================

### Bugfixes

* Compile iOS Simulator framework architectures with `-fembed-bitcode-marker`.
* Fix crashes when the first Realm opened uses a class subset and later Realms
  opened do not.
* Fix inconsistent errors when `Object(value: ...)` is used to initialize the
  default value of a property of an `Object` subclass.
* Throw an exception when a class subset has objects with array or object
  properties of a type that are not part of the class subset.

0.95.2 Release notes (2015-09-24)
=============================================================

* Enable bitcode for iOS and watchOS frameworks.
* Build libraries with Xcode 7 final rather than the GM.

0.95.1 Release notes (2015-09-23)
=============================================================

### Enhancements

* Add missing KVO handling for moving and exchanging objects in `RLMArray` and
  `List`.

### Bugfixes

* Setting the primary key property on persisted `RLMObject`s / `Object`s
  via subscripting or key-value coding will cause an exception to be thrown.
* Fix crash due to race condition in `RLMRealmConfiguration` where the default
  configuration was in the process of being copied in one thread, while
  released in another.
* Fix crash when a migration which removed an object or array property is
  rolled back due to an error.

0.95.0 Release notes (2015-08-25)
=============================================================

### API breaking changes

* The following APIs have been deprecated in favor of the new `RLMRealmConfiguration` class in Realm Objective-C:

| Deprecated API                                                    | New API                                                                          |
|:------------------------------------------------------------------|:---------------------------------------------------------------------------------|
| `+[RLMRealm realmWithPath:readOnly:error:]`                       | `+[RLMRealm realmWithConfiguration:error:]`                                      |
| `+[RLMRealm realmWithPath:encryptionKey:readOnly:error:]`         | `+[RLMRealm realmWithConfiguration:error:]`                                      |
| `+[RLMRealm setEncryptionKey:forRealmsAtPath:]`                   | `-[RLMRealmConfiguration setEncryptionKey:]`                                     |
| `+[RLMRealm inMemoryRealmWithIdentifier:]`                        | `+[RLMRealm realmWithConfiguration:error:]`                                      |
| `+[RLMRealm defaultRealmPath]`                                    | `+[RLMRealmConfiguration defaultConfiguration]`                                  |
| `+[RLMRealm setDefaultRealmPath:]`                                | `+[RLMRealmConfiguration setDefaultConfiguration:]`                              |
| `+[RLMRealm setDefaultRealmSchemaVersion:withMigrationBlock]`     | `RLMRealmConfiguration.schemaVersion` and `RLMRealmConfiguration.migrationBlock` |
| `+[RLMRealm setSchemaVersion:forRealmAtPath:withMigrationBlock:]` | `RLMRealmConfiguration.schemaVersion` and `RLMRealmConfiguration.migrationBlock` |
| `+[RLMRealm migrateRealmAtPath:]`                                 | `+[RLMRealm migrateRealm:]`                                                      |
| `+[RLMRealm migrateRealmAtPath:encryptionKey:]`                   | `+[RLMRealm migrateRealm:]`                                                      |

* The following APIs have been deprecated in favor of the new `Realm.Configuration` struct in Realm Swift for Swift 1.2:

| Deprecated API                                                | New API                                                                      |
|:--------------------------------------------------------------|:-----------------------------------------------------------------------------|
| `Realm.defaultPath`                                           | `Realm.Configuration.defaultConfiguration`                                   |
| `Realm(path:readOnly:encryptionKey:error:)`                   | `Realm(configuration:error:)`                                                |
| `Realm(inMemoryIdentifier:)`                                  | `Realm(configuration:error:)`                                                |
| `Realm.setEncryptionKey(:forPath:)`                           | `Realm(configuration:error:)`                                                |
| `setDefaultRealmSchemaVersion(schemaVersion:migrationBlock:)` | `Realm.Configuration.schemaVersion` and `Realm.Configuration.migrationBlock` |
| `setSchemaVersion(schemaVersion:realmPath:migrationBlock:)`   | `Realm.Configuration.schemaVersion` and `Realm.Configuration.migrationBlock` |
| `migrateRealm(path:encryptionKey:)`                           | `migrateRealm(configuration:)`                                               |

* The following APIs have been deprecated in favor of the new `Realm.Configuration` struct in Realm Swift for Swift 2.0:

| Deprecated API                                                | New API                                                                      |
|:--------------------------------------------------------------|:-----------------------------------------------------------------------------|
| `Realm.defaultPath`                                           | `Realm.Configuration.defaultConfiguration`                                   |
| `Realm(path:readOnly:encryptionKey:) throws`                  | `Realm(configuration:) throws`                                               |
| `Realm(inMemoryIdentifier:)`                                  | `Realm(configuration:) throws`                                               |
| `Realm.setEncryptionKey(:forPath:)`                           | `Realm(configuration:) throws`                                               |
| `setDefaultRealmSchemaVersion(schemaVersion:migrationBlock:)` | `Realm.Configuration.schemaVersion` and `Realm.Configuration.migrationBlock` |
| `setSchemaVersion(schemaVersion:realmPath:migrationBlock:)`   | `Realm.Configuration.schemaVersion` and `Realm.Configuration.migrationBlock` |
| `migrateRealm(path:encryptionKey:)`                           | `migrateRealm(configuration:)`                                               |

* `List.extend` in Realm Swift for Swift 2.0 has been replaced with `List.appendContentsOf`,
  mirroring changes to `RangeReplaceableCollectionType`.

* Object properties on `Object` subclasses in Realm Swift must be marked as optional,
  otherwise a runtime exception will be thrown.

### Enhancements

* Persisted properties of `RLMObject`/`Object` subclasses are now Key-Value
  Observing compliant.
* The different options used to create Realm instances have been consolidated
  into a single `RLMRealmConfiguration`/`Realm.Configuration` object.
* Enumerating Realm collections (`RLMArray`, `RLMResults`, `List<>`,
  `Results<>`) now enumerates over a copy of the collection, making it no
  longer an error to modify a collection during enumeration (either directly,
  or indirectly by modifying objects to make them no longer match a query).
* Improve performance of object insertion in Swift to bring it roughly in line
  with Objective-C.
* Allow specifying a specific list of `RLMObject` / `Object` subclasses to include
  in a given Realm via `RLMRealmConfiguration.objectClasses` / `Realm.Configuration.objectTypes`.

### Bugfixes

* Subscripting on `RLMObject` is now marked as nullable.

0.94.1 Release notes (2015-08-10)
=============================================================

### API breaking changes

* Building for watchOS requires Xcode 7 beta 5.

### Enhancements

* `Object.className` is now marked as `final`.

### Bugfixes

* Fix crash when adding a property to a model without updating the schema
  version.
* Fix unnecessary redownloading of the core library when building from source.
* Fix crash when sorting by an integer or floating-point property on iOS 7.

0.94.0 Release notes (2015-07-29)
=============================================================

### API breaking changes

* None.

### Enhancements

* Reduce the amount of memory used by RLMRealm notification listener threads.
* Avoid evaluating results eagerly when filtering and sorting.
* Add nullability annotations to the Objective-C API to provide enhanced compiler
  warnings and bridging to Swift.
* Make `RLMResult`s and `RLMArray`s support Objective-C generics.
* Add support for building watchOS and bitcode-compatible apps.
* Make the exceptions thrown in getters and setters more informative.
* Add `-[RLMArray exchangeObjectAtIndex:withObjectAtIndex]` and `List.swap(_:_:)`
  to allow exchanging the location of two objects in the given `RLMArray` / `List`.
* Added anonymous analytics on simulator/debugger runs.
* Add `-[RLMArray moveObjectAtIndex:toIndex:]` and `List.move(from:to:)` to
  allow moving objects in the given `RLMArray` / `List`.

### Bugfixes

* Processes crashing due to an uncaught exception inside a write transaction will
  no longer cause other processes using the same Realm to hang indefinitely.
* Fix incorrect results when querying for < or <= on ints that
  require 64 bits to represent with a CPU that supports SSE 4.2.
* An exception will no longer be thrown when attempting to reset the schema
  version or encryption key on an open Realm to the current value.
* Date properties on 32 bit devices will retain 64 bit second precision.
* Wrap calls to the block passed to `enumerate` in an autoreleasepool to reduce
  memory growth when migrating a large amount of objects.
* In-memory realms no longer write to the Documents directory on iOS or
  Application Support on OS X.

0.93.2 Release notes (2015-06-12)
=============================================================

### Bugfixes

* Fixed an issue where the packaged OS X Realm.framework was built with
  `GCC_GENERATE_TEST_COVERAGE_FILES` and `GCC_INSTRUMENT_PROGRAM_FLOW_ARCS`
  enabled.
* Fix a memory leak when constructing standalone Swift objects with NSDate
  properties.
* Throw an exception rather than asserting when an invalidated object is added
  to an RLMArray.
* Fix a case where data loss would occur if a device was hard-powered-off
  shortly after a write transaction was committed which had to expand the Realm
  file.

0.93.1 Release notes (2015-05-29)
=============================================================

### Bugfixes

* Objects are no longer copied into standalone objects during object creation. This fixes an issue where
  nested objects with a primary key are sometimes duplicated rather than updated.
* Comparison predicates with a constant on the left of the operator and key path on the right now give
  correct results. An exception is now thrown for predicates that do not yet support this ordering.
* Fix some crashes in `index_string.cpp` with int primary keys or indexed int properties.

0.93.0 Release notes (2015-05-27)
=============================================================

### API breaking changes

* Schema versions are now represented as `uint64_t` (Objective-C) and `UInt64` (Swift) so that they have
  the same representation on all architectures.

### Enhancements

* Swift: `Results` now conforms to `CVarArgType` so it can
  now be passed as an argument to `Results.filter(_:...)`
  and `List.filter(_:...)`.
* Swift: Made `SortDescriptor` conform to the `Equatable` and
  `StringLiteralConvertible` protocols.
* Int primary keys are once again automatically indexed.
* Improve error reporting when attempting to mark a property of a type that
  cannot be indexed as indexed.

### Bugfixes

* Swift: `RealmSwift.framework` no longer embeds `Realm.framework`,
  which now allows apps using it to pass iTunes Connect validation.

0.92.4 Release notes (2015-05-22)
=============================================================

### API breaking changes

* None.

### Enhancements

* Swift: Made `Object.init()` a required initializer.
* `RLMObject`, `RLMResults`, `Object` and `Results` can now be safely
  deallocated (but still not used) from any thread.
* Improve performance of `-[RLMArray indexOfObjectWhere:]` and `-[RLMArray
  indexOfObjectWithPredicate:]`, and implement them for standalone RLMArrays.
* Improved performance of most simple queries.

### Bugfixes

* The interprocess notification mechanism no longer uses dispatch worker threads, preventing it from
  starving other GCD clients of the opportunity to execute blocks when dozens of Realms are open at once.

0.92.3 Release notes (2015-05-13)
=============================================================

### API breaking changes

* Swift: `Results.average(_:)` now returns an optional, which is `nil` if and only if the results
  set is empty.

### Enhancements

* Swift: Added `List.invalidated`, which returns if the given `List` is no longer
  safe to be accessed, and is analogous to `-[RLMArray isInvalidated]`.
* Assertion messages are automatically logged to Crashlytics if it's loaded
  into the current process to make it easier to diagnose crashes.

### Bugfixes

* Swift: Enumerating through a standalone `List` whose objects themselves
  have list properties won't crash.
* Swift: Using a subclass of `RealmSwift.Object` in an aggregate operator of a predicate
  no longer throws a spurious type error.
* Fix incorrect results for when using OR in a query on a `RLMArray`/`List<>`.
* Fix incorrect values from `[RLMResults count]`/`Results.count` when using
  `!=` on an int property with no other query conditions.
* Lower the maximum doubling threshold for Realm file sizes from 128MB to 16MB
  to reduce the amount of wasted space.

0.92.2 Release notes (2015-05-08)
=============================================================

### API breaking changes

* None.

### Enhancements

* Exceptions raised when incorrect object types are used with predicates now contain more detailed information.
* Added `-[RLMMigration deleteDataForClassName:]` and `Migration.deleteData(_:)`
  to enable cleaning up after removing object subclasses

### Bugfixes

* Prevent debugging of an application using an encrypted Realm to work around
  frequent LLDB hangs. Until the underlying issue is addressed you may set
  REALM_DISABLE_ENCRYPTION=YES in your application's environment variables to
  have requests to open an encrypted Realm treated as a request for an
  unencrypted Realm.
* Linked objects are properly updated in `createOrUpdateInRealm:withValue:`.
* List properties on Objects are now properly initialized during fast enumeration.

0.92.1 Release notes (2015-05-06)
=============================================================

### API breaking changes

* None.

### Enhancements

* `-[RLMRealm inWriteTransaction]` is now public.
* Realm Swift is now available on CoocaPods.

### Bugfixes

* Force code re-signing after stripping architectures in `strip-frameworks.sh`.

0.92.0 Release notes (2015-05-05)
=============================================================

### API breaking changes

* Migration blocks are no longer called when a Realm file is first created.
* The following APIs have been deprecated in favor of newer method names:

| Deprecated API                                         | New API                                               |
|:-------------------------------------------------------|:------------------------------------------------------|
| `-[RLMMigration createObject:withObject:]`             | `-[RLMMigration createObject:withValue:]`             |
| `-[RLMObject initWithObject:]`                         | `-[RLMObject initWithValue:]`                         |
| `+[RLMObject createInDefaultRealmWithObject:]`         | `+[RLMObject createInDefaultRealmWithValue:]`         |
| `+[RLMObject createInRealm:withObject:]`               | `+[RLMObject createInRealm:withValue:]`               |
| `+[RLMObject createOrUpdateInDefaultRealmWithObject:]` | `+[RLMObject createOrUpdateInDefaultRealmWithValue:]` |
| `+[RLMObject createOrUpdateInRealm:withObject:]`       | `+[RLMObject createOrUpdateInRealm:withValue:]`       |

### Enhancements

* `Int8` properties defined in Swift are now treated as integers, rather than
  booleans.
* NSPredicates created using `+predicateWithValue:` are now supported.

### Bugfixes

* Compound AND predicates with no subpredicates now correctly match all objects.

0.91.5 Release notes (2015-04-28)
=============================================================

### Bugfixes

* Fix issues with removing search indexes and re-enable it.

0.91.4 Release notes (2015-04-27)
=============================================================

### Bugfixes

* Temporarily disable removing indexes from existing columns due to bugs.

0.91.3 Release notes (2015-04-17)
=============================================================

### Bugfixes

* Fix `Extra argument 'objectClassName' in call` errors when building via
  CocoaPods.

0.91.2 Release notes (2015-04-16)
=============================================================

* Migration blocks are no longer called when a Realm file is first created.

### Enhancements

* `RLMCollection` supports collection KVC operations.
* Sorting `RLMResults` is 2-5x faster (typically closer to 2x).
* Refreshing `RLMRealm` after a write transaction which inserts or modifies
  strings or `NSData` is committed on another thread is significantly faster.
* Indexes are now added and removed from existing properties when a Realm file
  is opened, rather than only when properties are first added.

### Bugfixes

* `+[RLMSchema dynamicSchemaForRealm:]` now respects search indexes.
* `+[RLMProperty isEqualToProperty:]` now checks for equal `indexed` properties.

0.91.1 Release notes (2015-03-12)
=============================================================

### Enhancements

* The browser will automatically refresh when the Realm has been modified
  from another process.
* Allow using Realm in an embedded framework by setting
  `APPLICATION_EXTENSION_API_ONLY` to YES.

### Bugfixes

* Fix a crash in CFRunLoopSourceInvalidate.

0.91.0 Release notes (2015-03-10)
=============================================================

### API breaking changes

* `attributesForProperty:` has been removed from `RLMObject`. You now specify indexed
  properties by implementing the `indexedProperties` method.
* An exception will be thrown when calling `setEncryptionKey:forRealmsAtPath:`,
  `setSchemaVersion:forRealmAtPath:withMigrationBlock:`, and `migrateRealmAtPath:`
  when a Realm at the given path is already open.
* Object and array properties of type `RLMObject` will no longer be allowed.

### Enhancements

* Add support for sharing Realm files between processes.
* The browser will no longer show objects that have no persisted properties.
* `RLMSchema`, `RLMObjectSchema`, and `RLMProperty` now have more useful descriptions.
* Opening an encrypted Realm while a debugger is attached to the process no
  longer throws an exception.
* `RLMArray` now exposes an `isInvalidated` property to indicate if it can no
  longer be accessed.

### Bugfixes

* An exception will now be thrown when calling `-beginWriteTransaction` from within a notification
  triggered by calling `-beginWriteTransaction` elsewhere.
* When calling `delete:` we now verify that the object being deleted is persisted in the target Realm.
* Fix crash when calling `createOrUpdate:inRealm` with nested linked objects.
* Use the key from `+[RLMRealm setEncryptionKey:forRealmsAtPath:]` in
  `-writeCopyToPath:error:` and `+migrateRealmAtPath:`.
* Comparing an RLMObject to a non-RLMObject using `-[RLMObject isEqual:]` or
  `-isEqualToObject:` now returns NO instead of crashing.
* Improved error message when an `RLMObject` subclass is defined nested within
  another Swift declaration.
* Fix crash when the process is terminated by the OS on iOS while encrypted realms are open.
* Fix crash after large commits to encrypted realms.

0.90.6 Release notes (2015-02-20)
=============================================================

### Enhancements

* Improve compatiblity of encrypted Realms with third-party crash reporters.

### Bugfixes

* Fix incorrect results when using aggregate functions on sorted RLMResults.
* Fix data corruption when using writeCopyToPath:encryptionKey:.
* Maybe fix some assertion failures.

0.90.5 Release notes (2015-02-04)
=============================================================

### Bugfixes

* Fix for crashes when encryption is enabled on 64-bit iOS devices.

0.90.4 Release notes (2015-01-29)
=============================================================

### Bugfixes

* Fix bug that resulted in columns being dropped and recreated during migrations.

0.90.3 Release notes (2015-01-27)
=============================================================

### Enhancements

* Calling `createInDefaultRealmWithObject:`, `createInRealm:withObject:`,
  `createOrUpdateInDefaultRealmWithObject:` or `createOrUpdateInRealm:withObject:`
  is a no-op if the argument is an RLMObject of the same type as the receiver
  and is already backed by the target realm.

### Bugfixes

* Fix incorrect column type assertions when the first Realm file opened is a
  read-only file that is missing tables.
* Throw an exception when adding an invalidated or deleted object as a link.
* Throw an exception when calling `createOrUpdateInRealm:withObject:` when the
  receiver has no primary key defined.

0.90.1 Release notes (2015-01-22)
=============================================================

### Bugfixes

* Fix for RLMObject being treated as a model object class and showing up in the browser.
* Fix compilation from the podspec.
* Fix for crash when calling `objectsWhere:` with grouping in the query on `allObjects`.

0.90.0 Release notes (2015-01-21)
=============================================================

### API breaking changes

* Rename `-[RLMRealm encryptedRealmWithPath:key:readOnly:error:]` to
  `-[RLMRealm realmWithPath:encryptionKey:readOnly:error:]`.
* `-[RLMRealm setSchemaVersion:withMigrationBlock]` is no longer global and must be called
  for each individual Realm path used. You can now call `-[RLMRealm setDefaultRealmSchemaVersion:withMigrationBlock]`
  for the default Realm and `-[RLMRealm setSchemaVersion:forRealmAtPath:withMigrationBlock:]` for all others;

### Enhancements

* Add `-[RLMRealm writeCopyToPath:encryptionKey:error:]`.
* Add support for comparing string columns to other string columns in queries.

### Bugfixes

* Roll back changes made when an exception is thrown during a migration.
* Throw an exception if the number of items in a RLMResults or RLMArray changes
  while it's being fast-enumerated.
* Also encrypt the temporary files used when encryption is enabled for a Realm.
* Fixed crash in JSONImport example on OS X with non-en_US locale.
* Fixed infinite loop when opening a Realm file in the Browser at the same time
  as it is open in a 32-bit simulator.
* Fixed a crash when adding primary keys to older realm files with no primary
  keys on any objects.
* Fixed a crash when removing a primary key in a migration.
* Fixed a crash when multiple write transactions with no changes followed by a
  write transaction with changes were committed without the main thread
  RLMRealm getting a chance to refresh.
* Fixed incomplete results when querying for non-null relationships.
* Improve the error message when a Realm file is opened in multiple processes
  at once.

0.89.2 Release notes (2015-01-02)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix an assertion failure when invalidating a Realm which is in a write
  transaction, has already been invalidated, or has never been used.
* Fix an assertion failure when sorting an empty RLMArray property.
* Fix a bug resulting in the browser never becoming visible on 10.9.
* Write UTF-8 when generating class files from a realm file in the Browser.

0.89.1 Release notes (2014-12-22)
=============================================================

### API breaking changes

* None.

### Enhancements

* Improve the error message when a Realm can't be opened due to lacking write
  permissions.

### Bugfixes

* Fix an assertion failure when inserting rows after calling `deleteAllObjects`
  on a Realm.
* Separate dynamic frameworks are now built for the simulator and devices to
  work around App Store submission errors due to the simulator version not
  being automatically stripped from dynamic libraries.

0.89.0 Release notes (2014-12-18)
=============================================================

### API breaking changes

* None.

### Enhancements

* Add support for encrypting Realm files on disk.
* Support using KVC-compliant objects without getters or with custom getter
  names to initialize RLMObjects with `createObjectInRealm` and friends.

### Bugfixes

* Merge native Swift default property values with defaultPropertyValues().
* Don't leave the database schema partially updated when opening a realm fails
  due to a migration being needed.
* Fixed issue where objects with custom getter names couldn't be used to
  initialize other objects.
* Fix a major performance regression on queries on string properties.
* Fix a memory leak when circularly linked objects are added to a Realm.

0.88.0 Release notes (2014-12-02)
=============================================================

### API breaking changes

* Deallocating an RLMRealm instance in a write transaction lacking an explicit
  commit/cancel will now be automatically cancelled instead of committed.
* `-[RLMObject isDeletedFromRealm]` has been renamed to `-[RLMObject isInvalidated]`.

### Enhancements

* Add `-[RLMRealm writeCopyToPath:]` to write a compacted copy of the Realm
  another file.
* Add support for case insensitive, BEGINSWITH, ENDSWITH and CONTAINS string
  queries on array properties.
* Make fast enumeration of `RLMArray` and `RLMResults` ~30% faster and
  `objectAtIndex:` ~55% faster.
* Added a lldb visualizer script for displaying the contents of persisted
  RLMObjects when debugging.
* Added method `-setDefaultRealmPath:` to change the default Realm path.
* Add `-[RLMRealm invalidate]` to release data locked by the current thread.

### Bugfixes

* Fix for crash when running many simultaneous write transactions on background threads.
* Fix for crashes caused by opening Realms at multiple paths simultaneously which have had
  properties re-ordered during migration.
* Don't run the query twice when `firstObject` or `lastObject` are called on an
  `RLMResults` which has not had its results accessed already.
* Fix for bug where schema version is 0 for new Realm created at the latest version.
* Fix for error message where no migration block is specified when required.

0.87.4 Release notes (2014-11-07)
=============================================================

### API breaking changes

* None.

### Enhancements

* None.

### Bugfixes

* Fix browser location in release zip.

0.87.3 Release notes (2014-11-06)
=============================================================

### API breaking changes

* None.

### Enhancements

* Added method `-linkingObjectsOfClass:forProperty:` to RLMObject to expose inverse
  relationships/backlinks.

### Bugfixes

* Fix for crash due to missing search index when migrating an object with a string primary key
  in a database created using an older versions (0.86.3 and earlier).
* Throw an exception when passing an array containing a
  non-RLMObject to -[RLMRealm addObjects:].
* Fix for crash when deleting an object from multiple threads.

0.87.0 Release notes (2014-10-21)
=============================================================

### API breaking changes

* RLMArray has been split into two classes, `RLMArray` and `RLMResults`. RLMArray is
  used for object properties as in previous releases. Moving forward all methods used to
  enumerate, query, and sort objects return an instance of a new class `RLMResults`. This
  change was made to support diverging apis and the future addition of change notifications
  for queries.
* The api for migrations has changed. You now call `setSchemaVersion:withMigrationBlock:` to
  register a global migration block and associated version. This block is applied to Realms as
  needed when opened for Realms at a previous version. The block can be applied manually if
  desired by calling `migrateRealmAtPath:`.
* `arraySortedByProperty:ascending:` was renamed to `sortedResultsUsingProperty:ascending`
* `addObjectsFromArray:` on both `RLMRealm` and `RLMArray` has been renamed to `addObjects:`
  and now accepts any container class which implements `NSFastEnumeration`
* Building with Swift support now requires Xcode 6.1

### Enhancements

* Add support for sorting `RLMArray`s by multiple columns with `sortedResultsUsingDescriptors:`
* Added method `deleteAllObjects` on `RLMRealm` to clear a Realm.
* Added method `createObject:withObject:` on `RLMMigration` which allows object creation during migrations.
* Added method `deleteObject:` on `RLMMigration` which allows object deletion during migrations.
* Updating to core library version 0.85.0.
* Implement `objectsWhere:` and `objectsWithPredicate:` for array properties.
* Add `cancelWriteTransaction` to revert all changes made in a write transaction and end the transaction.
* Make creating `RLMRealm` instances on background threads when an instance
  exists on another thread take a fifth of the time.
* Support for partial updates when calling `createOrUpdateWithObject:` and `addOrUpdateObject:`
* Re-enable Swift support on OS X

### Bugfixes

* Fix exceptions when trying to set `RLMObject` properties after rearranging
  the properties in a `RLMObject` subclass.
* Fix crash on IN query with several thousand items.
* Fix crash when querying indexed `NSString` properties.
* Fixed an issue which prevented in-memory Realms from being used accross multiple threads.
* Preserve the sort order when querying a sorted `RLMResults`.
* Fixed an issue with migrations where if a Realm file is deleted after a Realm is initialized,
  the newly created Realm can be initialized with an incorrect schema version.
* Fix crash in `RLMSuperSet` when assigning to a `RLMArray` property on a standalone object.
* Add an error message when the protocol for an `RLMArray` property is not a
  valid object type.
* Add an error message when an `RLMObject` subclass is defined nested within
  another Swift class.

0.86.3 Release notes (2014-10-09)
=============================================================

### Enhancements

* Add support for != in queries on object relationships.

### Bugfixes

* Re-adding an object to its Realm no longer throws an exception and is now a no-op
  (as it was previously).
* Fix another bug which would sometimes result in subclassing RLMObject
  subclasses not working.

0.86.2 Release notes (2014-10-06)
=============================================================

### Bugfixes

* Fixed issues with packaging "Realm Browser.app" for release.

0.86.1 Release notes (2014-10-03)
=============================================================

### Bugfixes

* Fix a bug which would sometimes result in subclassing RLMObject subclasses
  not working.

0.86.0 Release notes (2014-10-03)
=============================================================

### API breaking changes

* Xcode 6 is now supported from the main Xcode project `Realm.xcodeproj`.
  Xcode 5 is no longer supported.

### Enhancements

* Support subclassing RLMObject models. Although you can now persist subclasses,
  polymorphic behavior is not supported (i.e. setting a property to an
  instance of its subclass).
* Add support for sorting RLMArray properties.
* Speed up inserting objects with `addObject:` by ~20%.
* `readonly` properties are automatically ignored rather than having to be
  added to `ignoredProperties`.
* Updating to core library version 0.83.1.
* Return "[deleted object]" rather than throwing an exception when
  `-description` is called on a deleted RLMObject.
* Significantly improve performance of very large queries.
* Allow passing any enumerable to IN clauses rather than just NSArray.
* Add `objectForPrimaryKey:` and `objectInRealm:forPrimaryKey:` convenience
  methods to fetch an object by primary key.

### Bugfixes

* Fix error about not being able to persist property 'hash' with incompatible
  type when building for devices with Xcode 6.
* Fix spurious notifications of new versions of Realm.
* Fix for updating nested objects where some types do not have primary keys.
* Fix for inserting objects from JSON with NSNull values when default values
  should be used.
* Trying to add a persisted RLMObject to a different Realm now throws an
  exception rather than creating an uninitialized object.
* Fix validation errors when using IN on array properties.
* Fix errors when an IN clause has zero items.
* Fix for chained queries ignoring all but the last query's conditions.

0.85.0 Release notes (2014-09-15)
=============================================================

### API breaking changes

* Notifications for a refresh being needed (when autorefresh is off) now send
  the notification type RLMRealmRefreshRequiredNotification rather than
  RLMRealmDidChangeNotification.

### Enhancements

* Updating to core library version 0.83.0.
* Support for primary key properties (for int and string columns). Declaring a property
  to be the primary key ensures uniqueness for that property for all objects of a given type.
  At the moment indexes on primary keys are not yet supported but this will be added in a future
  release.
* Added methods to update or insert (upsert) for objects with primary keys defined.
* `[RLMObject initWithObject:]` and `[RLMObject createInRealmWithObject:]` now support
  any object type with kvc properties.
* The Swift support has been reworked to work around Swift not being supported
  in Frameworks on iOS 7.
* Improve performance when getting the count of items matching a query but not
  reading any of the objects in the results.
* Add a return value to `-[RLMRealm refresh]` that indicates whether or not
  there was anything to refresh.
* Add the class name to the error message when an RLMObject is missing a value
  for a property without a default.
* Add support for opening Realms in read-only mode.
* Add an automatic check for updates when using Realm in a simulator (the
  checker code is not compiled into device builds). This can be disabled by
  setting the REALM_DISABLE_UPDATE_CHECKER environment variable to any value.
* Add support for Int16 and Int64 properties in Swift classes.

### Bugfixes

* Realm change notifications when beginning a write transaction are now sent
  after updating rather than before, to match refresh.
* `-isEqual:` now uses the default `NSObject` implementation unless a primary key
  is specified for an RLMObject. When a primary key is specified, `-isEqual:` calls
  `-isEqualToObject:` and a corresponding implementation for `-hash` is also implemented.

0.84.0 Release notes (2014-08-28)
=============================================================

### API breaking changes

* The timer used to trigger notifications has been removed. Notifications are now
  only triggered by commits made in other threads, and can not currently be triggered
  by changes made by other processes. Interprocess notifications will be re-added in
  a future commit with an improved design.

### Enhancements

* Updating to core library version 0.82.2.
* Add property `deletedFromRealm` to RLMObject to indicate objects which have been deleted.
* Add support for the IN operator in predicates.
* Add support for the BETWEEN operator in link queries.
* Add support for multi-level link queries in predicates (e.g. `foo.bar.baz = 5`).
* Switch to building the SDK from source when using CocoaPods and add a
  Realm.Headers subspec for use in targets that should not link a copy of Realm
  (such as test targets).
* Allow unregistering from change notifications in the change notification
  handler block.
* Significant performance improvements when holding onto large numbers of RLMObjects.
* Realm-Xcode6.xcodeproj now only builds using Xcode6-Beta6.
* Improved performance during RLMArray iteration, especially when mutating
  contained objects.

### Bugfixes

* Fix crashes and assorted bugs when sorting or querying a RLMArray returned
  from a query.
* Notifications are no longer sent when initializing new RLMRealm instances on background
  threads.
* Handle object cycles in -[RLMObject description] and -[RLMArray description].
* Lowered the deployment target for the Xcode 6 projects and Swift examples to
  iOS 7.0, as they didn't actually require 8.0.
* Support setting model properties starting with the letter 'z'
* Fixed crashes that could result from switching between Debug and Relase
  builds of Realm.

0.83.0 Release notes (2014-08-13)
=============================================================

### API breaking changes

* Realm-Xcode6.xcodeproj now only builds using Xcode6-Beta5.
* Properties to be persisted in Swift classes must be explicitly declared as `dynamic`.
* Subclasses of RLMObject subclasses now throw an exception on startup, rather
  than when added to a Realm.

### Enhancements

* Add support for querying for nil object properties.
* Improve error message when specifying invalid literals when creating or
  initializing RLMObjects.
* Throw an exception when an RLMObject is used from the incorrect thread rather
  than crashing in confusing ways.
* Speed up RLMRealm instantiation and array property iteration.
* Allow array and objection relation properties to be missing or null when
  creating a RLMObject from a NSDictionary.

### Bugfixes

* Fixed a memory leak when querying for objects.
* Fixed initializing array properties on standalone Swift RLMObject subclasses.
* Fix for queries on 64bit integers.

0.82.0 Release notes (2014-08-05)
=============================================================

### API breaking changes

* Realm-Xcode6.xcodeproj now only builds using Xcode6-Beta4.

### Enhancements

* Updating to core library version 0.80.5.
* Now support disabling the `autorefresh` property on RLMRealm instances.
* Building Realm-Xcode6 for iOS now builds a universal framework for Simulator & Device.
* Using NSNumber properties (unsupported) now throws a more informative exception.
* Added `[RLMRealm defaultRealmPath]`
* Proper implementation for [RLMArray indexOfObjectWhere:]
* The default Realm path on OS X is now ~/Library/Application Support/[bundle
  identifier]/default.realm rather than ~/Documents
* We now check that the correct framework (ios or osx) is used at compile time.

### Bugfixes

* Fixed rapid growth of the realm file size.
* Fixed a bug which could cause a crash during RLMArray destruction after a query.
* Fixed bug related to querying on float properties: `floatProperty = 1.7` now works.
* Fixed potential bug related to the handling of array properties (RLMArray).
* Fixed bug where array properties accessed the wrong property.
* Fixed bug that prevented objects with custom getters to be added to a Realm.
* Fixed a bug where initializing a standalone object with an array literal would
  trigger an exception.
* Clarified exception messages when using unsupported NSPredicate operators.
* Clarified exception messages when using unsupported property types on RLMObject subclasses.
* Fixed a memory leak when breaking out of a for-in loop on RLMArray.
* Fixed a memory leak when removing objects from a RLMArray property.
* Fixed a memory leak when querying for objects.


0.81.0 Release notes (2014-07-22)
=============================================================

### API breaking changes

* None.

### Enhancements

* Updating to core library version 0.80.3.
* Added support for basic querying of RLMObject and RLMArray properties (one-to-one and one-to-many relationships).
  e.g. `[Person objectsWhere:@"dog.name == 'Alfonso'"]` or `[Person objectsWhere:@"ANY dogs.name == 'Alfonso'"]`
  Supports all normal operators for numeric and date types. Does not support NSData properties or `BEGINSWITH`, `ENDSWITH`, `CONTAINS`
  and other options for string properties.
* Added support for querying for object equality in RLMObject and RLMArray properties (one-to-one and one-to-many relationships).
  e.g. `[Person objectsWhere:@"dog == %@", myDog]` `[Person objectsWhere:@"ANY dogs == %@", myDog]` `[Person objectsWhere:@"ANY friends.dog == %@", dog]`
  Only supports comparing objects for equality (i.e. ==)
* Added a helper method to RLMRealm to perform a block inside a transaction.
* OSX framework now supported in CocoaPods.

### Bugfixes

* Fixed Unicode support in property names and string contents (Chinese, Russian, etc.). Closing #612 and #604.
* Fixed bugs related to migration when properties are removed.
* Fixed keyed subscripting for standalone RLMObjects.
* Fixed bug related to double clicking on a .realm file to launch the Realm Browser (thanks to Dean Moore).


0.80.0 Release notes (2014-07-15)
=============================================================

### API breaking changes

* Rename migration methods to -migrateDefaultRealmWithBlock: and -migrateRealmAtPath:withBlock:
* Moved Realm specific query methods from RLMRealm to class methods on RLMObject (-allObjects: to +allObjectsInRealm: ect.)

### Enhancements

* Added +createInDefaultRealmWithObject: method to RLMObject.
* Added support for array and object literals when calling -createWithObject: and -initWithObject: variants.
* Added method -deleteObjects: to batch delete objects from a Realm
* Support for defining RLMObject models entirely in Swift (experimental, see known issues).
* RLMArrays in Swift support Sequence-style enumeration (for obj in array).
* Implemented -indexOfObject: for RLMArray

### Known Issues for Swift-defined models

* Properties other than String, NSData and NSDate require a default value in the model. This can be an empty (but typed) array for array properties.
* The previous caveat also implies that not all models defined in Objective-C can be used for object properties. Only Objective-C models with only implicit (i.e. primitives) or explicit default values can be used. However, any Objective-C model object can be used in a Swift array property.
* Array property accessors don't work until its parent object has been added to a realm.
* Realm-Bridging-Header.h is temporarily exposed as a public header. This is temporary and will be private again once rdar://17633863 is fixed.
* Does not leverage Swift generics and still uses RLM-prefix everywhere. This is coming in #549.


0.22.0 Release notes
=============================================================

### API breaking changes

* Rename schemaForObject: to schemaForClassName: on RLMSchema
* Removed -objects:where: and -objects:orderedBy:where: from RLMRealm
* Removed -indexOfObjectWhere:, -objectsWhere: and -objectsOrderedBy:where: from RLMArray
* Removed +objectsWhere: and +objectsOrderedBy:where: from RLMObject

### Enhancements

* New Xcode 6 project for experimental swift support.
* New Realm Editor app for reading and editing Realm db files.
* Added support for migrations.
* Added support for RLMArray properties on objects.
* Added support for creating in-memory default Realm.
* Added -objectsWithClassName:predicateFormat: and -objectsWithClassName:predicate: to RLMRealm
* Added -indexOfObjectWithPredicateFormat:, -indexOfObjectWithPredicate:, -objectsWithPredicateFormat:, -objectsWithPredi
* Added +objectsWithPredicateFormat: and +objectsWithPredicate: to RLMObject
* Now allows predicates comparing two object properties of the same type.


0.20.0 Release notes (2014-05-28)
=============================================================

Completely rewritten to be much more object oriented.

### API breaking changes

* Everything

### Enhancements

* None.

### Bugfixes

* None.


0.11.0 Release notes (not released)
=============================================================

The Objective-C API has been updated and your code will break!

### API breaking changes

* `RLMTable` objects can only be created with an `RLMRealm` object.
* Renamed `RLMContext` to `RLMTransactionManager`
* Renamed `RLMContextDidChangeNotification` to `RLMRealmDidChangeNotification`
* Renamed `contextWithDefaultPersistence` to `managerForDefaultRealm`
* Renamed `contextPersistedAtPath:` to `managerForRealmWithPath:`
* Renamed `realmWithDefaultPersistence` to `defaultRealm`
* Renamed `realmWithDefaultPersistenceAndInitBlock` to `defaultRealmWithInitBlock`
* Renamed `find:` to `firstWhere:`
* Renamed `where:` to `allWhere:`
* Renamed `where:orderBy:` to `allWhere:orderBy:`

### Enhancements

* Added `countWhere:` on `RLMTable`
* Added `sumOfColumn:where:` on `RLMTable`
* Added `averageOfColumn:where:` on `RLMTable`
* Added `minOfProperty:where:` on `RLMTable`
* Added `maxOfProperty:where:` on `RLMTable`
* Added `toJSONString` on `RLMRealm`, `RLMTable` and `RLMView`
* Added support for `NOT` operator in predicates
* Added support for default values
* Added validation support in `createInRealm:withObject:`

### Bugfixes

* None.


0.10.0 Release notes (2014-04-23)
=============================================================

TightDB is now Realm! The Objective-C API has been updated
and your code will break!

### API breaking changes

* All references to TightDB have been changed to Realm.
* All prefixes changed from `TDB` to `RLM`.
* `TDBTransaction` and `TDBSmartContext` have merged into `RLMRealm`.
* Write transactions now take an optional rollback parameter (rather than needing to return a boolean).
* `addColumnWithName:` and variant methods now return the index of the newly created column if successful, `NSNotFound` otherwise.

### Enhancements

* `createTableWithName:columns:` has been added to `RLMRealm`.
* Added keyed subscripting for RLMTable's first column if column is of type RLMPropertyTypeString.
* `setRow:atIndex:` has been added to `RLMTable`.
* `RLMRealm` constructors now have variants that take an writable initialization block
* New object interface - tables created/retrieved using `tableWithName:objectClass:` return custom objects

### Bugfixes

* None.


0.6.0 Release notes (2014-04-11)
=============================================================

### API breaking changes

* `contextWithPersistenceToFile:error:` renamed to `contextPersistedAtPath:error:` in `TDBContext`
* `readWithBlock:` renamed to `readUsingBlock:` in `TDBContext`
* `writeWithBlock:error:` renamed to `writeUsingBlock:error:` in `TDBContext`
* `readTable:withBlock:` renamed to `readTable:usingBlock:` in `TDBContext`
* `writeTable:withBlock:error:` renamed to `writeTable:usingBlock:error:` in `TDBContext`
* `findFirstRow` renamed to `indexOfFirstMatchingRow` on `TDBQuery`.
* `findFirstRowFromIndex:` renamed to `indexOfFirstMatchingRowFromIndex:` on `TDBQuery`.
* Return `NSNotFound` instead of -1 when appropriate.
* Renamed `castClass` to `castToTytpedTableClass` on `TDBTable`.
* `removeAllRows`, `removeRowAtIndex`, `removeLastRow`, `addRow` and `insertRow` methods
  on table now return void instead of BOOL.

### Enhancements
* A `TDBTable` can now be queried using `where:` and `where:orderBy:` taking
  `NSPredicate` and `NSSortDescriptor` as arguments.
* Added `find:` method on `TDBTable` to find first row matching predicate.
* `contextWithDefaultPersistence` class method added to `TDBContext`. Will create a context persisted
  to a file in app/documents folder.
* `renameColumnWithIndex:to:` has been added to `TDBTable`.
* `distinctValuesInColumnWithIndex` has been added to `TDBTable`.
* `dateIsBetween::`, `doubleIsBetween::`, `floatIsBetween::` and `intIsBetween::`
  have been added to `TDBQuery`.
* Column names in Typed Tables can begin with non-capital letters too. The generated `addX`
  selector can look odd. For example, a table with one column with name `age`,
  appending a new row will look like `[table addage:7]`.
* Mixed typed values are better validated when rows are added, inserted,
  or modified as object literals.
* `addRow`, `insertRow`, and row updates can be done using objects
   derived from `NSObject`.
* `where` has been added to `TDBView`and `TDBViewProtocol`.
* Adding support for "smart" contexts (`TDBSmartContext`).

### Bugfixes

* Modifications of a `TDBView` and `TDBQuery` now throw an exception in a readtransaction.


0.5.0 Release notes (2014-04-02)
=============================================================

The Objective-C API has been updated and your code will break!
Of notable changes a fast interface has been added.
This interface includes specific methods to get and set values into Tightdb.
To use these methods import `<Tightdb/TightdbFast.h>`.

### API breaking changes

* `getTableWithName:` renamed to `tableWithName:` in `TDBTransaction`.
* `addColumnWithName:andType:` renamed to `addColumnWithName:type:` in `TDBTable`.
* `columnTypeOfColumn:` renamed to `columnTypeOfColumnWithIndex` in `TDBTable`.
* `columnNameOfColumn:` renamed to `nameOfColumnWithIndex:` in `TDBTable`.
* `addColumnWithName:andType:` renamed to `addColumnWithName:type:` in `TDBDescriptor`.
* Fast getters and setters moved from `TDBRow.h` to `TDBRowFast.h`.

### Enhancements

* Added `minDateInColumnWithIndex` and `maxDateInColumnWithIndex` to `TDBQuery`.
* Transactions can now be started directly on named tables.
* You can create dynamic tables with initial schema.
* `TDBTable` and `TDBView` now have a shared protocol so they can easier be used interchangeably.

### Bugfixes

* Fixed bug in 64 bit iOS when inserting BOOL as NSNumber.


0.4.0 Release notes (2014-03-26)
=============================================================

### API breaking changes

* Typed interface Cursor has now been renamed to Row.
* TDBGroup has been renamed to TDBTransaction.
* Header files are renamed so names match class names.
* Underscore (_) removed from generated typed table classes.
* TDBBinary has been removed; use NSData instead.
* Underscope (_) removed from generated typed table classes.
* Constructor for TDBContext has been renamed to contextWithPersistenceToFile:
* Table findFirstRow and min/max/sum/avg operations has been hidden.
* Table.appendRow has been renamed to addRow.
* getOrCreateTable on Transaction has been removed.
* set*:inColumnWithIndex:atRowIndex: methods have been prefixed with TDB
* *:inColumnWithIndex:atRowIndex: methods have been prefixed with TDB
* addEmptyRow on table has been removed. Use [table addRow:nil] instead.
* TDBMixed removed. Use id and NSObject instead.
* insertEmptyRow has been removed from table. Use insertRow:nil atIndex:index instead.

#### Enhancements

* Added firstRow, lastRow selectors on view.
* firstRow and lastRow on table now return nil if table is empty.
* getTableWithName selector added on group.
* getting and creating table methods on group no longer take error argument.
* [TDBQuery parent] and [TDBQuery subtable:] selectors now return self.
* createTable method added on Transaction. Throws exception if table with same name already exists.
* Experimental support for pinning transactions on Context.
* TDBView now has support for object subscripting.

### Bugfixes

* None.


0.3.0 Release notes (2014-03-14)
=============================================================

The Objective-C API has been updated and your code will break!

### API breaking changes

* Most selectors have been renamed in the binding!
* Prepend TDB-prefix on all classes and types.

### Enhancements

* Return types and parameters changed from size_t to NSUInteger.
* Adding setObject to TightdbTable (t[2] = @[@1, @"Hello"] is possible).
* Adding insertRow to TightdbTable.
* Extending appendRow to accept NSDictionary.

### Bugfixes

* None.


0.2.0 Release notes (2014-03-07)
=============================================================

The Objective-C API has been updated and your code will break!

### API breaking changes

* addRow renamed to addEmptyRow

### Enhancements

* Adding a simple class for version numbering.
* Adding get-version and set-version targets to build.sh.
* tableview now supports sort on column with column type bool, date and int
* tableview has method for checking the column type of a specified column
* tableview has method for getting the number of columns
* Adding methods getVersion, getCoreVersion and isAtLeast.
* Adding appendRow to TightdbTable.
* Adding object subscripting.
* Adding method removeColumn on table.

### Bugfixes

* None.
