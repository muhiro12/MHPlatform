/// Runtime native ad layout values exposed without leaking SDK-specific types.
public enum MHNativeAdLayout: String, Sendable, CaseIterable {
    /// Compact arrangement that prioritizes text.
    case compact

    /// Media-forward arrangement for images and video.
    case media
}
