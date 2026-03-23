import Foundation
import MHAppRuntime
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
        guard let normalizedNativeAdUnitID = Self.normalizeText(
            configuration.nativeAdUnitID
        ) else {
            startAds = nil
            nativeAdFactory = nil
            return
        }

        let controller = GoogleMobileAdsController(
            adUnitID: normalizedNativeAdUnitID
        )

        startAds = {
            controller.start()
        }
        nativeAdFactory = .init { size in
            controller.buildNativeAd(size.wrapperSizeID)
        }
        #else
        startAds = nil
        nativeAdFactory = nil
        #endif
    }
}

private extension MHAppRuntimeAdsBundle {
    static func normalizeText(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            return nil
        }

        return normalized
    }
}
