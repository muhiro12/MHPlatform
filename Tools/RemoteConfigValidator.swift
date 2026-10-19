import Foundation
import MHRemoteUpdate

@main
enum RemoteConfigValidator {
    private enum Failure: Error, CustomStringConvertible {
        case usage

        var description: String {
            "Usage: mh-validate-remote-config <candidate.json> [previous.json]"
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
        let candidate = try decode(path)
        if arguments.count == maximumArgumentCount {
            try candidate.validateReplacement(of: decode(arguments[1]))
        }
        print("Validated \(candidate.bundleIdentifier), remoteUpdate revision \(candidate.revision)")
    }

    private static func decode(_ path: String) throws -> MHRemoteUpdateSchedule {
        try .decode(Data(contentsOf: URL(fileURLWithPath: path)))
    }
}
