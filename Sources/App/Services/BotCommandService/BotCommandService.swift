//
//  BotCommandService.swift
//
//
//  Created by Ivan Ipatov on 14.10.2023.
//

import Foundation

final class BotCommandService {

    private(set) var processCommand: String?
    private var shellCommand: ShellCommand?
    private var timer: Timer?

    var hasCommand: Bool {
        shellCommand != nil || shellCommand?.isRunning == true
    }

    /// Execute Git Commands
    func executeGitCommand(
        _ command: BotGitCommand,
        projectPath: String,
        branch: String,
        sendDocumentAction: ((_ filename: String, _ data: Data) -> Void)?,
        sendMessageAction: ((_ message: String) -> Void)?,
        completion: ((Swift.Result<String?, Error>) -> Void)?
    ) {
        if let processCommand {
            let error = BotError.processBusy(command: processCommand)
            sendMessageAction?(error.localizedDescription)
            completion?(.failure(error))
            return
        }
        guard let shellData = command.shellData(path: projectPath, branch: branch) else {
            let error = BotError.shellCommandsNotFound
            sendMessageAction?(error.localizedDescription)
            completion?(.failure(error))
            return
        }
        executeShellCommand(
            command.rawValue,
            shellData: shellData,
            sendDocumentAction: sendDocumentAction,
            sendMessageAction: sendMessageAction,
            completion: { [weak self] result in
                self?.disableProcess()
                completion?(result)
            }
        )
    }

    /// Execute Shell Commands
    func executeShellCommand(
        _ command: BotShellCommand,
        projectPath: String,
        sendDocumentAction: ((_ filename: String, _ data: Data) -> Void)?,
        sendMessageAction: ((_ message: String) -> Void)?,
        completion: ((Swift.Result<String?, Error>) -> Void)?
    ) {
        switch command {
        case .status:
            if let processCommand {
                let error = BotError.processBusy(command: processCommand)
                sendMessageAction?(error.localizedDescription)
            } else {
                let error = BotError.processesNotFound
                sendMessageAction?(error.localizedDescription)
            }
            completion?(.success((nil)))
        case .cancel:
            guard hasCommand else {
                let error = BotError.processesNotFound
                sendMessageAction?(error.localizedDescription)
                completion?(.failure(error))
                return
            }
            disableProcess()
            completion?(.success((nil)))
        case .upload, .terminalCommand:
            if let processCommand {
                let error = BotError.processBusy(command: processCommand)
                sendMessageAction?(error.localizedDescription)
                completion?(.failure(error))
                return
            }
            guard let shellData = command.shellData(path: projectPath) else {
                let error = BotError.shellCommandsNotFound
                sendMessageAction?(error.localizedDescription)
                completion?(.failure(error))
                return
            }
            executeShellCommand(
                command.rawValue,
                shellData: shellData,
                sendDocumentAction: sendDocumentAction,
                sendMessageAction: sendMessageAction,
                completion: { [weak self] result in
                    self?.disableProcess()
                    completion?(result)
                }
            )
        }
    }

    /// Execute Shell Commands
    private func executeShellCommand(
        _ command: String,
        shellData: (shellPath: String, args: [String]),
        sendDocumentAction: ((_ filename: String, _ data: Data) -> Void)?,
        sendMessageAction: ((_ message: String) -> Void)?,
        completion: ((Swift.Result<String?, Error>) -> Void)?
    ) {
        let startProcessMessage = "The \(command) command has started executing..."
        sendMessageAction?(startProcessMessage)

        let startDate = Date()

        processCommand = command
        shellCommand = ShellCommand(
            path: shellData.shellPath,
            args: shellData.args,
            password: nil
        )
        enableProcess()
        shellCommand?.run { [weak self] result in
            guard let self else {
                let error = BotError.somthingWrong
                sendMessageAction?(error.localizedDescription)
                completion?(.failure(error))
                return
            }
            let endDate = Date()
            switch result {
            case .success(let output):
                let totalTime = self.getProcessTotalTime(startDate: startDate, endDate: endDate)

                var outputData: Data?
                if let output, !output.data.isEmpty {
                    outputData = output.data
                }

                let message =
                """
                The \(command) command was executed successfully!
                \(outputData != nil ? "Attached file with logs output_log.txt" : "")
                -----------
                Total time taken: \(totalTime)
                -----------
                """

                sendMessageAction?(message)
                if let outputData {
                    sendDocumentAction?("output_log.txt", outputData)
                }
                completion?(.success((output?.text)))
            case .failure(let error):
                let totalTime = self.getProcessTotalTime(startDate: startDate, endDate: endDate)

                var outputData: Data?
                var errorData: Data?
                var finalError: Error
                let extraText: String

                switch error {
                case let .with(output, error, status):
                    extraText = "Status code: \(status)"
                    if let output, !output.data.isEmpty {
                        outputData = output.data
                    }
                    if let error, !error.data.isEmpty {
                        errorData = error.data
                    }
                    finalError = BotError.somthingWrong
                case .withError(let error):
                    finalError = error
                    extraText = finalError.localizedDescription
                case .canceled:
                    extraText = "The \(command) command was canceled!"
                    finalError = BotError.processCanceled
                case .`internal`:
                    finalError = BotError.somthingWrong
                    extraText = finalError.localizedDescription
                }

                let message =
                """
                The \(command) command was executed with an error:
                \(extraText)
                \(outputData != nil ? "Attached file with logs output_log.txt" : "")
                \(errorData != nil ? "Attached file with logs error_log.txt" : "")
                -----------
                Total time taken: \(totalTime)
                -----------
                """
                sendMessageAction?(message)
                if let outputData {
                    sendDocumentAction?("output_log.txt", outputData)
                }
                if let errorData {
                    sendDocumentAction?("error_log.txt", errorData)
                }
                completion?(.failure(error))
            }
            self.disableProcess()
        }
    }

    /// Inhibit desktop idleness while a command runs
    private func enableProcess() {
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
            let shellCommand = ShellCommand(
                path: "/bin/zsh",
                args: ["--login", "-c", "caffeinate -u -t 1"],
                password: nil
            )
            shellCommand.run { result in
                log("caffeinate command with result: \(result)")
            }
        }
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
    }

    private func disableProcess() {
        timer?.invalidate()
        timer = nil
        processCommand = nil
        shellCommand?.cancel()
        shellCommand = nil
    }

    private func getProcessTotalTime(startDate: Date, endDate: Date) -> String {
        let dateComponents = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: startDate,
            to: endDate
        )
        return "\(dateComponents.hour ?? 0)h \(dateComponents.minute ?? 0)m \(dateComponents.second ?? 0)s"
    }
}
