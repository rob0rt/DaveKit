import libdave
import Foundation

class Encryptor {
    private let encryptorHandle: DAVEEncryptorHandle

    init() {
        self.encryptorHandle = daveEncryptorCreate()
    }

    deinit {
        daveEncryptorDestroy(self.encryptorHandle)
    }

    func setKeyRatchet(keyRatchet: KeyRatchet) {
        daveEncryptorSetKeyRatchet(self.encryptorHandle, keyRatchet.handle)
    }

    func setPassthroughMode(enabled: Bool) {
        daveEncryptorSetPassthroughMode(self.encryptorHandle, enabled)
    }

    func encrypt(
        ssrc: UInt32,
        data: Data,
        mediaType: MediaType = .audio,
    ) throws(EncryptError) -> Data {
        var encryptedData = Data(count: data.count)
        var outputLength: Int = 0

        let result = encryptedData.withUnsafeMutableBytes { encryptedData in
            data.withUnsafeBytes { data in
                let encryptedData = encryptedData.bindMemory(to: UInt8.self)
                let data = data.bindMemory(to: UInt8.self)

                return daveEncryptorEncrypt(
                    self.encryptorHandle,
                    mediaType.rawValue,
                    ssrc,
                    data.baseAddress!,
                    data.count,
                    encryptedData.baseAddress!,
                    encryptedData.count,
                    &outputLength,
                )
            }
        }

        if let error = EncryptError(rawValue: result) {
            throw error
        }

        encryptedData.removeSubrange(outputLength..<encryptedData.count)
        return encryptedData
    }
}

public enum EncryptError: Error {
    case encryptionFailure
    case unknown(code: DAVEEncryptorResultCode)

    init?(rawValue: DAVEEncryptorResultCode) {
        switch rawValue {
        case DAVE_ENCRYPTOR_RESULT_CODE_SUCCESS:
            return nil
        case DAVE_ENCRYPTOR_RESULT_CODE_ENCRYPTION_FAILURE:
            self = .encryptionFailure
        default:
            self = .unknown(code: rawValue)
        }
    }
}