import Foundation
import MHAnnouncements
import MHRemoteUpdate
import Testing

struct MHAnnouncementFeedTests {
    private let localized = #"""
        {"en":{"title":"Update","body":"Details"},"ja":{"title":"更新","body":"詳細"},
        "zh-Hant":{"title":"更新","body":"說明"}}
    """#

    @Test
    func visibilityUsesPublicationOrderAndIndependentTimeAndVersionBounds() throws {
        let feed = try decode(items: [
            item("general"),
            item("targeted", fields: #"""
                "startsAt":"2026-01-01T00:00:00Z","endsAt":"2026-01-02T00:00:00Z",
                "minimumVersion":"2.9","maximumVersion":"2.10",
            """#)
        ]).features.announcements.get()
        let start = try Date("2026-01-01T00:00:00Z", strategy: .iso8601)
        let end = try Date("2026-01-02T00:00:00Z", strategy: .iso8601)
        func ids(_ date: Date, _ version: String?) -> [String] {
            feed.visibleAnnouncements(installedVersion: version.flatMap(MHAppVersion.init), at: date).map(\.id)
        }
        #expect(ids(start, "2.9.0") == ["general", "targeted"])
        #expect(ids(end.addingTimeInterval(-1), "2.10.0") == ["general", "targeted"])
        #expect(ids(end, "2.10") == ["general"])
        #expect(ids(start.addingTimeInterval(-1), "2.10") == ["general"])
        #expect(ids(start, "2.8.9") == ["general"])
        #expect(ids(start, "2.10.1") == ["general"])
        #expect(ids(start, nil) == ["general"])
    }

    @Test
    func languageSelectionUsesPreferenceOrderThenDefaultAcrossTitleAndBody() throws {
        let feed = try decode(items: [item("news")]).features.announcements.get()
        func copy(_ languages: [String]) throws -> MHAnnouncement {
            try #require(feed.visibleAnnouncements(installedVersion: nil, preferredLanguages: languages).first)
        }
        #expect(try copy(["de", "JA-jp", "en"]).title == "更新")
        #expect(try copy(["zh-Hant-TW"]).body == "說明")
        #expect(try copy(["de"]).body == "Details")
        #expect(try copy([]).title == "Update")
    }

    @Test
    func aStoredFeedCanReevaluateDatesAndLanguagesAfterReopening() throws {
        let feed = try decode(items: [
            item("news", fields: #""startsAt":"2026-01-01T00:00:00Z","minimumVersion":"2","#)
        ]).features.announcements.get()
        let restored = try JSONDecoder().decode(MHAnnouncementFeed.self, from: JSONEncoder().encode(feed))
        let start = try Date("2026-01-01T00:00:00Z", strategy: .iso8601)
        let version = try #require(MHAppVersion("2"))
        #expect(restored.visibleAnnouncements(installedVersion: version, at: start.addingTimeInterval(-1)).isEmpty)
        #expect(restored.visibleAnnouncements(installedVersion: nil, at: start).isEmpty)
        let visible = restored.visibleAnnouncements(installedVersion: version, at: start, preferredLanguages: ["ja"])
        #expect(visible.first?.body == "詳細")
    }

    @Test
    func invalidFeedsLeaveValidUpdatePolicyReadable() throws {
        let invalidItems = [
            [item("same"), item("same")], [item(" ")], [item("x", fields: #""minimumVersion":"1a","#)],
            [item("x", fields: #""startsAt":"tomorrow","#)],
            [item("x", fields: #""startsAt":"2026-01-01T00:00:00Z","endsAt":"2026-01-01T00:00:00Z","#)],
            [item("x", fields: #""minimumVersion":"2","maximumVersion":"1","#)],
            [item("x", translations: #"{"ja":{"title":"a","body":"b"}}"#)],
            [item("x", translations: #"{"en":{"title":" ","body":"b"}}"#)],
            [item("x", translations: #"{"en":{"title":"a","body":" "}}"#)],
            [item("x", translations: #"{"en":{"title":"a","body":"b"},"EN":{"title":"c","body":"d"}}"#)]
        ]
        for items in invalidItems {
            let features = try decode(items: items).features
            #expect(try features.remoteUpdate.get().revision == 1)
            #expect(throws: DecodingError.self) {
                try features.announcements.get()
            }
        }
    }

    @Test
    func anEmptyPublicationRemovesAllItemsAndFutureFormatsFailIndependently() throws {
        let feed = try decode(items: []).features.announcements.get()
        #expect(feed.visibleAnnouncements(installedVersion: nil).isEmpty)
        let features = try decode(items: [], schema: 2).features
        #expect(throws: DecodingError.self) {
            try features.announcements.get()
        }
        #expect(try features.remoteUpdate.get().revision == 1)
    }

    private func item(_ id: String, fields: String = "", translations: String? = nil) -> String {
        #"{"id":"\#(id)",\#(fields)"localizations":\#(translations ?? localized)}"#
    }

    private func decode(items: [String], schema: Int = 1) throws -> MHRemoteConfigDocument<MHRemoteAppFeatures> {
        try .decode(Data(#"""
            {"schemaVersion":1,"bundleIdentifier":"example.app","features":{
            "remoteUpdate":{"schemaVersion":1,"revision":1,"requirement":null},
            "announcements":{"schemaVersion":\#(schema),"defaultLanguage":"en","items":[
            \#(items.joined(separator: ","))]}}}
        """#.utf8))
    }
}
