////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
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

#import "RLMRealmConfiguration_Private.hpp"

#import "RLMIvarStorage.hpp"
#import "RLMObjectSchema_Private.hpp"
#import "RLMRealm_Private.h"
#import "RLMSchema_Private.hpp"
#import "RLMUtil.hpp"

#import <realm/object-store/schema.hpp>
#import <realm/object-store/shared_realm.hpp>

#if REALM_ENABLE_SYNC
#import <realm/sync/config.hpp>
#else
@class RLMSyncConfiguration;
#endif

static NSString *const c_RLMRealmConfigurationProperties[] = {
    @"fileURL",
    @"inMemoryIdentifier",
    @"encryptionKey",
    @"readOnly",
    @"schemaVersion",
    @"migrationBlock",
    @"deleteRealmIfMigrationNeeded",
    @"shouldCompactOnLaunch",
    @"dynamic",
    @"customSchema",
};

static NSString *const c_defaultRealmFileName = @"default.realm";
RLMRealmConfiguration *s_defaultConfiguration;

NSString *RLMRealmPathForFileAndBundleIdentifier(NSString *fileName, NSString *bundleIdentifier) {
    return [RLMDefaultDirectoryForBundleIdentifier(bundleIdentifier)
            stringByAppendingPathComponent:fileName];
}

NSString *RLMRealmPathForFile(NSString *fileName) {
    static NSString *directory = RLMDefaultDirectoryForBundleIdentifier(nil);
    return [directory stringByAppendingPathComponent:fileName];
}

@implementation RLMRealmConfiguration {
    RLMIvar<realm::Realm::Config> _config;
}

- (realm::Realm::Config&)config {
    return _config;
}

+ (instancetype)defaultConfiguration {
    return [[self rawDefaultConfiguration] copy];
}

+ (void)setDefaultConfiguration:(RLMRealmConfiguration *)configuration {
    if (!configuration) {
        @throw RLMException(@"Cannot set the default configuration to nil.");
    }
    @synchronized(c_defaultRealmFileName) {
        s_defaultConfiguration = [configuration copy];
    }
}

+ (RLMRealmConfiguration *)rawDefaultConfiguration {
    RLMRealmConfiguration *configuration;
    @synchronized(c_defaultRealmFileName) {
        if (!s_defaultConfiguration) {
            s_defaultConfiguration = [[RLMRealmConfiguration alloc] init];
        }
        configuration = s_defaultConfiguration;
    }
    return configuration;
}

+ (void)resetRealmConfigurationState {
    @synchronized(c_defaultRealmFileName) {
        s_defaultConfiguration = nil;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        static NSURL *defaultRealmURL = [NSURL fileURLWithPath:RLMRealmPathForFile(c_defaultRealmFileName)];
        self.fileURL = defaultRealmURL;
        self.schemaVersion = 0;
        self.cache = YES;
    }

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    RLMRealmConfiguration *configuration = [[[self class] allocWithZone:zone] init];
    configuration->_config = _config;
    configuration->_cache = _cache;
    configuration->_dynamic = _dynamic;
    configuration->_migrationBlock = _migrationBlock;
    configuration->_shouldCompactOnLaunch = _shouldCompactOnLaunch;
    configuration->_customSchema = _customSchema;
    return configuration;
}

