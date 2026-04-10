#if canImport(SwiftUI)
import Foundation
import SwiftUI

#if !os(watchOS)
import UniformTypeIdentifiers
#endif

/// Reusable diagnostics console backed by `MHLogStore`.
public struct MHLogConsoleView: View {
    enum Constants {
        static let defaultLimit = 200
        static let minimumLimit = 10
        static let maximumLimit = 2_000
        static let limitStep = 10
        static let exportBaseName = "mhlogging-export"
        static let rowSpacing = 6.0
        static let metadataSpacing = 4.0
        static let verticalPadding = 2.0
        static let rowSpacer = 12.0
        static let metadataPreviewLineLimit = 2
    }

    let store: MHLogStore
    let logging: MHLoggingBootstrap?

    // swiftlint:disable private_swiftui_state
    @State var sessionScope: MHLogSessionScope = .current
    @State var visibleMinimumLevel: MHLogLevel = .debug
    @State var categoryFilter = String()
    @State var searchText = String()
    @State var limit = Constants.defaultLimit
    @State var events = [MHLogEvent]()
    @State var statusMessage = "Ready"

    #if !os(watchOS)
    @State var exportDocument = MHLogConsoleExportDocument(jsonLines: "")
    @State var exportFilename = "\(Constants.exportBaseName).jsonl"
    @State var isPresentingExporter = false
    #endif
    // swiftlint:enable private_swiftui_state

    public var body: some View {
        List {
            captureSection
            filterSection
            actionSection
            eventSection
            statusSection
        }
        .navigationTitle("Diagnostics Console")
        .task {
            await prepareConsole()
        }
        .onChange(of: sessionScope) {
            Task {
                await refreshEvents()
            }
        }
        .onChange(of: visibleMinimumLevel) {
            Task {
                await refreshEvents()
            }
        }
        .onChange(of: categoryFilter) {
            Task {
                await refreshEvents()
            }
        }
        .onChange(of: searchText) {
            Task {
                await refreshEvents()
            }
        }
        .onChange(of: limit) {
            Task {
                await refreshEvents()
            }
        }
        #if !os(watchOS)
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                statusMessage = "Exported JSONL"
            case let .failure(error):
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        #endif
    }

    var availableSessionScopes: [MHLogSessionScope] {
        if let logging,
           logging.hasPreviousSession {
            return MHLogSessionScope.allCases
        }

        return [.current]
    }

    public init(store: MHLogStore) {
        self.store = store
        self.logging = nil
    }

    public init(logging: MHLoggingBootstrap) {
        self.store = logging.store
        self.logging = logging
    }
}
#endif
