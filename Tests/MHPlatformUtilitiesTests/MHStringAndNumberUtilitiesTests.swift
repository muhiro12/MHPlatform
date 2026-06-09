import Foundation
import MHPlatformUtilities
import Testing

struct MHStringAndNumberUtilitiesTests {
    @Test
    func decimalStringHelpers() {
        #expect("".isEmptyOrDecimal)
        #expect("123".isEmptyOrDecimal)
        #expect(!"abc".isEmptyOrDecimal)

        #expect("42.5".decimalValue == Decimal(string: "42.5"))
        #expect("abc".decimalValue == .zero)
    }

    @Test
    func normalizedContainsMatchesWidthAndKanaVariants() {
        #expect("ｶﾀｶﾅ".normalizedContains("カタカナ"))
        #expect("カタカナ".normalizedContains("ｶﾀｶﾅ"))
        #expect("ひらがな".normalizedContains("ヒラガナ"))
        #expect("ヒラガナ".normalizedContains("ひらがな"))
        #expect("これはｶﾀｶﾅです".normalizedContains("カタ"))
    }

    @Test
    func numericZeroHelpers() {
        let zeroInteger = 0
        #expect(zeroInteger.isZero)
        #expect(!zeroInteger.isNotZero)

        let integer = 42
        #expect(!integer.isZero)
        #expect(integer.isNotZero)

        let zeroDouble = 0.0
        #expect(zeroDouble.isZero)
        #expect(!zeroDouble.isNotZero)
    }

    @Test
    func decimalSignChecks() {
        let plus = Decimal(10)
        let minus = Decimal(-1)
        let zero = Decimal.zero

        #expect(plus.isPlus)
        #expect(!plus.isMinus)

        #expect(minus.isMinus)
        #expect(!minus.isPlus)

        #expect(!zero.isPlus)
        #expect(!zero.isMinus)
    }
}
