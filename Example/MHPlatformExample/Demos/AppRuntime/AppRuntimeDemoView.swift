import MHPlatform
import SwiftUI

struct AppRuntimeDemoView: View {
    private enum Layout {
        static let minimumAdHeight = CGFloat(Int("72") ?? .zero)
    }

    @Environment(MHAppRuntime.self)
    private var runtime

    @State private var nativeAdSize: MHNativeAdSize = .small

    var body: some View {
        NavigationStack {
            List {
                statusSection
                controlsSection
                runtime.subscriptionSectionView()
                nativeAdSection
                licensesSection
            }
            .navigationTitle("MHAppRuntime")
        }
    }

    private var statusSection: some View {
        Section("Runtime Status") {
            LabeledContent("Started") {
                Text(runtime.hasStarted ? "true" : "false")
            }
            LabeledContent("Premium Status") {
                Text(runtime.premiumStatus.rawValue)
            }
            LabeledContent("Ads Availability") {
                Text(runtime.adsAvailability.rawValue)
            }
        }
    }

    private var controlsSection: some View {
        Section("Controls") {
            Button("Start Runtime") {
                runtime.startIfNeeded()
            }
            .disabled(runtime.hasStarted)
        }
    }

    private var nativeAdSection: some View {
        Section("Native Ad") {
            Picker("Ad Size", selection: $nativeAdSize) {
                Text("Small").tag(MHNativeAdSize.small)
                Text("Medium").tag(MHNativeAdSize.medium)
            }
            .pickerStyle(.segmented)

            runtime.nativeAdView(size: nativeAdSize)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Layout.minimumAdHeight)

            if runtime.adsAvailability != .available {
                Text("Ad rendering is disabled for the current runtime state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var licensesSection: some View {
        Section("Licenses") {
            if runtime.configuration.showsLicenses {
                NavigationLink("Open Licenses") {
                    runtime.licensesView()
                        .navigationTitle("Licenses")
                }
            } else {
                Text("License surface is disabled in runtime configuration.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AppRuntimeDemoView()
        .environment(
            MHAppRuntime(
                configuration: .init(
                    subscriptionProductIDs: ["com.example.mhplatform.premium.monthly"],
                    nativeAdUnitID: MHPlatformExampleAdMobConfiguration.nativeAdUnitID,
                    preferencesSuiteName: "MHPlatformExample.Runtime",
                    showsLicenses: true
                )
            )
        )
}
