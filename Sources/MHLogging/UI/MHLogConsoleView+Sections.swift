#if canImport(SwiftUI)
import SwiftUI

extension MHLogConsoleView {
    @ViewBuilder var captureSection: some View {
        if let logging {
            let captureLevel = logging.captureLevel

            Section("Capture") {
                sessionScopePicker()
                captureLevelPicker(logging: logging)
                captureSummaryText(captureLevel: captureLevel)
                previousSessionAvailabilityText(logging: logging)
            }
        }
    }

    var filterSection: some View {
        Section("Filters") {
            Picker(
                "Visible Minimum Level",
                selection: $visibleMinimumLevel
            ) {
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

    var actionSection: some View {
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
            Button("Export JSONL") {
                Task {
                    await exportJSONL()
                }
            }
            Button("Clear") {
                Task {
                    await clearLogs()
                }
            }
        }
    }

    var eventSection: some View {
        Section("Events") {
            if events.isEmpty {
                Text(
                    sessionScope == .previous
                        ? "No previous session events"
                        : "No events"
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(events.enumerated()),
                    id: \.offset
                ) { _, event in
                    NavigationLink {
                        MHLogEventDetailView(event: event)
                    } label: {
                        eventRow(event)
                    }
                }
            }
        }
    }

    var statusSection: some View {
        Section("Status") {
            Text(statusMessage)
                .font(.caption.monospaced())
                .logConsoleTextSelectionIfSupported()
        }
    }

    func eventRow(_ event: MHLogEvent) -> some View {
        VStack(
            alignment: .leading,
            spacing: Constants.rowSpacing
        ) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.timestamp.ISO8601Format())
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer(minLength: Constants.rowSpacer)
                Text(event.level.name.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(levelColor(event.level))
            }
            Text(event.message)
                .font(.body.monospaced())
                .multilineTextAlignment(.leading)
            Text("\(event.subsystem)/\(event.category)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if event.metadata.isEmpty == false {
                Text(event.metadataLine)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(Constants.metadataPreviewLineLimit)
            }
        }
        .padding(.vertical, Constants.verticalPadding)
    }

    func levelColor(_ level: MHLogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info, .notice:
            return .blue
        case .warning:
            return .orange
        case .error, .critical:
            return .red
        }
    }

    @ViewBuilder
    private func sessionScopePicker() -> some View {
        Picker(
            "Session",
            selection: $sessionScope
        ) {
            ForEach(availableSessionScopes, id: \.self) { scope in
                Text(scope.title)
                    .tag(scope)
            }
        }
    }

    @ViewBuilder
    private func captureLevelPicker(logging: MHLoggingBootstrap) -> some View {
        Picker(
            "Capture Level",
            selection: Binding(
                get: {
                    logging.captureLevel
                },
                set: { newValue in
                    logging.captureLevel = newValue
                    statusMessage = "Capture level set to \(newValue.name.uppercased())"
                }
            )
        ) {
            ForEach(MHLogLevel.allCases, id: \.self) { level in
                Text(level.name.uppercased())
                    .tag(level)
            }
        }
        .disabled(sessionScope == .previous)
    }

    @ViewBuilder
    private func captureSummaryText(captureLevel: MHLogLevel) -> some View {
        if sessionScope == .current {
            Text("Currently capturing \(captureLevel.name.uppercased()) and higher for new events.")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            Text("Previous session snapshots are read-only.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    @ViewBuilder
    private func previousSessionAvailabilityText(logging: MHLoggingBootstrap) -> some View {
        if logging.hasPreviousSession == false {
            Text("No previous session snapshot is available.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
#endif
