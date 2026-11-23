import Foundation
import MHRemoteUpdate

struct AnnouncementItem: Codable, Sendable {
    struct Text: Codable, Sendable {
        let title: String
        let body: String
    }

    private enum CodingKeys: CodingKey {
        case id, startsAt, endsAt, minimumVersion, maximumVersion, localizations
    }

    let id: String
    let localizations: [String: Text]
    private let startsAt: Date?
    private let endsAt: Date?
    private let minimumVersion: MHAppVersion?
    private let maximumVersion: MHAppVersion?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        guard id.isEmpty == false, id == id.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid ID")
        }
        startsAt = try container.decodeIfPresent(Date.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        if let startsAt, let endsAt, startsAt >= endsAt {
            throw DecodingError.dataCorruptedError(forKey: .endsAt, in: container, debugDescription: "Invalid window")
        }
        minimumVersion = try container.decodeIfPresent(MHAppVersion.self, forKey: .minimumVersion)
        maximumVersion = try container.decodeIfPresent(MHAppVersion.self, forKey: .maximumVersion)
        if let minimumVersion, let maximumVersion, minimumVersion > maximumVersion {
            throw DecodingError.dataCorruptedError(
                forKey: .maximumVersion, in: container, debugDescription: "Reversed version bounds"
            )
        }
        let translations = try container.decode([String: Text].self, forKey: .localizations)
        var normalized = [String: Text]()
        for (language, text) in translations {
            guard Self.isLanguageTag(language), normalized[language.lowercased()] == nil,
                  text.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  text.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw DecodingError.dataCorruptedError(
                    forKey: .localizations, in: container, debugDescription: "Invalid language key or empty text"
                )
            }
            normalized[language.lowercased()] = text
        }
        localizations = normalized
    }

    static func isLanguageTag(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard let first = parts.first, first.isEmpty == false,
              first.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            return false
        }
        return parts.dropFirst().allSatisfy { part in
            part.isEmpty == false && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        }
    }

    func isVisible(at date: Date, installedVersion: MHAppVersion?) -> Bool {
        if let startsAt, date < startsAt {
            return false
        }
        if let endsAt, date >= endsAt {
            return false
        }
        guard let installedVersion else {
            return minimumVersion == nil && maximumVersion == nil
        }
        return minimumVersion.map { installedVersion >= $0 } != false
            && maximumVersion.map { installedVersion <= $0 } != false
    }

    func text(for languages: [String]) -> Text? {
        for language in languages {
            var tag = language.lowercased()[...]
            while tag.isEmpty == false {
                if let text = localizations[String(tag)] {
                    return text
                }
                guard let separator = tag.lastIndex(of: "-") else {
                    break
                }
                tag = tag[..<separator]
            }
        }
        return nil
    }
}
