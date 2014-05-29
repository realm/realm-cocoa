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

#import "RLMRealm_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMObjectStore.h"
#import "RLMConstants.h"
#import "RLMQueryUtil.h"

#include <exception>
#include <sstream>

#include <tightdb/group_shared.hpp>
#include <tightdb/group.hpp>
#include <tightdb/util/unique_ptr.hpp>
#include <tightdb/lang_bind_helper.hpp>

using namespace std;
using namespace tightdb;
using namespace tightdb::util;

namespace {

// create NSException from c++ exception
void throw_objc_exception(exception &ex) {
    NSString *errorMessage = [NSString stringWithUTF8String:ex.what()];
    @throw [NSException exceptionWithName:@"RLMException" reason:errorMessage userInfo:nil];
}
 
// create NSError from c++ exception
inline NSError* make_realm_error(RLMError code, exception &ex) {
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    [details setValue:[NSString stringWithUTF8String:ex.what()] forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"io.realm" code:code userInfo:details];
}

} // anonymous namespace


// simple weak wrapper for a weak target timer
@interface RLMWeakTarget : NSObject
+ (instancetype)createWithRealm:(id)target;
@property (nonatomic, weak) RLMRealm *realm;
@end
@implementation RLMWeakTarget
+ (instancetype)createWithRealm:(RLMRealm *)realm {
    RLMWeakTarget *wt = [RLMWeakTarget new];
    wt.realm = realm;
    return wt;
}
- (void)checkForUpdate {
    [_realm performSelector:@selector(refresh)];
}
@end


//
//
// Global RLMRealm instance cache
//
//
static NSMutableDictionary *s_realmsPerPath;

// FIXME: In the following 3 functions, we should be identifying files by the inode,device number pair
//  rather than by the path (since the path is not a reliable identifier). This requires additional support
//  from the core library though, because the inode,device number pair needs to be taken from the open file
//  (to avoid race conditions).
inline RLMRealm *cachedRealm(NSString *path) {
    mach_port_t threadID = pthread_mach_thread_np(pthread_self());
    @synchronized(s_realmsPerPath) {
        return [s_realmsPerPath[path] objectForKey:@(threadID)];
    }
}

inline void cacheRealm(RLMRealm *realm, NSString *path) {
    mach_port_t threadID = pthread_mach_thread_np(pthread_self());
    @synchronized(s_realmsPerPath) {
        if (!s_realmsPerPath[path]) {
            s_realmsPerPath[path] = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsObjectPersonality valueOptions:NSPointerFunctionsWeakMemory];
        }
        [s_realmsPerPath[path] setObject:realm forKey:@(threadID)];
    }
}

inline NSArray *realmsAtPath(NSString *path) {
    @synchronized(s_realmsPerPath) {
        return [s_realmsPerPath[path] objectEnumerator].allObjects;
    }
}

inline void clearRealmCache() {
    @synchronized(s_realmsPerPath) {
        s_realmsPerPath = [NSMutableDictionary dictionary];
    }
}


@interface RLMRealm ()
@property (nonatomic) NSString *path;
@property (nonatomic) BOOL isReadOnly;
@property (nonatomic, readwrite) RLMSchema *schema;
@end


NSString *const c_defaultRealmFileName = @"default.realm";
static NSString *s_defaultRealmPath = nil;
static NSArray *s_objectDescriptors = nil;

@implementation RLMRealm {
    UniquePtr<SharedGroup> _sharedGroup;
    NSMapTable *_objects;
    NSRunLoop *_runLoop;
    NSTimer *_updateTimer;
    NSMutableArray *_notificationHandlers;
    
    tightdb::Group *_readGroup;
    tightdb::Group *_writeGroup;
}

+ (void)initialize {
    // set up global realm cache
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // initilize realm cache
        clearRealmCache();
        
        // initialize object store
        RLMInitializeObjectStore();
    });
}

- (instancetype)initWithPath:(NSString *)path readOnly:(BOOL)readonly {
    self = [super init];
    if (self) {
        _path = path;
        _runLoop = [NSRunLoop currentRunLoop];
        _objects = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaquePersonality
                                             valueOptions:NSPointerFunctionsWeakMemory
                                                 capacity:128];
        _notificationHandlers = [NSMutableArray array];
        _isReadOnly = readonly;
        _updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:[RLMWeakTarget createWithRealm:self]
                                                      selector:@selector(checkForUpdate)
                                                      userInfo:nil
                                                       repeats:YES];
    }
    return self;
}

+(NSString *)defaultPath
{
    return s_defaultRealmPath;
}

+ (NSString *)writeablePathForFile:(NSString*)fileName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

+ (instancetype)defaultRealm
{
    if (!s_defaultRealmPath) {
        s_defaultRealmPath = [RLMRealm writeablePathForFile:c_defaultRealmFileName];
    }
    return [RLMRealm realmWithPath:RLMRealm.defaultPath readOnly:NO error:nil];
}

