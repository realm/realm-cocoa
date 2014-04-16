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

#import <Foundation/Foundation.h>

#include <tightdb/util/unique_ptr.hpp>
#include <tightdb/table.hpp>
#include <tightdb/descriptor.hpp>
#include <tightdb/table_view.hpp>
#include <tightdb/lang_bind_helper.hpp>

#import "TDBTable_noinst.h"
#import "TDBRow.h"
#import "TDBView_noinst.h"
#import "TDBQuery_noinst.h"
#import "PrivateTDB.h"
#import "util_noinst.hpp"


@implementation TDBView
{
    tightdb::util::UniquePtr<tightdb::TableView> m_view;
    TDBTable* m_table;
    TDBRow* m_tmp_row;
    BOOL m_read_only;
}

+(TDBView*)viewWithTable:(TDBTable*)table andNativeView:(const tightdb::TableView&)view
{
    TDBView* view_2 = [[TDBView alloc] init];
    if (!view_2)
        return nil;
    view_2->m_view.reset(new tightdb::TableView(view)); // FIXME: Exception handling needed here
    view_2->m_table = table;
    view_2->m_read_only = [table isReadOnly];

    return view_2;
}

-(id)_initWithQuery:(RLMQuery *)query
{
    self = [super init];
    if (self) {
        tightdb::Query& query_2 = [query getNativeQuery];
        m_view.reset(new tightdb::TableView(query_2.find_all())); // FIXME: Exception handling needed here
        m_table = [query originTable];
        m_read_only = [m_table isReadOnly];
    }
    return self;
}

-(TDBTable*)originTable // Synthesize property
{
    return m_table;
}

-(void)dealloc
{
#ifdef TIGHTDB_DEBUG
    // NSLog(@"TDBView dealloc");
#endif
    m_table = nil; // FIXME: What is the point of doing this?
}

-(TDBRow *)objectAtIndexedSubscript:(NSUInteger)ndx
{
    // The cursor constructor checks the index is in bounds. However, getSourceIndex should
    // not be called with illegal index.

    if (ndx >= self.rowCount)
        return nil;

    return [[TDBRow alloc] initWithTable:m_table ndx:[self rowIndexInOriginTableForRowAtIndex:ndx]];
}

-(TDBRow*)rowAtIndex:(NSUInteger)ndx
{
    // The cursor constructor checks the index is in bounds. However, getSourceIndex should
    // not be called with illegal index.

    if (ndx >= self.rowCount)
        return nil;

    return [[TDBRow alloc] initWithTable:m_table ndx:[self rowIndexInOriginTableForRowAtIndex:ndx]];
}

-(TDBRow *)firstRow
{
    if (self.rowCount == 0) {
        return nil;
    }
    return [[TDBRow alloc] initWithTable:m_table ndx:[self rowIndexInOriginTableForRowAtIndex:0]];
}

-(TDBRow *)lastRow
{
    if (self.rowCount == 0) {
        return nil;
    }
    return [[TDBRow alloc] initWithTable:m_table ndx:[self rowIndexInOriginTableForRowAtIndex:self.rowCount-1]];
}

-(NSUInteger)rowCount
{
    return m_view->size();
}

-(NSUInteger)columnCount
{
    return m_view->get_column_count();
}

-(TDBType)columnTypeOfColumnWithIndex:(NSUInteger)colNdx
{
    TIGHTDB_EXCEPTION_HANDLER_COLUMN_INDEX_VALID(colNdx);
    return TDBType(m_view->get_column_type(colNdx));
}

-(void)sortUsingColumnWithIndex:(NSUInteger)colIndex
{
    [self sortUsingColumnWithIndex:colIndex inOrder:TDBAscending];
}

-(void)sortUsingColumnWithIndex:(NSUInteger)colIndex  inOrder: (TDBSortOrder)order
{
    TDBType columnType = [self columnTypeOfColumnWithIndex:colIndex];

    if(columnType != TDBIntType && columnType != TDBBoolType && columnType != TDBDateType) {
        @throw [NSException exceptionWithName:@"tightdb:sort_on_column_with_type_not_supported"
                                       reason:@"Sort is currently only supported on Integer, Boolean and Date columns."
                                     userInfo:nil];
    }

    try {
        m_view->sort(colIndex, order == 0);
    } catch(std::exception& ex) {
        @throw [NSException exceptionWithName:@"tightdb:core_exception"
                                       reason:[NSString stringWithUTF8String:ex.what()]
                                     userInfo:nil];
    }
}

