import Foundation
import Darwin

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

        var environment: [String: String] = [runtimeRootKey: runtimeRootURL.path]

        if let backendPath = preferredBackendLibraryURL(in: runtimeRootURL)?.path {
            environment[backendPathKey] = backendPath
        }

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

    static func preferredBackendFilenames(cpuBrand: String?) -> [String] {
        let normalizedBrand = (cpuBrand ?? "").lowercased()

        if normalizedBrand.contains("m4") {
            return [
                "libggml-cpu-apple_m4.so",
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m1.so"
            ]
        }

        if normalizedBrand.contains("m3") || normalizedBrand.contains("m2") {
            return [
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m1.so",
                "libggml-cpu-apple_m4.so"
            ]
        }

        return [
            "libggml-cpu-apple_m1.so",
            "libggml-cpu-apple_m2_m3.so",
            "libggml-cpu-apple_m4.so"
        ]
    }

    private static func preferredBackendLibraryURL(in runtimeRootURL: URL) -> URL? {
        let backendsURL = runtimeRootURL.appendingPathComponent("backends", isDirectory: true)
        let fileManager = FileManager.default

        for filename in preferredBackendFilenames(cpuBrand: currentCPUBrand()) {
            let candidateURL = backendsURL.appendingPathComponent(filename, isDirectory: false)
            if fileManager.isReadableFile(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return nil
    }

    private static func currentCPUBrand() -> String? {
        var size: size_t = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
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
