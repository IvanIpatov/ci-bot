//
//  StorageService.swift
//  
//
//  Created by Ivan Ipatov on 28.10.2023.
//

import Foundation

final public class StorageService: StorageServiceProtocol {

    // MARK: - Private Properties
    private let domain: String?

    private var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let urlString = paths[0].absoluteString + "/ci_bot"
        return URL(string: urlString) ?? paths[0]
    }

    // MARK: - Initialization and deinitialization
    public init(domain: String? = nil) {
        self.domain = domain
    }
}

// MARK: - Cache on disk
public extension StorageService {

    /**
     Store data for key.
     If data is primitive type (Int, Double, String, etc) - it will be stored in container (like UserDefaults).
     If data is not primitive type - it will be stored on disk.
     - parameter data: A Codable object which will be stored.
     - parameter key: The name of the file in which the data will be stored.
     */
    func storeData<T: Codable>(_ data: T?, forKey key: String) {
        let filePath = self.filePath(for: key)
        ensureDomainDirectoryExistance()
        let encoder = JSONEncoder()
        let data = try? encoder.encode(data)
        try? data?.write(to: filePath)
    }

    /**
     Read data for key.
     - parameter key: The name of the key with which the object was stored.
     - Returns: Object of `T` class if it was in the cache with `key`.
     */
    func readData<T: Codable>(forKey key: String) -> T? {
        var data: T? = nil
        let filePath = self.filePath(for: key)
        guard let content = try? Data(contentsOf: filePath) else { return nil }
        let decoder = JSONDecoder()
        data = try? decoder.decode(T.self, from: content)
        return data
    }

    func deleteData<T: Codable>(type: T.Type, for key: String) {
        let fileUrl = filePath(for: key)
        try? FileManager.default.removeItem(at: fileUrl)
    }

    private func userDefaultsKey(for storageKey: String) -> String {
        if let domain = domain {
            return "\(domain).\(storageKey)"
        } else {
            return storageKey
        }
    }

    private func domainDirectory() -> URL {
        if let domain = domain {
            return documentsDirectory
                .appendingPathComponent(domain)
        } else {
            return documentsDirectory
        }
    }

    private func filePath(for storageKey: String) -> URL {
        domainDirectory()
            .appendingPathComponent(storageKey)
            .appendingPathExtension("json")
    }

    private func ensureDomainDirectoryExistance() {
        let directory = domainDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
