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
        let stepBuilder: StepBuilder = { _ in [] }
        return .init(stepBuilder: stepBuilder)
    }

    private let stepBuilder: StepBuilder

    /// Creates an adapter from a step-building closure.
    @preconcurrency
    public init(
        stepBuilder: @escaping StepBuilder
    ) {
        self.stepBuilder = stepBuilder
    }

    /// Creates an adapter from a step builder with a trailing-closure-friendly
    /// factory.
    ///
    /// This is the preferred semantics-free surface for conditionally
    /// composing ordered follow-up steps from app-owned effect flags.
    @preconcurrency
    public static func build(
        @MHMutationStepListBuilder _ steps: @escaping StepBuilder
    ) -> Self {
        .init(stepBuilder: steps)
    }

    /// Creates an adapter that always returns the same ordered steps.
    public static func fixed(
        _ steps: [MHMutationStep]
    ) -> Self {
        let stepBuilder: StepBuilder = { _ in
            steps
        }
        return .init(stepBuilder: stepBuilder)
    }

    /// Creates an adapter that always returns the same ordered steps built
    /// with `MHMutationStepListBuilder`.
    @preconcurrency
    public static func fixed(
        @MHMutationStepListBuilder _ steps: @escaping @Sendable () -> [MHMutationStep]
    ) -> Self {
        let stepBuilder: StepBuilder = { _ in
            steps()
        }
        return .init(stepBuilder: stepBuilder)
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

    /// Appends fixed post-success steps built with `MHMutationStepListBuilder`
    /// after the steps derived by this adapter.
    @preconcurrency
    public func appending(
        @MHMutationStepListBuilder _ steps: @escaping @Sendable () -> [MHMutationStep]
    ) -> Self {
        appending(.fixed(steps))
    }

    /// Appends another adapter after the steps derived by this adapter.
    public func appending(
        _ other: Self
    ) -> Self {
        let stepBuilder: StepBuilder = { value in
            steps(for: value) + other.steps(for: value)
        }
        return .init(stepBuilder: stepBuilder)
    }

    /// Reuses this adapter for a new value by mapping the new value first.
    @preconcurrency
    public func contramap<NewValue: Sendable>(
        _ transform: @escaping @Sendable (NewValue) -> Value
    ) -> MHMutationAdapter<NewValue> {
        let stepBuilder: MHMutationAdapter<NewValue>.StepBuilder = { newValue in
            steps(for: transform(newValue))
        }
        return .init(stepBuilder: stepBuilder)
    }
}
