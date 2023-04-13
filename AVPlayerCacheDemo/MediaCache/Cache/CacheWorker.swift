//
//  CacheWorker.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation
import UIKit

class CacheWorker {
    let url: URL
    var cacheConfiguration: CacheConfiguration
    var readFileHandle: FileHandle?
    var writeFileHandle: FileHandle?
    var writeBytes: Int = 0
    var writting = false
    var startWriteDate: Date?
    var currentOffset: Int = 0
    
    let packageLength = 512 * 1024;
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        save()
        try? readFileHandle?.close()
        try? writeFileHandle?.close()
    }
    
    init(url: URL) {
        self.url = url
        let fileURL = CacheManager.shared.cachedFileURLFor(url: url)
        self.cacheConfiguration = CacheConfiguration.configurationWithFileURL(fileURL)
        self.cacheConfiguration.url = url
        let fileManager = FileManager.default
        let cacheFolder = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: cacheFolder.path()) {
            do {
                try fileManager.createDirectory(at: cacheFolder, withIntermediateDirectories: true)
            } catch {
                print("createDirectory error:\(error.localizedDescription)")
            }
        }
        if !fileManager.fileExists(atPath: fileURL.path()) {
            fileManager.createFile(atPath: fileURL.path(), contents: nil)
        }
        do {
            try readFileHandle = FileHandle(forReadingFrom: fileURL)
            try writeFileHandle = FileHandle(forWritingTo: fileURL)
        } catch {
            print("cacheWorker init error:\(error.localizedDescription)")
        }
    }
    
    func cacheData(_ data: Data, for range: NSRange) {
        guard let writeFileHandle = writeFileHandle else { return }
        synced(writeFileHandle) {
            do {
                try writeFileHandle.seek(toOffset: UInt64(range.location))
                try writeFileHandle.write(contentsOf: data)
                writeBytes += data.count
                self.cacheConfiguration.addCacheFragment(range)
            } catch {
                print("缓存失败:\(error.localizedDescription)")
            }
        }
    }
    
    func cachedDataForRange(_ range: NSRange) throws -> Data? {
        guard let readFileHandle = readFileHandle else { return nil }
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
    
    func cachedDataActionsForRange(_ range: NSRange) -> [LoadingTask] {
        let cachedFragments = cacheConfiguration.cacheFragments
        var actions = [LoadingTask]()
        if range.location == NSNotFound {
            return actions
        }
        let endOffset = range.location + range.length
        for (index, fragmentRange) in cachedFragments.enumerated() {
            let intersectionRange = NSIntersectionRange(range, fragmentRange)
            if intersectionRange.length > 0 {
                let package = intersectionRange.length / packageLength
                for i in 0...package {
                    let offset = i * packageLength
                    let offsetLocation = intersectionRange.location + offset
                    let maxLocation = intersectionRange.location + intersectionRange.length
                    let length = (offsetLocation + packageLength) > maxLocation ? (maxLocation - offsetLocation) : packageLength
                    let action = LoadingTask(taskType: .local, range: NSRange(location: offsetLocation, length: length))
                    actions.append(action)
                }
            } else if fragmentRange.location >= endOffset {
                break
            }
        }
        
        if actions.isEmpty {
            actions.append(LoadingTask(taskType: .remote, range: range))
        } else {
            var localRemoteActions = [LoadingTask]()
            for (index, action) in actions.enumerated() {
                let actionRange = action.range
                if index == 0 {
                    if range.location < actionRange.location {
                        localRemoteActions.append(LoadingTask(taskType: .remote, range: NSRange(location: range.location, length: actionRange.location - range.location)))
                    }
                } else {
                    let lastAction = localRemoteActions.last!
                    let lastOffset = lastAction.range.location + lastAction.range.length
                    if actionRange.location > lastOffset {
                        localRemoteActions.append(LoadingTask(taskType: .remote, range: NSRange(location: lastOffset, length: actionRange.location - lastOffset)))
                    }
                }
                localRemoteActions.append(action)
                if index == actions.count - 1 {
                    let localEndOffset = actionRange.location + actionRange.length
                    if endOffset > localEndOffset {
                        localRemoteActions.append(LoadingTask(taskType: .remote, range: NSRange(location: localEndOffset, length: endOffset - localEndOffset)))
                    }
                }
            }
            actions = localRemoteActions
        }
        return actions
    }
    
    func setContentInfo(_ contentInfo: ContentInfo) {
        cacheConfiguration.contentInfo = contentInfo
        do {
            try writeFileHandle?.truncate(atOffset: UInt64(contentInfo.contentLength))
            try writeFileHandle?.synchronize()
        } catch {
            
        }
    }
    
    func save() {
        guard let writeFileHandle = writeFileHandle else { return }
        synced(writeFileHandle) {
            do {
                try writeFileHandle.synchronize()
                cacheConfiguration.save()
            } catch {
                
            }
        }
    }
    
    func startWritting() {
        if !writting {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification
                                                   , object: nil)
        }
        writting = true
        startWriteDate = Date()
        writeBytes = 0
    }
    
    func finishWritting() {
        if writting, let startWriteDate = startWriteDate {
            writting = false
            NotificationCenter.default.removeObserver(self)
            let time = Date().timeIntervalSince(startWriteDate)
            cacheConfiguration.addDownloadedBytes(writeBytes, spend: time)
        }
    }
    
    @objc func applicationDidEnterBackground() {
        save()
    }
}
