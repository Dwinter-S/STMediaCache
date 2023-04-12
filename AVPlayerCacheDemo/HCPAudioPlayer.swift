//
//  HCPAudioPlayer.swift
//  IeltsBroV3
//
//  Created by Steve on 2019/11/4.
//  Copyright © 2019 HCP. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import RxRelay
import RxSwift
import Then
import CoreServices

protocol HCPAudioPlayerDelegate: AnyObject {
    func playerIsReadyToPlay()
    func didFailPlay(error: Error)
    func playbackLikelyToKeepUp()
    func loadedTimeRangeDidChange(duration: CGFloat)
    func playbackBufferEmpty()
    func playerTimeDidChanged(time: Double)
    func playerDidPlayToEnd()
    func playerStatusDidChanged(status: HCPAudioPlayer.State)
    func playerSeekFinished()
}

extension HCPAudioPlayerDelegate {
    func playerIsReadyToPlay() {}
    func didFailPlay(error: Error) {}
    func playbackLikelyToKeepUp() {}
    func loadedTimeRangeDidChange(duration: CGFloat) {}
    func playbackBufferEmpty() {}
    func playerTimeDidChanged(time: Double) {}
    func playerDidPlayToEnd() {}
    func playerStatusDidChanged(status: HCPAudioPlayer.State) {}
    func playerSeekFinished() {}
}

class HCPAudioPlayer: NSObject {
    
    static let shared = HCPAudioPlayer.playerWithReuseIdentifier("global")
    private static var reusedPlayers = [HCPAudioPlayer]()
    
    enum State {
        case playing
        case paused
        case buffering
        case stopped
        
        var name: String {
            switch self {
            case .playing: return "播放"
            case .paused: return "暂停"
            case .buffering: return "缓冲"
            case .stopped: return "停止"
            }
        }
    }
    
    // Observables
    let stateObservable = BehaviorRelay<State>(value: .stopped)
    let timeObservable = BehaviorRelay<Double>(value: 0)
    let loadedTimeRanges = BehaviorRelay<Double>(value: 0)
    let durationObservable = PublishSubject<Double>()
    let playerPrepareToPlay = PublishSubject<Void>()
    let playerIsReadyToPlay = PublishSubject<Void>()
    let playToEndObservable = PublishSubject<Void>()
    let playErrorObservable = PublishSubject<Error>()
    let playErrorInfoObservable = PublishSubject<String>()

    var isSeeking = false
    
    /// 是否正在播放
    private(set) var state: State = .stopped {
        didSet {
            stateObservable.accept(state)
        }
    }
    var currentTime: Double {
        let timeSecond = CMTimeGetSeconds(player.currentTime())
        return timeSecond
    }
    /// 时长
    private(set) var duration: Double = 0
    private(set) var rate: Float = 0
    private var outSetRate: Float = 1
    
    private(set) var player = AVPlayer().then {
        $0.actionAtItemEnd = .pause
    }
    weak var delegate: HCPAudioPlayerDelegate?
    
    private(set) var url: URL? {
        willSet {
            if url != nil {
                state = .stopped
            }
        }
        didSet {
            if let url = url {
                // !url.absoluteString.hasSuffix(".m3u8")
                if !url.isFileURL {
                    player.automaticallyWaitsToMinimizeStalling = false
                    let playerItem = STPlayerItem(url: url)
                    playerItem.audioTimePitchAlgorithm = .timeDomain
                    replacePlayerItem(with: playerItem)
                    
//                    HCPMediaCache.shared.getCache(with: url) { data in
//                        let playerItem: CachingPlayerItem
//                        if let data = data {
//                            playerItem = CachingPlayerItem(data: data, mimeType: self.mimeType(pathExtension: url.pathExtension), fileExtension: url.pathExtension)
//                        } else {
//                            playerItem = CachingPlayerItem(url: url)
//                        }
//                        playerItem.audioTimePitchAlgorithm = .timeDomain
//                        playerItem.delegate = self
//                        self.replacePlayerItem(with: playerItem)
//                    }
                } else {
                    player.automaticallyWaitsToMinimizeStalling = true
                    DispatchQueue.global().async {
                        let asset = AVURLAsset(url: url)
                        let playerItem = AVPlayerItem(asset: asset)
                        playerItem.audioTimePitchAlgorithm = .timeDomain
                        DispatchQueue.main.async {
                            self.replacePlayerItem(with: playerItem)
                        }
                    }
                }
            } else {
                replacePlayerItem(with: nil)
            }
        }
    }
    
