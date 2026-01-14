import libdave
import Foundation

class Decryptor {
    private let decryptorHandle: DAVEDecryptorHandle

    init() {
        self.decryptorHandle = daveDecryptorCreate()
    }

    deinit {
        daveDecryptorDestroy(self.decryptorHandle)
    }

    func transitionToKeyRatchet(keyRatchet: KeyRatchet) {
        daveDecryptorTransitionToKeyRatchet(self.decryptorHandle, keyRatchet.handle)
    }

    func transitionToPassthroughMode(enabled: Bool) {
        daveDecryptorTransitionToPassthroughMode(self.decryptorHandle, enabled)
    }

    func decrypt(data: Data, mediaType: MediaType = .audio) throws(DecryptError) -> Data {
        var decryptedData = Data(count: data.count)  // Allocate space for decrypted data
        var outputLength: Int = 0

        let result = decryptedData.withUnsafeMutableBytes { decryptedData in
            data.withUnsafeBytes { data in
                let decryptedData = decryptedData.bindMemory(to: UInt8.self)
                let data = data.bindMemory(to: UInt8.self)

                return daveDecryptorDecrypt(
                    self.decryptorHandle,
                    mediaType.rawValue,
                    data.baseAddress!,
                    data.count,
                    decryptedData.baseAddress!,
                    decryptedData.count,
                    &outputLength,
                )
            }
        }

        if let error = DecryptError(rawValue: result) {
            throw error
        }

        decryptedData.removeSubrange(outputLength..<decryptedData.count)
        return decryptedData
    }
}

public enum DecryptError: Error {
    case decryptionFailure
    case missingKeyRatchet
    case invalidNonce
    case missingCryptor
    case unknown(code: DAVEDecryptorResultCode)

    init?(rawValue: DAVEDecryptorResultCode) {
        switch rawValue {
        case DAVE_DECRYPTOR_RESULT_CODE_SUCCESS:
            return nil
        case DAVE_DECRYPTOR_RESULT_CODE_DECRYPTION_FAILURE:
            self = .decryptionFailure
        case DAVE_DECRYPTOR_RESULT_CODE_MISSING_KEY_RATCHET:
            self = .missingKeyRatchet
        case DAVE_DECRYPTOR_RESULT_CODE_INVALID_NONCE:
            self = .invalidNonce
        case DAVE_DECRYPTOR_RESULT_CODE_MISSING_CRYPTOR:
            self = .missingCryptor
        default:
            self = .unknown(code: rawValue)
        }
    }
}