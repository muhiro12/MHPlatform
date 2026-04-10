#if canImport(SwiftUI)
import SwiftUI

extension View {
    @ViewBuilder
    func logConsoleTextSelectionIfSupported() -> some View {
        #if os(watchOS)
        self
        #else
        self.textSelection(.enabled)
        #endif
    }
}
#endif
