//
//  BotError.swift
//  
//
//  Created by Ivan Ipatov on 14.10.2023.
//

import Foundation

public enum BotError: Error, LocalizedError {

    case commandNotFound(command: String)
    case processesNotFound
    case processBusy(command: String)
    case processCanceled
    case shellCommandsNotFound
    case somthingWrong

    public var errorDescription: String? {
        switch self {
        case .commandNotFound(let command):
            NSLocalizedString("Command \(command) not found", comment: "")
        case .processesNotFound:
            NSLocalizedString("No processes found", comment: "")
        case .processBusy(let command):
            NSLocalizedString("Busy with the \(command) process. To cancel the current process, call the /cancel command", comment: "")
        case .processCanceled:
            NSLocalizedString("The process has been canceled", comment: "")
        case .shellCommandsNotFound:
            NSLocalizedString("No commands found for this process", comment: "")
        case .somthingWrong:
            NSLocalizedString("Something went wrong", comment: "")
        }
    }
}
