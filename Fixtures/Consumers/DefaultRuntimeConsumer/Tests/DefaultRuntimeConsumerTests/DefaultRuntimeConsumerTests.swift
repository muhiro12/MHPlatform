@testable import DefaultRuntimeConsumer
import Testing

@MainActor
struct DefaultRuntimeConsumerTests {
    @Test
    func lifecycle_starts_default_runtime_on_initial_appearance() async {
        let bootstrap = DefaultRuntimeConsumer.makeBootstrap()
        let lifecycle = bootstrap.makeLifecycle()

        #expect(bootstrap.runtime.hasStarted == false)

        await lifecycle.handleInitialAppearance()

        #expect(bootstrap.runtime.hasStarted)
    }
}
