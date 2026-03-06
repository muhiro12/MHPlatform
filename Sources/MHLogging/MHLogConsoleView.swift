#if canImport(SwiftUI)
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Reusable log console UI backed by `MHLogStore`.
public struct MHLogConsoleView: View {
    private enum Constants {
        static let defaultLimit = 200
        static let minimumLimit = 10
        static let maximumLimit = 2_000
        static let limitStep = 10
    }

    private let store: MHLogStore

    @State private var minimumLevel: MHLogLevel = .debug
    @State private var categoryFilter = String()
    @State private var searchText = String()
    @State private var limit = Constants.defaultLimit
    @State private var events = [MHLogEvent]()
    @State private var statusMessage = "Ready"

    public var body: some View {
        List {
            filterSection
            actionSection
            eventSection
            statusSection
        }
        .navigationTitle("MHLogging")
        .task {
            await refreshEvents()
        }
        .onChange(of: minimumLevel) {
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
    }

    private var filterSection: some View {
        Section("Filters") {
            Picker("Minimum Level", selection: $minimumLevel) {
                ForEach(MHLogLevel.allCases, id: \.self) { level in
                    Text(level.name.uppercased())
                        .tag(level)
                }
            }
            TextField("Category contains", text: $categoryFilter)
                .autocorrectionDisabled()
            TextField("Search text", text: $searchText)
                .autocorrectionDisabled()
            Stepper(
                "Limit: \(limit)",
                value: $limit,
                in: Constants.minimumLimit...Constants.maximumLimit,
                step: Constants.limitStep
            )
        }
    }

    private var actionSection: some View {
        Section("Actions") {
            Button("Refresh") {
                Task {
                    await refreshEvents()
                }
            }
            Button("Copy JSONL") {
                Task {
                    await copyJSONL()
                }
            }
            Button("Clear") {
                Task {
                    await clearLogs()
                }
            }
        }
    }

    private var eventSection: some View {
        Section("Events") {
            if events.isEmpty {
                Text("No events")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(events.enumerated()),
                    id: \.offset
                ) { _, event in
                    Text(event.summaryLine)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Text(statusMessage)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private var activeQuery: MHLogQuery {
        MHLogQuery(
            minimumLevel: minimumLevel,
            category: categoryFilter,
            searchText: searchText,
            limit: limit
        )
    }

    public init(store: MHLogStore) {
        self.store = store
    }

    private func refreshEvents() async {
        let values = await store.events(matching: activeQuery)
        await MainActor.run {
            events = values
            statusMessage = "Loaded \(values.count) event(s)"
        }
    }

    private func copyJSONL() async {
        let jsonLines = await store.exportJSONLines(matching: activeQuery)
        let copied = copyToClipboard(jsonLines)
        await MainActor.run {
            if copied {
                statusMessage = "Copied \(jsonLines.utf8.count) bytes as JSONL"
            } else {
                statusMessage = "Clipboard is not supported on this platform"
            }
        }
    }

    private func clearLogs() async {
        await store.clear()
        await refreshEvents()
        await MainActor.run {
            statusMessage = "Cleared in-memory logs"
        }
    }

    private func copyToClipboard(_ value: String) -> Bool {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        return true
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
        #else
        return false
        #endif
    }
}
#endif
