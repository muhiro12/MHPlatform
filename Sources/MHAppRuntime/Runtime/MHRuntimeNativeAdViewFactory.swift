import SwiftUI

/// Erased runtime-owned view factory for native ad views.
public struct MHRuntimeNativeAdViewFactory {
    private let makeAnyView: @MainActor (MHNativeAdLayout) -> AnyView

    /// Creates a runtime-owned native ad view factory from a view builder.
    @preconcurrency
    public init<Content: View>(
        @ViewBuilder _ makeView: @escaping @MainActor (MHNativeAdLayout) -> Content
    ) {
        makeAnyView = { layout in
            AnyView(makeView(layout))
        }
    }

    /// Builds the runtime-owned native ad view for the requested layout.
    @preconcurrency
    @MainActor
    public func makeView(
        layout: MHNativeAdLayout
    ) -> some View {
        makeAnyView(layout)
    }
}
