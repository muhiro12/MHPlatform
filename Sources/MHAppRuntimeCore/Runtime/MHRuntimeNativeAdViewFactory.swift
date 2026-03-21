import SwiftUI

/// Erased runtime-owned view factory for native ad views.
public struct MHRuntimeNativeAdViewFactory {
    private let makeAnyView: (MHNativeAdSize) -> AnyView

    /// Creates a runtime-owned native ad view factory from a view builder.
    public init<Content: View>(
        @ViewBuilder _ makeView: @escaping (MHNativeAdSize) -> Content
    ) {
        makeAnyView = { size in
            AnyView(makeView(size))
        }
    }

    /// Builds the runtime-owned native ad view for the requested size.
    public func makeView(
        size: MHNativeAdSize
    ) -> some View {
        makeAnyView(size)
    }
}
