import SwiftUI

struct RouteExecutionDemoView: View {
    @State private var model = RouteExecutionDemoModel()

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                readinessSection(model: model)
                sendRouteSection(model: model)
                pendingRouteSection(model: model)
                eventLogSection(model: model)
            }
            .navigationTitle("MHRouteExecution")
        }
        .task {
            await model.refreshPendingRouteStatus()
        }
    }

    private func readinessSection(
        model: RouteExecutionDemoModel
    ) -> some View {
        @Bindable var model = model

        return Section("Readiness") {
            Toggle(
                "Ready to execute routes",
                isOn: $model.isReady
            )
        }
    }

    private func sendRouteSection(
        model: RouteExecutionDemoModel
    ) -> some View {
        Section("Send Route") {
            ForEach(RouteExecutionDemoRoute.allCases) { route in
                Button(route.buttonTitle) {
                    model.submit(route)
                }
            }
        }
    }

    private func pendingRouteSection(
        model: RouteExecutionDemoModel
    ) -> some View {
        Section("Pending Route") {
            LabeledContent("Has pending route") {
                Text(model.hasPendingRoute ? "Yes" : "No")
                    .font(.caption.monospaced())
            }

            Button("Apply Pending Route") {
                model.applyPendingIfReady()
            }

            Button("Clear Pending Route") {
                model.clearPendingRoute()
            }
            .disabled(model.hasPendingRoute == false)
        }
    }

    private func eventLogSection(
        model: RouteExecutionDemoModel
    ) -> some View {
        Section("Execution Log") {
            if model.logs.isEmpty {
                Text("No events yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    model.logs.indices,
                    id: \.self
                ) { index in
                    Text(model.logs[index])
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }
}
