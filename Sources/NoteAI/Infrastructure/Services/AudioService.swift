import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol AudioServiceProtocol {
    func startRecording(settings: RecordingSettings) async throws -> AudioSession
    func pauseRecording() async throws
    func resumeRecording() async throws
    func stopRecording() async throws -> URL
    func getCurrentLevel() -> Float
    func requestMicrophonePermission() async -> Bool
}

class AudioService: NSObject, AudioServiceProtocol {
    private var audioRecorder: AVAudioRecorder?
    #if os(iOS)
    private var audioSession: AVAudioSession
    #endif
    private var recordingTimer: Timer?
    private var currentAudioLevel: Float = 0.0
    private var isRecordingPaused = false
    
    override init() {
        #if os(iOS)
        self.audioSession = AVAudioSession.sharedInstance()
        #endif
        super.init()
    }
    
    func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #else
        // macOSでは自動的にマイクアクセスが許可される
        return true
        #endif
    }
    
    func startRecording(settings: RecordingSettings) async throws -> AudioSession {
        // 1. マイクアクセス許可確認
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw AudioServiceError.microphonePermissionDenied
        }
        
        // 2. オーディオセッション設定
        #if os(iOS)
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        #endif
        
        // 3. 録音設定
        let recordingSettings = buildRecordingSettings(from: settings)
        
        // 4. ファイルURL生成
        let audioFilename = generateAudioFileName(format: settings.format)
        
        // 5. 録音開始
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: recordingSettings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        
        guard audioRecorder?.record() == true else {
            throw AudioServiceError.recordingStartFailed
        }
        
        // 6. 音声レベル監視開始
        startAudioLevelMonitoring()
        
        let session = AudioSession(
            fileURL: audioFilename,
            startTime: Date(),
            settings: settings
        )
        
        return session
    }
    
    func pauseRecording() async throws {
        guard let recorder = audioRecorder, recorder.isRecording else {
            throw AudioServiceError.notRecording
        }
        
        recorder.pause()
        isRecordingPaused = true
        stopAudioLevelMonitoring()
    }
    
    func resumeRecording() async throws {
        guard let recorder = audioRecorder, isRecordingPaused else {
            throw AudioServiceError.notPaused
        }
        
        guard recorder.record() else {
            throw AudioServiceError.recordingResumeFailed
        }
        
        isRecordingPaused = false
        startAudioLevelMonitoring()
    }
    
    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder else {
            throw AudioServiceError.notRecording
        }
        
        stopAudioLevelMonitoring()
        
        let url = recorder.url
        recorder.stop()
        
        // オーディオセッション非アクティブ化
        #if os(iOS)
        try audioSession.setActive(false)
        #endif
        
        audioRecorder = nil
        isRecordingPaused = false
        
        return url
    }
    
    func getCurrentLevel() -> Float {
        return currentAudioLevel
    }
    
    // MARK: - Private Methods
    
    private func buildRecordingSettings(from settings: RecordingSettings) -> [String: Any] {
        var recordingSettings: [String: Any] = [:]
        
        switch settings.format {
        case .m4a:
            recordingSettings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
        case .wav:
            recordingSettings[AVFormatIDKey] = Int(kAudioFormatLinearPCM)
            recordingSettings[AVLinearPCMBitDepthKey] = 16
            recordingSettings[AVLinearPCMIsBigEndianKey] = false
            recordingSettings[AVLinearPCMIsFloatKey] = false
        case .mp3:
            recordingSettings[AVFormatIDKey] = Int(kAudioFormatMPEGLayer3)
        case .aac:
            recordingSettings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
        case .flac:
            recordingSettings[AVFormatIDKey] = Int(kAudioFormatFLAC)
        }
        
        recordingSettings[AVSampleRateKey] = settings.quality.sampleRate
        recordingSettings[AVNumberOfChannelsKey] = 1
        recordingSettings[AVEncoderAudioQualityKey] = settings.quality.avQuality
        
        if settings.format == .m4a || settings.format == .mp3 || settings.format == .aac {
            recordingSettings[AVEncoderBitRateKey] = settings.quality.bitRate
        }
        
        return recordingSettings
    }
    
    private func generateAudioFileName(format: AudioFormat) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "recording_\(timestamp).\(format.rawValue)"
        return documentsPath.appendingPathComponent(filename)
    }
    
    private func startAudioLevelMonitoring() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopAudioLevelMonitoring() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        currentAudioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // デシベルを0-1の範囲に正規化
        let normalizedLevel = pow(10, averagePower / 20)
        currentAudioLevel = max(0.0, min(1.0, normalizedLevel))
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Audio recording encode error: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct AudioSession {
    let fileURL: URL
    let startTime: Date
    let settings: RecordingSettings
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

enum AudioServiceError: LocalizedError {
    case microphonePermissionDenied
    case recordingStartFailed
    case recordingResumeFailed
    case notRecording
    case notPaused
    case audioSessionSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "マイクへのアクセス許可が必要です"
        case .recordingStartFailed:
            return "録音の開始に失敗しました"
        case .recordingResumeFailed:
            return "録音の再開に失敗しました"
        case .notRecording:
            return "録音中ではありません"
        case .notPaused:
            return "録音は一時停止されていません"
        case .audioSessionSetupFailed:
            return "オーディオセッションの設定に失敗しました"
        }
    }
}

extension AudioQuality {
    var avQuality: AVAudioQuality {
        switch self {
        case .high: return .high
        case .standard: return .medium
        case .low: return .low
        case .lossless: return .max
        }
    }
}