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
    private let cacheStore: CacheStore

    var inputText: String = ""
    var refineInstruction: String = ""
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
        cacheStore: CacheStore = CacheStore()
    ) {
        self.settingsStore = settingsStore
        self.modelManager = modelManager
        self.clipboardMonitor = clipboardMonitor
        self.routeEngine = routeEngine
        self.promptComposer = promptComposer
        self.inferenceEngine = inferenceEngine
        self.cacheStore = cacheStore
        self.selectedTool = settingsStore.defaultFallbackTool
        self.selectedMode = settingsStore.defaultFallbackTool.defaultMode

        startClipboardMonitoring()
    }

    var availableModes: [ToolMode] {
        selectedTool.modes
    }

    var modelSummary: String {
        "\(modelManager.defaultModel.displayName) · \(settingsStore.modelProfile.title)"
    }

    func selectTool(_ tool: ToolKind) {
        selectedTool = tool
        if selectedMode.tool != tool {
            selectedMode = tool.defaultMode
        }
        regenerate()
    }

    func selectMode(_ mode: ToolMode) {
        selectedMode = mode
        regenerate()
    }

    func regenerate() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            outputText = "Copy text anywhere on macOS to precompute a result."
            statusText = "Watching clipboard"
            return
        }

        let request = GenerationRequest(
            inputText: trimmed,
            refineInstruction: refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
            tool: selectedTool,
            mode: selectedMode,
            modelProfile: settingsStore.modelProfile,
            quantPreset: settingsStore.quantPreset
        )

        let key = CacheKey(
            clipboardHash: trimmed.hashValue,
            tool: request.tool,
            modeID: request.mode.id,
            modelProfile: request.modelProfile,
            quantPreset: request.quantPreset,
            refineInstruction: request.refineInstruction
        )

        if let cached = cacheStore.output(for: key) {
            outputText = cached
            statusText = "\(modelManager.statusSummary) · cached"
            return
        }

        modelManager.markWarm()
        let prompt = promptComposer.compose(for: request)
        let output = inferenceEngine.generate(for: request, prompt: prompt)

        cacheStore.store(output, for: key)
        outputText = output
        statusText = "\(modelManager.statusSummary) · ready"
    }

    func copyOutputToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
        statusText = "\(modelManager.statusSummary) · copied"
    }

    private func startClipboardMonitoring() {
        clipboardMonitor.start { [weak self] clipboardText in
            guard let self else { return }
            guard self.settingsStore.autoClipEnabled else { return }

            self.cacheStore.invalidateAll()
            self.inputText = clipboardText

            let routedTool = self.routeEngine.route(
                clipboardText,
                fallback: self.settingsStore.defaultFallbackTool
            )

            self.selectedTool = routedTool
            self.selectedMode = routedTool.defaultMode
            self.regenerate()
        }
    }
}
