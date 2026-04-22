import SwiftUI

struct SettingsView: View {
    @Bindable var settingsStore: SettingsStore
    @Bindable var modelManager: ModelManager

    @State private var selectedAdvancedModeID = ToolMode.rewriteClean.id
    @State private var previewInput = ToolMode.rewriteClean.sampleInput
    @State private var previewRefineInstruction = ""
    @State private var importExportStatus = ""

    private let promptComposer = PromptComposer()

    private var selectedMode: ToolMode {
        ToolMode.mode(for: selectedAdvancedModeID) ?? .rewriteClean
    }

    private var editableConfiguration: ModePromptConfiguration {
        settingsStore.editablePromptConfiguration(for: selectedMode)
    }

    private var effectiveConfiguration: ModePromptConfiguration {
        settingsStore.promptConfiguration(for: selectedMode)
    }

    private var activeModel: LocalModelDescriptor {
        modelManager.model(for: settingsStore.quantPreset)
    }

    private var previewPrompt: ComposedPrompt {
        promptComposer.preview(
            for: selectedMode,
            configuration: effectiveConfiguration,
            sampleInput: previewInput,
            refineInstruction: previewRefineInstruction
        )
    }

    var body: some View {
        Form {
            modelSection
            behaviorSection
            advancedPromptSection
            runtimeSection
        }
        .padding(20)
        .frame(width: 720, height: 860)
        .onChange(of: selectedAdvancedModeID) { _, _ in
            previewInput = selectedMode.sampleInput
        }
        .onChange(of: settingsStore.quantPreset) { _, quantPreset in
            Task {
                await modelManager.refreshAvailability(for: quantPreset)
            }
        }
    }

    private var modelSection: some View {
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
                Text(activeModel.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(activeModel.repository)
                    .foregroundStyle(.secondary)
                Text("Selected quant file: \(activeModel.suggestedFilename)")
                    .foregroundStyle(.secondary)
                Text(modelManager.runtimeDetail(for: settingsStore.quantPreset))
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
                        await modelManager.refreshAvailability(for: settingsStore.quantPreset)
                    }
                }

                Spacer()

                Text(modelManager.setupCommand(for: settingsStore.quantPreset))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var behaviorSection: some View {
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

                Slider(value: $settingsStore.warmCacheSeconds, in: 15...300, step: 15)
            }
        }
    }

    private var advancedPromptSection: some View {
        Section("Advanced Prompt Profiles") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Picker("Mode", selection: $selectedAdvancedModeID) {
                        ForEach(ToolMode.allCases) { mode in
                            Text("\(mode.tool.title) · \(mode.title)").tag(mode.id)
                        }
                    }

                    Spacer()

                    Toggle("Strict Mode", isOn: $settingsStore.strictModeEnabled)
                        .toggleStyle(.switch)
                }

                Text("The base system prompt is locked. Advanced settings let you tune the additive system instruction, task template, and decode controls for each mode.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Locked Base System Prompt")
                        .font(.subheadline.weight(.semibold))
                    ScrollView {
                        Text(PromptComposer.lockedBaseSystemPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 92)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode-Specific System Instruction")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: systemInstructionBinding)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 88)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Template")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: taskTemplateBinding)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 168)
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(editableConfiguration.temperature, format: .number.precision(.fractionLength(2)))
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: temperatureBinding, in: 0...1, step: 0.05)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(value: maxTokensBinding, in: 32...512, step: 8) {
                            HStack {
                                Text("Max Tokens")
                                Spacer()
                                Text("\(editableConfiguration.maxTokens)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Seed")
                        TextField("Seed", value: seedBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Text("-1 keeps sampling random")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("Reset Mode") {
                        settingsStore.resetConfiguration(for: selectedMode)
                    }

                    Button("Reset All") {
                        settingsStore.resetAllPromptConfigurations()
                    }

                    Button("Apply Strict Defaults") {
                        settingsStore.applyStrictModeDefaults()
                    }

                    Spacer()

                    Button("Import Profile") {
                        runProfileAction("Imported prompt profile.") {
                            try settingsStore.importPromptProfile()
                        }
                    }

                    Button("Export Profile") {
                        runProfileAction("Exported prompt profile.") {
                            try settingsStore.exportPromptProfile()
                        }
                    }
                }

                if !importExportStatus.isEmpty {
                    Text(importExportStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt Preview")
                        .font(.subheadline.weight(.semibold))

                    TextField("Preview refine instruction", text: $previewRefineInstruction)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $previewInput)
                        .font(.body)
                        .frame(height: 90)

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Effective System Prompt")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView {
                                Text(previewPrompt.systemPrompt)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(height: 132)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Effective User Prompt")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView {
                                Text(previewPrompt.userPrompt)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(height: 132)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Strict mode preview is active when the toggle is on. It clamps temperature lower and forces a deterministic seed if none is set.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var runtimeSection: some View {
        Section("Runtime") {
            Text("Local inference runs through \(activeModel.runtime) in offline mode after the selected quant is cached.")
            Text("Users can install the app first, then download the model on first run or from settings. The warm cache slider above controls how long the runtime should stay ready after generation.")
                .foregroundStyle(.secondary)
        }
    }

    private var systemInstructionBinding: Binding<String> {
        Binding(
            get: { settingsStore.editablePromptConfiguration(for: selectedMode).systemInstruction },
            set: { settingsStore.setSystemInstruction($0, for: selectedMode) }
        )
    }

    private var taskTemplateBinding: Binding<String> {
        Binding(
            get: { settingsStore.editablePromptConfiguration(for: selectedMode).taskTemplate },
            set: { settingsStore.setTaskTemplate($0, for: selectedMode) }
        )
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { settingsStore.editablePromptConfiguration(for: selectedMode).temperature },
            set: { settingsStore.setTemperature($0, for: selectedMode) }
        )
    }

    private var maxTokensBinding: Binding<Int> {
        Binding(
            get: { settingsStore.editablePromptConfiguration(for: selectedMode).maxTokens },
            set: { settingsStore.setMaxTokens($0, for: selectedMode) }
        )
    }

    private var seedBinding: Binding<Int> {
        Binding(
            get: { settingsStore.editablePromptConfiguration(for: selectedMode).seed },
            set: { settingsStore.setSeed($0, for: selectedMode) }
        )
    }

    private func runProfileAction(_ successMessage: String, action: () throws -> Void) {
        do {
            try action()
            importExportStatus = successMessage
        } catch {
            importExportStatus = error.localizedDescription
        }
    }
}
