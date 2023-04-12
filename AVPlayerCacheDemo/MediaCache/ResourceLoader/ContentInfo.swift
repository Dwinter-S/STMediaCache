//
//  ContentInfo.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation

class ContentInfo: Codable {
    var contentType: String = ""
    var contentLength: Int = 0
    var downloadedContentLength: Int = 0
    var isByteRangeAccessSupported: Bool = false
}

class LocalCacheInfo {
    var contentInfo: ContentInfo
    var data: Data
    init(contentInfo: ContentInfo, data: Data) {
        self.contentInfo = contentInfo
        self.data = data
    }
}
