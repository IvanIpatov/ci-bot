//
//  File.swift
//  
//
//  Created by Ivan Ipatov on 06.12.2023.
//

import Foundation

public struct BotSettings: Codable {

    public var lastUploadBranch: String
    public var lastUploadVersion: String

    public init(
        lastUploadBranch: String,
        lastUploadVersion: String
    ) {
        self.lastUploadBranch = lastUploadBranch
        self.lastUploadVersion = lastUploadVersion
    }
}
