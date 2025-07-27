import Foundation
import AVFoundation
import WhisperKit

protocol WhisperKitServiceProtocol {
    func transcribe(audioURL: URL, model: WhisperModel, language: String) async throws -> TranscriptionResult
    func downloadModel(_ model: WhisperModel) async throws
    func getAvailableModels() -> [WhisperModel]
    func isModelDownloaded(_ model: WhisperModel) -> Bool
}

class WhisperKitService: WhisperKitServiceProtocol {
    private var whisperKit: WhisperKit?
    private var currentModel: WhisperModel?
    private let modelCache = NSCache<NSString, WhisperKit>()
    
    init() {
        setupModelCache()
    }
    
    func transcribe(audioURL: URL, model: WhisperModel, language: String) async throws -> TranscriptionResult {
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
        return TranscriptionResult(
            text: result?.text ?? "",
            language: result?.language ?? language,
            duration: getDuration(from: audioURL),
            segments: result?.segments.map { segment in
                TranscriptionSegment(
                    text: segment.text,
                    startTime: segment.start,
                    endTime: segment.end,
                    confidence: segment.avgLogprob
                )
            } ?? [],
            model: model,
            processingTime: result?.timings.totalDecodingTime ?? 0
        )
    }
    
    func downloadModel(_ model: WhisperModel) async throws {
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
    }
    
    func getAvailableModels() -> [WhisperModel] {
        return WhisperModel.allCases
    }
    
    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let cacheKey = NSString(string: model.modelName)
        return modelCache.object(forKey: cacheKey) != nil
    }
    
    // MARK: - Private Methods
    
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
    
    private func getDuration(from url: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            return duration
        } catch {
            return 0
        }
    }
    
    private func setupModelCache() {
        modelCache.countLimit = 3 // 最大3モデルをキャッシュ
        modelCache.totalCostLimit = 1024 * 1024 * 1024 // 1GB
    }
}

// MARK: - Supporting Types

struct TranscriptionResult {
    let text: String
    let language: String
    let duration: TimeInterval
    let segments: [TranscriptionSegment]
    let model: WhisperModel
    let processingTime: TimeInterval
    
    var averageConfidence: Double {
        guard !segments.isEmpty else { return 0 }
        let totalConfidence = segments.compactMap { $0.confidence }.reduce(0, +)
        return totalConfidence / Double(segments.count)
    }
    
    var wordsPerMinute: Double {
        guard duration > 0 else { return 0 }
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        return Double(wordCount) / (duration / 60)
    }
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double?
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var formattedTimeRange: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        let start = formatter.string(from: startTime) ?? "00:00"
        let end = formatter.string(from: endTime) ?? "00:00"
        
        return "\(start) - \(end)"
    }
}

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