//
//  CacheManager.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/7.
//

import Foundation
import CommonCrypto

class CacheManager {
    static let shared = CacheManager()
    
    private init() {
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appending(path: "STMediaCache")
        self.cacheUpdateNotifyInterval = 0.1
    }
    
    var cacheDirectory: URL
    var cacheUpdateNotifyInterval: TimeInterval?
    
    func cachedFileURLForURL(_ url: URL) -> URL {
        return cacheDirectory.appending(path: url.absoluteString.md5String()).appendingPathExtension(url.pathExtension)
    }
    
    func cacheConfiguration(with url: URL) -> CacheConfiguration {
        let fileURL = cachedFileURLForURL(url)
        return CacheConfiguration.configurationWithFileURL(fileURL)
    }
    
    func addCacheFile() {
        
    }
}



extension String {
    func md5String() -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = self.data(using:.utf8)!
        var digestData = Data(count: length)
        
        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
            messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }

//    //Test:
//    let md5Data = MD5(string:"Hello")
//
//    let md5Hex =  md5Data.map { String(format: "%02hhx", $0) }.joined()
//    print("md5Hex: \(md5Hex)")
//
//    let md5Base64 = md5Data.base64EncodedString()
//    print("md5Base64: \(md5Base64)")
}
