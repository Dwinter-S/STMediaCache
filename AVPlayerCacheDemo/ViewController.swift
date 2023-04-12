//
//  ViewController.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/3/30.
//

import UIKit

class ViewController: UIViewController {

//    let player = HCPAudioPlayer.shared
    private lazy var player = HCPAudioPlayer.playerWithReuseIdentifier("HCP_Video_Cell").then {
        $0.isLooping = true
    }
    lazy var playerView = HCPVideoPlayerBaseView(player: player)
    
    let button = UIButton()
    var curIndex = 0
    let urls = ["http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Emily-%E5%8F%A3%E8%AF%ADPart%201%E5%A6%82%E4%BD%95%E8%8E%B7%E5%BE%97%E8%80%83%E5%AE%98%E5%A5%BD%E6%84%9F.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Emily-%E5%8F%A3%E8%AF%ADPart%201%E9%99%A4%E4%BA%86because%E8%BF%98%E8%83%BD%E5%A6%82%E4%BD%95%E6%8B%93%E5%B1%95.mp4",
                "https://static.ieltsbro.com/apk/10.0.0/%E5%8F%A3%E8%AF%AD%E5%BD%95%E8%AF%BE%EF%BC%9AP2%E4%B8%B2%E9%A2%98.mp4",
                "https://static.ieltsbro.com/apk/10.0.0/%E5%8F%A3%E8%AF%AD%E5%BD%95%E8%AF%BE%EF%BC%9AP2%E7%9A%84%E2%80%9C%E5%81%A5%E8%B0%88%E2%80%9D%E6%8A%80%E5%B7%A70827.mp4",
                "https://static.ieltsbro.com/apk/10.0.0/%E5%8F%A3%E8%AF%AD%E5%BD%95%E8%AF%BE%EF%BC%9A%E8%AF%8D%E6%B1%87%E5%A4%9A%E6%A0%B7%E6%80%A7FINALFINAL.mp4",
                "https://static.ieltsbro.com/apk/10.0.0/%E5%8F%A3%E8%AF%AD%E5%BD%95%E8%AF%BE%EF%BC%9AP3%E8%BE%A9%E8%AE%BA%E5%9E%8B%E9%97%AE%E9%A2%98FINALFINAL.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Emily-%E5%8F%A3%E8%AF%ADPart%201%E7%AD%94%E9%A2%98%E6%80%9D%E8%B7%AF.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Emily-%E5%8F%A3%E8%AF%AD%E8%B0%9A%E8%AF%AD.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E5%9F%BA%E7%A1%80%E8%83%BD%E5%8A%9B%E6%8F%90%E5%8D%87%E6%96%B9%E6%B3%95.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E5%A4%9A%E9%80%89%E9%A2%98.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E6%B5%81%E7%A8%8B%E5%9B%BE.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E8%A1%A8%E6%A0%BC%E9%A2%98.mp4",
                "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E6%84%8F%E7%BE%A4.mp4",
                "https://video.ieltsbro.com/8cb3a1cc34fa4fca8491628c40b0f71c/4493d0dbce9c486189920f288ba4d5ea-ea46f0a493bc3ae64067a35dab78407d-ld.m3u8", "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E5%A4%9A%E9%80%89%E9%A2%98.mp4"].prefix(3)
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        let str = "https://static.ieltsbro.com/apk/10.0.0/2023-02-07%20210755.mp4"
//        let str = "https://video.ieltsbro.com/7b24ac75f98b42729b9b65bdaba31ffe/893ea0c4486747d8bc5f0b38fe11f2cf-ee36df538c23d1e900def6d45b9615e4-ld.mp4"
//        let str = "https://video.ieltsbro.com/e56d814b58c2464db9cc1523ee108ee3/aaf7fe1747a54709bbbfb5b0055db083-9d8babc282ed37910024e66da5a100d1-ld.mp4"
//        let str = "https://static.ieltsbro.com/uploads/app_oral_practice_comment/audio_record/1631016/record.mp3"
//        let str = "https://app-cdn.ieltsbro.com/uploads/app_english_definition/production/us_pronunciation/8436/dictvoice.mpga"
//        let str = "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E5%A4%9A%E9%80%89%E9%A2%98.mp4"
        
//    let str = "https://video.ieltsbro.com/8cb3a1cc34fa4fca8491628c40b0f71c/4493d0dbce9c486189920f288ba4d5ea-ea46f0a493bc3ae64067a35dab78407d-ld.m3u8"
        CacheManager.shared.cleanCache()
        player.play(url: URL(string: urls[0])!)
        // Do any additional setup after loading the view.
        view.addSubview(playerView)
        playerView.frame = CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: 180)
        
        button.setTitle("下一个", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.addTarget(self, action: #selector(playNext), for: .touchUpInside)
        view.addSubview(button)
        button.frame = CGRect(x: 0, y: 300, width:  100, height: 50)
    }
    
    @objc func playNext() {
        let count = urls.count
        curIndex += 1
        if curIndex == count {
            curIndex = 0
        }
        player.play(url: URL(string: urls[curIndex])!)
    }


}


//import AVKit
//import Cache
//
//class AudioPlayerWorker {
//    private var player: AVPlayer!
//
//    let diskConfig = DiskConfig(name: "DiskCache")
//    let memoryConfig = MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10)
//
//    lazy var storage: Cache.Storage? = {
//        return try? Cache.Storage(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: <#Transformer<_>#>)
//    }()
//
//    // MARK: - Logic
//
//    /// Plays a track either from the network if it's not cached or from the cache.
//    func play(with url: URL) {
//        // Trying to retrieve a track from cache asynchronously.
//        storage?.async.entry(ofType: Data.self, forKey: url.absoluteString, completion: { result in
//            let playerItem: CachingPlayerItem
//            switch result {
//            case .error:
//                // The track is not cached.
//                playerItem = CachingPlayerItem(url: url)
//            case .value(let entry):
//                // The track is cached.
//                playerItem = CachingPlayerItem(data: entry.object, mimeType: "audio/mpeg", fileExtension: "mp3")
//            }
//            playerItem.delegate = self
//            self.player = AVPlayer(playerItem: playerItem)
//            self.player.automaticallyWaitsToMinimizeStalling = false
//            self.player.play()
//        })
//    }
//
//}
//
//// MARK: - CachingPlayerItemDelegate
//extension AudioPlayerWorker: CachingPlayerItemDelegate {
//    func playerItem(_ playerItem: CachingPlayerItem, didFinishDownloadingData data: Data) {
//        // A track is downloaded. Saving it to the cache asynchronously.
//        storage?.async.setObject(data, forKey: playerItem.url.absoluteString, completion: { _ in })
//    }
//}
