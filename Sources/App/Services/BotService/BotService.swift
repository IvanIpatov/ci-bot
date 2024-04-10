//
//  File.swift
//  
//
//  Created by Ivan Ipatov on 14.10.2023.
//

import Foundation
import Vapor
import TelegramVaporBot
import Dispatch

public class BotService {

    private let storageService: StorageServiceProtocol

	private var timer: DispatchSourceTimer?
    private var inProgressReconnection: Bool = false

    public let botId: String = "my_token"

    private static let defaultConfig = Config(
        projectPath: "~/documents/my-app",
        projectTargets: ["MyTarget1", "MyTarget2"]
    )
    private static let defaultBotSettings = BotSettings(
        lastUploadBranch: "master",
        lastUploadVersion: "1.0 1"
    )

    public var config: Config {
        get { storageService.readData(forKey: "config") ?? BotService.defaultConfig }
        set { storageService.storeData(newValue, forKey: "config") }
    }
    public var botSettings: BotSettings {
        get { storageService.readData(forKey: "bot_settigns") ?? BotService.defaultBotSettings }
        set { storageService.storeData(newValue, forKey: "bot_settigns") }
    }

    public var users: [UserModel]? {
        get { storageService.readData(forKey: "users") }
        set { storageService.storeData(newValue, forKey: "users") }
    }

    private let TGBOT: TGBotConnection = .init()

    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }

    public func startConnection(app: Application) async throws {
        TGBot.log.logLevel = app.logger.logLevel
        let bot: TGBot = .init(app: app, botId: botId)
        await TGBOT.setConnection(try await TGLongPollingConnection(bot: bot))
    //    await TGBOT.setConnection(try await TGWebHookConnection(bot: bot, webHookURL: "https://your_domain/telegramWebHook"))
        await DefaultBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
        try await TGBOT.connection.start()
        try await setCommands()
        startHandlingConnection()
    }

    public func telegramWebHook(_ req: Request) async throws -> Bool {
        let update: TGUpdate = try req.content.decode(TGUpdate.self)
        return try await TGBOT.connection.dispatcher.process([update])
    }

    private func setCommands() async throws {
        let commands: [TGBotCommand] = [
            .init(command: "/upload", description: "archive builds in testflight"),
            .init(command: "/cancel", description: "cancel the current process"),
            .init(command: "/status", description: "get the status of the current process"),
            .init(command: "/gitpull", description: "pull commits"),
            .init(command: "/gitdiscardall", description: "discard all changes"),
            .init(command: "/gitstatus", description: "check git status"),
            .init(command: "/help", description: "see the list of commands"),
        ]
        let params: TGSetMyCommandsParams = .init(commands: commands)
        try await TGBOT.connection.bot.setMyCommands(params: params)
    }

    func availableUser(chatId: Int64, username: String?) -> Bool {
        let users = users
        if let user = users?.first(where: { $0.id == chatId }) {
            return user.isAvailable
        } else {
            let user = UserModel(id: chatId, username: username, isAvailable: false)
            var users = users ?? []
            users.append(user)
            self.users = users
            return false
        }
    }

    func sendMessage(params: TGSendMessageParams) {
        Task(priority: .medium) {
            do {
                try await TGBOT.connection.bot.sendMessage(params: params)
            } catch {
                log("""
                ❌ [BotService] Send message with failure: \(error.localizedDescription)
                """)
            }
        }
    }

    func sendDocument(params: TGSendDocumentParams) {
        Task(priority: .medium) {
            do {
                try await TGBOT.connection.bot.sendDocument(params: params)
            } catch {
                log("""
                ❌ [BotService] Send document with failure: \(error.localizedDescription)
                """)
            }
        }
    }
}

// MARK: - Reconnection
extension BotService {

    private func startHandlingConnection() {
        stopHandlingConnection()
        log("""
        🚀 [BotService] Handling: start handling
        """)
        timer = DispatchSource.makeTimerSource()
        timer?.setEventHandler() {
            guard !self.inProgressReconnection else { return }
            let _ = Task {
                do {
                    try await self.TGBOT.connection.bot.getMe()
                    log("""
                    ✅ [BotService] Handling: handling with success
                    """)
                } catch {
                    log("""
                    ❌ [BotService] Handling: handling with failure \(error.localizedDescription)
                    """)
                    try await self.reconnect()
                }
            }
        }
        timer?.schedule(deadline: .now() + .seconds(15), repeating: .seconds(15))
        timer?.activate()
    }

    private func stopHandlingConnection() {
        timer?.cancel()
        timer = nil
        log("""
        🚀 [BotService] Handling: finished handling
        """)
    }

    private func reconnect() async throws {
        log("""
        🚀 [BotService] Reconnect: start reconnect
        """)
        guard !inProgressReconnection else { return }
        inProgressReconnection = true
        stopHandlingConnection()
        do {
            try await TGBOT.connection.start()
            log("""
            ✅ [BotService] Reconnect: reconnect with success
            """)
        } catch {
            log("""
            ❌ [BotService] Reconnect: with failure \(error.localizedDescription)
            """)
        }
        startHandlingConnection()
        inProgressReconnection = false
    }
}
