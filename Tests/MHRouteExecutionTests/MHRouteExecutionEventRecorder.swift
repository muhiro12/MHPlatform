actor MHRouteExecutionEventRecorder {
    private var values = [String]()

    func record(_ value: String) {
        values.append(value)
    }

    func events() -> [String] {
        values
    }
}
