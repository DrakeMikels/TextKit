import AppKit
import SwiftUI

@main
struct TextKitApp: App {
    @NSApplicationDelegateAdaptor(TextKitAppDelegate.self) private var appDelegate
    @State private var appModel: AppModel
    private let initialSetupWindowController: InitialSetupWindowController

    init() {
        let appModel = AppModel()
        TextKitAppDelegate.configure(appModel: appModel)

        let initialSetupWindowController = InitialSetupWindowController()
        initialSetupWindowController.appModel = appModel
        appModel.configureInitialSetupWindowPresentation { [weak initialSetupWindowController] in
            initialSetupWindowController?.present()
        }

        self._appModel = State(initialValue: appModel)
        self.initialSetupWindowController = initialSetupWindowController
    }

    var body: some Scene {
        Settings {
            SettingsView(
                settingsStore: appModel.settingsStore,
                modelManager: appModel.modelManager,
                setupManager: appModel.setupManager,
                startSetup: appModel.startSetup,
                runDebugEvaluation: { inputText, refineInstruction, mode in
                    try await appModel.runDebugEvaluation(
                        inputText: inputText,
                        refineInstruction: refineInstruction,
                        mode: mode
                    )
                }
            )
        }
        .defaultSize(width: 760, height: 720)
    }
}
