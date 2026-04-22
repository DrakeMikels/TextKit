import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if appModel.showsSetupFlow {
                setupContent
            } else {
                mainContent
            }
        }
        .padding(16)
        .frame(width: 480)
        .onChange(of: appModel.inputText) { _, _ in
            appModel.scheduleRegeneration()
        }
        .onChange(of: appModel.settingsStore.generationSettingsRevision) { _, _ in
            appModel.handleGenerationSettingsChange()
        }
        .onChange(of: appModel.settingsStore.runtimeSelectionRevision) { _, _ in
            appModel.handleRuntimeSelectionChange()
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ToolTabBar(selectedTool: appModel.selectedTool, onSelect: appModel.selectTool)

            GroupBox("Input") {
                TextEditor(text: $appModel.inputText)
                    .font(.body)
                    .frame(height: TextSizing.editorHeight(
                        for: appModel.inputText,
                        minHeight: 110,
                        maxHeight: 260
                    ))
                    .scrollContentBackground(.hidden)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Refine")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    TextField("Refine the current result", text: $appModel.refineDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            appModel.submitRefine()
                        }

                    Button {
                        appModel.submitRefine()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(appModel.canSubmitRefine ? Color.accentColor : Color.secondary.opacity(0.18))
                            .foregroundStyle(appModel.canSubmitRefine ? Color.white : Color.secondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!appModel.canSubmitRefine)
                    .help("Apply refine instruction")
                }

                Text(appModel.hasPendingRefineChanges ? "Press Return or click send to apply the refine instruction." : "Refine applies to the current clipboard text only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Mode")
                    .font(.subheadline.weight(.semibold))
                ModePillRow(
                    modes: appModel.availableModes,
                    selectedMode: appModel.selectedMode,
                    onSelect: appModel.selectMode
                )
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        Text(appModel.outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: TextSizing.editorHeight(
                        for: appModel.outputText,
                        minHeight: 120,
                        maxHeight: 300
                    ))

                    HStack {
                        Button("Copy Result") {
                            appModel.copyOutputToClipboard()
                        }
                        .keyboardShortcut("c", modifiers: [.command, .shift])

                        Spacer()

                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                }
            }
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                SetupStatusView(
                    setupManager: appModel.setupManager,
                    runtimeState: appModel.modelManager.runtimeState,
                    model: appModel.modelManager.model(for: appModel.settingsStore.quantPreset),
                    startSetup: appModel.startSetup
                )
            } label: {
                Label("Set Up TextKit", systemImage: "arrow.down.circle")
                    .font(.headline)
            }

            if !appModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                GroupBox("Copied Text") {
                    ScrollView {
                        Text(appModel.inputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: TextSizing.editorHeight(
                        for: appModel.inputText,
                        minHeight: 110,
                        maxHeight: 220
                    ))
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TextKit")
                    .font(.title2.weight(.semibold))

                Text(appModel.showsSetupFlow && appModel.setupManager.isRunning ? appModel.setupManager.stepTitle : appModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(appModel.modelSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("Open settings")
        }
    }
}
