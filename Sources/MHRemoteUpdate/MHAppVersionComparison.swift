import Foundation

/// String comparison for adopters whose existing policy uses Foundation numeric ordering.
public enum MHAppVersionComparison {
    /// Preserves `String.compare(options: .numeric)`, including unequal component counts.
    ///
    /// Unlike `MHAppVersion`, this does not validate or zero-pad either string.
    /// Use the validated value type for new component-based policies.
    public static func numericStringsRequireUpdate(
        currentVersion: String,
        minimumVersion: String
    ) -> Bool {
        currentVersion.compare(minimumVersion, options: .numeric) == .orderedAscending
    }
}
