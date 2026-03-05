import Foundation

/// Configuration for `MHNotificationPayloadCodec`.
public struct MHNotificationPayloadCodecConfiguration: Equatable, Sendable {
    /// Reserved userInfo keys used for encoding and decoding.
    public let keys: MHNotificationPayloadKeys

    /// Metadata keys that are allowed to be decoded from userInfo.
    public let decodableMetadataKeys: Set<String>

    /// Creates codec configuration.
    public init(
        keys: MHNotificationPayloadKeys = .mhKit,
        decodableMetadataKeys: Set<String> = []
    ) {
        self.keys = keys
        self.decodableMetadataKeys = decodableMetadataKeys
    }
}
