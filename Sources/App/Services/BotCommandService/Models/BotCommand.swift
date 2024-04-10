//
//  BotCommand.swift
//
//
//  Created by Ivan Ipatov on 14.10.2023.
//

import Foundation

public enum BotCommand {
    case start
    case help
    case setConfig(projectPath: String, targets: [String])
    case getConfig
    case git(BotGitCommand)
    case shell(BotShellCommand)

    public var rawValue: String {
        switch self {
        case .start: "/start"
        case .help: "/help"
        case .setConfig: "/setconfig"
        case .getConfig: "/getconfig"
        case .git(let command): command.rawValue
        case .shell(let command): command.rawValue
        }
    }

    public static var allCases: [Self] {
        allMainCases +
        BotGitCommand.allCases.map { BotCommand.git($0) } +
        BotShellCommand.allCases.map { BotCommand.shell($0) }
    }

    public static var allCommands: [String] {
        allCases.map { $0.rawValue }
    }

    public static var allMainCases: [Self] {
        [.start, .help, .setConfig(projectPath: "", targets: []), .getConfig]
    }

    public static var allMainCommands: [String] {
        allMainCases.map { $0.rawValue }
    }

    public init?(rawValue: String) {
        if let command = BotGitCommand(rawValue: rawValue) {
            self = .git(command)
        } else if let command = BotShellCommand(rawValue: rawValue) {
            self = .shell(command)
        } else if let command = (BotCommand.allMainCases.first { $0.rawValue == rawValue }) {
            self = command
        } else {
            return nil
        }
    }
}

public enum BotGitCommand: CaseIterable {
    case checkout
    case fetch
    case pull
    case status
    case discardAll

    public init?(rawValue: String) {
        guard let value = (Self.allCases.first { $0.rawValue.lowercased() == rawValue.lowercased() }) else {
            return nil
        }
        self = value
    }

    public var rawValue: String {
        switch self {
        case .checkout:
            "/gitcheckout"
        case .fetch:
            "/gitfetch"
        case .pull:
            "/gitpull"
        case .status:
            "/gitstatus"
        case .discardAll:
            "/gitdiscardall"
        }
    }

    public static var allCases: [Self] {
        [.checkout, .fetch, .pull, .status, .discardAll]
    }

    public static var allCommands: [String] {
        Self.allCases.map { $0.rawValue }
    }

    public func shellData(path: String, branch: String) -> (shellPath: String, args: [String])? {
        let shellPath = "/bin/zsh"
        var args: [String] = ["--login", "-c"]
        switch self {
        case .checkout:
            args += ["cd \(path); git checkout \(branch);"]
            return (shellPath, args)
        case .fetch:
            args += ["cd \(path); git fetch origin \(branch);"]
            return (shellPath, args)
        case .pull:
            args += ["cd \(path); git pull origin \(branch);"]
            return (shellPath, args)
        case .status:
            args += ["cd \(path); git status;"]
            return (shellPath, args)
        case .discardAll:
            args += ["cd \(path); git restore .;"]
            return (shellPath, args)
        }
    }
}

public enum BotShellCommand {
    case upload(branch: String, targets: [String], version: String)
    case status
    case cancel
    case terminalCommand(String)

    public var rawValue: String {
        switch self {
        case .upload: "/upload"
        case .status: "/status"
        case .cancel: "/cancel"
        case .terminalCommand: "/terminalcommand"
        }
    }

    public static var allCases: [Self] {
        [
            .upload(branch: "", targets: [], version: ""),
            .status, .cancel, .terminalCommand("")
        ]
    }

    public static var allCommands: [String] {
        allCases.map { $0.rawValue }
    }

    public init?(rawValue: String) {
        guard let command = (Self.allCases.first { $0.rawValue == rawValue }) else {
            return nil
        }
        self = command
    }

    public func shellData(path: String) -> (shellPath: String, args: [String])? {
        let shellPath = "/bin/zsh"
        var args: [String] = ["--login", "-c"]
        var command: String = "caffeinate -u -t 1; "
        switch self {
        case let .upload(branch, targets, version):
            let targetsString = targets.reduce("") { result, value in
                result.isEmpty ? value : result + " \(value)"
            }
            command += "cd \(path)/ci_scripts; sh ci_upload.sh \(branch) \(version) \"\(targetsString)\";"
        case .status:
            return nil
        case .cancel:
            return nil
        case .terminalCommand(let customCommand):
            command += customCommand
        }
        args += [command]
        return (shellPath, args)
    }
}
