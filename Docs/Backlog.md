# MHKit Backlog

This backlog is derived from concrete duplication found in `Incomes/` and `Cookle/`. Evidence paths are workspace-root relative and remain read-only references.

Current remaining priority after this phase:
1. Lightweight logging policy

## P0. Deep link URL grammar is duplicated

Problem:
Both apps independently build and parse custom-scheme and universal-link URLs, including path-prefix stripping and query handling.

Why now:
This duplication is already stable and isolated enough to extract without pulling in app navigation state.

Evidence:
- `Incomes/IncomesLibrary/Sources/Common/IncomesRouteParser.swift`
- `Incomes/IncomesLibrary/Sources/Common/IncomesRouteURLBuilder.swift`
- `Cookle/CookleLibrary/Sources/Common/CookleRouteParser.swift`
- `Cookle/CookleLibrary/Sources/Common/CookleRouteURLBuilder.swift`

Recommended module:
`MHDeepLinking`

Minimal API sketch:
- `MHDeepLinkConfiguration`
- `MHDeepLinkDescriptor`
- `MHDeepLinkRoute`
- `MHDeepLinkCodec`

ExampleApp validation:
Build sample routes, parse sample URLs, and verify custom/universal round-trips.

## P0. Pending route handoff is duplicated

Problem:
Both apps persist or queue a pending URL so that intents or notifications can open the main app later.

Why now:
This logic is small, shared, and independent from UI state machines.

Evidence:
- `Incomes/Incomes/Sources/Common/Intents/IncomesIntentRouteStore.swift`
- `Incomes/Incomes/Sources/Notification/Models/NotificationService.swift`
- `Cookle/Cookle/Sources/Main/Intents/CookleIntentRouteStore.swift`
- `Cookle/Cookle/Sources/Main/Services/MainRouteInbox.swift`

Recommended module:
`MHDeepLinking`

Minimal API sketch:
- `MHDeepLinkInbox`
- `MHDeepLinkStore`

ExampleApp validation:
Store a pending URL, consume it once, and show that the second consume returns `nil`.

## P0. Deterministic reminder scheduling is duplicated

Problem:
Incomes computes due-date reminders and Cookle computes daily suggestions with separate deterministic planners.

Why now:
The planning logic is pure and testable. It has clear value without any platform-specific notification adapter.

Evidence:
- `Incomes/IncomesLibrary/Sources/Notification/UpcomingPaymentPlanner.swift`
- `Incomes/IncomesLibrary/Sources/Notification/UpcomingPaymentNotificationPresentationBuilder.swift`
- `Cookle/CookleLibrary/Sources/Recipe/DailyRecipeSuggestionService.swift`

Recommended module:
`MHNotificationPlans`

Minimal API sketch:
- `MHNotificationTime`
- `MHReminderCandidate`, `MHReminderPolicy`, `MHReminderPlan`, `MHReminderPlanner`
- `MHSuggestionCandidate`, `MHSuggestionPolicy`, `MHSuggestionPlan`, `MHSuggestionPlanner`

ExampleApp validation:
Show stable reminder and suggestion schedules from fixed sample data and a fixed reference date.

## P0. Post-mutation side-effect orchestration is duplicated

Problem:
Mutation entrypoints in both apps mix primary save logic with widget reloads, notification sync, review requests, and cancellation concerns.

Why now:
This is a real cross-cutting concern already visible in multiple app services and coordinators.

Evidence:
- `Incomes/Incomes/Sources/Item/Models/ItemFormSaveCoordinator.swift`
- `Incomes/Incomes/Sources/Settings/Models/SettingsActionCoordinator.swift`
- `Cookle/Cookle/Sources/Recipe/Services/RecipeActionService.swift`
- `Cookle/Cookle/Sources/Diary/Services/DiaryActionService.swift`
- `Cookle/Cookle/Sources/Settings/Services/SettingsActionService.swift`

Recommended module:
`MHMutationFlow`

Minimal API sketch:
- `MHMutationRetryPolicy`
- `MHCancellationHandle`
- `MHMutationStep`
- `MHMutationRunner`

ExampleApp validation:
Run a sample mutation with retry, side-effect failure, and cancellation toggles.

## P1. Notification payload routing core was implemented

Status:
Implemented in this phase as `MHNotificationPayloads` (routing core + orchestration adapter).

What was extracted:
- payload route model (`default`, `fallback`, action map)
- action/category descriptors
- userInfo encode/decode codec
- response action to route resolution
- optional `UserNotifications` bridge helpers
- notification-center abstraction and adapter (`MHNotificationCentering`)
- orchestration helpers (`MHNotificationOrchestrator`, `MHNotificationRequestSyncResult`)

Evidence:
- `Incomes/Incomes/Sources/Notification/Models/NotificationService.swift`
- `Cookle/Cookle/Sources/Notification/Services/RecipeSuggestionNotificationComposer.swift`
- `Cookle/Cookle/Sources/Notification/Services/NotificationService.swift`
- `MHKit/Sources/MHNotificationPayloads/`

