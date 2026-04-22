import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let settingsStore: SettingsStore
    let modelManager: ModelManager

    private let clipboardMonitor: ClipboardMonitor
    private let routeEngine: RouteEngine
    private let promptComposer: PromptComposer
    private let inferenceEngine: InferenceEngine
    private let outputPostProcessor: OutputPostProcessor
    private let cacheStore: CacheStore
    private var lastSelectedModeByTool: [ToolKind: ToolMode]
    private var generationTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var generationRevision = 0

    var inputText: String = ""
    var refineInstruction: String = ""
    var refineDraft: String = ""
    var selectedTool: ToolKind
    var selectedMode: ToolMode
    var outputText = "Copy text anywhere on macOS to precompute a result."
    var statusText = "On-device"

    init(
        settingsStore: SettingsStore = SettingsStore(),
        modelManager: ModelManager = ModelManager(),
        clipboardMonitor: ClipboardMonitor = ClipboardMonitor(),
        routeEngine: RouteEngine = RouteEngine(),
        promptComposer: PromptComposer = PromptComposer(),
        inferenceEngine: InferenceEngine = InferenceEngine(),
        outputPostProcessor: OutputPostProcessor = OutputPostProcessor(),
        cacheStore: CacheStore = CacheStore()
    ) {
        self.settingsStore = settingsStore
        self.modelManager = modelManager
        self.clipboardMonitor = clipboardMonitor
        self.routeEngine = routeEngine
        self.promptComposer = promptComposer
        self.inferenceEngine = inferenceEngine
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
            await self.modelManager.refreshAvailability(for: self.settingsStore.quantPreset)
            self.statusText = self.modelManager.statusSummary
        }
    }

    var availableModes: [ToolMode] {
        selectedTool.modes
    }

    var modelSummary: String {
        let model = modelManager.model(for: settingsStore.quantPreset)
        return "\(model.displayName) · \(settingsStore.modelProfile.title) profile · \(settingsStore.quantPreset.title) quant"
    }

    var hasPendingRefineChanges: Bool {
        refineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            != refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmitRefine: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasPendingRefineChanges
    }

    func selectTool(_ tool: ToolKind) {
        selectedTool = tool
        if selectedMode.tool != tool {
            selectedMode = lastSelectedModeByTool[tool] ?? tool.defaultMode
        }
        regenerateNow()
    }

    func selectMode(_ mode: ToolMode) {
        selectedMode = mode
        lastSelectedModeByTool[mode.tool] = mode
        regenerateNow()
    }

    func scheduleRegeneration() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.regenerateNow()
        }
    }

    func refreshModelAvailability() {
        Task { [weak self] in
            guard let self else { return }
            await self.modelManager.refreshAvailability(for: self.settingsStore.quantPreset)
            self.statusText = self.modelManager.statusSummary
        }
    }

    func handleRuntimeSelectionChange() {
        Task { [weak self] in
            guard let self else { return }
            await self.inferenceEngine.stopWarmRuntime(modelManager: self.modelManager)
            await self.modelManager.refreshAvailability(for: self.settingsStore.quantPreset)
            self.statusText = self.modelManager.statusSummary
            self.cacheStore.invalidateAll()
            self.regenerateNow()
        }
    }

    func handleGenerationSettingsChange() {
        cacheStore.invalidateAll()
        scheduleRegeneration()
    }

    func submitRefine() {
        let trimmedDraft = refineDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDraft != refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }

        refineInstruction = trimmedDraft
        regenerateNow()
    }

    func regenerateNow() {
        generationTask?.cancel()

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            outputText = "Copy text anywhere on macOS to precompute a result."
            statusText = modelManager.statusSummary
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
            modelProfile: request.modelProfile,
            quantPreset: request.quantPreset,
            refineInstruction: request.refineInstruction,
            configurationFingerprint: settingsStore.configurationFingerprint(for: selectedMode)
        )

        if let cached = cacheStore.output(for: key) {
            outputText = cached
            statusText = "\(modelManager.statusSummary) · cached"
            return
        }

        let prompt = promptComposer.compose(for: request)
        generationRevision += 1
        let revision = generationRevision

        modelManager.markRunning()
        let model = modelManager.model(for: request.quantPreset)
        outputText = "Generating locally with \(model.displayName)…"
        statusText = modelManager.statusSummary

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let generation = try await self.inferenceEngine.generate(
                    for: request,
                    prompt: prompt,
                    executableURL: self.modelManager.runtimeExecutableURL,
                    serverExecutableURL: self.modelManager.serverExecutableURL,
                    model: model,
                    setupCommand: self.modelManager.setupCommand(for: request.quantPreset),
                    warmCacheSeconds: self.settingsStore.warmCacheSeconds,
                    modelManager: self.modelManager
                )
                let output = self.outputPostProcessor.finalize(generation.text, for: request)

                guard !Task.isCancelled, revision == self.generationRevision else { return }

                self.cacheStore.store(output, for: key)
                self.modelManager.markReady(isWarm: generation.keepsRuntimeWarm)
                self.outputText = output
                self.statusText = "\(self.modelManager.statusSummary) · ready"
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
        statusText = "\(modelManager.statusSummary) · copied"
    }

    private func startClipboardMonitoring() {
        clipboardMonitor.start { [weak self] clipboardText in
            guard let self else { return }
            guard self.settingsStore.autoClipEnabled else { return }
            guard !self.shouldIgnoreClipboardText(clipboardText) else { return }

            self.cacheStore.invalidateAll()
            self.inputText = clipboardText
            self.refineInstruction = ""
            self.refineDraft = ""

            let routedTool = self.routeEngine.route(
                clipboardText,
                fallback: self.settingsStore.defaultFallbackTool
            )

            self.selectedTool = routedTool
            self.selectedMode = self.lastSelectedModeByTool[routedTool] ?? routedTool.defaultMode
            self.regenerateNow()
        }
    }

    private func shouldIgnoreClipboardText(_ clipboardText: String) -> Bool {
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSApplication.shared.isActive && !trimmedOutput.isEmpty && clipboardText == trimmedOutput
    }
}
