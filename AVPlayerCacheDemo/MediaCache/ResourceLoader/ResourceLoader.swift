//
//  ResourceLoader.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation
import AVFoundation

protocol ResourceLoaderDelegate: AnyObject {
    func didFail(resourceLoader: ResourceLoader, error: Error?)
}

class ResourceLoader {
    private(set) var url: URL
    weak var delegate: ResourceLoaderDelegate?
    let cacheWorker: CacheWorker
    let mediaDownloader: MediaDownloader
    var pendingRequestWorkers = Set<ResourceLoadingRequestWorker>()
    init(url: URL) {
        self.url = url
        self.cacheWorker = CacheWorker(url: url)
        self.mediaDownloader = MediaDownloader(url: url, cacheWorker: self.cacheWorker)
    }
    
    deinit {
        mediaDownloader.cancel()
    }
    
    func addRequest(_ request: AVAssetResourceLoadingRequest) {
        if pendingRequestWorkers.isEmpty {
            startNoCacheWorkerWithRequest(request)
        } else {
            startWorkerWithRequest(request)
        }
    }
    
    func removeRequest(_ request: AVAssetResourceLoadingRequest) {
        if let index = pendingRequestWorkers.firstIndex(where: { $0.request == request }) {
            pendingRequestWorkers[index].finish()
            pendingRequestWorkers.remove(at: index)
        }
    }
    
    func cancel() {
        mediaDownloader.cancel()
        pendingRequestWorkers.removeAll()
        MediaDownloaderStatus.share.removeURL(url)
    }
    
    func startNoCacheWorkerWithRequest(_ request: AVAssetResourceLoadingRequest) {
        MediaDownloaderStatus.share.addURL(url)
        let mediaDownloader = MediaDownloader(url: url, cacheWorker: cacheWorker)
        let requestWorker = ResourceLoadingRequestWorker(mediaDownloader: mediaDownloader, resourceLoadingRequest: request)
        requestWorker.delegate = self
        requestWorker.startWork()
        pendingRequestWorkers.insert(requestWorker)
//        pendingRequestWorkers.append(requestWorker)
        
    }
    
    func startWorkerWithRequest(_ request: AVAssetResourceLoadingRequest) {
        MediaDownloaderStatus.share.addURL(url)
        let requestWorker = ResourceLoadingRequestWorker(mediaDownloader: mediaDownloader, resourceLoadingRequest: request)
        requestWorker.delegate = self
        requestWorker.startWork()
        pendingRequestWorkers.insert(requestWorker)
//        pendingRequestWorkers.append(requestWorker)
    }
}

extension ResourceLoader: ResourceLoadingRequestWorkerDelegate {
    func didComplete(requestWorker: ResourceLoadingRequestWorker, _ error: Error?) {
        removeRequest(requestWorker.request)
        if error != nil {
            delegate?.didFail(resourceLoader: self, error: error)
        }
        if pendingRequestWorkers.isEmpty {
            MediaDownloaderStatus.share.removeURL(url)
        }
    }
}
