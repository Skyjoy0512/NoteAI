import Foundation
import AVFoundation
#if !MINIMAL_BUILD
import WhisperKit
#endif

protocol WhisperKitServiceProtocol {
    func transcribe(audioURL: URL, model: WhisperModel, language: String) async throws -> TranscriptionResult
    func downloadModel(_ model: WhisperModel) async throws
    func getAvailableModels() -> [WhisperModel]
    func isModelDownloaded(_ model: WhisperModel) -> Bool
}

class WhisperKitService: WhisperKitServiceProtocol {
    #if !MINIMAL_BUILD
    private var whisperKit: WhisperKit?
    private let modelCache = NSCache<NSString, WhisperKit>()
    #endif
    private var currentModel: WhisperModel?
    
    init() {
        setupModelCache()
    }
    
    func transcribe(audioURL: URL, model: WhisperModel, language: String) async throws -> TranscriptionResult {
        #if !MINIMAL_BUILD
        // 1. モデル初期化・キャッシュ確認
        let whisperKit = try await getOrLoadModel(model)
        
        // 2. 音声ファイル読み込み
        let audioData = try await loadAudioData(from: audioURL)
        
        // 3. 文字起こし実行
        let result = try await whisperKit.transcribe(
            audioArray: audioData,
            decodeOptions: DecodingOptions(
                language: language,
                task: .transcribe,
                temperature: 0.0,
                temperatureFallbackCount: 3,
                sampleLength: 30
            )
        )
        
        // 4. 結果変換
        let duration = getDuration(from: audioURL)
        let segments: [TranscriptionSegment] = result?.segments.map { segment in
            TranscriptionSegment(
                id: 0,
                text: segment.text,
                startTime: segment.start,
                endTime: segment.end,
                confidence: segment.avgLogprob
            )
        } ?? []
        
        return TranscriptionResult(
            text: result?.text ?? "",
            segments: segments,
            detectedLanguage: result?.language ?? language,
            languageConfidence: 0.9,
            audioDuration: duration,
            processingDuration: result?.timings.totalDecodingTime ?? 0,
            modelUsed: model.rawValue,
            averageConfidence: segments.isEmpty ? 0.0 : segments.reduce(0) { $0 + $1.confidence } / Double(segments.count),
            alternativeLanguages: nil
        )
        #else
        // MINIMAL_BUILD: Mock implementation
        return TranscriptionResult(
            text: "Mock transcription",
            segments: [],
            detectedLanguage: language,
            languageConfidence: 0.5,
            audioDuration: getDuration(from: audioURL),
            processingDuration: 0.1,
            modelUsed: model.rawValue,
            averageConfidence: 0.5,
            alternativeLanguages: nil
        )
        #endif
    }
    
    func downloadModel(_ model: WhisperModel) async throws {
        #if !MINIMAL_BUILD
        do {
            let whisperKit = try await WhisperKit(
                computeOptions: WhisperKit.ModelComputeOptions(),
                audioProcessor: WhisperKit.AudioProcessor(),
                featureExtractor: WhisperKit.FeatureExtractor(),
                audioEncoder: WhisperKit.AudioEncoder(),
                textDecoder: WhisperKit.TextDecoder(),
                logitsFilters: [WhisperKit.SuppressTokensFilter(), WhisperKit.SuppressBlankFilter()],
                segmentSeeker: WhisperKit.SegmentSeeker()
            )
            
            // モデルキャッシュに保存
            let cacheKey = NSString(string: model.modelName)
            modelCache.setObject(whisperKit, forKey: cacheKey)
            
        } catch {
            throw WhisperKitError.modelDownloadFailed(error)
        }
        #else
        // MINIMAL_BUILD: No-op
        #endif
    }
    
