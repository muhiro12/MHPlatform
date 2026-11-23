import Foundation
import MHAnnouncements
import MHRemoteUpdate

@main
enum RemoteConfigValidator {
    private enum HistoricalFeatureKey: CodingKey {
        case remoteUpdate
    }

    private struct HistoricalFeatures: Decodable, Sendable {
        let remoteUpdate: MHRemoteUpdateSchedule.Feature

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: HistoricalFeatureKey.self)
            remoteUpdate = try .init(
                from: container.superDecoder(forKey: .remoteUpdate),
                allowingImplicitSchemaVersion: true
            )
        }
    }

    private enum Failure: Error, CustomStringConvertible {
        case usage

        var description: String {
            "Usage: mh-validate-remote-config <candidate> [previous] or (--announcements | --historical) <file>"
        }
    }

    private static let maximumArgumentCount = 2

    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("Configuration validation failed: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard (1...maximumArgumentCount).contains(arguments.count), let path = arguments.first else {
            throw Failure.usage
        }
        if path == "--announcements" {
            guard arguments.count == maximumArgumentCount else {
                throw Failure.usage
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
            let document = try MHRemoteConfigDocument<MHRemoteAppFeatures>.decode(data)
            if case .missing = document.features.announcements {
                print("No announcements section for \(document.bundleIdentifier)")
            } else {
                _ = try document.features.announcements.get()
                print("Validated \(document.bundleIdentifier) announcements")
            }
            return
        }
        if path == "--historical" {
            guard arguments.count == maximumArgumentCount else {
                throw Failure.usage
            }
            let previous = try historicalSchedule(at: arguments[1])
            print("Validated historical \(previous.bundleIdentifier), remoteUpdate revision \(previous.revision)")
            return
        }
        let candidate = try decode(path)
        if arguments.count == maximumArgumentCount {
            try candidate.validateReplacement(of: historicalSchedule(at: arguments[1]))
        }
        print("Validated \(candidate.bundleIdentifier), remoteUpdate revision \(candidate.revision)")
    }

    private static func historicalSchedule(at path: String) throws -> MHRemoteUpdateSchedule {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let document = try MHRemoteConfigDocument<HistoricalFeatures>.decode(data)
        return try .init(bundleIdentifier: document.bundleIdentifier, feature: document.features.remoteUpdate)
    }

    private static func decode(_ path: String) throws -> MHRemoteUpdateSchedule {
        try .decode(Data(contentsOf: URL(fileURLWithPath: path)))
    }
}