    func mimeType(pathExtension: String) -> String {
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                           pathExtension as NSString,
                                                           nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?
                .takeRetainedValue() {
                return mimetype as String
            }
        }
        //文件资源类型如果不知道，传万能类型application/octet-stream，服务器会自动解析文件类
        return "application/octet-stream"
    }

    
    var isLooping: Bool = false
    private(set) var indentifier: Int?

    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    private var isPausedByUser = false
    private var isBuffering = false
    private lazy var playableBufferLength: Double = DefaultPlayableBufferLength
    private let DefaultPlayableBufferLength: Double = 2
    private(set) var isPlayToEnd = false
    
    private var playerItemContext = 0
    private var playerContext = 1
    private let requiredAssetKeys = [
        "playable",
        "hasProtectedContent"
    ]
    private var mediaServicesWereResetSeekToSecond: Double?
    private var mediaServicesWereResetAutoPlay = false
//    private let resourceLoaderManager = VIResourceLoaderManager()
    private let disposeBag = DisposeBag()
    
    private override init() {
        reuseIdentifier = ""
        super.init()
    }

    
    func cleanCacheIfNeeded() {
        HCPMediaCache.shared.cleanCache()
//        DispatchQueue.global().async {
//            var error: NSError?
//            let size = VICacheManager.calculateCachedSizeWithError(&error)
//            if size > 1 * 1024 * 1024 * 1024 {
//                VICacheManager.cleanAllCacheWithError(&error)
//            }
//        }
    }
    
    static func playerWithReuseIdentifier(_ reuseIdentifier: String) -> HCPAudioPlayer {
        if let player = reusedPlayers.first(where: { $0.reuseIdentifier ==  reuseIdentifier}) {
            return player
        }
        let newPlayer = HCPAudioPlayer(reuseIdentifier: reuseIdentifier)
        reusedPlayers.append(newPlayer)
        return newPlayer
    }
    
    let reuseIdentifier: String
    private init(reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init()
        cleanCacheIfNeeded()
        setupPlayer()
        setupRemoteTransportControls()
        
//        SystemNotificationManager.shared.isHeadphonesUnavailable
//            .subscribe(onNext: { [weak self] _ in
//                guard let `self` = self else { return }
//                self.pause(byUser: false)
//            }).disposed(by: disposeBag)
//
//        SystemNotificationManager.shared.mediaServicesWereReset
//            .subscribe(onNext: { [weak self] _ in
//                guard let `self` = self else { return }
//                self.resetPlayer()
//                if self.mediaServicesWereResetSeekToSecond != nil {
//                    let url = self.url
//                    self.url = url
//                }
//            }).disposed(by: disposeBag)
//
//        SystemNotificationManager.shared.mediaServicesWereLost
//            .subscribe(onNext: { [weak self] _ in
//                guard let `self` = self else { return }
//                /// 如果媒体服务器崩溃前正在播放，则恢复后自动继续播放
//                if self.timeObservable.value > 0 {
//                    self.mediaServicesWereResetAutoPlay = self.state == .playing
//                    self.mediaServicesWereResetSeekToSecond = self.timeObservable.value
//                }
//            }).disposed(by: disposeBag)
//
//        SystemNotificationManager.shared.audioSessionInterruptionType
//            .subscribe(onNext: { [weak self] interruptionType in
//                guard let `self` = self else { return }
//                if interruptionType == .ended && !self.isPausedByUser {
//                    self.play()
//                }
//            }).disposed(by: disposeBag)
//
//        NotificationManager.shared.startPlayWithReuseIdentifier
//            .subscribe(onNext: { [weak self] indentifier in
//                guard let self = self else { return }
//                if indentifier != self.reuseIdentifier {
//                    self.pause(byUser: false)
//                }
//            }).disposed(by: disposeBag)
    }
    
    deinit {
        replacePlayerItem(with: nil)
        removeTimeObserver()
        removePlayerObservers()
    }
    
    private func replacePlayerItem(with playerItem: AVPlayerItem?) {
        isPlayToEnd = false
        isPausedByUser = false
        isBuffering = false
        playableBufferLength = DefaultPlayableBufferLength
        if let preItem = self.playerItem {
            removePlayerItemObserver(for: preItem)
        }
        self.playerItem = playerItem
        if let currentItem = playerItem {
            addPlayerItemObserver(for: currentItem)
        } else {
            state = .stopped
            outSetRate = 1
        }
//        resourceLoaderManager.cancelLoaders()
        player.replaceCurrentItem(with: playerItem)
//        setupNowPlayingInfo(title: "口语")
    }
    
    private func resetPlayer() {
        removeTimeObserver()
        removePlayerObservers()
        player = AVPlayer()
        setupPlayer()
    }
    
    private func removeTimeObserver() {
        guard let observer = timeObserver else { return }
        player.removeTimeObserver(observer)
        timeObserver = nil
    }
    
    private func removePlayerObservers() {
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), context: &playerContext)
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay), context: &playerContext)
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status), context: &playerContext)
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate), context: &playerContext)
    }
    
    private func removePlayerItemObserver(for playerItem: AVPlayerItem) {
        playerItem.cancelPendingSeeks()
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerItemContext)
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), context: &playerItemContext)
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), context: &playerItemContext)
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp), context: &playerItemContext)
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), context: &playerItemContext)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemNewErrorLogEntry, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    
    /// 初始化
    /// - Parameter isLooping: 是否循环播放，播放结束后自动跳转到开始位置重新播放
