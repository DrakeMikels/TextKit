import Foundation
import Observation

@Observable
final class SettingsStore {
    private enum Keys {
        static let modelProfile = "settings.modelProfile"
        static let quantPreset = "settings.quantPreset"
        static let autoClipEnabled = "settings.autoClipEnabled"
        static let defaultFallbackTool = "settings.defaultFallbackTool"
        static let warmCacheSeconds = "settings.warmCacheSeconds"
    }

    private let defaults: UserDefaults

    var modelProfile: ModelProfile {
        didSet { defaults.set(modelProfile.rawValue, forKey: Keys.modelProfile) }
    }

    var quantPreset: QuantPreset {
        didSet { defaults.set(quantPreset.rawValue, forKey: Keys.quantPreset) }
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.modelProfile = ModelProfile(rawValue: defaults.string(forKey: Keys.modelProfile) ?? "") ?? .balanced
        self.quantPreset = QuantPreset(rawValue: defaults.string(forKey: Keys.quantPreset) ?? "") ?? .balanced
        self.autoClipEnabled = defaults.object(forKey: Keys.autoClipEnabled) as? Bool ?? true
        self.defaultFallbackTool = ToolKind(rawValue: defaults.string(forKey: Keys.defaultFallbackTool) ?? "") ?? .rewrite
        self.warmCacheSeconds = defaults.object(forKey: Keys.warmCacheSeconds) as? Double ?? 45
    }
}
