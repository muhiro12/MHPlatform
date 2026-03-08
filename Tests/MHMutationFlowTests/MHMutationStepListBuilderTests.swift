import MHMutationFlow
import Testing

struct MHMutationStepListBuilderTests {
    private struct StepConfiguration: Sendable {
        let shouldReloadWidgets: Bool
        let additionalStepNames: [String]
        let shouldRequestReview: Bool
        let fixedSteps: [MHMutationStep]
    }

    @Test
    func adapter_builder_initializer_builds_conditional_steps_in_order() {
        let adapter = MHMutationAdapter<StepConfiguration>.build { configuration in
            if configuration.shouldReloadWidgets {
                MHMutationStep.sync(name: "reloadWidgets") {
                    // Intentionally empty.
                }
            }

            for stepName in configuration.additionalStepNames {
                MHMutationStep.sync(name: stepName) {
                    // Intentionally empty.
                }
            }

            if configuration.shouldRequestReview {
                MHMutationStep.sync(name: "requestReview") {
                    // Intentionally empty.
                }
            }
        }

        let steps = adapter.steps(
            for: .init(
                shouldReloadWidgets: true,
                additionalStepNames: [
                    "syncNotifications",
                    "refreshWatchSnapshot"
                ],
                shouldRequestReview: true,
                fixedSteps: []
            )
        )

        #expect(steps.map(\.name) == [
            "reloadWidgets",
            "syncNotifications",
            "refreshWatchSnapshot",
            "requestReview"
        ])
    }

    @Test
    func adapter_builder_initializer_accepts_prebuilt_step_arrays_and_empty_branches() {
        let adapter = MHMutationAdapter<StepConfiguration>.build { configuration in
            if configuration.shouldReloadWidgets {
                configuration.fixedSteps
            }

            if configuration.shouldRequestReview == false {
                // Intentionally empty.
            }
        }

        let steps = adapter.steps(
            for: .init(
                shouldReloadWidgets: false,
                additionalStepNames: [],
                shouldRequestReview: false,
                fixedSteps: [
                    .sync(name: "reloadWidgets") {
                        // Intentionally empty.
                    }
                ]
            )
        )

        #expect(steps.isEmpty)
    }

    @Test
    func fixed_builder_returns_static_steps_in_order() {
        let adapter = MHMutationAdapter<String>.fixed {
            MHMutationStep.sync(name: "reloadWidgets") {
                // Intentionally empty.
            }

            for stepName in [
                "syncNotifications",
                "requestReview"
            ] {
                MHMutationStep.sync(name: stepName) {
                    // Intentionally empty.
                }
            }
        }

        #expect(adapter.steps(for: "saved").map(\.name) == [
            "reloadWidgets",
            "syncNotifications",
            "requestReview"
        ])
    }

    @Test
    func appending_builder_adds_fixed_steps_after_dynamic_steps() {
        let adapter = MHMutationAdapter<StepConfiguration>.build { configuration in
            if configuration.shouldReloadWidgets {
                MHMutationStep.sync(name: "reloadWidgets") {
                    // Intentionally empty.
                }
            }
        }
        .appending {
            MHMutationStep.sync(name: "requestReview") {
                // Intentionally empty.
            }
        }

        let steps = adapter.steps(
            for: .init(
                shouldReloadWidgets: true,
                additionalStepNames: [],
                shouldRequestReview: false,
                fixedSteps: []
            )
        )

        #expect(steps.map(\.name) == [
            "reloadWidgets",
            "requestReview"
        ])
    }
}
