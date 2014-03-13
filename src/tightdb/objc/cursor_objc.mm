//
//  cursor.mm
//  TightDb

#include <tightdb/table.hpp>

#import <tightdb/objc/cursor.h>
#import <tightdb/objc/table.h>
#import <tightdb/objc/table_priv.h>

#include <tightdb/objc/util.hpp>

using namespace std;

// TODO: Concept for cursor invalidation (when table updates).

@interface TDBRow()
@property (nonatomic, weak) TDBTable *table;
@property (nonatomic) NSUInteger ndx;
@end
@implementation TDBRow
@synthesize table = _table;
@synthesize ndx = _ndx;

-(id)initWithTable:(TDBTable *)table ndx:(NSUInteger)ndx
{
    if (ndx >= [table rowCount])
        return nil;

    self = [super init];
    if (self) {
        _table = table;
        _ndx = ndx;
    }
    return self;
}
-(NSUInteger)TDBIndex
{
    return _ndx;
}
-(void)TDBSetNdx:(NSUInteger)ndx
{
    _ndx = ndx;
}
-(void)dealloc
{
#ifdef TIGHTDB_DEBUG
    NSLog(@"TDBRow dealloc");
#endif
    _table = nil;
}

-(int64_t)intInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table intInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(NSString *)stringInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table stringInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(TightdbBinary *)binaryInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table binaryInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(BOOL)boolInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table boolInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(float)floatInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table floatInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(double)doubleInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table doubleInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(time_t)dateInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table dateInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(TDBTable *)tableInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table tableInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(TightdbMixed *)mixedInColumnWithIndex:(NSUInteger)colNdx
{
    return [_table mixedInColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setInt:(int64_t)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setInt:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setString:(NSString *)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setString:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setBinary:(TightdbBinary *)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setBinary:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setBool:(BOOL)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setBool:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setFloat:(float)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setFloat:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setDouble:(double)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setDouble:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setDate:(time_t)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setDate:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setTable:(TDBTable *)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setTable:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

-(void)setMixed:(TightdbMixed *)value inColumnWithIndex:(NSUInteger)colNdx
{
    [_table setMixed:value inColumnWithIndex:colNdx atRowIndex:_ndx];
}

@end


@implementation TightdbAccessor
{
    __weak TDBRow *_cursor;
    size_t _columnId;
}

-(id)initWithCursor:(TDBRow *)cursor columnId:(NSUInteger)columnId
{
    self = [super init];
    if (self) {
        _cursor = cursor;
        _columnId = columnId;
    }
    return self;
}

-(BOOL)getBool
{
    return [_cursor.table boolInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setBool:(BOOL)value
{
    [_cursor.table setBool:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(int64_t)getInt
{
    return [_cursor.table intInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setInt:(int64_t)value
{
    [_cursor.table setInt:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(float)getFloat
{
    return [_cursor.table floatInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setFloat:(float)value
{
    [_cursor.table setFloat:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(double)getDouble
{
    return [_cursor.table doubleInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setDouble:(double)value
{
    [_cursor.table setDouble:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(NSString *)getString
{
    return [_cursor.table stringInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setString:(NSString *)value
{
    [_cursor.table setString:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(TightdbBinary *)getBinary
{
    return [_cursor.table binaryInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setBinary:(TightdbBinary *)value
{
    [_cursor.table setBinary:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}
// FIXME: should it be setBinaryWithBuffer / setBinaryWithBinary ?
// -(BOOL)setBinary:(const char *)data size:(size_t)size
// {
//    return [_cursor.table setBinary:_columnId ndx:_cursor.ndx data:data size:size error:error];
// }

-(time_t)getDate
{
    return [_cursor.table dateInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setDate:(time_t)value
{
    [_cursor.table setDate:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(id)getSubtable:(Class)obj
{
    return [_cursor.table tableInColumnWithIndex:_columnId atRowIndex:_cursor.ndx asTableClass:obj];
}

-(void)setSubtable:(TDBTable *)value
{
    [_cursor.table setTable:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(TightdbMixed *)getMixed
{
    return [_cursor.table mixedInColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

-(void)setMixed:(TightdbMixed *)value
{
    [_cursor.table setMixed:value inColumnWithIndex:_columnId atRowIndex:_cursor.ndx];
}

@end
