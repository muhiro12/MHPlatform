@testable import RuntimeOnlyConsumer
import Testing

@MainActor
struct RuntimeOnlyConsumerTests {
    @Test
    func lifecycle_starts_runtime_on_initial_appearance() async {
        let bootstrap = RuntimeOnlyConsumer.makeBootstrap()
        let lifecycle = bootstrap.makeLifecycle()

        #expect(bootstrap.runtime.hasStarted == false)

        await lifecycle.handleInitialAppearance()

        #expect(bootstrap.runtime.hasStarted)
    }
}
