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
    var startOffset = 0
    var isCancelled = false
    var requestTasksMap = [AVAssetResourceLoadingRequest: [LoadingTask]]()
    var bufferDataMap = [URLSessionDataTask : Data]()
    
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
    deinit {
        cancel()
    }
    
    init(url: URL) {
        self.url = url
        self.cacheWorker = CacheWorker(url: url)
        self.contentInfo = self.cacheWorker.cacheConfiguration.contentInfo
    }
        
    func addRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
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
            requestTasksMap[loadingRequest] = cacheWorker.cachedDataActionsForRange(range)
//            for action in actions {
//                print("action:\(action.taskType) \(action.range)")
//            }
            processRequests()
        }
    }
    
    func removeRequest(_ request: AVAssetResourceLoadingRequest) {
//        if let downloader = downloaders.first(where: ({ $0.loadingRequest == request })) {
//            downloaders.remove(downloader)
//            print("????remove:\(downloaders.count)")
//            //            if request.isFinished {
//            downloader.cancel()
//            request.finishLoading(with: NSError(domain: "com.resourceloader", code: -3, userInfo: [NSLocalizedDescriptionKey : "Resource loader cancelled"]))
//            //            }
//        }
    }
    
    func cancel() {
        MediaDownloaderStatus.share.removeURL(url)
        session.invalidateAndCancel()
        isCancelled = true
    }
    
    func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?, response: URLResponse?) {
        guard let contentInformationRequest = contentInformationRequest else { return }
        if let contentInfo = contentInfo {
            setContentInfo(contentInfo)
            return
        }
        if let httpResponse = response as? HTTPURLResponse {
            let contentInfo = ContentInfo()
            self.contentInfo = contentInfo
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
    
    func processRequests() {
        for (loadingRequest, _) in requestTasksMap {
            processRequest(loadingRequest)
        }
    }
    
    func processRequest(_ loadingRequest: AVAssetResourceLoadingRequest) {
        guard !isCancelled else {
            return
        }
        guard var tasks = requestTasksMap[loadingRequest], !tasks.isEmpty else {
            finishLoadingRequest(loadingRequest, error: nil)
            return
        }
        let task = tasks.removeFirst()
        requestTasksMap[loadingRequest] = tasks
        if task.taskType == .local {
            do {
                if let data = try cacheWorker.cachedDataForRange(task.range) {
                    startOffset += data.count
                    fillInContentInformationRequest(loadingRequest.contentInformationRequest, response: nil)
                    loadingRequest.dataRequest?.respond(with: data)
                    processRequest(loadingRequest)
                    //                    print("STPlayerItem: 本地缓存\(data.count)")
                } else {
                    print("STPlayerItem: 本地缓存空\(task.range)")
                }
            } catch {
                delegate?.didFinishedWithError(error)
                print("STPlayerItem: 本地缓存获取失败\(error.localizedDescription)")
            }
            
        } else {
            let fromOffset = task.range.location
            let endOffset = task.range.location + task.range.length - 1
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let range = "bytes=\(fromOffset)-\(endOffset)"
            request.setValue(range, forHTTPHeaderField: "Range")
            startOffset = task.range.location
            task.dataTask = session.dataTask(with: request)
            task.dataTask?.resume()
            print("STPlayerItem: 开始请求Range:\(range)")
        }
    }
    
    func finishLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest?, error: Error?) {
        guard let loadingRequest = loadingRequest else { return }
        if error != nil {
            loadingRequest.finishLoading(with: error)
        } else {
            loadingRequest.finishLoading()
        }
        requestTasksMap.removeValue(forKey: loadingRequest)
    }
    
    func cacheBufferData(_ bufferData: Data) {
        let range = NSRange(location: startOffset, length: bufferData.count)
        cacheWorker.cacheData(bufferData, for: range)
        startOffset += bufferData.count
    }
    
    func getLoadingRequest(dataTask: URLSessionDataTask) -> AVAssetResourceLoadingRequest? {
        for (loadingRequest, tasks) in requestTasksMap {
            if let _ = tasks.firstIndex(where: { $0.dataTask == dataTask }) {
                return loadingRequest
            }
        }
        return nil
    }
    
}

extension STMediaDownloader: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let loadingRequest = getLoadingRequest(dataTask: dataTask)
        fillInContentInformationRequest(loadingRequest?.contentInformationRequest, response: response)
        bufferDataMap[dataTask] = Data()
        cacheWorker.startWritting()
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let loadingRequest = getLoadingRequest(dataTask: dataTask)
        var bufferData = bufferDataMap[dataTask]!
        bufferData.append(data)
        bufferDataMap[dataTask] = bufferData
        guard bufferData.count > 1024 * 1024 else {
            return
        }
//        print("didReceiveData: \(startOffset) \(bufferData.count)")
        cacheBufferData()
        cacheWorker.save()
        loadingRequest?.dataRequest?.respond(with: bufferData)
        bufferDataMap[dataTask] = Data()
    }
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        print("completeDidReceiveData:\(bufferData)")
        MediaDownloaderStatus.share.removeURL(url)
        
        cacheBufferData()
        cacheWorker.finishWritting()
        cacheWorker.save()
        let loadingRequest = getLoadingRequest(dataTask: task as! URLSessionDataTask)
        loadingRequest?.dataRequest?.respond(with: bufferData)
        if (error as? NSError)?.code == NSURLErrorCancelled {
            return
        }
        finishLoadingRequest(loadingRequest, error: error)
        delegate?.didFinishedWithError(error)
    }
}
