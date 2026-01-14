import libdave
import Logging

let logger = Logger(label: "net.robort.davekit")

extension Logger.Level {
    init?(from: DAVELoggingSeverity) {
        switch from {
        case DAVE_LOGGING_SEVERITY_NONE:
            return nil
        case DAVE_LOGGING_SEVERITY_VERBOSE:
            self = .debug
        case DAVE_LOGGING_SEVERITY_INFO:
            self = .info
        case DAVE_LOGGING_SEVERITY_WARNING:
            self = .warning
        case DAVE_LOGGING_SEVERITY_ERROR:
            self = .error
        default:
            return nil
        }
    }
}

func logSyncCallback(
    severity: DAVELoggingSeverity,
    file: UnsafePointer<CChar>?,
    line: Int32,
    message: UnsafePointer<CChar>?
) {
    let logMessage = String(cString: message!)
    if let level = Logger.Level(from: severity) {
        logger.log(level: level, "\(logMessage)", metadata: [
            "file": .string(String(cString: file!)),
            "line": .stringConvertible(line),
        ])
    }
}
