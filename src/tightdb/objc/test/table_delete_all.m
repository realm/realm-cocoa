//
//  table_delete_all.m
//  TightDB
//

#import <XCTest/XCTest.h>

#import <tightdb/objc/RLMTable.h>
#import <tightdb/objc/RLMDescriptor.h>
#import <tightdb/objc/PrivateTDB.h>

@interface MACTestTableDeleteAll: XCTestCase
@end
@implementation MACTestTableDeleteAll

-(void)testTableDeleteAll
{
    // Create table with all column types
    RLMTable * table = [[RLMTable alloc] init];
    RLMDescriptor * desc = [table descriptor];
    [desc addColumnWithName:@"int" type:RLMTypeInt];
    [desc addColumnWithName:@"bool" type:RLMTypeBool];
    [desc addColumnWithName:@"date" type:RLMTypeDate];
    [desc addColumnWithName:@"string" type:RLMTypeString];
    [desc addColumnWithName:@"string_long" type:RLMTypeString];
    [desc addColumnWithName:@"string_enum" type:RLMTypeString];
    [desc addColumnWithName:@"binary" type:RLMTypeBinary];
    [desc addColumnWithName:@"mixed" type:RLMTypeMixed];
    RLMDescriptor * subdesc = [desc addColumnTable:@"tables"];
    [subdesc addColumnWithName:@"sub_first" type:RLMTypeInt];
    [subdesc addColumnWithName:@"sub_second" type:RLMTypeString];

    // Add some rows
    for (size_t i = 0; i < 15; ++i) {
        [table TDB_insertInt:0 ndx:i value:i];
        [table TDB_insertBool:1 ndx:i value:(i % 2 ? YES : NO)];
        [table TDB_insertDate:2 ndx:i value:[NSDate date]];
        [table TDB_insertString:3 ndx:i value:[NSString stringWithFormat:@"string %zu", i]];
        [table TDB_insertString:4 ndx:i value:@" Very long string.............."];

        switch (i % 3) {
            case 0:
                [table TDB_insertString:5 ndx:i value:@"test1"];
                break;
            case 1:
                [table TDB_insertString:5 ndx:i value:@"test2"];
                break;
            case 2:
                [table TDB_insertString:5 ndx:i value:@"test3"];
                break;
        }

        [table TDB_insertBinary:6 ndx:i data:"binary" size:7];
        switch (i % 3) {
            case 0:
                [table TDB_insertMixed:7 ndx:i value:[NSNumber numberWithBool:NO]];
                break;
            case 1:
                [table TDB_insertMixed:7 ndx:i value:[NSNumber numberWithLongLong:i]];
                break;
            case 2:
                [table TDB_insertMixed:7 ndx:i value:[NSString stringWithUTF8String:"string"]];
                break;
        }
        [table TDB_insertSubtable:8 ndx:i];
        [table TDB_insertDone];

        // Add sub-tables
        if (i == 2) {
            RLMTable * subtable = [table TDB_tableInColumnWithIndex:8 atRowIndex:i];
            [subtable TDB_insertInt:0 ndx:0 value:42];
            [subtable TDB_insertString:1 ndx:0 value:@"meaning"];
            [subtable TDB_insertDone];
        }

    }

    // We also want a ColumnStringEnum
    [table optimize];

    // Test Deletes
    [table removeRowAtIndex:14];
    [table removeRowAtIndex:0];
    [table removeRowAtIndex:5];
    XCTAssertEqual([table rowCount], (size_t)12, @"Size should have been 12");

    // Test Clear
    [table removeAllRows];
    XCTAssertEqual([table rowCount], (size_t)0, @"Size should have been zero");

}

@end
