//
//  DefaultBotHandlers.swift
//
//
//  Created by Ivan Ipatov on 13.10.2023.
//

import Vapor
import TelegramVaporBot

final class DefaultBotHandlers {

    private static var messageProcesses: [MessageProcess] = []

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await baseHandler(app: app, connection: connection)
//        await messageHandler(app: app, connection: connection)
        await commandsHandler(app: app, connection: connection)
    }

    /// Handler for All
    private static func baseHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGBaseHandler { update, bot in
            guard BotCommand(rawValue: update.message?.text ?? "") == nil else { return }
            var messageProcess: MessageProcess?
            if let message = update.message, let user = message.from {
                messageProcess = messageProcesses.first { $0.userId == user.id }
            } else if let poll = update.poll {
                messageProcess = messageProcesses.first { $0.pollId == poll.id }
            }
            guard let messageProcess else { return }
            try await executeMessageProcess(
                process: messageProcess,
                update: update,
                bot: bot
            )
        }
        await connection.dispatcher.add(handler)
    }

//    /// Handler for Messages
//    private static func messageHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
//        let filters: TGFilter = (.all && !.command.names(BotCommand.allCommands))
//        let handler = TGMessageHandler(filters: filters) { update, bot in
//            log("messageHandler", update.message?.text ?? "nil")
//        }
//        await connection.dispatcher.add(handler)
//    }

    /// Handler for Main Commands
    private static func commandsHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        let handler = TGCommandHandler(commands: BotCommand.allCommands) { update, bot in
            guard let message = update.message, let user = message.from else { return }
            guard let command = BotCommand(rawValue: message.text ?? "") else { return }
            if !dependencies.botService.availableUser(chatId: user.id, username: user.username) {
                try await bot.sendMessage(params: .init(
                    chatId: .chat(user.id),
                    text: "Wait for confirmation"
                ))
                return
            }
            try await executeMessageProcess(
                process: .init(command: command, userId: user.id),
                update: update,
                bot: bot
            )
        }
        await connection.dispatcher.add(handler)
    }

    private static func executeMessageProcess(
        process: MessageProcess,
        update: TGUpdate,
        bot: TGBot
    ) async throws {
        switch process.command {
        case .start, .help:
            let text =
            """
            List of commands:
            /help, /start - see the list of commands
            /setconfig - change the current config
            /getconfig - display the current config

            Commands for interacting with git
            /gitcheckout - switch to a branch
            /gitfetch - fetch commits
            /gitpull - pull commits
            /gitdiscardall - discard all changes
            /gitstatus - check status

            Commands for interacting with project processes:
            /upload - archive builds in testflight
            /cancel - cancel the current process
            /status - get the status of the current process
            /terminalcommand - execute any command in the terminal
            """
            try await bot.sendMessage(params: .init(
                chatId: .chat(process.userId),
                text: text
            ))
        case let .setConfig(projectPath, _):
            switch process.step {
            case 0:
                process.step = 1
                if let index = (self.messageProcesses.firstIndex { $0 == process }) {
                    self.messageProcesses.remove(at: index)
                }
                self.messageProcesses.append(process)
                let buttons: [[TGKeyboardButton]] = [[
                    .init(text: "Share your phone number", requestContact: true)
                ]]
                let params: TGSendMessageParams = .init(
                    chatId: .chat(process.userId),
                    text: "Share your phone number for authorization",
                    replyMarkup: .replyKeyboardMarkup(.init(keyboard: buttons))
                )
                try await bot.sendMessage(params: params)
            case 1:
                guard let _ = update.message?.contact?.phoneNumber else {
                    return
                }
                process.step = 2
                let params: TGSendMessageParams = .init(
                    chatId: .chat(process.userId),
                    text: "Enter the path to the project:",
                    replyMarkup: .replyKeyboardRemove(.init(removeKeyboard: true))
                )
                try await bot.sendMessage(params: params)
            case 2:
                guard let projectPath = update.message?.text else {
                    return
                }
                process.command = .setConfig(projectPath: projectPath, targets: [])
                process.step = 3
                let params: TGSendMessageParams = .init(
                    chatId: .chat(process.userId),
                    text: "Enter the names of the targets, separating them with commas:",
                    replyMarkup: .replyKeyboardRemove(.init(removeKeyboard: true))
                )
                try await bot.sendMessage(params: params)
            case 3:
                guard let targetsString = update.message?.text else {
                    return
                }
                let targetsSplit = targetsString.condenseWhitespace().split(separator: ",")
                let targets = targetsSplit.map { String($0).condenseWhitespace() }
                process.command = .setConfig(projectPath: projectPath, targets: targets)
                dependencies.botService.config = .init(projectPath: projectPath, projectTargets: targets)
                self.messageProcesses.removeAll { $0 == process }
                try await executeMessageProcess(
                    process: .init(command: .help, userId: process.userId),
                    update: update,
                    bot: bot
                )
            default:
                let error = BotError.somthingWrong
                try await bot.sendMessage(params: .init(
                    chatId: .chat(process.userId),
                    text: error.localizedDescription
                ))
            }
        case .getConfig:
            let text =
            """
            Project config:
            Path: \(dependencies.botService.config.projectPath)
            Targets: \(dependencies.botService.config.projectTargets)
            """
            try await bot.sendMessage(params: .init(
                chatId: .chat(process.userId),
                text: text
            ))
        case .git(let botGitCommand):
            dependencies.botCommandService.executeGitCommand(
                botGitCommand,
                projectPath: dependencies.botService.config.projectPath,
                branch: "develop",
                sendDocumentAction: { (filename, document) in
                    dependencies.botService.sendDocument(params: .init(
                        chatId: .chat(process.userId),
                        document: .file(.init(
                            filename: filename,
                            data: document,
                            mimeType: document.mimeType
                        ))
                    ))
                },
                sendMessageAction: { text in
                    dependencies.botService.sendMessage(params: .init(
                        chatId: .chat(process.userId),
                        text: text
                    ))
                },
                completion: nil
            )
        case .shell(let botShellCommand):
            let availableShellProcess = {
                if let processCommand = dependencies.botCommandService.processCommand {
                    let error = BotError.processBusy(command: processCommand)
                    try await bot.sendMessage(params: .init(
                        chatId: .chat(process.userId),
                        text: error.localizedDescription
                    ))
                    return false
                }
                return true
            }
            let startShellProcess: (((Swift.Result<String?, Error>) -> Void)?) -> Void = { completion in
                dependencies.botCommandService.executeShellCommand(
                    botShellCommand,
                    projectPath: dependencies.botService.config.projectPath,
                    sendDocumentAction: { (filename, document) in
                        dependencies.botService.sendDocument(params: .init(
                            chatId: .chat(process.userId),
                            document: .file(.init(
                                filename: filename,
                                data: document,
                                mimeType: document.mimeType
                            ))
                        ))
                    },
                    sendMessageAction: { text in
                        dependencies.botService.sendMessage(params: .init(
                            chatId: .chat(process.userId),
                            text: text
                        ))
                    },
                    completion: { result in
                        completion?(result)
                    }
                )
            }
            if case .cancel = botShellCommand {
                messageProcesses.removeAll { $0 == process }
                if dependencies.botCommandService.hasCommand {
                    startShellProcess(nil)
                }
                dependencies.botService.sendMessage(params: .init(
                    chatId: .chat(process.userId),
                    text: "Local processes have been canceled",
                    replyMarkup: .replyKeyboardRemove(.init(removeKeyboard: true))
                ))
                return
            }
            switch botShellCommand {
            case let .upload(branch, targets, version):
                guard try await availableShellProcess() else { return }
                switch process.step {
                case 0:
                    process.step = 1
                    if let index = (self.messageProcesses.firstIndex { $0 == process }) {
                        self.messageProcesses.remove(at: index)
                    }
                    self.messageProcesses.append(process)
                    var params: TGSendMessageParams = .init(
                        chatId: .chat(process.userId),
                        text: "Enter a branch",
                        replyMarkup: .replyKeyboardRemove(.init(removeKeyboard: true))
                    )
                    let lastBranch = dependencies.botService.botSettings.lastUploadBranch
                    if !lastBranch.isEmpty {
                        let buttons: [[TGKeyboardButton]] = [[
                            .init(text: lastBranch)
                        ]]
                        params.replyMarkup = .replyKeyboardMarkup(.init(keyboard: buttons, resizeKeyboard: true))
                    }
                    try await bot.sendMessage(params: params)
                case 1:
                    guard let branch = update.message?.text else {
                        return
                    }
                    process.command = .shell(.upload(branch: branch, targets: [], version: ""))
                    process.step = 2
                    let buttons: [[TGKeyboardButton]] = [[
                        .init(text: "All targets")
                    ]]
                    let params: TGSendPollParams = .init(
                        chatId: .chat(process.userId),
                        question: "Select the targets you want to upload",
                        options: dependencies.botService.config.projectTargets,
                        allowsMultipleAnswers: true,
                        replyMarkup: .replyKeyboardMarkup(.init(keyboard: buttons, resizeKeyboard: true))
                    )
                    let message = try await bot.sendPoll(params: params)
                    process.pollId = message.poll?.id
                case 2:
                    let targets: [String]
                    if let poll = update.poll {
                        targets = poll.options.enumerated().compactMap {
                            $0.element.voterCount > 0 ? $0.element.text : nil
                        }
                    } else if update.message?.text == "All targets" {
                        targets = dependencies.botService.config.projectTargets
                    } else {
                        targets = []
                    }
                    guard !targets.isEmpty else {
                        return
                    }
                    process.command = .shell(.upload(branch: branch, targets: targets, version: ""))
                    process.step = 3
                    var params: TGSendMessageParams = .init(
                        chatId: .chat(process.userId),
                        text: "Enter the version and build. Example: 1.0 1",
                        replyMarkup: .replyKeyboardRemove(.init(removeKeyboard: true))
                    )
                    var nextVersion: String = ""
                    let lastVersion = dependencies.botService.botSettings.lastUploadVersion
                    if !lastVersion.isEmpty {
                        let versionSplit = lastVersion.split(separator: " ")
                        let version = versionSplit[0]
                        let build = Int(versionSplit[1]) ?? 0
                        nextVersion = "\(version) \(build + 1)"
                    }
                    if !nextVersion.isEmpty {
                        let buttons: [[TGKeyboardButton]] = [[
                            .init(text: nextVersion)
                        ]]
                        params.replyMarkup = .replyKeyboardMarkup(.init(keyboard: buttons, resizeKeyboard: true))
                    }
                    dependencies.botService.sendMessage(params: params)
                case 3:
                    guard let version = update.message?.text else {
                        return
                    }
                    process.command = .shell(.upload(branch: branch, targets: targets, version: version))
                    process.step = 4
                    let text =
                    """
                    Uploading info:
                    Targets: \(targets)
                    Version: \(version)
                    """
                    try await bot.sendMessage(params: .init(
                        chatId: .chat(process.userId),
                        text: text,
                        replyMarkup: .replyKeyboardRemove(.init(removeKeyboard: true))
                    ))
                    try await executeMessageProcess(
                        process: process,
                        update: update,
                        bot: bot
                    )
                case 4:
                    messageProcesses.removeAll { $0 == process }
                    startShellProcess { result in
                        switch result {
                        case .success:
                            dependencies.botService.botSettings.lastUploadBranch = branch
                            dependencies.botService.botSettings.lastUploadVersion = version
                        case .failure:
                            break
                        }
                    }
                default:
                    break
                }
            case .terminalCommand:
                guard try await availableShellProcess() else { return }
                switch process.step {
                case 0:
                    process.step = 1
                    if let index = (self.messageProcesses.firstIndex { $0 == process }) {
                        self.messageProcesses.remove(at: index)
                    }
                    self.messageProcesses.append(process)
                    let params: TGSendMessageParams = .init(
                        chatId: .chat(process.userId),
                        text: "Enter the command"
                    )
                    try await bot.sendMessage(params: params)
                case 1:
                    guard let command = update.message?.text else {
                        return
                    }
                    process.command = .shell(.terminalCommand(command))
                    process.step = 2
                    try await executeMessageProcess(
                        process: process,
                        update: update,
                        bot: bot
                    )
                case 2:
                    messageProcesses.removeAll { $0 == process }
                    startShellProcess(nil)
                default:
                    break
                }
            case .status, .cancel:
                startShellProcess(nil)
            }
        }
    }
}
