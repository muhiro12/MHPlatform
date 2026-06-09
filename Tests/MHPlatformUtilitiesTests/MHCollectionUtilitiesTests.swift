import MHPlatformUtilities
import Testing

struct MHCollectionUtilitiesTests {
    @Test
    func collectionEmptyAndIsNotEmpty() {
        let emptyArray = [Int].empty
        #expect(emptyArray.isEmpty)
        #expect(!emptyArray.isNotEmpty)

        let array = [1, 2, 3]
        #expect(array.isNotEmpty)
    }

    @Test
    func optionalCollectionOrEmptyAndIsNotEmpty() {
        // swiftlint:disable:next discouraged_optional_collection
        let missingArray: [Int]? = nil
        #expect(missingArray.orEmpty.isEmpty)
        #expect(!missingArray.isNotEmpty)

        // swiftlint:disable:next discouraged_optional_collection
        let presentArray: [Int]? = [1]
        #expect(presentArray.orEmpty.count == 1)
        #expect(presentArray.isNotEmpty)
    }
}
