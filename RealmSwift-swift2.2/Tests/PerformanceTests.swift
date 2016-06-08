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

import Darwin
import Realm.Private
import RealmSwift
import XCTest

private func createStringObjects(factor: Int) -> Realm {
    let realm = inMemoryRealm(factor.description)
    try! realm.write {
        for _ in 0..<(1000 * factor) {
            realm.create(SwiftStringObject.self, value: ["a"])
            realm.create(SwiftStringObject.self, value: ["b"])
        }
    }
    return realm
}

private var mediumRealm: Realm!
private var largeRealm: Realm!

private let isRunningOnDevice = TARGET_IPHONE_SIMULATOR == 0

private var fsyncPath: String!
private var fsyncFd: Int32 = -1

class SwiftPerformanceTests: TestCase {
    override class func defaultTestSuite() -> XCTestSuite {
#if !DEBUG && os(iOS)
        if isRunningOnDevice {
            return super.defaultTestSuite()
        }
#endif
        return XCTestSuite(name: "SwiftPerformanceTests")
    }

    override class func setUp() {
        super.setUp()
        autoreleasepool {
            mediumRealm = createStringObjects(5)
            largeRealm = createStringObjects(50)
        }

        fsyncPath = RLMRealmPathForFile("fsync")
        let fm = NSFileManager.defaultManager()
        try! fm.createDirectoryAtPath((fsyncPath as NSString).stringByDeletingLastPathComponent,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
        fsyncFd = open(fsyncPath, O_CREAT|O_RDWR, 0644)
        if fsyncFd == -1 {
            fatalError("failed to open fsync file \(fsyncPath): \(errno) \(String.fromCString(strerror(errno)))")
        }
    }

    override class func tearDown() {
        close(fsyncFd)
        unlink(fsyncPath)
        mediumRealm = nil
        largeRealm = nil
        super.tearDown()
    }

    override func resetRealmState() {
        // Do nothing, as we need to keep our in-memory realms around between tests
    }

    override func measureBlock(block: (() -> Void)) {
        inMeasureBlock {
            self.startMeasuring()
            block()
        }
    }

    // Some of the perf tests are significantly slower on the first iteration
    // (sometimes because they're the only one which performs I/O, but there is
    // more slowdown than can be explained by only that), so call the block an
    // extra time and discard the first result. Note that the extra call does
    // need to happen after the call to measureMetrics() (and thus within the
    // wrapper block); it's not clear why.
    func measureBlockDiscardingFirst(block: (() -> Void)) {
        var first = true
        inMeasureBlock {
            if first {
                autoreleasepool {
                    block()
                }
                first = false
            }
            self.startMeasuring()
            block()
        }
    }

    func inMeasureBlock(block: () -> ()) {
        measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            autoreleasepool {
                _ = fcntl(fsyncFd, F_FULLFSYNC)
                _ = block()
            }
        }
    }

    private func copyRealmToTestPath(realm: Realm) -> Realm {
        cleanUpTestDir()
        try! realm.writeCopyToURL(testRealmURL())
        return realmWithTestPath()
    }

    func testInsertMultiple() {
        inMeasureBlock {
            self.cleanUpTestDir()
            let realm = self.realmWithTestPath()
            self.startMeasuring()
            try! realm.write {
                for _ in 0..<5000 {
                    let obj = SwiftStringObject()
                    obj.stringCol = "a"
                    realm.add(obj)
                }
            }
        }
    }

    func testInsertSingleLiteral() {
        inMeasureBlock {
            self.cleanUpTestDir()
            let realm = self.realmWithTestPath()
            self.startMeasuring()
            for _ in 0..<50 {
                try! realm.write {
                    _ = realm.create(SwiftStringObject.self, value: ["a"])
                }
            }
        }
    }

    func testInsertMultipleLiteral() {
        inMeasureBlock {
            self.cleanUpTestDir()
            let realm = self.realmWithTestPath()
            self.startMeasuring()
            try! realm.write {
                for _ in 0..<5000 {
                    realm.create(SwiftStringObject.self, value: ["a"])
                }
            }
        }
    }

