import Foundation

// MARK: - エンベディングサービス実装

@MainActor
class EmbeddingService: EmbeddingServiceProtocol {
    
    // MARK: - 依存関係
    private let llmService: LLMServiceProtocol
    private let apiKeyManager: APIKeyManagerProtocol
    private let cacheManager: EmbeddingCacheManager
    
    // MARK: - 設定
    private var configuration: EmbeddingConfiguration
    private var currentModel: EmbeddingModel?
    private var processingStats = EmbeddingProcessingStats(
        totalEmbeddingsGenerated: 0,
        averageProcessingTime: 0,
        successRate: 1.0,
        totalTokensProcessed: 0,
        cacheHitRate: 0,
        recentProcessingTimes: [],
        errorCounts: [:],
        lastMeasuredAt: Date()
    )
    
    init(
        llmService: LLMServiceProtocol,
        apiKeyManager: APIKeyManagerProtocol,
        configuration: EmbeddingConfiguration? = nil
    ) {
        self.llmService = llmService
        self.apiKeyManager = apiKeyManager
        self.cacheManager = EmbeddingCacheManager()
        
        self.configuration = configuration ?? EmbeddingConfiguration(
            model: .openaiTextEmbedding3Small,
            maxTokens: 8192,
            batchSize: 10,
            timeout: 30.0,
            retryCount: 3,
            enableCaching: true,
            cacheExpiration: 3600,
            preprocessingOptions: PreprocessingOptions(
                normalizeWhitespace: true,
                removeSpecialCharacters: false,
                lowercaseText: false,
                removeStopWords: false,
                stemming: false,
                maxLength: 8192,
                minLength: 1
            )
        )
    }
    
    // MARK: - エンベディング生成実装
    
    func generateEmbedding(text: String) async throws -> [Float] {
        let startTime = Date()
        
        // 前処理
        let processedText = preprocessText(text)
        
        // キャッシュチェック
        if configuration.enableCaching,
           let cachedEmbedding = await cacheManager.getEmbedding(
               text: processedText,
               model: configuration.model
           ) {
            updateCacheHitStats()
            return cachedEmbedding
        }
        
        var embedding: [Float]
        
        // モデル別の処理
        if configuration.model.isLocal {
            embedding = try await generateLocalEmbedding(text: processedText)
        } else {
            embedding = try await generateAPIEmbedding(text: processedText)
        }
        
        // キャッシュに保存
        if configuration.enableCaching {
            await cacheManager.setEmbedding(
                text: processedText,
                model: configuration.model,
                embedding: embedding,
                expiration: configuration.cacheExpiration
            )
        }
        
        // 統計更新
        let processingTime = Date().timeIntervalSince(startTime)
        updateProcessingStats(processingTime: processingTime, tokenCount: estimateTokenCount(processedText))
        
        return embedding
    }
    
    func generateEmbeddings(texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        
        // バッチサイズに分割して処理
        return try await generateEmbeddingBatch(
            texts: texts,
            batchSize: configuration.batchSize
        )
    }
    
    func generateEmbeddingBatch(
        texts: [String],
        batchSize: Int
    ) async throws -> [[Float]] {
        
        var allEmbeddings: [[Float]] = []
        
        for batch in texts.chunked(into: batchSize) {
            let batchEmbeddings = try await processBatch(batch)
            allEmbeddings.append(contentsOf: batchEmbeddings)
        }
        
        return allEmbeddings
    }
    
    // MARK: - モデル管理実装
    
    func loadModel(model: EmbeddingModel) async throws {
        if model.isLocal {
            try await loadLocalModel(model)
        } else {
            // API モデルは動的ロード不要
            currentModel = model
            configuration.model = model
        }
    }
    
    func unloadModel() async throws {
        if let model = currentModel, model.isLocal {
            try await unloadLocalModel(model)
        }
        currentModel = nil
    }
    
    func getCurrentModel() -> EmbeddingModel? {
        return currentModel
    }
    
    func getAvailableModels() -> [EmbeddingModel] {
        var availableModels: [EmbeddingModel] = []
        
        // APIモデルの可用性チェック
        if apiKeyManager.hasAPIKey(for: .openai) {
            availableModels.append(.openaiTextEmbedding3Small)
            availableModels.append(.openaiTextEmbedding3Large)
            availableModels.append(.openaiTextEmbeddingAda002)
        }
        
        // ローカルモデルは常に利用可能とする
        availableModels.append(.sentenceTransformersMultilingual)
        availableModels.append(.localJapanese)
        
        return availableModels
    }
    
