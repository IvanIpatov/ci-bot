//
//  MessageProcess.swift
//  
//
//  Created by Ivan Ipatov on 16.10.2023.
//

import Foundation

public class MessageProcess {

    public var command: BotCommand
    public var step: Int
    public var userId: Int64
    public var pollId: String?

    public init(command: BotCommand, step: Int = 0, userId: Int64, pollId: String? = nil) {
        self.command = command
        self.step = step
        self.userId = userId
        self.pollId = pollId
    }
}

extension MessageProcess: Equatable {

    public static func == (lhs: MessageProcess, rhs: MessageProcess) -> Bool {
        lhs.userId == rhs.userId ||
        ((lhs.pollId != nil || rhs.pollId != nil) && lhs.pollId == rhs.pollId)
    }
}
