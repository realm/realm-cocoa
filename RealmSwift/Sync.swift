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

import Realm
import Realm.Private

/**
 An object representing a Realm Object Server user.

 - see: `RLMSyncUser`
 */
public typealias SyncUser = RLMSyncUser

/**
 An immutable data object representing information retrieved from the Realm Object
 Server about a particular user.

 - see: `RLMSyncUserInfo`
 */
public typealias SyncUserInfo = RLMSyncUserInfo

/**
 An immutable data object representing an account belonging to a particular user.

 - see: `SyncUserInfo`, `RLMSyncUserAccountInfo`
 */
public typealias SyncUserAccountInfo = RLMSyncUserAccountInfo

/**
 A singleton which configures and manages the Realm Object Server synchronization-related
 functionality.

 - see: `RLMSyncManager`
 */
public typealias SyncManager = RLMSyncManager

extension SyncManager {
    /// The sole instance of the singleton.
    public static var shared: SyncManager {
        return __shared()
    }
}

/**
 Options for configuring timeouts and intervals in the sync client.

  - see: `RLMSyncTimeoutOptions`
 */
public typealias SyncTimeoutOptions = RLMSyncTimeoutOptions

/**
 A session object which represents communication between the client and server for a specific
 Realm.

 - see: `RLMSyncSession`
 */
public typealias SyncSession = RLMSyncSession

/**
 A closure type for a closure which can be set on the `SyncManager` to allow errors to be reported
 to the application.

 - see: `RLMSyncErrorReportingBlock`
 */
public typealias ErrorReportingBlock = RLMSyncErrorReportingBlock

/**
 A closure type for a closure which is used by certain APIs to asynchronously return a `SyncUser`
 object to the application.

 - see: `RLMUserCompletionBlock`
 */
public typealias UserCompletionBlock = RLMUserCompletionBlock

/**
 An error associated with the SDK's synchronization functionality. All errors reported by
 an error handler registered on the `SyncManager` are of this type.

 - see: `RLMSyncError`
 */
public typealias SyncError = RLMSyncError

extension SyncError {
    /**
     An opaque token allowing the user to take action after certain types of
     errors have been reported.

     - see: `RLMSyncErrorActionToken`
     */
    public typealias ActionToken = RLMSyncErrorActionToken

    /**
     Given a client reset error, extract and return the recovery file path
     and the action token.

     The action token can be passed into `SyncSession.immediatelyHandleError(_:)`
     to immediately delete the local copy of the Realm which experienced the
     client reset error. The local copy of the Realm must be deleted before
     your application attempts to open the Realm again.

     The recovery file path is the path to which the current copy of the Realm
     on disk will be saved once the client reset occurs.

     - warning: Do not call `SyncSession.immediatelyHandleError(_:)` until you are
                sure that all references to the Realm and managed objects belonging
                to the Realm have been nil'ed out, and that all autorelease pools
                containing these references have been drained.

     - see: `SyncError.ActionToken`, `SyncSession.immediatelyHandleError(_:)`
     */
    public func clientResetInfo() -> (String, SyncError.ActionToken)? {
        if code == SyncError.clientResetError,
            let recoveryPath = userInfo[kRLMSyncPathOfRealmBackupCopyKey] as? String,
            let token = _nsError.__rlmSync_errorActionToken() {
            return (recoveryPath, token)
        }
        return nil
    }

    /**
     Given a permission denied error, extract and return the action token.

     This action token can be passed into `SyncSession.immediatelyHandleError(_:)`
     to immediately delete the local copy of the Realm which experienced the
     permission denied error. The local copy of the Realm must be deleted before
     your application attempts to open the Realm again.

     - warning: Do not call `SyncSession.immediatelyHandleError(_:)` until you are
                sure that all references to the Realm and managed objects belonging
                to the Realm have been nil'ed out, and that all autorelease pools
                containing these references have been drained.

     - see: `SyncError.ActionToken`, `SyncSession.immediatelyHandleError(_:)`
     */
    public func deleteRealmUserInfo() -> SyncError.ActionToken? {
        return _nsError.__rlmSync_errorActionToken()
    }
}

/**
 An error associated with network requests made to the authentication server. This type of error
 may be returned in the callback block to `SyncUser.logIn()` upon certain types of failed login
 attempts (for example, if the request is malformed or if the server is experiencing an issue).

 - see: `RLMSyncAuthError`
 */
public typealias SyncAuthError = RLMSyncAuthError

/**
 An enum which can be used to specify the level of logging.

 - see: `RLMSyncLogLevel`
 */
public typealias SyncLogLevel = RLMSyncLogLevel

