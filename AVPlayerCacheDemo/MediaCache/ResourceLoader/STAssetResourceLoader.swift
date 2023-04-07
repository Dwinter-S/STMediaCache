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
//    var pendingLoadingRequests = Set<AVAssetResourceLoadingRequest>()
    var downloaders = Set<STMediaDownloader>()
    let cacheWorker: CacheWorker
    
    init(url: URL) {
        self.url = url
        self.cacheWorker = CacheWorker(url: url)
    }
    
    deinit {
        downloaders.forEach({ $0.cancel() })
    }
    
    func addRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
//        pendingLoadingRequests.insert(loadingRequest)
        let downloader = STMediaDownloader(url: url, loadingRequest: loadingRequest, cacheWorker: cacheWorker)
        downloader.startDownload()
        downloaders.insert(downloader)
    }
    
    func removeRequest(_ request: AVAssetResourceLoadingRequest) {
        if let downloader = downloaders.first(where: ({ $0.loadingRequest == request })) {
            downloaders.remove(downloader)
            if request.isFinished {
                downloader.cancel()
                request.finishLoading(with: NSError(domain: "com.resourceloader", code: -3, userInfo: [NSLocalizedDescriptionKey : "Resource loader cancelled"]))
            }
        }
//        pendingLoadingRequests.remove(request)
    }
    
    func cancel() {
        downloaders.forEach({ $0.cancel() })
//        pendingLoadingRequests.removeAll()
    }
}
