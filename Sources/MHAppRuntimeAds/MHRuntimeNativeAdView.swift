#if canImport(GoogleMobileAdsWrapper)
import GoogleMobileAdsWrapper
import MHAppRuntime
import SwiftUI

/// Waits for SDK initialization before allowing the view to request an ad.
struct MHRuntimeNativeAdView: View {
    let adUnitID: String
    let layout: MHNativeAdLayout

    @State private var isInitialized = false

    private var wrapperLayout: NativeAdLayout {
        switch layout {
        case .compact:
            .compact
        case .media:
            .media
        }
    }

    var body: some View {
        Group {
            if isInitialized {
                NativeAdView(adUnitID: adUnitID, layout: wrapperLayout)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .task {
            do {
                try await GoogleMobileAdsController.start()
                isInitialized = true
            } catch {
                // Cancellation leaves the view idle; reappearance retries initialization.
            }
        }
    }
}
#endif
