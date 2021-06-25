////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMResults_Private.hpp"

#import "RLMAccessor.hpp"
#import "RLMArray_Private.hpp"
#import "RLMCollection_Private.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMObjectStore.h"
#import "RLMObject_Private.hpp"
#import "RLMObservation.hpp"
#import "RLMProperty_Private.h"
#import "RLMQueryUtil.hpp"
#import "RLMRealm_Private.hpp"
#import "RLMRealmConfiguration_Private.hpp"
#import "RLMSchema_Private.h"
#import "RLMThreadSafeReference_Private.hpp"
#import "RLMUtil.hpp"

#import <realm/object-store/results.hpp>
#import <realm/object-store/shared_realm.hpp>
#import <realm/table_view.hpp>

#import <objc/message.h>

using namespace realm;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation RLMNotificationToken
@end
#pragma clang diagnostic pop

@interface RLMResults () <RLMThreadConfined_Private>
@end

//
// RLMResults implementation
//
@implementation RLMResults {
    RLMRealm *_realm;
    RLMClassInfo *_info;
}

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

- (instancetype)initWithResults:(Results)results {
    if (self = [super init]) {
        _results = std::move(results);
    }
    return self;
}

static void assertKeyPathIsNotNested(NSString *keyPath) {
    if ([keyPath rangeOfString:@"."].location != NSNotFound) {
        @throw RLMException(@"Nested key paths are not supported yet for KVC collection operators.");
    }
}

void RLMThrowResultsError(NSString *aggregateMethod) {
    try {
        throw;
    }
    catch (realm::InvalidTransactionException const&) {
        @throw RLMException(@"Cannot modify Results outside of a write transaction.");
    }
    catch (realm::IncorrectThreadException const&) {
        @throw RLMException(@"Realm accessed from incorrect thread.");
    }
    catch (realm::Results::InvalidatedException const&) {
        @throw RLMException(@"RLMResults has been invalidated.");
    }
    catch (realm::Results::DetatchedAccessorException const&) {
        @throw RLMException(@"Object has been invalidated.");
    }
    catch (realm::Results::IncorrectTableException const& e) {
        @throw RLMException(@"Object of type '%s' does not match RLMResults type '%s'.",
                            e.actual.data(), e.expected.data());
    }
    catch (realm::Results::OutOfBoundsIndexException const& e) {
        @throw RLMException(@"Index %zu is out of bounds (must be less than %zu).",
                            e.requested, e.valid_count);
    }
    catch (realm::Results::UnsupportedColumnTypeException const& e) {
        @throw RLMException(@"%@ is not supported for %s%s property '%s'.",
                            aggregateMethod,
                            string_for_property_type(e.property_type),
                            is_nullable(e.property_type) ? "?" : "",
                            e.column_name.data());
    }
    catch (std::exception const& e) {
        @throw RLMException(e);
    }
}

- (instancetype)initWithObjectInfo:(RLMClassInfo&)info
                           results:(realm::Results&&)results {
    if (self = [super init]) {
        _results = std::move(results);
        _realm = info.realm;
        _info = &info;
    }
    return self;
}

+ (instancetype)resultsWithObjectInfo:(RLMClassInfo&)info
                              results:(realm::Results&&)results {
    return [[self alloc] initWithObjectInfo:info results:std::move(results)];
}

+ (instancetype)emptyDetachedResults {
    return [[self alloc] initPrivate];
}

- (instancetype)subresultsWithResults:(realm::Results)results {
    return [self.class resultsWithObjectInfo:*_info results:std::move(results)];
}

static inline void RLMResultsValidateInWriteTransaction(__unsafe_unretained RLMResults *const ar) {
    ar->_realm->_realm->verify_thread();
    ar->_realm->_realm->verify_in_write();
}

- (BOOL)isInvalidated {
    return translateRLMResultsErrors([&] { return !_results.is_valid(); });
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] { return _results.size(); });
}

- (RLMPropertyType)type {
    return translateRLMResultsErrors([&] {
        return static_cast<RLMPropertyType>(_results.get_type() & ~realm::PropertyType::Nullable);
    });
}

- (BOOL)isOptional {
    return translateRLMResultsErrors([&] {
        return is_nullable(_results.get_type());
    });
}

- (NSString *)objectClassName {
    return translateRLMResultsErrors([&] {
        if (_info && _results.get_type() == realm::PropertyType::Object) {
            return _info->rlmObjectSchema.className;
        }
        return (NSString *)nil;
    });
}

