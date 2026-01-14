import libdave
import Foundation

class DaveSession {
    private let sessionHandle: DAVESessionHandle
    init() {
        sessionHandle = daveSessionCreate(nil, nil, { _, _, _ in }, nil);
    }

    deinit {
        daveSessionDestroy(self.sessionHandle)
    }

    func getKeyRatchet(userId: String) -> KeyRatchet {
        KeyRatchet(handle: daveSessionGetKeyRatchet(self.sessionHandle, userId))
    }

    func reset() {
        daveSessionReset(self.sessionHandle)
    }

    func setExternalSenderPackage(externalSenderPackage: Data) {
        externalSenderPackage.withUnsafeBytes { externalSenderPackage in
            let externalSenderPackage = externalSenderPackage.bindMemory(to: UInt8.self)
            daveSessionSetExternalSender(
                self.sessionHandle,
                externalSenderPackage.baseAddress!,
                externalSenderPackage.count,
            )
        }
    }

    func initialize(version: UInt16, groupId: UInt64, selfUserId: String) {
        daveSessionInit(self.sessionHandle, version, groupId, selfUserId)
    }

    func getKeyPackage() -> Data {
        var outputLength: Int = 0
        var data: UnsafeMutablePointer<UInt8>?
        daveSessionGetMarshalledKeyPackage(
            self.sessionHandle,
            &data,
            &outputLength,
        )

        return Data(bytes: data!, count: outputLength)
    }

    func getProtocolVersion() -> UInt16 {
        return daveSessionGetProtocolVersion(self.sessionHandle)
    }

    func processProposals(proposals: Data, knownUserIds: [String]) -> Data? {
        var welcomeData: UnsafeMutablePointer<UInt8>?
        var welcomeDataLength = 0
        var knownUserIds = knownUserIds
        knownUserIds.withUnsafeMutableBytes { knownUserIdsBuffer in
            return proposals.withUnsafeBytes { proposals in
                let proposals = proposals.bindMemory(to: UInt8.self)
                let knownUserIdsBuffer = knownUserIdsBuffer.bindMemory(
                    to: UnsafePointer<CChar>?.self)
                return daveSessionProcessProposals(
                    self.sessionHandle,
                    proposals.baseAddress!,
                    proposals.count,
                    knownUserIdsBuffer.baseAddress!,
                    knownUserIds.count,
                    &welcomeData,
                    &welcomeDataLength,
                )
            }
        }

        if let result = welcomeData {
            return Data(bytes: result, count: welcomeDataLength)
        } else {
            return nil
        }
    }

    func processWelcome(welcome: Data, knownUserIds: [String]) -> Welcome? {
        var knownUserIds = knownUserIds
        let result = knownUserIds.withUnsafeMutableBytes { knownUserIds in
            let knownUserIds = knownUserIds.bindMemory(to: UnsafePointer<CChar>?.self)
            return welcome.withUnsafeBytes { welcome in
                let welcome = welcome.bindMemory(to: UInt8.self)
                return daveSessionProcessWelcome(
                    self.sessionHandle,
                    welcome.baseAddress!,
                    welcome.count,
                    knownUserIds.baseAddress!,
                    knownUserIds.count,
                )
            }
        }

        if let result = result {
            return Welcome(handle: result)
        } else {
            return nil
        }
    }

    func processCommit(commit: Data) -> Commit? {
        let handle = commit.withUnsafeBytes { commit in
            let commit = commit.bindMemory(to: UInt8.self)
            return daveSessionProcessCommit(
                self.sessionHandle,
                commit.baseAddress!,
                commit.count,
            )
        }

        if let handle = handle {
            return Commit(handle: handle)
        } else {
            return nil
        }
    }
}