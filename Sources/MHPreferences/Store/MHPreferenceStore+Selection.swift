import Foundation

public extension MHPreferenceStore {
    /// Creates a bound store that overrides every descriptor's default selection.
    ///
    /// Uses the same validation as `MHUserDefaultsSelection.resolveUserDefaults()`.
    /// This does not change descriptor selections or lifecycle cleanup targets.
    init(
        selection: MHUserDefaultsSelection,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.init(
            userDefaults: selection.resolveUserDefaults(),
            encoder: encoder,
            decoder: decoder
        )
    }
}
