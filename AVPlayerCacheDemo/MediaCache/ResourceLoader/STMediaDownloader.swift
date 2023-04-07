//
//  STMediaDownloader.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/7.
//

import Foundation
import AVFoundation
import CoreServices

class STMediaDownloader: NSObject {
    
    weak var delegate: MediaDownloaderDelegate?
    var contentInfo: ContentInfo?
    let url: URL
    let cacheWorker: CacheWorker
    let loadingRequest: AVAssetResourceLoadingRequest
    var actions: [CacheAction] = []
    var canSaveToCache = true
    var downloadToEnd = false
    var startOffset = 0
    var task: URLSessionDataTask?
    var isCancelled = false
    
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    init(url: URL, loadingRequest: AVAssetResourceLoadingRequest, cacheWorker: CacheWorker) {
        self.url = url
        self.loadingRequest = loadingRequest
        self.cacheWorker = cacheWorker
        self.contentInfo = cacheWorker.cacheConfiguration.contentInfo
        MediaDownloaderStatus.share.addURL(url)
    }
    
    func startDownload() {
        if let dataRequest = loadingRequest.dataRequest {
            var offset = Int(dataRequest.requestedOffset)
            var length = dataRequest.requestedLength
            if dataRequest.currentOffset != 0 {
                offset = Int(dataRequest.currentOffset)
            }
            if dataRequest.requestsAllDataToEndOfResource, let contentLength = contentInfo?.contentLength {
                length = contentLength - offset
            }
            
            let range = NSRange(location: offset, length: length)
            actions = cacheWorker.cachedDataActionsForRange(range)
//            actions = [CacheAction(actionType: .remote, range: range)]
            processActions()
//            downloadTaskFromOffset(offset, length: length)
        }
    }
    
    func downloadTaskFromOffset(_ offset: Int, length: Int) {
        startOffset = offset
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let range = "bytes=\(offset)-\(offset + length - 1)"
        request.setValue(range, forHTTPHeaderField: "Range")
        task = session.dataTask(with: request)
        task?.resume()
    }
    
    func downloadTaskFromOffsetToEnd(_ fromOffset: Int) {
        guard let contentInfo = contentInfo else {
            return
        }
        downloadTaskFromOffset(fromOffset, length: contentInfo.contentLength - fromOffset)
    }
    
    func downloadFromStartToEnd() {
        downloadToEnd = true
        downloadTaskFromOffset(0, length: 2)
    }
    
    func cancel() {
        MediaDownloaderStatus.share.removeURL(url)
        session.invalidateAndCancel()
        isCancelled = true
    }
    
    func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?, response: URLResponse) {
        guard let contentInformationRequest = contentInformationRequest else { return }
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
            contentInformationRequest.isByteRangeAccessSupported = contentInfo.isByteRangeAccessSupported
            contentInformationRequest.contentType = contentInfo.contentType
            contentInformationRequest.contentLength = Int64(contentInfo.contentLength)
            cacheWorker.setContentInfo(contentInfo)
        }
    }
    
    func processActions() {
        guard !isCancelled, let action = popFirstActionInList() else {
            return
        }
        if action.actionType == .local {
            do {
                if let data = try cacheWorker.cachedDataForRange(action.range) {
                    print("STPlayerItem: 本地缓存:\(data.count)")
                    startOffset += data.count
                    loadingRequest.dataRequest?.respond(with: data)
                    DispatchQueue.global().async {
                        self.processActions()
                    }
                } else {
                    print("STPlayerItem: 本地缓存空")
                }
            } catch {
                delegate?.didFinishedWithError(error)
                print("STPlayerItem: 本地缓存获取失败\(error.localizedDescription)")
            }
            
        } else {
            let fromOffset = action.range.location
            let endOffset = action.range.location + action.range.length - 1
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let range = "bytes=\(fromOffset)-\(endOffset)"
            request.setValue(range, forHTTPHeaderField: "Range")
            startOffset = action.range.location
            task = session.dataTask(with: request)
            task?.resume()
            print("STPlayerItem: 开始请求Range:\(range)")
        }
        
    }
    
    func popFirstActionInList() -> CacheAction? {
        var action: CacheAction?
        synced(self) {
            if let act = self.actions.first {
                action = act
                self.actions.removeFirst()
            }
        }
        if action == nil {
//            delegate?.didFinishedWithError(nil)
        }
        return action
    }
    
}

extension STMediaDownloader: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let card = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, card)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        print("urlSession didReceive response: \(response)")
        fillInContentInformationRequest(loadingRequest.contentInformationRequest, response: response)
        if canSaveToCache {
            cacheWorker.startWritting()
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//        print("urlSession didReceiveData: \(data.count)")
        if isCancelled {
            return
        }
        if canSaveToCache {
            let range = NSRange(location: startOffset, length: data.count)
            cacheWorker.cacheData(data, for: range)
            cacheWorker.save()
        }
//        print("STPlayerItem: didReceive data:\(data.count) startOffset:\(startOffset)")
        startOffset += data.count
        loadingRequest.dataRequest?.respond(with: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        print("urlSession didCompleteWithError: \(error)")
        MediaDownloaderStatus.share.removeURL(url)
        
        if canSaveToCache {
            cacheWorker.finishWritting()
            cacheWorker.save()
        }
        if (error as? NSError)?.code == NSURLErrorCancelled {
            return
        }
        if error == nil {
            loadingRequest.finishLoading()
            processActions()
        } else {
            loadingRequest.finishLoading(with: error)
        }
        delegate?.didFinishedWithError(error)
        
    }
}
