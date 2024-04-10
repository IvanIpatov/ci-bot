//
//  File.swift
//  
//
//  Created by Ivan Ipatov on 28.10.2023.
//

import Foundation

public protocol StorageServiceProtocol: AnyObject {

    /**
     Store data for key.
     If data is primitive type (Int, Double, String, etc) - it will be stored in container (like UserDefaults).
     If data is not primitive type - it will be stored on disk.
     - parameter data: A Codable object which will be stored.
     - parameter key: The name of the file in which the data will be stored.
     */
    func storeData<T: Codable>(_ data: T?, forKey key: String)

    /**
     Read data for key.
     - parameter key: The name of the key with which the object was stored.
     - Returns: Object of `T` class if it was in the cache with `key`.
     */
    func readData<T: Codable>(forKey key: String) -> T?

    /**
     Delete data
     */
    func deleteData<T: Codable>(type: T.Type, for key: String)
}
