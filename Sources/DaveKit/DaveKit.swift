import libdave

public actor DaveSessionManager {
    // MARK: - Constants
    private static let INIT_TRANSITION_ID = 0
    private static let DISABLED_PROTOCOL_VERSION = 0
    private static let MLS_NEW_GROUP_EXPECTED_EPOCH = 1

    private let session: DaveSession
    private let selfUserId: String
    
    private var lastPreparedTransitionVersion: UInt16 = 0
    private var preparedTransitions: [UInt16: UInt16] = [:]

    private let encryptor: Encryptor
    private var decryptors: [String: Decryptor] = [:]

    init(selfUserId: String) {
        session = DaveSession()
        encryptor = Encryptor()
        encryptor.setPassthroughMode(enabled: true)
        self.selfUserId = selfUserId
    }

    nonisolated func maxSupportedProtocolVersion() -> UInt16 {
        return daveMaxSupportedProtocolVersion()
    }

    public func addUser(userId: String) {
        decryptors[userId] = Decryptor()
        setupKeyRatchetForUser(userId: userId, protocolVersion: self.lastPreparedTransitionVersion)
    }

    public func removeUser(userId: String) {
        decryptors.removeValue(forKey: userId)
    }

    public func prepareTransition(transitionId: UInt16, protocolVersion: UInt16) {
        for userId in decryptors.keys {
            setupKeyRatchetForUser(userId: userId, protocolVersion: protocolVersion)
        }

        if transitionId == Self.INIT_TRANSITION_ID {
            setupKeyRatchetForEncryptor(protocolVersion: protocolVersion)
        } else {
            preparedTransitions[transitionId] = protocolVersion
        }

        lastPreparedTransitionVersion = transitionId
    }

    public func executeTransition(transitionId: UInt16) {
        guard let protocolVersion = preparedTransitions.removeValue(forKey: transitionId) else {
            return
        }

        if protocolVersion == Self.DISABLED_PROTOCOL_VERSION {
            self.session.reset()
        }

        setupKeyRatchetForEncryptor(protocolVersion: protocolVersion)
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