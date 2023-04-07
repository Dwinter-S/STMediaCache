//
//  MediaDownloader.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation
import CoreServices

protocol MediaDownloaderDelegate: AnyObject {
    func didReceiveResponse(_ response: URLResponse)
    func didReceiveData(_ data: Data)
    func didFinishedWithError(_ error: Error?)
}

class MediaDownloaderStatus {
    static let share = MediaDownloaderStatus()
    var downloadingURLs = Set<URL>()
    
    func addURL(_ url: URL) {
        synced(self.downloadingURLs) {
            self.downloadingURLs.insert(url)
        }
    }
    
    func removeURL(_ url: URL) {
        synced(self.downloadingURLs) {
            self.downloadingURLs.remove(url)
        }
    }
    
    func containsURL(_ url: URL) -> Bool {
        var res = false
        synced(self.downloadingURLs) {
            res = self.downloadingURLs.contains(url)
        }
        return res
    }
}

class MediaDownloader {
    
    weak var delegate: MediaDownloaderDelegate?
    var contentInfo: ContentInfo?
    let url: URL
    let cacheWorker: CacheWorker
    var actionWorker: ActionWorker?
    var saveToCache = true
    var downloadToEnd = false
    
    init(url: URL, cacheWorker: CacheWorker) {
        self.url = url
        self.cacheWorker = cacheWorker
        self.contentInfo = cacheWorker.cacheConfiguration.contentInfo
        MediaDownloaderStatus.share.addURL(url)
    }
    
    func downloadTaskFromOffset(_ fromOffset: Int, length: Int) {
        let range = NSRange(location: fromOffset, length: length)
        let actions = cacheWorker.cachedDataActionsForRange(range)
//        let actions = [CacheAction(actionType: .remote, range: range)]
        actionWorker = ActionWorker(actions: actions, url: url, cacheWorker: cacheWorker)
        actionWorker?.canSaveToCache = saveToCache
        actionWorker?.delegate = self
        actionWorker?.start()
        print("STPlayerItem: 开始下载 from:\(fromOffset) length:\(length)")
    }
    
    func downloadTaskFromOffsetToEnd(_ fromOffset: Int) {
        guard let contentInfo = cacheWorker.cacheConfiguration.contentInfo else {
            return
        }
        downloadTaskFromOffset(fromOffset, length: contentInfo.contentLength - fromOffset)
    }
    
    func downloadFromStartToEnd() {
        downloadToEnd = true
        downloadTaskFromOffset(0, length: 2)
    }
    
    func cancel() {
        actionWorker?.delegate = nil
        MediaDownloaderStatus.share.removeURL(url)
        actionWorker?.cancel()
        actionWorker = nil
    }
}


extension MediaDownloader: ActionWorkerDelegate {
    func didReceiveResponse(_ response: URLResponse) {
        if let httpResponse = response as? HTTPURLResponse {
            let contentInfo = ContentInfo()
            self.contentInfo = contentInfo
            let acceptRange = httpResponse.allHeaderFields["Accept-Ranges"] as? String
            contentInfo.isByteRangeAccessSupported = acceptRange == "bytes"
            // fix swift allHeaderFields NO! case insensitive
            var contentLength = 0
            var contentRange = httpResponse.allHeaderFields["content-range"] as? String
            contentRange = contentRange ?? httpResponse.allHeaderFields["Content-Range"] as? String
            if let last = contentRange?.components(separatedBy: "/").last {
                contentLength = Int(last)!
            }
            if contentLength == 0 {
                contentLength = Int(httpResponse.expectedContentLength)
            }
            contentInfo.contentLength = contentLength
            if let mimeType = httpResponse.mimeType {
                let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
                if let takeUnretainedValue = contentType?.takeUnretainedValue() {
                    contentInfo.contentType = takeUnretainedValue as String
                }
            }
            cacheWorker.setContentInfo(contentInfo)
        }
        delegate?.didReceiveResponse(response)
    }
    
    func didReceiveData(_ data: Data, isLocal: Bool) {
        delegate?.didReceiveData(data)
    }
    
    func didFinishedWithError(_ error: Error?) {
        MediaDownloaderStatus.share.removeURL(url)
        if error == nil && downloadToEnd {
            downloadToEnd = false
            downloadTaskFromOffsetToEnd(2)
        } else {
            delegate?.didFinishedWithError(error)
        }
    }
}
