//
//  Config.swift
//
//
//  Created by Ivan Ipatov on 06.12.2023.
//

import Foundation

public struct Config: Codable {
    
    public var projectPath: String
    public var projectTargets: [String]

    public init(
        projectPath: String,
        projectTargets: [String]
    ) {
        self.projectPath = projectPath
        self.projectTargets = projectTargets
    }
}
