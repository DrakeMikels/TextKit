import AppKit
import SwiftUI

private enum PopoverActivation {
    static let maxAttempts = 5
    static let retryDelay: TimeInterval = 0.025
}

@MainActor
final class TextKitAppDelegate: NSObject, NSApplicationDelegate {
    private static var configuredAppModel: AppModel?

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var hostingController: NSHostingController<ContentView>?
    private var pendingPopoverShowWorkItem: DispatchWorkItem?

    static func configure(appModel: AppModel) {
        configuredAppModel = appModel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let appModel = Self.configuredAppModel else {
            assertionFailure("AppModel must be configured before launch")
            return
        }

        NSApplication.shared.applicationIconImage = AppIconProvider.applicationIconImage()
        configureStatusItem()
        configurePopover(appModel: appModel)
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = AppIconProvider.menuBarImage()
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "TextKit"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        self.statusItem = statusItem
    }

    private func configurePopover(appModel: AppModel) {
        let hostingController = NSHostingController(rootView: ContentView(appModel: appModel))
        self.hostingController = hostingController

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 512, height: 720)
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown || pendingPopoverShowWorkItem != nil {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard
            let button = statusItem?.button,
            let hostingController
        else { return }

        requestPopoverActivation()
        presentPopoverWhenActive(
            from: button,
            controller: hostingController,
            remainingAttempts: PopoverActivation.maxAttempts
        )
    }

    private func closePopover() {
        pendingPopoverShowWorkItem?.cancel()
        pendingPopoverShowWorkItem = nil
        statusItem?.button?.highlight(false)
        popover.performClose(nil)
    }

    private func requestPopoverActivation() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate()
    }

    private func presentPopoverWhenActive(
        from button: NSStatusBarButton,
        controller: NSHostingController<ContentView>,
        remainingAttempts: Int
    ) {
        pendingPopoverShowWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self, weak button] in
            guard let self, let button else { return }

            if !(NSRunningApplication.current.isActive || NSApp.isActive), remainingAttempts > 0 {
                self.requestPopoverActivation()
                self.presentPopoverWhenActive(
                    from: button,
                    controller: controller,
                    remainingAttempts: remainingAttempts - 1
                )
                return
            }

            self.pendingPopoverShowWorkItem = nil
            controller.view.layoutSubtreeIfNeeded()
            let fittingSize = controller.view.fittingSize
            let width = max(512, fittingSize.width)
            let height = min(max(620, fittingSize.height), 780)
            self.popover.contentSize = NSSize(width: width, height: height)
            button.highlight(true)
            self.popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            self.popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }

        pendingPopoverShowWorkItem = workItem
        let delay = remainingAttempts == PopoverActivation.maxAttempts ? 0.0 : PopoverActivation.retryDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

extension TextKitAppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
    }
}
