import MHRemoteUpdate
import Testing

struct MHRemoteUpdateOperationTests {
    @Test(arguments: [MHRemoteUpdateUnavailableBehavior.allow, .block])
    func validatedNoUpdateAllowsOperation(_ behavior: MHRemoteUpdateUnavailableBehavior) throws {
        try MHRemoteUpdateDecision.notRequired.checkOperationAllowed(whenUnavailable: behavior)
    }

    @Test(arguments: [MHRemoteUpdateUnavailableBehavior.allow, .block])
    func requiredUpdateAlwaysBlocks(_ behavior: MHRemoteUpdateUnavailableBehavior) {
        #expect(throws: MHRemoteUpdateOperationError.updateRequired) {
            try MHRemoteUpdateDecision.updateRequired.checkOperationAllowed(whenUnavailable: behavior)
        }
    }

    @Test
    func unavailablePolicyRequiresTheAppChoice() throws {
        try MHRemoteUpdateDecision.unavailable.checkOperationAllowed(whenUnavailable: .allow)
        #expect(throws: MHRemoteUpdateOperationError.policyUnavailable) {
            try MHRemoteUpdateDecision.unavailable.checkOperationAllowed(whenUnavailable: .block)
        }
    }
}
