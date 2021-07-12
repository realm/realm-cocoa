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

class Contact: Object, ObjectKeyIdentifiable {
    @Persisted var name: String
    @Persisted var lastName: String
    @Persisted var email: String
    @Persisted var phones: [PhoneNumber]
    @Persisted var birthdate: Date
    @Persisted var notes: String

    var fullName: String {
        return "\(name) \(lastName)"
    }
}

class PhoneNumber: EmbeddedObject, ObjectKeyIdentifiable {
    enum PhoneNumberType: PersistableEnum, String, Identifiable, CaseIterable {
        case home, mobile, work
    }
    @Persisted var type: PhoneNumberType = .home
    @Persisted var phoneNumber: String
}

// You can find your Realm app ID in the Realm UI.
let appId = "realm-async-open"
// The partition determines which subset of data to access, this is configured in the Realm UI too.
let partitionValue = "partition-value"
let app = App(appId: appId)

private enum NavigationType: String {
    case asyncOpen
    case autoOpen
}

// For the purpose of this example, we have to ways of syncing, using @AsyncOpen and @AutoOpen
struct ContentView: View {
    var body: some View {
        VStack {
            Button("@AsyncOpen") {
                LoginView(navigationType: .asyncOpen)
            }
            Spacer()
            Button("@AutoOpen") {
                LoginView(navigationType: .autoOpen)
            }
        }
    }
}

// LoginView, Authenticate User
// When you have enabled anonymous authentication in the Realm UI, users can immediately log into your app without providing any identifying information:
// Documentation of how to login can be found (https://docs.mongodb.com/realm/sdk/ios/quick-start-with-sync/)
struct LoginView: View {
    var navigationType: NavigationType

    @State var username: String = ""
    @State var password: String = ""
    @State var navigationTag: String? = nil

    var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            VStack {
                TextField("Username", text: $username)
                TextField("Username", text: $password)
                Spacer()
                NavigationLink(destination: AsyncOpenView(), tag: "asyncOpen", selection: navigationTag, label: { EmptyView()})
                NavigationLink(destination: AutoOpenView(), tag: "autoOpen", selection: navigationTag, label: { EmptyView()})
                Button("Login") {
                    app.login(credentials: Credentials.emailPassword(email: email, password: password))
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { result in
                            if case .failure(let error) = completion {
                                ErrorView(error: error)
                            }
                        }, receiveValue: { _ in
                            navigationTag = navigationType.rawValue
                        })
                        .store(in: &cancellables)
                }
            }
            .padding()
        }
        .navigationTitle("Logging View")
    }
}

// AsyncOpen is as simple as declaring it on your view and wait a notification from the process
struct AsyncOpenView: View {
    @AsyncOpen(appId: appId, partitionValue: partitionValue, timeout: 2000) var asyncOpen

    var body: some View {
        VStack {
            switch asyncOpen {
            case .notOpen:
                ProgressView()
            case .open(let realm):
                ContactsListView()
                    .environment(\.realm, realm)
            case .error(let error):
                ErrorView(error: error)
            case .progress(let progress):
                ProgressView(progress)
            }
        }
    }
}

// AutoOpen declaration and use is the same as AsyncOpen, but in case of no internet
// connection this will return an opened realm. 
struct AutoOpenView: View {
    @AutoOpen(appId: appId, partitionValue: partitionValue, timeout: 2000) var autoOpen

    var body: some View {
        VStack {
            switch autoOpen {
            case .notOpen:
                ProgressView()
            case .open(let realm):
                ContactsListView()
                    .environment(\.realm, realm)
            case .error:
                ErrorView(error: error)
            case .progress(let progress):
                ProgressView(progress)
            }
        }
    }
}

struct ErrorView: View {
    var error: Error
    var body: some View {
        Alert(title: Text("Error"),
              message: Text("Operation failed with error \(error.localizedDescription)"),
              dismissButton: .default(Text("OK")))
    }
}

struct ContactsListView: View {
    @ObservedResults(Contact.self) var contacts

    var body: some View {
        List {
            ForEach(contacts) { contact in
                NavigationLink(destination: ContactDetailView(contact: contact)) {
                    ContactCellView(contant: contact)
                }
            }
        }
        .navigationBarItems(trailing: HStack {
            Button("add") {
                let contact = Contact()
                contact.name = "New Contact"
                contacts.append(contact)
            }
        })
    }
}

struct ContactCellView: View {
    @ObservedRealmObject var contact: Contact

    var body: some View {
        HStack {
            Text(contact.fullName)
            Spacer()
            Text(contact.phones.first?.phoneNumber ?? "")
        }

    }
}

struct ContactDetailView: View {
    @ObservedRealmObject var contact: Contact

    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $contact.name)
                TextField("Lastname", text: $contact.lastname)
                TextField("Email", text: $contact.email)
                    .keyboardType(.emailAddress)
                DatePicker("Birthday", selection: $contact.birthday, displayedComponents: [.date])
            }
            Section("Phones") {
                ForEach(contact.phones) { phone in
                    HStack {
                        Picker(selection: $phone.type, label: Text("")) {
                            ForEach(PhoneNumber.PhoneNumberType.allCases) { phoneTypes in
                                Text("\(phoneTypes.rawValue)").tag(index)
                            }
                        }
                        TextField("Phone Number", text: $phone.phoneNumber)
                    }
                }
                Button {
                    withAnimation {
                        $contact.phones.append(PhoneNumber())
                    }
                } label: {
                    Label("Add", systemImage: "plus.app")
                }
                .tint(.red)
            }
            Section("Notes") {
                TextField("Notes", text: $contact.notes)
            }
            .navigationTitle("Contact")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
