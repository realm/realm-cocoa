//
//  query.mm
//  TightDB
//

#include <tightdb/table.hpp>
#include <tightdb/table_view.hpp>
#include <tightdb/query.hpp>
#include <tightdb/lang_bind_helper.hpp>

#import <tightdb/objc/query.h>
#import <tightdb/objc/table.h>
#import <tightdb/objc/table_priv.h>
#import <tightdb/objc/cursor.h>

#include <tightdb/objc/util.hpp>

using namespace std;


@interface TightdbView()
+(TightdbView *)tableViewWithTableView:(tightdb::TableView)table;
@end


@interface TightdbQuery()
{
    @public
    NSError *_error; // To enable the flow of multiple stacked queries, any error is kept until the last step.
}
@end


@implementation TightdbQuery
{
    tightdb::Query *_query;
    __weak TightdbTable *_table;
}

-(id)initWithTable:(TightdbTable *)table
{
    return [self initWithTable:table error:nil];
}

-(id)initWithTable:(TightdbTable *)table error:(NSError *__autoreleasing *)error
{
    self = [super init];
    if (self) {        
        _table = table;
        TIGHTDB_EXCEPTION_ERRHANDLER(
                                     _query = new tightdb::Query([_table getTable].where());
                                     , @"com.tightdb.query", nil);
    }
    return self;
}

-(TightdbCursor *)getCursor:(long)ndx
{
    (void)ndx;
    return nil; // Must be overridden in TightDb.h
}

-(long)getFastEnumStart
{
    return 0; // Must be overridden in TightDb.h
}
-(long)incrementFastEnum:(long)ndx
{
    (void)ndx;
    return ndx; // Must be overridden in TightDb.h
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained *)stackbuf count:(NSUInteger)len
{
    (void)len;
    if(state->state == 0)
    {
        state->state = [self getFastEnumStart];
        state->mutationsPtr = (unsigned long *)objc_unretainedPointer(self);
        TightdbCursor *tmp = [self getCursor:state->state];
        *stackbuf = tmp;
    }
    if ((int)state->state != -1) {
        [((TightdbCursor *)*stackbuf) setNdx:state->state];
        state->itemsPtr = stackbuf;
        state->state = [self incrementFastEnum:state->state];
    } else {
        *stackbuf = nil;
        state->itemsPtr = nil;
        state->mutationsPtr = nil;
        return 0;
    }
    return 1;
}

// Due to cyclic ARC problems. You have to clear manually. (Must be called from client code)
-(void)clear
{
    _table = nil;
}
-(void)dealloc
{
#ifdef TIGHTDB_DEBUG
    NSLog(@"Query dealloc");
#endif
    delete _query;
}

-(tightdb::Query *)getQuery
{
    return _query;
}

-(TightdbTable *)getTable
{
    return _table;
}

-(TightdbQuery *)group
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                 _query->group();
                                 , @"com.tightdb.query", self, &_error);
    return self;
}
-(TightdbQuery *)or
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    _query->Or();
                                    , @"com.tightdb.query", self, &_error);
    return self;
}
-(TightdbQuery *)endgroup
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    _query->end_group();
                                    , @"com.tightdb.query", self, &_error);
    return self;
}
-(void)subtable:(size_t)column
{
    _query->subtable(column);
}
-(void)parent
{
    _query->end_subtable();
}

-(NSNumber *)count
{
    return [self countWithError:nil];
}
-(NSNumber *)countWithError:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber TIGHTDB_OBJC_SIZE_T_NUMBER_IN:_query->count()];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)remove
{
    return [self removeWithError:nil];
}

-(NSNumber *)removeWithError:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber TIGHTDB_OBJC_SIZE_T_NUMBER_IN:_query->remove()];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)minInt:(size_t)col_ndx
{
    return [self minInt:col_ndx error:nil];
}
-(NSNumber *)minInt:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithLongLong:_query->minimum(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)minimumIntOfColumn:(size_t)colNdx
{
    return [self minInt:colNdx error:nil];
}


