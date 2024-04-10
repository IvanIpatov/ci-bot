//
//  File.swift
//  
//
//  Created by Ivan Ipatov on 28.10.2023.
//

import Foundation

public struct UserModel: Codable {
    
    public let id: Int64
    public let username: String?
    public let isAvailable: Bool

    public init(id: Int64, username: String?, isAvailable: Bool) {
        self.id = id
        self.username = username
        self.isAvailable = isAvailable
    }
}
