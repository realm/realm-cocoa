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

import UIKit
import RealmSwift

class DemoObject: Object {
    dynamic var title = ""
    dynamic var date = NSDate()
    dynamic var sectionTitle = ""
}

class Cell: UITableViewCell {
    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        super.init(style: .Subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}

var sectionTitles = ["A", "B", "C"]
var objectsBySection = [Results<DemoObject>]()

class TableViewController: UITableViewController {

    var notificationToken: NotificationToken?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()

        // Set realm notification block
        notificationToken = Realm().addNotificationBlock { note, realm in
            self.tableView.reloadData()
        }
        for section in sectionTitles {
            let unsortedObjects = Realm().objects(DemoObject).filter("sectionTitle == '\(section)'")
            let sortedObjects = unsortedObjects.sorted("date", ascending: true)
            objectsBySection.append(sortedObjects)
        }
        tableView.reloadData()
    }

    // UI

    func setupUI() {
        tableView.registerClass(Cell.self, forCellReuseIdentifier: "cell")

        self.title = "GroupedTableView"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "BG Add", style: .Plain, target: self, action: "backgroundAdd")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "add")
    }

    // Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sectionTitles.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }

    override func tableView(tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        return Int(objectsBySection[section].count)
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as Cell

        let object = objectForIndexPath(indexPath)!
        cell.textLabel?.text = object.title
        cell.detailTextLabel?.text = object.date.description

        return cell
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let realm = Realm()
            realm.write {
                realm.delete(objectForIndexPath(indexPath)!)
            }
        }
    }

    // Actions

    func backgroundAdd() {
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        // Import many items in a background thread
        dispatch_async(queue) {
            // Get new realm and table since we are in a new thread
            let realm = Realm()
            realm.beginWrite()
            for index in 0..<5 {
                // Add row via dictionary. Order is ignored.
                realm.create(DemoObject.self, value: ["title": randomTitle(), "date": NSDate(), "sectionTitle": randomSectionTitle()])
            }
            realm.commitWrite()
        }
    }

    func add() {
        Realm().write {
            let object = [randomTitle(), NSDate(), randomSectionTitle()]
            Realm().create(DemoObject.self, value: object)
        }
    }
}

// Helpers

func objectForIndexPath(indexPath: NSIndexPath) -> DemoObject? {
    return objectsBySection[indexPath.section][indexPath.row]
}

func randomTitle() -> String {
    return "Title \(arc4random())"
}

func randomSectionTitle() -> String {
    return sectionTitles[Int(arc4random()) % sectionTitles.count]
}
