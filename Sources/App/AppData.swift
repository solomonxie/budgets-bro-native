import Foundation

/// Which store the app is on: the real one, or a separate demo store (Settings > Demo mode).
enum AppData {
    /// Kept in UserDefaults, outside both stores, so turning demo mode off is always reachable.
    static let demoKey = "demo.on"

    static var isDemo: Bool { UserDefaults.standard.bool(forKey: demoKey) }

    static func setDemo(_ on: Bool) {
        guard on != isDemo else { return }
        UserDefaults.standard.set(on, forKey: demoKey)
        Database.shared.reopen()
        if on { DemoSeed.seedIfNeeded() }
        BoardContext.shared.reload()
        // The demo store has no app lock; coming back to real data asks again.
        if !on { AppLockController.shared.appDidLaunch() }
    }
}

enum StoreRegion: String {
    case us, cn
}

/// App Store region this install was built for (`make device STORE=cn`); `us` covers Canada/US.
/// TODO: gate third-party AI providers and S3 endpoints by region.
func storeRegion(_ bundle: Bundle = .main) -> StoreRegion {
    StoreRegion(rawValue: bundle.object(forInfoDictionaryKey: "AppStoreRegion") as? String ?? "") ?? .us
}
