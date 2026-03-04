import MHDeepLinking
import SwiftUI

struct DeepLinkingDemoView: View {
    private enum ExampleRoute: Hashable, MHDeepLinkRoute {
        case root
        case item(String)
        case search(String?)
        case settings(String)

        private static let settingsRouteComponentCount = 2

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
            case .root:
                return MHDeepLinkDescriptor(pathComponents: [])
            case .item(let identifier):
                return MHDeepLinkDescriptor(
                    pathComponents: ["item"],
                    queryItems: [
                        .init(name: "id", value: identifier)
                    ]
                )
            case .search(let query):
                let queryItems: [URLQueryItem]
                if let query {
                    queryItems = [
                        .init(name: "q", value: query)
                    ]
                } else {
                    queryItems = []
                }
                return MHDeepLinkDescriptor(
                    pathComponents: ["search"],
                    queryItems: queryItems
                )
            case .settings(let section):
                return MHDeepLinkDescriptor(
                    pathComponents: ["settings", section]
                )
            }
        }

        var title: String {
            switch self {
            case .root:
                return "Root"
            case .item(let identifier):
                return "Item \(identifier)"
            case .search(let query):
                return "Search \(query ?? "nil")"
            case .settings(let section):
                return "Settings \(section)"
            }
        }

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            switch deepLinkDescriptor.pathComponents {
            case []:
                self = .root
            case ["item"]:
                let identifierQueryItem = deepLinkDescriptor.queryItems.first { queryItem in
                    queryItem.name == "id"
                }
                guard let identifier = identifierQueryItem?.value,
                      identifier.isEmpty == false else {
                    return nil
                }
                self = .item(identifier)
            case ["search"]:
                self = .search(
                    deepLinkDescriptor.queryItems.first { queryItem in
                        queryItem.name == "q"
                    }?.value
                )
            case let components
                    where components.count == Self.settingsRouteComponentCount &&
                    components.first == "settings":
                guard let section = components.last else {
                    return nil
                }
                self = .settings(section)
            default:
                return nil
            }
        }
    }

    private enum Constants {
        static let builtURLRowSpacing = 6.0
        static let parsedURLRowSpacing = 6.0
        static let builtRowVerticalPadding = 4.0
        static let parsedRowVerticalPadding = 2.0
    }

    private static let configuration = MHDeepLinkConfiguration(
        customScheme: "mhkit",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: [
            "example.com",
            "www.example.com"
        ],
        universalLinkPathPrefix: "MHKit",
        preferredTransport: .customScheme
    )

    private static let inbox = MHDeepLinkInbox()
    private static let store = MHDeepLinkStore(
        userDefaults: .standard,
        key: "MHKitExample.pendingDeepLink"
    )

    @State private var inboxStatus = "No pending inbox URL"
    @State private var storeStatus = "No stored URL"

    private var codec: MHDeepLinkCodec<ExampleRoute> {
        MHDeepLinkCodec(configuration: Self.configuration)
    }

    private var sampleRoutes: [ExampleRoute] {
        [
            .root,
            .item("rent"),
            .search("tea"),
            .settings("notifications")
        ]
    }

    private var sampleURLStrings: [String] {
        [
            "mhkit://",
            "mhkit://item?id=rent",
            "https://example.com/MHKit/settings/notifications",
            "https://example.com/MHKit/search?q=tea"
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                builtURLsSection
                parsedURLsSection
                inboxSection
                storeSection
            }
            .navigationTitle("MHDeepLinking")
        }
    }

    private var builtURLsSection: some View {
        Section("Built URLs") {
            ForEach(sampleRoutes, id: \.self) { route in
                VStack(
                    alignment: .leading,
                    spacing: Constants.builtURLRowSpacing
                ) {
                    Text(route.title)
                        .font(.headline)

                    LabeledContent("Preferred") {
                        routeURLText(
                            codec.preferredURL(for: route)
                        )
                    }

                    LabeledContent("Custom") {
                        routeURLText(
                            codec.url(for: route, transport: .customScheme)
                        )
                    }

                    LabeledContent("Universal") {
                        routeURLText(
                            codec.url(for: route, transport: .universalLink)
                        )
                    }
                }
                .padding(.vertical, Constants.builtRowVerticalPadding)
            }
        }
    }

    private var parsedURLsSection: some View {
        Section("Parsed URLs") {
            ForEach(sampleURLStrings, id: \.self) { urlString in
                VStack(
                    alignment: .leading,
                    spacing: Constants.parsedURLRowSpacing
                ) {
                    Text(urlString)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)

                    Text(parsedTitle(for: urlString))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Constants.parsedRowVerticalPadding)
            }
        }
    }

    private var inboxSection: some View {
        Section("Pending Route Inbox") {
            Button("Store Settings Route") {
                Task {
                    guard let url = codec.preferredURL(
                        for: .settings("notifications")
                    ) else {
                        return
                    }

                    await Self.inbox.store(url)
                    await MainActor.run {
                        inboxStatus = "Stored \(url.absoluteString)"
                    }
                }
            }

            Button("Consume Inbox Route") {
                Task {
                    let url = await Self.inbox.consume()
                    await MainActor.run {
                        inboxStatus = url?.absoluteString ?? "No pending inbox URL"
                    }
                }
            }

            Text(inboxStatus)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private var storeSection: some View {
        Section("UserDefaults Store") {
            Button("Store Item Route") {
                guard let url = codec.preferredURL(for: .item("rent")) else {
                    return
                }

                Self.store.store(url)
                storeStatus = "Stored \(url.absoluteString)"
            }

            Button("Consume Stored Route") {
                storeStatus = Self.store.consume()?.absoluteString ?? "No stored URL"
            }

            Text(storeStatus)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func routeURLText(_ url: URL?) -> some View {
        Text(url?.absoluteString ?? "Unavailable")
            .font(.caption.monospaced())
            .textSelection(.enabled)
    }

    private func parsedTitle(for urlString: String) -> String {
        guard let url = URL(string: urlString),
              let route = codec.parse(url) else {
            return "Rejected"
        }
        return route.title
    }
}
