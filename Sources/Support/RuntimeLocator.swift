import Foundation

enum RuntimeLocator {
    private static let runtimeRootKey = "TEXTKIT_RUNTIME_ROOT"
    private static let backendPathKey = "GGML_BACKEND_PATH"

    static func executableURL(named executable: String) -> URL? {
        if let runtimeRootURL = runtimeRootURL() {
            let bundledExecutableURL = runtimeRootURL
                .appendingPathComponent("bin", isDirectory: true)
                .appendingPathComponent(executable, isDirectory: false)

            if FileManager.default.isExecutableFile(atPath: bundledExecutableURL.path) {
                return bundledExecutableURL
            }
        }

        let defaultPaths = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)"
        ]

        for path in defaultPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in environmentPath.split(separator: ":") {
            let candidatePath = String(directory) + "/" + executable
            if FileManager.default.isExecutableFile(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath)
            }
        }

        return nil
    }

    static func processEnvironment() -> [String: String] {
        guard let runtimeRootURL = runtimeRootURL() else {
            return [:]
        }

        let binPath = runtimeRootURL.appendingPathComponent("bin", isDirectory: true).path
        let libPath = runtimeRootURL.appendingPathComponent("lib", isDirectory: true).path
        let backendPath = runtimeRootURL.appendingPathComponent("backends", isDirectory: true).path

        var environment: [String: String] = [
            runtimeRootKey: runtimeRootURL.path,
            backendPathKey: backendPath
        ]

        environment["PATH"] = prepend(path: binPath, to: ProcessInfo.processInfo.environment["PATH"])
        environment["DYLD_LIBRARY_PATH"] = prepend(path: libPath, to: ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"])
        environment["DYLD_FALLBACK_LIBRARY_PATH"] = prepend(path: libPath, to: ProcessInfo.processInfo.environment["DYLD_FALLBACK_LIBRARY_PATH"])

        return environment
    }

    private static func runtimeRootURL() -> URL? {
        let fileManager = FileManager.default
        let processEnvironment = ProcessInfo.processInfo.environment

        if let environmentPath = processEnvironment[runtimeRootKey], !environmentPath.isEmpty {
            let environmentURL = URL(fileURLWithPath: environmentPath, isDirectory: true)
            if fileManager.fileExists(atPath: environmentURL.path) {
                return environmentURL
            }
        }

        if let resourceURL = Bundle.main.resourceURL {
            let bundledURL = resourceURL.appendingPathComponent("Runtime", isDirectory: true)
            if fileManager.fileExists(atPath: bundledURL.path) {
                return bundledURL
            }
        }

        return nil
    }

    private static func prepend(path: String, to existingValue: String?) -> String {
        guard let existingValue, !existingValue.isEmpty else {
            return path
        }

        if existingValue.split(separator: ":").contains(Substring(path)) {
            return existingValue
        }

        return path + ":" + existingValue
    }
}
