import MHPlatform
import SwiftUI

struct PreferencesDemoView: View {
    enum Constants {
        nonisolated static let suiteName = "MHPlatformExample.PreferencesDemo"
        nonisolated static let defaultSelection = MHUserDefaultsSelection.suite(suiteName)
        nonisolated static let obsoleteStorageKey = "mhplatform.example.preferences.legacy"

        nonisolated static let defaultIntValue = 5
        nonisolated static let intStepperRange = 0...100
        nonisolated static let rowSpacing = 6.0
    }

    private enum KnownStorageDescriptor: CaseIterable, MHStorageDescriptorProtocol {
        case bool
        case int
        case string
        case date
        case codable

        var storageKey: String {
            switch self {
            case .bool:
                MHPreferenceDescriptors().hasSeenOnboarding.storageKey
            case .int:
                MHPreferenceDescriptors().launchCount.storageKey
            case .string:
                MHPreferenceDescriptors().displayName.storageKey
            case .date:
                MHPreferenceDescriptors().lastSeenAt.storageKey
            case .codable:
                MHPreferenceDescriptors().userProfile.storageKey
            }
        }

        var defaultSelection: MHUserDefaultsSelection {
            Constants.defaultSelection
        }
    }

    private static let userDefaults = Constants.defaultSelection.resolveUserDefaults()
    private static let store = MHPreferenceStore(userDefaults: userDefaults)
    private static let obsoleteKey = MHRawStorageDescriptor(
        storageKey: Constants.obsoleteStorageKey,
        defaultSelection: Constants.defaultSelection
    )

    @AppStorage(\.hasSeenOnboarding)
    private var hasSeenOnboarding

    @AppStorage(\.launchCount)
    private var launchCount

    @AppStorage(\.displayName, default: "")
    private var displayName

    @AppStorage(\.lastSeenAt)
    private var lastSeenAt

    @MHCodablePreference(
        \MHPreferenceDescriptors.userProfile,
        default: .init(title: "", count: Constants.defaultIntValue)
    )
    private var userProfile: PreferencesDemoPayload

    @State private var status = "Wrappers write through immediately. Use actions to inspect cleanup behavior."

    var body: some View {
        NavigationStack {
            List {
                primitiveSection
                codableSection
                actionsSection
                rawStorageSection
                statusSection
            }
            .navigationTitle("MHPreferences")
        }
    }

    private var primitiveSection: some View {
        Section("Primitive Values") {
            Toggle(
                "Bool (\(MHPreferenceDescriptors().hasSeenOnboarding.storageKey))",
                isOn: $hasSeenOnboarding
            )

            Stepper(
                "Int (\(MHPreferenceDescriptors().launchCount.storageKey)): \(launchCount)",
                value: $launchCount,
                in: Constants.intStepperRange
            )

            TextField(
                "String (\(MHPreferenceDescriptors().displayName.storageKey))",
                text: $displayName
            )
            .autocorrectionDisabled()

            DatePicker(
                "Date (\(MHPreferenceDescriptors().lastSeenAt.storageKey))",
                selection: lastSeenAtBinding,
                displayedComponents: [.date, .hourAndMinute]
            )

            Button("Clear Date") {
                lastSeenAt = nil
                status = "Cleared stored date value"
            }
        }
    }

