import Foundation
import Sparkle

@MainActor
final class UpdateService: NSObject {
    private let updaterController: SPUStandardUpdaterController
    private var hasStarted = false

    override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var isConfigured: Bool {
        hasStarted ? updaterController.updater.canCheckForUpdates : true
    }

    func start() {
        guard !hasStarted else { return }
        updaterController.startUpdater()
        hasStarted = true
    }

    func checkForUpdates() {
        start()
        updaterController.checkForUpdates(nil)
    }
}
