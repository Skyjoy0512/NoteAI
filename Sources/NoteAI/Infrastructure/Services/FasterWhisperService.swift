import Foundation
import AVFoundation

// MARK: - Supporting Types (Forward Declarations)

struct LanguageDetectionResult {
    let detectedLanguage: String
    let confidence: Double
    let alternativeLanguages: [LanguageProbability]
}

struct ModelInfo {
    let name: String
    let version: String
    let size: String
    let languages: Int
    let features: [String]
    let maxAudioLength: TimeInterval
    let supportedFormats: [String]
}

struct DiarizedTranscriptionResult {
    let transcriptionResult: TranscriptionResult
    let diarizationResult: DiarizationResult
    let speakerSegments: [SpeakerAwareTranscriptionSegment]
    let speakerCount: Int
    let totalDuration: TimeInterval
    let processingTime: TimeInterval
}

struct SpeakerAwareTranscriptionSegment: Identifiable {
    let id: UUID
    let speakerId: String
    let speakerName: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String?
    let confidence: Double
    let words: [WordTimestamp]
    let language: String
    let audioLevel: Float
    let speakerCharacteristics: SpeakerCharacteristics?
    
    var duration: TimeInterval {
        return endTime - startTime
    }
}

enum TranscriptionTask: String, CaseIterable {
    case transcribe = "transcribe"
    case translate = "translate"
}

struct TranscriptionOptions {
    let language: String?
    let task: TranscriptionTask
    let temperature: Float
    let wordTimestamps: Bool
    let vadFilter: Bool
    let noSpeechThreshold: Float
    let logProbThreshold: Float
    let compressionRatioThreshold: Float
    let conditionOnPreviousText: Bool
    let promptTemplate: String?
    
    init(
        language: String? = nil,
        task: TranscriptionTask = .transcribe,
        temperature: Float = 0.0,
        wordTimestamps: Bool = true,
        vadFilter: Bool = true,
        noSpeechThreshold: Float = 0.6,
        logProbThreshold: Float = -1.0,
        compressionRatioThreshold: Float = 2.4,
        conditionOnPreviousText: Bool = true,
        promptTemplate: String? = nil
    ) {
        self.language = language
        self.task = task
        self.temperature = temperature
        self.wordTimestamps = wordTimestamps
        self.vadFilter = vadFilter
        self.noSpeechThreshold = noSpeechThreshold
        self.logProbThreshold = logProbThreshold
        self.compressionRatioThreshold = compressionRatioThreshold
        self.conditionOnPreviousText = conditionOnPreviousText
        self.promptTemplate = promptTemplate
    }
}

// MARK: - Faster Whisper Turbo Service

protocol FasterWhisperServiceProtocol {
    func transcribe(audioFile: URL, options: TranscriptionOptions) async throws -> TranscriptionResult
    func transcribeStream(audioStream: AsyncStream<Data>, options: TranscriptionOptions) async throws -> AsyncStream<TranscriptionSegment>
    func transcribeBatch(audioFiles: [URL], options: TranscriptionOptions) async throws -> [TranscriptionResult]
    func transcribeWithSpeakerDiarization(audioFile: URL, options: TranscriptionOptions, diarizationOptions: DiarizationOptions) async throws -> DiarizedTranscriptionResult
    func detectLanguage(audioFile: URL) async throws -> LanguageDetectionResult
    func getSupportedLanguages() -> [TranscriptionLanguage]
    func getModelInfo() -> ModelInfo
}

class FasterWhisperService: FasterWhisperServiceProtocol {
    
    // MARK: - Properties
    private let logger = RAGLogger.shared
    private let performanceMonitor = RAGPerformanceMonitor.shared
    private let fileManager = FileManager.default
    private let speakerDiarizationService = SpeakerDiarizationService()
    
    // MARK: - Configuration
    private struct Config {
        static let modelName = "turbo"
        static let maxAudioLength: TimeInterval = 7200 // 2 hours
        static let chunkDuration: TimeInterval = 30 // 30 seconds for streaming
        static let maxConcurrentTranscriptions = 3
        static let supportedFormats: Set<String> = ["wav", "mp3", "m4a", "aac", "flac"]
    }
    
    // MARK: - Initialization
    init() {
        setupModel()
    }
    
    private func setupModel() {
        logger.log(level: .info, message: "Initializing Faster Whisper Turbo model", context: [
            "model": Config.modelName
        ])
    }
    
    // MARK: - Single File Transcription
    
