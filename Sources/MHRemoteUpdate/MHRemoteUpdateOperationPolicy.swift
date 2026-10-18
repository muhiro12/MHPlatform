/// Standard MH operation rules; the app decides which operations may use the relaxed rule.
public enum MHRemoteUpdateOperationPolicy: Equatable, Sendable {
    /// Refresh once if evidence is unavailable, then require confirmed permission.
    case requireConfirmation
    /// Permit app-designated low-impact operations while evidence is unavailable, without networking.
    case allowWhenUnavailable
}
