import MHMutationFlow
import Testing

struct MHMutationFlowAdapterCompositionTests {
    @Test
    func appending_steps_preserves_dynamic_then_static_order() async {
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
        let adapter = MHMutationAdapter<MutationAdapterFixtures.IncomesLikeMutationResult>(
            stepBuilder: MutationAdapterFixtures.incomesLikeSteps(for:)
        )
        .appending([
            .init(name: "requestReview") {
                // Intentionally empty.
            }
        ])

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter
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
    func appending_adapter_combines_static_prefix_and_value_steps() async {
        let mutation = MHMutation<MutationAdapterFixtures.CookleLikeMutationOutcome<String>>(
            name: "saveDraft"
        ) {
            .init(
                value: "saved",
                effects: [.notificationPlanChanged]
            )
        }
        let adapter = MHMutationAdapter<MutationAdapterFixtures.CookleLikeMutationOutcome<String>>
            .fixed([
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                }
            ])
            .appending(
                .init { result in
                    MutationAdapterFixtures.cookleLikeSteps(
                        for: result,
                        failNotificationSync: false,
                        cancellationHandle: nil
                    )
                }
            )

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter
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
    func composed_adapter_is_not_invoked_when_operation_fails() async {
        let counter = MutationAdapterFixtures.InvocationCounter()
        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            throw MutationAdapterFixtures.MutationTestError.operationFailed
        }
        let adapter = MHMutationAdapter<String> { _ in
            counter.increment()
            return []
        }
        .appending(
            .init { _ in
                counter.increment()
                return []
            }
        )

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter,
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
            #expect(counter.count() == 0)
            switch failure {
            case .operation:
                break
            case .step:
                Issue.record("Expected operation failure.")
            }
        case .succeeded, .cancelled:
            Issue.record("Expected failure outcome.")
        }
    }

    @Test
    func appended_step_failure_does_not_retry_operation() async {
        let state = MutationAdapterFixtures.AttemptState()
        let mutation = MHMutation<String>(
            name: "saveDraft"
        ) {
            _ = await state.nextAttempt()
            return "saved"
        }
        let adapter = MHMutationAdapter<String>
            .fixed([
                .init(name: "reloadWidgets") {
                    // Intentionally empty.
                }
            ])
            .appending([
                .init(name: "syncNotifications") {
                    throw MutationAdapterFixtures.MutationTestError.sideEffectFailed
                }
            ])

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter,
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
    func composed_adapter_runs_appended_steps_after_retry_success() async {
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
        let adapter = MHMutationAdapter<MutationAdapterFixtures.CookleLikeMutationOutcome<String>> { result in
            MutationAdapterFixtures.cookleLikeSteps(
                for: result,
                failNotificationSync: false,
                cancellationHandle: nil
            )
        }
        .appending([
            .init(name: "requestReview") {
                // Intentionally empty.
            }
        ])

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: adapter,
            retryPolicy: .init(
                maximumAttempts: 3,
                backoff: .immediate
            )
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value.value == "saved")
            #expect(attempts == 2)
            #expect(completedSteps == [
                "syncNotifications",
                "requestReview"
            ])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }
}
