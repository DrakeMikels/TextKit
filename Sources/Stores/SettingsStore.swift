import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let localModelOption = "settings.localModelOption"
        static let modelProfile = "settings.modelProfile"
        static let quantPreset = "settings.quantPreset"
        static let autoClipEnabled = "settings.autoClipEnabled"
        static let defaultFallbackTool = "settings.defaultFallbackTool"
        static let warmCacheSeconds = "settings.warmCacheSeconds"
        static let strictModeEnabled = "settings.strictModeEnabled"
        static let promptProfile = "settings.promptProfile"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private(set) var generationSettingsRevision = 0
    private(set) var runtimeSelectionRevision = 0

    var localModelOption: LocalModelOption {
        didSet {
            defaults.set(localModelOption.rawValue, forKey: Keys.localModelOption)
            generationSettingsRevision += 1
            runtimeSelectionRevision += 1
        }
    }

    var modelProfile: ModelProfile {
        didSet {
            defaults.set(modelProfile.rawValue, forKey: Keys.modelProfile)
            generationSettingsRevision += 1
        }
    }

    var quantPreset: QuantPreset {
        didSet {
            defaults.set(quantPreset.rawValue, forKey: Keys.quantPreset)
            generationSettingsRevision += 1
            runtimeSelectionRevision += 1
        }
    }

    var autoClipEnabled: Bool {
        didSet { defaults.set(autoClipEnabled, forKey: Keys.autoClipEnabled) }
    }

    var defaultFallbackTool: ToolKind {
        didSet { defaults.set(defaultFallbackTool.rawValue, forKey: Keys.defaultFallbackTool) }
    }

    var warmCacheSeconds: Double {
        didSet { defaults.set(warmCacheSeconds, forKey: Keys.warmCacheSeconds) }
    }

    var strictModeEnabled: Bool {
        didSet {
            defaults.set(strictModeEnabled, forKey: Keys.strictModeEnabled)
            generationSettingsRevision += 1
        }
    }

    private var modeConfigurations: [String: ModePromptConfiguration] {
        didSet {
            persistPromptProfile()
            generationSettingsRevision += 1
        }
    }

    init(defaults: UserDefaults? = nil) {
        let resolvedDefaults = defaults ?? Self.runtimeDefaults()
        self.defaults = resolvedDefaults
        self.localModelOption = LocalModelOption(rawValue: resolvedDefaults.string(forKey: Keys.localModelOption) ?? "") ?? .stable
        self.modelProfile = ModelProfile(rawValue: resolvedDefaults.string(forKey: Keys.modelProfile) ?? "") ?? .balanced
        self.quantPreset = QuantPreset(rawValue: resolvedDefaults.string(forKey: Keys.quantPreset) ?? "") ?? .balanced
        self.autoClipEnabled = resolvedDefaults.object(forKey: Keys.autoClipEnabled) as? Bool ?? true
        self.defaultFallbackTool = ToolKind(rawValue: resolvedDefaults.string(forKey: Keys.defaultFallbackTool) ?? "") ?? .rewrite
        self.warmCacheSeconds = resolvedDefaults.object(forKey: Keys.warmCacheSeconds) as? Double ?? 45
        self.strictModeEnabled = resolvedDefaults.object(forKey: Keys.strictModeEnabled) as? Bool ?? false
        self.modeConfigurations = SettingsStore.loadPromptProfile(from: resolvedDefaults)
    }

    func promptConfiguration(for mode: ToolMode) -> ModePromptConfiguration {
        let base = modeConfigurations[mode.id] ?? .default(for: mode)
        return strictModeEnabled ? base.strictAdjusted() : base
    }

    func editablePromptConfiguration(for mode: ToolMode) -> ModePromptConfiguration {
        modeConfigurations[mode.id] ?? .default(for: mode)
    }

    func setSystemInstruction(_ value: String, for mode: ToolMode) {
        var configuration = editablePromptConfiguration(for: mode)
        configuration.systemInstruction = value
        modeConfigurations[mode.id] = configuration
    }

    func setTaskTemplate(_ value: String, for mode: ToolMode) {
        var configuration = editablePromptConfiguration(for: mode)
        configuration.taskTemplate = value
        modeConfigurations[mode.id] = configuration
    }

    func setTemperature(_ value: Double, for mode: ToolMode) {
        var configuration = editablePromptConfiguration(for: mode)
        configuration.temperature = value
        modeConfigurations[mode.id] = configuration
    }

    func setMaxTokens(_ value: Int, for mode: ToolMode) {
        var configuration = editablePromptConfiguration(for: mode)
        configuration.maxTokens = value
        modeConfigurations[mode.id] = configuration
    }

    func setSeed(_ value: Int, for mode: ToolMode) {
        var configuration = editablePromptConfiguration(for: mode)
        configuration.seed = value
        modeConfigurations[mode.id] = configuration
    }

    func configurationFingerprint(for mode: ToolMode) -> String {
        let configuration = promptConfiguration(for: mode)
        let data = try? encoder.encode(configuration)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\(configuration.hashValue)"
    }

    func resetConfiguration(for mode: ToolMode) {
        modeConfigurations[mode.id] = .default(for: mode)
    }

    func resetAllPromptConfigurations() {
        modeConfigurations = Dictionary(
            uniqueKeysWithValues: ToolMode.allCases.map { ($0.id, .default(for: $0)) }
        )
        strictModeEnabled = false
    }

    func applyStrictModeDefaults() {
        modeConfigurations = Dictionary(
            uniqueKeysWithValues: ToolMode.allCases.map { mode in
                var configuration = ModePromptConfiguration.default(for: mode)
                configuration.temperature = min(configuration.temperature, 0.15)
                configuration.seed = 7
                return (mode.id, configuration)
            }
        )
        strictModeEnabled = true
    }

    func exportPromptProfile() throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "TextKitPromptProfile.json"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let document = PromptProfileDocument(
            strictModeEnabled: strictModeEnabled,
            modeConfigurations: modeConfigurations
        )
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    func importPromptProfile() throws {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let data = try Data(contentsOf: url)
        let imported = try decoder.decode(PromptProfileDocument.self, from: data)
        strictModeEnabled = imported.strictModeEnabled
        modeConfigurations = Dictionary(
            uniqueKeysWithValues: ToolMode.allCases.map { mode in
                (mode.id, imported.modeConfigurations[mode.id] ?? .default(for: mode))
            }
        )
    }

    private func persistPromptProfile() {
        let document = PromptProfileDocument(
            strictModeEnabled: strictModeEnabled,
            modeConfigurations: modeConfigurations
        )

        if let data = try? encoder.encode(document) {
            defaults.set(data, forKey: Keys.promptProfile)
        }
    }

    private static func loadPromptProfile(from defaults: UserDefaults) -> [String: ModePromptConfiguration] {
        guard
            let data = defaults.data(forKey: Keys.promptProfile),
            let document = try? JSONDecoder().decode(PromptProfileDocument.self, from: data)
        else {
            return Dictionary(uniqueKeysWithValues: ToolMode.allCases.map { ($0.id, .default(for: $0)) })
        }

        return Dictionary(
            uniqueKeysWithValues: ToolMode.allCases.map { mode in
                let configuration = document.modeConfigurations[mode.id] ?? .default(for: mode)
                return (mode.id, migratePromptConfiguration(configuration, for: mode, from: document.version))
            }
        )
    }

    private static func runtimeDefaults() -> UserDefaults {
        let environment = ProcessInfo.processInfo.environment

        guard
            let suiteName = environment["TEXTKIT_USER_DEFAULTS_SUITE"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !suiteName.isEmpty,
            let suiteDefaults = UserDefaults(suiteName: suiteName)
        else {
            return .standard
        }

        return suiteDefaults
    }

    private static func migratePromptConfiguration(
        _ configuration: ModePromptConfiguration,
        for mode: ToolMode,
        from version: Int
    ) -> ModePromptConfiguration {
        guard version < PromptProfileDocument.currentVersion else {
            return configuration
        }

        if version < 2, configuration == .legacyDefaultV1(for: mode) {
            return .default(for: mode)
        }

        return configuration
    }
}
