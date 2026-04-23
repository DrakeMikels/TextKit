import AppKit
import SwiftUI

struct InitialSetupWindowView: View {
    @Bindable var appModel: AppModel

    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to TextKit")
                    .font(.largeTitle.weight(.semibold))

                Text("Choose a local model, download it once, and TextKit will run on-device after setup.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            quickStartCard

            SetupStatusView(
                settingsStore: appModel.settingsStore,
                modelManager: appModel.modelManager,
                setupManager: appModel.setupManager,
                startSetup: appModel.startSetup
            )

            HStack {
                Button(primarySecondaryActionTitle) {
                    onDismiss()
                }
                .disabled(appModel.setupManager.isRunning)

                Spacer()

                if setupIsComplete {
                    Button("Start Using TextKit") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Open Full Settings") {
                        openSettingsWindow()
                    }
                    .buttonStyle(.bordered)
                    .disabled(appModel.setupManager.isRunning)
                }
            }
        }
        .padding(24)
        .frame(width: 620)
    }

    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Setup")
                .font(.headline)

            Text("Start with Qwen2.5 0.5B. TextKit downloads one balanced local file for each model, and you can switch response mode later.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Start Recommended Setup") {
                    startRecommendedSetup()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.setupManager.isRunning || setupIsComplete)

                Text(quickStartCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                }
        }
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var setupIsComplete: Bool {
        if case .ready = appModel.modelManager.runtimeState {
            return true
        }

        return false
    }

    private var primarySecondaryActionTitle: String {
        setupIsComplete ? "Close" : "Set Up Later"
    }

    private var quickStartCaption: String {
        if setupIsComplete {
            return "Setup is complete. You can start using TextKit now."
        }

        return "Downloads from Hugging Face and installs locally on this Mac."
    }

    private func startRecommendedSetup() {
        appModel.settingsStore.localModelOption = .stable
        appModel.setupManager.resetFailure()
        appModel.startSetup()
    }
}
