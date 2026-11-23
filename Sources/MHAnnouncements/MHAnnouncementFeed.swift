import Foundation
import MHRemoteUpdate

/// The complete, ordered contents of the optional `features.announcements` section.
public struct MHAnnouncementFeed: Codable, Sendable {
    private enum CodingKeys: CodingKey {
        case schemaVersion, defaultLanguage, items
    }

    private let schemaVersion: Int
    private let defaultLanguage: String
    private let items: [AnnouncementItem]

    /// Validates the entire feed before exposing any items from this publication.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container, debugDescription: "Unsupported announcement schema version"
            )
        }
        let language = try container.decode(String.self, forKey: .defaultLanguage)
        guard AnnouncementItem.isLanguageTag(language) else {
            throw DecodingError.dataCorruptedError(
                forKey: .defaultLanguage, in: container, debugDescription: "Invalid default language"
            )
        }
        defaultLanguage = language.lowercased()
        items = try container.decode([AnnouncementItem].self, forKey: .items)
        var identifiers: Set<String> = []
        for item in items {
            guard identifiers.insert(item.id).inserted, item.localizations[defaultLanguage] != nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .items, in: container, debugDescription: "Duplicate announcement ID or missing default text"
                )
            }
        }
    }

    /// Selects entries in publication order. Start is inclusive, end is exclusive,
    /// and version bounds are inclusive. An unknown version excludes targeted items.
    /// Pass the app's ordered language preferences when they differ from the device's.
    public func visibleAnnouncements(
        installedVersion: MHAppVersion?,
        at date: Date = .now,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> [MHAnnouncement] {
        items.compactMap { item in
            guard item.isVisible(at: date, installedVersion: installedVersion),
                  let text = item.text(for: preferredLanguages) ?? item.localizations[defaultLanguage] else {
                return nil
            }
            return .init(id: item.id, title: text.title, body: text.body)
        }
    }
}
