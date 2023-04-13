//
//  LoadingRequestProcessor.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/13.
//

import Foundation
import AVFoundation
import CoreServices

enum LoadingTaskType {
    case local
    case remote
}

class LoadingTask {
    let taskType: LoadingTaskType
    let range: NSRange
    
    init(taskType: LoadingTaskType, range: NSRange) {
        self.taskType = taskType
        self.range = range
    }
    
    static func == (lhs: LoadingTask, rhs: LoadingTask) -> Bool {
        return (lhs.taskType == rhs.taskType) && (lhs.range == rhs.range)
    }
}

protocol LoadingRequestProcessorDelegate: AnyObject {
    func processor(_ processor: LoadingRequestProcessor, didCompleteWithError error: Error?)
}

class LoadingRequestProcessor: NSObject {
    
    weak var delegate: LoadingRequestProcessorDelegate?
    let url: URL
    let loadingRequest: AVAssetResourceLoadingRequest
    let cacheWorker: CacheWorker
    
    var loadingTasks: [LoadingTask] = []
    var startOffset: Int = 0
    var bufferData = Data()
    var isCancelled = false
    
    init(url: URL,
         loadingRequest: AVAssetResourceLoadingRequest,
         cacheWorker: CacheWorker,
         delegate: LoadingRequestProcessorDelegate) {
        self.url = url
        self.loadingRequest = loadingRequest
        self.cacheWorker = cacheWorker
        self.delegate = delegate
        super.init()
        if let dataRequest = loadingRequest.dataRequest {
            var offset = Int(dataRequest.requestedOffset)
            var length = dataRequest.requestedLength
            if dataRequest.currentOffset != 0 {
                offset = Int(dataRequest.currentOffset)
            }
            if dataRequest.requestsAllDataToEndOfResource, let contentLength = loadingRequest.contentInformationRequest?.contentLength {
                length = Int(contentLength) - offset
            }
            
            let range = NSRange(location: offset, length: length)
            loadingTasks = cacheWorker.cachedDataActionsForRange(range)
        }
    }
    
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    func proccessTasks() {
        guard !isCancelled else {
            return
        }
        guard !loadingTasks.isEmpty else {
            finishLoadingRequest(loadingRequest, error: nil)
            return
        }
        let loadingTask = loadingTasks.removeFirst()
        if loadingTask.taskType == .local {
            do {
                if let data = try cacheWorker.cachedDataForRange(loadingTask.range) {
                    startOffset += data.count
                    fillInContentInformationRequest(loadingRequest.contentInformationRequest, response: nil)
                    loadingRequest.dataRequest?.respond(with: data)
                    proccessTasks()
                } else {
                    
                }
            } catch {
                
            }
        } else {
            let fromOffset = loadingTask.range.location
            let endOffset = loadingTask.range.location + loadingTask.range.length - 1
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let range = "bytes=\(fromOffset)-\(endOffset)"
            request.setValue(range, forHTTPHeaderField: "Range")
            startOffset = loadingTask.range.location
            let dataTask = session.dataTask(with: request)
            dataTask.resume()
        }
    }
    
    func cancelTasks() {
        session.invalidateAndCancel()
        isCancelled = true
    }
    
    func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?, response: URLResponse?) {
        guard let contentInformationRequest = contentInformationRequest else { return }
        guard contentInformationRequest.contentType == nil else { return }
        if let contentInfo = cacheWorker.cacheConfiguration.contentInfo {
            setContentInfo(contentInfo)
            return
        }
        if let httpResponse = response as? HTTPURLResponse {
            let contentInfo = ContentInfo()
            let acceptRange = httpResponse.allHeaderFields["Accept-Ranges"] as? String
            contentInfo.isByteRangeAccessSupported = acceptRange == "bytes"
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
            setContentInfo(contentInfo)
        }
        
        func setContentInfo(_ contentInfo: ContentInfo) {
            contentInformationRequest.isByteRangeAccessSupported = contentInfo.isByteRangeAccessSupported
            contentInformationRequest.contentType = contentInfo.contentType
            contentInformationRequest.contentLength = Int64(contentInfo.contentLength)
        }
    }
    
    func finishLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest?, error: Error?) {
        guard let loadingRequest = loadingRequest else { return }
        if error != nil {
            loadingRequest.finishLoading(with: error)
        } else {
            loadingRequest.finishLoading()
        }
    }
    
    func cacheBufferData() {
        let range = NSRange(location: startOffset, length: bufferData.count)
        cacheWorker.cacheData(bufferData, for: range)
        startOffset += bufferData.count
    }
    
}


extension LoadingRequestProcessor: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        fillInContentInformationRequest(loadingRequest.contentInformationRequest, response: response)
        bufferData = Data()
        cacheWorker.startWritting()
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bufferData.append(data)
        guard bufferData.count > 1024 * 1024 else {
            return
        }
        cacheBufferData()
        cacheWorker.save()
        loadingRequest.dataRequest?.respond(with: bufferData)
        bufferData = Data()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        cacheBufferData()
        cacheWorker.finishWritting()
        cacheWorker.save()
        loadingRequest.dataRequest?.respond(with: bufferData)
        if (error as? NSError)?.code == NSURLErrorCancelled {
            return
        }
        proccessTasks()
    }
    
}
