import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    @Bindable var modelManager: ModelManager

    var body: some View {
        Form {
            Section("Model") {
                Picker("Profile", selection: $settingsStore.modelProfile) {
                    ForEach(ModelProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }

                Picker("Quant Preset", selection: $settingsStore.quantPreset) {
                    ForEach(QuantPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(modelManager.defaultModel.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(modelManager.defaultModel.repository)
                        .foregroundStyle(.secondary)
                    Text("Default suggested file: \(modelManager.defaultModel.suggestedFilename)")
                        .foregroundStyle(.secondary)
                    Text(modelManager.runtimeDetail)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text(modelManager.statusSummary)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Refresh Status") {
                        Task {
                            await modelManager.refreshAvailability()
                        }
                    }

                    Spacer()

                    Text(modelManager.setupCommand)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Behavior") {
                Toggle("Watch clipboard automatically", isOn: $settingsStore.autoClipEnabled)

                Picker("Fallback Tool", selection: $settingsStore.defaultFallbackTool) {
                    ForEach(ToolKind.allCases) { tool in
                        Text(tool.title).tag(tool)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Warm Cache")
                        Spacer()
                        Text("\(Int(settingsStore.warmCacheSeconds)) sec")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $settingsStore.warmCacheSeconds, in: 30...90, step: 15)
                }
            }

            Section("Runtime") {
                Text("Local inference now runs through \(modelManager.defaultModel.runtime) in offline mode after the model is cached.")
                Text("Use the setup command above on a fresh machine to install llama.cpp and pre-download the Qwen GGUF.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
