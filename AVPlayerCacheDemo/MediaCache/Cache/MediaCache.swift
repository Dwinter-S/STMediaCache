//
//  MediaCache.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/13.
//

import Foundation

class MediaCache {
    
    static let `default` = MediaCache(name: "default")
    
    let fileManager = FileManager.default
    let diskCacheDirectory: URL
    let ioQueue: DispatchQueue
    
    init(name: String) {
        self.diskCacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("com.dwinters.CachingPlayerItem.MediaCache.\(name)")
        print("diskCacheDirectory:\(diskCacheDirectory.absoluteString)")
        self.ioQueue = DispatchQueue(label: "com.dwinters.CachingPlayerItem.MediaCache.ioQueue.\(name)")
    }
    
    func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: diskCacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
            } catch {
                
            }
        }
    }
    
    func clearDiskCache(completion handler: (()->())? = nil) {
        ioQueue.async {
            do {
                try self.fileManager.removeItem(at: self.diskCacheDirectory)
                try self.fileManager.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
            } catch {}
            
            if let handler = handler {
                DispatchQueue.main.async {
                    handler()
                }
            }
        }
    }
    
    func cachedFileURLWith(url: URL) -> URL {
        return diskCacheDirectory.appendingPathComponent(url.absoluteString.md5).appendingPathExtension(url.pathExtension)
    }
    
    func cachedFileInfoURLWith(url: URL) -> URL {
        return diskCacheDirectory.appendingPathComponent(url.absoluteString.md5).appendingPathExtension("cfi")
    }
    
}

extension NSRange {
    var isValid: Bool {
        return location != NSNotFound && length != 0
    }
    var end: Int {
        return location + length
    }
}
