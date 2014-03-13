/*************************************************************************
 *
 * TIGHTDB CONFIDENTIAL
 * __________________
 *
 *  [2011] - [2014] TightDB Inc
 *  All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains
 * the property of TightDB Incorporated and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to TightDB Incorporated
 * and its suppliers and may be covered by U.S. and Foreign Patents,
 * patents in process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from TightDB Incorporated.
 *
 **************************************************************************/

#import <SenTestingKit/SenTestingKit.h>
#import <Foundation/NSException.h>

#import <tightdb/objc/tightdb.h>


@interface TightdbDynamicTableTests: SenTestCase
  // Intentionally left blank.
  // No new public instance methods need be defined.
@end

@implementation TightdbDynamicTableTests

- (void)testTable
{
    TightdbTable* _table = [[TightdbTable alloc] init];
    NSLog(@"Table: %@", _table);
    STAssertNotNil(_table, @"Table is nil");

    // 1. Add two columns
    [_table addColumnWithName:@"first" andType:tightdb_Int];
    [_table addColumnWithName:@"second" andType:tightdb_Int];

    // Verify
    STAssertEquals(tightdb_Int, [_table columnTypeOfColumn:0], @"First column not int");
    STAssertEquals(tightdb_Int, [_table columnTypeOfColumn:1], @"Second column not int");
    if (![[_table columnNameOfColumn:0] isEqualToString:@"first"])
        STFail(@"First not equal to first");
    if (![[_table columnNameOfColumn:1] isEqualToString:@"second"])
        STFail(@"Second not equal to second");

    // 2. Add a row with data

    //const size_t ndx = [_table addEmptyRow];
    //[_table set:0 ndx:ndx value:0];
    //[_table set:1 ndx:ndx value:10];

    TightdbCursor* cursor = [_table addEmptyRow];
    size_t ndx = [cursor TDBIndex];
    [cursor setInt:0 inColumnWithIndex:0];
    [cursor setInt:10 inColumnWithIndex:1];

    // Verify
    if ([_table intInColumnWithIndex:0 atRowIndex:ndx] != 0)
        STFail(@"First not zero");
    if ([_table intInColumnWithIndex:1 atRowIndex:ndx] != 10)
        STFail(@"Second not 10");
}

-(void)testAddColumn
{
    TightdbTable *t = [[TightdbTable alloc] init];
    NSUInteger stringColIndex = [t addColumnWithName:@"stringCol" andType:tightdb_String];
    TightdbCursor *row = [t addEmptyRow];
    [row setString:@"val" inColumnWithIndex:stringColIndex];
    
    
}

-(void)testAppendRowsIntColumn
{
    // Add row using object literate
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    STAssertTrue([t appendRow:@[ @1 ]], @"Impossible!");
    STAssertEquals((size_t)1, [t rowCount], @"Expected 1 row");
    STAssertTrue([t appendRow:@[ @2 ]], @"Impossible!");
    STAssertEquals((size_t)2, [t rowCount], @"Expected 2 rows");
    STAssertEquals((int64_t)1, [t intInColumnWithIndex:0 atRowIndex:0], @"Value 1 expected");
    STAssertEquals((int64_t)2, [t intInColumnWithIndex:0 atRowIndex:1], @"Value 2 expected");
    STAssertFalse([t appendRow:@[@"Hello"]], @"Wrong type");
    if ([t appendRow:@[@1, @"Hello"]])
        STFail(@"Wrong number of columns");
}

-(void)testInsertRowsIntColumn
{
    // Add row using object literate
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    STAssertTrue([t insertRow:@[ @1 ] atRowIndex:0], @"Impossible!");
    STAssertEquals((size_t)1, [t rowCount], @"Expected 1 row");
    STAssertTrue([t insertRow:@[ @2 ] atRowIndex:0], @"Impossible!");
    STAssertEquals((size_t)2, [t rowCount], @"Expected 2 rows");
    STAssertEquals((int64_t)1, [t intInColumnWithIndex:0 atRowIndex:1], @"Value 1 expected");
    STAssertEquals((int64_t)2, [t intInColumnWithIndex:0 atRowIndex:0], @"Value 2 expected");
    STAssertFalse([t insertRow:@[@"Hello"] atRowIndex:0], @"Wrong type");
    if ([t insertRow:@[@1, @"Hello"] atRowIndex:0])
        STFail(@"Wrong number of columns");
}

-(void)testUpdateRowIntColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    [t insertRow:@[@1] atRowIndex:0];
    t[0] = @[@2];
    STAssertEquals((int64_t)2, [t intInColumnWithIndex:0 atRowIndex:0], @"Value 2 expected");
}

-(void)testUpdateRowWithLabelsIntColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    [t insertRow:@[@1] atRowIndex:0];
    t[0] = @{@"first": @2};
    STAssertEquals((int64_t)2, [t intInColumnWithIndex:0 atRowIndex:0], @"Value 2 expected");
}


-(void)testAppendRowWithLabelsIntColumn
{
    // Add row using object literate
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    
    STAssertTrue([t appendRow:@{ @"first": @1 }], @"Impossible!");
    STAssertEquals((size_t)1, [t rowCount], @"Expected 1 row");

    STAssertTrue([t appendRow:@{ @"first": @2 }], @"Impossible!");
    STAssertEquals((size_t)2, [t rowCount], @"Expected 2 rows");

    STAssertEquals((int64_t)1, [t intInColumnWithIndex:0 atRowIndex:0], @"Value 1 expected");
    STAssertEquals((int64_t)2, [t intInColumnWithIndex:0 atRowIndex:1], @"Value 2 expected");

    STAssertFalse([t appendRow:@{ @"first": @"Hello" }], @"Wrong type");
    STAssertEquals((size_t)2, [t rowCount], @"Expected 2 rows");

    STAssertTrue(([t appendRow:@{ @"first": @1, @"second": @"Hello" }]), @"dh");
    STAssertEquals((size_t)3, [t rowCount], @"Expected 3 rows");

    STAssertTrue(([t appendRow:@{ @"second": @1 }]), @"This is impossible");
    STAssertEquals((size_t)4, [t rowCount], @"Expected 4 rows");

    STAssertEquals((int64_t)0, [t intInColumnWithIndex:0 atRowIndex:3], @"Value 0 expected");
}

-(void)testInsertRowWithLabelsIntColumn
{
    // Add row using object literate
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    
    STAssertTrue(([t insertRow:@{ @"first": @1 } atRowIndex:0]), @"Impossible!");
    STAssertEquals((size_t)1, [t rowCount], @"Expected 1 row");
    
    STAssertTrue(([t insertRow:@{ @"first": @2 } atRowIndex:0]), @"Impossible!");
    STAssertEquals((size_t)2, [t rowCount], @"Expected 2 rows");
    
    STAssertEquals((int64_t)1, ([t intInColumnWithIndex:0 atRowIndex:1]), @"Value 1 expected");
    STAssertEquals((int64_t)2, ([t intInColumnWithIndex:0 atRowIndex:0]), @"Value 2 expected");
    
    STAssertFalse(([t insertRow:@{ @"first": @"Hello" } atRowIndex:0]), @"Wrong type");
    STAssertEquals((size_t)2, ([t rowCount]), @"Expected 2 rows");
    
    STAssertTrue(([t insertRow:@{ @"first": @3, @"second": @"Hello"} atRowIndex:0]), @"Has 'first'");
    STAssertEquals((size_t)3, [t rowCount], @"Expected 3 rows");
    
    STAssertTrue(([t insertRow:@{ @"second": @4 } atRowIndex:0]), @"This is impossible");
    STAssertEquals((size_t)4, [t rowCount], @"Expected 4 rows");
    STAssertTrue((int64_t)0 == ([t intInColumnWithIndex:0 atRowIndex:0]), @"Value 0 expected");
}


-(void)testAppendRowsIntStringColumns
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    [t addColumnWithName:@"second" andType:tightdb_String];

    STAssertTrue(([t appendRow:@[@1, @"Hello"]]), @"appendRow 1");
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
    STAssertEquals((int64_t)1, ([t intInColumnWithIndex:0 atRowIndex:0]), @"Value 1 expected");
    STAssertTrue(([[t stringInColumnWithIndex:1 atRowIndex:0] isEqualToString:@"Hello"]), @"Value 'Hello' expected");
    STAssertFalse(([t appendRow:@[@1, @2]]), @"appendRow 2");
}


-(void)testAppendRowWithLabelsIntStringColumns
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    [t addColumnWithName:@"second" andType:tightdb_String];
    STAssertTrue(([t appendRow:@{@"first": @1, @"second": @"Hello"}]), @"appendRowWithLabels 1");
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
    STAssertEquals((int64_t)1, ([t intInColumnWithIndex:0 atRowIndex:0]), @"Value 1 expected");
    STAssertTrue(([[t stringInColumnWithIndex:1 atRowIndex:0] isEqualToString:@"Hello"]), @"Value 'Hello' expected");
    STAssertFalse(([t appendRow:@{@"first": @1, @"second": @2}]), @"appendRowWithLabels 2");
}


-(void)testAppendRowsDoubleColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Double];
    STAssertTrue(([t appendRow:@[@3.14]]), @"Cannot insert 'double'");  /* double is default */
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
}

-(void)testAppendRowWithLabelsDoubleColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Double];
    STAssertTrue(([t appendRow:@{@"first": @3.14}]), @"Cannot insert 'double'");   /* double is default */
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
}

-(void)testAppendRowsFloatColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Float];
    STAssertTrue(([t appendRow:@[@3.14F]]), @"Cannot insert 'float'"); /* F == float */
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
}

-(void)testAppendRowWithLabelsFloatColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Float];
    STAssertTrue(([t appendRow:@{@"first": @3.14F}]), @"Cannot insert 'float'");   /* F == float */
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
}

-(void)testAppendRowsDateColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Date];
    STAssertTrue(([t appendRow:@[@1000000000]]), @"Cannot insert 'time_t'"); /* 2001-09-09 01:46:40 */
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");

    NSDate *d = [[NSDate alloc] initWithString:@"2001-09-09 01:46:40 +0000"];
    STAssertTrue(([t appendRow:@[d]]), @"Cannot insert 'NSDate'");
    STAssertEquals((size_t)2, ([t rowCount]), @"2 rows excepted");
}

-(void)testAppendRowWithLabelsDateColumn
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Date];

    STAssertTrue(([t appendRow:@{@"first": @1000000000}]), @"Cannot insert 'time_t'");   /* 2001-09-09 01:46:40 */
    STAssertEquals((size_t)1, ([t rowCount]), @"1 row expected");
    
    NSDate *d = [[NSDate alloc] initWithString:@"2001-09-09 01:46:40 +0000"];
    STAssertTrue(([t appendRow:@{@"first": d}]), @"Cannot insert 'NSDate'");
    STAssertEquals((size_t)2, ([t rowCount]), @"2 rows excepted");
}

-(void)testAppendRowsBinaryColumn
{
    const char bin[4] = { 0, 1, 2, 3 };
    TightdbBinary* bin2 = [[TightdbBinary alloc] initWithData:bin size:sizeof bin];
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Binary];
    if (![t appendRow:@[bin2]])
        STFail(@"Cannot insert 'binary'");
    if ([t rowCount] != 1)
        STFail(@"1 row expected");
    
    NSData *nsd = [NSData dataWithBytes:(const void *)bin length:4];
    if (![t appendRow:@[nsd]])
        STFail(@"Cannot insert 'NSData'");
    if ([t rowCount] != 2)
        STFail(@"2 rows excepted");
}


-(void)testAppendRowWithLabelsBinaryColumn
{
    const char bin[4] = { 0, 1, 2, 3 };
    TightdbBinary* bin2 = [[TightdbBinary alloc] initWithData:bin size:sizeof bin];
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Binary];

    if (![t appendRow:@{@"first": bin2}])
        STFail(@"Cannot insert 'binary'");
    if ([t rowCount] != 1)
        STFail(@"1 row expected");

    NSData *nsd = [NSData dataWithBytes:(const void *)bin length:4];
    if (![t appendRow:@{@"first": nsd}])
        STFail(@"Cannot insert 'NSData'");
    if ([t rowCount] != 2)
        STFail(@"2 rows excepted");
}

-(void)testAppendRowsTooManyItems
{
    TightdbTable *t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    STAssertFalse(([t appendRow:@[@1, @1]]), @"Too many items for a row.");
}

-(void)testAppendRowsTooFewItems
{
    TightdbTable *t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    STAssertFalse(([t appendRow:@[]]), @"Too few items for a row.");
}

-(void)testAppendRowsWrongType
{
    TightdbTable *t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    STAssertFalse(([t appendRow:@[@YES]]), @"Wrong type for column.");
    STAssertFalse(([t appendRow:@[@""]]), @"Wrong type for column.");
    STAssertFalse(([t appendRow:@[@3.5]]), @"Wrong type for column.");
    STAssertFalse(([t appendRow:@[@3.5F]]), @"Wrong type for column.");
    STAssertFalse(([t appendRow:@[@[]]]), @"Wrong type for column.");
}

-(void)testAppendRowsBoolColumn
{
    TightdbTable *t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Bool];
    STAssertTrue(([t appendRow:@[@YES]]), @"Cannot append bool column.");
    STAssertTrue(([t appendRow:@[@NO]]), @"Cannot append bool column.");
    STAssertEquals((size_t)2, [t rowCount], @"2 rows expected");
}

-(void)testAppendRowWithLabelsBoolColumn
{
    TightdbTable *t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Bool];
    STAssertTrue(([t appendRow:@{@"first": @YES}]), @"Cannot append bool column.");
    STAssertTrue(([t appendRow:@{@"first": @NO}]), @"Cannot append bool column.");
    STAssertEquals((size_t)2, [t rowCount], @"2 rows expected");
}

