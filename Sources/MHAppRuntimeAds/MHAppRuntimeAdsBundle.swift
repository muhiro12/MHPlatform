import Foundation
import MHAppRuntime
import OSLog
import SwiftUI

#if canImport(GoogleMobileAdsWrapper)
import GoogleMobileAdsWrapper
#endif

/// Bundle of package-owned ads runtime defaults.
public struct MHAppRuntimeAdsBundle {
    /// Ads startup bridge when ads are configured on the current platform.
    public let startAds: MHAppRuntime.StartAds?
    /// Factory for runtime-owned native ad views when ads are configured.
    public let nativeAdFactory: MHRuntimeNativeAdViewFactory?

    /// Creates package-owned ads runtime defaults.
    public init(configuration: MHAppConfiguration) {
        #if canImport(GoogleMobileAdsWrapper)
        guard let normalizedNativeAdUnitID = MHRuntimeTextNormalizer.trimmedNonEmpty(
            configuration.nativeAdUnitID
        ) else {
            startAds = nil
            nativeAdFactory = nil
            return
        }

        startAds = {
            Task { @MainActor in
                do {
                    try await GoogleMobileAdsController.start()
                } catch {
                    Logger(subsystem: "MHPlatform", category: "Ads")
                        .error("Ads initialization failed: \(error.localizedDescription)")
                }
            }
        }
        nativeAdFactory = .init { layout in
            MHRuntimeNativeAdView(adUnitID: normalizedNativeAdUnitID, layout: layout)
        }
        #else
        startAds = nil
        nativeAdFactory = nil
        #endif
    }
}
