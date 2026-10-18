import Foundation
import MHRemoteUpdate
import Testing

struct MHRemoteUpdatePolicyTests {
    @Test(arguments: [
        "", ".", "1.", ".1", "1..2", "1.2.3.4", "-1", "+1", " 1", "1 ", "1b", "１", "١",
        "1.2-beta", String(repeating: "9", count: 30)
    ])
    func malformedVersionsAreRejected(_ value: String) {
        #expect(MHAppVersion(value) == nil)
    }

    @Test
    func numericComparisonNormalizesMissingComponentsAndLeadingZeros() throws {
        let versions = try ["1", "1.0", "01.00.0"].map { value in
            try #require(MHAppVersion(value))
        }
        #expect(Set(versions).count == 1)
        #expect(try #require(MHAppVersion("1.9")) < #require(MHAppVersion("1.10")))
        #expect(try #require(MHAppVersion("1.2.9")) < #require(MHAppVersion("1.3")))
        #expect(try #require(MHAppVersion("2")) > #require(MHAppVersion("1.99.99")))
        #expect(MHAppVersion("\(Int.max).0.0") != nil)
        #expect(MHAppVersion("\(Int.max)0") == nil)
    }

    @Test(arguments: [
        ("1.2", "1.10", true), ("2.0.0", "2.0.0", false), ("1.02", "1.2", false),
        ("1.2", "1.02", false), ("1", "1.0", true), ("1.0", "1", false), ("1.0.0.1", "1.0.0.2", true)
    ])
    func stringNumericComparisonPreservesExistingIncomesBehavior(
        _ current: String,
        _ minimum: String,
        _ requiresUpdate: Bool
    ) {
        #expect(
            MHAppVersionComparison.numericStringsRequireUpdate(currentVersion: current, minimumVersion: minimum)
                == requiresUpdate
        )
    }

    @Test(arguments: [-1.0, 0.0, 101.0, .infinity, .nan])
    func invalidActivationDurationsAreRejected(_ duration: Double) {
        #expect(MHUpdateActivationWindow(
            activatedAt: date(0), expiresAt: date(duration), maximumDuration: 100
        ) == nil)
    }

    @Test(arguments: [-1.0, 0.0, .infinity, .nan])
    func invalidMaximumDurationsAreRejected(_ maximum: Double) {
        #expect(MHUpdateActivationWindow(
            activatedAt: date(0), expiresAt: date(100), maximumDuration: maximum
        ) == nil)
    }

    @Test
    func activationWindowAcceptsMaximumAndInclusiveEndpoints() throws {
        let window = try #require(MHUpdateActivationWindow(
            activatedAt: date(0), expiresAt: date(100), maximumDuration: 100
        ))
        #expect(window.contains(date(0)))
        #expect(window.contains(date(100)))
        #expect(window.contains(date(-1)) == false)
        #expect(window.contains(date(101)) == false)
        #expect(MHUpdateActivationWindow(
            activatedAt: date(.infinity), expiresAt: date(.infinity), maximumDuration: 100
        ) == nil)
    }

    @Test
    func boundedPolicyPreservesCookleSafeguards() throws {
        let window = try #require(MHUpdateActivationWindow(
            activatedAt: date(0), expiresAt: date(100), maximumDuration: 100
        ))
        let policy = MHRemoteUpdatePolicy(
            minimumVersion: try #require(MHAppVersion("3.9")),
            activationWindow: window,
            requiresPublicVersion: true
        )
        let older = try #require(MHAppVersion("3.8"))
        let minimum = try #require(MHAppVersion("3.9"))
        let newer = try #require(MHAppVersion("4"))
        #expect(policy.evaluate(currentVersion: older, now: date(0), publicVersion: minimum) == .updateRequired)
        #expect(policy.evaluate(currentVersion: older, now: date(100), publicVersion: newer) == .updateRequired)
        #expect(policy.evaluate(currentVersion: minimum, now: date(10), publicVersion: newer) == .notRequired)
        #expect(policy.evaluate(currentVersion: newer, now: date(10), publicVersion: newer) == .notRequired)
        #expect(policy.evaluate(currentVersion: older, now: date(10), publicVersion: older) == .unavailable)
        #expect(policy.evaluate(currentVersion: older, now: date(10)) == .unavailable)
        #expect(policy.evaluate(currentVersion: older, now: date(-1)) == .notRequired)
        #expect(policy.evaluate(currentVersion: older, now: date(101)) == .notRequired)
        #expect(policy.evaluate(currentVersion: older, now: date(.nan), publicVersion: newer) == .unavailable)
    }

    @Test
    func unrestrictedPolicyNeedsNoPublicVersion() throws {
        let policy = MHRemoteUpdatePolicy(
            minimumVersion: try #require(MHAppVersion("2")),
            activationWindow: nil,
            requiresPublicVersion: false
        )
        #expect(policy.evaluate(currentVersion: try #require(MHAppVersion("1")), now: date(0)) == .updateRequired)
        #expect(policy.evaluate(currentVersion: try #require(MHAppVersion("2")), now: date(0)) == .notRequired)
    }

    private func date(_ seconds: Double) -> Date {
        .init(timeIntervalSinceReferenceDate: seconds)
    }
}