    // MARK: - 設定・最適化実装
    
    func updateConfiguration(_ configuration: EmbeddingConfiguration) async throws {
        self.configuration = configuration
        
        // モデルが変更された場合は再ロード
        if let currentModel = currentModel, currentModel != configuration.model {
            try await unloadModel()
            try await loadModel(model: configuration.model)
        }
    }
    
    func getConfiguration() -> EmbeddingConfiguration {
        return configuration
    }
    
    func optimizeForPerformance() async throws {
        configuration = EmbeddingConfiguration(
            model: .openaiTextEmbedding3Small, // 高速モデル
            maxTokens: 4096,
            batchSize: 20,
            timeout: 15.0,
            retryCount: 2,
            enableCaching: true,
            cacheExpiration: 7200,
            preprocessingOptions: PreprocessingOptions(
                normalizeWhitespace: true,
                removeSpecialCharacters: true,
                lowercaseText: true,
                removeStopWords: false,
                stemming: false,
                maxLength: 4096,
                minLength: 5
            )
        )
    }
    
    func optimizeForAccuracy() async throws {
        configuration = EmbeddingConfiguration(
            model: .openaiTextEmbedding3Large, // 高精度モデル
            maxTokens: 8192,
            batchSize: 5,
            timeout: 60.0,
            retryCount: 5,
            enableCaching: true,
            cacheExpiration: 3600,
            preprocessingOptions: PreprocessingOptions(
                normalizeWhitespace: true,
                removeSpecialCharacters: false,
                lowercaseText: false,
                removeStopWords: false,
                stemming: false,
                maxLength: 8192,
                minLength: 1
            )
        )
    }
    
    // MARK: - メトリクス実装
    
    func getProcessingStats() async throws -> EmbeddingProcessingStats {
        return processingStats
    }
    
    func getModelInfo() async throws -> EmbeddingModelInfo {
        let model = configuration.model
        
        return EmbeddingModelInfo(
            model: model,
            dimension: model.dimension,
            maxTokens: configuration.maxTokens,
            isLoaded: currentModel == model,
            loadedAt: currentModel == model ? Date() : nil,
            memoryUsage: estimateMemoryUsage(for: model),
            supportedLanguages: getSupportedLanguages(for: model),
            accuracy: nil // TODO: 評価メトリクス実装
        )
    }
    
    // MARK: - 内部メソッド
    
