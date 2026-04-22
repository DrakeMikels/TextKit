import SwiftUI

@main
struct TextKitApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("TextKit", systemImage: "text.quote") {
            ContentView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                settingsStore: appModel.settingsStore,
                modelManager: appModel.modelManager,
                setupManager: appModel.setupManager,
                startSetup: appModel.startSetup
            )
        }
        .defaultSize(width: 760, height: 720)
    }
}
