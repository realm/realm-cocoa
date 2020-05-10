//
//  CRUDProtocols.swift
//  RealmSwift
//
//  Created by Vato Kostava on 5/10/20.
//  Copyright © 2020 Realm. All rights reserved.
//

import Foundation

protocol RealmPersistable {
    func persist(in realm: Realm?)
    static func update(in realm: Realm?, update code: (() -> ()))
}

extension RealmPersistable {
        
    func persist(in realm: Realm? = try? Realm()) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                if let object = self as? Object {
                    realm.add(object)
                }
            }
        } catch {
            print("Error occured during saving")
        }
    }
    
    static func update(in realm: Realm? = try? Realm(), update code: (() -> ())) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                code()
            }
        } catch {
            print("Error during update")
        }
    }
}



protocol RealmFetchable {
    associatedtype Entity: Object
    static func fetchAll(from realm: Realm?) -> [Entity]?
    static func fetchFiltered(from realm: Realm?, with predicate: NSPredicate) -> [Entity]?
}

extension RealmFetchable {
    
    static func fetchAll(from realm: Realm? = try? Realm()) -> [Entity]? {
        guard let realm = realm else { return nil }
        
        let entities = realm.objects(Entity.self)
        return Array(entities)
    }
    
    static func fetchFiltered(from realm: Realm? = try? Realm(), with predicate: NSPredicate) -> [Entity]? {
        guard let realm = realm else { return nil }
        
        let entities = realm.objects(Entity.self).filter(predicate)
        return Array(entities)
    }
    
}


protocol RealmRemovable {
    associatedtype Entity: Object
    static func removeAll(from realm: Realm?)
    static func removeFiltered(with predicate: NSPredicate, from realm: Realm?)
    func remove(from realm: Realm?)
}

extension RealmRemovable {
    
    static func removeAll(from realm: Realm? = try? Realm()) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                let entities = realm.objects(Entity.self)
                realm.delete(entities)
            }
        } catch {
            print("Error during deleting all entities from realm")
        }
    }
    
    static func removeFiltered(with predicate: NSPredicate, from realm: Realm? = try? Realm()) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                let entities = realm.objects(Entity.self).filter(predicate)
                realm.delete(entities)
            }
        } catch {
            print("Error during deleting filtered entities from realm")
        }
    }
    
    func remove(from realm: Realm? = try? Realm()) {
        guard let realm = realm else { return }
        
        do {
            try realm.write({
                if let object = self as? Object {
                    realm.delete(object)
                }
            })
        } catch {
            print ("Error during deleting object")
        }
    }
}


typealias RealmStorable = RealmPersistable & RealmFetchable & RealmRemovable
