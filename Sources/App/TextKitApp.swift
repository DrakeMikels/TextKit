import AppKit
import SwiftUI

@main
struct TextKitApp: App {
    @State private var appModel: AppModel
    private let initialSetupWindowController: InitialSetupWindowController

    init() {
        let appModel = AppModel()
        let initialSetupWindowController = InitialSetupWindowController()
        initialSetupWindowController.appModel = appModel
        appModel.configureInitialSetupWindowPresentation { [weak initialSetupWindowController] in
            initialSetupWindowController?.present()
        }

        NSApp.applicationIconImage = AppIconProvider.applicationIconImage()

        self._appModel = State(initialValue: appModel)
        self.initialSetupWindowController = initialSetupWindowController
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(appModel: appModel)
        } label: {
            Image(nsImage: AppIconProvider.menuBarImage())
                .help("TextKit")
        }
        .menuBarExtraStyle(.window)

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
