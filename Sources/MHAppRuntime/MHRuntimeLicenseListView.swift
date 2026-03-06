import SwiftUI

#if canImport(LicenseList)
import LicenseList
#endif

struct MHRuntimeLicenseListView: View {
    var body: some View {
        #if canImport(LicenseList)
        LicenseList.LicenseListView()
            .licenseViewStyle(.withRepositoryAnchorLink)
        #else
        Text("License list is unavailable on this platform.")
            .foregroundStyle(.secondary)
        #endif
    }
}
