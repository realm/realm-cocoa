/* @@Example: ex_objc_sharedgroup_intro @@ */
#import <Realm/Realm.h>
#import "people.h"

/*
 The classes People, PeopleQuery, PeopleView, and PeopleRow are declared
 (interfaces are generated) in people.h as

 REALM_TABLE_DEF_3(People,
                   Name,  String,
                   Age,   Int,
                   Hired, Bool)

 and in people.m you must have

 REALM_TABLE_IMPL_3(People,
                    Name, String,
                    Age,  Int,
                    Hired, Bool)

 in order to generate the implementation of the classes.
 */


void ex_objc_transaction_manager_intro()
{

    // Remove previous datafile
    [[NSFileManager defaultManager] removeItemAtPath:@"transactionManagerTest.realm" error:nil];

    // Create datafile with a new table
    RLMTransactionManager *manager = [RLMTransactionManager managerForRealmWithPath:@"transactionManagerTest.realm"
                                                                      error:nil];
    // Perform a write transaction (with commit to file)
    [manager writeUsingBlock:^(RLMRealm *realm) {
        PeopleTable *table = [realm tableWithName:@"employees" asTableClass:[PeopleTable class]];
        [table addRow:@{@"Name":@"Bill", @"Age":@53, @"Hired":@YES}];
    }];

    // Perform a write transaction (with rollback)
    [manager writeUsingBlockWithRollback:^(RLMRealm *realm, BOOL *rollback) {
        PeopleTable *table = [realm tableWithName:@"employees" asTableClass:[PeopleTable class]];
        if ([table rowCount] == 0) {
            NSLog(@"Roll back!");
            *rollback = YES;
            return;
        }
        [table addRow:@[@"Mary", @21, @NO]];
    }];

    // Perform a read transaction
    [manager readUsingBlock:^(RLMRealm *realm) {
        PeopleTable *table = [realm tableWithName:@"employees" asTableClass:[PeopleTable class]];
        for (People *row in table) {
            NSLog(@"Name: %@", row.Name);
        }
    }];
}
/* @@EndExample@@ */
