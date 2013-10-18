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

@interface TightdbCursor()
@property (nonatomic, weak) TightdbTable *table;
@property (nonatomic) size_t ndx;
@end
@implementation TightdbCursor
@synthesize table = _table;
@synthesize ndx = _ndx;

-(id)initWithTable:(TightdbTable *)table ndx:(size_t)ndx
{
    if (ndx >= [table count]) 
        return nil;

    self = [super init];
    if (self) {
        _table = table;
        _ndx = ndx;
    }
    return self;
}
-(size_t)index
{
    return _ndx;
}
-(void)setNdx:(size_t)ndx
{
    _ndx = ndx;
}
-(void)dealloc
{
#ifdef TIGHTDB_DEBUG
    NSLog(@"TightdbCursor dealloc");
#endif
    _table = nil;
}

-(int64_t)getIntInColumn:(size_t)colNdx
{
    return [_table get:colNdx ndx:_ndx];
}

-(NSString *)getStringInColumn:(size_t)colNdx
{
    return [_table getString:colNdx ndx:_ndx];
}

-(BOOL)getBoolInColumn:(size_t)colNdx
{
    return [_table getBool:colNdx ndx:_ndx];
}

-(float)getFloatInColumn:(size_t)colNdx
{
    return [_table getFloat:colNdx ndx:_ndx];
}

-(double)getDoubleInColumn:(size_t)colNdx
{
    return [_table getDouble:colNdx ndx:_ndx];
}

-(time_t)getDateInColumn:(size_t)colNdx
{
    return [_table getDate:colNdx ndx:_ndx];
}

-(TightdbBinary *)getBinaryInColumn:(size_t)colNdx
{
    return [_table getBinary:colNdx ndx:_ndx];
}

-(TightdbMixed *)getMixedInColumn:(size_t)colNdx
{
    return [_table getMixed:colNdx ndx:_ndx];
}

-(TightdbTable *)getTableInColumn:(size_t)colNdx
{
    return [_table getSubtable:colNdx ndx:_ndx];
}

-(void)setInt:(int64_t)value inColumn:(size_t)colNdx
{
    [_table setInt:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setString:(NSString *)value inColumn:(size_t)colNdx
{
    [_table setString:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setBool:(BOOL)value inColumn:(size_t)colNdx
{
    [_table setBool:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setFloat:(float)value inColumn:(size_t)colNdx
{
    [_table setFloat:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setDouble:(double)value inColumn:(size_t)colNdx
{
    [_table setDouble:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setDate:(time_t)value inColumn:(size_t)colNdx
{
    [_table setDate:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setBinary:(TightdbBinary *)value inColumn:(size_t)colNdx
{
    [_table setBinary:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setMixed:(TightdbMixed *)value inColumn:(size_t)colNdx
{
    [_table setMixed:value inColumn:colNdx atRow:_ndx]; 
}

-(void)setTable:(TightdbTable *)value inColumn:(size_t)colNdx
{
    [_table setTable:value inColumn:colNdx atRow:_ndx]; 
} 

@end


@implementation TightdbAccessor
{
    __weak TightdbCursor *_cursor;
    size_t _columnId;
}

-(id)initWithCursor:(TightdbCursor *)cursor columnId:(size_t)columnId
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
    return [_cursor.table getBool:_columnId ndx:_cursor.ndx];
}

-(void)setBool:(BOOL)value
{
    [_cursor.table setBool:value inColumn:_columnId atRow:_cursor.ndx];
}

-(int64_t)getInt
{
    return [_cursor.table get:_columnId ndx:_cursor.ndx];
}

-(void)setInt:(int64_t)value
{
    [_cursor.table setInt:value inColumn:_columnId atRow:_cursor.ndx];
}

-(float)getFloat
{
    return [_cursor.table getFloat:_columnId ndx:_cursor.ndx];
}

-(void)setFloat:(float)value
{
    [_cursor.table setFloat:value inColumn:_columnId atRow:_cursor.ndx];
}

-(double)getDouble
{
    return [_cursor.table getDouble:_columnId ndx:_cursor.ndx];
}

-(void)setDouble:(double)value
{
    [_cursor.table setDouble:value inColumn:_columnId atRow:_cursor.ndx];
}

-(NSString *)getString
{
    return [_cursor.table getString:_columnId ndx:_cursor.ndx];
}

-(void)setString:(NSString *)value
{
    [_cursor.table setString:value inColumn:_columnId atRow:_cursor.ndx];
}

-(TightdbBinary *)getBinary
{
    return [_cursor.table getBinary:_columnId ndx:_cursor.ndx];
}

-(void)setBinary:(TightdbBinary *)value
{
    [_cursor.table setBinary:value inColumn:_columnId atRow:_cursor.ndx];
}
// FIXME: should it be setBinaryWithBuffer / setBinaryWithBinary ?
// -(BOOL)setBinary:(const char *)data size:(size_t)size
// {
//    return [_cursor.table setBinary:_columnId ndx:_cursor.ndx data:data size:size error:error];
// }

-(time_t)getDate
{
    return [_cursor.table getDate:_columnId ndx:_cursor.ndx];
}

-(void)setDate:(time_t)value
{
    [_cursor.table setDate:value inColumn:_columnId atRow:_cursor.ndx];
}

-(id)getSubtable:(Class)obj
{
    return [_cursor.table getSubtable:_columnId ndx:_cursor.ndx withClass:obj];
}

-(void)setSubtable:(TightdbTable *)value
{
    [_cursor.table setTable:value inColumn:_columnId atRow:_cursor.ndx];
}

-(TightdbMixed *)getMixed
{
    return [_cursor.table getMixed:_columnId ndx:_cursor.ndx];
}

-(void)setMixed:(TightdbMixed *)value
{
    [_cursor.table setMixed:value inColumn:_columnId atRow:_cursor.ndx];
}

@end
