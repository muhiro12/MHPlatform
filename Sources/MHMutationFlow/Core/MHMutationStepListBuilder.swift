/// Result builder for ordered `MHMutationStep` lists used by mutation adapters.
@resultBuilder
public enum MHMutationStepListBuilder {
    /// Lifts a single step into the builder output.
    public static func buildExpression(
        _ expression: MHMutationStep
    ) -> [MHMutationStep] {
        [expression]
    }

    /// Passes through a prebuilt ordered step list.
    public static func buildExpression(
        _ expression: [MHMutationStep]
    ) -> [MHMutationStep] {
        expression
    }

    /// Flattens builder components into one ordered step list.
    public static func buildBlock(
        _ components: [MHMutationStep]...
    ) -> [MHMutationStep] {
        components.flatMap(\.self)
    }

    // swiftlint:disable discouraged_optional_collection
    /// Supports `if` branches that may not emit any steps.
    public static func buildOptional(
        _ component: [MHMutationStep]?
    ) -> [MHMutationStep] {
        component ?? []
    }
    // swiftlint:enable discouraged_optional_collection

    /// Supports the first branch of `if/else`.
    public static func buildEither(
        first component: [MHMutationStep]
    ) -> [MHMutationStep] {
        component
    }

    /// Supports the second branch of `if/else`.
    public static func buildEither(
        second component: [MHMutationStep]
    ) -> [MHMutationStep] {
        component
    }

    /// Supports `for` loops that emit ordered step lists.
    public static func buildArray(
        _ components: [[MHMutationStep]]
    ) -> [MHMutationStep] {
        components.flatMap(\.self)
    }

    /// Preserves builder output inside availability checks.
    public static func buildLimitedAvailability(
        _ component: [MHMutationStep]
    ) -> [MHMutationStep] {
        component
    }
}
