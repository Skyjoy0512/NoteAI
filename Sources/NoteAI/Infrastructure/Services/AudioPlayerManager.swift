import AVFoundation
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// 音声ファイル再生を管理するクラス
@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            updatePlaybackRate()
        }
    }
    @Published var isLoading = false
    @Published var error: AudioPlayerError?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    #if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
    #endif
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        // 同期的なクリーンアップを実行
        audioPlayer?.stop()
        audioPlayer = nil
        timer?.invalidate()
        timer = nil
        
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session in deinit: \(error)")
        }
        #endif
    }
    
    // MARK: - Public Methods
    
    /// 音声ファイルを読み込んで再生準備
    func loadAudio(from url: URL) {
        isLoading = true
        error = nil
        
        Task {
            do {
                cleanupPlayer()
                
                // オーディオセッション設定
                #if os(iOS)
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                #endif
                
                // プレイヤー初期化
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                
                self.audioPlayer = player
                self.duration = player.duration
                self.currentTime = 0
                self.isLoading = false
                
                updatePlaybackRate()
                
            } catch {
                self.error = .loadFailed(error)
                self.isLoading = false
            }
        }
    }
    
    /// 再生/一時停止を切り替え
    func togglePlayPause() {
        guard audioPlayer != nil else {
            error = .playerNotReady
            return
        }
        
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// 再生開始
    func play() {
        guard let player = audioPlayer else {
            error = .playerNotReady
            return
        }
        
        player.play()
        isPlaying = true
        startTimer()
    }
    
    /// 一時停止
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    /// 停止
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    /// 指定位置にシーク
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else {
            error = .playerNotReady
            return
        }
        
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
    }
    
    /// 15秒早送り
    func skipForward() {
        let newTime = currentTime + 15
        seek(to: newTime)
    }
    
    /// 15秒巻き戻し
    func skipBackward() {
        let newTime = currentTime - 15
        seek(to: newTime)
    }
    
    /// 再生速度を設定
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = max(0.5, min(2.0, speed))
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
        } catch {
            self.error = .audioSessionFailed(error)
        }
        #endif
    }
    
    private func updatePlaybackRate() {
        audioPlayer?.rate = Float(playbackSpeed)
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        
        // 再生終了チェック
        if currentTime >= duration && isPlaying {
            playbackDidFinish()
        }
    }
    
    private func playbackDidFinish() {
        isPlaying = false
        currentTime = 0
        audioPlayer?.currentTime = 0
        stopTimer()
    }
    
    private func cleanupPlayer() {
        stop()
        audioPlayer = nil
        
        #if os(iOS)
        do {
            try audioSession.setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        #endif
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                playbackDidFinish()
            } else {
                error = .playbackFailed
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.error = .decodeFailed(error)
        }
    }
}

// MARK: - Error Types

enum AudioPlayerError: LocalizedError, Equatable {
    case loadFailed(Error)
    case playerNotReady
    case playbackFailed
    case decodeFailed(Error?)
    case audioSessionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "音声ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        case .playerNotReady:
            return "プレイヤーの準備ができていません"
        case .playbackFailed:
            return "再生に失敗しました"
        case .decodeFailed(let error):
            return "音声のデコードに失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
        case .audioSessionFailed(let error):
            return "オーディオセッションの設定に失敗しました: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: AudioPlayerError, rhs: AudioPlayerError) -> Bool {
        switch (lhs, rhs) {
        case (.loadFailed, .loadFailed),
             (.playerNotReady, .playerNotReady),
             (.playbackFailed, .playbackFailed),
             (.decodeFailed, .decodeFailed),
             (.audioSessionFailed, .audioSessionFailed):
            return true
        default:
            return false
        }
    }
}