-(void)testAppendRowsIntSubtableColumns
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Int];
    TightdbDescriptor* descr = [t descriptor];
    TightdbDescriptor* subdescr = [descr addColumnTable:@"second"];
    [subdescr addColumnWithName:@"TableCol_IntCol" andType:tightdb_Int];
    if (![t appendRow:@[@1, @[]]])
        STFail(@"1 row excepted");
    if ([t rowCount] != 1)
        STFail(@"1 row expected");
    if (![t appendRow:@[@2, @[@[@3]]]])
        STFail(@"Cannot insert subtable");
    if ([t rowCount] != 2)
        STFail(@"2 rows expected");
}

-(void)testAppendRowsMixedColumns
{
    const char bin[4] = { 0, 1, 2, 3 };
    TightdbBinary* bin2 = [[TightdbBinary alloc] initWithData:bin size:sizeof bin];

    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Mixed];
    if (![t appendRow:@[@1]])
        STFail(@"Cannot insert 'int'");
    if ([t rowCount] != 1)
        STFail(@"1 row excepted");
    if (![t appendRow:@[@"Hello"]])
        STFail(@"Cannot insert 'string'");
    if ([t rowCount] != 2)
        STFail(@"2 rows excepted");
    if (![t appendRow:@[@3.14f]])
        STFail(@"Cannot insert 'float'");
    if ([t rowCount] != 3)
        STFail(@"3 rows excepted");
    if (![t appendRow:@[@3.14]])
        STFail(@"Cannot insert 'double'");
    if ([t rowCount] != 4)
        STFail(@"4 rows excepted");
    if (![t appendRow:@[@YES]])
        STFail(@"Cannot insert 'bool'");
    if ([t rowCount] != 5)
        STFail(@"5 rows excepted");
    if (![t appendRow:@[bin2]])
        STFail(@"Cannot insert 'binary'");
    if ([t rowCount] != 6)
        STFail(@"6 rows excepted");

    TightdbTable* _table10 = [[TightdbTable alloc] init];
    [_table10 addColumnWithName:@"first" andType:tightdb_Bool];
    if (![_table10 appendRow:@[@YES]])
        STFail(@"Cannot insert 'bool'");
    if ([_table10 rowCount] != 1)
        STFail(@"1 row excepted");
}

-(void)testAppendRowWithLabelsMixedColumns
{
    const char bin[4] = { 0, 1, 2, 3 };
    TightdbBinary* bin2 = [[TightdbBinary alloc] initWithData:bin size:sizeof bin];
    
    TightdbTable* t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"first" andType:tightdb_Mixed];
    if (![t appendRow:@{@"first": @1}])
        STFail(@"Cannot insert 'int'");
    if ([t rowCount] != 1)
        STFail(@"1 row excepted");
    if (![t appendRow:@{@"first": @"Hello"}])
        STFail(@"Cannot insert 'string'");
    if ([t rowCount] != 2)
        STFail(@"2 rows excepted");
    if (![t appendRow:@{@"first": @3.14f}])
        STFail(@"Cannot insert 'float'");
    if ([t rowCount] != 3)
        STFail(@"3 rows excepted");
    if (![t appendRow:@{@"first": @3.14}])
        STFail(@"Cannot insert 'double'");
    if ([t rowCount] != 4)
        STFail(@"4 rows excepted");
    if (![t appendRow:@{@"first": @YES}])
        STFail(@"Cannot insert 'bool'");
    if ([t rowCount] != 5)
        STFail(@"5 rows excepted");
    if (![t appendRow:@{@"first": bin2}])
        STFail(@"Cannot insert 'binary'");
    if ([t rowCount] != 6)
        STFail(@"6 rows excepted");
    }

-(void)testRemoveColumns
{
    
    TightdbTable *t = [[TightdbTable alloc] init];
    [t addColumnWithName:@"col0" andType:tightdb_Int];
    STAssertTrue([t columnCount] == 1,@"1 column added" );
    
    [t removeColumnWithIndex:0];
    STAssertTrue([t columnCount] == 0, @"Colum removed");
    
    for (int i=0;i<10;i++) {
        [t addColumnWithName:@"name" andType:tightdb_Int];
    }
    
    STAssertThrows([t removeColumnWithIndex:10], @"Out of bounds");
    STAssertThrows([t removeColumnWithIndex:-1], @"Less than zero colIndex");

    STAssertTrue([t columnCount] == 10, @"10 columns added");

    for (int i=0;i<10;i++) {
        [t removeColumnWithIndex:0];
    }
    
    STAssertTrue([t columnCount] == 0, @"Colums removed");
    
    STAssertThrows([t removeColumnWithIndex:1], @"No columns added");
    STAssertThrows([t removeColumnWithIndex:-1], @"Less than zero colIndex");

    
}

