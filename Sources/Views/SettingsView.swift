import SwiftUI

struct SettingsView: View {
    typealias DebugEvaluationAction = (String, String, ToolMode) async throws -> DebugEvaluationResult

    private enum SettingsPane: String, CaseIterable, Identifiable {
        case general
        case prompts
        case preview

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                "Basics"
            case .prompts:
                "Customize"
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
    @Bindable var setupManager: SetupManager
    let startSetup: () -> Void
    let runDebugEvaluation: DebugEvaluationAction

    @State private var selectedPane: SettingsPane = .general
    @State private var selectedAdvancedModeID = ToolMode.rewriteClean.id
    @State private var previewInput = ToolMode.rewriteClean.sampleInput
    @State private var previewRefineInstruction = ""
    @State private var importExportStatus = ""
    @State private var debugRawOutput = ""
    @State private var debugFinalOutput = ""
    @State private var debugStatus = "Run a live check with the current model and style."
    @State private var debugIsRunning = false

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
        modelManager.model(
            for: settingsStore.localModelOption,
            quantPreset: settingsStore.quantPreset
        )
    }

    private var previewPrompt: ComposedPrompt {
        promptComposer.preview(
            for: selectedMode,
            configuration: effectiveConfiguration,
            sampleInput: previewInput,
            refineInstruction: previewRefineInstruction
        )
    }

    private var canRunDebugEvaluation: Bool {
        !previewInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !setupManager.isRunning
            && modelManager.runtimeState != .missingRuntime
            && modelManager.runtimeState != .missingModel
    }

