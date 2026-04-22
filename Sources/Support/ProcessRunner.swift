import Foundation

struct ProcessResult {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String
}

enum ProcessRunnerError: LocalizedError {
    case launchFailed(String)
    case nonZeroExit(command: String, code: Int32, stdout: String, stderr: String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return "Failed to launch process: \(message)"
        case let .nonZeroExit(command, code, _, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "\(command) exited with status \(code)." : "\(command) exited with status \(code): \(trimmed)"
        }
    }
}

enum ProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) async throws -> ProcessResult {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(
                "textkit-\(UUID().uuidString)",
                isDirectory: true
            )

            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDirectory) }

            let stdoutURL = tempDirectory.appendingPathComponent("stdout.txt")
            let stderrURL = tempDirectory.appendingPathComponent("stderr.txt")

            fileManager.createFile(atPath: stdoutURL.path, contents: nil)
            fileManager.createFile(atPath: stderrURL.path, contents: nil)

            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdoutHandle.close()
                try? stderrHandle.close()
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            var mergedEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                mergedEnvironment[key] = value
            }
            process.environment = mergedEnvironment

            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.launchFailed(error.localizedDescription)
            }

            process.waitUntilExit()

            try stdoutHandle.close()
            try stderrHandle.close()

            let stdout = String(decoding: try Data(contentsOf: stdoutURL), as: UTF8.self)
            let stderr = String(decoding: try Data(contentsOf: stderrURL), as: UTF8.self)
            let result = ProcessResult(
                terminationStatus: process.terminationStatus,
                stdout: stdout,
                stderr: stderr
            )

            if result.terminationStatus == 0 {
                return result
            }

            throw ProcessRunnerError.nonZeroExit(
                command: ([executableURL.path] + arguments).joined(separator: " "),
                code: result.terminationStatus,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }.value
    }
}
