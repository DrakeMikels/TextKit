import SwiftUI

struct SettingsView: View {
    private enum SettingsPane: String, CaseIterable, Identifiable {
        case general
        case prompts
        case preview

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                "General"
            case .prompts:
                "Prompts"
            case .preview:
                "Preview"
            }
        }

        var systemImage: String {
            switch self {
            case .general:
                "slider.horizontal.3"
            case .prompts:
                "text.quote"
            case .preview:
                "doc.text.magnifyingglass"
            }
        }
    }

    @Bindable var settingsStore: SettingsStore
    @Bindable var modelManager: ModelManager

    @State private var selectedPane: SettingsPane = .general
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
        TabView(selection: $selectedPane) {
            generalPane
                .tabItem {
                    Label(SettingsPane.general.title, systemImage: SettingsPane.general.systemImage)
                }
                .tag(SettingsPane.general)

            promptProfilesPane
                .tabItem {
                    Label(SettingsPane.prompts.title, systemImage: SettingsPane.prompts.systemImage)
                }
                .tag(SettingsPane.prompts)

            previewPane
                .tabItem {
                    Label(SettingsPane.preview.title, systemImage: SettingsPane.preview.systemImage)
                }
                .tag(SettingsPane.preview)
        }
        .padding(20)
        .frame(minWidth: 760, idealWidth: 760, minHeight: 720, idealHeight: 720)
        .onChange(of: selectedAdvancedModeID) { _, _ in
            previewInput = selectedMode.sampleInput
        }
        .onChange(of: settingsStore.quantPreset) { _, quantPreset in
            Task {
                await modelManager.refreshAvailability(for: quantPreset)
            }
        }
    }

    private var generalPane: some View {
        settingsScrollView {
            settingsCard("Model", systemImage: "cube.box") {
                VStack(alignment: .leading, spacing: 14) {
                    controlBlock(title: "Profile") {
                        Picker("Profile", selection: $settingsStore.modelProfile) {
                            ForEach(ModelProfile.allCases) { profile in
                                Text(profile.title).tag(profile)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)
                    }

                    controlBlock(title: "Quant Preset") {
                        Picker("Quant Preset", selection: $settingsStore.quantPreset) {
                            ForEach(QuantPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)
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
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Text("Status")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(modelManager.statusSummary)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Button("Refresh Status") {
                            Task {
                                await modelManager.refreshAvailability(for: settingsStore.quantPreset)
                            }
                        }

                        Text(modelManager.setupCommand(for: settingsStore.quantPreset))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingsCard("Behavior", systemImage: "switch.2") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Watch clipboard automatically", isOn: $settingsStore.autoClipEnabled)

                    controlBlock(title: "Fallback Tool") {
                        Picker("Fallback Tool", selection: $settingsStore.defaultFallbackTool) {
                            ForEach(ToolKind.allCases) { tool in
                                Text(tool.title).tag(tool)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Warm Cache")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(settingsStore.warmCacheSeconds)) sec")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $settingsStore.warmCacheSeconds, in: 15...300, step: 15)

                        Text("Controls how long the local runtime should stay ready after the last generation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingsCard("Runtime", systemImage: "cpu") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local inference runs through \(activeModel.runtime) in offline mode after the selected quant is cached.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Users can install the app first, then download the model on first run or from settings. The warm cache control above is already wired into preferences and will back a persistent runtime lifecycle later.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var promptProfilesPane: some View {
        settingsScrollView {
            settingsCard("Mode Configuration", systemImage: "slider.horizontal.below.rectangle") {
                VStack(alignment: .leading, spacing: 14) {
                    modeSelectionHeader

                    Text("The base system prompt stays locked. This pane edits the additive system instruction, task template, and decode controls for the selected mode.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsCard("Locked Base System Prompt", systemImage: "lock") {
                readOnlyPromptBlock(PromptComposer.lockedBaseSystemPrompt, height: 108)
            }

            settingsCard("Mode-Specific System Instruction", systemImage: "text.alignleft") {
                TextEditor(text: systemInstructionBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
            }

            settingsCard("Task Template", systemImage: "doc.plaintext") {
                TextEditor(text: taskTemplateBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
            }

            settingsCard("Generation Controls", systemImage: "dial.medium") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(editableConfiguration.temperature, format: .number.precision(.fractionLength(2)))
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: temperatureBinding, in: 0...1, step: 0.05)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            maxTokensControl
                            seedControl
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            maxTokensControl
                            seedControl
                        }
                    }
                }
            }

            settingsCard("Profile Actions", systemImage: "square.and.arrow.down.on.square") {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Button("Reset Mode") {
                                settingsStore.resetConfiguration(for: selectedMode)
                            }

                            Button("Reset All") {
                                settingsStore.resetAllPromptConfigurations()
                            }

                            Button("Apply Strict Defaults") {
                                settingsStore.applyStrictModeDefaults()
                            }

                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Button("Reset Mode") {
                                settingsStore.resetConfiguration(for: selectedMode)
                            }

                            Button("Reset All") {
                                settingsStore.resetAllPromptConfigurations()
                            }

                            Button("Apply Strict Defaults") {
                                settingsStore.applyStrictModeDefaults()
                            }
                        }
                    }

                    Divider()

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
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

                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 10) {
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
                    }

                    if !importExportStatus.isEmpty {
                        Text(importExportStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var previewPane: some View {
        settingsScrollView {
            settingsCard("Prompt Preview", systemImage: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 14) {
                    modeSelectionHeader

                    TextField("Preview refine instruction", text: $previewRefineInstruction)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $previewInput)
                        .font(.body)
                        .frame(minHeight: 120)

                    Text("Use this pane to see the exact prompt shape the app sends for the selected mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsCard("Effective System Prompt", systemImage: "lock.doc") {
                readOnlyPromptBlock(previewPrompt.systemPrompt, height: 180)
            }

            settingsCard("Effective User Prompt", systemImage: "text.badge.plus") {
                readOnlyPromptBlock(previewPrompt.userPrompt, height: 220)
            }

            Text("Strict mode preview is active when the toggle is on. It clamps temperature lower and forces a deterministic seed if none is set.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private var modeSelectionHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                modePickerControl
                Spacer(minLength: 0)
                strictModeToggle
            }

            VStack(alignment: .leading, spacing: 12) {
                modePickerControl
                strictModeToggle
            }
        }
    }

    private var modePickerControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Mode", selection: $selectedAdvancedModeID) {
                ForEach(ToolMode.allCases) { mode in
                    Text("\(mode.tool.title) · \(mode.title)").tag(mode.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 280, alignment: .leading)
        }
    }

    private var strictModeToggle: some View {
        Toggle("Strict Mode", isOn: $settingsStore.strictModeEnabled)
            .toggleStyle(.switch)
    }

    private var maxTokensControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Max Tokens")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(editableConfiguration.maxTokens)")
                    .foregroundStyle(.secondary)
            }

            Stepper(value: maxTokensBinding, in: 32...512, step: 8) {
                Text("Adjust output budget")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var seedControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Seed", value: seedBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180, alignment: .leading)

            Text("-1 keeps sampling random")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsScrollView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 6)
        }
        .scrollIndicators(.visible)
    }

    private func settingsCard<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
    }

    private func controlBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func readOnlyPromptBlock(_ text: String, height: CGFloat) -> some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: height)
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
