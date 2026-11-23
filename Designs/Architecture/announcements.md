# In-app announcements

Publish app-owned, localized notices under `features.announcements` in the
app's existing HTTPS configuration. Apps choose when and where to show a
notice and whether to remember its ID as read. Publication takes effect on
the next successful fetch by a compatible client.

## Publication format

The section below can be added alongside `features.remoteUpdate`. Editing a
notice does not require a new update-policy revision.

```json
{
  "schemaVersion": 1,
  "defaultLanguage": "en",
  "items": [
    {
      "id": "export-maintenance",
      "startsAt": "2026-12-01T00:00:00Z",
      "endsAt": "2026-12-02T00:00:00Z",
      "minimumVersion": "2.0",
      "maximumVersion": "2.1",
      "localizations": {
        "en": { "title": "Export maintenance", "body": "Export may take longer today." },
        "ja": { "title": "書き出しのメンテナンス", "body": "本日は書き出しに時間がかかる場合があります。" }
      }
    }
  ]
}
```

- Use a stable, unique ID per notice. Keep the ID when correcting its text.
  Put items in display order. Publish an empty `items` array to clear the feed.
- All four date and version bounds are optional. The start is inclusive and
  the end is exclusive. Both version bounds are inclusive numeric app versions.
  If the installed version is unknown, only untargeted versions match.
- Supply plain-text title and body for the default language of every item.
  Match language keys case-insensitively. For each preferred language, try the
  full tag then its progressively shorter prefixes. For example,
  `zh-Hant-TW` can select `zh-Hant`, then `zh`. If no preference matches, use
  the published default. Title and body always use the same localization.
- An omitted section is missing. A malformed section is invalid, including
  unsupported schema versions, duplicate IDs, invalid bounds, and missing
  default text. These outcomes remain distinguishable from a valid empty feed.
  An invalid announcement section leaves a valid sibling update policy usable.

## Application integration

Import `MHPlatformCore` or `MHPlatform`. For existing App Store update
adopters, supply the announcement handoff when constructing the controller.
Continue calling the existing adapter's `prepare()` at startup and foreground.

```swift
let updates = try MHRemoteUpdateController(
    appStoreID: storeID,
    configurationURL: configurationURL,
    onAnnouncements: { response in
        continuation.yield(response)
    }
)
```

Here, `continuation` belongs to an app-owned `AsyncStream`. The handoff
synchronously enqueues the original observation for the app to consume. Inspect
`response.value` and use `response.fetchedAt` for an app-specific freshness
policy. Store a valid feed and call
`feed.visibleAnnouncements(installedVersion:at:preferredLanguages:)` when
presenting it, so date and language changes take effect. Supply the active
app language preferences and the containing app's marketing version. Keep
the handoff brief. Invalid update policy does not suppress a valid handoff.
A transport or envelope error yields no handoff. Apps can encode the validated
`MHAnnouncementFeed` for offline use and decode it on the next launch. Use
matching encoder and decoder date strategies. Apps choose the cache lifetime.

Apps that only display announcements can fetch
`MHRemoteConfigClient.configuration(from:bundleIdentifier:features:)` with
`MHRemoteAppFeatures.self` and select `response.value.features.announcements`.
The update section may be absent on that path. Focused consumers can use the
`MHAnnouncements` product and import `MHRemoteUpdate` for its version and
configuration APIs.

## Publisher verification

After building the [publisher tool](remote-update.md#publisher-validation),
run `mh-validate-remote-config --announcements candidate.json` on each
candidate in addition to the existing update-policy checks. An omitted
announcement section is valid for apps that have not adopted notices.
Keep historical update revision comparisons in the existing update-only mode
so an unrelated malformed announcement cannot hide a valid update baseline.