//    convenience init(isLooping: Bool) {
//        self.init()
//        self.isLooping = isLooping
//    }
    
    private func setupPlayer() {
        player.actionAtItemEnd = .pause
        addTimeObserver()
        addPlayerObservers()
    }
    
    private func addTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.01, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let timeSecond = CMTimeGetSeconds(time)
            self.delegate?.playerTimeDidChanged(time: timeSecond)
            self.timeObservable.accept(timeSecond)
        }
    }
    
    private func addPlayerObservers() {
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: .new, context: &playerContext)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: .new, context: &playerContext)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay), options: .new, context: &playerContext)
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: .new, context: &playerContext)
    }
    
    private func addPlayerItemObserver(for playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), options: .new, context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), options: .new, context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp), options: .new, context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), options: .new, context: &playerItemContext)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemNewErrorLog), name: NSNotification.Name.AVPlayerItemNewErrorLogEntry, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player.rate == 0.0 {
                self.play()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player.rate == 1.0 {
                self.player.pause()
                return .success
            }
            return .commandFailed
        }
    }
    
//    private func setupNowPlayingInfo(title: String) {
//        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyAlbumTitle : title,
//                                                     MPMediaItemPropertyPlaybackDuration : 200,
//                                                               MPMediaItemPropertyArtist : "雅思哥",
//                                                               MPMediaItemPropertyTitle : "title",
//                                                              MPMediaItemPropertyAssetURL: URL(string: "https://static.ieltsbro.com/base_service/base/advert/1659405972961.png")!,
//                                                              MPMediaItemPropertyArtwork : MPMediaItemArtwork(boundsSize: CGSize(width: 50, height: 50), requestHandler: { _ in
//            return UIImage(named: "mine_logo")!
//        })]
//        if #available(iOS 13.0, *) {
//            MPNowPlayingInfoCenter.default().playbackState = .playing
//        } else {
//            // Fallback on earlier versions
//        }
//    }
    
    private func setAudioSession() {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            configAudioSession()
        }
        do {
            try session.setActive(true)
        } catch {
            let errorInfo = "AudioSession error: \((error as NSError).description)"
            playErrorInfoObservable.onNext(errorInfo)
            print(errorInfo)
        }
    }
    
    /// 设置音频配置
    func configAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 设置类别,表示该应用同时支持播放和录音
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @objc private func playerItemDidPlayToEndTime(notification: Notification) {
        if let item = notification.object as? AVPlayerItem, item !== player.currentItem {
            return
        }
        delegate?.playerDidPlayToEnd()
        isPlayToEnd = true
        playToEndObservable.onNext(())
        if isLooping {
            replay()
        }
    }
    
    @objc private func playerItemNewErrorLog(notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem else {
            return
        }
        guard let errorLog: AVPlayerItemErrorLog = playerItem.errorLog() else {
            return
        }
        for event in errorLog.events {
            print("AVPlayerItemErrorLog: \(event.errorComment ?? "")")
        }
    }
    
    @objc private func playerItemFailedToPlayToEndTime(notification: Notification) {
        if let error = notification.userInfo?["AVPlayerItemFailedToPlayToEndTimeErrorKey"] as? NSError {
            let errorInfo = "AVPlayerItemFailedToPlayToEndTimeError: \(error.description)"
            playErrorInfoObservable.onNext(errorInfo)
            print(errorInfo)
        }
    }
    
    
    /// 重新播放
    func replay() {
        seekTo(time: 0, completionHandler: { [weak self] in
            self?.isPlayToEnd = false
            self?.play()
        })
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &playerItemContext {
            if keyPath == #keyPath(AVPlayerItem.duration) {
                if let newDuration = change?[NSKeyValueChangeKey.newKey] as? CMTime {
                    duration = CMTimeGetSeconds(newDuration)
                    durationObservable.onNext(duration)
                }
            }
            
            if keyPath == #keyPath(AVPlayerItem.status) {
                let oldStatus: AVPlayerItem.Status
                let newStatus: AVPlayerItem.Status
                if let statusNumber = change?[.newKey] as? Int {
                    newStatus = AVPlayerItem.Status(rawValue: statusNumber)!
                } else {
                    newStatus = .unknown
                }
                if let statusNumber = change?[.oldKey] as? Int {
                    oldStatus = AVPlayerItem.Status(rawValue: statusNumber)!
                } else {
                    oldStatus = .unknown
                }
                if oldStatus != newStatus {
                    switch newStatus {
                    case .unknown: ()
                    case .readyToPlay:
                        delegate?.playerIsReadyToPlay()
                        playerIsReadyToPlay.onNext(())
                        // 媒体服务器崩溃继续播放
                        if let mediaServicesWereResetSeekToSecond = mediaServicesWereResetSeekToSecond {
                            seekTo(time: mediaServicesWereResetSeekToSecond, isAutoPlay: mediaServicesWereResetAutoPlay)
                            self.mediaServicesWereResetSeekToSecond = nil
                        } else {
                            play()
//                            if let playerItem = playerItem {
//                                enableAudioTracks(true, in: playerItem)
//                            }
                        }
                    case .failed:
                        var error: Error
                        print("????\(player.currentItem?.errorLog())")
                        if let err = player.currentItem?.error {
                            error = err
                        } else {
                            error = NSError(domain: "kVideoPlayerErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : "unknown player error, status == AVPlayerItemStatusFailed"])
                        }
                        let nserror = error as NSError
                        let errorInfo = "playerItemError: description = \(nserror.description)"
                        print("Video playerItem Status Failed: error = \(errorInfo)")
                        delegate?.didFailPlay(error: error)
                        playErrorObservable.onNext(error)
                        /// 网络错误
                        if nserror.domain == NSURLErrorDomain {
                            playErrorInfoObservable.onNext(errorInfo)
                            url = nil
//                            SceneCoordinator.shared.transition(to: Scene.hud(.showMessage("网络连接异常")))
                        } else {
                            if nserror.domain == AVFoundationErrorDomain && nserror.code == -11819 {
                                // 媒体服务器崩溃会继续播放
                            } else {
                                playErrorInfoObservable.onNext(errorInfo)
                                url = nil
//                                SceneCoordinator.shared.transition(to: Scene.hud(.showMessage("音频播放异常")))
                            }
                        }
                    default:()
                    }
                } else if newStatus == .readyToPlay {
                    delegate?.playbackLikelyToKeepUp()
                }
            }
            
            if keyPath == #keyPath(AVPlayerItem.loadedTimeRanges) {
                // 计算缓冲进度
                let loadedDuration = getLoadedDuration()
//                if state == .playing && player.rate == 0 {
//                    if loadedDuration >= CMTimeGetSeconds(player.currentTime()) + playableBufferLength {
//                        playableBufferLength *= 2
//                        if playableBufferLength > 64 {
//                            playableBufferLength = 64
//                        }
//                        player.play()
//                    }
//                }
                loadedTimeRanges.accept(loadedDuration)
                delegate?.loadedTimeRangeDidChange(duration: CGFloat(loadedDuration))
            }
            
            if keyPath == #keyPath(AVPlayerItem.isPlaybackBufferEmpty) {
                if player.currentItem?.isPlaybackBufferEmpty == true, state == .playing {
                    delegate?.playbackBufferEmpty()
                }
            }
            
            if keyPath == #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp) {
                if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                    delegate?.playbackLikelyToKeepUp()
                }
            }
        } else if context == &playerContext {
            if keyPath == #keyPath(AVPlayer.timeControlStatus) ||
                keyPath == #keyPath(AVPlayer.reasonForWaitingToPlay) {
                setPlayerStatus()
            }
            if keyPath == #keyPath(AVPlayer.rate) {
                rate = player.rate
            }
        }
    }
    
    private func setPlayerStatus() {
        var newState: State?
        switch player.timeControlStatus {
        case .playing:
            newState = .playing
            isPausedByUser = false
//            NotificationManager.shared.startPlayWithReuseIdentifier.onNext(reuseIdentifier)
        case .waitingToPlayAtSpecifiedRate:
//            if !isPausedByUser {
//                state = .buffering
//            }
            if player.reasonForWaitingToPlay == AVPlayer.WaitingReason.toMinimizeStalls || player.reasonForWaitingToPlay == AVPlayer.WaitingReason.evaluatingBufferingRate {
                newState = .buffering
            }
        case .paused:
            if state == .playing {
                newState = .paused
            }
        @unknown default: ()
        }
        if let newState = newState {
            state = newState
            delegate?.playerStatusDidChanged(status: state)
        }
    }
    
    // 缓冲时间
    private func getLoadedDuration() -> TimeInterval {
        guard let timeRange = player.currentItem?.loadedTimeRanges.first as? CMTimeRange else { return 0 }
        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        return startSeconds + durationSeconds
    }
    