- (NSString *)description {
    NSMutableString *string = [NSMutableString stringWithFormat:@"%@ {\n", self.class];
    for (NSString *key : c_RLMRealmConfigurationProperties) {
        NSString *description = [[self valueForKey:key] description];
        description = [description stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"];

        [string appendFormat:@"\t%@ = %@;\n", key, description];
    }
    return [string stringByAppendingString:@"}"];
}

- (NSURL *)fileURL {
    if (_config->in_memory) {
        return nil;
    }
    return [NSURL fileURLWithPath:@(_config->path.c_str())];
}

- (void)setFileURL:(NSURL *)fileURL {
    NSString *path = fileURL.path;
    if (path.length == 0) {
        @throw RLMException(@"Realm path must not be empty");
    }

    RLMNSStringToStdString(_config->path, path);
    _config->in_memory = false;
}

- (NSString *)inMemoryIdentifier {
    if (!_config->in_memory) {
        return nil;
    }
    return [@(_config->path.c_str()) lastPathComponent];
}

- (void)setInMemoryIdentifier:(NSString *)inMemoryIdentifier {
    if (inMemoryIdentifier.length == 0) {
        @throw RLMException(@"In-memory identifier must not be empty");
    }
    _config->sync_config = nullptr;

    RLMNSStringToStdString(_config->path, [NSTemporaryDirectory() stringByAppendingPathComponent:inMemoryIdentifier]);
    _config->in_memory = true;
}

- (NSData *)encryptionKey {
    return _config->encryption_key.empty() ? nil : [NSData dataWithBytes:_config->encryption_key.data() length:_config->encryption_key.size()];
}

- (void)setEncryptionKey:(NSData * __nullable)encryptionKey {
    if (NSData *key = RLMRealmValidatedEncryptionKey(encryptionKey)) {
        auto bytes = static_cast<const char *>(key.bytes);
        _config->encryption_key.assign(bytes, bytes + key.length);
#if REALM_ENABLE_SYNC
        if (_config->sync_config) {
            auto& sync_encryption_key = self.config.sync_config->realm_encryption_key;
            sync_encryption_key = std::array<char, 64>();
            std::copy_n(_config->encryption_key.begin(), 64, sync_encryption_key->begin());
        }
#endif
    }
    else {
        _config->encryption_key.clear();
#if REALM_ENABLE_SYNC
        if (_config->sync_config)
            _config->sync_config->realm_encryption_key = realm::util::none;
#endif
    }
}

- (BOOL)readOnly {
    return _config->immutable() || _config->read_only_alternative();
}

static bool isSync(realm::Realm::Config const& config) {
#if REALM_ENABLE_SYNC
    return !!config.sync_config;
#endif
    return false;
}

- (void)updateSchemaMode {
    if (self.deleteRealmIfMigrationNeeded) {
        if (isSync(_config)) {
            @throw RLMException(@"Cannot set 'deleteRealmIfMigrationNeeded' when sync is enabled ('syncConfig' is set).");
        }
    }
    else if (self.readOnly) {
        _config->schema_mode = isSync(_config) ? realm::SchemaMode::ReadOnlyAlternative : realm::SchemaMode::Immutable;
    }
    else if (isSync(_config)) {
        if (_customSchema) {
            _config->schema_mode = realm::SchemaMode::AdditiveExplicit;
        }
        else {
            _config->schema_mode = realm::SchemaMode::AdditiveDiscovered;
        }
    }
    else {
        _config->schema_mode = realm::SchemaMode::Automatic;
    }
}

- (void)setReadOnly:(BOOL)readOnly {
    if (readOnly) {
        if (self.deleteRealmIfMigrationNeeded) {
            @throw RLMException(@"Cannot set `readOnly` when `deleteRealmIfMigrationNeeded` is set.");
        } else if (self.shouldCompactOnLaunch) {
            @throw RLMException(@"Cannot set `readOnly` when `shouldCompactOnLaunch` is set.");
        }
        _config->schema_mode = isSync(_config) ? realm::SchemaMode::ReadOnlyAlternative : realm::SchemaMode::Immutable;
    }
    else if (self.readOnly) {
        _config->schema_mode = realm::SchemaMode::Automatic;
        [self updateSchemaMode];
    }
}

- (uint64_t)schemaVersion {
    return _config->schema_version;
}

- (void)setSchemaVersion:(uint64_t)schemaVersion {
    if (schemaVersion == RLMNotVersioned) {
        @throw RLMException(@"Cannot set schema version to %llu (RLMNotVersioned)", RLMNotVersioned);
    }
    _config->schema_version = schemaVersion;
}

- (BOOL)deleteRealmIfMigrationNeeded {
    return _config->schema_mode == realm::SchemaMode::ResetFile;
}

- (void)setDeleteRealmIfMigrationNeeded:(BOOL)deleteRealmIfMigrationNeeded {
    if (deleteRealmIfMigrationNeeded) {
        if (self.readOnly) {
            @throw RLMException(@"Cannot set `deleteRealmIfMigrationNeeded` when `readOnly` is set.");
        }
        if (isSync(_config)) {
            @throw RLMException(@"Cannot set 'deleteRealmIfMigrationNeeded' when sync is enabled ('syncConfig' is set).");
        }
        _config->schema_mode = realm::SchemaMode::ResetFile;
    }
    else if (self.deleteRealmIfMigrationNeeded) {
        _config->schema_mode = realm::SchemaMode::Automatic;
    }
}

- (NSArray *)objectClasses {
    return [_customSchema.objectSchema valueForKeyPath:@"objectClass"];
}

- (void)setObjectClasses:(NSArray *)objectClasses {
    self.customSchema = objectClasses ? [RLMSchema schemaWithObjectClasses:objectClasses] : nil;
    [self updateSchemaMode];
}

- (NSUInteger)maximumNumberOfActiveVersions {
    if (_config->max_number_of_active_versions > std::numeric_limits<NSUInteger>::max()) {
        return std::numeric_limits<NSUInteger>::max();
    }
    return static_cast<NSUInteger>(_config->max_number_of_active_versions);
}

- (void)setMaximumNumberOfActiveVersions:(NSUInteger)maximumNumberOfActiveVersions {
    if (maximumNumberOfActiveVersions == 0) {
        _config->max_number_of_active_versions = std::numeric_limits<uint_fast64_t>::max();
    }
    else {
        _config->max_number_of_active_versions = maximumNumberOfActiveVersions;
    }
}

- (void)setDynamic:(bool)dynamic {
    _dynamic = dynamic;
    self.cache = !dynamic;
}

- (bool)disableFormatUpgrade {
    return _config->disable_format_upgrade;
}

- (void)setDisableFormatUpgrade:(bool)disableFormatUpgrade {
    _config->disable_format_upgrade = disableFormatUpgrade;
}

- (realm::SchemaMode)schemaMode {
    return _config->schema_mode;
}

- (void)setSchemaMode:(realm::SchemaMode)mode {
    _config->schema_mode = mode;
}

- (NSString *)pathOnDisk {
    return @(_config->path.c_str());
}

- (void)setShouldCompactOnLaunch:(RLMShouldCompactOnLaunchBlock)shouldCompactOnLaunch {
    if (shouldCompactOnLaunch) {
        if (_config->immutable()) {
            @throw RLMException(@"Cannot set `shouldCompactOnLaunch` when `readOnly` is set.");
        }
        _config->should_compact_on_launch_function = [=](size_t totalBytes, size_t usedBytes) {
            return shouldCompactOnLaunch(totalBytes, usedBytes);
        };
    }
    else {
        _config->should_compact_on_launch_function = nullptr;
    }
    _shouldCompactOnLaunch = shouldCompactOnLaunch;
}

- (void)setCustomSchemaWithoutCopying:(RLMSchema *)schema {
    _customSchema = schema;
}

#if !REALM_ENABLE_SYNC
- (RLMSyncConfiguration *)syncConfiguration {
    return nil;
}
#endif

@end
