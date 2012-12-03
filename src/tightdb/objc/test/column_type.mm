//
//  column_type.mm
//  TightDB
//
// Check that column type enumeration values are in synch with the core library
//

#import <SenTestingKit/SenTestingKit.h>

#import <tightdb/objc/column_type.h>
#import <tightdb/column_type.hpp>

@interface TestColumnType : SenTestCase
@end
@implementation TestColumnType

- (void)testColumnType
{
    STAssertEquals((int)COLUMN_TYPE_BOOL,   (int)tightdb::COLUMN_TYPE_BOOL,   @"Bool");
    STAssertEquals((int)COLUMN_TYPE_INT,    (int)tightdb::COLUMN_TYPE_INT,    @"Int");
    STAssertEquals((int)COLUMN_TYPE_STRING, (int)tightdb::COLUMN_TYPE_STRING, @"String");
    STAssertEquals((int)COLUMN_TYPE_BINARY, (int)tightdb::COLUMN_TYPE_BINARY, @"Binary");
    STAssertEquals((int)COLUMN_TYPE_TABLE,  (int)tightdb::COLUMN_TYPE_TABLE,  @"Table");
    STAssertEquals((int)COLUMN_TYPE_MIXED,  (int)tightdb::COLUMN_TYPE_MIXED,  @"Mixed");
}

@end