    func testCountWhereQuery() {
        let realm = copyRealmToTestPath(largeRealm)
        measureBlockDiscardingFirst {
            for _ in 0..<50 {
                let results = realm.objects(SwiftStringObject).filter("stringCol = 'a'")
                _ = results.count
            }
        }
    }

    func testCountWhereTableView() {
        let realm = copyRealmToTestPath(mediumRealm)
        measureBlockDiscardingFirst {
            for _ in 0..<50 {
                let results = realm.objects(SwiftStringObject).filter("stringCol = 'a'")
                _ = results.first
                _ = results.count
            }
        }
    }

    func testEnumerateAndAccessQuery() {
        let realm = copyRealmToTestPath(largeRealm)
        measureBlockDiscardingFirst {
            for stringObject in realm.objects(SwiftStringObject).filter("stringCol = 'a'") {
                _ = stringObject.stringCol
            }
        }
    }

    func testEnumerateAndAccessAll() {
        let realm = copyRealmToTestPath(largeRealm)
        measureBlockDiscardingFirst {
            for stringObject in realm.objects(SwiftStringObject) {
                _ = stringObject.stringCol
            }
        }
    }

    func testEnumerateAndAccessAllSlow() {
        let realm = copyRealmToTestPath(largeRealm)
        measureBlockDiscardingFirst {
            let results = realm.objects(SwiftStringObject)
            for i in 0..<results.count {
                _ = results[i].stringCol
            }
        }
    }

    func testEnumerateAndAccessArrayProperty() {
        let realm = copyRealmToTestPath(largeRealm)
        realm.beginWrite()
        let arrayPropertyObject = realm.create(SwiftArrayPropertyObject.self,
            value: ["name", realm.objects(SwiftStringObject).map { $0 }, []])
        try! realm.commitWrite()

        measureBlockDiscardingFirst {
            for stringObject in arrayPropertyObject.array {
                _ = stringObject.stringCol
            }
        }
    }

    func testEnumerateAndAccessArrayPropertySlow() {
        let realm = copyRealmToTestPath(largeRealm)
        realm.beginWrite()
        let arrayPropertyObject = realm.create(SwiftArrayPropertyObject.self,
            value: ["name", realm.objects(SwiftStringObject).map { $0 }, []])
        try! realm.commitWrite()

        measureBlockDiscardingFirst {
            let list = arrayPropertyObject.array
            for i in 0..<list.count {
                _ = list[i].stringCol
            }
        }
    }

    func testEnumerateAndMutateAll() {
        inMeasureBlock {
            let realm = self.copyRealmToTestPath(largeRealm)
            self.startMeasuring()
            try! realm.write {
                for stringObject in realm.objects(SwiftStringObject) {
                    stringObject.stringCol = "c"
                }
            }
        }
    }

    func testEnumerateAndMutateQuery() {
        inMeasureBlock {
            let realm = self.copyRealmToTestPath(largeRealm)
            self.startMeasuring()
            try! realm.write {
                for stringObject in realm.objects(SwiftStringObject).filter("stringCol != 'b'") {
                    stringObject.stringCol = "c"
                }
            }
        }
    }

    func testDeleteAll() {
        inMeasureBlock {
            let realm = self.copyRealmToTestPath(largeRealm)
            self.startMeasuring()
            try! realm.write {
                realm.delete(realm.objects(SwiftStringObject))
            }
        }
    }

    func testQueryDeletion() {
        inMeasureBlock {
            let realm = self.copyRealmToTestPath(mediumRealm)
            self.startMeasuring()
            try! realm.write {
                realm.delete(realm.objects(SwiftStringObject).filter("stringCol = 'a' OR stringCol = 'b'"))
            }
        }
    }

    func testManualDeletion() {
        inMeasureBlock {
            let realm = self.copyRealmToTestPath(mediumRealm)
            let objects = realm.objects(SwiftStringObject).map { $0 }
            self.startMeasuring()
            try! realm.write {
                realm.delete(objects)
            }
        }
    }

    func testLargeINQuery() {
        let realm = realmWithTestPath()
        realm.beginWrite()
        var ids = [Int]()
        for i in 0..<10000 {
            realm.create(SwiftIntObject.self, value: [i])
            if i % 2 != 0 {
                ids.append(i)
            }
        }
        try! realm.commitWrite()
        measureBlockDiscardingFirst {
            _ = realm.objects(SwiftIntObject).filter("intCol IN %@", ids).first
        }
    }

