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

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
