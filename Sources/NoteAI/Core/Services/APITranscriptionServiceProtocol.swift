import Foundation

// MARK: - API Transcription Service Protocol

/// API経由での文字起こしサービスプロトコル
protocol APITranscriptionServiceProtocol {
    
    /// 音声ファイルを文字起こしする
    /// - Parameters:
    ///   - audioURL: 音声ファイルのURL
    ///   - options: 文字起こしオプション
    /// - Returns: 文字起こし結果
    func transcribe(audioURL: URL, options: APITranscriptionOptions) async throws -> TranscriptionResult
    
    /// バッチで複数の音声ファイルを文字起こしする
    /// - Parameters:
    ///   - audioURLs: 音声ファイルのURL配列
    ///   - options: 文字起こしオプション
    /// - Returns: 文字起こし結果配列
    func transcribeBatch(audioURLs: [URL], options: APITranscriptionOptions) async throws -> [TranscriptionResult]
    
    /// サポートされる言語の一覧を取得
    /// - Returns: サポートされる言語コード配列
    func getSupportedLanguages() async throws -> [String]
    
    /// 利用可能なモデルの一覧を取得
    /// - Returns: 利用可能なモデル配列
    func getAvailableModels() async throws -> [String]
    
    /// APIの利用状況を取得
    /// - Returns: API利用状況
    func getUsageStats() async throws -> APIUsageStats
}

/// API利用統計
struct APIUsageStats {
    let totalRequests: Int
    let totalDuration: TimeInterval
    let remainingQuota: Int?
    let resetDate: Date?
    let costThisMonth: Double
}

/// 文字起こしオプション
struct APITranscriptionOptions {
    let language: String?
    let model: String?
    let prompt: String?
    let temperature: Double?
    let maxTokens: Int?
    let enableSpeakerDiarization: Bool
    let enableTimestamps: Bool
    let enablePunctuation: Bool
    
    init(
        language: String? = nil,
        model: String? = nil,
        prompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        enableSpeakerDiarization: Bool = false,
        enableTimestamps: Bool = true,
        enablePunctuation: Bool = true
    ) {
        self.language = language
        self.model = model
        self.prompt = prompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.enableSpeakerDiarization = enableSpeakerDiarization
        self.enableTimestamps = enableTimestamps
        self.enablePunctuation = enablePunctuation
    }
}