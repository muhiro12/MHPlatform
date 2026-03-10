import Foundation

#if os(iOS)
import StoreKit
import UIKit
#endif

struct MHReviewRequestEnvironment: Sendable {
    static let live: Self = {
        #if os(iOS)
        .init {
            MHReviewRequester.requestReview(
                connectedScenes: UIApplication.shared.connectedScenes
            ) { windowScene in
                AppStore.requestReview(in: windowScene)
            }
        }
        #else
        .init {
            .unsupportedPlatform
        }
        #endif
    }()

    let requestReview: @Sendable @MainActor () -> MHReviewRequestOutcome

    init(_ requestReview: @escaping @Sendable @MainActor () -> MHReviewRequestOutcome) {
        self.requestReview = requestReview
    }
}
