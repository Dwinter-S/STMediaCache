//
//  HCPMediaCache.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/3/30.
//

import Foundation
import AVKit
import Cache

class HCPMediaCache {
    static let shared = HCPMediaCache()
    let diskConfig = DiskConfig(name: "DiskCache", maxSize: 1024 * 1024 * 1024)
    let memoryConfig = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)

    lazy var storage: Cache.Storage? = {
        return try? Cache.Storage(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: TransformerFactory.forData())
    }()
    
    func getCache(with url: URL, completion: ((Data?) -> ())?) {
        storage?.async.entry(forKey: url.absoluteString, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .error:
                    completion?(nil)
                case .value(let entry):
                    completion?(entry.object)
                }
            }
        })
    }
    
    func setCache(data: Data, with url: URL) {
        storage?.async.setObject(data, forKey: url.absoluteString, completion: { _ in })
    }
    
    func cleanCache() {
        try? storage?.removeExpiredObjects()
    }
    
}

    