/*
- (void)testColumnlessCount
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertEquals((size_t)0, [t count], @"Columnless table has 0 rows.");     
}

- (void)testColumnlessIsEmpty
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertTrue([t isEmpty], @"Columnless table is empty.");
}

- (void)testColumnlessClear
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t clear];
}

- (void)testColumnlessOptimize
{
    TightdbTable* t = [[TightdbTable alloc] init];
    [t optimize];
}

- (void)testColumnlessIsEqual
{
    TightdbTable* t1 = [[TightdbTable alloc] init];
    TightdbTable* t2 = [[TightdbTable alloc] init];
    STAssertTrue([t1 isEqual:t1], @"Columnless table is equal to itself.");
    STAssertTrue([t1 isEqual:t2], @"Columnless table is equal to another columnless table.");
    STAssertTrue([t2 isEqual:t1], @"Columnless table is equal to another columnless table.");
}

- (void)testColumnlessGetColumnCount
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertEquals((size_t)0, [t getColumnCount], @"Columnless table has column count 0.");
}

- (void)testColumnlessGetColumnName
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t getColumnName:((size_t)-1)],
        NSException, NSRangeException,
        @"Columnless table has no column names.");
    STAssertThrowsSpecific([t getColumnName:((size_t)0)],
        NSException, NSRangeException,
        @"Columnless table has no column names.");
    STAssertThrowsSpecific([t getColumnName:((size_t)1)],
        NSException, NSRangeException,
        @"Columnless table has no column names.");
}

- (void)testColumnlessGetColumnType
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t getColumnType:((size_t)-1)],
        NSException, NSRangeException,
        @"Columnless table has no column types.");
    STAssertThrowsSpecific([t getColumnType:((size_t)0)],
        NSException, NSRangeException,
        @"Columnless table has no column types.");
    STAssertThrowsSpecific([t getColumnType:((size_t)1)],
        NSException, NSRangeException,
        @"Columnless table has no column types.");
}

- (void)testColumnlessCursorAtIndex
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t cursorAtIndex:((size_t)-1)],
        NSException, NSRangeException,
        @"Columnless table has no cursors.");
    STAssertThrowsSpecific([t cursorAtIndex:((size_t)0)],
        NSException, NSRangeException,
        @"Columnless table has no cursors.");
    STAssertThrowsSpecific([t cursorAtIndex:((size_t)1)],
        NSException, NSRangeException,
        @"Columnless table has no cursors.");
}

- (void)testColumnlessCursorAtLastIndex
{
    TightdbTable* t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t cursorAtLastIndex],
        NSException, NSRangeException,
        @"Columnless table has no cursors."); 
}

- (void)testRemoveRowAtIndex
{
    TightdbTable *t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t removeRowAtIndex:((size_t)-1)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
    STAssertThrowsSpecific([t removeRowAtIndex:((size_t)0)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
    STAssertThrowsSpecific([t removeRowAtIndex:((size_t)1)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
}

- (void)testColumnlessRemoveLastRow
{
    TightdbTable *t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t removeLastRow],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
}

- (void)testColumnlessGetTableSize
{
    TightdbTable *t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t getTableSize:((size_t)0) ndx:((size_t)-1)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
    STAssertThrowsSpecific([t getTableSize:((size_t)0) ndx:((size_t)0)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
    STAssertThrowsSpecific([t getTableSize:((size_t)0) ndx:((size_t)1)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
}

- (void)testColumnlessClearSubtable
{
    TightdbTable *t = [[TightdbTable alloc] init];
    STAssertThrowsSpecific([t clearSubtable:((size_t)0) ndx:((size_t)-1)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
    STAssertThrowsSpecific([t clearSubtable:((size_t)0) ndx:((size_t)0)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
    STAssertThrowsSpecific([t clearSubtable:((size_t)0) ndx:((size_t)1)],
        NSException, NSRangeException,
        @"No rows in a columnless table.");
}
*/
- (void)testColumnlessSetIndex
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t setIndex:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t setIndex:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t setIndex:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessHasIndex
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t hasIndex:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t hasIndex:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t hasIndex:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessCountWithIntColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t countWithIntColumn:((size_t)-1) andValue: 0],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithIntColumn:((size_t)0) andValue: 0],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithIntColumn:((size_t)1) andValue: 0],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessCountWithFloatColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t countWithFloatColumn:((size_t)-1) andValue: 0.0f],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithFloatColumn:((size_t)0) andValue: 0.0f],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithFloatColumn:((size_t)1) andValue: 0.0f],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessCountWithDoubleColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t countWithDoubleColumn:((size_t)-1) andValue: 0.0],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithDoubleColumn:((size_t)0) andValue: 0.0],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithDoubleColumn:((size_t)1) andValue: 0.0],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessCountWithStringColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t countWithStringColumn:((size_t)-1) andValue: @""],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithStringColumn:((size_t)0) andValue: @""],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t countWithStringColumn:((size_t)1) andValue: @""],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessSumWithIntColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t sumWithIntColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t sumWithIntColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t sumWithIntColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessSumWithFloatColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t sumWithFloatColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t sumWithFloatColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t sumWithFloatColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessSumWithDoubleColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t sumWithDoubleColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t sumWithDoubleColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t sumWithDoubleColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessMaximumWithIntColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t maximumWithIntColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t maximumWithIntColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t maximumWithIntColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessMaximumWithFloatColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t maximumWithFloatColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t maximumWithFloatColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t maximumWithFloatColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessMaximumWithDoubleColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t maximumWithDoubleColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t maximumWithDoubleColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t maximumWithDoubleColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessMinimumWithIntColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t minimumWithIntColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t minimumWithIntColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t minimumWithIntColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessMinimumWithFloatColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t minimumWithFloatColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t minimumWithFloatColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t minimumWithFloatColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessMinimumWithDoubleColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t minimumWithDoubleColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t minimumWithDoubleColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t minimumWithDoubleColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessAverageWithIntColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t averageWithIntColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t averageWithIntColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t averageWithIntColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessAverageWithFloatColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t averageWithFloatColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t averageWithFloatColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t averageWithFloatColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testColumnlessAverageWithDoubleColumn
{
// SEGFAULT
//    TightdbTable *t = [[TightdbTable alloc] init];
//    STAssertThrowsSpecific([t averageWithDoubleColumn:((size_t)-1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t averageWithDoubleColumn:((size_t)0)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
//    STAssertThrowsSpecific([t averageWithDoubleColumn:((size_t)1)],
//        NSException, NSRangeException,
//        @"No rows in a columnless table.");
}

