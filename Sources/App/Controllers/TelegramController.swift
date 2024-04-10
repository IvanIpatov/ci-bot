//
//  TelegramController.swift
//
//
//  Created by Ivan Ipatov on 13.10.2023.
//

import Vapor

final class TelegramController: RouteCollection {

    func boot(routes: Vapor.RoutesBuilder) throws {
        routes.post("telegramWebHook", use: telegramWebHook)
    }
}

extension TelegramController {

    func telegramWebHook(_ req: Request) async throws -> Bool {
        try await dependencies.botService.telegramWebHook(req)
    }
}