    func getAvailableModels() -> [WhisperModel] {
        #if !MINIMAL_BUILD
        return WhisperModel.allCases
        #else
        return WhisperModel.allCases
        #endif
    }
    
    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        #if !MINIMAL_BUILD
        let cacheKey = NSString(string: model.modelName)
        return modelCache.object(forKey: cacheKey) != nil
        #else
        return false
        #endif
    }
    
    // MARK: - Private Methods
    
    #if !MINIMAL_BUILD
    private func getOrLoadModel(_ model: WhisperModel) async throws -> WhisperKit {
        let cacheKey = NSString(string: model.modelName)
        
        // キャッシュ確認
        if let cachedModel = modelCache.object(forKey: cacheKey) {
            return cachedModel
        }
        
        // モデル読み込み
        do {
            let whisperKit = try await WhisperKit(
                modelFolder: model.modelName,
                computeOptions: WhisperKit.ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                verbose: false,
                logLevel: .none,
                prewarm: false,
                load: true,
                download: true
            )
            
            // キャッシュに保存
            modelCache.setObject(whisperKit, forKey: cacheKey)
            currentModel = model
            
            return whisperKit
            
        } catch {
            throw WhisperKitError.modelLoadFailed(model, error)
        }
    }
    
    private func loadAudioData(from url: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // AVAudioFile を使用して音声データを読み込み
                    let file = try AVAudioFile(forReading: url)
                    
                    // 16kHz モノラルフォーマット（WhisperKit要件）
                    let format = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: 16000,
                        channels: 1,
                        interleaved: false
                    )!
                    
                    let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: UInt32(file.length)
                    )!
                    
                    // コンバーター使用してフォーマット変換
                    let converter = AVAudioConverter(from: file.processingFormat, to: format)!
                    
                    var error: NSError?
                    let status = converter.convert(to: buffer, error: &error) { packetCount, inputStatus in
                        do {
                            let inputBuffer = AVAudioPCMBuffer(
                                pcmFormat: file.processingFormat,
                                frameCapacity: packetCount
                            )!
                            
                            try file.read(into: inputBuffer)
                            inputStatus.pointee = .haveData
                            return inputBuffer
                        } catch {
                            inputStatus.pointee = .noDataNow
                            return nil
                        }
                    }
                    
                    if status == .error {
                        throw error ?? WhisperKitError.audioConversionFailed
                    }
                    
                    // Float配列に変換
                    guard let channelData = buffer.floatChannelData?[0] else {
                        throw WhisperKitError.audioDataExtractionFailed
                    }
                    
                    let audioArray = Array(UnsafeBufferPointer(
                        start: channelData,
                        count: Int(buffer.frameLength)
                    ))
                    
                    continuation.resume(returning: audioArray)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    #endif
    
    private func getDuration(from url: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            return duration
        } catch {
            return 0
        }
    }
    
    #if !MINIMAL_BUILD
    private func setupModelCache() {
        modelCache.countLimit = 3 // 最大3モデルをキャッシュ
        modelCache.totalCostLimit = 1024 * 1024 * 1024 // 1GB
    }
    #else
    private func setupModelCache() {
        // MINIMAL_BUILD: No-op
    }
    #endif
    
} // End of WhisperKitService class

// MARK: - Supporting Types

// TranscriptionResult and TranscriptionSegment are now defined in Domain/Entities/TranscriptionTypes.swift

enum WhisperKitError: LocalizedError {
    case modelLoadFailed(WhisperModel, Error)
    case modelDownloadFailed(Error)
    case audioConversionFailed
    case audioDataExtractionFailed
    case transcriptionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let model, let error):
            return "モデル \(model.displayName) の読み込みに失敗しました: \(error.localizedDescription)"
        case .modelDownloadFailed(let error):
            return "モデルのダウンロードに失敗しました: \(error.localizedDescription)"
        case .audioConversionFailed:
            return "音声ファイルの変換に失敗しました"
        case .audioDataExtractionFailed:
            return "音声データの抽出に失敗しました"
        case .transcriptionFailed(let error):
            return "文字起こしに失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - WhisperKit Extensions

#if !MINIMAL_BUILD
extension WhisperModel {
    var downloadProgress: Double {
        // TODO: 実際のダウンロード進捗を取得
        return 1.0
    }
    
    var isDownloading: Bool {
        // TODO: ダウンロード状態を確認
        return false
    }
}
#endif