//    private func bufferingSomeSecond() {
//        if isBuffering { return }
//        isBuffering = true
//        player.pause()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            if self.isPausedByUser {
//                self.isBuffering = false
//                return
//            }
//            self.player.play()
//            self.isBuffering = false
//            if self.player.currentItem?.isPlaybackLikelyToKeepUp == true {
//                self.bufferingSomeSecond()
//            }
//        }
//
//    }

    /// 检测后播放
    /// - Parameters:
    ///   - url: url地址
    ///   - indentifier: 录音唯一标识符
    ///   - userId: 录音用户id
    ///   - oralId: 录音id
    ///   - checkStatus: 录音播放前的检测状态，默认为待检测
//    func playWithCheck(url: URL, indentifier: Int? = nil, userId: String?, oralId: String?, checkStatus: RecordingCheckStatus? = nil) {
//        guard let userId = userId, let oralId = oralId else {
//            play(url: url, indentifier: indentifier)
//            return
//        }
//        if userId == AccountManager.shared.current?.userId {
//            play(url: url, indentifier: indentifier)
//        } else {
//            let status = checkStatus ?? .ready
//            switch status {
//            case .ready:
//                Networking.request(api: .checkRecordingStatus(oralId: oralId, userId: userId))
//                    .subscribe(onNext: { [weak self] (result: Result<Bool?, HCPError>) in
//                        guard let self = self else { return }
//                        switch result {
//                        case let .success(rsp):
//                            let isPassed = rsp ?? false
//                            if isPassed {
//                                self.play(url: url, indentifier: indentifier)
//                            } else {
//                                SceneCoordinator.shared.transition(to: Scene.hud(.showMessage("录音无法播放")))
//                            }
//                        case .error: ()
//                        }
//                    }).disposed(by: disposeBag)
//            case .passed:
//                play(url: url, indentifier: indentifier)
//            case .failed:
//                SceneCoordinator.shared.transition(to: Scene.hud(.showMessage("录音无法播放")))
//            }
//        }
//    }
    
    /// 使用URL播放
    /// - Parameter url: 播放的URL
    /// - Parameter indentifier: 当前播放的标识，如果有两个视图同时播放同一个URL，根据这个标识来判断正在播放的是哪一个
    func play(url: URL, indentifier: Int? = nil) {
        setAudioSession()
        self.url = url
        self.indentifier = indentifier
        playerPrepareToPlay.onNext(())
    }
    
    /// 恢复播放
    func resume() {
        guard let currentItem = player.currentItem, currentItem.status == .readyToPlay, state == .paused else {
            return
        }
        if isPlayToEnd {
            replay()
        } else {
            play()
        }
    }
    
    private func play() {
        DispatchQueue.main.async {
            self.player.playImmediately(atRate: self.outSetRate)
        }
    }
    
    func pause(byUser: Bool = true) {
        guard let currentItem = player.currentItem, currentItem.status == .readyToPlay, state == .playing else {
            return
        }
        isPausedByUser = byUser
        player.pause()
    }
    
    func stop() {
        self.url = nil
        self.indentifier = nil
    }
    
    func setRate(_ rate: Float) {
        outSetRate = rate
        guard let currentItem = player.currentItem, state == .playing else { return }
        if rate == 1 ||
            (rate > 1 && currentItem.canPlayFastForward) ||
            (rate < 1 && currentItem.canPlaySlowForward) {
            play()
            print("设置播放速率:\(rate)")
        } else {
            print("不支持的播放速率:\(rate)")
        }
        
    }
    
    func duration(with urlString: String?) -> Double {
        guard let urlString = urlString else { return 0 }
        var asset: AVURLAsset
        let dic = [AVURLAssetPreferPreciseDurationAndTimingKey : false]
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            if let url = URL(string: urlString) {
                asset = AVURLAsset(url: url, options: dic)
            } else {
                return 0
            }
        } else {
            asset = AVURLAsset(url: URL(fileURLWithPath: urlString), options: dic)
        }
        let duration = asset.duration
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isNormal else {
            return 0
        }
        return seconds
    }
    
    /// seek到指定位置
    /// - Parameter time: seek到的时间
    /// - Parameter isAutoPlay: 是否seek后自动播放
    /// - Parameter completionHandler: seek完成后的回调
    func seekTo(time: Double, isAutoPlay: Bool = false, completionHandler: (() -> Void)? = nil) {
        print("seekTo:\(time)")
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        guard let playerItem = player.currentItem,
                playerItem.status == .readyToPlay,
                CMTIME_IS_VALID(cmTime) else {
            return
        }
        isSeeking = true
        let loadedTimeRanges = playerItem.loadedTimeRanges as! [CMTimeRange]
        var isLoaded = false
        for loadedTimeRange in loadedTimeRanges {
            if loadedTimeRange.containsTime(cmTime) {
                isLoaded = true
                break
            }
        }
        if !isLoaded {
            player.pause()
            state = .buffering
        }
        let isPlayingBeforeSeek = state == .playing || state == .buffering
        player.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] finished in
            guard let self = self, finished else { return }
            self.isSeeking = false
            if isAutoPlay || isPlayingBeforeSeek {
                self.play()
            }
            self.delegate?.playerSeekFinished()
            completionHandler?()
        }
    }
    
    func enableAudioTracks(_ enable: Bool, in playerItem: AVPlayerItem) {
        for track in playerItem.tracks {
            if track.assetTrack?.mediaType == .audio {
                track.isEnabled = enable
            }
        }
    }
    
}


extension HCPAudioPlayer: CachingPlayerItemDelegate {
    func playerItem(_ playerItem: CachingPlayerItem, didFinishDownloadingData data: Data) {
        // A track is downloaded. Saving it to the cache asynchronously.
//        print("didFinishDownloadingData")
//        HCPMediaCache.shared.setCache(data: data, with: playerItem.url)
    }
}
