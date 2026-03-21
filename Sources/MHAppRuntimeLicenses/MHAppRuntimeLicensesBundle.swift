import MHAppRuntimeCore
import SwiftUI

/// Bundle of package-owned license view runtime defaults.
public struct MHAppRuntimeLicensesBundle {
    /// Factory for the runtime-owned license view.
    public let licensesFactory: MHRuntimeViewFactory

    /// Creates package-owned license view runtime defaults.
    public init(configuration: MHAppConfiguration) {
        licensesFactory = .init {
            if configuration.showsLicenses {
                MHRuntimeLicenseListView()
            } else {
                EmptyView()
            }
        }
    }
}