    private func preprocessText(_ text: String) -> String {
        var processedText = text
        
        let options = configuration.preprocessingOptions
        
        if options.normalizeWhitespace {
            processedText = processedText.replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if options.removeSpecialCharacters {
            processedText = processedText.replacingOccurrences(
                of: "[^\\w\\s\\p{P}]",
                with: "",
                options: .regularExpression
            )
        }
        
        if options.lowercaseText {
            processedText = processedText.lowercased()
        }
        
        // 長さ制限
        if let maxLength = options.maxLength, processedText.count > maxLength {
            let endIndex = processedText.index(processedText.startIndex, offsetBy: maxLength)
            processedText = String(processedText[..<endIndex])
        }
        
        if let minLength = options.minLength, processedText.count < minLength {
            processedText = processedText.padding(
                toLength: minLength,
                withPad: " ",
                startingAt: 0
            )
        }
        
        return processedText
    }
    
    private func generateAPIEmbedding(text: String) async throws -> [Float] {
        switch configuration.model {
        case .openaiTextEmbedding3Small, .openaiTextEmbedding3Large, .openaiTextEmbeddingAda002:
            return try await generateOpenAIEmbedding(text: text)
        default:
            throw EmbeddingServiceError.unsupportedModel(configuration.model.rawValue)
        }
    }
    
    private func generateOpenAIEmbedding(text: String) async throws -> [Float] {
        let request = OpenAIEmbeddingRequest(
            input: [text],
            model: configuration.model.rawValue,
            dimensions: configuration.model.dimension
        )
        
        let response = try await callOpenAIEmbeddingAPI(request: request)
        
        guard let embedding = response.data.first?.embedding else {
            throw EmbeddingServiceError.invalidResponse("No embedding in response")
        }
        
        return embedding
    }
    
    private func generateLocalEmbedding(text: String) async throws -> [Float] {
        // ローカルモデルの実装（プレースホルダー）
        switch configuration.model {
        case .sentenceTransformersMultilingual:
            return try await generateSentenceTransformersEmbedding(text: text)
        case .localJapanese:
            return try await generateLocalJapaneseEmbedding(text: text)
        default:
            throw EmbeddingServiceError.unsupportedModel(configuration.model.rawValue)
        }
    }
    
    private func generateSentenceTransformersEmbedding(text: String) async throws -> [Float] {
        // Sentence Transformers実装（プレースホルダー）
        // 実際の実装では、Python bridgeまたはONNXモデルを使用
        return Array(repeating: 0.0, count: 384)
    }
    
    private func generateLocalJapaneseEmbedding(text: String) async throws -> [Float] {
        // 日本語BERTモデル実装（プレースホルダー）
        return Array(repeating: 0.0, count: 768)
    }
    
    private func processBatch(_ texts: [String]) async throws -> [[Float]] {
        if configuration.model.isLocal {
            // ローカルモデルの場合は並列処理
            return try await withThrowingTaskGroup(of: [Float].self) { group in
                for text in texts {
                    group.addTask {
                        return try await self.generateEmbedding(text: text)
                    }
                }
                
                var embeddings: [[Float]] = []
                for try await embedding in group {
                    embeddings.append(embedding)
                }
                return embeddings
            }
        } else {
            // APIモデルの場合はバッチAPIを使用
            return try await generateAPIBatchEmbeddings(texts: texts)
        }
    }
    
    private func generateAPIBatchEmbeddings(texts: [String]) async throws -> [[Float]] {
        let request = OpenAIEmbeddingRequest(
            input: texts,
            model: configuration.model.rawValue,
            dimensions: configuration.model.dimension
        )
        
        let response = try await callOpenAIEmbeddingAPI(request: request)
        return response.data.map { $0.embedding }
    }
    
    private func callOpenAIEmbeddingAPI(request: OpenAIEmbeddingRequest) async throws -> OpenAIEmbeddingResponse {
        // llmServiceを使用してAPI呼び出し
        let jsonData = try JSONEncoder().encode(request)
        
        guard let apiKey = try await apiKeyManager.getAPIKey(for: .openai) else {
            throw EmbeddingServiceError.noAPIKey
        }
        
        let urlRequest = try createOpenAIRequest(jsonData: jsonData, apiKey: apiKey)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw EmbeddingServiceError.apiError("API request failed")
        }
        
        return try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)
    }
    
    private func createOpenAIRequest(jsonData: Data, apiKey: String) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = configuration.timeout
        
        return request
    }
    
    private func loadLocalModel(_ model: EmbeddingModel) async throws {
        // ローカルモデルのロード処理（プレースホルダー）
        currentModel = model
    }
    
    private func unloadLocalModel(_ model: EmbeddingModel) async throws {
        // ローカルモデルのアンロード処理（プレースホルダー）
    }
    
    private func updateProcessingStats(processingTime: TimeInterval, tokenCount: Int) {
        var stats = processingStats
        
        stats.totalEmbeddingsGenerated += 1
        stats.totalTokensProcessed += tokenCount
        
        // 平均処理時間更新
        let totalTime = stats.averageProcessingTime * Double(stats.totalEmbeddingsGenerated - 1) + processingTime
        stats.averageProcessingTime = totalTime / Double(stats.totalEmbeddingsGenerated)
        
        // 最近の処理時間記録
        stats.recentProcessingTimes.append(processingTime)
        if stats.recentProcessingTimes.count > 100 {
            stats.recentProcessingTimes.removeFirst()
        }
        
        stats.lastMeasuredAt = Date()
        processingStats = stats
    }
    
    private func updateCacheHitStats() {
        var stats = processingStats
        
        let totalRequests = stats.totalEmbeddingsGenerated + 1
        let cacheHits = stats.cacheHitRate * Double(stats.totalEmbeddingsGenerated) + 1
        stats.cacheHitRate = cacheHits / Double(totalRequests)
        
        processingStats = stats
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // 簡単なトークン数推定
        return text.split(separator: " ").count
    }
    
    private func estimateMemoryUsage(for model: EmbeddingModel) -> Int64 {
        // モデル別メモリ使用量推定
        switch model {
        case .openaiTextEmbedding3Small, .openaiTextEmbedding3Large, .openaiTextEmbeddingAda002:
            return 0 // API モデルはローカルメモリ使用なし
        case .sentenceTransformersMultilingual:
            return 512 * 1024 * 1024 // 512MB
        case .localJapanese:
            return 1024 * 1024 * 1024 // 1GB
        }
    }
    
    private func getSupportedLanguages(for model: EmbeddingModel) -> [SupportedLanguage] {
        switch model {
        case .openaiTextEmbedding3Small, .openaiTextEmbedding3Large, .openaiTextEmbeddingAda002:
            return [.japanese, .english] // OpenAIは多言語対応
        case .sentenceTransformersMultilingual:
            return [.japanese, .english] // 多言語モデル
        case .localJapanese:
            return [.japanese] // 日本語特化
        }
    }
}

