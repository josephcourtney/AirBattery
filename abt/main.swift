//
//  main.swift
//  abt
//
//  Created by apple on 2025/5/19.
//

import AirBatteryKit
import AppKit
import ArgumentParser
import Foundation

struct AirBatteryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(version: "0.1.0")

    @Flag(name: .shortAndLong, help: "Including Nearcast devices")
    var nearcast = false

    @Flag(name: .shortAndLong, help: "Print in JSON format")
    var json = false

    @Flag(name: .shortAndLong, help: "Print in CSV format")
    var csv = false

    mutating func validate() throws {
        guard [json, csv].filter({ $0 }).count <= 1 else {
            throw ValidationError("These options cannot be used together!")
        }
    }

    mutating func run() throws {
        requestFreshSnapshot()
        usleep(500_000)

        let items = AirBatteryCLI.items(includeNearcast: nearcast)
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            print(String(decoding: data, as: UTF8.self))
            return
        }

        var rows = items.map {
            "\($0.device)\t\(String(format: "%3d", $0.level))%\t\($0.status)"
        }
        rows.insert("Device\tLevel\tStatus", at: 0)

        if csv {
            print(rows.joined(separator: "\n").replacingOccurrences(of: "\t", with: ","))
            return
        }

        rows.insert("-------\t------\t-------", at: 1)
        try printTable(rows.joined(separator: "\n") + "\n")
    }

    private func requestFreshSnapshot() {
        guard let url = URL(string: "airbattery://writedata") else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(url, configuration: config)
    }

    private func printTable(_ input: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["column", "-t", "-s", "\t"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe

        try process.run()
        guard let data = input.data(using: .utf8) else {
            throw ValidationError("Unable to encode command output")
        }
        inputPipe.fileHandleForWriting.write(data)
        inputPipe.fileHandleForWriting.closeFile()

        let result = outputPipe.fileHandleForReading.readDataToEndOfFile()
        print(String(decoding: result, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

AirBatteryCommand.main()
