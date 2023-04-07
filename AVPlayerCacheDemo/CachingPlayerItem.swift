//
//  CachingPlayerItem.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/3/30.
//

import Foundation
import AVFoundation
import CoreServices

fileprivate extension URL {
    
    func withScheme(_ scheme: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        return components?.url
    }
    
}

@objc protocol CachingPlayerItemDelegate {
    
    /// Is called when the media file is fully downloaded.
    @objc optional func playerItem(_ playerItem: CachingPlayerItem, didFinishDownloadingData data: Data)
    
    /// Is called every time a new portion of data is received.
    @objc optional func playerItem(_ playerItem: CachingPlayerItem, didDownloadBytesSoFar bytesDownloaded: Int, outOf bytesExpected: Int)
    
    /// Is called after initial prebuffering is finished, means
    /// we are ready to play.
    @objc optional func playerItemReadyToPlay(_ playerItem: CachingPlayerItem)
    
    /// Is called when the data being downloaded did not arrive in time to
    /// continue playback.
    @objc optional func playerItemPlaybackStalled(_ playerItem: CachingPlayerItem)
    
    /// Is called on downloading error.
    @objc optional func playerItem(_ playerItem: CachingPlayerItem, downloadingFailedWith error: Error)
    
}

open class CachingPlayerItem: AVPlayerItem {
    
    class ResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
        
        var playingFromData = false
        var mimeType: String? // is required when playing from Data
        var session: URLSession?
        var mediaData: Data?
        var tasks: [URLSessionDataTask : AVAssetResourceLoadingRequest] = [:]
//        var response: URLResponse?
//        var pendingRequests = Set<AVAssetResourceLoadingRequest>()
        weak var owner: CachingPlayerItem?
        
        func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
            
            if playingFromData {
                
                // Nothing to load.
                
            } else {
                guard let initialUrl = owner?.url else {
                    fatalError("internal inconsistency")
                }
                if session == nil {
                    configSession(with: initialUrl)
                }
                var urlRequst = URLRequest(url: initialUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)
//                urlRequst.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
//                urlRequst.httpMethod = "GET"
                //设置请求头
                guard let dataRequest = loadingRequest.dataRequest else{
                    //本次请求没有数据请求
                    return true
                }
                let range = NSMakeRange(Int(dataRequest.requestedOffset), dataRequest.requestedLength)
                let rangeHeaderStr = "bytes=\(range.location)-\(range.location + range.length - 1)"
                urlRequst.setValue(rangeHeaderStr, forHTTPHeaderField: "Range")
//                urlRequst.setValue(initialUrl.host, forHTTPHeaderField: "Referer")
                guard let task = session?.dataTask(with: urlRequst) else{
                    fatalError("cant create task for url")
                }
                task.resume()
                print("task resume: \(rangeHeaderStr)")
                self.tasks[task] = loadingRequest
            }
            
//            pendingRequests.insert(loadingRequest)
//            processPendingRequests()
            return true
            
        }
        
        func configSession(with url: URL) {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        }
        
//        func startDataRequest(with url: URL) {
//            let configuration = URLSessionConfiguration.default
//            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
//            session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
//            session?.dataTask(with: url).resume()
//        }
        
        func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
            print("didCancel loadingRequest")
//            pendingRequests.remove(loadingRequest)
        }
        
        // MARK: URLSession delegate
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            print("didReceive data")
            mediaData?.append(data)
            let loadingRequest = tasks[dataTask]
            loadingRequest?.dataRequest?.respond(with: data)
            loadingRequest?.finishLoading()
            tasks.removeValue(forKey: dataTask)
//            processPendingRequests()
            owner?.delegate?.playerItem?(owner!, didDownloadBytesSoFar: mediaData!.count, outOf: Int(dataTask.countOfBytesExpectedToReceive))
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            print("didReceive response")
            completionHandler(Foundation.URLSession.ResponseDisposition.allow)
            mediaData = Data()
            fillInContentInformationRequest(tasks[dataTask]?.contentInformationRequest, response: response)
//            self.response = response
//            processPendingRequests()
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            print("didCompleteWithError")
            if let errorUnwrapped = error {
                owner?.delegate?.playerItem?(owner!, downloadingFailedWith: errorUnwrapped)
                return
            }
//            processPendingRequests()
            owner?.delegate?.playerItem?(owner!, didFinishDownloadingData: mediaData!)
        }
        
        // MARK: -
        
