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

import SwiftUI
import RealmSwift

struct AsyncOpenView: View {
    @AsyncOpen(appId: ProcessInfo.processInfo.environment["app_id"]!, partitionValue: #function) var asyncOpen

    var body: some View {
        switch asyncOpen {
        case .notOpen:
            ProgressView()
        case .open(let realm):
            ListView()
                .environment(\.realm, realm)
        case .error(_):
            ErrorView()
        case .progress(let progress):
            ProgressView(progress)
        }
    }
}


struct AutoOpenView: View {
    @AsyncOpen(appId: "", partitionValue: #function) var asyncOpen

    var body: some View {
        switch asyncOpen {
        case .notOpen:
            ProgressView()
        case .open(let realm):
            ListView()
                .environment(\.realm, realm)
        case .error(_):
            ErrorView()
        case .progress(let progress):
            ProgressView(progress)
        }
    }
}

struct ErrorView: View {
    var body: some View {
        Text("Error View")
    }
}

struct ListView: View {
    @ObservedResults(SwiftPerson.self) var persons

    var body: some View {
        List {
            ForEach(persons) { person in
                HStack {
                    VStack {
                        Text("\(person.firstName)")
                        Text("\(person.lastName)")
                    }
                    Spacer()
                    Text("\(person.age)")
                }
            }
        }
        .navigationTitle("SwiftPerson's List")
    }
}
