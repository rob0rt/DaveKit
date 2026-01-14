import Foundation

/// Delegate protocol for handling DaveSession events, to send messages
/// back to the gateway.
public protocol DaveSessionDelegate: AnyObject {
    // Opcode MLS_KEY_PACKAGE (26)
    func sendMLSKeyPackage(keyPackage: Data)
    // Opcode DAVE_PROTOCOL_READY_FOR_TRANSITION (23)
    func readyForTransition(transitionId: UInt16)
    // Opcode MLS_COMMIT_WELCOME (28)
    func sendMLSCommitWelcome(welcome: Data)
    // Opcode MLS_INVALID_COMMIT_WELCOME (31)
    func mlsInvalidCommitWelcome(transitionId: UInt16)
}
