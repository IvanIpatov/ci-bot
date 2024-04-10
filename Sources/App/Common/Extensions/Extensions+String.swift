//
//  Extensions+String.swift
//
//
//  Created by Ivan Ipatov on 09.04.2024.
//

import Foundation

extension String {

    func condenseWhitespace() -> String {
        let components = components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
