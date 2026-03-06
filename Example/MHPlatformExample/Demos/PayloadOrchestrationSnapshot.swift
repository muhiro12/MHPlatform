#if canImport(UserNotifications)
struct PayloadOrchestrationSnapshot {
    static let empty = Self(
        authorizationStatusDescription: "pending",
        registeredCategoryIdentifiers: ["none"],
        removedPendingIdentifiers: ["none"],
        addedRequestIdentifiers: ["none"],
        failedRequestIdentifiers: ["none"],
        resolvedRouteURLString: "pending",
        pendingIdentifiersAfterSync: ["none"]
    )

    let authorizationStatusDescription: String
    let registeredCategoryIdentifiers: [String]
    let removedPendingIdentifiers: [String]
    let addedRequestIdentifiers: [String]
    let failedRequestIdentifiers: [String]
    let resolvedRouteURLString: String
    let pendingIdentifiersAfterSync: [String]
}
#endif