//        func processPendingRequests() {
//
//            // get all fullfilled requests
//            let requestsFulfilled = Set<AVAssetResourceLoadingRequest>(pendingRequests.compactMap {
//                self.fillInContentInformationRequest($0.contentInformationRequest)
//                if self.haveEnoughDataToFulfillRequest($0.dataRequest!) {
//                    $0.finishLoading()
//                    return $0
//                }
//                return nil
//            })
//
//            // remove fulfilled requests from pending requests
//            _ = requestsFulfilled.map { self.pendingRequests.remove($0) }
//
//        }
        
        func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?, response: URLResponse) {
            
            // if we play from Data we make no url requests, therefore we have no responses, so we need to fill in contentInformationRequest manually
            if playingFromData {
                
                contentInformationRequest?.contentType = getContentTypeString(mimeType: self.mimeType)
                contentInformationRequest?.contentLength = Int64(mediaData!.count)
                contentInformationRequest?.isByteRangeAccessSupported = true
                return
            }
            
//            guard let responseUnwrapped = response else {
//                // have no response from the server yet
//                return
//            }
            
            var isByteRangeAccessSupported = false
            var contentLength: Int64 = 0
            var contentTypeString = ""
            
            if let httpResponse = response as? HTTPURLResponse {
                let acceptRange = httpResponse.allHeaderFields["Accept-Ranges"] as? String
                if let bytes = acceptRange?.isEqual("bytes") {
                    isByteRangeAccessSupported = bytes
                }
                // fix swift allHeaderFields NO! case insensitive
                let contentRange = httpResponse.allHeaderFields["content-range"] as? String
                let contentRang = httpResponse.allHeaderFields["Content-Range"] as? String
                if let last = contentRange?.components(separatedBy: "/").last {
                    contentLength = Int64(last)!
                }
                if let last = contentRang?.components(separatedBy: "/").last {
                    contentLength = Int64(last)!
                }
                
                if contentLength == 0 {
                    contentLength = httpResponse.expectedContentLength
                }
                
                if let mimeType = httpResponse.mimeType {
                    let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
                    if let takeUnretainedValue = contentType?.takeUnretainedValue() {
                        contentTypeString = takeUnretainedValue as String
                    }
                }
            }
            contentInformationRequest?.contentType = contentTypeString
            contentInformationRequest?.contentLength = contentLength
            contentInformationRequest?.isByteRangeAccessSupported = isByteRangeAccessSupported
        }
        
        func getContentTypeString(mimeType: String?) -> String? {
            var contentTypeString: String?
            if let mimeType = mimeType {
                let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
                if let takeUnretainedValue = contentType?.takeUnretainedValue() {
                    contentTypeString = takeUnretainedValue as String
                }
            }
            return contentTypeString
        }
        
        func haveEnoughDataToFulfillRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
            
            let requestedOffset = Int(dataRequest.requestedOffset)
            let requestedLength = dataRequest.requestedLength
            let currentOffset = Int(dataRequest.currentOffset)
            
            guard let songDataUnwrapped = mediaData,
                songDataUnwrapped.count > currentOffset else {
                // Don't have any data at all for this request.
                return false
            }
            
            let bytesToRespond = min(songDataUnwrapped.count - currentOffset, requestedLength)
            let dataToRespond = songDataUnwrapped.subdata(in: Range(uncheckedBounds: (currentOffset, currentOffset + bytesToRespond)))
            dataRequest.respond(with: dataToRespond)
            
            return songDataUnwrapped.count >= requestedLength + requestedOffset
            
        }
        
        deinit {
            session?.invalidateAndCancel()
        }
        
    }
    
    fileprivate let resourceLoaderDelegate = ResourceLoaderDelegate()
    let url: URL
    fileprivate let initialScheme: String?
    fileprivate var customFileExtension: String?
    
    weak var delegate: CachingPlayerItemDelegate?
    
    open func download() {
        if resourceLoaderDelegate.session == nil {
//            resourceLoaderDelegate.startDataRequest(with: url)
        }
    }
    
    private let cachingPlayerItemScheme = "cachingPlayerItemScheme"
    
    /// Is used for playing remote files.
    convenience init(url: URL) {
        self.init(url: url, customFileExtension: nil)
    }
    
    /// Override/append custom file extension to URL path.
    /// This is required for the player to work correctly with the intended file type.
    init(url: URL, customFileExtension: String?) {
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              var urlWithCustomScheme = url.withScheme(cachingPlayerItemScheme) else {
            fatalError("Urls without a scheme are not supported")
        }
        
        self.url = url
        self.initialScheme = scheme
        
        if let ext = customFileExtension {
            urlWithCustomScheme.deletePathExtension()
            urlWithCustomScheme.appendPathExtension(ext)
            self.customFileExtension = ext
        }
        
        let asset = AVURLAsset(url: urlWithCustomScheme)
        asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: DispatchQueue.main)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        self.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        resourceLoaderDelegate.owner = self
        
        //        addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        //
        //        NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledHandler), name:NSNotification.Name.AVPlayerItemPlaybackStalled, object: self)
        
    }
    
    /// Is used for playing from Data.
    init(data: Data, mimeType: String, fileExtension: String) {
        guard let fakeUrl = URL(string: cachingPlayerItemScheme + "://whatever/file.\(fileExtension)") else {
            fatalError("internal inconsistency")
        }
        
        self.url = fakeUrl
        self.initialScheme = nil
        
        resourceLoaderDelegate.mediaData = data
        resourceLoaderDelegate.playingFromData = true
        resourceLoaderDelegate.mimeType = mimeType
        
        let asset = AVURLAsset(url: fakeUrl)
        asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: DispatchQueue.main)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        resourceLoaderDelegate.owner = self
        
        //        addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
        //
        //        NotificationCenter.default.addObserver(self, selector: #selector(playbackStalledHandler), name:NSNotification.Name.AVPlayerItemPlaybackStalled, object: self)
        
    }
    
    // MARK: KVO
    
    //    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    //        delegate?.playerItemReadyToPlay?(self)
    //    }
    
    // MARK: Notification hanlers
    
    //    @objc func playbackStalledHandler() {
    //        delegate?.playerItemPlaybackStalled?(self)
    //    }
    
    // MARK: -
    
    override init(asset: AVAsset, automaticallyLoadedAssetKeys: [String]?) {
        fatalError("not implemented")
    }
    
    deinit {
        //        NotificationCenter.default.removeObserver(self)
        //        removeObserver(self, forKeyPath: "status")
        resourceLoaderDelegate.session?.invalidateAndCancel()
    }
    
}