+ (void)setDefaultRealmPath:(NSString *)path
{
    // if already set then throw
    @synchronized(s_realmsPerPath) {
        if (s_realmsPerPath.count) {
            @throw [NSException exceptionWithName:@"RLMException" reason:@"Can only set default realm path before creating or getting an RLMRealm instance" userInfo:nil];
        }
    }
    s_defaultRealmPath = path;
}

+ (void)useInMemoryDefaultRealm
{
    @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                   reason:@"Not yet implemented" userInfo:nil];
}

+ (instancetype)realmWithPath:(NSString *)path
{
    return [self realmWithPath:path readOnly:NO error:nil];
}

+ (instancetype)realmWithPath:(NSString *)path
                     readOnly:(BOOL)readonly
                        error:(NSError **)outError
{
    return [self realmWithPath:path readOnly:readonly dynamic:NO error:outError];
}

+ (instancetype)realmWithPath:(NSString *)path
                     readOnly:(BOOL)readonly
                      dynamic:(BOOL)dynamic
                        error:(NSError **)outError
{
    NSRunLoop *currentRunloop = [NSRunLoop currentRunLoop];
    if (!currentRunloop) {
        @throw [NSException exceptionWithName:@"realm:runloop_exception"
                                       reason:[NSString stringWithFormat:@"%@ \
                                               can only be called from a thread with a runloop. \
                                               Use an RLMTransactionManager read or write block \
                                               instead.", NSStringFromSelector(_cmd)] userInfo:nil];
    }

    // try to reuse existing realm first
    RLMRealm *realm = cachedRealm(path);
    if (realm) {
        // if already open with different read permissions then throw
        if (realm.isReadOnly != readonly) {
            @throw [NSException exceptionWithName:@"RLMException"
                                           reason:@"Realm at path already opened with different read permissions"
                                         userInfo:@{@"path":realm.path}];
        }
        return realm;
    }
    
    realm = [[RLMRealm alloc] initWithPath:path readOnly:readonly];
    if (!realm) {
        return nil;
    }
    
    NSError *error = nil;
    try {
        realm->_sharedGroup.reset(new SharedGroup(path.UTF8String));
    }
    catch (File::PermissionDenied &ex) {
        error = make_realm_error(RLMErrorFilePermissionDenied, ex);
    }
    catch (File::Exists &ex) {
        error = make_realm_error(RLMErrorFileExists, ex);
    }
    catch (File::AccessError &ex) {
        error = make_realm_error(RLMErrorFileAccessError, ex);
    }
    catch (exception &ex) {
        error = make_realm_error(RLMErrorFail, ex);
    }
    if (error) {
        if (outError) {
            *outError = error;
        }
        return nil;
    }
    
    if (dynamic) {
        // begin read transaction
        [realm beginReadTransaction];
        
        // for dynamic realms, get schema from stored tables
        realm.schema = [RLMSchema dynamicSchemaFromRealm:realm];
    }
    else {
        // set the schema for this realm
        realm.schema = [RLMSchema sharedSchema];
        
        // initialize object store for this realm
        RLMEnsureRealmTablesExist(realm);
        
        // cache main thread realm at this path
        cacheRealm(realm, path);
        
        // begin read transaction
        [realm beginReadTransaction];
    }
    
    return realm;
}

+ (void)clearRealmCache {
    clearRealmCache();
}

- (void)addNotificationBlock:(RLMNotificationBlock)block {
    [_notificationHandlers addObject:block];
}

- (void)removeNotificationBlock:(RLMNotificationBlock)block {
    [_notificationHandlers removeObject:block];
}

- (void)removeAllNotificationBlocks {
    [_notificationHandlers removeAllObjects];
}

- (void)sendNotifications {
    // call this realms notification blocks
    for (RLMNotificationBlock block in _notificationHandlers) {
        block(RLMRealmDidChangeNotification, self);
    }
}

- (RLMTransactionMode)transactionMode {
    if (_readGroup != NULL) {
        return RLMTransactionModeRead;
    }
    if (_writeGroup != NULL) {
        return RLMTransactionModeWrite;
    }
    return RLMTransactionModeNone;
    
}

- (void)beginReadTransaction {
    if (self.transactionMode == RLMTransactionModeNone) {
        try {
            _readGroup = (tightdb::Group *)&_sharedGroup->begin_read();
            [self updateAllObjects];
        }
        catch (exception &ex) {
            throw_objc_exception(ex);
        }
    }
}

- (void)endReadTransaction {
    if (self.transactionMode == RLMTransactionModeRead) {
        try {
            _sharedGroup->end_read();
            _readGroup = NULL;
        }
        catch (std::exception& ex) {
            throw_objc_exception(ex);
        }
    }
}

