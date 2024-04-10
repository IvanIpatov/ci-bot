//
//  File.swift
//  
//
//  Created by Ivan Ipatov on 09.04.2024.
//

import Foundation

let dependencies: Dependencies = Dependencies()

struct Dependencies {

    let storageService: StorageServiceProtocol
    let botService: BotService
    let botCommandService: BotCommandService

    init() {
        storageService = StorageService()
        botService = BotService(storageService: storageService)
        botCommandService = BotCommandService()
    }
}
