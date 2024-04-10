//
//  ShellCommands.swift
//
//
//  Created by Ivan Ipatov on 13.10.2023.
//

import Foundation

func shell(path: String, args: [String]) throws -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = args
    task.executableURL = URL(fileURLWithPath: path)
    task.standardInput = nil

    try task.run()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

func getShell(path: String, args: [String]) -> (process: Process, pipe: Pipe) {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = args
    task.executableURL = URL(fileURLWithPath: path)
    task.standardInput = nil

    return (task, pipe)
}

final class ShellCommand {

    private let path: String
    private var args: [String]
    private let password: String?

    private var process = Process()
    private var inputProcess: Process?
    private var inputPipe: Pipe?
    private var outputPipe = Pipe()
    private var errorPipe = Pipe()

    private var wasCancelledManually: Bool = false

    var isRunning: Bool {
        process.isRunning
    }

    init(path: String, args: [String], password: String?) {
        self.path = path
        self.args = args
        self.password = password
    }

    func run(completion: @escaping (Swift.Result<(text: String, data: Data)?, ShellCommandError>) -> Void) {
        process = Process()
        inputProcess = password == nil ? nil : Process()
        inputPipe = password == nil ? nil : Pipe()
        outputPipe = Pipe()
        errorPipe = Pipe()
        wasCancelledManually = false

        var inputText: String = ""
        var outputText: String = ""
        var errorText: String = ""

        log("""
        🚀 [ShellCommand] Run command.
        ✴️ [ShellCommand] Arguments: \(self.args)
        ✴️ [ShellCommand] Path: \(self.path)
        """)

        inputPipe?.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            var input = String(data: data, encoding: .utf8) ?? ""
            input = input.trimmingCharacters(in: .newlines)
            inputText += "\n\(input)"
            log(input)
        }
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            var output = String(data: data, encoding: .utf8) ?? ""
            output = output.trimmingCharacters(in: .newlines)
            outputText += "\n\(output)"
            log(output)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            var error = String(data: data, encoding: .utf8) ?? ""
            error = error.trimmingCharacters(in: .newlines)
            errorText += "\n\(error)"
            log(error)
        }
        process.terminationHandler = { [weak self] process in
            guard let self else { 
                log("❌ [ShellCommand] Command was executed with internal error")
                completion(.failure(.`internal`))
                return
            }
            guard !wasCancelledManually else {
                log("❌ [ShellCommand] The process has been canceled")
                completion(.failure(.canceled))
                return
            }
            let status = process.terminationStatus

            var outputResponse: (text: String, data: Data)?
            if let outputData = outputText.data(using: .utf8) {
                outputResponse = (outputText, outputData)
            }

            if status == 0 {
                log("✅ [ShellCommand] Command was executed successfully")
                completion(.success(outputResponse))
            } else {
                var errorResponse: (text: String, data: Data)?
                if let errorData = errorText.data(using: .utf8) {
                    errorResponse = (errorText, errorData)
                }
                log("❌ [ShellCommand] Command was executed with an error")
                completion(.failure(.with(
                    output: outputResponse,
                    error: errorResponse,
                    status: status
                )))
            }
        }
        do {
            if let password, let inputProcess, let inputPipe {
                inputProcess.executableURL = URL(fileURLWithPath: "/bin/echo")
                inputProcess.arguments = [password]
                inputProcess.standardOutput = inputPipe
                process.executableURL = URL(fileURLWithPath: self.path)
                process.arguments = self.args
                process.standardInput = inputPipe
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                try inputProcess.run()
                try process.run()
            } else {
                process.executableURL = URL(fileURLWithPath: self.path)
                process.arguments = self.args
                process.standardInput = nil
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                try process.run()
            }
        } catch {
            log("❌ [ShellCommand] Command was executed with an error")
            completion(.failure(.withError(error: error)))
        }
    }

    func cancel() {
        wasCancelledManually = true
        process.terminate()
    }
}

enum ShellCommandError: Swift.Error {
    case with(output: (text: String, data: Data)?, error: (text: String, data: Data)?, status: Int32)
    case withError(error: Error)
    case canceled
    case `internal`
}
