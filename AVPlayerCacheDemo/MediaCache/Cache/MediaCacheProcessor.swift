//
//  MediaCacheProcessor.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/13.
//

import Foundation

class MediaCacheProcessor {
    let url: URL
    let cachedFileURL: URL
    let cachedFileInfo: CachedFileInfo?
    
    private var fileManager = FileManager.default
    private var writeFileHandle: FileHandle?
    private var readFileHandle: FileHandle?
    private lazy var ioQueue: DispatchQueue = {
        return DispatchQueue(label: "com.dwinters.CachingPlayerItem.MediaCache.ioQueue.\(url.absoluteString.md5)")
    }()
    
    init(url: URL) {
        self.url = url
        self.cachedFileURL = MediaCache.default.cachedFileURLWith(url: url)
        let cachedFileInfoURL = MediaCache.default.cachedFileInfoURLWith(url: url)
        if fileManager.fileExists(atPath: cachedFileInfoURL.path),
           let data = fileManager.contents(atPath: cachedFileInfoURL.path),
           let value = try? JSONDecoder().decode(CachedFileInfo.self, from: data) {
            self.cachedFileInfo = value
        } else {
            self.cachedFileInfo = nil
        }
    }
    
    func cacheData(_ data: Data, for range: NSRange, completion handler: ((Bool)->())? = nil) {
        guard data.count > 0, range.isValid else {
            handler?(false)
            return
        }
        if !fileManager.fileExists(atPath: cachedFileURL.path) {
            fileManager.createFile(atPath: cachedFileURL.path, contents: nil)
        }
        if writeFileHandle == nil {
            do {
                writeFileHandle = try FileHandle(forWritingTo: cachedFileURL)
            } catch {
                handler?(false)
            }
        }
        if let writeFileHandle = writeFileHandle {
            ioQueue.async {
                self.writeFileHandle?.seek(toFileOffset: UInt64(range.location))
                self.writeFileHandle?.write(data)
                self.cachedFileInfo?.addCacheFragment(range)
                handler?(true)
            }
        } else {
            handler?(false)
        }
        
        func writeData(_ data: Data, for range: NSRange) {
            writeFileHandle?.seek(toFileOffset: UInt64(range.location))
            writeFileHandle?.write(data)
            cachedFileInfo?.addCacheFragment(range)
        }
    }
    
    func cachedDataFor(range: NSRange) throws -> Data? {
        if !fileManager.fileExists(atPath: cachedFileURL.path) {
            return nil
        }
        var data: Data?
        do {
            if readFileHandle == nil {
                readFileHandle = try FileHandle(forReadingFrom: cachedFileURL)
            }
            ioQueue.async {
                self.writeFileHandle?.seek(toFileOffset: UInt64(range.location))
                self.writeFileHandle?.write(data)
                self.cachedFileInfo?.addCacheFragment(range)
            }
        } catch {
            throw error
        }
        var data: Data?
//        synced(readFileHandle) {
            do {
                try readFileHandle.seek(toOffset: UInt64(range.location))
                try data = readFileHandle.read(upToCount: range.length)
            } catch {
                throw error
            }
//        }
        return data
    }
}