- (RLMClassInfo *)objectInfo {
    return _info;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    if (!_info) {
        return 0;
    }
    if (state->state == 0) {
        translateRLMResultsErrors([&] {
            _results.evaluate_query_if_needed();
        });
    }
    return RLMFastEnumerate(state, len, self);
}

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    NSUInteger index = [self indexOfObjectWhere:predicateFormat args:args];
    va_end(args);
    return index;
}

- (NSUInteger)indexOfObjectWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self indexOfObjectWithPredicate:[NSPredicate predicateWithFormat:predicateFormat
                                                                   arguments:args]];
}

- (NSUInteger)indexOfObjectWithPredicate:(NSPredicate *)predicate {
    if (_results.get_mode() == Results::Mode::Empty) {
        return NSNotFound;
    }

    return translateRLMResultsErrors([&] {
        if (_results.get_type() != realm::PropertyType::Object) {
            @throw RLMException(@"Querying is currently only implemented for arrays of Realm Objects");
        }
        return RLMConvertNotFound(_results.index_of(RLMPredicateToQuery(predicate, _info->rlmObjectSchema, _realm.schema, _realm.group)));
    });
}

- (id)objectAtIndex:(NSUInteger)index {
    RLMAccessorContext ctx(*_info);
    return translateRLMResultsErrors([&] {
        return _results.get(ctx, index);
    });
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    if (!_info) {
        return nil;
    }
    size_t c = self.count;
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:indexes.count];
    NSUInteger i = [indexes firstIndex];
    RLMAccessorContext context(*_info);
    while (i != NSNotFound) {
        if (i >= 0 && i < c) {
            [result addObject:_results.get(context, i)];
        } else {
            return nil;
        }
        i = [indexes indexGreaterThanIndex:i];
    }
    return result;
}

- (id)firstObject {
    if (!_info) {
        return nil;
    }
    RLMAccessorContext ctx(*_info);
    return translateRLMResultsErrors([&] {
        return _results.first(ctx);
    });
}

- (id)lastObject {
    if (!_info) {
        return nil;
    }
    RLMAccessorContext ctx(*_info);
    return translateRLMResultsErrors([&] {
        return _results.last(ctx);
    });
}

- (NSUInteger)indexOfObject:(id)object {
    if (!_info || !object) {
        return NSNotFound;
    }
    if (RLMObjectBase *obj = RLMDynamicCast<RLMObjectBase>(object)) {
        // Unmanaged objects are considered not equal to all managed objects
        if (!obj->_realm && !obj.invalidated) {
            return NSNotFound;
        }
    }
    RLMAccessorContext ctx(*_info);
    return translateRLMResultsErrors([&] {
        return RLMConvertNotFound(_results.index_of(ctx, object));
    });
}

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath characterAtIndex:0] != '@') {
        return [super valueForKeyPath:keyPath];
    }
    if ([keyPath isEqualToString:@"@count"]) {
        return @(self.count);
    }

    NSRange operatorRange = [keyPath rangeOfString:@"." options:NSLiteralSearch];
    NSUInteger keyPathLength = keyPath.length;
    NSUInteger separatorIndex = operatorRange.location != NSNotFound ? operatorRange.location : keyPathLength;
    NSString *operatorName = [keyPath substringWithRange:NSMakeRange(1, separatorIndex - 1)];
    SEL opSelector = NSSelectorFromString([NSString stringWithFormat:@"_%@ForKeyPath:", operatorName]);
    if (![self respondsToSelector:opSelector]) {
        @throw RLMException(@"Unsupported KVC collection operator found in key path '%@'", keyPath);
    }
    if (separatorIndex >= keyPathLength - 1) {
        @throw RLMException(@"Missing key path for KVC collection operator %@ in key path '%@'",
                            operatorName, keyPath);
    }
    NSString *operatorKeyPath = [keyPath substringFromIndex:separatorIndex + 1];
    return ((id(*)(id, SEL, id))objc_msgSend)(self, opSelector, operatorKeyPath);
}

- (id)valueForKey:(NSString *)key {
    if (!_info) {
        return @[];
    }
    return translateRLMResultsErrors([&] {
        return RLMCollectionValueForKey(_results, key, *_info);
    });
}

- (void)setValue:(id)value forKey:(NSString *)key {
    translateRLMResultsErrors([&] { RLMResultsValidateInWriteTransaction(self); });
    RLMCollectionSetValueForKey(self, key, value);
}

- (NSNumber *)_aggregateForKeyPath:(NSString *)keyPath
                            method:(util::Optional<Mixed> (Results::*)(ColKey))method
                        methodName:(NSString *)methodName returnNilForEmpty:(BOOL)returnNilForEmpty {
    assertKeyPathIsNotNested(keyPath);
    return [self aggregate:keyPath method:method methodName:methodName returnNilForEmpty:returnNilForEmpty];
}

