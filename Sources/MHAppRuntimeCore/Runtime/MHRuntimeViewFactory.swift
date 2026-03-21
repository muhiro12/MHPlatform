import SwiftUI

/// Erased runtime-owned view factory for views without input parameters.
public struct MHRuntimeViewFactory {
    private let makeAnyView: () -> AnyView

    /// Creates a runtime-owned view factory from a regular view builder.
    public init<Content: View>(
        @ViewBuilder _ makeView: @escaping () -> Content
    ) {
        makeAnyView = {
            AnyView(makeView())
        }
    }

    /// Builds the runtime-owned view.
    public func makeView() -> some View {
        makeAnyView()
    }
}
