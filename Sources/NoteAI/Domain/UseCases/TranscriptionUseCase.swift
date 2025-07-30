import Foundation

protocol TranscriptionUseCaseProtocol {
    func transcribeRecording(_ recording: Recording, method: TranscriptionMethod) async throws -> TranscriptionResult
    func retranscribeWithAPI(_ recording: Recording, provider: LLMProvider) async throws -> TranscriptionResult
    func getTranscriptionProgress(for recordingId: UUID) -> TranscriptionProgress?
    func cancelTranscription(for recordingId: UUID) async throws
}

class TranscriptionUseCase: TranscriptionUseCaseProtocol {
    private let whisperKitService: WhisperKitServiceProtocol
    private let apiTranscriptionService: APITranscriptionServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    
    private var activeTranscriptions: [UUID: TranscriptionProgress] = [:]
    
    init(
        whisperKitService: WhisperKitServiceProtocol,
        apiTranscriptionService: APITranscriptionServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        recordingRepository: RecordingRepositoryProtocol
    ) {
        self.whisperKitService = whisperKitService
        self.apiTranscriptionService = apiTranscriptionService
        self.subscriptionService = subscriptionService
        self.recordingRepository = recordingRepository
    }
    
    func transcribeRecording(_ recording: Recording, method: TranscriptionMethod) async throws -> TranscriptionResult {
        // 1. 既存の文字起こしチェック
        if activeTranscriptions[recording.id] != nil {
            throw TranscriptionUseCaseError.alreadyTranscribing(recording.id)
        }
        
        // 2. 進捗追跡開始
        startProgressTracking(for: recording.id, method: method)
        
        defer {
            // 完了時に進捗追跡停止
            stopProgressTracking(for: recording.id)
        }
        
        do {
            let result: TranscriptionResult
            
            switch method {
            case .local(let model):
                result = try await transcribeLocally(recording, model: model)
            case .api(let provider):
                result = try await transcribeWithAPI(recording, provider: provider)
            }
            
            // 3. 結果をRecordingに保存
            try await updateRecordingWithTranscription(recording, result: result, method: method)
            
            return result
            
        } catch {
            // エラー時も進捗をクリア
            stopProgressTracking(for: recording.id)
            throw error
        }
    }
    
    func retranscribeWithAPI(_ recording: Recording, provider: LLMProvider) async throws -> TranscriptionResult {
        // 有料版確認
        guard await subscriptionService.canUseFeature("premium_transcription") else {
            throw TranscriptionUseCaseError.subscriptionRequired
        }
        
        return try await transcribeRecording(recording, method: .api(provider))
    }
    
    func getTranscriptionProgress(for recordingId: UUID) -> TranscriptionProgress? {
        return activeTranscriptions[recordingId]
    }
    
    func cancelTranscription(for recordingId: UUID) async throws {
        guard activeTranscriptions[recordingId] != nil else {
            throw TranscriptionUseCaseError.noActiveTranscription(recordingId)
        }
        
        // TODO: 実際のキャンセル処理（WhisperKit/API呼び出し中断）
        stopProgressTracking(for: recordingId)
    }
    
    // MARK: - Private Methods
    
    private func transcribeLocally(_ recording: Recording, model: WhisperModel) async throws -> TranscriptionResult {
        updateProgress(for: recording.id, progress: 0.1, status: "モデル準備中...")
        
        // モデル準備
        if !whisperKitService.isModelDownloaded(model) {
            updateProgress(for: recording.id, progress: 0.2, status: "モデルダウンロード中...")
            try await whisperKitService.downloadModel(model)
        }
        
        updateProgress(for: recording.id, progress: 0.4, status: "音声解析中...")
        
        // 文字起こし実行
        let result = try await whisperKitService.transcribe(
            audioURL: recording.audioFileURL,
            model: model,
            language: recording.language
        )
        
        updateProgress(for: recording.id, progress: 0.9, status: "結果処理中...")
        
        return result
    }
    
