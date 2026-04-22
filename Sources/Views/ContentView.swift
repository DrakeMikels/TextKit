import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ToolTabBar(selectedTool: appModel.selectedTool, onSelect: appModel.selectTool)

            GroupBox("Input") {
                TextEditor(text: $appModel.inputText)
                    .font(.body)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Refine")
                    .font(.subheadline.weight(.semibold))
                TextField("Optional instruction for the current tool", text: $appModel.refineInstruction)
                    .textFieldStyle(.roundedBorder)
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
                    .frame(minHeight: 120)

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
        .padding(16)
        .frame(width: 480)
        .onChange(of: appModel.inputText) { _, _ in
            appModel.regenerate()
        }
        .onChange(of: appModel.refineInstruction) { _, _ in
            appModel.regenerate()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TextKit")
                    .font(.title2.weight(.semibold))

                Text(appModel.statusText)
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