- (void)beginWriteTransaction {
    if (self.transactionMode != RLMTransactionModeWrite) {
        try {
            // if we are moving the transaction forward, send local notifications
            if (_sharedGroup->has_changed()) {
                [self sendNotifications];
            }
            
            // end current read
            [self endReadTransaction];
            
            // create group
            _writeGroup = &_sharedGroup->begin_write();
            
            // make all objects in this realm writable
            [self updateAllObjects];
        }
        catch (std::exception& ex) {
            // File access errors are treated as exceptions here since they should not occur after the shared
            // group has already been successfully opened on the file and memory mapped. The shared group constructor handles
            // the excepted error related to file access.
            throw_objc_exception(ex);
        }
    } else {
        @throw [NSException exceptionWithName:@"RLMException" reason:@"The Realm is already in a writetransaction" userInfo:nil];
    }
}

- (void)commitWriteTransaction {
    if (self.transactionMode == RLMTransactionModeWrite) {
        try {
            _sharedGroup->commit();
            _writeGroup = NULL;
            
            [self beginReadTransaction];

            // notify other realm istances of changes
            for (RLMRealm *realm in realmsAtPath(_path)) {
                if (![realm isEqual:self]) {
                    [realm->_runLoop performSelector:@selector(refresh) target:realm argument:nil order:0 modes:@[NSRunLoopCommonModes]];
                }
            }
            
            // send local notification
            [self sendNotifications];
        }
        catch (std::exception& ex) {
            throw_objc_exception(ex);
        }
    } else {
       @throw [NSException exceptionWithName:@"RLMException" reason:@"Can't commit a non-existing writetransaction" userInfo:nil];
    }
}

- (void)rollbackWriteTransaction {
    if (self.transactionMode == RLMTransactionModeWrite) {
        try {
            _sharedGroup->rollback();
            _writeGroup = NULL;
            
            [self beginReadTransaction];
        }
        catch (std::exception& ex) {
            throw_objc_exception(ex);
        }
    } else {
        @throw [NSException exceptionWithName:@"RLMException" reason:@"Can't roll-back a non-existing writetransaction" userInfo:nil];
    }
}

- (void)dealloc
{
    [_updateTimer invalidate];
    _updateTimer = nil;
    
    if (self.transactionMode == RLMTransactionModeWrite) {
        [self commitWriteTransaction];
        NSLog(@"A transaction was lacking explicit commit, but it has been auto committed.");
    }
    [self endReadTransaction];
}

- (void)refresh {
    try {
        // no-op if writing
        if (self.transactionMode == RLMTransactionModeWrite) {
            return;
        }
        
        // advance transaction if database has changed
        if (_sharedGroup->has_changed()) { // Throws
            [self endReadTransaction];
            [self beginReadTransaction];
            [self updateAllObjects];
            
            // send notification that someone else changed the realm
            [self sendNotifications];
        }
    }
    catch (exception &ex) {
        throw_objc_exception(ex);
    }
}

- (void)registerAccessor:(id<RLMAccessor>)accessor {
    [_objects setObject:accessor forKey:accessor];
}

- (void)updateAllObjects {
    try {
        // get the group
        tightdb::Group *group = self.group;
        BOOL writable = (self.transactionMode == RLMTransactionModeWrite);

        // refresh all outstanding objects
        for (id<RLMAccessor> obj in _objects.objectEnumerator.allObjects) {
            TableRef tableRef = group->get_table(obj.backingTableIndex); // Throws
            obj.backingTable = tableRef.get();
            obj.writable = writable;
        }
    }
    catch (exception &ex) {
        throw_objc_exception(ex);
    }
}

- (tightdb::Group *)group {
    return _writeGroup ? _writeGroup : _readGroup;
}

- (void)addObject:(RLMObject *)object {
    RLMAddObjectToRealm(object, self);
}

- (void)addObjectsFromArray:(id)array {
    for (RLMObject *obj in array) {
        [self addObject:obj];
    }
}

- (void)deleteObject:(RLMObject *)object {
    RLMDeleteObjectFromRealm(object);
}

- (RLMArray *)allObjects:(NSString *)objectClassName {
    return RLMGetObjects(self, objectClassName, nil, nil);
}

- (RLMArray *)objects:(NSString *)objectClassName where:(id)predicate, ... {
    NSPredicate *outPredicate = nil;
    if (predicate) {
        RLM_PREDICATE(predicate, outPredicate);
    }
    return RLMGetObjects(self, objectClassName, outPredicate, nil);
}

- (RLMArray *)objects:(NSString *)objectClassName orderedBy:(id)order where:(id)predicate, ... {
    NSPredicate *outPredicate = nil;
    if (predicate) {
        RLM_PREDICATE(predicate, outPredicate);
    }
    return RLMGetObjects(self, objectClassName, outPredicate, order);
}

-(NSUInteger)schemaVersion {
    // FIXME - store version in metadata table - will come with migration support
    return 0;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
-(id)objectForKeyedSubscript:(id <NSCopying>)key {
    @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                   reason:@"Not yet implemented" userInfo:nil];
}

-(void)setObject:(RLMObject *)obj forKeyedSubscript:(id <NSCopying>)key {
    @throw [NSException exceptionWithName:@"RLMNotImplementedException"
                                   reason:@"Not yet implemented" userInfo:nil];
}
#pragma GCC diagnostic pop


@end
