import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ToolTabBar(selectedTool: appModel.selectedTool, onSelect: appModel.selectTool)
            if appModel.showsSetupFlow && appModel.selectedTool.usesModel {
                setupContent
            } else {
                mainContent
            }
        }
        .padding(16)
        .frame(width: 480)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.022), lineWidth: 0.6)
                }
        }
        .onChange(of: appModel.inputText) { _, _ in
            appModel.handleInputChange()
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

            if appModel.selectedTool == .reduce {
                reductionSubmitSection
            } else {
                refineSection
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
                    if let reductionSummaryText = appModel.reductionSummaryText {
                        reductionSummaryRow(reductionSummaryText)
                    }

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
                        Button(appModel.selectedTool == .reduce ? "Copy Reduced Text" : "Copy Result") {
                            appModel.copyOutputToClipboard()
                        }
                        .keyboardShortcut("c", modifiers: [.command, .shift])

                        Spacer()

                        Button("Quit") {
                            appModel.quitApplication()
                        }
                    }
                }
            }
        }
    }

    private var refineSection: some View {
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
    }

    private var reductionSubmitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run Reduce")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                Text("Shrink the current text only when you choose to run it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    appModel.submitReduction()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(appModel.canSubmitReduction ? Color.accentColor : Color.secondary.opacity(0.18))
                        .foregroundStyle(appModel.canSubmitReduction ? Color.white : Color.secondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!appModel.canSubmitReduction)
                .help("Run Reduce on the current text")
            }

            Text(appModel.hasPendingReductionChanges ? "Click send to reduce the current text." : "Best for logs, traces, and long repetitive text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func reductionSummaryRow(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                SetupStatusView(
                    settingsStore: appModel.settingsStore,
                    modelManager: appModel.modelManager,
                    setupManager: appModel.setupManager,
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
