actor MHRouteExecutionStartedSignal {
    private var hasStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        hasStarted = true
        continuation?.resume()
        continuation = nil
    }

    func waitForStart() async {
        guard hasStarted == false else {
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
