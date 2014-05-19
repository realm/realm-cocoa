////////////////////////////////////////////////////////////////////////////
//
// TIGHTDB CONFIDENTIAL
// __________________
//
//  [2011] - [2014] TightDB Inc
//  All Rights Reserved.
//
// NOTICE:  All information contained herein is, and remains
// the property of TightDB Incorporated and its suppliers,
// if any.  The intellectual and technical concepts contained
// herein are proprietary to TightDB Incorporated
// and its suppliers and may be covered by U.S. and Foreign Patents,
// patents in process, and are protected by trade secret or copyright law.
// Dissemination of this information or reproduction of this material
// is strictly forbidden unless prior written permission is obtained
// from TightDB Incorporated.
//
////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "RLMRealm.h"
#include <tightdb/table.hpp>

//
// Accessor Protocol
//

// implemented by all persisted objects
@protocol RLMAccessor <NSObject>

@property (nonatomic) RLMRealm *realm;
@property (nonatomic, assign) NSUInteger objectIndex;
@property (nonatomic, assign) NSUInteger backingTableIndex;
@property (nonatomic, assign) tightdb::Table *backingTable;
@property (nonatomic, assign) BOOL writable;

@end


//
// Accessors Class Creation/Caching
//

// initialize accessor cache
void RLMAccessorCacheInitialize();

// get accessor classes for an object class - generates classes if not cached
Class RLMAccessorClassForObjectClass(Class objectClass);
Class RLMReadOnlyAccessorClassForObjectClass(Class objectClass);
Class RLMInvalidAccessorClassForObjectClass(Class objectClass);
Class RLMInsertionAccessorClassForObjectClass(Class objectClass);



