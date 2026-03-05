actor MHRouteExecutionSuspensionGate {
    private var isOpen = false
    private var continuations = [CheckedContinuation<Void, Never>]()

    func wait() async {
        guard isOpen == false else {
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        guard isOpen == false else {
            return
        }
        isOpen = true
        continuations.forEach { continuation in
            continuation.resume()
        }
        continuations = []
    }
}
