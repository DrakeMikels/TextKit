import Foundation
@testable import TextKit
import Testing

struct TextKitCleanupManagerTests {
    @Test
    func appOwnedModelDataUsesApplicationSupportCache() {
        let appSupportURL = URL(fileURLWithPath: "/tmp/TextKit", isDirectory: true)
        let xdgCacheURL = appSupportURL.appendingPathComponent("xdg-cache", isDirectory: true)
        let activeXDGCacheURL = URL(fileURLWithPath: "/Volumes/SSD/Dev Projects/TextKit/.tmp/xdg-cache", isDirectory: true)

        let urls = TextKitCleanupManager.appOwnedModelDataURLs(
            appSupportURL: appSupportURL,
            xdgCacheURL: xdgCacheURL,
            activeXDGCacheURL: activeXDGCacheURL
        )

        #expect(urls.contains(xdgCacheURL))
        #expect(urls.contains(activeXDGCacheURL))
    }

    @Test
    func appOwnedModelDataDoesNotTargetArbitraryXDGCache() {
        let appSupportURL = URL(fileURLWithPath: "/tmp/TextKit", isDirectory: true)
        let xdgCacheURL = appSupportURL.appendingPathComponent("xdg-cache", isDirectory: true)
        let arbitraryXDGCacheURL = URL(fileURLWithPath: "/Users/example/.cache", isDirectory: true)

        let urls = TextKitCleanupManager.appOwnedModelDataURLs(
            appSupportURL: appSupportURL,
            xdgCacheURL: xdgCacheURL,
            activeXDGCacheURL: arbitraryXDGCacheURL
        )

        #expect(!urls.contains(arbitraryXDGCacheURL))
    }

    @Test
    func legacyModelDataTargetsOnlyTextKitModelRepositories() {
        let urls = TextKitCleanupManager.legacyModelDataURLs(
            homeURL: URL(fileURLWithPath: "/Users/example", isDirectory: true)
        )
        let paths = urls.map(\.path)

        #expect(paths.contains("/Users/example/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF"))
        #expect(paths.contains("/Users/example/.cache/huggingface/hub/models--AaryanK--Qwen3.5-0.8B-GGUF"))
        #expect(paths.contains("/Users/example/Library/Caches/llama.cpp/Qwen_Qwen2.5-0.5B-Instruct-GGUF_preset.ini"))
        #expect(!paths.contains("/Users/example/.cache/huggingface"))
    }
}