-(NSNumber *)minimumIntOfColumn:(size_t)colNdx withError:(NSError *__autoreleasing *)error
{
     if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithLongLong:_query->minimum(colNdx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)minFloat:(size_t)col_ndx
{
    return [self minFloat:col_ndx error:nil];
}
-(NSNumber *)minFloat:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithFloat:_query->minimum_float(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)minDouble:(size_t)col_ndx
{
    return [self minDouble:col_ndx error:nil];
}
-(NSNumber *)minDouble:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithDouble:_query->minimum_double(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)maxInt:(size_t)col_ndx
{
    return [self maxInt:col_ndx error:nil];
}
-(NSNumber *)maxInt:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithLongLong:_query->maximum(col_ndx)];
                                 , @"com.tightdb.query", nil);
}
-(NSNumber *)maxFloat:(size_t)col_ndx
{
    return [self maxFloat:col_ndx error:nil];
}
-(NSNumber *)maxFloat:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithFloat:_query->maximum_float(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)maxDouble:(size_t)col_ndx
{
    return [self maxDouble:col_ndx error:nil];
}
-(NSNumber *)maxDouble:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithDouble:_query->maximum_double(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)sumInt:(size_t)col_ndx
{
    return [self sumInt:col_ndx error:nil];
}
-(NSNumber *)sumInt:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithLongLong:_query->sum(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)sumFloat:(size_t)col_ndx
{
    return [self sumFloat:col_ndx error:nil];
}
-(NSNumber *)sumFloat:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithFloat:_query->sum_float(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)sumDouble:(size_t)col_ndx
{
    return [self sumDouble:col_ndx error:nil];
}
-(NSNumber *)sumDouble:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithDouble:_query->sum_double(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)avgInt:(size_t)col_ndx
{
    return [self avgInt:col_ndx error:nil];
}
-(NSNumber *)avgInt:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithDouble:_query->average(col_ndx)];
                                 , @"com.tightdb.query", nil);
}
-(NSNumber *)avgFloat:(size_t)col_ndx
{
    return [self avgFloat:col_ndx error:nil];
}
-(NSNumber *)avgFloat:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithDouble:_query->average_float(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(NSNumber *)avgDouble:(size_t)col_ndx
{
    return [self avgDouble:col_ndx error:nil];
}
-(NSNumber *)avgDouble:(size_t)col_ndx error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return nil;
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return [NSNumber numberWithDouble:_query->average_double(col_ndx)];
                                 , @"com.tightdb.query", nil);
}

-(tightdb::TableView)getTableView
{
    return _query->find_all();
}


-(TightdbView *)findAll {

    // jjepsen: please review this.
    return [[TightdbView alloc] initFromQuery:self];
}


-(size_t)findNext:(size_t)last
{
    return [self findNext:last error:nil];
}
-(size_t)findNext:(size_t)last error:(NSError *__autoreleasing *)error
{
    if (_error) {
        if (error) {
            *error = _error;
            _error = nil;
        }
        return size_t(-1);
    }
    TIGHTDB_EXCEPTION_ERRHANDLER(
                                 return _query->find_next(last);
                                 , @"com.tightdb.query", size_t(-1));
}


// Conditions:


