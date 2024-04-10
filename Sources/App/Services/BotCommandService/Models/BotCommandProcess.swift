//
//  BotCommandProcess.swift
//
//
//  Created by Ivan Ipatov on 14.10.2023.
//

import Foundation

public struct BotCommandProcess {

    public var state: BotCommandProcess.State
    public let startDate: TimeInterval
    public var endDate: TimeInterval?
}

public extension BotCommandProcess {

    enum State {
        case none
        case executing
        case success
        case failure

        public var isExecuting: Bool {
            self == .executing
        }
    }
}
