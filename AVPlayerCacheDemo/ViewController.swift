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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let str = "https://static.ieltsbro.com/apk/10.0.0/2023-02-07%20210755.mp4"
//        let str = "https://video.ieltsbro.com/7b24ac75f98b42729b9b65bdaba31ffe/893ea0c4486747d8bc5f0b38fe11f2cf-ee36df538c23d1e900def6d45b9615e4-ld.mp4"
//        let str = "https://video.ieltsbro.com/e56d814b58c2464db9cc1523ee108ee3/aaf7fe1747a54709bbbfb5b0055db083-9d8babc282ed37910024e66da5a100d1-ld.mp4"
//        let str = "https://static.ieltsbro.com/uploads/app_oral_practice_comment/audio_record/1631016/record.mp3"
//        let str = "https://app-cdn.ieltsbro.com/uploads/app_english_definition/production/us_pronunciation/8436/dictvoice.mpga"
//        let str = "http://ieltsbro.oss-cn-beijing.aliyuncs.com/apk/10.0.0/Annie-%E5%90%AC%E5%8A%9B%E5%A4%9A%E9%80%89%E9%A2%98.mp4"
        player.play(url: URL(string: str)!)
        // Do any additional setup after loading the view.
        view.addSubview(playerView)
        playerView.frame = CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: 180)
        print("?????\(CacheManager.shared.cacheDirectory.absoluteString)")
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
