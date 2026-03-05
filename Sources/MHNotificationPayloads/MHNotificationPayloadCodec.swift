import Foundation

/// Encodes and decodes notification payloads to/from userInfo dictionaries.
public struct MHNotificationPayloadCodec: Sendable {
    /// Codec configuration.
    public let configuration: MHNotificationPayloadCodecConfiguration

    private var reservedKeys: Set<String> {
        [
            configuration.keys.defaultRouteURL,
            configuration.keys.fallbackRouteURL,
            configuration.keys.actionRouteURLs
        ]
    }

    /// Creates a payload codec.
    public init(
        configuration: MHNotificationPayloadCodecConfiguration = .init()
    ) {
        self.configuration = configuration
    }

    /// Encodes a payload to a `userInfo`-compatible dictionary.
    public func encode(
        _ payload: MHNotificationPayload
    ) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [:]

        if let defaultRouteURL = payload.routes.defaultRouteURL {
            userInfo[
                configuration.keys.defaultRouteURL
            ] = defaultRouteURL.absoluteString
        }

        if let fallbackRouteURL = payload.routes.fallbackRouteURL {
            userInfo[
                configuration.keys.fallbackRouteURL
            ] = fallbackRouteURL.absoluteString
        }

        if payload.routes.actionRouteURLs.isEmpty == false {
            let encodedActionRoutes = Dictionary(
                uniqueKeysWithValues: payload.routes.actionRouteURLs.map { key, value in
                    (key, value.absoluteString)
                }
            )
            userInfo[
                configuration.keys.actionRouteURLs
            ] = encodedActionRoutes
        }

        for (key, value) in payload.metadata where reservedKeys.contains(key) == false {
            userInfo[key] = value
        }

        return userInfo
    }

    /// Decodes a payload from a `userInfo` dictionary.
    public func decode(
        _ userInfo: [AnyHashable: Any]
    ) -> MHNotificationPayload? {
        let defaultRouteURL = decodeURL(
            from: userInfo,
            key: configuration.keys.defaultRouteURL
        )
        let fallbackRouteURL = decodeURL(
            from: userInfo,
            key: configuration.keys.fallbackRouteURL
        )
        let actionRouteURLs = decodeActionRouteURLs(from: userInfo)

        guard defaultRouteURL != nil
                || fallbackRouteURL != nil
                || actionRouteURLs.isEmpty == false else {
            return nil
        }

        return MHNotificationPayload(
            routes: .init(
                defaultRouteURL: defaultRouteURL,
                fallbackRouteURL: fallbackRouteURL,
                actionRouteURLs: actionRouteURLs
            ),
            metadata: decodeMetadata(from: userInfo)
        )
    }
}

private extension MHNotificationPayloadCodec {
    func decodeURL(
        from userInfo: [AnyHashable: Any],
        key: String
    ) -> URL? {
        let value = userInfo[key]

        if let urlString = value as? String {
            return URL(string: urlString)
        }

        if let url = value as? URL {
            return url
        }

        return nil
    }

    func decodeActionRouteURLs(
        from userInfo: [AnyHashable: Any]
    ) -> [String: URL] {
        let key = configuration.keys.actionRouteURLs

        if let encodedActionRoutes = userInfo[key] as? [String: String] {
            return decodeActionRouteMap(encodedActionRoutes)
        }

        guard let rawActionRoutes = userInfo[key] as? [AnyHashable: Any] else {
            return [:]
        }

        var encodedActionRoutes = [String: String]()

        for (rawKey, rawValue) in rawActionRoutes {
            guard let actionIdentifier = rawKey as? String else {
                continue
            }

            if let routeURLString = rawValue as? String {
                encodedActionRoutes[actionIdentifier] = routeURLString
                continue
            }

            if let routeURL = rawValue as? URL {
                encodedActionRoutes[actionIdentifier] = routeURL.absoluteString
            }
        }

        return decodeActionRouteMap(encodedActionRoutes)
    }

    func decodeActionRouteMap(
        _ encodedActionRoutes: [String: String]
    ) -> [String: URL] {
        var actionRoutes = [String: URL]()

        for (actionIdentifier, routeURLString) in encodedActionRoutes {
            guard let routeURL = URL(string: routeURLString) else {
                continue
            }
            actionRoutes[actionIdentifier] = routeURL
        }

        return actionRoutes
    }

    func decodeMetadata(
        from userInfo: [AnyHashable: Any]
    ) -> [String: String] {
        var metadata = [String: String]()

        for key in configuration.decodableMetadataKeys where reservedKeys.contains(key) == false {
            guard let value = userInfo[key] as? String else {
                continue
            }
            metadata[key] = value
        }

        return metadata
    }
}