    private var hasDebugResult: Bool {
        !debugRawOutput.isEmpty || !debugFinalOutput.isEmpty
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
            invalidateDebugResult()
        }
        .onChange(of: previewInput) { _, _ in invalidateDebugResult() }
        .onChange(of: previewRefineInstruction) { _, _ in invalidateDebugResult() }
        .onChange(of: settingsStore.generationSettingsRevision) { _, _ in invalidateDebugResult() }
        .onChange(of: settingsStore.runtimeSelectionRevision) { _, _ in invalidateDebugResult() }
        .onChange(of: settingsStore.quantPreset) { _, quantPreset in
            Task {
                await modelManager.refreshAvailability(
                    for: settingsStore.localModelOption,
                    quantPreset: quantPreset
                )
            }
        }
        .onChange(of: settingsStore.localModelOption) { _, modelOption in
            Task {
                await modelManager.refreshAvailability(
                    for: modelOption,
                    quantPreset: settingsStore.quantPreset
                )
            }
        }
    }

    private var generalPane: some View {
        settingsScrollView {
            settingsCard("Model", systemImage: "cube.box") {
                VStack(alignment: .leading, spacing: 14) {
                    controlBlock(title: "AI Model") {
                        Picker("AI Model", selection: $settingsStore.localModelOption) {
                            ForEach(LocalModelOption.allCases) { modelOption in
                                Text(modelOption.title).tag(modelOption)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 280, alignment: .leading)
                        .disabled(setupManager.isRunning)

                        Text(settingsStore.localModelOption.helperDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    controlBlock(title: "Detail Level") {
                        Picker("Detail Level", selection: $settingsStore.modelProfile) {
                            ForEach(ModelProfile.allCases) { profile in
                                Text(profile.title).tag(profile)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)
                        .disabled(setupManager.isRunning)

                        Text("Fast keeps answers short. Quality allows more detail.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    controlBlock(title: "Model Size") {
                        Picker("Model Size", selection: $settingsStore.quantPreset) {
                            ForEach(QuantPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)
                        .disabled(setupManager.isRunning)

                        Text("This changes the download size and speed for the selected AI model.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(activeModel.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("Model source: \(activeModel.repository)")
                            .foregroundStyle(.secondary)
                        Text("Installed file: \(activeModel.suggestedFilename)")
                            .foregroundStyle(.secondary)
                        Text(modelManager.runtimeDetail(
                            for: settingsStore.localModelOption,
                            quantPreset: settingsStore.quantPreset
                        ))
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
                        Button("Check Again") {
                            Task {
                                await modelManager.refreshAvailability(
                                    for: settingsStore.localModelOption,
                                    quantPreset: settingsStore.quantPreset
                                )
                            }
                        }
                        .disabled(setupManager.isRunning)

                        Text("Install command")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(modelManager.setupCommand(
                            for: settingsStore.localModelOption,
                            quantPreset: settingsStore.quantPreset
                        ))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingsCard("Set Up Local AI", systemImage: "arrow.down.circle") {
                SetupStatusView(
                    settingsStore: settingsStore,
                    modelManager: modelManager,
                    setupManager: setupManager,
                    startSetup: startSetup
                )
            }

            settingsCard("How TextKit Works", systemImage: "switch.2") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Use copied text automatically", isOn: $settingsStore.autoClipEnabled)

                    controlBlock(title: "Default Action") {
                        Picker("Default Action", selection: $settingsStore.defaultFallbackTool) {
                            ForEach(ToolKind.allCases) { tool in
                                Text(tool.title).tag(tool)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220, alignment: .leading)

                        Text("This is the action TextKit falls back to when it is not sure what you copied.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Keep Model Ready")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(settingsStore.warmCacheSeconds)) sec")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $settingsStore.warmCacheSeconds, in: 15...300, step: 15)

                        Text("Keeps the local AI ready for a short time after you use it, so the next result can feel faster.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingsCard("About Local AI", systemImage: "cpu") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TextKit runs the selected AI model locally on your Mac after it has been downloaded.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The model is downloaded once. After that, your copied text stays on-device while TextKit works.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var promptProfilesPane: some View {
        settingsScrollView {
            settingsCard("Customize a Style", systemImage: "slider.horizontal.below.rectangle") {
                VStack(alignment: .leading, spacing: 14) {
                    modeSelectionHeader

                    Text("TextKit keeps its built-in rules. Here you can adjust the extra instructions and output settings for the selected style.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsCard("Built-In Instructions", systemImage: "lock") {
                readOnlyPromptBlock(PromptComposer.lockedBaseSystemPrompt, height: 108)
            }

            settingsCard("Extra Instructions", systemImage: "text.alignleft") {
                TextEditor(text: systemInstructionBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
            }

            settingsCard("What To Create", systemImage: "doc.plaintext") {
                TextEditor(text: taskTemplateBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
            }

            settingsCard("Response Settings", systemImage: "dial.medium") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Creativity")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(editableConfiguration.temperature, format: .number.precision(.fractionLength(2)))
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: temperatureBinding, in: 0...1, step: 0.05)

                        Text("Lower is steadier. Higher allows more variety.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

            settingsCard("Save or Reset", systemImage: "square.and.arrow.down.on.square") {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Button("Reset This Style") {
                                settingsStore.resetConfiguration(for: selectedMode)
                            }

                            Button("Reset All Styles") {
                                settingsStore.resetAllPromptConfigurations()
                            }

                            Button("Use Consistent Defaults") {
                                settingsStore.applyStrictModeDefaults()
                            }

                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Button("Reset This Style") {
                                settingsStore.resetConfiguration(for: selectedMode)
                            }

                            Button("Reset All Styles") {
                                settingsStore.resetAllPromptConfigurations()
                            }

                            Button("Use Consistent Defaults") {
                                settingsStore.applyStrictModeDefaults()
                            }
                        }
                    }

                    Divider()

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Button("Import Settings") {
                                runProfileAction("Imported custom settings.") {
                                    try settingsStore.importPromptProfile()
                                }
                            }

                            Button("Export Settings") {
                                runProfileAction("Exported custom settings.") {
                                    try settingsStore.exportPromptProfile()
                                }
                            }

                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Button("Import Settings") {
                                runProfileAction("Imported custom settings.") {
                                    try settingsStore.importPromptProfile()
                                }
                            }

                            Button("Export Settings") {
                                runProfileAction("Exported custom settings.") {
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
            settingsCard("Preview Your Setup", systemImage: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 14) {
                    modeSelectionHeader

                    TextField("Optional extra note", text: $previewRefineInstruction)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $previewInput)
                        .font(.body)
                        .frame(minHeight: 120)

                    Text("Use this page to see what TextKit will send for the selected style.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsCard("Built-In Instructions Used", systemImage: "lock.doc") {
                readOnlyPromptBlock(previewPrompt.systemPrompt, height: 180)
            }

            settingsCard("Final Request Sent", systemImage: "text.badge.plus") {
                readOnlyPromptBlock(previewPrompt.userPrompt, height: 220)
            }

            settingsCard("Live Debug Check", systemImage: "waveform.path.ecg") {
                VStack(alignment: .leading, spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Button(debugIsRunning ? "Running..." : "Run Live Check") {
                                Task {
                                    await runDebugEvaluationNow()
                                }
                            }
                            .disabled(debugIsRunning || !canRunDebugEvaluation)

                            Spacer(minLength: 0)

                            Text(activeModel.displayName)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Button(debugIsRunning ? "Running..." : "Run Live Check") {
                                Task {
                                    await runDebugEvaluationNow()
                                }
                            }
                            .disabled(debugIsRunning || !canRunDebugEvaluation)

                            Text(activeModel.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("This runs the same local model, prompt settings, runtime path, and output shaping that TextKit uses in the menu bar app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(debugStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if hasDebugResult {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                debugOutputBlock(
                                    title: "Raw Model Output",
                                    systemImage: "bolt.horizontal",
                                    text: debugRawOutput
                                )
                                debugOutputBlock(
                                    title: "Final TextKit Output",
                                    systemImage: "checkmark.seal",
                                    text: debugFinalOutput
                                )
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                debugOutputBlock(
                                    title: "Raw Model Output",
                                    systemImage: "bolt.horizontal",
                                    text: debugRawOutput
                                )
                                debugOutputBlock(
                                    title: "Final TextKit Output",
                                    systemImage: "checkmark.seal",
                                    text: debugFinalOutput
                                )
                            }
                        }
                    }
                }
            }

            Text("When More Consistent Results is on, this preview uses the steadier settings too.")
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
            Text("Tool & Style")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Tool & Style", selection: $selectedAdvancedModeID) {
                ForEach(ToolMode.promptTunableModes) { mode in
                    Text("\(mode.tool.title) · \(mode.title)").tag(mode.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 280, alignment: .leading)
        }
    }

    private var strictModeToggle: some View {
        Toggle("More Consistent Results", isOn: $settingsStore.strictModeEnabled)
            .toggleStyle(.switch)
    }

    private var maxTokensControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Length Limit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(editableConfiguration.maxTokens)")
                    .foregroundStyle(.secondary)
            }

            Stepper(value: maxTokensBinding, in: 32...512, step: 8) {
                Text("Allow longer results")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var seedControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variation Code")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Use -1 for automatic", value: seedBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180, alignment: .leading)

            Text("Use the same number for steadier repeats. Use -1 for a fresh variation each time.")
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

    private func debugOutputBlock(
        title: String,
        systemImage: String,
        text: String
    ) -> some View {
        GroupBox {
            readOnlyPromptBlock(text.isEmpty ? "No output yet." : text, height: 180)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func invalidateDebugResult() {
        debugRawOutput = ""
        debugFinalOutput = ""
        debugStatus = "Run a live check with the current model and style."
    }

    @MainActor
    private func runDebugEvaluationNow() async {
        debugIsRunning = true
        debugRawOutput = ""
        debugFinalOutput = ""
        debugStatus = "Running the live local check..."

        do {
            let result = try await runDebugEvaluation(
                previewInput,
                previewRefineInstruction,
                selectedMode
            )

            debugRawOutput = result.rawOutput
            debugFinalOutput = result.finalizedOutput
            debugStatus = debugSummary(for: result)
        } catch {
            debugStatus = error.localizedDescription
        }

        debugIsRunning = false
    }

    private func debugSummary(for result: DebugEvaluationResult) -> String {
        let shapingSummary = result.rawOutput == result.finalizedOutput
            ? "The raw model output already matched TextKit's final result."
            : "TextKit adjusted the raw model output before showing the final result."
        let runtimeSummary = result.keepsRuntimeWarm
            ? "The local runtime stayed warm for faster follow-up checks."
            : "The check finished without keeping the runtime warm."
        return "\(shapingSummary) \(runtimeSummary)"
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
