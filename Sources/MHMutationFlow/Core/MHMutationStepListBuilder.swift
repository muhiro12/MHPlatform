/// Result builder for ordered `MHMutationStep` lists used by mutation adapters.
@resultBuilder
public enum MHMutationStepListBuilder {
    /// Lifts a single step into the builder output.
    public static func buildExpression(
        _ expression: MHMutationStep
    ) -> MHMutationStepList {
        .init([expression])
    }

    /// Passes through a prebuilt ordered step list.
    public static func buildExpression(
        _ expression: [MHMutationStep]
    ) -> MHMutationStepList {
        .init(expression)
    }

    /// Flattens builder components into one ordered step list.
    public static func buildBlock(
        _ components: MHMutationStepList...
    ) -> MHMutationStepList {
        .init(components.flatMap(\.steps))
    }

    /// Supports `if` branches that may not emit any steps.
    public static func buildOptional(
        _ component: MHMutationStepList?
    ) -> MHMutationStepList {
        component ?? .init([])
    }

    /// Supports the first branch of `if/else`.
    public static func buildEither(
        first component: MHMutationStepList
    ) -> MHMutationStepList {
        component
    }

    /// Supports the second branch of `if/else`.
    public static func buildEither(
        second component: MHMutationStepList
    ) -> MHMutationStepList {
        component
    }

    /// Supports `for` loops that emit ordered step lists.
    public static func buildArray(
        _ components: [MHMutationStepList]
    ) -> MHMutationStepList {
        .init(components.flatMap(\.steps))
    }

    /// Preserves builder output inside availability checks.
    public static func buildLimitedAvailability(
        _ component: MHMutationStepList
    ) -> MHMutationStepList {
        component
    }

    /// Exposes the final builder output as an ordered step array.
    public static func buildFinalResult(
        _ component: MHMutationStepList
    ) -> [MHMutationStep] {
        component.steps
    }
}
