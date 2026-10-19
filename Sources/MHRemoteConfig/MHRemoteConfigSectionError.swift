/// Failure to select a required feature from a shared configuration response.
public enum MHRemoteConfigSectionError: Error, Equatable, Sendable {
    /// The feature key was absent; this is never a validated empty policy.
    case missing
}
