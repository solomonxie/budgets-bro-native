import Foundation
import LocalAuthentication
import Observation

enum AppLockMode: String, CaseIterable, Identifiable {
    case off, passcode, biometric
    var id: String { rawValue }
}

/// Off by default; Off · 4-digit passcode · Face ID — see
/// docs/DESIGN.md#app-lock-shipped. Locked asks for proof on cold start and
/// after 60s away; a shorter grace period would challenge every glance.
@Observable
final class AppLockController {
    static let shared = AppLockController()

    private let settings = AppSettingsRepository()
    private let gracePeriodSeconds: TimeInterval = 60
    private var lastBackgroundedAt: Date?

    var isLocked = false

    var mode: AppLockMode {
        get { AppLockMode(rawValue: settings.get("app_lock_mode") ?? "off") ?? .off }
        set { settings.set("app_lock_mode", newValue.rawValue) }
    }

    func appDidLaunch() {
        isLocked = mode != .off
    }

    func appDidEnterBackground() {
        lastBackgroundedAt = Date()
    }

    func appWillEnterForeground() {
        guard mode != .off else { return }
        if let lastBackgroundedAt, Date().timeIntervalSince(lastBackgroundedAt) < gracePeriodSeconds {
            return
        }
        isLocked = true
    }

    func setPasscode(_ passcode: String) {
        Keychain.set(passcode, for: SecretKey.appPasscode)
    }

    var hasPasscode: Bool {
        Keychain.get(SecretKey.appPasscode) != nil
    }

    func verify(passcode: String) -> Bool {
        guard let stored = Keychain.get(SecretKey.appPasscode) else { return false }
        return stored == passcode
    }

    /// `.deviceOwnerAuthentication` falls back to the device passcode when
    /// no face/finger is enrolled or scanning fails — same
    /// BIOMETRY_ANY_OR_DEVICE_PASSCODE guarantee as the original: a face
    /// that won't scan can't lock anyone out of their own phone.
    func unlockWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Budgets Bro") { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    func unlock() {
        isLocked = false
        lastBackgroundedAt = nil
    }
}
