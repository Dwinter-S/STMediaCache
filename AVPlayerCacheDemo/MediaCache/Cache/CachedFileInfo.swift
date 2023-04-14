//
//  CachedFileInfo.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/13.
//

import Foundation

class CachedFileInfo: Codable {
    let url: URL
    var cachedFragments: [NSRange] = []
    lazy var fileURL = MediaCache.default.cachedFileInfoURLWith(url: url)
    var contentInfo: ContentInfo?
    
    init(url: URL) {
        self.url = url
    }
    
    func addCacheFragment(_ fragment: NSRange) {
        guard fragment.isValid else {
            return
        }
        print("addCacheFragment:\(fragment)")
        synced(cachedFragments) {
            var cachedFragments = self.cachedFragments
            let startIndex = cachedFragments.firstIndex(where: { $0.intersection(fragment) != nil || $0.end == fragment.location })
            let endIndex = cachedFragments.lastIndex(where: { $0.intersection(fragment) != nil || $0.location == fragment.end })
            if startIndex == nil && endIndex == nil {
                let insertIndex = cachedFragments.firstIndex(where: { fragment.location > $0.end }) ?? 0
                cachedFragments.insert(fragment, at: insertIndex)
            } else {
                let replaceSubrange = (startIndex ?? endIndex!)...(endIndex ?? startIndex!)
                var unionRange = fragment
                for range in cachedFragments[replaceSubrange] {
                    unionRange.formUnion(range)
                }
                cachedFragments.replaceSubrange(replaceSubrange, with: [unionRange])
            }
            print("cachedFragments:\(cachedFragments)")
            self.cachedFragments = cachedFragments.sorted(by: { $0.location < $1.location })
        }
    }
    
    func save() {
        MediaCache.default.createCacheDirectoryIfNeeded()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: fileURL)
        } catch {
            print("STCachingPlayerItemSaveError:\(error.localizedDescription)")
        }
    }
    
}
