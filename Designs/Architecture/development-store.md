# Isolated development store

The [development-store fixture](../../Fixtures/Consumers/SharedLibraryConsumer/Sources/SharedLibraryConsumer/DevelopmentStore.swift)
is an app-owned recipe, not an MHPlatform API or a database-switching service.
It complements the [host, extension, and Preview assembly](minimal-app-setup.md#one-swiftdata-store-for-the-app-family).
Its [disk tests](../../Fixtures/Consumers/SharedLibraryConsumer/Tests/SharedLibraryConsumerTests/DevelopmentStoreTests.swift)
use fabricated records and unique temporary directories.

## Choose the store once at startup

In an adopting app, keep one development-store owner for the host's lifetime.
Use an app-local Application Support subdirectory reserved for development,
outside the real store, App Group, and synchronized locations. Supply the same
directory on subsequent launches. Temporary directories are appropriate for
tests, but the system may remove them; they are not durable development storage.

For example, the DEBUG branch of the app's assembly can use:

```swift
#if DEBUG
let directory = URL.applicationSupportDirectory.appending(path: "JournalDevelopment")
let developmentStore = try DevelopmentStore(
    directory: directory,
    automaticallyInsertSamples: true
)
let container = developmentStore.container
#else
let container = try sharedStoreAssembly.host()
#endif
```

Retain `developmentStore` in the DEBUG assembly if it exposes manual insertion.
The fixture uses its own small `JournalEntry` model; adapt the schema and sample
values to the app. Do not migrate or repoint an existing user store to this
location. Extensions retain their existing-store reader contract; this recipe
does not switch the app family between databases while running.

The development container always uses an explicit file URL and
[`cloudKitDatabase: .none`](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct/none).
Errors propagate to the host. There is no fallback to the shared/user store,
in-memory storage, or automatic deletion of an unreadable database.

## Initialize once, insert manually when requested

The presence of `Development.store` distinguishes first creation from reopening.
Only first creation can insert samples automatically. The store file itself
records that initialization was attempted, including an opt-out; no preference
flag or sample-count heuristic is needed.

- Change `automaticallyInsertSamples` to `false` for a new empty development
  store. This does not delete records in an existing store.
- Reopening preserves edits and intentional deletion of all entries. Turning
  automatic insertion back on does not repopulate an already created store.
- A failure after creating the file also leaves automatic insertion disabled
  on reopening. Inspect the error, then explicitly insert samples if appropriate.
  This deliberately favors preserving the store over retrying initialization.
- To exercise first creation again, choose a new dedicated development directory.
  Deleting/resetting a store is a separate deliberate operation, not an opt-out
  side effect. Never remove individual SQLite files while a container is open.

The DEBUG-only manual action calls
`developmentStore.insertSamples(into: context)`, independently of the automatic
setting. It accepts only a context from the exact container created by that
owner, rejects pending edits, and requires the development store to be empty.
An arbitrary real/shared/cloud-backed container cannot be substituted. Insertion
and saving are synchronous on the main actor; a failed save rolls back only the
sample changes. The host should finish or cancel editing before offering this
action and keep one owner/writer for this local development store.

`JournalSamples` contains fabricated value definitions shared by the disk tests
and an isolated Preview example. A Preview creates its own in-memory container
through `SharedStoreAssembly.preview()`; it never opens the development disk
store or resolves the App Group. Keep app inventories and user records out of
these sample definitions.

## Expose diagnostics without development controls

When a host needs diagnostics in its distributed app, provide an ordinary
discoverable route, such as Settings → Advanced → Debug. The app owns the route,
wording, permitted information, and privacy filtering. Visibility is not an
authorization boundary.

Reuse `MHLogConsoleView` from `MHLoggingUI` for suitable logs and
`MHRemoteUpdateController.evaluation()` for a read-only view of retained update
evidence. The latter does not fetch, restore, save, or renew evidence; operation
permission still comes from the operation check. The log console also supports
export and clearing logs, so it is not a read-only or automatically redacted
surface. Decide what can be logged and exported before exposing it.

Keep sample insertion, test controls, and entitlement overrides behind actual
`#if DEBUG` compilation in both the UI and their implementation. The fixture's
development owner and sample definitions are absent from Release builds.
Retain operation-level target checks even in DEBUG. A hidden gesture, saved
unlock, or runtime flag must not enable these capabilities in distributed builds.
No new diagnostic engine, common settings UI, or entitlement bypass is needed.

## Verification boundary

Run the repository's retained consumer-fixture checks. The tests exercise first
creation, preserved edits, deliberate deletion followed by reopening, opt-out,
explicit insertion, rejection of foreign containers and pending edits, Preview
isolation, and a failing storage location. Compile the fixture in Release as
well to check that the DEBUG-only implementation is excluded.

These are local persistence and compilation checks. They do not establish live
CloudKit behavior, signed entitlements, device convergence, app navigation,
or the privacy of any adopting app's diagnostic contents.
