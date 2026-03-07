import MHMutationFlow
import Testing

struct MHMutationFlowConvenienceTests {
    @MainActor
    private final class MainActorRecorder {
        var values = [String]()
    }

    private struct WrappedMutationResult: Sendable {
        let outcome: WrappedMutationOutcome
    }

    private struct WrappedMutationOutcome: Sendable {
        let reloadWidgets: Bool
        let syncNotifications: Bool
    }

    @Test
    func contramap_reuses_steps_for_wrapped_success_values() async {
        let outcomeAdapter = MHMutationAdapter<WrappedMutationOutcome> { outcome in
            var steps = [MHMutationStep]()

            if outcome.reloadWidgets {
                steps.append(
                    .sync(name: "reloadWidgets") {
                        // Intentionally empty.
                    }
                )
            }

            if outcome.syncNotifications {
                steps.append(
                    .sync(name: "syncNotifications") {
                        // Intentionally empty.
                    }
                )
            }

            return steps
        }

        let mutation = MHMutation.sync(
            name: "saveWrappedValue"
        ) {
            WrappedMutationResult(
                outcome: .init(
                    reloadWidgets: true,
                    syncNotifications: true
                )
            )
        }

        let outcome = await MHMutationRunner.run(
            mutation: mutation,
            adapter: outcomeAdapter.contramap(\.outcome)
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value.outcome.reloadWidgets)
            #expect(value.outcome.syncNotifications)
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
    func sync_builders_wrap_mutations_and_steps() async {
        let outcome = await MHMutationRunner.run(
            mutation: .sync(name: "saveSyncValue") {
                "saved"
            },
            afterSuccess: [
                .sync(name: "recordValue") {
                    // Intentionally empty.
                }
            ]
        )

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 1)
            #expect(completedSteps == ["recordValue"])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }

    @Test
    func main_actor_builders_run_on_main_actor() async {
        let recorder = await MainActor.run {
            MainActorRecorder()
        }

        let outcome = await MHMutationRunner.run(
            mutation: .mainActor(name: "saveMainActorValue") {
                recorder.values.append("mutation")
                return "saved"
            },
            afterSuccess: [
                .mainActor(name: "recordStep") {
                    recorder.values.append("step")
                }
            ]
        )

        let recordedValues = await MainActor.run {
            recorder.values
        }

        switch outcome {
        case let .succeeded(value, attempts, completedSteps):
            #expect(value == "saved")
            #expect(attempts == 1)
            #expect(completedSteps == ["recordStep"])
            #expect(recordedValues == ["mutation", "step"])
        case .failed, .cancelled:
            Issue.record("Expected success outcome.")
        }
    }
}
