import AppKit
import Testing
@testable import TextKit

struct ClipboardMonitorTests {
    @Test
    @MainActor
    func managedPasteboardItemCarriesSourceMarker() {
        let item = ClipboardMonitor.makeManagedPasteboardItem(text: "Hello")

        #expect(item.string(forType: .string) == "Hello")
        #expect(ClipboardMonitor.isManagedPasteboardItem(item))
    }
}
