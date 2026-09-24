import Foundation

public struct ProcessExecutionResult {
    let output: String
    let terminationStatus: Int32
    let terminationReason: Process.TerminationReason
}

func processWithStatus(path: String, arguments: [String], timeout: Int = 0) -> ProcessExecutionResult? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments

    let errorPipe = Pipe()
    let outputPipe = Pipe()
    task.standardError = errorPipe
    task.standardOutput = outputPipe

    defer {
        errorPipe.fileHandleForReading.closeFile()
        outputPipe.fileHandleForReading.closeFile()
    }

    if timeout != 0 {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout)) {
            if task.isRunning {
                task.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(400)) {
                    if task.isRunning {
                        task.interrupt()
                    }
                }
            }
        }
    }

    do {
        try task.run()
    } catch {
        print(error.localizedDescription)
        return nil
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

func process(path: String, arguments: [String], timeout: Int = 0) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    task.standardError = Pipe()

    let outputPipe = Pipe()
    defer { outputPipe.fileHandleForReading.closeFile() }
    task.standardOutput = outputPipe

    if timeout != 0 {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout)) {
            if task.isRunning {
                task.terminate()
                // Escalate if still running shortly after terminate
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(400)) {
                    if task.isRunning {
                        let pid = task.processIdentifier
                        _ = process(path: "/bin/kill", arguments: ["-9", String(pid)], timeout: 1)
                    }
                }
            }
        }
    }

    do {
        try task.run()
    } catch let error {
        print("\(error.localizedDescription)")
        return nil
    }

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: outputData, as: UTF8.self)

    if output.isEmpty { return nil }

    return output.trimmingCharacters(in: .newlines)
}
