import Foundation
import MHMutationFlow

enum MutationAdapterFixtures {
    actor AttemptState {
        private var value = 0

        func nextAttempt() -> Int {
            value += 1
            return value
        }

        func attempts() -> Int {
            value
        }
    }

    final class InvocationCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.lock()
            value += 1
            lock.unlock()
        }

        func count() -> Int {
            lock.lock()
            let currentValue = value
            lock.unlock()
            return currentValue
        }
    }

    enum IncomesLikeFollowUpHint: Hashable, Sendable {
        case refreshNotificationSchedule
        case reloadWidgets
        case refreshWatchSnapshot
    }

    struct IncomesLikeMutationResult: Sendable {
        let value: String
        let followUpHints: Set<IncomesLikeFollowUpHint>
    }

    struct CookleLikeMutationEffect: OptionSet, Sendable {
        static let dataChanged: Self = .init(rawValue: 1 << 0)
        static let notificationPlanChanged: Self = .init(rawValue: 1 << 1)
        static let reviewPromptEligible: Self = .init(rawValue: 1 << 2)

        let rawValue: Int
    }

    struct CookleLikeMutationOutcome<Value: Sendable>: Sendable {
        let value: Value
        let effects: CookleLikeMutationEffect
    }

    enum MutationTestError: Error {
        case operationFailed
        case sideEffectFailed
    }

    static func incomesLikeSteps(
        for result: IncomesLikeMutationResult
    ) -> [MHMutationStep] {
        var steps = [MHMutationStep]()

        if result.followUpHints.contains(.reloadWidgets) {
            steps.append(
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                }
            )
        }

        if result.followUpHints.contains(.refreshNotificationSchedule) {
            steps.append(
                .init(name: "syncNotifications") {
                    // Intentionally empty.
                }
            )
        }

        if result.followUpHints.contains(.refreshWatchSnapshot) {
            steps.append(
                .init(name: "refreshWatchSnapshot") {
                    // Intentionally empty.
                }
            )
        }

        return steps
    }

    static func cookleLikeSteps(
        for result: CookleLikeMutationOutcome<String>,
        failNotificationSync: Bool,
        cancellationHandle: MHCancellationHandle?
    ) -> [MHMutationStep] {
        var steps = [MHMutationStep]()

        if result.effects.contains(.dataChanged) {
            steps.append(
                .init(name: "reloadWidgets") {
                    cancellationHandle?.cancel()
                }
            )
        }

        if result.effects.contains(.notificationPlanChanged) {
            steps.append(
                .init(name: "syncNotifications") {
                    if failNotificationSync {
                        throw MutationTestError.sideEffectFailed
                    }
                }
            )
        }

        if result.effects.contains(.reviewPromptEligible) {
            steps.append(
                .init(name: "requestReview") {
                    // Intentionally empty.
                }
            )
        }

        return steps
    }
}
