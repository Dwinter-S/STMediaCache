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
    
    init(url: URL) {
        self.url = url
    }
    
    func addCacheFragment(_ fragment: NSRange) {
        guard fragment.location != NSNotFound, fragment.length != 0 else {
            return
        }
        synced(cachedFragments) {
            var cachedFragments = self.cachedFragments
            if cachedFragments.isEmpty {
                cachedFragments.append(fragment)
            } else {
                
            }
        }
    }
    
}
