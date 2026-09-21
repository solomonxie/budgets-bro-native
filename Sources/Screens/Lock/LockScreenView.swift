import SwiftUI

/// Presented as a full-screen cover so it sits above every other modal —
/// see docs/DESIGN.md's App lock section.
struct LockScreenView: View {
    @Bindable var controller: AppLockController
    @State private var enteredPasscode = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill").font(.system(size: 40)).foregroundStyle(Theme.accent)
                Text("Budgets Bro Locked").foregroundStyle(.white).font(.title2.bold())

                if controller.mode == .biometric {
                    Button("Unlock with Face ID") { attemptBiometrics() }
                        .buttonStyle(.borderedProminent)
                } else {
                    SecureField("Passcode", text: $enteredPasscode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                    Button("Unlock") { attemptPasscode() }
                        .buttonStyle(.borderedProminent)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.negative).font(.caption)
                }
            }
        }
        .task {
            if controller.mode == .biometric { attemptBiometrics() }
        }
    }

    private func attemptBiometrics() {
        controller.unlockWithBiometrics { success in
            if success {
                controller.unlock()
            } else {
                errorMessage = "Couldn't verify — try again."
            }
        }
    }

    private func attemptPasscode() {
        if controller.verify(passcode: enteredPasscode) {
            controller.unlock()
        } else {
            errorMessage = "Wrong passcode."
        }
        enteredPasscode = ""
    }
}
