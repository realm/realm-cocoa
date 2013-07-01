/*************************************************************************
 *
 * TIGHTDB CONFIDENTIAL
 * __________________
 *
 *  [2011] - [2012] TightDB Inc
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

#import <tightdb/objc/table.h>
#import <tightdb/objc/query.h>
#import <tightdb/objc/cursor.h>
#import <tightdb/objc/helper_macros.h>


#define TIGHTDB_TABLE_DEF_1(TableName, CName1, CType1) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_1(TableName, CName1, CType1) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_1(TableName, CType1, CName1) \
TIGHTDB_TABLE_DEF_1(TableName, CType1, CName1) \
TIGHTDB_TABLE_IMPL_1(TableName, CType1, CName1)


#define TIGHTDB_TABLE_DEF_2(TableName, CName1, CType1, CName2, CType2) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_2(TableName, CName1, CType1, CName2, CType2) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_2(TableName, CType1, CName1, CType2, CName2) \
TIGHTDB_TABLE_DEF_2(TableName, CType1, CName1, CType2, CName2) \
TIGHTDB_TABLE_IMPL_2(TableName, CType1, CName1, CType2, CName2)


#define TIGHTDB_TABLE_DEF_3(TableName, CName1, CType1, CName2, CType2, CName3, CType3) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_3(TableName, CName1, CType1, CName2, CType2, CName3, CType3) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_3(TableName, CType1, CName1, CType2, CName2, CType3, CName3) \
TIGHTDB_TABLE_DEF_3(TableName, CType1, CName1, CType2, CName2, CType3, CName3) \
TIGHTDB_TABLE_IMPL_3(TableName, CType1, CName1, CType2, CName2, CType3, CName3)


#define TIGHTDB_TABLE_DEF_4(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_4(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_4(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4) \
TIGHTDB_TABLE_DEF_4(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4) \
TIGHTDB_TABLE_IMPL_4(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4)


#define TIGHTDB_TABLE_DEF_5(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_5(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_5(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5) \
TIGHTDB_TABLE_DEF_5(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5) \
TIGHTDB_TABLE_IMPL_5(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5)


#define TIGHTDB_TABLE_DEF_6(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_6(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_6(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6) \
TIGHTDB_TABLE_DEF_6(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6) \
TIGHTDB_TABLE_IMPL_6(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6)


#define TIGHTDB_TABLE_DEF_7(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_7(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_7(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7) \
TIGHTDB_TABLE_DEF_7(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7) \
TIGHTDB_TABLE_IMPL_7(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7)


#define TIGHTDB_TABLE_DEF_8(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_8(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_8(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8) \
TIGHTDB_TABLE_DEF_8(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8) \
TIGHTDB_TABLE_IMPL_8(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8)


#define TIGHTDB_TABLE_DEF_9(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_9(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_9(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9) \
TIGHTDB_TABLE_DEF_9(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9) \
TIGHTDB_TABLE_IMPL_9(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9)


#define TIGHTDB_TABLE_DEF_10(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName10, CType10) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName10, CType10) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName10 *CName10; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_DEF(CName10, CType10) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_10(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
    TightdbAccessor *_##CName10; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
        _##CName10 = [[TightdbAccessor alloc] initWithCursor:self columnId:9]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName10, CType10) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
@synthesize CName10 = _CName10; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
        _CName10 = [[TableName##_QueryAccessor_##CName10 alloc] initWithColumn:9 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName10, CType10) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_IMPL(CName10, CType10) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 9, ndx, CName10, CType10, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    TIGHTDB_COLUMN_INSERT(self, 9, ndx, CName10, CType10); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 9, CName10, CType10) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    TIGHTDB_ADD_COLUMN(spec, CName10, CType10) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_10(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10) \
TIGHTDB_TABLE_DEF_10(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10) \
TIGHTDB_TABLE_IMPL_10(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10)


#define TIGHTDB_TABLE_DEF_11(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName11, CType11) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName11, CType11) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName10 *CName10; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName11 *CName11; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_DEF(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_DEF(CName11, CType11) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_11(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
    TightdbAccessor *_##CName10; \
    TightdbAccessor *_##CName11; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
        _##CName10 = [[TightdbAccessor alloc] initWithCursor:self columnId:9]; \
        _##CName11 = [[TightdbAccessor alloc] initWithCursor:self columnId:10]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName11, CType11) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
@synthesize CName10 = _CName10; \
@synthesize CName11 = _CName11; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
        _CName10 = [[TableName##_QueryAccessor_##CName10 alloc] initWithColumn:9 query:self]; \
        _CName11 = [[TableName##_QueryAccessor_##CName11 alloc] initWithColumn:10 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName11, CType11) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_IMPL(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_IMPL(CName11, CType11) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 9, ndx, CName10, CType10, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 10, ndx, CName11, CType11, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    TIGHTDB_COLUMN_INSERT(self, 9, ndx, CName10, CType10); \
    TIGHTDB_COLUMN_INSERT(self, 10, ndx, CName11, CType11); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 9, CName10, CType10) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 10, CName11, CType11) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    TIGHTDB_ADD_COLUMN(spec, CName10, CType10) \
    TIGHTDB_ADD_COLUMN(spec, CName11, CType11) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_11(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11) \
TIGHTDB_TABLE_DEF_11(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11) \
TIGHTDB_TABLE_IMPL_11(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11)


#define TIGHTDB_TABLE_DEF_12(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName12, CType12) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName12, CType12) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName10 *CName10; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName11 *CName11; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName12 *CName12; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_DEF(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_DEF(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_DEF(CName12, CType12) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_12(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
    TightdbAccessor *_##CName10; \
    TightdbAccessor *_##CName11; \
    TightdbAccessor *_##CName12; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
        _##CName10 = [[TightdbAccessor alloc] initWithCursor:self columnId:9]; \
        _##CName11 = [[TightdbAccessor alloc] initWithCursor:self columnId:10]; \
        _##CName12 = [[TightdbAccessor alloc] initWithCursor:self columnId:11]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName12, CType12) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
@synthesize CName10 = _CName10; \
@synthesize CName11 = _CName11; \
@synthesize CName12 = _CName12; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
        _CName10 = [[TableName##_QueryAccessor_##CName10 alloc] initWithColumn:9 query:self]; \
        _CName11 = [[TableName##_QueryAccessor_##CName11 alloc] initWithColumn:10 query:self]; \
        _CName12 = [[TableName##_QueryAccessor_##CName12 alloc] initWithColumn:11 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName12, CType12) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_IMPL(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_IMPL(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_IMPL(CName12, CType12) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 9, ndx, CName10, CType10, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 10, ndx, CName11, CType11, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 11, ndx, CName12, CType12, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    TIGHTDB_COLUMN_INSERT(self, 9, ndx, CName10, CType10); \
    TIGHTDB_COLUMN_INSERT(self, 10, ndx, CName11, CType11); \
    TIGHTDB_COLUMN_INSERT(self, 11, ndx, CName12, CType12); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 9, CName10, CType10) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 10, CName11, CType11) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 11, CName12, CType12) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    TIGHTDB_ADD_COLUMN(spec, CName10, CType10) \
    TIGHTDB_ADD_COLUMN(spec, CName11, CType11) \
    TIGHTDB_ADD_COLUMN(spec, CName12, CType12) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_12(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12) \
TIGHTDB_TABLE_DEF_12(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12) \
TIGHTDB_TABLE_IMPL_12(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12)


#define TIGHTDB_TABLE_DEF_13(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12, CName13, CType13) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName12, CType12) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName13, CType13) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName12, CType12) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName13, CType13) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName10 *CName10; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName11 *CName11; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName12 *CName12; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName13 *CName13; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_DEF(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_DEF(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_DEF(CName12, CType12) \
TIGHTDB_COLUMN_PROXY_DEF(CName13, CType13) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_13(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12, CName13, CType13) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
    TightdbAccessor *_##CName10; \
    TightdbAccessor *_##CName11; \
    TightdbAccessor *_##CName12; \
    TightdbAccessor *_##CName13; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
        _##CName10 = [[TightdbAccessor alloc] initWithCursor:self columnId:9]; \
        _##CName11 = [[TightdbAccessor alloc] initWithCursor:self columnId:10]; \
        _##CName12 = [[TightdbAccessor alloc] initWithCursor:self columnId:11]; \
        _##CName13 = [[TightdbAccessor alloc] initWithCursor:self columnId:12]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName12, CType12) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName13, CType13) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
@synthesize CName10 = _CName10; \
@synthesize CName11 = _CName11; \
@synthesize CName12 = _CName12; \
@synthesize CName13 = _CName13; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
        _CName10 = [[TableName##_QueryAccessor_##CName10 alloc] initWithColumn:9 query:self]; \
        _CName11 = [[TableName##_QueryAccessor_##CName11 alloc] initWithColumn:10 query:self]; \
        _CName12 = [[TableName##_QueryAccessor_##CName12 alloc] initWithColumn:11 query:self]; \
        _CName13 = [[TableName##_QueryAccessor_##CName13 alloc] initWithColumn:12 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName12, CType12) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName13, CType13) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_IMPL(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_IMPL(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_IMPL(CName12, CType12) \
TIGHTDB_COLUMN_PROXY_IMPL(CName13, CType13) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 12, CName13, CType13); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 12, CName13, CType13); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 9, ndx, CName10, CType10, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 10, ndx, CName11, CType11, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 11, ndx, CName12, CType12, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 12, ndx, CName13, CType13, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    TIGHTDB_COLUMN_INSERT(self, 9, ndx, CName10, CType10); \
    TIGHTDB_COLUMN_INSERT(self, 10, ndx, CName11, CType11); \
    TIGHTDB_COLUMN_INSERT(self, 11, ndx, CName12, CType12); \
    TIGHTDB_COLUMN_INSERT(self, 12, ndx, CName13, CType13); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 9, CName10, CType10) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 10, CName11, CType11) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 11, CName12, CType12) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 12, CName13, CType13) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    TIGHTDB_ADD_COLUMN(spec, CName10, CType10) \
    TIGHTDB_ADD_COLUMN(spec, CName11, CType11) \
    TIGHTDB_ADD_COLUMN(spec, CName12, CType12) \
    TIGHTDB_ADD_COLUMN(spec, CName13, CType13) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_13(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13) \
TIGHTDB_TABLE_DEF_13(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13) \
TIGHTDB_TABLE_IMPL_13(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13)


#define TIGHTDB_TABLE_DEF_14(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12, CName13, CType13, CName14, CType14) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName12, CType12) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName13, CType13) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName14, CType14) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName12, CType12) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName13, CType13) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName14, CType14) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName10 *CName10; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName11 *CName11; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName12 *CName12; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName13 *CName13; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName14 *CName14; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_DEF(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_DEF(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_DEF(CName12, CType12) \
TIGHTDB_COLUMN_PROXY_DEF(CName13, CType13) \
TIGHTDB_COLUMN_PROXY_DEF(CName14, CType14) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_14(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12, CName13, CType13, CName14, CType14) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
    TightdbAccessor *_##CName10; \
    TightdbAccessor *_##CName11; \
    TightdbAccessor *_##CName12; \
    TightdbAccessor *_##CName13; \
    TightdbAccessor *_##CName14; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
        _##CName10 = [[TightdbAccessor alloc] initWithCursor:self columnId:9]; \
        _##CName11 = [[TightdbAccessor alloc] initWithCursor:self columnId:10]; \
        _##CName12 = [[TightdbAccessor alloc] initWithCursor:self columnId:11]; \
        _##CName13 = [[TightdbAccessor alloc] initWithCursor:self columnId:12]; \
        _##CName14 = [[TightdbAccessor alloc] initWithCursor:self columnId:13]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName12, CType12) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName13, CType13) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName14, CType14) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
@synthesize CName10 = _CName10; \
@synthesize CName11 = _CName11; \
@synthesize CName12 = _CName12; \
@synthesize CName13 = _CName13; \
@synthesize CName14 = _CName14; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
        _CName10 = [[TableName##_QueryAccessor_##CName10 alloc] initWithColumn:9 query:self]; \
        _CName11 = [[TableName##_QueryAccessor_##CName11 alloc] initWithColumn:10 query:self]; \
        _CName12 = [[TableName##_QueryAccessor_##CName12 alloc] initWithColumn:11 query:self]; \
        _CName13 = [[TableName##_QueryAccessor_##CName13 alloc] initWithColumn:12 query:self]; \
        _CName14 = [[TableName##_QueryAccessor_##CName14 alloc] initWithColumn:13 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName12, CType12) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName13, CType13) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName14, CType14) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_IMPL(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_IMPL(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_IMPL(CName12, CType12) \
TIGHTDB_COLUMN_PROXY_IMPL(CName13, CType13) \
TIGHTDB_COLUMN_PROXY_IMPL(CName14, CType14) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 12, CName13, CType13); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 13, CName14, CType14); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 12, CName13, CType13); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 13, CName14, CType14); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 9, ndx, CName10, CType10, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 10, ndx, CName11, CType11, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 11, ndx, CName12, CType12, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 12, ndx, CName13, CType13, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 13, ndx, CName14, CType14, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    TIGHTDB_COLUMN_INSERT(self, 9, ndx, CName10, CType10); \
    TIGHTDB_COLUMN_INSERT(self, 10, ndx, CName11, CType11); \
    TIGHTDB_COLUMN_INSERT(self, 11, ndx, CName12, CType12); \
    TIGHTDB_COLUMN_INSERT(self, 12, ndx, CName13, CType13); \
    TIGHTDB_COLUMN_INSERT(self, 13, ndx, CName14, CType14); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 9, CName10, CType10) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 10, CName11, CType11) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 11, CName12, CType12) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 12, CName13, CType13) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 13, CName14, CType14) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    TIGHTDB_ADD_COLUMN(spec, CName10, CType10) \
    TIGHTDB_ADD_COLUMN(spec, CName11, CType11) \
    TIGHTDB_ADD_COLUMN(spec, CName12, CType12) \
    TIGHTDB_ADD_COLUMN(spec, CName13, CType13) \
    TIGHTDB_ADD_COLUMN(spec, CName14, CType14) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_14(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13, CType14, CName14) \
TIGHTDB_TABLE_DEF_14(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13, CType14, CName14) \
TIGHTDB_TABLE_IMPL_14(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13, CType14, CName14)


#define TIGHTDB_TABLE_DEF_15(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12, CName13, CType13, CName14, CType14, CName15, CType15) \
@interface TableName##_Cursor: TightdbCursor \
TIGHTDB_CURSOR_PROPERTY_DEF(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName12, CType12) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName13, CType13) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName14, CType14) \
TIGHTDB_CURSOR_PROPERTY_DEF(CName15, CType15) \
@end \
@class TableName##_Query; \
@class TableName##_View; \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName12, CType12) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName13, CType13) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName14, CType14) \
TIGHTDB_QUERY_ACCESSOR_DEF(TableName, CName15, CType15) \
@interface TableName##_Query: TightdbQuery \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName1 *CName1; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName2 *CName2; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName3 *CName3; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName4 *CName4; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName5 *CName5; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName6 *CName6; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName7 *CName7; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName8 *CName8; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName9 *CName9; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName10 *CName10; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName11 *CName11; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName12 *CName12; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName13 *CName13; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName14 *CName14; \
@property(nonatomic, strong) TableName##_QueryAccessor_##CName15 *CName15; \
-(TableName##_Query *)group; \
-(TableName##_Query *)or; \
-(TableName##_Query *)endgroup; \
-(TableName##_Query *)subtable:(size_t)column; \
-(TableName##_Query *)parent; \
-(TableName##_View *)findAll; \
@end \
@interface TableName: TightdbTable \
TIGHTDB_COLUMN_PROXY_DEF(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_DEF(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_DEF(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_DEF(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_DEF(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_DEF(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_DEF(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_DEF(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_DEF(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_DEF(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_DEF(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_DEF(CName12, CType12) \
TIGHTDB_COLUMN_PROXY_DEF(CName13, CType13) \
TIGHTDB_COLUMN_PROXY_DEF(CName14, CType14) \
TIGHTDB_COLUMN_PROXY_DEF(CName15, CType15) \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15; \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15 error:(NSError **)error; \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15; \
-(TableName##_Query *)where; \
-(TableName##_Cursor *)add; \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
-(TableName##_Cursor *)lastObject; \
@end \
@interface TableName##_View: TightdbView \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx; \
@end

#define TIGHTDB_TABLE_IMPL_15(TableName, CName1, CType1, CName2, CType2, CName3, CType3, CName4, CType4, CName5, CType5, CName6, CType6, CName7, CType7, CName8, CType8, CName9, CType9, CName10, CType10, CName11, CType11, CName12, CType12, CName13, CType13, CName14, CType14, CName15, CType15) \
@implementation TableName##_Cursor \
{ \
    TightdbAccessor *_##CName1; \
    TightdbAccessor *_##CName2; \
    TightdbAccessor *_##CName3; \
    TightdbAccessor *_##CName4; \
    TightdbAccessor *_##CName5; \
    TightdbAccessor *_##CName6; \
    TightdbAccessor *_##CName7; \
    TightdbAccessor *_##CName8; \
    TightdbAccessor *_##CName9; \
    TightdbAccessor *_##CName10; \
    TightdbAccessor *_##CName11; \
    TightdbAccessor *_##CName12; \
    TightdbAccessor *_##CName13; \
    TightdbAccessor *_##CName14; \
    TightdbAccessor *_##CName15; \
} \
-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx \
{ \
    self = [super initWithTable:table ndx:ndx]; \
    if (self) { \
        _##CName1 = [[TightdbAccessor alloc] initWithCursor:self columnId:0]; \
        _##CName2 = [[TightdbAccessor alloc] initWithCursor:self columnId:1]; \
        _##CName3 = [[TightdbAccessor alloc] initWithCursor:self columnId:2]; \
        _##CName4 = [[TightdbAccessor alloc] initWithCursor:self columnId:3]; \
        _##CName5 = [[TightdbAccessor alloc] initWithCursor:self columnId:4]; \
        _##CName6 = [[TightdbAccessor alloc] initWithCursor:self columnId:5]; \
        _##CName7 = [[TightdbAccessor alloc] initWithCursor:self columnId:6]; \
        _##CName8 = [[TightdbAccessor alloc] initWithCursor:self columnId:7]; \
        _##CName9 = [[TightdbAccessor alloc] initWithCursor:self columnId:8]; \
        _##CName10 = [[TightdbAccessor alloc] initWithCursor:self columnId:9]; \
        _##CName11 = [[TightdbAccessor alloc] initWithCursor:self columnId:10]; \
        _##CName12 = [[TightdbAccessor alloc] initWithCursor:self columnId:11]; \
        _##CName13 = [[TightdbAccessor alloc] initWithCursor:self columnId:12]; \
        _##CName14 = [[TightdbAccessor alloc] initWithCursor:self columnId:13]; \
        _##CName15 = [[TightdbAccessor alloc] initWithCursor:self columnId:14]; \
    } \
    return self; \
} \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName1, CType1) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName2, CType2) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName3, CType3) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName4, CType4) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName5, CType5) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName6, CType6) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName7, CType7) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName8, CType8) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName9, CType9) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName10, CType10) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName11, CType11) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName12, CType12) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName13, CType13) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName14, CType14) \
TIGHTDB_CURSOR_PROPERTY_IMPL(CName15, CType15) \
@end \
@implementation TableName##_Query \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(long)getFastEnumStart \
{ \
    return [self findNext:-1]; \
} \
-(long)incrementFastEnum:(long)ndx \
{ \
    return [self findNext:ndx]; \
} \
-(TightdbCursor *)getCursor:(long)ndx \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:ndx]; \
} \
@synthesize CName1 = _CName1; \
@synthesize CName2 = _CName2; \
@synthesize CName3 = _CName3; \
@synthesize CName4 = _CName4; \
@synthesize CName5 = _CName5; \
@synthesize CName6 = _CName6; \
@synthesize CName7 = _CName7; \
@synthesize CName8 = _CName8; \
@synthesize CName9 = _CName9; \
@synthesize CName10 = _CName10; \
@synthesize CName11 = _CName11; \
@synthesize CName12 = _CName12; \
@synthesize CName13 = _CName13; \
@synthesize CName14 = _CName14; \
@synthesize CName15 = _CName15; \
-(id)initWithTable:(TightdbTable *)table \
{ \
    self = [super initWithTable:table]; \
    if (self) { \
        _CName1 = [[TableName##_QueryAccessor_##CName1 alloc] initWithColumn:0 query:self]; \
        _CName2 = [[TableName##_QueryAccessor_##CName2 alloc] initWithColumn:1 query:self]; \
        _CName3 = [[TableName##_QueryAccessor_##CName3 alloc] initWithColumn:2 query:self]; \
        _CName4 = [[TableName##_QueryAccessor_##CName4 alloc] initWithColumn:3 query:self]; \
        _CName5 = [[TableName##_QueryAccessor_##CName5 alloc] initWithColumn:4 query:self]; \
        _CName6 = [[TableName##_QueryAccessor_##CName6 alloc] initWithColumn:5 query:self]; \
        _CName7 = [[TableName##_QueryAccessor_##CName7 alloc] initWithColumn:6 query:self]; \
        _CName8 = [[TableName##_QueryAccessor_##CName8 alloc] initWithColumn:7 query:self]; \
        _CName9 = [[TableName##_QueryAccessor_##CName9 alloc] initWithColumn:8 query:self]; \
        _CName10 = [[TableName##_QueryAccessor_##CName10 alloc] initWithColumn:9 query:self]; \
        _CName11 = [[TableName##_QueryAccessor_##CName11 alloc] initWithColumn:10 query:self]; \
        _CName12 = [[TableName##_QueryAccessor_##CName12 alloc] initWithColumn:11 query:self]; \
        _CName13 = [[TableName##_QueryAccessor_##CName13 alloc] initWithColumn:12 query:self]; \
        _CName14 = [[TableName##_QueryAccessor_##CName14 alloc] initWithColumn:13 query:self]; \
        _CName15 = [[TableName##_QueryAccessor_##CName15 alloc] initWithColumn:14 query:self]; \
    } \
    return self; \
} \
-(TableName##_Query *)group \
{ \
    [super group]; \
    return self; \
} \
-(TableName##_Query *)or \
{ \
    [super or]; \
    return self; \
} \
-(TableName##_Query *)endgroup \
{ \
    [super endgroup]; \
    return self; \
} \
-(TableName##_Query *)subtable:(size_t)column \
{ \
    [super subtable:column]; \
    return self; \
} \
-(TableName##_Query *)parent \
{ \
    [super parent]; \
    return self; \
} \
-(TableName##_View *)findAll \
{ \
    return [[TableName##_View alloc] initFromQuery:self]; \
} \
@end \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName1, CType1) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName2, CType2) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName3, CType3) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName4, CType4) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName5, CType5) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName6, CType6) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName7, CType7) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName8, CType8) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName9, CType9) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName10, CType10) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName11, CType11) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName12, CType12) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName13, CType13) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName14, CType14) \
TIGHTDB_QUERY_ACCESSOR_IMPL(TableName, CName15, CType15) \
@implementation TableName \
{ \
    TableName##_Cursor *tmpCursor; \
} \
TIGHTDB_COLUMN_PROXY_IMPL(CName1, CType1) \
TIGHTDB_COLUMN_PROXY_IMPL(CName2, CType2) \
TIGHTDB_COLUMN_PROXY_IMPL(CName3, CType3) \
TIGHTDB_COLUMN_PROXY_IMPL(CName4, CType4) \
TIGHTDB_COLUMN_PROXY_IMPL(CName5, CType5) \
TIGHTDB_COLUMN_PROXY_IMPL(CName6, CType6) \
TIGHTDB_COLUMN_PROXY_IMPL(CName7, CType7) \
TIGHTDB_COLUMN_PROXY_IMPL(CName8, CType8) \
TIGHTDB_COLUMN_PROXY_IMPL(CName9, CType9) \
TIGHTDB_COLUMN_PROXY_IMPL(CName10, CType10) \
TIGHTDB_COLUMN_PROXY_IMPL(CName11, CType11) \
TIGHTDB_COLUMN_PROXY_IMPL(CName12, CType12) \
TIGHTDB_COLUMN_PROXY_IMPL(CName13, CType13) \
TIGHTDB_COLUMN_PROXY_IMPL(CName14, CType14) \
TIGHTDB_COLUMN_PROXY_IMPL(CName15, CType15) \
\
-(id)_initRaw \
{ \
    self = [super _initRaw]; \
    if (!self) return nil; \
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 12, CName13, CType13); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 13, CName14, CType14); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 14, CName15, CType15); \
    return self; \
} \
-(id)init \
{ \
    self = [super init]; \
    if (!self) return nil; \
    if (![self _addColumns]) return nil; \
\
    TIGHTDB_COLUMN_PROXY_INIT(self, 0, CName1, CType1); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 1, CName2, CType2); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 2, CName3, CType3); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 3, CName4, CType4); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 4, CName5, CType5); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 5, CName6, CType6); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 6, CName7, CType7); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 7, CName8, CType8); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 8, CName9, CType9); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 9, CName10, CType10); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 10, CName11, CType11); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 11, CName12, CType12); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 12, CName13, CType13); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 13, CName14, CType14); \
    TIGHTDB_COLUMN_PROXY_INIT(self, 14, CName15, CType15); \
    return self; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15 \
{ \
    return [self add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15 error:nil]; \
} \
-(BOOL)add##CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15 error:(NSError **)error\
{ \
    const size_t ndx = [self count]; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 0, ndx, CName1, CType1, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 1, ndx, CName2, CType2, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 2, ndx, CName3, CType3, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 3, ndx, CName4, CType4, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 4, ndx, CName5, CType5, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 5, ndx, CName6, CType6, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 6, ndx, CName7, CType7, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 7, ndx, CName8, CType8, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 8, ndx, CName9, CType9, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 9, ndx, CName10, CType10, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 10, ndx, CName11, CType11, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 11, ndx, CName12, CType12, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 12, ndx, CName13, CType13, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 13, ndx, CName14, CType14, error)) return NO; \
    if (!TIGHTDB_COLUMN_INSERT_ERROR(self, 14, ndx, CName15, CType15, error)) return NO; \
    return [self insertDoneWithError:error]; \
} \
-(void)insertAtIndex:(size_t)ndx CName1:(TIGHTDB_ARG_TYPE(CType1))CName1 CName2:(TIGHTDB_ARG_TYPE(CType2))CName2 CName3:(TIGHTDB_ARG_TYPE(CType3))CName3 CName4:(TIGHTDB_ARG_TYPE(CType4))CName4 CName5:(TIGHTDB_ARG_TYPE(CType5))CName5 CName6:(TIGHTDB_ARG_TYPE(CType6))CName6 CName7:(TIGHTDB_ARG_TYPE(CType7))CName7 CName8:(TIGHTDB_ARG_TYPE(CType8))CName8 CName9:(TIGHTDB_ARG_TYPE(CType9))CName9 CName10:(TIGHTDB_ARG_TYPE(CType10))CName10 CName11:(TIGHTDB_ARG_TYPE(CType11))CName11 CName12:(TIGHTDB_ARG_TYPE(CType12))CName12 CName13:(TIGHTDB_ARG_TYPE(CType13))CName13 CName14:(TIGHTDB_ARG_TYPE(CType14))CName14 CName15:(TIGHTDB_ARG_TYPE(CType15))CName15 \
{ \
    TIGHTDB_COLUMN_INSERT(self, 0, ndx, CName1, CType1); \
    TIGHTDB_COLUMN_INSERT(self, 1, ndx, CName2, CType2); \
    TIGHTDB_COLUMN_INSERT(self, 2, ndx, CName3, CType3); \
    TIGHTDB_COLUMN_INSERT(self, 3, ndx, CName4, CType4); \
    TIGHTDB_COLUMN_INSERT(self, 4, ndx, CName5, CType5); \
    TIGHTDB_COLUMN_INSERT(self, 5, ndx, CName6, CType6); \
    TIGHTDB_COLUMN_INSERT(self, 6, ndx, CName7, CType7); \
    TIGHTDB_COLUMN_INSERT(self, 7, ndx, CName8, CType8); \
    TIGHTDB_COLUMN_INSERT(self, 8, ndx, CName9, CType9); \
    TIGHTDB_COLUMN_INSERT(self, 9, ndx, CName10, CType10); \
    TIGHTDB_COLUMN_INSERT(self, 10, ndx, CName11, CType11); \
    TIGHTDB_COLUMN_INSERT(self, 11, ndx, CName12, CType12); \
    TIGHTDB_COLUMN_INSERT(self, 12, ndx, CName13, CType13); \
    TIGHTDB_COLUMN_INSERT(self, 13, ndx, CName14, CType14); \
    TIGHTDB_COLUMN_INSERT(self, 14, ndx, CName15, CType15); \
    [self insertDone]; \
} \
-(TableName##_Query *)where \
{ \
    return [[TableName##_Query alloc] initWithTable:self]; \
} \
-(TableName##_Cursor *)add \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self addRow]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:ndx]; \
} \
-(TableName##_Cursor *)lastObject \
{ \
    return [[TableName##_Cursor alloc] initWithTable:self ndx:[self count]-1]; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:self ndx:0]; \
} \
+(BOOL)_checkType:(TightdbSpec *)spec \
{ \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 0, CName1, CType1) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 1, CName2, CType2) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 2, CName3, CType3) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 3, CName4, CType4) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 4, CName5, CType5) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 5, CName6, CType6) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 6, CName7, CType7) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 7, CName8, CType8) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 8, CName9, CType9) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 9, CName10, CType10) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 10, CName11, CType11) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 11, CName12, CType12) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 12, CName13, CType13) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 13, CName14, CType14) \
    TIGHTDB_CHECK_COLUMN_TYPE(spec, 14, CName15, CType15) \
    return YES; \
} \
-(BOOL)_checkType \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _checkType:spec]) return NO; \
    return YES; \
} \
+(BOOL)_addColumns:(TightdbSpec *)spec \
{ \
    TIGHTDB_ADD_COLUMN(spec, CName1, CType1) \
    TIGHTDB_ADD_COLUMN(spec, CName2, CType2) \
    TIGHTDB_ADD_COLUMN(spec, CName3, CType3) \
    TIGHTDB_ADD_COLUMN(spec, CName4, CType4) \
    TIGHTDB_ADD_COLUMN(spec, CName5, CType5) \
    TIGHTDB_ADD_COLUMN(spec, CName6, CType6) \
    TIGHTDB_ADD_COLUMN(spec, CName7, CType7) \
    TIGHTDB_ADD_COLUMN(spec, CName8, CType8) \
    TIGHTDB_ADD_COLUMN(spec, CName9, CType9) \
    TIGHTDB_ADD_COLUMN(spec, CName10, CType10) \
    TIGHTDB_ADD_COLUMN(spec, CName11, CType11) \
    TIGHTDB_ADD_COLUMN(spec, CName12, CType12) \
    TIGHTDB_ADD_COLUMN(spec, CName13, CType13) \
    TIGHTDB_ADD_COLUMN(spec, CName14, CType14) \
    TIGHTDB_ADD_COLUMN(spec, CName15, CType15) \
    return YES; \
} \
-(BOOL)_addColumns \
{ \
    TightdbSpec *spec = [self getSpec]; \
    if (!spec) return NO; \
    if (![TableName _addColumns:spec]) return NO; \
    [self updateFromSpec]; \
    return YES; \
} \
@end \
@implementation TableName##_View \
{ \
    TableName##_Cursor *tmpCursor; \
} \
-(TightdbCursor *)getCursor \
{ \
    return tmpCursor = [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:0]]; \
} \
-(TableName##_Cursor *)objectAtIndex:(size_t)ndx \
{ \
    return [[TableName##_Cursor alloc] initWithTable:[self getTable] ndx:[self getSourceNdx:ndx]]; \
} \
@end

#define TIGHTDB_TABLE_15(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13, CType14, CName14, CType15, CName15) \
TIGHTDB_TABLE_DEF_15(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13, CType14, CName14, CType15, CName15) \
TIGHTDB_TABLE_IMPL_15(TableName, CType1, CName1, CType2, CName2, CType3, CName3, CType4, CName4, CType5, CName5, CType6, CName6, CType7, CName7, CType8, CName8, CType9, CName9, CType10, CName10, CType11, CName11, CType12, CName12, CType13, CName13, CType14, CName14, CType15, CName15)