    private var codableSection: some View {
        Section("Codable Value (Data)") {
            VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                TextField("Payload title", text: userProfileTitleBinding)
                    .autocorrectionDisabled()

                Stepper(
                    "Payload count: \(userProfile.count)",
                    value: userProfileCountBinding,
                    in: Constants.intStepperRange
                )
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Reset Keys") {
                resetKeys()
            }
            Button("Insert Unknown Key") {
                insertUnknownKey()
            }
            Button("Remove Unknown Keys") {
                removeUnknownKeys()
            }
        }
    }

    private var rawStorageSection: some View {
        Section("Raw Storage") {
            LabeledContent("Bool exists") {
                Text(containsKey(MHPreferenceDescriptors().hasSeenOnboarding.storageKey) ? "true" : "false")
            }
            LabeledContent("Int exists") {
                Text(containsKey(MHPreferenceDescriptors().launchCount.storageKey) ? "true" : "false")
            }
            LabeledContent("String exists") {
                Text(containsKey(MHPreferenceDescriptors().displayName.storageKey) ? "true" : "false")
            }
            LabeledContent("Date exists") {
                Text(containsKey(MHPreferenceDescriptors().lastSeenAt.storageKey) ? "true" : "false")
            }
            LabeledContent("Codable") {
                Text(codableStorageStatus)
            }
            LabeledContent("Legacy key exists") {
                Text(containsKey(Self.obsoleteKey.storageKey) ? "true" : "false")
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Text(status)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

private extension PreferencesDemoView {
    var lastSeenAtBinding: Binding<Date> {
        .init(
            get: {
                lastSeenAt ?? .now
            },
            set: { newValue in
                lastSeenAt = newValue
                status = "Stored date value updated"
            }
        )
    }

    var userProfileTitleBinding: Binding<String> {
        .init(
            get: {
                userProfile.title
            },
            set: { newValue in
                userProfile = .init(
                    title: newValue,
                    count: userProfile.count
                )
                status = "Stored codable payload updated"
            }
        )
    }

    var userProfileCountBinding: Binding<Int> {
        .init(
            get: {
                userProfile.count
            },
            set: { newValue in
                userProfile = .init(
                    title: userProfile.title,
                    count: newValue
                )
                status = "Stored codable payload updated"
            }
        )
    }

    var codableStorageStatus: String {
        guard let rawObject = Self.userDefaults.object(
            forKey: MHPreferenceDescriptors().userProfile.storageKey
        ) else {
            return "No value"
        }
        guard let storedData = rawObject as? Data else {
            return "Non-Data value type: \(String(describing: type(of: rawObject)))"
        }
        return "Data (\(storedData.count) bytes)"
    }

    func containsKey(_ name: String) -> Bool {
        Self.userDefaults.object(forKey: name) != nil
    }

    func resetKeys() {
        let keys = MHPreferenceDescriptors()
        Self.store.remove(keys.hasSeenOnboarding)
        Self.store.remove(keys.launchCount)
        Self.store.remove(keys.displayName)
        Self.store.remove(keys.lastSeenAt)
        Self.store.remove(keys.userProfile)
        Self.userDefaults.removeObject(forKey: Self.obsoleteKey.storageKey)
        status = "Removed all known keys from suite"
    }

    func insertUnknownKey() {
        Self.userDefaults.set(
            "legacy",
            forKey: Self.obsoleteKey.storageKey
        )
        status = "Inserted unknown key \(Self.obsoleteKey.storageKey)"
    }

    func removeUnknownKeys() {
        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: Self.userDefaults,
            domainName: Constants.suiteName,
            knownDescriptors: KnownStorageDescriptor.allCases
        )

        if report.removedStorageKeys.isEmpty {
            status = "Cleanup ran without removing any keys"
            return
        }

        status = "Removed unknown keys: \(report.removedStorageKeys.joined(separator: ", "))"
    }
}

private extension MHPreferenceDescriptors {
    nonisolated var hasSeenOnboarding: MHBoolPreferenceDescriptor {
        .init(
            storageKey: "mhplatform.example.preferences.bool",
            defaultSelection: .suite("MHPlatformExample.PreferencesDemo"),
            default: true
        )
    }

    nonisolated var launchCount: MHIntPreferenceDescriptor {
        .init(
            storageKey: "mhplatform.example.preferences.int",
            defaultSelection: .suite("MHPlatformExample.PreferencesDemo"),
            default: PreferencesDemoView.Constants.defaultIntValue
        )
    }

    nonisolated var displayName: MHStringPreferenceDescriptor {
        .init(
            storageKey: "mhplatform.example.preferences.string",
            defaultSelection: .suite("MHPlatformExample.PreferencesDemo")
        )
    }

    nonisolated var lastSeenAt: MHDatePreferenceDescriptor {
        .init(
            storageKey: "mhplatform.example.preferences.date",
            defaultSelection: .suite("MHPlatformExample.PreferencesDemo")
        )
    }

    nonisolated var userProfile: MHCodablePreferenceDescriptor<PreferencesDemoPayload> {
        .init(
            storageKey: "mhplatform.example.preferences.codable",
            defaultSelection: .suite("MHPlatformExample.PreferencesDemo")
        )
    }
}
