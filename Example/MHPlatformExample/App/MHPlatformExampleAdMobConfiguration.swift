enum MHPlatformExampleAdMobConfiguration {
    // Matches Google's sample native ad unit for local development.
    static let nativeAdUnitIDDev = "ca-app-pub-3940256099942544/3986624511"

    static var nativeAdUnitID: String? {
        #if os(iOS) && DEBUG
        nativeAdUnitIDDev
        #else
        nil
        #endif
    }
}
