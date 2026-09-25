import Darwin
import Foundation

public struct ProcessExecutionResult {
    let output: String
    let terminationStatus: Int32
    let terminationReason: Process.TerminationReason
}

enum ProcessRunner {
    static func run(
        path: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> ProcessExecutionResult? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.environment = environment
        task.standardError = FileHandle.nullDevice

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        defer { outputPipe.fileHandleForReading.closeFile() }

        do {
            try task.run()
        } catch {
            print(error.localizedDescription)
            return nil
        }

        if let timeout, timeout > 0 {
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + timeout
            ) {
                guard task.isRunning else { return }
                task.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + 0.4
                ) {
                    guard task.isRunning else { return }
                    _ = Darwin.kill(task.processIdentifier, SIGKILL)
                }
            }
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        return ProcessExecutionResult(
            output: String(decoding: outputData, as: UTF8.self)
                .trimmingCharacters(in: .newlines),
            terminationStatus: task.terminationStatus,
            terminationReason: task.terminationReason
        )
    }
}

func processWithStatus(
    path: String,
    arguments: [String],
    timeout: Int = 0
) -> ProcessExecutionResult? {
    ProcessRunner.run(
        path: path,
        arguments: arguments,
        timeout: timeout > 0 ? TimeInterval(timeout) : nil
    )
}

func process(path: String, arguments: [String], timeout: Int = 0) -> String? {
    guard let result = ProcessRunner.run(
        path: path,
        arguments: arguments,
        timeout: timeout > 0 ? TimeInterval(timeout) : nil
    ), !result.output.isEmpty
    else {
        return nil
    }

    return result.output
}
