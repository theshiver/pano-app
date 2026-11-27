import AppKit
import PanoUI
import StoreKit

@MainActor
enum ReviewPrompt {
    static func recordCopyAndPromptIfEligible(prefs: Preferences) {
        prefs.totalPastes += 1
        #if !DIRECT_DISTRIBUTION
            let version = Preferences.marketingVersion
            guard prefs.lastReviewPromptVersion != version else { return }
            guard prefs.totalPastes >= 15, prefs.usedPowerFeature else { return }
            let days = Date().timeIntervalSince(prefs.firstLaunchDate) / 86_400
            guard days >= 5 else { return }
            prefs.lastReviewPromptVersion = version
            SKStoreReviewController.requestReview()
        #endif
    }
}
