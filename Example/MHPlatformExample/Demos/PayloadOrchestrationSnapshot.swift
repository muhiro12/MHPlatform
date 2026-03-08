#if canImport(UserNotifications)
struct PayloadOrchestrationSnapshot {
    static let empty = Self(
        authorizationStatusDescription: "pending",
        registeredCategoryIdentifiers: ["none"],
        removedPendingIdentifiers: ["none"],
        addedRequestIdentifiers: ["none"],
        failedRequestIdentifiers: ["none"],
        deliveredPendingRouteURLString: "pending",
        deliverySourceDescription: "pending",
        pendingIdentifiersAfterSync: ["none"]
    )

    let authorizationStatusDescription: String
    let registeredCategoryIdentifiers: [String]
    let removedPendingIdentifiers: [String]
    let addedRequestIdentifiers: [String]
    let failedRequestIdentifiers: [String]
    let deliveredPendingRouteURLString: String
    let deliverySourceDescription: String
    let pendingIdentifiersAfterSync: [String]
}
#endif
