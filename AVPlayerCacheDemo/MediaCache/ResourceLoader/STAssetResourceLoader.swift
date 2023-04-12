//
//  STAssetResourceLoader.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/7.
//

import Foundation
import AVFoundation
import CoreServices

class STAssetResourceLoader: NSObject {
    
    let url: URL
    var downloaders = Set<STMediaDownloader>()
    let cacheWorker: CacheWorker
    
    init(url: URL) {
        self.url = url
        self.cacheWorker = CacheWorker(url: url)
    }
    
//    deinit {
//        cancel()
//    }
    
    func addRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        let downloader = STMediaDownloader(url: url, loadingRequest: loadingRequest, cacheWorker: cacheWorker)
        downloader.startDownload()
        downloaders.insert(downloader)
        print("????add:\(downloaders.count)")
    }
    
    func removeRequest(_ request: AVAssetResourceLoadingRequest) {
        if let downloader = downloaders.first(where: ({ $0.loadingRequest == request })) {
            downloaders.remove(downloader)
            print("????remove:\(downloaders.count)")
//            if request.isFinished {
                downloader.cancel()
                request.finishLoading(with: NSError(domain: "com.resourceloader", code: -3, userInfo: [NSLocalizedDescriptionKey : "Resource loader cancelled"]))
//            }
        }
    }
    
    func cancel() {
        downloaders.forEach({ $0.cancel() })
    }
}
