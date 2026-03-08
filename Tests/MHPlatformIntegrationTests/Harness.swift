import MHAppRuntime
import MHDeepLinking
import MHLogging
import MHPlatformTesting

struct Harness {
    let runtime: MHAppRuntime
    let lifecycle: MHAppRuntimeLifecycle
    let traceRecorder: LockedTraceRecorder
    let sinkRecorder: MHLogSinkRecorder
    let logStore: MHLogStore
    let notificationDestination: MHDeepLinkURLRecorder
    let intentSource: MHDeepLinkURLRecorder
}
