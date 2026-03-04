# MHKit

MHKit is a Swift package workspace for shared app logic extracted from real usage in Incomes and Cookle. The current v1 baseline focuses on deep-link handling, deterministic notification planning, and post-mutation side-effect orchestration.

Minimum supported platforms:
- iOS 18.0+
- macOS 15.0+

## MHDeepLinking

`MHDeepLinking` handles route URL building, parsing, and pending-route handoff without owning app-specific route enums.

```swift
import MHDeepLinking

let codec = MHDeepLinkCodec<MyRoute>(
    configuration: .init(
        customScheme: "myapp",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: ["example.com"],
        universalLinkPathPrefix: "MyApp",
        preferredTransport: .customScheme
    )
)
```

## MHNotificationPlans

`MHNotificationPlans` builds deterministic reminder and suggestion schedules without depending on `UserNotifications`.

```swift
import MHNotificationPlans

let deliveryTime = MHNotificationTime(hour: 20, minute: 0)!
let policy = MHReminderPolicy(
    isEnabled: true,
    minimumAmount: 500,
    daysBeforeDueDate: 3,
    deliveryTime: deliveryTime,
    identifierPrefix: "upcoming-payment:"
)
```

## MHMutationFlow

`MHMutationFlow` runs a mutation with retry, cancellation, and ordered post-success side effects.

```swift
import MHMutationFlow

let outcome = await MHMutationRunner.run(
    operation: { "saved" },
    retryPolicy: .default,
    afterSuccess: [.init(name: "syncNotifications") {}]
)
```

## Example App

`MHKitExample` demonstrates all three modules with app-local sample data in `Example/`. It does not import any domain types from Incomes or Cookle.
