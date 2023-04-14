//
//  AssetResourceLoader.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/7.
//

import Foundation
import AVFoundation
import CoreServices

class AssetResourceLoader: NSObject {
    
    let url: URL
    let cacheProcessor: MediaCacheProcessor
    var requestProcessors = Set<LoadingRequestProcessor>()
    
    init(url: URL) {
        self.url = url
        self.cacheProcessor = MediaCacheProcessor(url: url)
    }
    
    deinit {
        cancel()
    }
        
    func addRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        if let _ = loadingRequest.dataRequest {
            let requestProcessor = LoadingRequestProcessor(url: url,
                                                           loadingRequest: loadingRequest,
                                                           cacheProcessor: cacheProcessor,
                                                           delegate: self)
            requestProcessors.insert(requestProcessor)
            requestProcessor.proccessTasks()
        }
    }
    
    func removeRequest(_ request: AVAssetResourceLoadingRequest) {
        if let processor = requestProcessors.first(where: ({ $0.loadingRequest == request })) {
            requestProcessors.remove(processor)
            processor.cancelTasks()
            request.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        }
    }
    
    func cancel() {
        requestProcessors.forEach({ $0.cancelTasks() })
    }
    
}

extension AssetResourceLoader: LoadingRequestProcessorDelegate {
    func processor(_ processor: LoadingRequestProcessor, didCompleteWithError error: Error?) {
        
    }
}
