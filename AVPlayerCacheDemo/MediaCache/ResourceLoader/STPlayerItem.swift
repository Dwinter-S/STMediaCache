//
//  STPlayerItem.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation
import AVFoundation

protocol STPlayerItemDelegate: AnyObject {
    func loadUrl(_ url: URL, didFailWithError error: Error?)
}

func synced(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

fileprivate extension URL {
    func withScheme(_ scheme: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        return components?.url
    }
}


class STPlayerItem: AVPlayerItem {
    
    weak var delegate: STPlayerItemDelegate?
    var loaders = [String : STAssetResourceLoader]()
    
    let cacheScheme = "STMediaCache"
    let initialURL: URL
    
    var cachedData: Data?
    
    init(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let _ = components.scheme,
              let urlWithCustomScheme = url.withScheme(cacheScheme) else {
            fatalError("Urls without a scheme are not supported")
        }
        self.initialURL = url
        let asset = AVURLAsset(url: urlWithCustomScheme)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        canUseNetworkResourcesForLiveStreamingWhilePaused = true
    }
    
    func clearCache() {
        loaders.removeAll()
    }
    
    func cancelLoaders() {
        loaders.values.forEach({ $0.cancel() })
        loaders.removeAll()
    }
}

extension STPlayerItem: AVAssetResourceLoaderDelegate {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let cachedData = cachedData {
            
        } else if let url = loadingRequest.request.url,
                  url.absoluteString.hasPrefix(cacheScheme) {
            var loader: STAssetResourceLoader? = loaders[url.absoluteString]
            if loader == nil {
                loader = STAssetResourceLoader(url: initialURL)
                //                loader?.delegate = self
                loaders[url.absoluteString] = loader
            }
            loader?.addRequest(loadingRequest)
        }
        
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        if let url = loadingRequest.request.url,
           let loader = loaders[url.absoluteString] {
            loader.removeRequest(loadingRequest)
        }
        
        print("STPlayerItem: loadingRequest didCancel")
    }
}

//extension STPlayerItem: ResourceLoaderDelegate {
//    func didFail(resourceLoader: ResourceLoader, error: Error?) {
//        resourceLoader.cancel()
//        delegate?.loadUrl(resourceLoader.url, didFailWithError: error)
//    }
//}