- (NSNumber *)_minForKeyPath:(NSString *)keyPath {
    return [self _aggregateForKeyPath:keyPath method:&Results::min methodName:@"@min" returnNilForEmpty:YES];
}

- (NSNumber *)_maxForKeyPath:(NSString *)keyPath {
    return [self _aggregateForKeyPath:keyPath method:&Results::max methodName:@"@max" returnNilForEmpty:YES];
}

- (NSNumber *)_sumForKeyPath:(NSString *)keyPath {
    return [self _aggregateForKeyPath:keyPath method:&Results::sum methodName:@"@sum" returnNilForEmpty:NO];
}

- (NSNumber *)_avgForKeyPath:(NSString *)keyPath {
    assertKeyPathIsNotNested(keyPath);
    return [self averageOfProperty:keyPath];
}

- (NSArray *)_unionOfObjectsForKeyPath:(NSString *)keyPath {
    assertKeyPathIsNotNested(keyPath);
    return translateRLMResultsErrors([&] {
        return RLMCollectionValueForKey(_results, keyPath, *_info);
    });
}

- (NSArray *)_distinctUnionOfObjectsForKeyPath:(NSString *)keyPath {
    return [NSSet setWithArray:[self _unionOfObjectsForKeyPath:keyPath]].allObjects;
}

- (NSArray *)_unionOfArraysForKeyPath:(NSString *)keyPath {
    assertKeyPathIsNotNested(keyPath);
    if ([keyPath isEqualToString:@"self"]) {
        @throw RLMException(@"self is not a valid key-path for a KVC array collection operator as 'unionOfArrays'.");
    }

    return translateRLMResultsErrors([&] {
        NSMutableArray *flatArray = [NSMutableArray new];
        for (id<NSFastEnumeration> array in RLMCollectionValueForKey(_results, keyPath, *_info)) {
            for (id value in array) {
                [flatArray addObject:value];
            }
        }
        return flatArray;
    });
}

- (NSArray *)_distinctUnionOfArraysForKeyPath:(__unused NSString *)keyPath {
    return [NSSet setWithArray:[self _unionOfArraysForKeyPath:keyPath]].allObjects;
}

- (RLMResults *)objectsWhere:(NSString *)predicateFormat, ... {
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objectsWhere:predicateFormat args:args];
    va_end(args);
    return results;
}

