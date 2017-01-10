////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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

#import "RLMHandover_Private.hpp"

#import "RLMRealm_Private.hpp"
#import "RLMUtil.hpp"
#import "shared_realm.hpp"

using namespace realm;

@implementation RLMThreadImport

- (instancetype)initWithRealm:(RLMRealm *)realm objects:(NSArray<id<RLMThreadConfined>> *)objects {
    if (self = [super init]) {
        _realm = realm;
        _objects = objects;
    }
    return self;
}

@end

@implementation RLMThreadHandover {
    NSMutableArray<id> *_metadata;
    NSMutableArray<Class> *_classes;
    util::Optional<Realm::HandoverPackage> _package;
    RLMRealmConfiguration *_configuration;
}

typedef NS_ENUM(bool, RLMErrorMode) {
    RLMErrorModeImport,
    RLMErrorModeExport
};

//
// validation helpers
//
[[gnu::noinline]]
[[noreturn]]
static void throwError(RLMErrorMode mode) {
    try {
        throw;
    }
    catch (realm::InvalidTransactionException const& exception) {
        @throw RLMException(@"Cannot %@ ThreadHandover inside of a write transaction",
                            mode == RLMErrorModeExport ? @"export" : @"import");
    }
    catch (realm::IncorrectThreadException const&) {
        @throw RLMException(@"Realm accessed from incorrect thread");
    }
    catch (std::exception const& ex) {
        @throw RLMException(ex);
    }
}

template<typename Function>
static auto translateErrors(Function&& f, RLMErrorMode mode) {
    try {
        return f();
    }
    catch (...) {
        throwError(mode);
    }
}

- (instancetype)initWithRealm:(RLMRealm *)realm objects:(NSArray<id<RLMThreadConfined>> *)objects {
    if (self = [super init]) {
        _metadata = [NSMutableArray arrayWithCapacity:objects.count];
        _classes = [NSMutableArray arrayWithCapacity:objects.count];

        std::vector<realm::AnyThreadConfined> handoverables;
        handoverables.reserve(objects.count);
        for (id<RLMThreadConfined, RLMThreadConfined_Private> object in objects) {
            if (![object conformsToProtocol:@protocol(RLMThreadConfined_Private)]) {
                if ([object conformsToProtocol:@protocol(RLMThreadConfined)]) {
                    @throw RLMException(@"Illegal custom conformance to `RLMThreadConfined` by `%@`", [object class]);
                }
                else {
                    @throw RLMException(@"Unexpected `%@` in array of expected `RLMThreadConfined` objects", [object class]);
                }
            }
            else if (realm != object.realm) {
                if (object.realm == nil) {
                    @throw RLMException(@"Illegal thread export of unmanaged object, which doesn't require export");
                }
                else {
                    @throw RLMException(@"Object must be exported by the Realm that manages it");
                }
            }
            handoverables.push_back(object.rlm_handoverData);
            [_metadata addObject:[object rlm_handoverMetadata] ?: [NSNull null]];
            [_classes addObject:[object class]];
        }
        _package = translateErrors([&] {
            return util::make_optional(realm->_realm->package_for_handover(handoverables));
        }, RLMErrorModeExport);
        _configuration = realm.configuration;
    }
    return self;
}

- (RLMThreadImport *)importOnCurrentThreadWithError:(NSError **)error {
    if (!_package) {
        @throw RLMException(@"Thread handover may not be imported more than once.");
    }
    REALM_ASSERT_DEBUG(_package->is_awaiting_import());

    RLMRealm *realm = [RLMRealm realmWithConfiguration:_configuration error:error];
    if (!realm) {
        _package = {};
        _metadata = nil;
        _classes = nil;
        _configuration = nil;
        return nil;
    }

    std::vector<AnyThreadConfined> handoverables = translateErrors([&] {
        return realm->_realm->accept_handover(std::move(*_package));
    }, RLMErrorModeImport);

    NSMutableArray<id<RLMThreadConfined>> *objects = [NSMutableArray arrayWithCapacity:handoverables.size()];
    for (NSUInteger i = 0; i < handoverables.size(); i++) {
        [objects addObject:[_classes[i] rlm_objectWithHandoverData:handoverables[i]
                                                          metadata:RLMCoerceToNil(_metadata[i]) inRealm:realm]];
    }

    _package = {};
    _metadata = nil;
    _classes = nil;
    _configuration = nil;
    return [[RLMThreadImport alloc] initWithRealm:realm objects:[NSArray arrayWithArray:objects]];
}

@end
