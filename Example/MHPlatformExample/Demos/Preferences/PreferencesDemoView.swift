import MHPlatform
import SwiftUI

struct PreferencesDemoView: View {
    private enum Constants {
        nonisolated static let suiteName = "MHPlatformExample.PreferencesDemo"
        nonisolated static let defaultSelection = MHUserDefaultsSelection.suite(suiteName)
        nonisolated static let boolStorageKey = "mhplatform.example.preferences.bool"
        nonisolated static let intStorageKey = "mhplatform.example.preferences.int"
        nonisolated static let stringStorageKey = "mhplatform.example.preferences.string"
        nonisolated static let codableStorageKey = "mhplatform.example.preferences.codable"
        nonisolated static let obsoleteStorageKey = "mhplatform.example.preferences.legacy"

        nonisolated static let defaultBoolValue = true
        nonisolated static let defaultIntValue = 5
        nonisolated static let intStepperRange = 0...100
        nonisolated static let rowSpacing = 6.0
    }

    nonisolated private struct DemoPreferencesPayload: Codable, Equatable, Sendable {
        let title: String
        let count: Int
    }

    private enum KnownStorageDescriptor: CaseIterable, MHStorageDescriptorProtocol {
        case bool
        case int
        case string
        case codable

        var storageKey: String {
            switch self {
            case .bool:
                Constants.boolStorageKey
            case .int:
                Constants.intStorageKey
            case .string:
                Constants.stringStorageKey
            case .codable:
                Constants.codableStorageKey
            }
        }

        var defaultSelection: MHUserDefaultsSelection {
            Constants.defaultSelection
        }
    }

    private struct CurrentValues {
        let boolValue: Bool
        let intValue: Int
        let stringValue: String
        let codableTitle: String
        let codableCount: Int
    }

    private static let userDefaults: UserDefaults = {
        Constants.defaultSelection.resolveUserDefaults()
    }()

    private static let boolKey = MHBoolPreferenceDescriptor(
        storageKey: Constants.boolStorageKey,
        defaultSelection: Constants.defaultSelection,
        default: Constants.defaultBoolValue
    )
    private static let intKey = MHIntPreferenceDescriptor(
        storageKey: Constants.intStorageKey,
        defaultSelection: Constants.defaultSelection,
        default: Constants.defaultIntValue
    )
    private static let stringKey = MHStringPreferenceDescriptor(
        storageKey: Constants.stringStorageKey,
        defaultSelection: Constants.defaultSelection
    )
    private static let codableKey = MHCodablePreferenceDescriptor<DemoPreferencesPayload>(
        storageKey: Constants.codableStorageKey,
        defaultSelection: Constants.defaultSelection
    )
    private static let obsoleteKey = MHRawStorageDescriptor(
        storageKey: Constants.obsoleteStorageKey,
        defaultSelection: Constants.defaultSelection
    )
    private static let store = MHPreferenceStore()

    private static var currentValues: CurrentValues {
        let boolValue = store.bool(for: boolKey)
        let intValue = store.int(for: intKey)
        let stringValue = store.string(for: stringKey) ?? .init()
        let payload = store.codable(for: codableKey) ?? DemoPreferencesPayload(
            title: .init(),
            count: intValue
        )

        return CurrentValues(
            boolValue: boolValue,
            intValue: intValue,
            stringValue: stringValue,
            codableTitle: payload.title,
            codableCount: payload.count
        )
    }

    @State private var boolValue: Bool
    @State private var intValue: Int
    @State private var stringValue: String
    @State private var codableTitle: String
    @State private var codableCount: Int
    @State private var status = "Use Save/Reload/Reset to inspect preference behavior."

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
            Toggle("Bool (\(Self.boolKey.storageKey))", isOn: $boolValue)

            Stepper(
                "Int (\(Self.intKey.storageKey)): \(intValue)",
                value: $intValue,
                in: Constants.intStepperRange
            )

            TextField("String (\(Self.stringKey.storageKey))", text: $stringValue)
                .autocorrectionDisabled()
        }
    }

    private var codableSection: some View {
        Section("Codable Value (Data)") {
            VStack(alignment: .leading, spacing: Constants.rowSpacing) {
                TextField("Payload title", text: $codableTitle)
                    .autocorrectionDisabled()

                Stepper(
                    "Payload count: \(codableCount)",
                    value: $codableCount,
                    in: Constants.intStepperRange
                )
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Save All") {
                saveAll()
            }
            Button("Reload from Store") {
                reloadFromStore()
            }
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
                Text(containsKey(Self.boolKey.storageKey) ? "true" : "false")
            }
            LabeledContent("Int exists") {
                Text(containsKey(Self.intKey.storageKey) ? "true" : "false")
            }
            LabeledContent("String exists") {
                Text(containsKey(Self.stringKey.storageKey) ? "true" : "false")
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

    private var codableStorageStatus: String {
        guard let rawObject = Self.userDefaults.object(forKey: Self.codableKey.storageKey) else {
            return "No value"
        }
        guard let storedData = rawObject as? Data else {
            return "Non-Data value type: \(String(describing: type(of: rawObject)))"
        }
        return "Data (\(storedData.count) bytes)"
    }

    init() {
        let values = Self.currentValues
        _boolValue = State(initialValue: values.boolValue)
        _intValue = State(initialValue: values.intValue)
        _stringValue = State(initialValue: values.stringValue)
        _codableTitle = State(initialValue: values.codableTitle)
        _codableCount = State(initialValue: values.codableCount)
    }

    private func containsKey(_ name: String) -> Bool {
        Self.userDefaults.object(forKey: name) != nil
    }

    private func saveAll() {
        Self.store.set(boolValue, for: Self.boolKey)
        Self.store.set(intValue, for: Self.intKey)

        let normalizedStringValue = stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if normalizedStringValue.isEmpty {
            Self.store.set(nil, for: Self.stringKey)
        } else {
            Self.store.set(normalizedStringValue, for: Self.stringKey)
        }

        let payload = DemoPreferencesPayload(
            title: codableTitle,
            count: codableCount
        )
        Self.store.setCodable(payload, for: Self.codableKey)
        status = "Saved values to dedicated suite \(Constants.suiteName)"
    }

    private func reloadFromStore() {
        let values = Self.currentValues
        boolValue = values.boolValue
        intValue = values.intValue
        stringValue = values.stringValue
        codableTitle = values.codableTitle
        codableCount = values.codableCount
        status = "Reloaded values from store"
    }

    private func resetKeys() {
        Self.store.remove(Self.boolKey)
        Self.store.remove(Self.intKey)
        Self.store.remove(Self.stringKey)
        Self.store.remove(Self.codableKey)
        Self.userDefaults.removeObject(forKey: Self.obsoleteKey.storageKey)
        reloadFromStore()
        status = "Removed all keys from suite"
    }

    private func insertUnknownKey() {
        Self.userDefaults.set(
            "legacy",
            forKey: Self.obsoleteKey.storageKey
        )
        status = "Inserted unknown key \(Self.obsoleteKey.storageKey)"
    }

    private func removeUnknownKeys() {
        let report = MHUserDefaultsCleanupService.removeUnknownKeys(
            from: Self.userDefaults,
            domainName: Constants.suiteName,
            knownKeys: KnownStorageDescriptor.allCases
        )

        if report.removedStorageKeys.isEmpty {
            status = "Cleanup ran without removing any keys"
            return
        }

        status = "Removed unknown keys: \(report.removedStorageKeys.joined(separator: ", "))"
    }
}
