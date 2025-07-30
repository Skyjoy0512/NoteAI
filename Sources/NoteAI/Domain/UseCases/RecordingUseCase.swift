import Foundation

protocol RecordingUseCaseProtocol {
    func startRecording(projectId: UUID?, settings: RecordingSettings) async throws -> Recording
    func pauseRecording() async throws
    func resumeRecording() async throws
    func stopRecording() async throws -> Recording
    func deleteRecording(_ recordingId: UUID) async throws
    func getRecordingProgress() -> RecordingProgress?
}

class RecordingUseCase: RecordingUseCaseProtocol {
    private let audioService: AudioServiceProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let fileManager: AudioFileManagerProtocol
    
    private var currentRecording: Recording?
    private var currentSession: AudioSession?
    
    init(
        audioService: AudioServiceProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        fileManager: AudioFileManagerProtocol
    ) {
        self.audioService = audioService
        self.recordingRepository = recordingRepository
        self.fileManager = fileManager
    }
    
    func startRecording(projectId: UUID?, settings: RecordingSettings) async throws -> Recording {
        // 1. 既存録音チェック
        guard currentRecording == nil else {
            throw RecordingUseCaseError.alreadyRecording
        }
        
        // 2. ストレージ容量チェック
        try await checkStorageCapacity()
        
        // 3. 音声録音開始
        currentSession = try await audioService.startRecording(settings: settings)
        
        guard let session = currentSession else {
            throw RecordingUseCaseError.sessionCreationFailed
        }
        
        // 4. Recording エンティティ作成
        let recording = Recording(
            id: UUID(),
            title: generateRecordingTitle(from: session.startTime),
            audioFileURL: session.fileURL,
            transcription: nil,
            transcriptionMethod: .local(.base),
            language: settings.language,
            duration: 0,
            audioQuality: settings.quality,
            isFromLimitless: false,
            createdAt: session.startTime,
            updatedAt: session.startTime,
            metadata: RecordingMetadata(),
            projectId: projectId
        )
        
        // 5. データベース保存
        try await recordingRepository.save(recording)
        
        currentRecording = recording
        
        return recording
    }
    
    func pauseRecording() async throws {
        guard currentRecording != nil else {
            throw RecordingUseCaseError.notRecording
        }
        
        try await audioService.pauseRecording()
    }
    
    func resumeRecording() async throws {
        guard currentRecording != nil else {
            throw RecordingUseCaseError.notRecording
        }
        
        try await audioService.resumeRecording()
    }
    
    func stopRecording() async throws -> Recording {
        guard var recording = currentRecording else {
            throw RecordingUseCaseError.notRecording
        }
        
        // 1. 音声録音停止
        let finalURL = try await audioService.stopRecording()
        
        // 2. 録音時間計算
        let duration = Date().timeIntervalSince(recording.createdAt)
        
        // 3. Recording更新
        recording = Recording(
            id: recording.id,
            title: recording.title,
            audioFileURL: finalURL,
            transcription: recording.transcription,
            transcriptionMethod: recording.transcriptionMethod,
            whisperModel: recording.whisperModel,
            language: recording.language,
            duration: duration,
            audioQuality: recording.audioQuality,
            isFromLimitless: recording.isFromLimitless,
            createdAt: recording.createdAt,
            updatedAt: Date(),
            metadata: recording.metadata,
            projectId: recording.projectId
        )
        
        // 4. データベース更新
        try await recordingRepository.save(recording)
        
        // 5. 状態リセット
        currentRecording = nil
        currentSession = nil
        
        return recording
    }
    
    func deleteRecording(_ recordingId: UUID) async throws {
        // 1. 録音データ取得
        guard let recording = try await recordingRepository.findById(recordingId) else {
            throw RecordingUseCaseError.recordingNotFound(recordingId)
        }
        
        // 2. 音声ファイル削除
        try fileManager.deleteAudioFile(at: recording.audioFileURL)
        
        // 3. データベースから削除
        try await recordingRepository.delete(recordingId)
        
        // 4. 現在録音中の場合はリセット
        if currentRecording?.id == recordingId {
            currentRecording = nil
            currentSession = nil
        }
    }
    
    func getRecordingProgress() -> RecordingProgress? {
        guard let recording = currentRecording,
              let session = currentSession else {
            return nil
        }
        
        return RecordingProgress(
            recordingId: recording.id,
            duration: session.duration,
            audioLevel: audioService.getCurrentLevel(),
            isPaused: false, // TODO: 一時停止状態を追跡
            fileSize: getFileSize(for: session.fileURL)
        )
    }
    
    // MARK: - Private Methods
    
    private func checkStorageCapacity() async throws {
        let availableStorage = try fileManager.getAvailableStorage()
        let minimumRequired: Int64 = 100 * 1024 * 1024 // 100MB
        
        if availableStorage < minimumRequired {
            throw RecordingUseCaseError.insufficientStorage(
                required: minimumRequired,
                available: availableStorage
            )
        }
    }
    
    private func generateRecordingTitle(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return "録音 \(formatter.string(from: date))"
    }
    
    private func getFileSize(for url: URL) -> Int64 {
        do {
            return try fileManager.getAudioFileSize(at: url)
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Types

struct RecordingProgress {
    let recordingId: UUID
    let duration: TimeInterval
    let audioLevel: Float
    let isPaused: Bool
    let fileSize: Int64
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

enum RecordingUseCaseError: LocalizedError {
    case alreadyRecording
    case notRecording
    case sessionCreationFailed
    case recordingNotFound(UUID)
    case insufficientStorage(required: Int64, available: Int64)
    case transcriptionInProgress
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "既に録音中です"
        case .notRecording:
            return "録音中ではありません"
        case .sessionCreationFailed:
            return "録音セッションの作成に失敗しました"
        case .recordingNotFound(let id):
            return "録音データが見つかりません: \(id)"
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            let requiredStr = formatter.string(fromByteCount: required)
            let availableStr = formatter.string(fromByteCount: available)
            return "ストレージ容量不足: 必要 \(requiredStr), 利用可能 \(availableStr)"
        case .transcriptionInProgress:
            return "文字起こし処理中のため、録音を削除できません"
        }
    }
}