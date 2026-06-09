import Foundation

package enum MHRuntimeTextNormalizer {
    package static func trimmedNonEmpty(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else {
            return nil
        }

        return normalizedText
    }

    package static func uniqueTrimmedNonEmptyValues(_ values: [String]) -> [String] {
        var normalizedValues: [String] = []
        var uniqueValues = Set<String>()

        for value in values {
            guard let normalizedValue = trimmedNonEmpty(value) else {
                continue
            }
            guard uniqueValues.contains(normalizedValue) == false else {
                continue
            }

            uniqueValues.insert(normalizedValue)
            normalizedValues.append(normalizedValue)
        }

        return normalizedValues
    }
}