    func transcribe(audioFile: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        let measurement = performanceMonitor.startMeasurement()
        
        logger.log(level: .info, message: "Starting transcription", context: [
            "file": audioFile.lastPathComponent,
            "language": options.language ?? "auto",
            "model": Config.modelName
        ])
        
        do {
            // Validate audio file
            try validateAudioFile(audioFile)
            
            // Preprocess audio if needed
            let processedAudioFile = try await preprocessAudio(audioFile, options: options)
            
            // Perform transcription using Faster Whisper Turbo
            let result = try await performTranscription(processedAudioFile, options: options)
            
            // Post-process results
            let finalResult = try await postprocessTranscription(result, options: options)
            
            performanceMonitor.recordMetric(
                operation: "transcription",
                measurement: measurement,
                success: true,
                metadata: [
                    "duration": finalResult.audioDuration,
                    "wordCount": finalResult.segments.reduce(0) { $0 + ($1.words?.count ?? 0) },
                    "language": finalResult.detectedLanguage
                ]
            )
            
            logger.log(level: .info, message: "Transcription completed", context: [
                "duration": finalResult.audioDuration,
                "confidence": finalResult.averageConfidence,
                "segments": finalResult.segments.count
            ])
            
            return finalResult
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "transcription",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Transcription failed", context: [
                "file": audioFile.lastPathComponent,
                "error": error.localizedDescription
            ])
            
