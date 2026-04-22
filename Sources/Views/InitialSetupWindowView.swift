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
                Button("Set Up Later") {
                    onDismiss()
                }

                Spacer()

                Button("Open Full Settings") {
                    openSettingsWindow()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 620)
        .onChange(of: appModel.modelManager.runtimeState) { _, runtimeState in
            guard !appModel.setupManager.isRunning else { return }

            if case .ready = runtimeState {
                onDismiss()
            }
        }
    }

    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Setup")
                .font(.headline)

            Text("Start with Qwen2.5 0.5B on the Balanced size. This is the fastest and most stable first setup for most Macs.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Start Recommended Setup") {
                    startRecommendedSetup()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.setupManager.isRunning)

                Text("Or choose a different model below.")
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

    private func startRecommendedSetup() {
        appModel.settingsStore.localModelOption = .stable
        appModel.settingsStore.quantPreset = .balanced
        appModel.setupManager.resetFailure()
        appModel.startSetup()
    }
}
