import Foundation

struct TextKitCleanupResult: Equatable {
    var removedURLs: [URL] = []
    var skippedURLs: [URL] = []
    var errors: [String] = []

    var removedCount: Int {
        removedURLs.count
    }

    var didRemoveAnything: Bool {
        !removedURLs.isEmpty
    }

    var summary: String {
        if !errors.isEmpty {
            return errors.joined(separator: "\n")
        }

        if removedURLs.isEmpty {
            return "No TextKit model files were found."
        }

        return "Removed \(removedCount) TextKit item\(removedCount == 1 ? "" : "s")."
    }
}

enum TextKitCleanupManager {
    static let appSupportFolderName = "TextKit"
    static let xdgCacheFolderName = "xdg-cache"

    private static let modelRepositoryCacheNames = [
        "models--Qwen--Qwen2.5-0.5B-Instruct-GGUF",
        "models--AaryanK--Qwen3.5-0.8B-GGUF"
    ]

    private static let llamaPresetFilenames = [
        "Qwen_Qwen2.5-0.5B-Instruct-GGUF_preset.ini",
        "AaryanK_Qwen3.5-0.8B-GGUF_preset.ini"
    ]

    static func defaultXDGCacheURL() -> URL {
        appSupportURL()
            .appendingPathComponent(xdgCacheFolderName, isDirectory: true)
    }

    static func modelDataURLs() -> [URL] {
        uniqueURLs(appOwnedModelDataURLs() + legacyModelDataURLs())
    }

    static func removeModelData() -> TextKitCleanupResult {
        remove(urls: modelDataURLs())
    }

    static func removeAllUserData() -> TextKitCleanupResult {
        remove(urls: uniqueURLs([appSupportURL()] + modelDataURLs()))
    }

    static func trashCurrentAppBundle() throws {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return }

        var resultingURL: NSURL?
        try FileManager.default.trashItem(
            at: bundleURL,
            resultingItemURL: &resultingURL
        )
    }

    static func resetUserDefaults() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()
    }

    static func appOwnedModelDataURLs(
        appSupportURL: URL = Self.appSupportURL(),
        xdgCacheURL: URL = Self.defaultXDGCacheURL()
    ) -> [URL] {
        [
            xdgCacheURL,
            appSupportURL.appendingPathComponent(xdgCacheFolderName, isDirectory: true)
        ]
    }

    static func legacyModelDataURLs(
        homeURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let huggingFaceHubURL = homeURL
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)

        let llamaCacheURL = homeURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("llama.cpp", isDirectory: true)

        return modelRepositoryCacheNames.map { repositoryName in
            huggingFaceHubURL.appendingPathComponent(repositoryName, isDirectory: true)
        } + llamaPresetFilenames.map { presetFilename in
            llamaCacheURL.appendingPathComponent(presetFilename, isDirectory: false)
        }
    }

    private static func appSupportURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        return baseURL.appendingPathComponent(appSupportFolderName, isDirectory: true)
    }

    private static func remove(urls: [URL]) -> TextKitCleanupResult {
        var result = TextKitCleanupResult()
        let fileManager = FileManager.default

        for url in uniqueURLs(urls) {
            guard fileManager.fileExists(atPath: url.path) else {
                result.skippedURLs.append(url)
                continue
            }

            do {
                try fileManager.removeItem(at: url)
                result.removedURLs.append(url)
            } catch {
                result.errors.append("\(url.path): \(error.localizedDescription)")
            }
        }

        return result
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let standardizedPath = url.standardizedFileURL.path
            guard !seen.contains(standardizedPath) else { return false }
            seen.insert(standardizedPath)
            return true
        }
    }
}
