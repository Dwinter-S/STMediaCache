//
//  STCachingPlayerItem.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/4.
//

import Foundation
import AVFoundation

protocol STCachingPlayerItemDelegate: AnyObject {
    func loadUrl(_ url: URL, didFailWithError error: Error?)
}

func synced(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

var date = Date()
func startTimer() {
    date = Date()
}

func endTimer() {
    print("?????\(Date().timeIntervalSince(date))")
}

fileprivate extension URL {
    func withScheme(_ scheme: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        return components?.url
    }
}

class STCachingPlayerItem: AVPlayerItem {
    
    weak var delegate: STCachingPlayerItemDelegate?
    var loaders = [String : AssetResourceLoader]()
    
    let cacheScheme = "STMediaCache"
    let initialURL: URL
    init(url: URL) {
        self.initialURL = url
        if url.pathExtension == "m3u8" {
            if let asset = STHLSManager.shared.localAsset(with: url) {
                super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
            } else {
                super.init(asset: AVURLAsset(url: url), automaticallyLoadedAssetKeys: nil)
                STHLSManager.shared.downloadStream(for: url)
            }
            return
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let _ = components.scheme,
              let urlWithCustomScheme = url.withScheme(cacheScheme) else {
            fatalError("Urls without a scheme are not supported")
        }
        let asset = AVURLAsset(url: urlWithCustomScheme)
        super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
        canUseNetworkResourcesForLiveStreamingWhilePaused = true
    }
    
}

extension STCachingPlayerItem: AVAssetResourceLoaderDelegate {
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let url = loadingRequest.request.url, url.scheme == cacheScheme else {
            return false
        }
        var loader: AssetResourceLoader? = loaders[url.absoluteString]
        if loader == nil {
            loader = AssetResourceLoader(url: initialURL)
            loaders[url.absoluteString] = loader
        }
        loader?.addRequest(loadingRequest)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        if let url = loadingRequest.request.url,
           let loader = loaders[url.absoluteString] {
            loader.removeRequest(loadingRequest)
        }
    }
}
