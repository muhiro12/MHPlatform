import MHAppRuntimeCore
import SwiftUI

/// Bundle of package-owned license view runtime defaults.
public struct MHAppRuntimeLicensesBundle {
    /// Builder for the runtime-owned license view.
    public let licensesViewBuilder: MHAppRuntime.LicensesViewBuilder

    /// Creates package-owned license view runtime defaults.
    public init(configuration: MHAppConfiguration) {
        licensesViewBuilder = {
            if configuration.showsLicenses {
                AnyView(MHRuntimeLicenseListView())
            } else {
                AnyView(EmptyView())
            }
        }
    }
}