/**
 A data type whose values represent different authentication providers that can be used with
 the Realm Object Server.

 - see: `RLMIdentityProvider`
 */
public typealias Provider = RLMIdentityProvider

/**
 * How the Realm client should validate the identity of the server for secure connections.
 *
 * By default, when connecting to the Realm Object Server over HTTPS, Realm will
 * validate the server's HTTPS certificate using the system trust store and root
 * certificates. For additional protection against man-in-the-middle (MITM)
 * attacks and similar vulnerabilities, you can pin a certificate or public key,
 * and reject all others, even if they are signed by a trusted CA.
 */
public enum ServerValidationPolicy {
    /// Perform no validation and accept potentially invalid certificates.
    ///
    /// - warning: DO NOT USE THIS OPTION IN PRODUCTION.
    case none

    /// Use the default server trust evaluation based on the system-wide CA
    /// store. Any certificate signed by a trusted CA will be accepted.
    case system

    /// Use a specific pinned certificate to validate the server identify.
    ///
    /// This will only connect to a server if one of the server certificates
    /// matches the certificate stored at the given local path and that
    /// certificate has a valid trust chain.
    ///
    /// On macOS, the certificate files may be in any of the formats supported
    /// by SecItemImport(), including PEM and .cer (see SecExternalFormat for a
    /// complete list of possible formats). On iOS and other platforms, only
    /// DER .cer files are supported.
    case pinCertificate(path: URL)
}

/**
 A `SyncConfiguration` represents configuration parameters for Realms intended to sync with
 a Realm Object Server.
 */
public struct SyncConfiguration {
    /// The `SyncUser` who owns the Realm that this configuration should open.
    public let user: SyncUser

    /**
     The URL of the Realm on the Realm Object Server that this configuration should open.

     - warning: The URL must be absolute (e.g. `realms://example.com/~/foo`), and cannot end with
                `.realm`, `.realm.lock` or `.realm.management`.
     */
    public let realmURL: URL

    /**
     A policy that determines what should happen when all references to Realms opened by this
     configuration go out of scope.
     */
    internal let stopPolicy: RLMSyncStopPolicy

    /**
     How the SSL certificate of the Realm Object Server should be validated.
     */
    public let serverValidationPolicy: ServerValidationPolicy

    /// :nodoc:
    @available(*, unavailable, message: "Use serverValidationPolicy instead")
    public var enableSSLValidation: Bool {
        fatalError()
    }

    /**
     The prefix that is prepended to the path in the HTTP request
     that initiates a sync connection. The value specified must match with the server's expectation.
     Changing the value of `urlPrefix` should be matched with a corresponding
     change of the server's configuration.
     If no value is specified here then the default `/realm-sync` path is used.
     */
    public let urlPrefix: String?

    /**
     By default, Realm.asyncOpen() swallows non-fatal connection errors such as
     a connection attempt timing out and simply retries until it succeeds. If
     this is set to `true`, instead the error will be reported to the callback
     and the async open will be cancelled.
     */
    public let cancelAsyncOpenOnNonFatalErrors: Bool

    internal init(config: RLMSyncConfiguration) {
        self.user = config.user
        self.realmURL = config.realmURL
        self.stopPolicy = config.stopPolicy
        if let certificateURL = config.pinnedCertificateURL {
            self.serverValidationPolicy = .pinCertificate(path: certificateURL)
        } else {
            self.serverValidationPolicy = config.enableSSLValidation ? .system : .none
        }
        self.urlPrefix = config.urlPrefix
        self.cancelAsyncOpenOnNonFatalErrors = config.cancelAsyncOpenOnNonFatalErrors
    }

    func asConfig() -> RLMSyncConfiguration {
        var validateSSL = true
        var certificate: URL?
        switch serverValidationPolicy {
        case .none:
            validateSSL = false
        case .system:
            break
        case .pinCertificate(let path):
            certificate = path
        }
        let c = RLMSyncConfiguration(user: user, realmURL: realmURL,
                                     urlPrefix: urlPrefix,
                                     stopPolicy: stopPolicy,
                                     enableSSLValidation: validateSSL,
                                     certificatePath: certificate)
        c.cancelAsyncOpenOnNonFatalErrors = cancelAsyncOpenOnNonFatalErrors
        return c
    }

    /// :nodoc:
    @available(*, unavailable, message: "Use SyncUser.configuration() instead")
    public init(user: SyncUser, realmURL: URL, enableSSLValidation: Bool = true, isPartial: Bool = false, urlPrefix: String? = nil) {
        fatalError()
    }