    func testSortingAllObjects() {
        let realm = realmWithTestPath()
        try! realm.write {
            for _ in 0..<8000 {
                let randomNumber = Int(arc4random_uniform(UInt32(INT_MAX)))
                realm.create(SwiftIntObject.self, value: [randomNumber])
            }
        }
        measureBlockDiscardingFirst {
            _ = realm.objects(SwiftIntObject).sorted("intCol", ascending: true).last
        }
    }

    func testRealmCreationCached() {
        var realm: Realm!
        dispatchSyncNewThread {
            realm = try! Realm()
        }

        measureBlock {
            for _ in 0..<250 {
                autoreleasepool {
                    _ = try! Realm()
                }
            }
        }
        _ = realm.configuration
    }

    func testRealmCreationUncached() {
        measureBlock {
            for _ in 0..<50 {
                autoreleasepool {
                    _ = try! Realm()
                }
            }
        }
    }

    func testCommitWriteTransaction() {
        inMeasureBlock {
            let realm = inMemoryRealm("test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            try! realm.commitWrite()

            self.startMeasuring()
            while object.intCol < 100 {
                try! realm.write { object.intCol += 1 }
            }
        }
    }

    func testCommitWriteTransactionWithLocalNotification() {
        inMeasureBlock {
            let realm = inMemoryRealm("test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            try! realm.commitWrite()

            let token = realm.addNotificationBlock { _, _ in }
            self.startMeasuring()
            while object.intCol < 100 {
                try! realm.write { object.intCol += 1 }
            }
            self.stopMeasuring()
            token.stop()
        }
    }

    func testCommitWriteTransactionWithCrossThreadNotification() {
        let stopValue = 100
        inMeasureBlock {
            let realm = inMemoryRealm("test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            try! realm.commitWrite()

            let queue = dispatch_queue_create("background", nil)
            let semaphore = dispatch_semaphore_create(0)
            dispatch_async(queue) {
                autoreleasepool {
                    let realm = inMemoryRealm("test")
                    let object = realm.objects(SwiftIntObject).first!
                    var token: NotificationToken! = nil
                    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                        token = realm.addNotificationBlock { _, _ in
                            if object.intCol == stopValue {
                                CFRunLoopStop(CFRunLoopGetCurrent())
                            }
                        }
                        dispatch_semaphore_signal(semaphore)
                    }
                    CFRunLoopRun()
                    token.stop()
                }
            }

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            self.startMeasuring()
            while object.intCol < stopValue {
                try! realm.write { object.intCol += 1 }
            }
            dispatch_sync(queue) {}
        }
    }

    func testCrossThreadSyncLatency() {
        let stopValue = 500
        let queue = dispatch_queue_create("background", nil)
        let semaphore = dispatch_semaphore_create(0)

        inMeasureBlock {
            let realm = inMemoryRealm("test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            try! realm.commitWrite()

            dispatch_async(queue) {
                autoreleasepool {
                    let realm = inMemoryRealm("test")
                    let object = realm.objects(SwiftIntObject).first!
                    var token: NotificationToken! = nil
                    CFRunLoopPerformBlock(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                        token = realm.addNotificationBlock { _, _ in
                            if object.intCol == stopValue {
                                CFRunLoopStop(CFRunLoopGetCurrent())
                            } else if object.intCol % 2 == 0 {
                                try! realm.write { object.intCol += 1 }
                            }
                        }
                        dispatch_semaphore_signal(semaphore)
                    }
                    CFRunLoopRun()
                    token.stop()
                }
            }

            let token = realm.addNotificationBlock { _, _ in
                if object.intCol % 2 == 1 && object.intCol < stopValue {
                    try! realm.write { object.intCol += 1 }
                }
            }

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            _ = fcntl(fsyncFd, F_FULLFSYNC)

            self.startMeasuring()
            try! realm.write { object.intCol += 1 }
            while object.intCol < stopValue {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
            }
            dispatch_sync(queue) {}
            self.stopMeasuring()
            token.stop()
        }
    }
}