- (void)testDataTypes_Dynamic
{
    TightdbTable* table = [[TightdbTable alloc] init];
    NSLog(@"Table: %@", table);
    STAssertNotNil(table, @"Table is nil");

    TightdbDescriptor* desc = [table descriptor];

    [desc addColumnWithName:@"BoolCol" andType:tightdb_Bool];    const size_t BoolCol = 0;
    [desc addColumnWithName:@"IntCol" andType:tightdb_Int];     const size_t IntCol = 1;
    [desc addColumnWithName:@"FloatCol" andType:tightdb_Float];   const size_t FloatCol = 2;
    [desc addColumnWithName:@"DoubleCol" andType:tightdb_Double];  const size_t DoubleCol = 3;
    [desc addColumnWithName:@"StringCol" andType:tightdb_String];  const size_t StringCol = 4;
    [desc addColumnWithName:@"BinaryCol" andType:tightdb_Binary];  const size_t BinaryCol = 5;
    [desc addColumnWithName:@"DateCol" andType:tightdb_Date];    const size_t DateCol = 6;
    TightdbDescriptor* subdesc = [desc addColumnTable:@"TableCol"]; const size_t TableCol = 7;
    [desc addColumnWithName:@"MixedCol" andType:tightdb_Mixed];   const size_t MixedCol = 8;

    [subdesc addColumnWithName:@"TableCol_IntCol" andType:tightdb_Int];

    // Verify column types
    STAssertEquals(tightdb_Bool,   [table columnTypeOfColumn:0], @"First column not bool");
    STAssertEquals(tightdb_Int,    [table columnTypeOfColumn:1], @"Second column not int");
    STAssertEquals(tightdb_Float,  [table columnTypeOfColumn:2], @"Third column not float");
    STAssertEquals(tightdb_Double, [table columnTypeOfColumn:3], @"Fourth column not double");
    STAssertEquals(tightdb_String, [table columnTypeOfColumn:4], @"Fifth column not string");
    STAssertEquals(tightdb_Binary, [table columnTypeOfColumn:5], @"Sixth column not binary");
    STAssertEquals(tightdb_Date,   [table columnTypeOfColumn:6], @"Seventh column not date");
    STAssertEquals(tightdb_Table,  [table columnTypeOfColumn:7], @"Eighth column not table");
    STAssertEquals(tightdb_Mixed,  [table columnTypeOfColumn:8], @"Ninth column not mixed");


    const char bin[4] = { 0, 1, 2, 3 };
    TightdbBinary* bin1 = [[TightdbBinary alloc] initWithData:bin size:sizeof bin / 2];
    TightdbBinary* bin2 = [[TightdbBinary alloc] initWithData:bin size:sizeof bin];
    time_t timeNow = [[NSDate date] timeIntervalSince1970];



    TightdbTable* subtab1 = [[TightdbTable alloc] init];
    [subtab1 addColumnWithName:@"TableCol_IntCol" andType:tightdb_Int];

    TightdbTable* subtab2 = [[TightdbTable alloc] init];
    [subtab2 addColumnWithName:@"TableCol_IntCol" andType:tightdb_Int];


    TightdbCursor* cursor;



    cursor = [subtab1 addEmptyRow];
    [cursor setInt:200 inColumnWithIndex:0];



    cursor = [subtab2 addEmptyRow];
    [cursor setInt:100 inColumnWithIndex:0];



    TightdbMixed* mixInt1   = [TightdbMixed mixedWithInt64:1];
    TightdbMixed* mixSubtab = [TightdbMixed mixedWithTable:subtab2];

    TightdbCursor* c;



    c = [table addEmptyRow];



    [c setBool:    NO        inColumnWithIndex:BoolCol];
    [c setInt:     54        inColumnWithIndex:IntCol];
    [c setFloat:   0.7       inColumnWithIndex:FloatCol];
    [c setDouble:  0.8       inColumnWithIndex:DoubleCol];
    [c setString:  @"foo"    inColumnWithIndex:StringCol];
    [c setBinary:  bin1      inColumnWithIndex:BinaryCol];
    [c setDate:    0         inColumnWithIndex:DateCol];
    [c setTable:   subtab1   inColumnWithIndex:TableCol];
    [c setMixed:   mixInt1   inColumnWithIndex:MixedCol];

    c = [table addEmptyRow];

    [c setBool:    YES       inColumnWithIndex:BoolCol];
    [c setInt:     506       inColumnWithIndex:IntCol];
    [c setFloat:   7.7       inColumnWithIndex:FloatCol];
    [c setDouble:  8.8       inColumnWithIndex:DoubleCol];
    [c setString:  @"banach" inColumnWithIndex:StringCol];
    [c setBinary:  bin2      inColumnWithIndex:BinaryCol];
    [c setDate:    timeNow   inColumnWithIndex:DateCol];
    [c setTable:   subtab2   inColumnWithIndex:TableCol];
    [c setMixed:   mixSubtab inColumnWithIndex:MixedCol];

    TightdbCursor* row1 = [table rowAtIndex:0];
    TightdbCursor* row2 = [table rowAtIndex:1];

    STAssertEquals([row1 boolInColumnWithIndex:BoolCol], NO, @"row1.BoolCol");
    STAssertEquals([row2 boolInColumnWithIndex:BoolCol], YES,                @"row2.BoolCol");
    STAssertEquals([row1 intInColumnWithIndex:IntCol], (int64_t)54,         @"row1.IntCol");
    STAssertEquals([row2 intInColumnWithIndex:IntCol], (int64_t)506,        @"row2.IntCol");
    STAssertEquals([row1 floatInColumnWithIndex:FloatCol], 0.7f,              @"row1.FloatCol");
    STAssertEquals([row2 floatInColumnWithIndex:FloatCol], 7.7f,              @"row2.FloatCol");
    STAssertEquals([row1 doubleInColumnWithIndex:DoubleCol], 0.8,              @"row1.DoubleCol");
    STAssertEquals([row2 doubleInColumnWithIndex:DoubleCol], 8.8,              @"row2.DoubleCol");
    STAssertTrue([[row1 stringInColumnWithIndex:StringCol] isEqual:@"foo"],    @"row1.StringCol");
    STAssertTrue([[row2 stringInColumnWithIndex:StringCol] isEqual:@"banach"], @"row2.StringCol");
    STAssertTrue([[row1 binaryInColumnWithIndex:BinaryCol] isEqual:bin1],      @"row1.BinaryCol");
    STAssertTrue([[row2 binaryInColumnWithIndex:BinaryCol] isEqual:bin2],      @"row2.BinaryCol");
    STAssertEquals([row1 dateInColumnWithIndex:DateCol], (time_t)0,          @"row1.DateCol");
    STAssertEquals([row2 dateInColumnWithIndex:DateCol], timeNow,            @"row2.DateCol");
    STAssertTrue([[row1 tableInColumnWithIndex:TableCol] isEqual:subtab1],    @"row1.TableCol");
    STAssertTrue([[row2 tableInColumnWithIndex:TableCol] isEqual:subtab2],    @"row2.TableCol");
    STAssertTrue([[row1 mixedInColumnWithIndex:MixedCol] isEqual:mixInt1],    @"row1.MixedCol");
    STAssertTrue([[row2 mixedInColumnWithIndex:MixedCol] isEqual:mixSubtab],  @"row2.MixedCol");

    STAssertEquals([table minIntInColumnWithIndex:IntCol], (int64_t)54,                 @"IntCol min");
    STAssertEquals([table maxIntInColumnWithIndex:IntCol], (int64_t)506,                @"IntCol max");
    STAssertEquals([table sumIntColumnWithIndex:IntCol], (int64_t)560,                @"IntCol sum");
    STAssertEquals([table avgIntColumnWithIndex:IntCol], 280.0,                       @"IntCol avg");

    STAssertEquals([table minFloatInColumnWithIndex:FloatCol], 0.7f,                      @"FloatCol min");
    STAssertEquals([table maxFloatInColumnWithIndex:FloatCol], 7.7f,                      @"FloatCol max");
    STAssertEquals([table sumFloatColumnWithIndex:FloatCol], (double)0.7f + 7.7f,       @"FloatCol sum");
    STAssertEquals([table avgFloatColumnWithIndex:FloatCol], ((double)0.7f + 7.7f) / 2, @"FloatCol avg");

    STAssertEquals([table minDoubleInColumnWithIndex:DoubleCol], 0.8,                      @"DoubleCol min");
    STAssertEquals([table maxDoubleInColumnWithIndex:DoubleCol], 8.8,                      @"DoubleCol max");
    STAssertEquals([table sumDoubleColumnWithIndex:DoubleCol], 0.8 + 8.8,                @"DoubleCol sum");
    STAssertEquals([table avgDoubleColumnWithIndex:DoubleCol], (0.8 + 8.8) / 2,          @"DoubleCol avg");
}

