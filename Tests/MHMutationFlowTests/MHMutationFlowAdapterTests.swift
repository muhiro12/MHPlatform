import MHMutationFlow
import Testing

struct MHMutationFlowAdapterTests {
    @Test
    func adapter_bridges_incomes_like_hints_into_ordered_steps() async {
        let mutation = MHMutation<MutationAdapterFixtures.IncomesLikeMutationResult>(
            name: "saveDraft"
        ) {
            .init(
                value: "saved",
                followUpHints: [
                    .reloadWidgets,
                    .refreshNotificationSchedule
                ]
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: .init { result in
                MutationAdapterFixtures.incomesLikeSteps(for: result)
            }
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value.value == "saved")
            #expect(attempts == 1)
            #expect(completedSteps == [
                "reloadWidgets",
                "syncNotifications"
            ])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }

    @Test
    func adapter_bridges_cookle_like_effects_into_ordered_steps() async {
        let mutation = MHMutation<MutationAdapterFixtures.CookleLikeMutationOutcome<String>>(
            name: "saveDraft"
        ) {
            .init(
                value: "saved",
                effects: [
                    .dataChanged,
                    .notificationPlanChanged,
                    .reviewPromptEligible
                ]
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: .init { result in
                MutationAdapterFixtures.cookleLikeSteps(
                    for: result,
                    failNotificationSync: false,
                    cancellationHandle: nil
                )
            }
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value.value == "saved")
            #expect(attempts == 1)
            #expect(completedSteps == [
                "reloadWidgets",
                "syncNotifications",
                "requestReview"
            ])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }

    @Test
    func adapter_is_not_invoked_when_operation_fails() async {
        let counter = MutationAdapterFixtures.InvocationCounter()

        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            throw MutationAdapterFixtures.MutationTestError.operationFailed
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: .init { _ in
                counter.increment()
                return []
            },
            retryPolicy: .init(
                maximumAttempts: 2,
                backoff: .immediate
            )
        )

        switch outcome {
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            #expect(attempts == 2)
            #expect(completedSteps.isEmpty)
            #expect(isRecoverable == false)
            switch failure {
            case .operation:
                #expect(counter.count() == 0)
            case .step:
                Issue.record("Expected operation failure.")
            }
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome.")
        }
    }

    @Test
    func adapter_step_failure_does_not_retry_operation() async {
        let state = MutationAdapterFixtures.AttemptState()

        let mutation = MHMutation<MutationAdapterFixtures.CookleLikeMutationOutcome<String>>(
            name: "saveDraft"
        ) {
            _ = await state.nextAttempt()
            return .init(
                value: "saved",
                effects: [
                    .dataChanged,
                    .notificationPlanChanged
                ]
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: .init { result in
                MutationAdapterFixtures.cookleLikeSteps(
                    for: result,
                    failNotificationSync: true,
                    cancellationHandle: nil
                )
            },
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            )
        )

        #expect(await state.attempts() == 1)

        switch outcome {
        case let .failed(failure, attempts, completedSteps, isRecoverable):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
            #expect(isRecoverable == false)
            switch failure {
            case .operation:
                Issue.record("Expected step failure.")
            case let .step(name, errorDescription):
                #expect(name == "syncNotifications")
                #expect(errorDescription.contains("sideEffectFailed"))
            }
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome.")
        }
    }

    @Test
    func adapter_generated_steps_run_after_retry_success() async {
        let state = MutationAdapterFixtures.AttemptState()

        let mutation = MHMutation<MutationAdapterFixtures.CookleLikeMutationOutcome<String>>(
            name: "saveDraft"
        ) {
            let attempt = await state.nextAttempt()
            if attempt == 1 {
                throw MutationAdapterFixtures.MutationTestError.operationFailed
            }

            return .init(
                value: "saved",
                effects: [.notificationPlanChanged]
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: .init { result in
                MutationAdapterFixtures.cookleLikeSteps(
                    for: result,
                    failNotificationSync: false,
                    cancellationHandle: nil
                )
            },
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            )
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value.value == "saved")
            #expect(attempts == 2)
            #expect(completedSteps == ["syncNotifications"])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }

    @Test
    func adapter_generated_steps_support_cancellation_between_steps() async {
        let cancellationHandle = MHCancellationHandle()

        let mutation = MHMutation<MutationAdapterFixtures.CookleLikeMutationOutcome<String>>(
            name: "saveDraft"
        ) {
            .init(
                value: "saved",
                effects: [
                    .dataChanged,
                    .notificationPlanChanged
                ]
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: .init { result in
                MutationAdapterFixtures.cookleLikeSteps(
                    for: result,
                    failNotificationSync: false,
                    cancellationHandle: cancellationHandle
                )
            },
            cancellationHandle: cancellationHandle
        )

        switch outcome {
        case let .cancelled(attempts, completedSteps):
            #expect(attempts == 1)
            #expect(completedSteps == ["reloadWidgets"])
        case .succeeded, .failed:
            Issue.record("Expected cancelled outcome.")
        }
    }
}
