//
//  HCPVideoPlayer.swift
//  ieltsbro-ios-v4
//
//  Created by Sven on 2022/3/7.
//

import Foundation
import AVFoundation
import UIKit

class HCPVideoPlayerBaseView: BaseView {
    
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    
//    var player: AVPlayer? {
//        get { playerLayer.player }
//        set { playerLayer.player = newValue }
//    }
    let player: HCPAudioPlayer
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    var playingURLString: String?
    
    init(player: HCPAudioPlayer = HCPAudioPlayer.playerWithReuseIdentifier("HCP_Video")) {
        self.player = player
        super.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setVideoURL(_ urlString: String?) {
        guard let url = URL(string: urlString ?? "") else { return }
        self.playingURLString = urlString
        player.play(url: url)
    }
    
    func playOrPause() {
        guard let url = URL(string: playingURLString ?? "") else { return }
        if player.url == url {
            if player.state == .paused {
                player.resume()
            } else if player.state == .playing || player.state == .buffering { 
                player.pause()
            }
        } else {
            player.play(url: url)
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if newSuperview == nil {
            player.stop()
        }
    }
    
    override func setupUI() {
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.contentsGravity = .resizeAspect
        playerLayer.player = player.player
    }
    
    override func setupConstraints() {
        
    }
    
    override func setupBindViewModel() {
//        NotificationCenter.default.rx.notification(UIApplication.willEnterForegroundNotification, object: nil)
//            .subscribe(onNext: { [weak self] noti in
//                guard let self = self else { return }
//                self.playerLayer.player = self.player.player
//            })
//            .disposed(by: disposeBag)
//
//        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification, object: nil)
//            .subscribe(onNext: { [weak self] noti in
//                guard let self = self else { return }
//                self.playerLayer.player = nil
//            })
//            .disposed(by: disposeBag)
    }
    
    override func setupBindView() {
        
    }
    
}