Remaining work:
- app-specific notification copy templates
- attachment generation and persistence policy
- app-specific adoption in Incomes/Cookle call sites

ExampleApp validation:
`NotificationPayloadsDemoView` demonstrates both Incomes-style and Cookle-style payload scenarios plus simulated orchestration flow.

## P1. Route execution decoupling adapter was implemented

Status:
Implemented in this phase as `MHRouteExecution`.

What was extracted:
- async route execution primitive (`MHRouteExecutor`)
- readiness-aware coordinator (`MHRouteCoordinator`)
- latest-wins pending queue behavior (`MHRouteResolution`)

Evidence:
- `Incomes/IncomesLibrary/Sources/Common/MainNavigationRouteExecutor.swift`
- `Cookle/CookleLibrary/Sources/Common/CookleRouteExecutor.swift`
- `Cookle/Cookle/Sources/Main/Services/MainRouteService.swift`
- `MHKit/Sources/MHRouteExecution/`

Remaining work:
- app-specific route enums and persistence lookups remain in each app
- app-specific UI state application remains in each app
- optional URL-input coordinator layer remains out of scope for v1

ExampleApp validation:
`RouteExecutionDemoView` demonstrates readiness changes, pending route handling, explicit pending application, and failure logging.

## P1. Preferences and storage codecs are inconsistent

Problem:
Both apps have lightweight preference helpers, but they encode settings in different ways and with different abstractions.

Why now:
Implemented in this phase as `MHPreferences` to provide typed keys, `UserDefaults` storage, codable `Data` persistence, and `AppStorage` bridges.

Evidence:
- `Incomes/IncomesLibrary/Sources/Common/AppStorageCodable.swift`
- `Incomes/IncomesLibrary/Sources/Common/NotificationSettings.swift`
- `Cookle/CookleLibrary/Sources/Common/CooklePreferences.swift`

Recommended module:
`MHPreferences` (implemented)

Minimal API sketch:
- `MHPreferenceKeyProtocol`
- `MHBoolPreferenceKey`, `MHIntPreferenceKey`, `MHStringPreferenceKey`, `MHCodablePreferenceKey`
- `MHPreferenceStore`
- `AppStorage` bridge initializers

ExampleApp validation:
`PreferencesDemoView` demonstrates bool/int/string/codable read-write-reset and raw stored value inspection.

## P2. Persistence migration and destructive reset unification was implemented

Status:
Implemented in this phase as `MHPersistenceMaintenance`.

What was extracted:
- store migration plan and skip semantics (`MHStoreMigrationPlan`, `MHStoreMigrationSkipReason`)
- deterministic migration and legacy cleanup outcomes (`MHStoreMigrationResult`, `MHStoreLegacyCleanupResult`)
- store migration and legacy cleanup execution (`MHStoreMigrator`)
- ordered destructive reset orchestration (`MHDestructiveResetStep`, `MHDestructiveResetService`, `MHDestructiveResetOutcome`)

Evidence:
- `Incomes/IncomesLibrary/Sources/Common/DatabaseMigrator.swift`
- `Incomes/IncomesLibrary/Sources/Common/DataMaintenanceService.swift`
- `Cookle/CookleLibrary/Sources/Common/DatabaseMigrator.swift`
- `Cookle/CookleLibrary/Sources/Common/DataResetService.swift`
- `MHKit/Sources/MHPersistenceMaintenance/`

Remaining work:
- app-specific adoption in Incomes/Cookle call sites is intentionally deferred
- migration-validation policy (for example object-count checks) remains app-specific

ExampleApp validation:
`PersistenceMaintenanceDemoView` demonstrates migration, legacy cleanup, and reset event flow with temporary sandbox files.

## P2. Review request policy unification was implemented

Status:
Implemented in this phase as `MHReviewPolicy`.

What was extracted:
- review request policy model (`MHReviewPolicy`)
- review request outcomes (`MHReviewRequestOutcome`)
- high-level requester API (`MHReviewRequester`)
- iOS live request path with guarded non-iOS fallback

Evidence:
- `Incomes/IncomesLibrary/Sources/Common/ReviewRequestPolicy.swift`
- `Cookle/Cookle/Sources/Main/Services/MainReviewService.swift`
- `Cookle/Cookle/Sources/Common/Services/CookleReviewRequester.swift`
- `MHKit/Sources/MHReviewPolicy/`

Remaining work:
- app-specific adoption in Incomes/Cookle call sites remains out of scope
- review trigger heuristics per feature remain app-level concerns

ExampleApp validation:
`ReviewPolicyDemoView` demonstrates policy evaluation and requester outcomes.

## P2. Lightweight logging policy is still inconsistent

Problem:
The apps still use app-local logging helpers with different wrappers and categories.

Why not now:
This phase focused on review request extraction with minimal safe scope.

Evidence:
- `Cookle/Cookle/Sources/Common/Logger.swift`
- app-local logging call sites across Incomes and Cookle

Recommended module:
Future observability layer

Minimal API sketch:
- `MHLogEvent`
- `MHLogSink`

ExampleApp validation:
Docs only for now.
