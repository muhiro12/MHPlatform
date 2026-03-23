@testable import SplitRuntimeConsumer
import Testing

@MainActor
struct SplitRuntimeConsumerTests {
    @Test
    func lifecycle_starts_split_runtime_on_initial_appearance() async {
        let bootstrap = SplitRuntimeConsumer.makeBootstrap()
        let lifecycle = bootstrap.makeLifecycle()

        #expect(bootstrap.runtime.hasStarted == false)

        await lifecycle.handleInitialAppearance()

        #expect(bootstrap.runtime.hasStarted)
    }
}
