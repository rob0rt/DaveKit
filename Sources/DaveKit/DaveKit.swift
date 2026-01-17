import libdave
import Foundation
import Logging

public actor DaveSessionManager {
    // MARK: - Constants

    private static let INIT_TRANSITION_ID: UInt16 = 0
    private static let DISABLED_PROTOCOL_VERSION = 0
    private static let MLS_NEW_GROUP_EXPECTED_EPOCH = "1"

    // Static property initializer to set up logging only once, even across multiple instances
    private static let setupLogging: Void = {
        daveSetLogSinkCallback(logSyncCallback)
    }()

    // MARK: - Properties

    private let selfUserId: String
    private let groupId: UInt64

    private let session: DaveSession
    private let encryptor: Encryptor
    private var decryptors: [String: Decryptor] = [:]
    
    private var lastPreparedTransitionVersion: UInt16 = 0
    private var preparedTransitions: [UInt16: UInt16] = [:]

    private weak let delegate: (any DaveSessionDelegate)?

    // MARK: - Initializer

    public init(
        selfUserId: String,
        groupId: UInt64,
        delegate: DaveSessionDelegate,
    ) {
        self.selfUserId = selfUserId
        self.groupId = groupId
        self.delegate = delegate

        _ = Self.setupLogging

        session = DaveSession()
        encryptor = Encryptor()
        encryptor.setPassthroughMode(enabled: true)
    }

    // MARK: - Static (informational) Methods

    public static nonisolated func maxSupportedProtocolVersion() -> UInt16 {
        return daveMaxSupportedProtocolVersion()
    }

    // MARK: - User Management

    public func addUser(userId: String) {
        decryptors[userId] = Decryptor()
        setupKeyRatchetForUser(userId: userId, protocolVersion: self.lastPreparedTransitionVersion)
    }

    public func removeUser(userId: String) {
        decryptors.removeValue(forKey: userId)
    }

    // MARK: - Encryption / Decryption

    public func encrypt(
        ssrc: UInt32,
        data: Data,
        mediaType: MediaType = .audio,
    ) throws(EncryptError) -> Data {
        return try encryptor.encrypt(ssrc: ssrc, data: data, mediaType: mediaType)
    }

    public func decrypt(
        userId: String,
        data: Data,
        mediaType: MediaType = .audio,
    ) throws(DecryptError) -> Data? {
        guard let decryptor = decryptors[userId] else {
            return nil
        }

        return try decryptor.decrypt(data: data, mediaType: mediaType)
    }

    // MARK: - Incoming Voice Gateway Requests

    // Opcode SELECT_PROTOCOL_ACK (1)
    public func selectProtocol(protocolVersion: UInt16) async {
        if (protocolVersion > Self.DISABLED_PROTOCOL_VERSION) {
            await prepareEpoch(
                epoch: Self.MLS_NEW_GROUP_EXPECTED_EPOCH,
                protocolVersion: protocolVersion,
            )
        } else {
            await prepareTransition(
                transitionId: Self.INIT_TRANSITION_ID,
                protocolVersion: protocolVersion,
            )
            executeTransition(transitionId: Self.INIT_TRANSITION_ID)
        }
    }

    // Opcode DAVE_PROTOCOL_PREPARE_TRANSITION (21)
    public func prepareTransition(transitionId: UInt16, protocolVersion: UInt16) async {
        for userId in decryptors.keys {
            setupKeyRatchetForUser(userId: userId, protocolVersion: protocolVersion)
        }

        if transitionId == Self.INIT_TRANSITION_ID {
            setupKeyRatchetForEncryptor(protocolVersion: protocolVersion)
        } else {
            preparedTransitions[transitionId] = protocolVersion
        }

        lastPreparedTransitionVersion = transitionId

        if transitionId != Self.INIT_TRANSITION_ID {
            await delegate?.readyForTransition(transitionId: transitionId)
        }
    }

    // Opcode DAVE_PROTOCOL_EXECUTE_TRANSITION (22)
    public func executeTransition(transitionId: UInt16) {
        guard let protocolVersion = preparedTransitions.removeValue(forKey: transitionId) else {
            return
        }

        if protocolVersion == Self.DISABLED_PROTOCOL_VERSION {
            self.session.reset()
        }

        setupKeyRatchetForEncryptor(protocolVersion: protocolVersion)
    }

    // Opcode DAVE_PROTOCOL_PREPARE_EPOCH (24)
    public func prepareEpoch(epoch: String, protocolVersion: UInt16) async {
        guard epoch == Self.MLS_NEW_GROUP_EXPECTED_EPOCH else {
            return
        }

        session.initialize(version: protocolVersion, groupId: groupId, selfUserId: selfUserId)

        await delegate?.mlsKeyPackage(keyPackage: session.getKeyPackage())
    }

    // Opcode MLS_EXTERNAL_SENDER_PACKAGE (25)
    public func mlsExternalSenderPackage(externalSenderPackage: Data) {
        session.setExternalSenderPackage(externalSenderPackage: externalSenderPackage)
    }

    // Opcode MLS_PROPOSALS (27)
    public func mlsProposals(proposals: Data) async {
        let welcome = session.processProposals(proposals: proposals, knownUserIds: knownUserIds)
        if let welcome = welcome {
            await delegate?.mlsCommitWelcome(welcome: welcome)
        }
    }

    // Opcode MLS_PREPARE_COMMIT_TRANSITION (29)
    public func mlsPrepareCommitTransition(transitionId: UInt16, commit: Data) async {
        let commit = session.processCommit(commit: commit)

        guard let commit, !commit.isFailed else {
            await delegate?.mlsInvalidCommitWelcome(transitionId: transitionId)
            await selectProtocol(protocolVersion: session.getProtocolVersion())
            return
        }

        if commit.isIgnored {
            return
        }

        await prepareTransition(transitionId: transitionId, protocolVersion: session.getProtocolVersion())
    }

    // Opcode MLS_WELCOME (30)
    public func mlsWelcome(transitionId: UInt16, welcome: Data) async {
        let welcome = session.processWelcome(
            welcome: welcome,
            knownUserIds: knownUserIds,
        )
        guard welcome != nil else {
            await delegate?.mlsInvalidCommitWelcome(transitionId: transitionId)
            await delegate?.mlsKeyPackage(keyPackage: session.getKeyPackage())
            return
        }

        await prepareTransition(
            transitionId: transitionId,
            protocolVersion: session.getProtocolVersion(),
        )
    }

    // MARK: - Private Methods

    private var knownUserIds: [String] {
        return Array(decryptors.keys) + [selfUserId]
    }

    private func setupKeyRatchetForEncryptor(protocolVersion: UInt16) {
        if protocolVersion == Self.DISABLED_PROTOCOL_VERSION {
            encryptor.setPassthroughMode(enabled: true)
            return
        }

        encryptor.setPassthroughMode(enabled: false)
        encryptor.setKeyRatchet(keyRatchet: session.getKeyRatchet(userId: self.selfUserId))
    }

    private func setupKeyRatchetForUser(userId: String, protocolVersion: UInt16) {        
        guard let decryptor = decryptors[userId] else {
            return
        }

        if protocolVersion == Self.DISABLED_PROTOCOL_VERSION {
            decryptor.transitionToPassthroughMode(enabled: true)
            return
        }

        decryptor.transitionToPassthroughMode(enabled: false)
        decryptor.transitionToKeyRatchet(keyRatchet: session.getKeyRatchet(userId: userId))
    }
}