    private func transcribeWithAPI(_ recording: Recording, provider: LLMProvider) async throws -> TranscriptionResult {
        // サブスクリプション確認
        guard await subscriptionService.canUseFeature("premium_transcription") else {
            throw TranscriptionUseCaseError.subscriptionRequired
        }
        
        updateProgress(for: recording.id, progress: 0.1, status: "API接続中...")
        
        // API文字起こし実行
        let options = APITranscriptionOptions(
            language: recording.language
        )
        
        let result = try await apiTranscriptionService.transcribe(
            audioURL: recording.audioFileURL,
            options: options
        )
        
        updateProgress(for: recording.id, progress: 0.9, status: "結果処理中...")
        
        return result
    }
    
    private func updateRecordingWithTranscription(
        _ recording: Recording,
        result: TranscriptionResult,
        method: TranscriptionMethod
    ) async throws {
        var updatedRecording = recording
        updatedRecording.transcription = result.text
        updatedRecording.updatedAt = Date()
        
        // セグメント情報も保存
        updatedRecording.segments = result.segments.map { segment in
            RecordingSegment(
                recordingId: recording.id,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                confidence: segment.confidence
            )
        }
        
        try await recordingRepository.save(updatedRecording)
    }
    
    private func startProgressTracking(for recordingId: UUID, method: TranscriptionMethod) {
        let progress = TranscriptionProgress(
            recordingId: recordingId,
            method: method,
            progress: 0.0,
            status: "準備中...",
            startTime: Date()
        )
        
        activeTranscriptions[recordingId] = progress
    }
    
    private func updateProgress(for recordingId: UUID, progress: Double, status: String) {
        guard var transcriptionProgress = activeTranscriptions[recordingId] else { return }
        
        transcriptionProgress = TranscriptionProgress(
            recordingId: recordingId,
            method: transcriptionProgress.method,
            progress: progress,
            status: status,
            startTime: transcriptionProgress.startTime
        )
        
        activeTranscriptions[recordingId] = transcriptionProgress
    }
    
    private func stopProgressTracking(for recordingId: UUID) {
        activeTranscriptions.removeValue(forKey: recordingId)
    }
}

// MARK: - Supporting Types

struct TranscriptionProgress {
    let recordingId: UUID
    let method: TranscriptionMethod
    let progress: Double // 0.0 - 1.0
    let status: String
    let startTime: Date
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var formattedElapsedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: elapsedTime) ?? ""
    }
    
    var estimatedRemainingTime: TimeInterval? {
        guard progress > 0.1 else { return nil }
        let remainingProgress = 1.0 - progress
        return (elapsedTime / progress) * remainingProgress
    }
    
    var formattedEstimatedRemainingTime: String? {
        guard let remaining = estimatedRemainingTime else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: remaining)
    }
}

enum TranscriptionUseCaseError: LocalizedError {
    case alreadyTranscribing(UUID)
    case noActiveTranscription(UUID)
    case subscriptionRequired
    case modelNotAvailable(WhisperModel)
    case apiKeyNotSet(LLMProvider)
    case transcriptionFailed(Error)
    case recordingNotFound(UUID)
    
    var errorDescription: String? {
        switch self {
        case .alreadyTranscribing(let id):
            return "録音 \(id) は既に文字起こし中です"
        case .noActiveTranscription(let id):
            return "録音 \(id) の文字起こしは実行されていません"
        case .subscriptionRequired:
            return "API機能を利用するにはPremiumプランへの登録が必要です"
        case .modelNotAvailable(let model):
            return "モデル \(model.displayName) が利用できません"
        case .apiKeyNotSet(let provider):
            return "\(provider.displayName) のAPIキーが設定されていません"
        case .transcriptionFailed(let error):
            return "文字起こしに失敗しました: \(error.localizedDescription)"
        case .recordingNotFound(let id):
            return "録音データが見つかりません: \(id)"
        }
    }
}

// Note: Service protocols and implementations moved to appropriate files:
// - APITranscriptionServiceProtocol: Will be defined in Phase 4
// - SubscriptionServiceProtocol: Will be defined in Phase 4
// - Mock implementations: Available in MockServices.swift