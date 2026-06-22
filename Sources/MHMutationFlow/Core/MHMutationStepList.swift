/// Intermediate result for `MHMutationStepListBuilder` components.
public struct MHMutationStepList: Sendable {
    let steps: [MHMutationStep]

    init(_ steps: [MHMutationStep]) {
        self.steps = steps
    }
}
