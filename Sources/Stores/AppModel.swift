import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsStore: SettingsStore
    let modelManager: ModelManager
    let setupManager: SetupManager

    private let clipboardMonitor: ClipboardMonitor
    private let routeEngine: RouteEngine
    private let promptComposer: PromptComposer
    private let inferenceEngine: InferenceEngine
    private let reductionEngine: ReductionEngine
    private let outputPostProcessor: OutputPostProcessor
    private let cacheStore: CacheStore
    private var lastSelectedModeByTool: [ToolKind: ToolMode]
    private var generationTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var generationRevision = 0
    private var lastReductionFingerprint: String?

    var inputText: String = ""
    var refineInstruction: String = ""
    var refineDraft: String = ""
    var selectedTool: ToolKind
    var selectedMode: ToolMode
    var outputText = "Copy text anywhere on macOS to precompute a result."
    var statusText = "On-device"
    var reductionStats: ReductionStats?

    init(
        settingsStore: SettingsStore = SettingsStore(),
        modelManager: ModelManager = ModelManager(),
        setupManager: SetupManager = SetupManager(),
        clipboardMonitor: ClipboardMonitor = ClipboardMonitor(),
        routeEngine: RouteEngine = RouteEngine(),
        promptComposer: PromptComposer = PromptComposer(),
        inferenceEngine: InferenceEngine = InferenceEngine(),
        reductionEngine: ReductionEngine = ReductionEngine(),
        outputPostProcessor: OutputPostProcessor = OutputPostProcessor(),
        cacheStore: CacheStore = CacheStore()
    ) {
        self.settingsStore = settingsStore
        self.modelManager = modelManager
        self.setupManager = setupManager
        self.clipboardMonitor = clipboardMonitor
        self.routeEngine = routeEngine
        self.promptComposer = promptComposer
        self.inferenceEngine = inferenceEngine
        self.reductionEngine = reductionEngine
        self.outputPostProcessor = outputPostProcessor
        self.cacheStore = cacheStore
        self.selectedTool = settingsStore.defaultFallbackTool
        self.selectedMode = settingsStore.defaultFallbackTool.defaultMode
        self.lastSelectedModeByTool = Dictionary(
            uniqueKeysWithValues: ToolKind.allCases.map { ($0, $0.defaultMode) }
        )
        self.statusText = "Checking local model"

        startClipboardMonitoring()

        Task { [weak self] in
            guard let self else { return }
            await self.modelManager.refreshAvailability(
                for: self.settingsStore.localModelOption,
                quantPreset: self.settingsStore.quantPreset
            )
            self.statusText = self.defaultStatusText()
        }
    }

    var availableModes: [ToolMode] {
        selectedTool.modes
    }

    var modelSummary: String {
        if !selectedTool.usesModel {
            return "Local reducer · no model required"
        }

        let model = modelManager.model(
            for: settingsStore.localModelOption,
            quantPreset: settingsStore.quantPreset
        )
        return "\(model.displayName) · \(settingsStore.modelProfile.title) profile · \(settingsStore.quantPreset.title) quant"
    }

    var showsSetupFlow: Bool {
        setupManager.isRunning
            || setupManager.hasFailure
            || modelManager.runtimeState == .missingRuntime
            || modelManager.runtimeState == .missingModel
    }

    var hasPendingRefineChanges: Bool {
        refineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            != refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmitRefine: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasPendingRefineChanges
    }

    var hasPendingReductionChanges: Bool {
        guard selectedTool == .reduce else { return false }
        return reductionFingerprint(for: inputText, mode: selectedMode) != lastReductionFingerprint
    }

    var canSubmitReduction: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasPendingReductionChanges
    }

    var reductionSummaryText: String? {
        guard let reductionStats else { return nil }
        return "Chars \(reductionStats.originalCharacterCount.formatted()) -> \(reductionStats.reducedCharacterCount.formatted()) · Estimated tokens \(reductionStats.originalEstimatedTokenCount.formatted()) -> \(reductionStats.reducedEstimatedTokenCount.formatted()) · \(String(format: "%.1f", reductionStats.reductionPercent))% smaller"
    }

    func selectTool(_ tool: ToolKind) {
        selectedTool = tool
        if selectedMode.tool != tool {
            selectedMode = lastSelectedModeByTool[tool] ?? tool.defaultMode
        }
        generationTask?.cancel()
        debounceTask?.cancel()
        if tool == .reduce {
            clearReductionResult()
            Task { [weak self] in
                guard let self else { return }
                await self.inferenceEngine.stopWarmRuntime(modelManager: self.modelManager)
            }
        } else {
            reductionStats = nil
        }
        regenerateNow()
    }

    func selectMode(_ mode: ToolMode) {
        selectedMode = mode
        lastSelectedModeByTool[mode.tool] = mode
        if mode.tool == .reduce {
            clearReductionResult()
        }
        regenerateNow()
    }

    func scheduleRegeneration() {
        guard !selectedTool.requiresManualSubmit else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.regenerateNow()
        }
    }

    func handleInputChange() {
        if selectedTool.requiresManualSubmit {
            clearReductionResult()
            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                statusText = "Ready to reduce locally"
                outputText = "Copy text anywhere on macOS, then press send to reduce it."
            } else {
                statusText = "Press send to reduce the current text"
                outputText = "Reduce is manual so you can choose when to shrink logs or long text."
            }
            return
        }

        scheduleRegeneration()
    }

    func refreshModelAvailability() {
        Task { [weak self] in
            guard let self else { return }
            await self.modelManager.refreshAvailability(
                for: self.settingsStore.localModelOption,
                quantPreset: self.settingsStore.quantPreset
            )
            self.statusText = self.defaultStatusText()
        }
    }

    func handleRuntimeSelectionChange() {
        Task { [weak self] in
            guard let self else { return }
            await self.inferenceEngine.stopWarmRuntime(modelManager: self.modelManager)
            self.setupManager.resetFailure()
            await self.modelManager.refreshAvailability(
                for: self.settingsStore.localModelOption,
                quantPreset: self.settingsStore.quantPreset
            )
            self.statusText = self.defaultStatusText()
            self.cacheStore.invalidateAll()
            self.regenerateNow()
        }
    }

    func handleGenerationSettingsChange() {
        cacheStore.invalidateAll()
        if selectedTool.requiresManualSubmit {
            clearReductionResult()
            outputText = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Copy text anywhere on macOS, then press send to reduce it."
                : "Reduce is manual so you can choose when to shrink logs or long text."
        } else {
            scheduleRegeneration()
        }
    }

    func submitRefine() {
        let trimmedDraft = refineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft != refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }

        refineInstruction = trimmedDraft
        regenerateNow()
    }

    func submitReduction() {
        guard selectedTool == .reduce else { return }

        generationTask?.cancel()
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            clearReductionResult()
            statusText = "Ready to reduce locally"
            outputText = "Copy text anywhere on macOS, then press send to reduce it."
            return
        }

        let result = reductionEngine.reduce(trimmedInput, mode: selectedMode)
        outputText = result.text
        reductionStats = result.stats
        lastReductionFingerprint = reductionFingerprint(for: trimmedInput, mode: selectedMode)
        if result.stats.savedEstimatedTokenCount <= 0 {
            statusText = "Reduced locally · no obvious redundancy found"
        } else if result.stats.reductionPercent < 10 {
            statusText = "Reduced locally · limited savings"
        } else {
            statusText = "Reduced locally · \(String(format: "%.1f", result.stats.reductionPercent))% smaller"
        }
    }

    func runDebugEvaluation(
        inputText: String,
        refineInstruction: String,
        mode: ToolMode
    ) async throws -> DebugEvaluationResult {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw DebugEvaluationError.emptyInput
        }

        if mode.tool == .reduce {
            let result = reductionEngine.reduce(trimmedInput, mode: mode)
            return DebugEvaluationResult(
                rawOutput: result.text,
                finalizedOutput: result.text,
                keepsRuntimeWarm: false
            )
        }

        let request = GenerationRequest(
            inputText: trimmedInput,
            refineInstruction: refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
            tool: mode.tool,
            mode: mode,
            modelProfile: settingsStore.modelProfile,
            quantPreset: settingsStore.quantPreset,
            promptConfiguration: settingsStore.promptConfiguration(for: mode)
        )

        let prompt = promptComposer.compose(for: request)
        let model = modelManager.model(
            for: settingsStore.localModelOption,
            quantPreset: request.quantPreset
        )

        modelManager.markRunning()

        do {
            let generation = try await inferenceEngine.generate(
                for: request,
                prompt: prompt,
                executableURL: modelManager.runtimeExecutableURL,
                serverExecutableURL: modelManager.serverExecutableURL,
                model: model,
                setupCommand: modelManager.setupCommand(
                    for: settingsStore.localModelOption,
                    quantPreset: request.quantPreset
                ),
                warmCacheSeconds: settingsStore.warmCacheSeconds,
                modelManager: modelManager
            )
            let rawOutput = generation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalizedOutput = outputPostProcessor.finalize(rawOutput, for: request)

            modelManager.markReady(isWarm: generation.keepsRuntimeWarm)

            return DebugEvaluationResult(
                rawOutput: rawOutput,
                finalizedOutput: finalizedOutput,
                keepsRuntimeWarm: generation.keepsRuntimeWarm
            )
        } catch let error as InferenceEngineError {
            switch error {
            case .missingRuntime:
                modelManager.markMissingRuntime()
            case .modelNotInstalled:
                modelManager.markMissingModel()
            case let .executionFailed(message):
                modelManager.markFailure(message)
            case .emptyOutput:
                modelManager.markFailure("The local model returned no text.")
            }

            throw error
        } catch {
            modelManager.markFailure("The local model failed.")
            throw error
        }
    }

    func regenerateNow() {
        generationTask?.cancel()

        guard !(showsSetupFlow && selectedTool.usesModel) else {
            statusText = setupManager.isRunning ? setupManager.stepTitle : modelManager.statusSummary
            outputText = setupManager.summary(
                for: modelManager.runtimeState,
                model: modelManager.model(
                    for: settingsStore.localModelOption,
                    quantPreset: settingsStore.quantPreset
                )
            )
            return
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            outputText = selectedTool == .reduce
                ? "Copy text anywhere on macOS, then press send to reduce it."
                : "Copy text anywhere on macOS to precompute a result."
            statusText = defaultStatusText()
            reductionStats = nil
            return
        }

        guard selectedTool.usesModel else {
            clearReductionResult()
            statusText = "Press send to reduce the current text"
            outputText = "Reduce is manual so you can choose when to shrink logs or long text."
            return
        }

        let request = GenerationRequest(
            inputText: trimmed,
            refineInstruction: refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
            tool: selectedTool,
            mode: selectedMode,
            modelProfile: settingsStore.modelProfile,
            quantPreset: settingsStore.quantPreset,
            promptConfiguration: settingsStore.promptConfiguration(for: selectedMode)
        )

        let key = CacheKey(
            clipboardHash: trimmed.hashValue,
            tool: request.tool,
            modeID: request.mode.id,
            modelOption: settingsStore.localModelOption,
            modelProfile: request.modelProfile,
            quantPreset: request.quantPreset,
            refineInstruction: request.refineInstruction,
            configurationFingerprint: settingsStore.configurationFingerprint(for: selectedMode)
        )

        if let cached = cacheStore.output(for: key) {
            outputText = cached
            statusText = "\(modelManager.statusSummary) · cached"
            reductionStats = nil
            return
        }

        let prompt = promptComposer.compose(for: request)
        generationRevision += 1
        let revision = generationRevision

        modelManager.markRunning()
        let model = modelManager.model(
            for: settingsStore.localModelOption,
            quantPreset: request.quantPreset
        )
        outputText = "Generating locally with \(model.displayName)…"
        statusText = modelManager.statusSummary
        reductionStats = nil

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let generation = try await self.inferenceEngine.generate(
                    for: request,
                    prompt: prompt,
                    executableURL: self.modelManager.runtimeExecutableURL,
                    serverExecutableURL: self.modelManager.serverExecutableURL,
                    model: model,
                    setupCommand: self.modelManager.setupCommand(
                        for: self.settingsStore.localModelOption,
                        quantPreset: request.quantPreset
                    ),
                    warmCacheSeconds: self.settingsStore.warmCacheSeconds,
                    modelManager: self.modelManager
                )
                let output = self.outputPostProcessor.finalize(generation.text, for: request)

                guard !Task.isCancelled, revision == self.generationRevision else { return }

                self.cacheStore.store(output, for: key)
                self.modelManager.markReady(isWarm: generation.keepsRuntimeWarm)
                self.outputText = output
                self.statusText = "\(self.modelManager.statusSummary) · ready"
                self.reductionStats = nil
            } catch let error as InferenceEngineError {
                guard !Task.isCancelled, revision == self.generationRevision else { return }

                switch error {
                case .missingRuntime:
                    self.modelManager.markMissingRuntime()
                case .modelNotInstalled:
                    self.modelManager.markMissingModel()
                case let .executionFailed(message):
                    self.modelManager.markFailure(message)
                case .emptyOutput:
                    self.modelManager.markFailure("The local model returned no text.")
                }

                self.outputText = error.localizedDescription
                self.statusText = self.modelManager.statusSummary
            } catch {
                guard !Task.isCancelled, revision == self.generationRevision else { return }

                self.modelManager.markFailure("The local model failed.")
                self.outputText = error.localizedDescription
                self.statusText = self.modelManager.statusSummary
            }
        }
    }

    func copyOutputToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([ClipboardMonitor.makeManagedPasteboardItem(text: outputText)])
        statusText = selectedTool == .reduce ? "Reduced text copied" : "\(modelManager.statusSummary) · copied"
    }

    func startSetup() {
        guard !setupManager.isRunning else { return }

        Task { [weak self] in
            guard let self else { return }

            let model = self.modelManager.model(
                for: self.settingsStore.localModelOption,
                quantPreset: self.settingsStore.quantPreset
            )
            self.statusText = "Setting up local AI"
            self.outputText = setupManager.summary(for: self.modelManager.runtimeState, model: model)

            await self.inferenceEngine.stopWarmRuntime(modelManager: self.modelManager)

            let succeeded = await self.setupManager.runSetup(for: model)
            await self.modelManager.refreshAvailability(
                for: self.settingsStore.localModelOption,
                quantPreset: self.settingsStore.quantPreset
            )
            self.statusText = self.defaultStatusText()

            if succeeded {
                self.cacheStore.invalidateAll()
                self.regenerateNow()
            } else {
                self.outputText = self.setupManager.summary(for: self.modelManager.runtimeState, model: model)
            }
        }
    }

    private func startClipboardMonitoring() {
        clipboardMonitor.start { [weak self] clipboardText in
            guard let self else { return }
            guard self.settingsStore.autoClipEnabled else { return }
            guard !self.shouldIgnoreClipboardText(clipboardText) else { return }

            self.generationTask?.cancel()
            self.debounceTask?.cancel()
            self.cacheStore.invalidateAll()
            self.inputText = clipboardText
            self.refineInstruction = ""
            self.refineDraft = ""
            self.clearReductionResult()

            let decision = self.routeEngine.decide(
                clipboardText,
                fallback: self.settingsStore.defaultFallbackTool
            )

            self.selectedTool = decision.tool
            let selectedMode = decision.preferredMode
                ?? self.lastSelectedModeByTool[decision.tool]
                ?? decision.tool.defaultMode
            self.selectedMode = selectedMode
            self.lastSelectedModeByTool[decision.tool] = selectedMode

            guard decision.shouldAutoGenerate else {
                Task { [weak self] in
                    guard let self else { return }
                    await self.inferenceEngine.stopWarmRuntime(modelManager: self.modelManager)
                }

                if decision.tool == .reduce, decision.preferredMode != nil {
                    self.statusText = "Large structured input detected"
                    self.outputText = "Large structured input was staged in Reduce so the local model would not auto-run. Click send to compress it locally."
                } else {
                    self.handleInputChange()
                }
                return
            }

            self.regenerateNow()
        }
    }

    private func shouldIgnoreClipboardText(_ clipboardText: String) -> Bool {
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSApplication.shared.isActive && !trimmedOutput.isEmpty && clipboardText == trimmedOutput
    }

    private func reductionFingerprint(for inputText: String, mode: ToolMode) -> String? {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }
        return "\(mode.id)|\(trimmedInput)"
    }

    private func clearReductionResult() {
        reductionStats = nil
        lastReductionFingerprint = nil
    }

    private func defaultStatusText() -> String {
        selectedTool == .reduce ? "Ready to reduce locally" : modelManager.statusSummary
    }
}
