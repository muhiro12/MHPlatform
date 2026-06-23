#if canImport(SwiftUI)
import Foundation
import MHLogging
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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

    @State private var sessionScope: MHLogSessionScope = .current
    @State private var visibleMinimumLevel: MHLogLevel = .debug
    @State private var categoryFilter = String()
    @State private var searchText = String()
    @State private var limit = Constants.defaultLimit
    @State private var events = [MHLogEvent]()
    @State private var statusMessage = "Ready"
    @State private var isPresentingClearConfirmation = false

    #if !os(watchOS)
    @State private var exportDocument = MHLogConsoleExportDocument(jsonLines: "")
    @State private var exportFilename = "\(Constants.exportBaseName).jsonl"
    @State private var isPresentingExporter = false
    #endif

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
        .confirmationDialog(
            "Clear Logs?",
            isPresented: $isPresentingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Logs", role: .destructive) {
                Task {
                    await clearLogs()
                }
            }
            Button("Cancel", role: .cancel) {
                isPresentingClearConfirmation = false
            }
        } message: {
            Text("This removes the visible diagnostic log history for the selected store.")
        }
    }

    var availableSessionScopes: [MHLogSessionScope] {
        if let logging,
           logging.hasPreviousSession {
            return MHLogSessionScope.allCases
        }

        return [.current]
    }

    var selectedSessionScope: MHLogSessionScope {
        get {
            sessionScope
        }
        nonmutating set {
            sessionScope = newValue
        }
    }

    var selectedSessionScopeBinding: Binding<MHLogSessionScope> {
        $sessionScope
    }

    var selectedVisibleMinimumLevel: MHLogLevel {
        visibleMinimumLevel
    }

    var visibleMinimumLevelBinding: Binding<MHLogLevel> {
        $visibleMinimumLevel
    }

    var currentCategoryFilter: String {
        categoryFilter
    }

    var categoryFilterBinding: Binding<String> {
        $categoryFilter
    }

    var currentSearchText: String {
        searchText
    }

    var searchTextBinding: Binding<String> {
        $searchText
    }

    var eventLimit: Int {
        limit
    }

    var limitBinding: Binding<Int> {
        $limit
    }

    var visibleEvents: [MHLogEvent] {
        get {
            events
        }
        nonmutating set {
            events = newValue
        }
    }

    var consoleStatusMessage: String {
        get {
            statusMessage
        }
        nonmutating set {
            statusMessage = newValue
        }
    }

    var isClearConfirmationPresented: Bool {
        get {
            isPresentingClearConfirmation
        }
        nonmutating set {
            isPresentingClearConfirmation = newValue
        }
    }

    #if !os(watchOS)
    var preparedExportDocument: MHLogConsoleExportDocument {
        get {
            exportDocument
        }
        nonmutating set {
            exportDocument = newValue
        }
    }

    var preparedExportFilename: String {
        get {
            exportFilename
        }
        nonmutating set {
            exportFilename = newValue
        }
    }

    var isExporterPresented: Bool {
        get {
            isPresentingExporter
        }
        nonmutating set {
            isPresentingExporter = newValue
        }
    }
    #endif

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