    /// :nodoc:
    @available(*, unavailable, message: "Use SyncUser.configuration() instead")
    public static func automatic() -> Realm.Configuration {
        fatalError()
    }

    /// :nodoc:
    @available(*, unavailable, message: "Use SyncUser.configuration() instead")
    public static func automatic(user: SyncUser) -> Realm.Configuration {
        fatalError()
    }
}

extension SyncUser {
    /**
     An optional error handler which can be set to notify the host application when
     the user encounters an error.

     - note: Check for `.invalidAccessToken` to see if the user has been remotely logged
             out because its refresh token expired, or because the third party authentication
             service providing the user's identity has logged the user out.

     - warning: Regardless of whether an error handler is defined, certain user errors
                will automatically cause the user to enter the logged out state.
     */
    @nonobjc public var errorHandler: ((SyncUser, SyncAuthError) -> Void)? {
        get {
            return __errorHandler
        }
        set {
            if let newValue = newValue {
                __errorHandler = { (user, error) in
                    newValue(user, error as! SyncAuthError)
                }
            } else {
                __errorHandler = nil
            }
        }
    }

    /**
     Create a sync configuration instance.

     Additional settings can be optionally specified. Descriptions of these
     settings follow.

     `enableSSLValidation` is true by default. It can be disabled for debugging
     purposes.

     - warning: The URL must be absolute (e.g. `realms://example.com/~/foo`), and cannot end with
     `.realm`, `.realm.lock` or `.realm.management`.

     - warning: NEVER disable SSL validation for a system running in production.
     */
    public func configuration(realmURL: URL? = nil,
                              enableSSLValidation: Bool, urlPrefix: String? = nil) -> Realm.Configuration {
        let config = self.__configuration(with: realmURL,
                                          enableSSLValidation: enableSSLValidation,
                                          urlPrefix: urlPrefix)
        return ObjectiveCSupport.convert(object: config)
    }

    /**
     Create a sync configuration instance.

     - parameter realmURL: The URL to connect to. If not set, the default Realm
     derived from the authentication URL is used. The URL must be absolute (e.g.
     `realms://example.com/~/foo`), and cannot end with `.realm`, `.realm.lock`
     or `.realm.management`.
     - parameter serverValidationPolicy: How the SSL certificate of the Realm Object
     Server should be validated. By default the system SSL validation is used,
     but it can be set to `.pinCertificate` to pin a specific SSL certificate,
     or `.none` for debugging.
     - parameter fullSynchronization: Whether this Realm should be a fully
     synchronized or a query-based Realm.
     - parameter urlPrefix: The prefix that is prepended to the path in the HTTP
     request that initiates a sync connection. The value specified must match
     with the server's expectation, and this parameter only needs to be set if
     you have changed the configuration of the server.
     - parameter cancelAsyncOpenOnNonFatalErrors: By default, Realm.asyncOpen()
     swallows non-fatal connection errors such as a connection attempt timing
     out and simply retries until it succeeds. If this is set to `true`, instead
     the error will be reported to the callback and the async open will be
     cancelled.

     - warning: NEVER disable SSL validation for a system running in production.
     */
    public func configuration(realmURL: URL? = nil, fullSynchronization: Bool = false,
                              serverValidationPolicy: ServerValidationPolicy = .system,
                              urlPrefix: String? = nil,
                              cancelAsyncOpenOnNonFatalErrors: Bool = false) -> Realm.Configuration {
        let config = self.__configuration(with: realmURL)
        let syncConfig = config.syncConfiguration!
        syncConfig.urlPrefix = urlPrefix
        syncConfig.cancelAsyncOpenOnNonFatalErrors = cancelAsyncOpenOnNonFatalErrors
        switch serverValidationPolicy {
        case .none:
            syncConfig.enableSSLValidation = false
        case .system:
            break
        case .pinCertificate(let path):
            syncConfig.pinnedCertificateURL = path
        }
        config.syncConfiguration = syncConfig
        return ObjectiveCSupport.convert(object: config)
    }
}

public extension SyncSession {
    /**
     The current state of the session represented by a session object.

     - see: `RLMSyncSessionState`
     */
    typealias State = RLMSyncSessionState

    /**
     The current state of a sync session's connection.

     - see: `RLMSyncConnectionState`
     */
    typealias ConnectionState = RLMSyncConnectionState

    /**
     The transfer direction (upload or download) tracked by a given progress notification block.

     Progress notification blocks can be registered on sessions if your app wishes to be informed
     how many bytes have been uploaded or downloaded, for example to show progress indicator UIs.
     */
    enum ProgressDirection {
        /// For monitoring upload progress.
        case upload
        /// For monitoring download progress.
        case download
    }