-(BOOL)TDB_boolInColumnWithIndex:(NSUInteger)colIndex atRowIndex:(NSUInteger)rowIndex
{
    return m_view->get_bool(colIndex, rowIndex);
}
-(NSDate *)TDB_dateInColumnWithIndex:(NSUInteger)colIndex atRowIndex:(NSUInteger)rowIndex
{
    return [NSDate dateWithTimeIntervalSince1970:m_view->get_datetime(colIndex, rowIndex).get_datetime()];
}
-(double)TDB_doubleInColumnWithIndex:(NSUInteger)colIndex atRowIndex:(NSUInteger)rowIndex
{
    return m_view->get_double(colIndex, rowIndex);
}
-(float)TDB_floatInColumnWithIndex:(NSUInteger)colIndex atRowIndex:(NSUInteger)rowIndex
{
    return m_view->get_float(colIndex, rowIndex);
}
-(int64_t)TDB_intInColumnWithIndex:(NSUInteger)colIndex atRowIndex:(NSUInteger)rowIndex
{
    return m_view->get_int(colIndex, rowIndex);
}
-(id)TDB_mixedInColumnWithIndex:(NSUInteger)colNdx atRowIndex:(NSUInteger)rowIndex
{
    tightdb::Mixed mixed = m_view->get_mixed(colNdx, rowIndex);
    if (mixed.get_type() != tightdb::type_Table)
        return to_objc_object(mixed);

    tightdb::TableRef table = m_view->get_subtable(colNdx, rowIndex);
    TIGHTDB_ASSERT(table);
    TDBTable* table_2 = [[TDBTable alloc] _initRaw];
    if (TIGHTDB_UNLIKELY(!table_2))
        return nil;
    [table_2 setNativeTable:table.get()];
    [table_2 setParent:self];
    [table_2 setReadOnly:m_read_only];
    if (![table_2 _checkType])
        return nil;

    return table_2;
}

-(NSString*)TDB_stringInColumnWithIndex:(NSUInteger)colIndex atRowIndex:(NSUInteger)rowIndex
{
    return to_objc_string(m_view->get_string(colIndex, rowIndex));
}


-(void)removeRowAtIndex:(NSUInteger)rowIndex
{
    if (m_read_only) {
        @throw [NSException exceptionWithName:@"tightdb:table_view_is_read_only"
                                       reason:@"You tried to modify an immutable tableview"
                                     userInfo:nil];
    }

    m_view->remove(rowIndex);
}
-(void)removeAllRows
{
    if (m_read_only) {
        @throw [NSException exceptionWithName:@"tightdb:table_view_is_read_only"
                                       reason:@"You tried to modify an immutable tableview"
                                     userInfo:nil];
    }

    m_view->clear();
}
-(NSUInteger)rowIndexInOriginTableForRowAtIndex:(NSUInteger)rowIndex
{
    return m_view->get_source_ndx(rowIndex);
}

-(TDBRow*)getRow
{
    return m_tmp_row = [[TDBRow alloc] initWithTable: m_table
                                                 ndx: m_view->get_source_ndx(0)];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id __unsafe_unretained*)stackbuf count:(NSUInteger)len
{
    static_cast<void>(len);
    if(state->state == 0) {
        const unsigned long* ptr = static_cast<const unsigned long*>(objc_unretainedPointer(self));
        state->mutationsPtr = const_cast<unsigned long*>(ptr); // FIXME: This casting away of constness seems dangerous. Is it?
        TDBRow* tmp = [self getRow];
        *stackbuf = tmp;
    }
    if (state->state < self.rowCount) {
        [((TDBRow*)*stackbuf) TDB_setNdx:[self rowIndexInOriginTableForRowAtIndex:state->state]];
        state->itemsPtr = stackbuf;
        state->state++;
    }
    else {
        *stackbuf = nil;
        state->itemsPtr = nil;
        state->mutationsPtr = nil;
        return 0;
    }
    return 1;
}

- (RLMQuery *)where
{
    RLMQuery *query = [[RLMQuery alloc] initWithTable:self.originTable error:nil];
    [query setTableView:*m_view];
    return query;
}

@end

