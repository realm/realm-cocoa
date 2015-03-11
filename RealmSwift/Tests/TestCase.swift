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

import XCTest
import RealmSwift
import Realm
import Foundation

private func realmPathForFile(fileName: String) -> String {
    return Realm.defaultPath.stringByDeletingLastPathComponent.stringByAppendingPathComponent(fileName)
}

private func realmLockPath(path: String) -> String {
    return path + ".lock"
}

private func deleteRealmFilesAtPath(path: String) {
    let fileManager = NSFileManager.defaultManager()
    if fileManager.fileExistsAtPath(path) {
        let succeeded = NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
        assert(succeeded, "Unable to delete realm")
    }

    let lockPath = realmLockPath(path)
    if fileManager.fileExistsAtPath(lockPath) {
        let succeeded = NSFileManager.defaultManager().removeItemAtPath(lockPath, error: nil)
        assert(succeeded, "Unable to delete realm")
    }
}

class TestCase: XCTestCase {
    func realmWithTestPath() -> Realm {
        return Realm(path: testRealmPath())
    }

    override func invokeTest() {
        deleteRealmFiles()

        autoreleasepool {
            Realm.defaultPath = realmPathForFile("\(self.name).default.realm")
            self.setUp()
        }
        autoreleasepool {
            self.invocation.invoke()
            self.tearDown()
        }

        deleteRealmFiles()
    }

    func assertThrows<T>(block: @autoclosure () -> T, _ message: String? = nil, fileName: String = __FILE__, lineNumber: UInt = __LINE__) {
        RLMAssertThrows(self, { _ = block() }, message, fileName, lineNumber);
    }

    private func realmFilePrefix() -> String {
        let remove = NSCharacterSet(charactersInString: "-[]")
        return self.name.stringByTrimmingCharactersInSet(remove)
    }

    private func deleteRealmFiles() {
        RLMRealm.resetRealmState()
        deleteRealmFilesAtPath(Realm.defaultPath)
        deleteRealmFilesAtPath(testRealmPath())
    }

    internal func testRealmPath() -> String {
        return realmPathForFile("\(realmFilePrefix()).realm")
    }
}
