//
//  shared_group.m
//  TightDB
//
// Demo code for short tutorial using Objective-C interface
//

#import <SenTestingKit/SenTestingKit.h>

#import <tightdb/objc/tightdb.h>
#import <tightdb/objc/group.h>
#import <tightdb/objc/group_shared.h>

TIGHTDB_TABLE_2(SharedTable2,
                Hired, Bool,
                Age,   Int)


@interface MACTestSharedGroup: SenTestCase
@end
@implementation MACTestSharedGroup

- (void)testSharedGroup
{

    // TODO: Update test to include more ASSERTS


    TightdbGroup* group = [TightdbGroup group];
    // Create new table in group
    SharedTable2 *table = [group getTable:@"employees" withClass:[SharedTable2 class] error:nil];
    NSLog(@"Table: %@", table);
    // Add some rows
    [table addHired:YES Age:50];
    [table addHired:YES Age:52];
    [table addHired:YES Age:53];
    [table addHired:YES Age:54];

    NSLog(@"MyTable Size: %lu", [table count]);


    NSFileManager* fm = [NSFileManager defaultManager];

    // Write to disk
    [fm removeItemAtPath:@"employees.tightdb" error:nil];
    [fm removeItemAtPath:@"employees.tightdb.lock" error:nil];
    [group writeToFile:@"employees.tightdb" withError:nil];

    // Read only shared group
    TightdbSharedGroup* fromDisk = [TightdbSharedGroup sharedGroupWithFile:@"employees.tightdb" withError:nil];

    [fromDisk readWithBlock:^(TightdbGroup* group) {
            SharedTable2* diskTable = [group getTable:@"employees" withClass:[SharedTable2 class] error:nil];
            NSLog(@"Disktable size: %zu", [diskTable count]);
            for (size_t i = 0; i < [diskTable count]; i++) {
                SharedTable2_Cursor *cursor = [diskTable cursorAtIndex:i];
                NSLog(@"%zu: %lld", i, [cursor Age]);
                NSLog(@"%zu: %lld", i, cursor.Age);
                NSLog(@"%zu: %i", i, [diskTable getBoolInColumn:0 atRow:i]);
            }
        }];


    [fromDisk writeWithBlock:^(TightdbGroup* group) {
            SharedTable2* diskTable = [group getTable:@"employees" withClass:[SharedTable2 class] error:nil];
            NSLog(@"Disktable size: %zu", [diskTable count]);
            for (size_t i = 0; i < 50; i++) {
                [diskTable addHired:YES Age:i];
            }
            return YES; // Commit
        } withError:nil];


    [fromDisk writeWithBlock:^(TightdbGroup* group) {
            SharedTable2* diskTable = [group getTable:@"employees" withClass:[SharedTable2 class] error:nil];
            NSLog(@"Disktable size: %zu", [diskTable count]);
            for (size_t i = 0; i < 50; i++) {
                [diskTable addHired:YES Age:i];
            }
            return NO; // rollback
        } withError:nil];


    [fromDisk writeWithBlock:^(TightdbGroup* group) {
            SharedTable2* diskTable = [group getTable:@"employees" withClass:[SharedTable2 class] error:nil];
            NSLog(@"Disktable size: %zu", [diskTable count]);
            for (size_t i = 0; i < 50; i++) {
                [diskTable addHired:YES Age:i];
            }
            return YES; // commit
        } withError:nil];

    [fromDisk readWithBlock:^(TightdbGroup* group) {
            SharedTable2* diskTable = [group getTable:@"employees" withClass:[SharedTable2 class] error:nil];
            NSLog(@"Disktable size: %zu", [diskTable count]);
        
        STAssertThrows([diskTable clear], @"Not allowed in readtransaction");

        }];
}

- (void) testReadTransaction
{
    
    NSFileManager* fm = [NSFileManager defaultManager];
    
    // Write to disk
    [fm removeItemAtPath:@"readonlyTest.tightdb" error:nil];
    [fm removeItemAtPath:@"readonlyTest.tightdb.lock" error:nil];
    
    TightdbSharedGroup* fromDisk = [TightdbSharedGroup sharedGroupWithFile:@"readonlyTest.tightdb" withError:nil];
    
    [fromDisk writeWithBlock:^(TightdbGroup *group) {
        TightdbTable *t = [group getTable:@"table" error:nil];
        
        [t addColumnWithType:tightdb_Int andName:@"col0"];
        TightdbCursor *row = [t addEmptyRow];
        [row setInt:10 inColumn:0 ];
         
        return YES;
        
    } withError:nil];
    
    [fromDisk readWithBlock:^(TightdbGroup* group) {
        TightdbTable *t = [group getTable:@"table" error:nil];
       
        TightdbQuery *q = [t where];
        
        TightdbView *v = [q findAll];
        
        // Should not be allowed!
        STAssertThrows([v clear], @"Is in readTransaction");
        
        STAssertTrue([t count] == 1, @"No rows have been removed");
        STAssertTrue([[q count] isEqualToNumber:[NSNumber numberWithInt:1]], @"No rows have been removed");
        STAssertTrue([v count] == 1, @"No rows have been removed");
    }];
}

@end



