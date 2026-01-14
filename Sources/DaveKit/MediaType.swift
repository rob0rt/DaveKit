import libdave

public enum MediaType: RawRepresentable {
    case audio
    case video

    public init?(rawValue: DAVEMediaType) {
        switch rawValue {
        case DAVE_MEDIA_TYPE_AUDIO:
            self = .audio
        case DAVE_MEDIA_TYPE_VIDEO:
            self = .video
        default:
            return nil
        }
    }

    public var rawValue: DAVEMediaType {
        switch self {
        case .audio:
            return DAVE_MEDIA_TYPE_AUDIO
        case .video:
            return DAVE_MEDIA_TYPE_VIDEO
        }
    }
}