// MARK: - エンベディングキャッシュマネージャー

actor EmbeddingCacheManager {
    
    private var cache: [String: CachedEmbedding] = [:]
    private let maxCacheSize = 10000
    
    struct CachedEmbedding {
        let embedding: [Float]
        let timestamp: Date
        let expirationDate: Date
        let model: EmbeddingModel
    }
    
    func getEmbedding(text: String, model: EmbeddingModel) -> [Float]? {
        let key = cacheKey(text: text, model: model)
        
        guard let cached = cache[key] else { return nil }
        
        // 有効期限チェック
        if cached.expirationDate < Date() {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return cached.embedding
    }
    
    func setEmbedding(
        text: String,
        model: EmbeddingModel,
        embedding: [Float],
        expiration: TimeInterval
    ) {
        let key = cacheKey(text: text, model: model)
        let expirationDate = Date().addingTimeInterval(expiration)
        
        let cached = CachedEmbedding(
            embedding: embedding,
            timestamp: Date(),
            expirationDate: expirationDate,
            model: model
        )
        
        cache[key] = cached
        
        // キャッシュサイズ制限
        if cache.count > maxCacheSize {
            cleanupOldEntries()
        }
    }
    
    private func cacheKey(text: String, model: EmbeddingModel) -> String {
        let textHash = text.djb2hash
        return "\(model.rawValue)_\(textHash)"
    }
    
    private func cleanupOldEntries() {
        let now = Date()
        
        // 期限切れエントリを削除
        cache = cache.filter { $0.value.expirationDate >= now }
        
        // まだ制限を超えている場合は古いエントリから削除
        if cache.count > maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize)
            
            for (key, _) in entriesToRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - データ構造

struct OpenAIEmbeddingRequest: Codable {
    let input: [String]
    let model: String
    let dimensions: Int?
    
    init(input: [String], model: String, dimensions: Int? = nil) {
        self.input = input
        self.model = model
        self.dimensions = dimensions
    }
}

struct OpenAIEmbeddingResponse: Codable {
    let data: [OpenAIEmbeddingData]
    let model: String
    let usage: OpenAIEmbeddingUsage?
}

struct OpenAIEmbeddingData: Codable {
    let embedding: [Float]
    let index: Int
    let object: String
}

struct OpenAIEmbeddingUsage: Codable {
    let promptTokens: Int
    let totalTokens: Int
    
    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - エラー定義

enum EmbeddingServiceError: Error, LocalizedError {
    case unsupportedModel(String)
    case noAPIKey
    case apiError(String)
    case invalidResponse(String)
    case modelNotLoaded
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedModel(let model):
            return "Unsupported embedding model: \(model)"
        case .noAPIKey:
            return "No API key available for embedding service"
        case .apiError(let message):
            return "Embedding API error: \(message)"
        case .invalidResponse(let message):
            return "Invalid embedding response: \(message)"
        case .modelNotLoaded:
            return "Embedding model not loaded"
        case .configurationError(let message):
            return "Embedding configuration error: \(message)"
        }
    }
}

// MARK: - 拡張

extension String {
    var djb2hash: Int {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) { (hash, scalar) in
            return ((hash << 5) &+ hash) &+ Int(scalar)
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}