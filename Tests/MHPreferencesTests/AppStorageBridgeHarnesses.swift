#if canImport(SwiftUI)
import Foundation
import MHPreferences
import SwiftUI

enum AppStorageBridgeHarnesses {
    enum DemoRawStringValue: String {
        case first
        case second
    }

    struct TypeInferenceSnapshot {
        let boolValue: Bool
        let intValue: Int
        let stringValue: String?
        let requiredStringValue: String
        let rawStringValue: DemoRawStringValue
        let dateValue: Date?
    }

    struct TypeInferenceHarness {
        static let boolSuiteName = "AppStorageBridgeTests.TypeInference.bool"
        static let intSuiteName = "AppStorageBridgeTests.TypeInference.int"
        static let stringSuiteName = "AppStorageBridgeTests.TypeInference.string"
        static let requiredStringSuiteName = "AppStorageBridgeTests.TypeInference.required-string"
        static let rawStringSuiteName = "AppStorageBridgeTests.TypeInference.raw-string"
        static let dateSuiteName = "AppStorageBridgeTests.TypeInference.date"

        static let boolKey = MHBoolPreferenceDescriptor(
            storageKey: "\(AppStorageBridgeTestSupport.Constants.storageKeyPrefix).type-inference.bool",
            defaultSelection: .suite(boolSuiteName),
            default: AppStorageBridgeTestSupport.Constants.boolDefaultValue
        )
        static let intKey = MHIntPreferenceDescriptor(
            storageKey: "\(AppStorageBridgeTestSupport.Constants.storageKeyPrefix).type-inference.int",
            defaultSelection: .suite(intSuiteName),
            default: AppStorageBridgeTestSupport.Constants.intDefaultValue
        )
        static let stringKey = MHStringPreferenceDescriptor(
            storageKey: "\(AppStorageBridgeTestSupport.Constants.storageKeyPrefix).type-inference.string",
            defaultSelection: .suite(stringSuiteName)
        )
        static let requiredStringKey = MHStringPreferenceDescriptor(
            storageKey: "\(AppStorageBridgeTestSupport.Constants.storageKeyPrefix).type-inference.required-string",
            defaultSelection: .suite(requiredStringSuiteName)
        )
        static let rawStringKey = MHStringPreferenceDescriptor(
            storageKey: "\(AppStorageBridgeTestSupport.Constants.storageKeyPrefix).type-inference.raw-string",
            defaultSelection: .suite(rawStringSuiteName)
        )
        static let dateKey = MHDatePreferenceDescriptor(
            storageKey: "\(AppStorageBridgeTestSupport.Constants.storageKeyPrefix).type-inference.date",
            defaultSelection: .suite(dateSuiteName)
        )

        @AppStorage(Self.boolKey)
        private var boolValue

        @AppStorage(Self.intKey)
        private var intValue

        @AppStorage(Self.stringKey)
        private var stringValue

        @AppStorage(Self.requiredStringKey, default: "fallback")
        private var requiredStringValue

        @AppStorage(Self.rawStringKey, default: DemoRawStringValue.first)
        private var rawStringValue

        @AppStorage(Self.dateKey)
        private var dateValue

        var snapshot: TypeInferenceSnapshot {
            .init(
                boolValue: boolValue,
                intValue: intValue,
                stringValue: stringValue,
                requiredStringValue: requiredStringValue,
                rawStringValue: rawStringValue,
                dateValue: dateValue
            )
        }
    }

    struct BoolHarness {
        @AppStorage private var value: Bool

        var wrappedValue: Bool {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHBoolPreferenceDescriptor,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }

        init(
            key: MHBoolPreferenceDescriptor
        ) {
            _value = AppStorage(
                key
            )
        }
    }

    struct IntHarness {
        @AppStorage private var value: Int

        var wrappedValue: Int {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHIntPreferenceDescriptor,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
    }

    struct StringHarness {
        @AppStorage private var value: String?

        var wrappedValue: String? {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHStringPreferenceDescriptor,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
    }

    struct RequiredStringHarness {
        @AppStorage private var value: String

        var wrappedValue: String {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHStringPreferenceDescriptor,
            default defaultValue: String,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                default: defaultValue,
                store: store
            )
        }
    }

    struct RawStringHarness {
        @AppStorage private var value: DemoRawStringValue

        var wrappedValue: DemoRawStringValue {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHStringPreferenceDescriptor,
            default defaultValue: DemoRawStringValue,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                default: defaultValue,
                store: store
            )
        }
    }

    struct DateHarness {
        @AppStorage private var value: Date?

        var wrappedValue: Date? {
            get {
                value
            }
            set {
                value = newValue
            }
        }

        init(
            key: MHDatePreferenceDescriptor,
            store: UserDefaults
        ) {
            _value = AppStorage(
                key,
                store: store
            )
        }
    }
}
#endif
