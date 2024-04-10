//
//  File.swift
//  
//
//  Created by Ivan Ipatov on 27.10.2023.
//

import Foundation

func log(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
