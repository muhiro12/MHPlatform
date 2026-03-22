@testable import OptionalShellConsumer
import Testing

@MainActor
struct OptionalShellConsumerTests {
    @Test
    func workflow_surface_runs_without_extra_adapters() async throws {
        OptionalShellConsumer.exerciseRuntimeTaskAPI()

        let step = OptionalShellConsumer.makeMutationStep()
        #expect(step.name == "requestReview")

        let value = try await OptionalShellConsumer.runWorkflow()

        #expect(value == 1)
    }
}