- (void)testTableDynamic_Subscripting
{
    TightdbTable* _table = [[TightdbTable alloc] init];
    STAssertNotNil(_table, @"Table is nil");

    // 1. Add two columns
    [_table addColumnWithName:@"first" andType:tightdb_Int];
    [_table addColumnWithName:@"second" andType:tightdb_String];

    TightdbCursor* c;

    // Add some rows
    c = [_table addEmptyRow];
    [c setInt: 506 inColumnWithIndex:0];
    [c setString: @"test" inColumnWithIndex:1];

    c = [_table addEmptyRow];
    [c setInt: 4 inColumnWithIndex:0];
    [c setString: @"more test" inColumnWithIndex:1];

    // Get cursor by object subscripting
    c = _table[0];
    STAssertEquals([c intInColumnWithIndex:0], (int64_t)506, @"table[0].first");
    STAssertTrue([[c stringInColumnWithIndex:1] isEqual:@"test"], @"table[0].second");

    // Same but used directly
    STAssertEquals([_table[0] intInColumnWithIndex:0], (int64_t)506, @"table[0].first");
    STAssertTrue([[_table[0] stringInColumnWithIndex:1] isEqual:@"test"], @"table[0].second");
}

- (void)testTableDynamic_Cursor_Subscripting
{
    TightdbTable* _table = [[TightdbTable alloc] init];
    STAssertNotNil(_table, @"Table is nil");

    // 1. Add two columns
    [_table addColumnWithName:@"first" andType:tightdb_Int];
    [_table addColumnWithName:@"second" andType:tightdb_String];

    TightdbCursor* c;

    // Add some rows
    c = [_table addEmptyRow];
    c[0] = @506;
    c[1] = @"test";
    STAssertEquals([_table[0] intInColumnWithIndex:0], (int64_t)506, @"table[0].first");
    STAssertTrue([[_table[0] stringInColumnWithIndex:1] isEqual:@"test"], @"table[0].second");

    c = [_table addEmptyRow];
    c[@"first"]  = @4;
    c[@"second"] = @"more test";

    // Get values from cursor by object subscripting
    c = _table[0];
    STAssertTrue([c[0] isEqual:@506], @"table[0].first");
    STAssertTrue([c[1] isEqual:@"test"], @"table[0].second");

    // Same but used with column name
    STAssertTrue([c[@"first"]  isEqual:@506], @"table[0].first");
    STAssertTrue([c[@"second"] isEqual:@"test"], @"table[0].second");

    // Combine with subscripting for rows
    STAssertTrue([_table[0][0] isEqual:@506], @"table[0].first");
    STAssertTrue([_table[0][1] isEqual:@"test"], @"table[0].second");
    STAssertTrue([_table[0][@"first"] isEqual:@506], @"table[0].first");
    STAssertTrue([_table[0][@"second"] isEqual:@"test"], @"table[0].second");

    STAssertTrue([_table[1][0] isEqual:@4], @"table[1].first");
    STAssertTrue([_table[1][1] isEqual:@"more test"], @"table[1].second");
    STAssertTrue([_table[1][@"first"] isEqual:@4], @"table[1].first");
    STAssertTrue([_table[1][@"second"] isEqual:@"more test"], @"table[1].second");
}

@end
