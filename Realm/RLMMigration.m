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

#import "RLMMigration_Private.h"
#import "RLMRealm_Private.hpp"

@interface RLMMigration ()
@property (nonatomic, strong) RLMRealm *realm;
@end

@implementation RLMMigration

+ (instancetype)migrationAtPath:(NSString *)path error:(NSError **)error {
    RLMMigration *migration = [RLMMigration new];
    migration.realm = [RLMRealm realmWithPath:path readOnly:NO dynamic:YES error:error];
    return migration;
}

- (NSUInteger)schemaVersion {
    return _realm.schemaVersion;
}

- (RLMSchema *)schema {
    return _realm.schema;
}

- (RLMArray *)allObjects:(NSString *)className {
    return [_realm allObjects:className];
}

@end
