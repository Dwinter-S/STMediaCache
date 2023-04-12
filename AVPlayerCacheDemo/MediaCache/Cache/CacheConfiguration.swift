//
//  CacheConfiguration.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/6.
//

import Foundation

class CacheConfiguration: Codable {
    var contentInfo: ContentInfo?
    var fileURL: URL
    var fileName: String
    var url: URL?
    var cacheFragments: [NSRange] = []
    var downloadInfo = [[CGFloat]]()
    
    var progress: CGFloat {
        if let contentInfo = contentInfo {
            return CGFloat(downloadedBytes) / CGFloat(contentInfo.contentLength)
        }
        return 0
    }
    
    var downloadedBytes: Int {
        var bytes = 0
        synced(cacheFragments) {
            for range in cacheFragments {
                bytes += range.length
            }
        }
        return bytes
    }
    
    var downloadSpeed: CGFloat {
        var bytes: CGFloat = 0
        var time: CGFloat = 0
        synced(downloadInfo) {
            for info in downloadInfo {
                bytes += info[0]
                time += info[1]
            }
        }
        return bytes / 1024.0 / time
    }
    
    var isDownloadComplete: Bool {
        return downloadedBytes == contentInfo?.contentLength
    }
    
    static func createAndSaveDownloadedConfigurationForURL(_ url: URL) {
        
    }
    
    static func configurationWithFileURL(_ fileURL: URL) -> CacheConfiguration {
        let configFileURL = fileURL.deletingPathExtension().appendingPathExtension("cfg")
        if FileManager.default.fileExists(atPath: configFileURL.path()),
           let data = FileManager.default.contents(atPath: configFileURL.path()),
           let value = try? JSONDecoder().decode(CacheConfiguration.self, from: data) {
            value.fileURL = configFileURL
            return value
        }
        if !FileManager.default.fileExists(atPath: configFileURL.path()) {
            FileManager.default.createFile(atPath: configFileURL.path(), contents: nil)
        }
        return CacheConfiguration(fileURL: configFileURL)
    }
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: fileURL)
        } catch {
            print("encode error: \(error.localizedDescription)")
        }
    }
    
    func addCacheFragment(_ fragment: NSRange) {
        if fragment.location == NSNotFound || fragment.length == 0 {
            return
        }
        synced(cacheFragments) {
            var cacheFragments = self.cacheFragments
            if cacheFragments.isEmpty {
                cacheFragments.append(fragment)
            } else {
                var indexSet = NSMutableIndexSet()
                for (index, range) in cacheFragments.enumerated() {
                    if fragment.location + fragment.length <= range.location {
                        if indexSet.count == 0 {
                            indexSet.add(index)
                        }
                        break
                    } else if fragment.location <= (range.location + range.length) {
                        indexSet.add(index)
                    } else {
                        if index == cacheFragments.count - 1 {
                            indexSet.add(index)
                        }
                    }
                }
                if indexSet.count > 1 {
                    let firstRange = cacheFragments[indexSet.firstIndex]
                    let lastRange = cacheFragments[indexSet.lastIndex]
                    let location = min(firstRange.location, fragment.location)
                    let endOffset = max(lastRange.location + lastRange.length, fragment.location + fragment.length)
                    let combineRange = NSRange(location: location, length: endOffset - location)
                    (cacheFragments as! NSMutableArray).removeObjects(at: indexSet as IndexSet)
                    cacheFragments.insert(combineRange, at: indexSet.firstIndex)
                } else if indexSet.count == 1 {
                    let firstRange = cacheFragments[indexSet.firstIndex]
                    let expandFirstRange = NSRange(location: firstRange.location, length: firstRange.length + 1)
                    let expandFragmentRange = NSRange(location: fragment.location, length: fragment.length + 1)
                    let intersectionRange = NSIntersectionRange(expandFirstRange, expandFragmentRange)
                    if intersectionRange.length > 0 {
                        let location = min(firstRange.location, fragment.location)
                        let endOffset = max(firstRange.location + firstRange.length, fragment.location + fragment.length)
                        let combineRange = NSRange(location: location, length: endOffset - location)
                        cacheFragments.remove(at: indexSet.firstIndex)
                        cacheFragments.insert(combineRange, at: indexSet.firstIndex)
                    } else {
                        if firstRange.location > fragment.location {
                            cacheFragments.insert(fragment, at: indexSet.lastIndex)
                        } else {
                            cacheFragments.insert(fragment, at: indexSet.lastIndex + 1)
                        }
                    }
                }
            }
            self.cacheFragments = cacheFragments
        }
    }
    
    func addDownloadedBytes(_ bytes: Int, spend time: TimeInterval) {
        synced(downloadInfo) {
            self.downloadInfo += [[CGFloat(bytes), CGFloat(time)]]
        }
    }
    
}