- (RLMResults *)objectsWhere:(NSString *)predicateFormat args:(va_list)args {
    return [self objectsWithPredicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (RLMResults *)objectsWithPredicate:(NSPredicate *)predicate {
    return translateRLMResultsErrors([&] {
        if (_results.get_mode() == Results::Mode::Empty) {
            return self;
        }
        if (_results.get_type() != realm::PropertyType::Object) {
            @throw RLMException(@"Querying is currently only implemented for arrays of Realm Objects");
        }
        auto query = RLMPredicateToQuery(predicate, _info->rlmObjectSchema, _realm.schema, _realm.group);
        return [self subresultsWithResults:_results.filter(std::move(query))];
    });
}

- (RLMResults *)sortedResultsUsingKeyPath:(NSString *)keyPath ascending:(BOOL)ascending {
    return [self sortedResultsUsingDescriptors:@[[RLMSortDescriptor sortDescriptorWithKeyPath:keyPath ascending:ascending]]];
}

- (RLMResults *)sortedResultsUsingDescriptors:(NSArray<RLMSortDescriptor *> *)properties {
    if (properties.count == 0) {
        return self;
    }
    return translateRLMResultsErrors([&] {
        if (_results.get_mode() == Results::Mode::Empty) {
            return self;
        }
        return [self subresultsWithResults:_results.sort(RLMSortDescriptorsToKeypathArray(properties))];
    });
}

- (RLMResults *)distinctResultsUsingKeyPaths:(NSArray<NSString *> *)keyPaths {
    for (NSString *keyPath in keyPaths) {
        if ([keyPath rangeOfString:@"@"].location != NSNotFound) {
            @throw RLMException(@"Cannot distinct on keypath '%@': KVC collection operators are not supported.", keyPath);
        }
    }
    
    return translateRLMResultsErrors([&] {
        if (_results.get_mode() == Results::Mode::Empty) {
            return self;
        }
        
        std::vector<std::string> keyPathsVector;
        for (NSString *keyPath in keyPaths) {
            keyPathsVector.push_back(keyPath.UTF8String);
        }
        
        return [self subresultsWithResults:_results.distinct(keyPathsVector)];
    });
}

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

- (id)aggregate:(NSString *)property method:(util::Optional<Mixed> (Results::*)(ColKey))method
     methodName:(NSString *)methodName returnNilForEmpty:(BOOL)returnNilForEmpty {
    if (_results.get_mode() == Results::Mode::Empty) {
        return returnNilForEmpty ? nil : @0;
    }
    ColKey column;
    if (self.type == RLMPropertyTypeObject || ![property isEqualToString:@"self"]) {
        column = _info->tableColumn(property);
    }

    auto value = translateRLMResultsErrors([&] { return (_results.*method)(column); }, methodName);
    return value ? RLMMixedToObjc(*value) : nil;
}

- (id)minOfProperty:(NSString *)property {
    return [self aggregate:property method:&Results::min
                methodName:@"minOfProperty" returnNilForEmpty:YES];
}

- (id)maxOfProperty:(NSString *)property {
    return [self aggregate:property method:&Results::max
                methodName:@"maxOfProperty" returnNilForEmpty:YES];
}

- (id)sumOfProperty:(NSString *)property {
    return [self aggregate:property method:&Results::sum
                methodName:@"sumOfProperty" returnNilForEmpty:NO];
}

- (id)averageOfProperty:(NSString *)property {
    if (_results.get_mode() == Results::Mode::Empty) {
        return nil;
    }
    ColKey column;
    if (self.type == RLMPropertyTypeObject || ![property isEqualToString:@"self"]) {
        column = _info->tableColumn(property);
    }
    auto value = translateRLMResultsErrors([&] { return _results.average(column); }, @"averageOfProperty");
    return value ? RLMMixedToObjc(*value) : nil;
}

- (void)deleteObjectsFromRealm {
    if (self.type != RLMPropertyTypeObject) {
        @throw RLMException(@"Cannot delete objects from RLMResults<%@>: only RLMObjects can be deleted.",
                            RLMTypeToString(self.type));
    }
    return translateRLMResultsErrors([&] {
        if (_results.get_mode() == Results::Mode::Table) {
            RLMResultsValidateInWriteTransaction(self);
            RLMClearTable(*_info);
        }
        else {
            RLMObservationTracker tracker(_realm, true);
            _results.clear();
        }
    });
}

- (NSString *)description {
    return RLMDescriptionWithMaxDepth(@"RLMResults", self, RLMDescriptionMaxDepth);
}

- (realm::TableView)tableView {
    return translateRLMResultsErrors([&] { return _results.get_tableview(); });
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateRLMResultsErrors([&] {
        return [[RLMFastEnumerator alloc] initWithResults:_results collection:self
                                                classInfo:*_info];
    });
}

- (RLMResults *)snapshot {
    return translateRLMResultsErrors([&] {
        return [self subresultsWithResults:_results.snapshot()];
    });
}

- (instancetype)freeze {
    if (self.frozen) {
        return self;
    }

    RLMRealm *frozenRealm = [_realm freeze];
    return translateRLMResultsErrors([&] {
        return [self.class resultsWithObjectInfo:_info->resolve(frozenRealm)
                                         results:_results.freeze(frozenRealm->_realm)];
    });
}

- (BOOL)isFrozen {
    return _realm.frozen;
}

- (instancetype)thaw {
    if (!self.frozen) {
        return self;
    }

    RLMRealm *liveRealm = [_realm thaw];
    return translateRLMResultsErrors([&] {
        return [self.class resultsWithObjectInfo:_info->resolve(liveRealm)
                                         results:_results.freeze(liveRealm->_realm)];
    });
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMResults *, RLMCollectionChange *, NSError *))block {
    return RLMAddNotificationBlock(self, block, nil);
}
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMResults *, RLMCollectionChange *, NSError *))block queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, block, queue);
}
#pragma clang diagnostic pop

realm::Results& RLMGetBackingCollection(RLMResults *self) {
    return self->_results;
}

- (BOOL)isAttached {
    return !!_realm;
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _results;
}

- (id)objectiveCMetadata {
    return nil;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(__unused id)metadata
                                        realm:(RLMRealm *)realm {
    auto results = reference.resolve<Results>(realm->_realm);
    return [RLMResults resultsWithObjectInfo:realm->_info[RLMStringDataToNSString(results.get_object_type())]
                                     results:std::move(results)];
}

@end

@implementation RLMLinkingObjects
- (NSString *)description {
    return RLMDescriptionWithMaxDepth(@"RLMLinkingObjects", self, RLMDescriptionMaxDepth);
}
@end
