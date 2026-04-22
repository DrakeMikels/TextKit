import AppKit
import Foundation

@MainActor
final class ClipboardMonitor: NSObject {
    static let sourcePasteboardType = NSPasteboard.PasteboardType("com.mikedrake.TextKit.source")
    static let sourcePasteboardValue = "generated-output"

    private let pasteboard: NSPasteboard
    private let pollInterval: TimeInterval

    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastText: String?
    private var onClipboardText: (@MainActor (String) -> Void)?

    init(
        pasteboard: NSPasteboard = .general,
        pollInterval: TimeInterval = 0.5
    ) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.lastChangeCount = pasteboard.changeCount
        self.lastText = pasteboard.string(forType: .string)
        super.init()
    }

    func start(onClipboardText: @escaping @MainActor (String) -> Void) {
        guard timer == nil else { return }
        self.onClipboardText = onClipboardText

        timer = Timer.scheduledTimer(
            timeInterval: pollInterval,
            target: self,
            selector: #selector(pollPasteboard),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onClipboardText = nil
    }

    static func makeManagedPasteboardItem(text: String) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setString(sourcePasteboardValue, forType: sourcePasteboardType)
        return item
    }

    static func isManagedPasteboardItem(_ item: NSPasteboardItem) -> Bool {
        item.string(forType: sourcePasteboardType) == sourcePasteboardValue
    }

    @objc
    private func pollPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        if pasteboard.pasteboardItems?.contains(where: Self.isManagedPasteboardItem) == true {
            return
        }

        guard let clipboardText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !clipboardText.isEmpty,
            clipboardText != lastText
        else {
            return
        }

        lastText = clipboardText
        onClipboardText?(clipboardText)
    }
}
