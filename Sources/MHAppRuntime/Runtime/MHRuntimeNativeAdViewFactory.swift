import SwiftUI

/// Erased runtime-owned view factory for native ad views.
public struct MHRuntimeNativeAdViewFactory {
    private let makeAnyView: (MHNativeAdLayout) -> AnyView

    /// Creates a runtime-owned native ad view factory from a view builder.
    public init<Content: View>(
        @ViewBuilder _ makeView: @escaping (MHNativeAdLayout) -> Content
    ) {
        makeAnyView = { layout in
            AnyView(makeView(layout))
        }
    }

    /// Builds the runtime-owned native ad view for the requested layout.
    public func makeView(
        layout: MHNativeAdLayout
    ) -> some View {
        makeAnyView(layout)
    }
}