-(TightdbQuery *)column:(size_t)colNdx isBetweenInt:(int64_t)from and:(int64_t)to
{
    _query->between(colNdx, from, to);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isBetweenFloat:(float)from and:(float)to
{
    _query->between(colNdx, from, to);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isBetweenDouble:(double)from and:(double)to
{
    _query->between(colNdx, from, to);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isBetweenDate:(time_t)from and:(time_t)to
{
    _query->between_date(colNdx, from, to);
    return self;
}  

-(TightdbQuery *)column:(size_t)colNdx isEqualToBool:(bool)value
{
    _query->equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToInt:(int64_t)value
{
    _query->equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToFloat:(float)value 
{
    _query->equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToDouble:(double)value
{
    _query->equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToString:(NSString *)value
{
    _query->equal(colNdx, ObjcStringAccessor(value));
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToString:(NSString *)value caseSensitive:(bool)caseSensitive
{
    _query->equal(colNdx, ObjcStringAccessor(value), caseSensitive);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToDate:(time_t)value
{
    _query->equal_date(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isEqualToBinary:(TightdbBinary *)value
{
    _query->equal(colNdx, [value getBinary]);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToInt:(int64_t)value
{
    _query->not_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToFloat:(float)value 
{
    _query->not_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToDouble:(double)value
{
    _query->not_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToString:(NSString *)value
{
    _query->not_equal(colNdx, ObjcStringAccessor(value));
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToString:(NSString *)value caseSensitive:(bool)caseSensitive
{
    _query->not_equal(colNdx, ObjcStringAccessor(value), caseSensitive);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToDate:(time_t)value
{
    _query->not_equal_date(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isNotEqualToBinary:(TightdbBinary *)value
{
    _query->not_equal(colNdx, [value getBinary]);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanInt:(int64_t)value 
{
    _query->greater(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanFloat:(float)value
{
    _query->greater(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanDouble:(double)value
{
    _query->greater(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanDate:(time_t)value
{
    _query->greater_date(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanOrEqualToInt:(int64_t)value
{
    _query->greater_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanOrEqualToFloat:(float)value 
{
    _query->greater_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanOrEqualToDouble:(double)value
{
    _query->greater_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isGreaterThanOrEqualToDate:(time_t)value
{
    _query->greater_equal_date(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanInt:(int64_t)value 
{
    _query->less(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanFloat:(float)value
{
    _query->less(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanDouble:(double)value
{
    _query->less(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanDate:(time_t)value
{
    _query->less_date(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanOrEqualToInt:(int64_t)value
{
    _query->less_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanOrEqualToFloat:(float)value 
{
    _query->less_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanOrEqualToDouble:(double)value
{
    _query->less_equal(colNdx, value);
    return self;
}

-(TightdbQuery *)column:(size_t)colNdx isLessThanOrEqualToDate:(time_t)value
{
    _query->less_equal_date(colNdx, value);
    return self;
}











@end


@implementation TightdbQueryAccessorBool
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}
-(TightdbQuery *)equal:(BOOL)value
{
    [_query getQuery]->equal(_column_ndx, (bool)value);
    return _query;
}
@end


@implementation TightdbQueryAccessorInt
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}

-(TightdbQuery *)equal:(int64_t)value
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->equal(_column_ndx, value);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(TightdbQuery *)notEqual:(int64_t)value
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->not_equal(_column_ndx, value);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(TightdbQuery *)greater:(int64_t)value
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->greater(_column_ndx, value);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(TightdbQuery *)greaterEqual:(int64_t)value
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->greater_equal(_column_ndx, value);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(TightdbQuery *)less:(int64_t)value
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->less(_column_ndx, value);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(TightdbQuery *)lessEqual:(int64_t)value
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->less_equal(_column_ndx, value);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(TightdbQuery *)between:(int64_t)from to:(int64_t)to
{
    TIGHTDB_EXCEPTION_ERRHANDLER_EX(
                                    [_query getQuery]->between(_column_ndx, from, to);
                                    , @"com.tightdb.queryaccessor", _query, &_query->_error);
    return _query;
}

-(NSNumber *)min
{
    return [self minWithError:nil];
}
-(NSNumber *)minWithError:(NSError *__autoreleasing *)error
{
    return [_query minInt:_column_ndx error:error];
}
-(NSNumber *)max
{
    return [self maxWithError:nil];
}
-(NSNumber *)maxWithError:(NSError *__autoreleasing *)error
{
    return [_query maxInt:_column_ndx error:error];
}

-(NSNumber *)sum
{
    return [self sumWithError:nil];
}
-(NSNumber *)sumWithError:(NSError *__autoreleasing *)error
{
    return [_query sumInt:_column_ndx error:error];
}
-(NSNumber *)avg
{
    return [self avgWithError:nil];
}
-(NSNumber *)avgWithError:(NSError *__autoreleasing *)error
{
    return [_query avgInt:_column_ndx error:error];
}
@end


@implementation TightdbQueryAccessorFloat
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}

-(TightdbQuery *)equal:(float)value
{
    [_query getQuery]->equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)notEqual:(float)value
{
    [_query getQuery]->not_equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)greater:(float)value
{
    [_query getQuery]->greater(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)greaterEqual:(float)value
{
    [_query getQuery]->greater_equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)less:(float)value
{
    [_query getQuery]->less(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)lessEqual:(float)value
{
    [_query getQuery]->less_equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)between:(float)from to:(float)to
{
    [_query getQuery]->between(_column_ndx, from, to);
    return _query;
}

-(NSNumber *)min
{
    return [self minWithError:nil];
}
-(NSNumber *)minWithError:(NSError *__autoreleasing *)error
{
    return [_query minFloat:_column_ndx error:error];
}
-(NSNumber *)max
{
    return [self maxWithError:nil];
}
-(NSNumber *)maxWithError:(NSError *__autoreleasing *)error
{
    return [_query maxFloat:_column_ndx error:error];
}

-(NSNumber *)sum
{
    return [self sumWithError:nil];
}
-(NSNumber *)sumWithError:(NSError *__autoreleasing *)error
{
    return [_query sumFloat:_column_ndx error:error];
}
-(NSNumber *)avg
{
    return [self avgWithError:nil];
}
-(NSNumber *)avgWithError:(NSError *__autoreleasing *)error
{
    return [_query avgFloat:_column_ndx error:error];
}
@end


@implementation TightdbQueryAccessorDouble
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}

-(TightdbQuery *)equal:(double)value
{
    [_query getQuery]->equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)notEqual:(double)value
{
    [_query getQuery]->not_equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)greater:(double)value
{
    [_query getQuery]->greater(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)greaterEqual:(double)value
{
    [_query getQuery]->greater_equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)less:(double)value
{
    [_query getQuery]->less(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)lessEqual:(double)value
{
    [_query getQuery]->less_equal(_column_ndx, value);
    return _query;
}

-(TightdbQuery *)between:(double)from to:(double)to
{
    [_query getQuery]->between(_column_ndx, from, to);
    return _query;
}

-(NSNumber *)min
{
    return [self minWithError:nil];
}
-(NSNumber *)minWithError:(NSError *__autoreleasing *)error
{
    return [_query minDouble:_column_ndx error:error];
}
-(NSNumber *)max
{
    return [self maxWithError:nil];
}
-(NSNumber *)maxWithError:(NSError *__autoreleasing *)error
{
    return [_query maxDouble:_column_ndx error:error];
}

-(NSNumber *)sum
{
    return [self sumWithError:nil];
}
-(NSNumber *)sumWithError:(NSError *__autoreleasing *)error
{
    return [_query sumDouble:_column_ndx error:error];
}
-(NSNumber *)avg
{
    return [self avgWithError:nil];
}
-(NSNumber *)avgWithError:(NSError *__autoreleasing *)error
{
    return [_query avgDouble:_column_ndx error:error];
}
@end


@implementation TightdbQueryAccessorString
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}
-(TightdbQuery *)equal:(NSString *)value
{
    [_query getQuery]->equal(_column_ndx, ObjcStringAccessor(value));
    return _query;
}
-(TightdbQuery *)equal:(NSString *)value caseSensitive:(BOOL)caseSensitive
{
    [_query getQuery]->equal(_column_ndx, ObjcStringAccessor(value), caseSensitive);
    return _query;
}
-(TightdbQuery *)notEqual:(NSString *)value
{
    [_query getQuery]->not_equal(_column_ndx, ObjcStringAccessor(value));
    return _query;
}
-(TightdbQuery *)notEqual:(NSString *)value caseSensitive:(BOOL)caseSensitive
{
    [_query getQuery]->not_equal(_column_ndx, ObjcStringAccessor(value), caseSensitive);
    return _query;
}
-(TightdbQuery *)beginsWith:(NSString *)value
{
    [_query getQuery]->begins_with(_column_ndx, ObjcStringAccessor(value));
    return _query;
}
-(TightdbQuery *)beginsWith:(NSString *)value caseSensitive:(BOOL)caseSensitive
{
    [_query getQuery]->begins_with(_column_ndx, ObjcStringAccessor(value), caseSensitive);
    return _query;
}
-(TightdbQuery *)endsWith:(NSString *)value
{
    [_query getQuery]->ends_with(_column_ndx, ObjcStringAccessor(value));
    return _query;
}
-(TightdbQuery *)endsWith:(NSString *)value caseSensitive:(BOOL)caseSensitive
{
    [_query getQuery]->ends_with(_column_ndx, ObjcStringAccessor(value), caseSensitive);
    return _query;
}
-(TightdbQuery *)contains:(NSString *)value
{
    [_query getQuery]->contains(_column_ndx, ObjcStringAccessor(value));
    return _query;
}
-(TightdbQuery *)contains:(NSString *)value caseSensitive:(BOOL)caseSensitive
{
    [_query getQuery]->contains(_column_ndx, ObjcStringAccessor(value), caseSensitive);
    return _query;
}
@end


@implementation TightdbQueryAccessorBinary
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}
-(TightdbQuery *)equal:(TightdbBinary *)value
{
    [_query getQuery]->equal(_column_ndx, [value getBinary]);
    return _query;
}
-(TightdbQuery *)notEqual:(TightdbBinary *)value
{
    [_query getQuery]->not_equal(_column_ndx, [value getBinary]);
    return _query;
}
-(TightdbQuery *)beginsWith:(TightdbBinary *)value
{
    [_query getQuery]->begins_with(_column_ndx, [value getBinary]);
    return _query;
}
-(TightdbQuery *)endsWith:(TightdbBinary *)value
{
    [_query getQuery]->ends_with(_column_ndx, [value getBinary]);
    return _query;
}
-(TightdbQuery *)contains:(TightdbBinary *)value
{
    [_query getQuery]->contains(_column_ndx, [value getBinary]);
    return _query;
}
@end


@implementation TightdbQueryAccessorDate
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}
-(TightdbQuery *)equal:(time_t)value
{
    [_query getQuery]->equal_date(_column_ndx, value);
    return _query;
}
-(TightdbQuery *)notEqual:(time_t)value
{
    [_query getQuery]->not_equal_date(_column_ndx, value);
    return _query;
}
-(TightdbQuery *)greater:(time_t)value
{
    [_query getQuery]->greater_date(_column_ndx, value);
    return _query;
}
-(TightdbQuery *)greaterEqual:(time_t)value
{
    [_query getQuery]->greater_equal_date(_column_ndx, value);
    return _query;
}
-(TightdbQuery *)less:(time_t)value
{
    [_query getQuery]->less_date(_column_ndx, value);
    return _query;
}
-(TightdbQuery *)lessEqual:(time_t)value
{
    [_query getQuery]->less_equal_date(_column_ndx, value);
    return _query;
}
-(TightdbQuery *)between:(time_t)from to:(time_t)to
{
    [_query getQuery]->between_date(_column_ndx, from, to);
    return _query;
}
@end


@implementation TightdbQueryAccessorSubtable
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}
@end


@implementation TightdbQueryAccessorMixed
{
    TightdbQuery *_query;
    size_t _column_ndx;
}
-(id)initWithColumn:(size_t)columnId query:(TightdbQuery *)query
{
    self = [super init];
    if (self) {
        _query = query;
        _column_ndx = columnId;
    }
    return self;
}
@end

