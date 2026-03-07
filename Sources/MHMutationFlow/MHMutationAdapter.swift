/// App-facing bridge that derives ordered post-success steps from a successful mutation value.
///
/// Use this when the mutation result already carries app-owned follow-up metadata such as
/// hints or effects. The adapter only maps that success value into `MHMutationStep`s; it does
/// not define a shared outcome schema and it does not perform side effects by itself.
@preconcurrency
public struct MHMutationAdapter<Value: Sendable>: Sendable {
    /// Closure that maps a successful mutation value into ordered post-success steps.
    public typealias StepBuilder = @Sendable (Value) -> [MHMutationStep]

    /// Adapter that derives no post-success steps.
    public static var none: Self { // swiftlint:disable:this discouraged_none_name
        .init { _ in [] }
    }

    private let stepBuilder: StepBuilder

    /// Creates an adapter from a step-building closure.
    @preconcurrency
    public init(
        stepBuilder: @escaping StepBuilder
    ) {
        self.stepBuilder = stepBuilder
    }

    /// Creates an adapter that always returns the same ordered steps.
    public static func fixed(
        _ steps: [MHMutationStep]
    ) -> Self {
        .init { _ in
            steps
        }
    }

    /// Derives ordered post-success steps for a successful mutation value.
    public func steps(
        for value: Value
    ) -> [MHMutationStep] {
        stepBuilder(value)
    }

    /// Appends fixed post-success steps after the steps derived by this adapter.
    public func appending(
        _ steps: [MHMutationStep]
    ) -> Self {
        appending(.fixed(steps))
    }

    /// Appends another adapter after the steps derived by this adapter.
    public func appending(
        _ other: Self
    ) -> Self {
        .init { value in
            steps(for: value) + other.steps(for: value)
        }
    }
}
