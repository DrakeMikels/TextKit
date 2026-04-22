import AppKit
import SwiftUI

@MainActor
final class InitialSetupWindowController: NSObject, NSWindowDelegate {
    weak var appModel: AppModel?

    private var window: NSWindow?

    func present() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        guard let appModel else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Set Up TextKit"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("TextKitInitialSetup")
        window.contentViewController = NSHostingController(
            rootView: InitialSetupWindowView(
                appModel: appModel,
                onDismiss: { [weak self] in
                    self?.close()
                }
            )
        )

        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
