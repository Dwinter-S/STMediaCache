//
//  ActionWorker.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation

protocol ActionWorkerDelegate: AnyObject {
    func didReceiveResponse(_ response: URLResponse)
    func didReceiveData(_ data: Data, isLocal: Bool)
    func didFinishedWithError(_ error: Error?)
}

class ActionWorker: NSObject {
    var actions: [LoadingTask]
    let url: URL
    let cacheWorker: CacheWorker
    var canSaveToCache = true
    var isCancelled = false
    weak var delegate: ActionWorkerDelegate?
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    var task: URLSessionDataTask?
    var startOffset: Int = 0
    init(actions: [LoadingTask], url: URL, cacheWorker: CacheWorker) {
        print("STCachingPlayerItem: ActionWorker init")
        for action in actions {
            print("STCachingPlayerItem: taskType:\(action.taskType) range:\(action.range)")
        }
        self.actions = actions
        self.url = url
        self.cacheWorker = cacheWorker
    }
    
    func start() {
        processActions()
    }
    
    func cancel() {
        session.invalidateAndCancel()
        isCancelled = true
    }
    
    func processActions() {
        guard !isCancelled, let action = popFirstActionInList() else {
            return
        }
        if action.taskType == .local {
            do {
                if let data = try cacheWorker.cachedDataForRange(action.range) {
                    print("STCachingPlayerItem: 本地缓存:\(data.count)")
                    delegate?.didReceiveData(data, isLocal: true)
                    DispatchQueue.global().async {
                        self.processActions()
                    }
                } else {
                    print("STCachingPlayerItem: 本地缓存空")
                }
            } catch {
                delegate?.didFinishedWithError(error)
                print("STCachingPlayerItem: 本地缓存获取失败\(error.localizedDescription)")
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
            print("STCachingPlayerItem: 开始请求Range:\(range)")
        }
        
    }
    
    func popFirstActionInList() -> LoadingTask? {
        var action: LoadingTask?
        synced(self) {
            if let act = self.actions.first {
                action = act
                self.actions.removeFirst()
            }
        }
        if action == nil {
            delegate?.didFinishedWithError(nil)
        }
        return action
    }
    
    func notifyDownloadProgressWithFlush(_ flush: Bool, finished: Bool) {
        
    }
    
}

extension ActionWorker: URLSessionDataDelegate {
    
//    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
//        let card = URLCredential(trust: challenge.protectionSpace.serverTrust!)
//        completionHandler(.useCredential, card)
//    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let card = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, card)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        print("urlSession didReceive response: \(response)")
        if canSaveToCache {
            cacheWorker.startWritting()
        }
        delegate?.didReceiveResponse(response)
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
        startOffset += data.count
        delegate?.didReceiveData(data, isLocal: false)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        print("urlSession didCompleteWithError: \(error)")
        if canSaveToCache {
            cacheWorker.finishWritting()
            cacheWorker.save()
        }
        if let error = error {
            delegate?.didFinishedWithError(error)
        } else {
            processActions()
        }
    }
}
