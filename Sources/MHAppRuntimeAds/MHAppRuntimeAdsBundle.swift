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
    /// UMP-backed consent bridge when ads and `adsConsent` are both configured.
    public let adsConsent: MHAdsConsentBridge?

    /// Creates package-owned ads runtime defaults.
    public init(configuration: MHAppConfiguration) {
        #if canImport(GoogleMobileAdsWrapper)
        guard let normalizedNativeAdUnitID = MHRuntimeTextNormalizer.trimmedNonEmpty(
            configuration.nativeAdUnitID
        ) else {
            startAds = nil
            nativeAdFactory = nil
            adsConsent = nil
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
        adsConsent = configuration.adsConsent.map { consentConfiguration in
            .googleMobileAds(configuration: consentConfiguration)
        }
        #else
        startAds = nil
        nativeAdFactory = nil
        adsConsent = nil
        #endif
    }
}