    /**
     The desired behavior of a progress notification block.

     Progress notification blocks can be registered on sessions if your app wishes to be informed
     how many bytes have been uploaded or downloaded, for example to show progress indicator UIs.
     */
    enum ProgressMode {
        /**
         The block will be called forever, or until it is unregistered by calling
         `ProgressNotificationToken.invalidate()`.

         Notifications will always report the latest number of transferred bytes, and the
         most up-to-date number of total transferrable bytes.
         */
        case reportIndefinitely
        /**
         The block will, upon registration, store the total number of bytes
         to be transferred. When invoked, it will always report the most up-to-date number
         of transferrable bytes out of that original number of transferrable bytes.

         When the number of transferred bytes reaches or exceeds the
         number of transferrable bytes, the block will be unregistered.
         */
        case forCurrentlyOutstandingWork
    }

    /**
     A token corresponding to a progress notification block.

     Call `invalidate()` on the token to stop notifications. If the notification block has already
     been automatically stopped, calling `invalidate()` does nothing. `invalidate()` should be called
     before the token is destroyed.
     */
    typealias ProgressNotificationToken = RLMProgressNotificationToken

    /**
     A struct encapsulating progress information, as well as useful helper methods.
     */
    struct Progress {
        /// The number of bytes that have been transferred.
        public let transferredBytes: Int

        /**
         The total number of transferrable bytes (bytes that have been transferred,
         plus bytes pending transfer).

         If the notification block is tracking downloads, this number represents the size of the
         changesets generated by all other clients using the Realm.
         If the notification block is tracking uploads, this number represents the size of the
         changesets representing the local changes on this client.
         */
        public let transferrableBytes: Int

        /// The fraction of bytes transferred out of all transferrable bytes. If this value is 1,
        /// no bytes are waiting to be transferred (either all bytes have already been transferred,
        /// or there are no bytes to be transferred in the first place).
        public var fractionTransferred: Double {
            if transferrableBytes == 0 {
                return 1
            }
            let percentage = Double(transferredBytes) / Double(transferrableBytes)
            return percentage > 1 ? 1 : percentage
        }

        /// Whether all pending bytes have already been transferred.
        public var isTransferComplete: Bool {
            return transferredBytes >= transferrableBytes
        }

        internal init(transferred: UInt, transferrable: UInt) {
            transferredBytes = Int(transferred)
            transferrableBytes = Int(transferrable)
        }
    }

    /**
     Register a progress notification block.

     If the session has already received progress information from the
     synchronization subsystem, the block will be called immediately. Otherwise, it
     will be called as soon as progress information becomes available.

     Multiple blocks can be registered with the same session at once. Each block
     will be invoked on a side queue devoted to progress notifications.

     The token returned by this method must be retained as long as progress
     notifications are desired, and the `invalidate()` method should be called on it
     when notifications are no longer needed and before the token is destroyed.

     If no token is returned, the notification block will never be called again.
     There are a number of reasons this might be true. If the session has previously
     experienced a fatal error it will not accept progress notification blocks. If
     the block was configured in the `forCurrentlyOutstandingWork` mode but there
     is no additional progress to report (for example, the number of transferrable bytes
     and transferred bytes are equal), the block will not be called again.

     - parameter direction: The transfer direction (upload or download) to track in this progress notification block.
     - parameter mode:      The desired behavior of this progress notification block.
     - parameter block:     The block to invoke when notifications are available.

     - returns: A token which must be held for as long as you want notifications to be delivered.

     - see: `ProgressDirection`, `Progress`, `ProgressNotificationToken`
     */
    func addProgressNotification(for direction: ProgressDirection,
                                 mode: ProgressMode,
                                 block: @escaping (Progress) -> Void) -> ProgressNotificationToken? {
        return __addProgressNotification(for: (direction == .upload ? .upload : .download),
                                         mode: (mode == .reportIndefinitely
                                            ? .reportIndefinitely
                                            : .forCurrentlyOutstandingWork)) { transferred, transferrable in
                                                block(Progress(transferred: transferred, transferrable: transferrable))
        }
    }
}

extension Realm {
    /// :nodoc:
    @available(*, unavailable, message: "Use Results.subscribe()")
    public func subscribe<T: Object>(to objects: T.Type, where: String,
                                     completion: @escaping (Results<T>?, Swift.Error?) -> Void) {
        fatalError()
    }

    /**
     Get the SyncSession used by this Realm. Will be nil if this is not a
     synchronized Realm.
    */
    public var syncSession: SyncSession? {
        return SyncSession(for: rlmRealm)
    }
}