            throw error
        }
    }
    
    // MARK: - Streaming Transcription
    
    func transcribeStream(audioStream: AsyncStream<Data>, options: TranscriptionOptions) async throws -> AsyncStream<TranscriptionSegment> {
        logger.log(level: .info, message: "Starting streaming transcription")
        
        return AsyncStream(TranscriptionSegment.self) { continuation in
            Task {
                do {
                    var audioBuffer = Data()
                    var chunkIndex = 0
                    
                    for await audioChunk in audioStream {
                        audioBuffer.append(audioChunk)
                        
                        // Process when we have enough audio data
                        if audioBuffer.count >= estimateDataSize(for: Config.chunkDuration, options: options) {
                            let tempFile = try createTempAudioFile(from: audioBuffer, index: chunkIndex)
                            
                            do {
                                let result = try await transcribe(audioFile: tempFile, options: options)
                                
                                // Send segments as they become available
                                for segment in result.segments {
                                    continuation.yield(segment)
                                }
                                
                                // Clean up temp file
                                try? fileManager.removeItem(at: tempFile)
                                
                                chunkIndex += 1
                                audioBuffer = Data()
                                
                            } catch {
                                logger.log(level: .error, message: "Streaming chunk transcription failed", context: [
                                    "chunk": chunkIndex,
                                    "error": error.localizedDescription
                                ])
                            }
                        }
                    }
                    
                    // Process remaining audio buffer
                    if !audioBuffer.isEmpty {
                        let tempFile = try createTempAudioFile(from: audioBuffer, index: chunkIndex)
                        
                        do {
                            let result = try await transcribe(audioFile: tempFile, options: options)
                            
                            for segment in result.segments {
                                continuation.yield(segment)
                            }
                            
                            try? fileManager.removeItem(at: tempFile)
                            
                        } catch {
                            logger.log(level: .error, message: "Final chunk transcription failed", context: [
                                "error": error.localizedDescription
                            ])
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    logger.log(level: .error, message: "Streaming transcription failed", context: [
                        "error": error.localizedDescription
                    ])
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Batch Transcription
    
    func transcribeBatch(audioFiles: [URL], options: TranscriptionOptions) async throws -> [TranscriptionResult] {
        logger.log(level: .info, message: "Starting batch transcription", context: [
            "fileCount": audioFiles.count
        ])
        
        let measurement = performanceMonitor.startMeasurement()
        
        // Process files in parallel with concurrency limit
        let results = try await withThrowingTaskGroup(of: (Int, TranscriptionResult).self, returning: [TranscriptionResult].self) { group in
            var results: [TranscriptionResult?] = Array(repeating: nil, count: audioFiles.count)
            var currentTaskCount = 0
            
            for (index, audioFile) in audioFiles.enumerated() {
                group.addTask {
                    let result = try await self.transcribe(audioFile: audioFile, options: options)
                    return (index, result)
                }
                currentTaskCount += 1
                
                // Limit concurrent transcriptions
                if currentTaskCount >= Config.maxConcurrentTranscriptions {
                    if let (index, result) = try await group.next() {
                        results[index] = result
                        currentTaskCount -= 1
                    }
                }
            }
            
            // Wait for remaining tasks
            for try await (index, result) in group {
                results[index] = result
            }
            
            return results.compactMap { $0 }
        }
        
        performanceMonitor.recordMetric(
            operation: "batchTranscription",
            measurement: measurement,
            success: true,
            metadata: [
                "fileCount": audioFiles.count,
                "successCount": results.count
            ]
        )
        
        logger.log(level: .info, message: "Batch transcription completed", context: [
            "processedFiles": results.count,
            "totalFiles": audioFiles.count
        ])
        
        return results
    }
    
    // MARK: - Speaker Diarization with Transcription
    
    func transcribeWithSpeakerDiarization(
        audioFile: URL,
        options: TranscriptionOptions,
        diarizationOptions: DiarizationOptions
    ) async throws -> DiarizedTranscriptionResult {
        
        let measurement = performanceMonitor.startMeasurement()
        
        logger.log(level: .info, message: "Starting transcription with speaker diarization", context: [
            "file": audioFile.lastPathComponent,
            "language": options.language ?? "auto",
            "expectedSpeakers": diarizationOptions.expectedSpeakerCount ?? "auto"
        ])
        
        // Perform transcription and diarization in parallel for better performance
        async let transcriptionTask = transcribe(audioFile: audioFile, options: options)
        async let diarizationTask = speakerDiarizationService.performDiarization(audioFile: audioFile, options: diarizationOptions)
        
        let (transcriptionResult, _) = try await (transcriptionTask, diarizationTask)
        
        // Combine results with better alignment
        let enhancedDiarizationResult = try await speakerDiarizationService.performDiarizationWithTranscription(
            audioFile: audioFile,
            transcriptionResult: transcriptionResult,
            options: diarizationOptions
        )
        
        // Create speaker-aware transcription segments
        let speakerSegments = createSpeakerAwareSegments(
            transcriptionResult: transcriptionResult,
            diarizationResult: enhancedDiarizationResult
        )
        
        let result = DiarizedTranscriptionResult(
            transcriptionResult: transcriptionResult,
            diarizationResult: enhancedDiarizationResult,
            speakerSegments: speakerSegments,
            speakerCount: enhancedDiarizationResult.speakerCount,
            totalDuration: transcriptionResult.audioDuration,
            processingTime: measurement.duration
        )
        
        logger.log(level: .info, message: "Speaker diarization with transcription completed", context: [
            "speakerCount": result.speakerCount,
            "speakerSegments": result.speakerSegments.count,
            "transcriptionSegments": transcriptionResult.segments.count
        ])
        
        return result
    }
    
    // MARK: - Language Detection
    
    func detectLanguage(audioFile: URL) async throws -> LanguageDetectionResult {
        logger.log(level: .debug, message: "Detecting language", context: [
            "file": audioFile.lastPathComponent
        ])
        
        // Simulate language detection using first 30 seconds of audio
        let options = TranscriptionOptions(
            language: nil, // Auto-detect
            task: .transcribe,
            temperature: 0.0,
            wordTimestamps: false,
            vadFilter: true,
            noSpeechThreshold: 0.6
        )
        
        // Use a short segment for language detection
        let shortAudioFile = try await extractAudioSegment(audioFile, startTime: 0, duration: 30)
        
        do {
            let result = try await transcribe(audioFile: shortAudioFile, options: options)
            // Clean up temp file
            try? fileManager.removeItem(at: shortAudioFile)
            
            return LanguageDetectionResult(
                detectedLanguage: result.detectedLanguage,
                confidence: result.languageConfidence,
                alternativeLanguages: result.alternativeLanguages ?? []
            )
            
        } catch {
            try? fileManager.removeItem(at: shortAudioFile)
            throw error
        }
    }
    
    // MARK: - Model Information
    
    func getSupportedLanguages() -> [TranscriptionLanguage] {
        return [
            TranscriptionLanguage(languageCode: "ja", displayName: "Japanese", nativeName: "日本語"),
            TranscriptionLanguage(languageCode: "en", displayName: "English", nativeName: "English"),
            TranscriptionLanguage(languageCode: "zh", displayName: "Chinese", nativeName: "中文"),
            TranscriptionLanguage(languageCode: "ko", displayName: "Korean", nativeName: "한국어"),
            TranscriptionLanguage(languageCode: "es", displayName: "Spanish", nativeName: "Español"),
            TranscriptionLanguage(languageCode: "fr", displayName: "French", nativeName: "Français"),
            TranscriptionLanguage(languageCode: "de", displayName: "German", nativeName: "Deutsch"),
            TranscriptionLanguage(languageCode: "it", displayName: "Italian", nativeName: "Italiano"),
            TranscriptionLanguage(languageCode: "pt", displayName: "Portuguese", nativeName: "Português"),
            TranscriptionLanguage(languageCode: "ru", displayName: "Russian", nativeName: "Русский"),
            TranscriptionLanguage(languageCode: "ar", displayName: "Arabic", nativeName: "العربية"),
            TranscriptionLanguage(languageCode: "hi", displayName: "Hindi", nativeName: "हिन्दी"),
            TranscriptionLanguage(languageCode: "th", displayName: "Thai", nativeName: "ไทย"),
            TranscriptionLanguage(languageCode: "vi", displayName: "Vietnamese", nativeName: "Tiếng Việt"),
            TranscriptionLanguage(languageCode: "id", displayName: "Indonesian", nativeName: "Bahasa Indonesia")
        ]
    }
    
    func getModelInfo() -> ModelInfo {
        return ModelInfo(
            name: "Faster Whisper Turbo",
            version: "1.0.0",
            size: "39 MB",
            languages: getSupportedLanguages().count,
            features: [
                "Real-time transcription",
                "Speaker diarization",
                "Word-level timestamps",
                "Automatic language detection",
                "Noise filtering",
                "Voice activity detection"
            ],
            maxAudioLength: Config.maxAudioLength,
            supportedFormats: Array(Config.supportedFormats)
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func validateAudioFile(_ audioFile: URL) throws {
        guard fileManager.fileExists(atPath: audioFile.path) else {
            throw WhisperError.fileNotFound
        }
        
        let fileExtension = audioFile.pathExtension.lowercased()
        guard Config.supportedFormats.contains(fileExtension) else {
            throw WhisperError.unsupportedFormat(fileExtension)
        }
        
        // Check file size and duration
        let attributes = try fileManager.attributesOfItem(atPath: audioFile.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Rough estimate: 10MB per minute for high quality audio
        let estimatedDuration = Double(fileSize) / (10 * 1024 * 1024) * 60
        
        if estimatedDuration > Config.maxAudioLength {
            throw WhisperError.audioTooLong(estimatedDuration, Config.maxAudioLength)
        }
    }
    
    private func preprocessAudio(_ audioFile: URL, options: TranscriptionOptions) async throws -> URL {
        // For now, return the original file
        // In a real implementation, this would handle:
        // - Format conversion
        // - Noise reduction
        // - Normalization
        // - Resampling
        
        return audioFile
    }
    
    private func performTranscription(_ audioFile: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        // Simulate Faster Whisper Turbo processing
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds simulation
        
        // Mock transcription result
        let segments = [
            TranscriptionSegment(
                id: 0,
                text: "こんにちは、これはテスト音声です。",
                startTime: 0.0,
                endTime: 3.2,
                confidence: 0.95,
                words: [
                    WordTimestamp(word: "こんにちは", startTime: 0.0, endTime: 1.2, confidence: 0.98),
                    WordTimestamp(word: "これは", startTime: 1.5, endTime: 2.0, confidence: 0.95),
                    WordTimestamp(word: "テスト", startTime: 2.1, endTime: 2.7, confidence: 0.92),
                    WordTimestamp(word: "音声です", startTime: 2.8, endTime: 3.2, confidence: 0.97)
                ],
                language: "ja",
                noSpeechProb: 0.02
            ),
            TranscriptionSegment(
                id: 1,
                text: "Faster Whisper Turboを使用しています。",
                startTime: 4.0,
                endTime: 7.5,
                confidence: 0.93,
                words: [
                    WordTimestamp(word: "Faster", startTime: 4.0, endTime: 4.5, confidence: 0.95),
                    WordTimestamp(word: "Whisper", startTime: 4.6, endTime: 5.2, confidence: 0.94),
                    WordTimestamp(word: "Turbo", startTime: 5.3, endTime: 5.8, confidence: 0.92),
                    WordTimestamp(word: "を使用しています", startTime: 6.0, endTime: 7.5, confidence: 0.91)
                ],
                language: "ja",
                noSpeechProb: 0.03
            )
        ]
        
        return TranscriptionResult(
            text: segments.map { $0.text }.joined(separator: " "),
            segments: segments,
            detectedLanguage: "ja",
            languageConfidence: 0.98,
            audioDuration: 7.5,
            processingDuration: 2.0,
            modelUsed: "faster-whisper-turbo",
            averageConfidence: segments.reduce(0) { $0 + $1.confidence } / Double(segments.count),
            alternativeLanguages: [
                LanguageProbability(language: "en", probability: 0.15, languageCode: "en"),
                LanguageProbability(language: "zh", probability: 0.08, languageCode: "zh")
            ]
        )
    }
    
    private func postprocessTranscription(_ result: TranscriptionResult, options: TranscriptionOptions) async throws -> TranscriptionResult {
        // Post-processing steps:
        // - Text cleaning
        // - Punctuation restoration
        // - Speaker diarization (if enabled)
        // - Sentiment analysis (if enabled)
        
        return result
    }
    
    private func estimateDataSize(for duration: TimeInterval, options: TranscriptionOptions) -> Int {
        // Estimate data size for given duration
        // Assume 44.1kHz, 16-bit, mono: ~88KB per second
        return Int(duration * 88000)
    }
    
    private func createTempAudioFile(from data: Data, index: Int) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "whisper_stream_\(index)_\(UUID().uuidString).wav"
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        try data.write(to: tempFile)
        return tempFile
    }
    
    private func extractAudioSegment(_ audioFile: URL, startTime: TimeInterval, duration: TimeInterval) async throws -> URL {
        // In a real implementation, use AVAssetExportSession or similar
        // For now, return the original file
        return audioFile
    }
    
    // MARK: - Speaker-Aware Segment Creation
    
    private func createSpeakerAwareSegments(
        transcriptionResult: TranscriptionResult,
        diarizationResult: DiarizationResult
    ) -> [SpeakerAwareTranscriptionSegment] {
        
        var speakerSegments: [SpeakerAwareTranscriptionSegment] = []
        
        for diarizationSegment in diarizationResult.segments {
            // Find overlapping transcription segments
            let overlappingTranscripts = transcriptionResult.segments.filter { transcriptSegment in
                let overlapStart = max(transcriptSegment.startTime, diarizationSegment.startTime)
                let overlapEnd = min(transcriptSegment.endTime, diarizationSegment.endTime)
                return overlapEnd > overlapStart
            }
            
            // Combine transcription text for this speaker segment
            let combinedText = overlappingTranscripts
                .sorted { $0.startTime < $1.startTime }
                .map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Calculate weighted confidence
            let totalDuration = overlappingTranscripts.reduce(0) { $0 + $1.duration }
            let weightedConfidence = totalDuration > 0 ? overlappingTranscripts.reduce(0.0) { sum, segment in
                sum + (segment.confidence * segment.duration)
            } / totalDuration : diarizationSegment.confidence
            
            // Find speaker info
            let speaker = diarizationResult.speakers.first { $0.id == diarizationSegment.speakerId }
            
            let speakerSegment = SpeakerAwareTranscriptionSegment(
                id: UUID(),
                speakerId: diarizationSegment.speakerId,
                speakerName: speaker?.name ?? "話者\(diarizationSegment.speakerId)",
                startTime: diarizationSegment.startTime,
                endTime: diarizationSegment.endTime,
                text: combinedText.isEmpty ? nil : combinedText,
                confidence: min(weightedConfidence, diarizationSegment.confidence),
                words: extractWordsForSegment(overlappingTranscripts),
                language: transcriptionResult.detectedLanguage,
                audioLevel: diarizationSegment.audioLevel,
                speakerCharacteristics: speaker?.characteristics
            )
            
            speakerSegments.append(speakerSegment)
        }
        
        return speakerSegments.sorted { $0.startTime < $1.startTime }
    }
    
    private func extractWordsForSegment(_ transcriptionSegments: [TranscriptionSegment]) -> [WordTimestamp] {
        return transcriptionSegments.flatMap { $0.words ?? [] }.sorted { $0.startTime < $1.startTime }
    }
}

enum WhisperError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat(String)
    case audioTooLong(TimeInterval, TimeInterval)
    case transcriptionFailed(String)
    case modelNotLoaded
    case insufficientMemory
    case invalidAudioData
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .unsupportedFormat(let format):
            return "サポートされていないフォーマットです: \(format)"
        case .audioTooLong(let duration, let maxDuration):
            return "音声が長すぎます: \(duration)秒 (最大: \(maxDuration)秒)"
        case .transcriptionFailed(let reason):
            return "文字起こしに失敗しました: \(reason)"
        case .modelNotLoaded:
            return "モデルが読み込まれていません"
        case .insufficientMemory:
            return "メモリが不足しています"
        case .invalidAudioData:
            return "無効な音声データです"
        }
    }
}
