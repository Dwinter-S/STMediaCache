//
//  ResourceLoadingRequestWorker.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation
import AVFoundation

protocol ResourceLoadingRequestWorkerDelegate: AnyObject {
    func didComplete(requestWorker: ResourceLoadingRequestWorker, _ error: Error?)
}
 
class ResourceLoadingRequestWorker: NSObject {
    
    let mediaDownloader: MediaDownloader
    let request: AVAssetResourceLoadingRequest
    weak var delegate: ResourceLoadingRequestWorkerDelegate?
    init(mediaDownloader: MediaDownloader, resourceLoadingRequest: AVAssetResourceLoadingRequest) {
        self.mediaDownloader = mediaDownloader
        self.request = resourceLoadingRequest
        super.init()
        self.mediaDownloader.delegate = self
        self.fullfillContentInfo()
    }

    func startWork() {
        mediaDownloader.delegate = self
        if let dataRequest = request.dataRequest {
            var offset = Int(dataRequest.requestedOffset)
            let length = dataRequest.requestedLength
            if dataRequest.currentOffset != 0 {
                offset = Int(dataRequest.currentOffset)
            }
            if dataRequest.requestsAllDataToEndOfResource {
                mediaDownloader.downloadTaskFromOffsetToEnd(offset)
            } else {
                mediaDownloader.downloadTaskFromOffset(offset, length: length)
            }
        }
        
    }
    
    func finish() {
        if request.isFinished {
            mediaDownloader.cancel()
            request.finishLoading(with: NSError(domain: "com.resourceloader", code: -3, userInfo: [NSLocalizedDescriptionKey : "Resource loader cancelled"]))
        }
    }
    
    func cancel() {
        mediaDownloader.cancel()
    }
    
    func fullfillContentInfo() {
        
        if let contentInformationRequest = request.contentInformationRequest,
           let contentInfo = mediaDownloader.contentInfo,
           (contentInformationRequest.contentType ?? "").isEmpty {
            contentInformationRequest.contentType = contentInfo.contentType
            contentInformationRequest.contentLength = Int64(contentInfo.contentLength)
            contentInformationRequest.isByteRangeAccessSupported = contentInfo.isByteRangeAccessSupported
        }
    }
}

extension ResourceLoadingRequestWorker: MediaDownloaderDelegate {
    func didReceiveResponse(_ response: URLResponse) {
        fullfillContentInfo()
    }
    
    func didReceiveData(_ data: Data) {
        request.dataRequest?.respond(with: data)
    }
    
    func didFinishedWithError(_ error: Error?) {
        if (error as? NSError)?.code == NSURLErrorCancelled {
            return
        }
        if error == nil {
            request.finishLoading()
        } else {
            request.finishLoading(with: error)
        }
        delegate?.didComplete(requestWorker: self, error)
    }
    
    
}
