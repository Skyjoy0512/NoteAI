import Foundation

// MARK: - RAG共通型定義とエラーハンドリング

// MARK: - Document Management Types

struct DocumentChunk: Codable, Identifiable, Hashable {
    let id: UUID
    let documentId: String
    let content: String
    let chunkIndex: Int
    let metadata: DocumentChunkMetadata
    let embedding: [Float]?
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: UUID = UUID(),
        documentId: String,
        content: String,
        chunkIndex: Int,
        metadata: DocumentChunkMetadata = DocumentChunkMetadata(),
        embedding: [Float]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.content = content
        self.chunkIndex = chunkIndex
        self.metadata = metadata
        self.embedding = embedding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DocumentChunkMetadata: Codable, Hashable {
    let sourceType: String
    let language: String
    let confidence: Double
    let tags: [String]
    let wordCount: Int
    
    init(
        sourceType: String = "unknown",
        language: String = "ja",
        confidence: Double = 1.0,
        tags: [String] = [],
        wordCount: Int = 0
    ) {
        self.sourceType = sourceType
        self.language = language
        self.confidence = confidence
        self.tags = tags
        self.wordCount = wordCount
    }
}

struct VectorDocument: Codable, Identifiable, Hashable {
    let id: UUID
    let documentId: String
    let embedding: [Float]
    let metadata: VectorMetadata
    let similarity: Double?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        documentId: String,
        embedding: [Float],
        metadata: VectorMetadata = VectorMetadata(),
        similarity: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.embedding = embedding
        self.metadata = metadata
        self.similarity = similarity
        self.createdAt = createdAt
    }
}

struct VectorMetadata: Codable, Hashable {
    let sourceType: String
    let chunkIndex: Int
    let originalText: String
    let language: String
    
    init(
        sourceType: String = "document",
        chunkIndex: Int = 0,
        originalText: String = "",
        language: String = "ja"
    ) {
        self.sourceType = sourceType
        self.chunkIndex = chunkIndex
        self.originalText = originalText
        self.language = language
    }
}

// MARK: - Usage Monitoring Types

enum UsagePeriod: String, CaseIterable, Codable {
    case today = "today"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case lastMonth = "lastMonth"
    case last3Months = "last3Months"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .today: return "今日"
        case .thisWeek: return "今週"
        case .thisMonth: return "今月"
        case .lastMonth: return "先月"
        case .last3Months: return "過去3ヶ月"
        case .custom: return "カスタム"
        }
    }
    
    var dateRange: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: startOfWeek, end: now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: startOfMonth, end: now)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
            let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
            return DateInterval(start: startOfLastMonth, end: endOfLastMonth)
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return DateInterval(start: threeMonthsAgo, end: now)
        case .custom:
            // Custom range should be set externally
            return DateInterval(start: now, end: now)
        }
    }
}

enum UsageMetric: String, CaseIterable, Codable {
    case apiCalls = "apiCalls"
    case tokens = "tokens"
    case cost = "cost"
    case responseTime = "responseTime"
    case successRate = "successRate"
    case errorRate = "errorRate"
    
    var displayName: String {
        switch self {
        case .apiCalls: return "API呼び出し数"
        case .tokens: return "トークン使用量"
        case .cost: return "コスト"
        case .responseTime: return "応答時間"
        case .successRate: return "成功率"
        case .errorRate: return "エラー率"
        }
    }
    
    var unit: String {
        switch self {
        case .apiCalls: return "回"
        case .tokens: return "トークン"
        case .cost: return "円"
        case .responseTime: return "秒"
        case .successRate: return "%"
        case .errorRate: return "%"
        }
    }
}

// MARK: - 言語サポート

enum SupportedLanguage: String, CaseIterable, Codable {
    case japanese = "ja"
    case english = "en"
    case chinese = "zh"
    case korean = "ko"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        case .chinese: return "中文"
        case .korean: return "한국어"
        case .auto: return "自動検出"
        }
    }
    
    var nativeName: String {
        return displayName
    }
    
    var code: String {
        return rawValue
    }
}

// MARK: - RAG結果の統一型

struct RAGResult<T> {
    let data: T
    let confidence: Double
    let processingTime: TimeInterval
    let sources: [SourceReference]
    let metadata: RAGResultMetadata
    
    init(
        data: T,
        confidence: Double,
        processingTime: TimeInterval,
        sources: [SourceReference] = [],
        metadata: RAGResultMetadata
    ) {
        self.data = data
        self.confidence = confidence
        self.processingTime = processingTime
        self.sources = sources
        self.metadata = metadata
    }
}

struct RAGResultMetadata {
    let modelUsed: String
    let tokenCount: Int
    let retrievalMethod: RetrievalMethod
    let contextLength: Int
    let qualityScore: Double
    let timestamp: Date
    
    init(
        modelUsed: String,
        tokenCount: Int,
        retrievalMethod: RetrievalMethod,
        contextLength: Int,
        qualityScore: Double,
        timestamp: Date = Date()
    ) {
        self.modelUsed = modelUsed
        self.tokenCount = tokenCount
        self.retrievalMethod = retrievalMethod
        self.contextLength = contextLength
        self.qualityScore = qualityScore
        self.timestamp = timestamp
    }
}

// MARK: - RAG統一エラー型

enum RAGError: Error, LocalizedError {
    case embeddingError(EmbeddingServiceError)
    case vectorStoreError(VectorStoreError)
    case searchError(String)
    case indexingError(String)
    case contextBuildingError(String)
    case insufficientData(String)
    case configurationError(String)
    case modelNotAvailable(String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .embeddingError(let error):
            return "Embedding error: \(error.localizedDescription)"
        case .vectorStoreError(let error):
            return "Vector store error: \(error.localizedDescription)"
        case .searchError(let message):
            return "Search error: \(message)"
        case .indexingError(let message):
            return "Indexing error: \(message)"
        case .contextBuildingError(let message):
            return "Context building error: \(message)"
        case .insufficientData(let message):
            return "Insufficient data: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        case .rateLimitExceeded(let retryAfter):
            let retryInfo = retryAfter.map { " (retry after \($0)s)" } ?? ""
            return "Rate limit exceeded\(retryInfo)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .embeddingError, .vectorStoreError:
            return "システム管理者に連絡してください"
        case .searchError, .indexingError:
            return "検索条件を変更して再試行してください"
        case .contextBuildingError:
            return "プロジェクトデータを確認してください"
        case .insufficientData:
            return "より多くのデータを追加してください"
        case .configurationError:
            return "設定を確認してください"
        case .modelNotAvailable:
            return "別のモデルを選択してください"
        case .rateLimitExceeded:
            return "しばらく待ってから再試行してください"
        case .networkError:
            return "ネットワーク接続を確認してください"
        }
    }
}

// MARK: - 検索フィルターとオプションの統一

struct UnifiedSearchOptions {
    let topK: Int
    let threshold: Double
    let includeMetadata: Bool
    let enableReranking: Bool
    let maxContextLength: Int
    let filters: SearchFilters?
    let retrievalMethod: RetrievalMethod
    
    static let defaultOptions = UnifiedSearchOptions(
        topK: 10,
        threshold: 0.7,
        includeMetadata: true,
        enableReranking: false,
        maxContextLength: 4000,
        filters: nil,
        retrievalMethod: .semantic
    )
    
    func withFilters(_ filters: SearchFilters) -> UnifiedSearchOptions {
        return UnifiedSearchOptions(
            topK: topK,
            threshold: threshold,
            includeMetadata: includeMetadata,
            enableReranking: enableReranking,
            maxContextLength: maxContextLength,
            filters: filters,
            retrievalMethod: retrievalMethod
        )
    }
}

// MARK: - パフォーマンス最適化のための結果キャッシュ

protocol RAGCacheProtocol {
    func get<T: Codable & Sendable>(key: String, type: T.Type) async -> T?
    func set<T: Codable & Sendable>(key: String, value: T, expiration: TimeInterval) async
    func remove(key: String) async
    func clear() async
    func getStats() async -> CacheStats
}

struct CacheStats {
    let hitCount: Int
    let missCount: Int
    let totalRequests: Int
    let averageResponseTime: TimeInterval
    let cacheSize: Int
    
    var hitRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(hitCount) / Double(totalRequests)
    }
}

@globalActor
actor RAGCache: RAGCacheProtocol {
    static let shared = RAGCache()
    
    private var cache: [String: CacheEntry] = [:]
    private var stats = CacheStats(
        hitCount: 0,
        missCount: 0,
        totalRequests: 0,
        averageResponseTime: 0,
        cacheSize: 0
    )
    private let maxCacheSize = 1000
    
    private struct CacheEntry {
        let data: Data
        let expirationDate: Date
        let accessCount: Int
        let lastAccessed: Date
    }
    
    func get<T: Codable & Sendable>(key: String, type: T.Type) async -> T? {
        let startTime = Date()
        defer {
            let responseTime = Date().timeIntervalSince(startTime)
            updateStats(hit: cache[key] != nil, responseTime: responseTime)
        }
        
        guard let entry = cache[key] else {
            return nil
        }
        
        if entry.expirationDate < Date() {
            cache.removeValue(forKey: key)
            return nil
        }
        
        // アクセス情報を更新
        cache[key] = CacheEntry(
            data: entry.data,
            expirationDate: entry.expirationDate,
            accessCount: entry.accessCount + 1,
            lastAccessed: Date()
        )
        
        return try? JSONDecoder().decode(type, from: entry.data)
    }
    
    func set<T: Codable & Sendable>(key: String, value: T, expiration: TimeInterval) async {
        guard let data = try? JSONEncoder().encode(value) else { return }
        
        let entry = CacheEntry(
            data: data,
            expirationDate: Date().addingTimeInterval(expiration),
            accessCount: 0,
            lastAccessed: Date()
        )
        
        cache[key] = entry
        
        // キャッシュサイズ制限
        if cache.count > maxCacheSize {
            await evictLeastUsed()
        }
        
        await updateCacheSize()
    }
    
    func remove(key: String) async {
        cache.removeValue(forKey: key)
        await updateCacheSize()
    }
    
    func clear() async {
        cache.removeAll()
        await updateCacheSize()
    }
    
    func getStats() async -> CacheStats {
        return stats
    }
    
    private func evictLeastUsed() async {
        let sortedEntries = cache.sorted { first, second in
            let firstEntry = first.value
            let secondEntry = second.value
            
            // 最初にアクセス回数で比較
            if firstEntry.accessCount != secondEntry.accessCount {
                return firstEntry.accessCount < secondEntry.accessCount
            }
            
            // 同じアクセス回数の場合は最終アクセス時間で比較
            return firstEntry.lastAccessed < secondEntry.lastAccessed
        }
        
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize + 100)
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    private func updateStats(hit: Bool, responseTime: TimeInterval) {
        let newTotalRequests = stats.totalRequests + 1
        let newHitCount = stats.hitCount + (hit ? 1 : 0)
        let newMissCount = stats.missCount + (hit ? 0 : 1)
        
        let newAverageResponseTime = (stats.averageResponseTime * Double(stats.totalRequests) + responseTime) / Double(newTotalRequests)
        
        stats = CacheStats(
            hitCount: newHitCount,
            missCount: newMissCount,
            totalRequests: newTotalRequests,
            averageResponseTime: newAverageResponseTime,
            cacheSize: cache.count
        )
    }
    
    private func updateCacheSize() async {
        stats = CacheStats(
            hitCount: stats.hitCount,
            missCount: stats.missCount,
            totalRequests: stats.totalRequests,
            averageResponseTime: stats.averageResponseTime,
            cacheSize: cache.count
        )
    }
}

// MARK: - RAGパフォーマンス測定

class RAGPerformanceMonitor {
    static let shared = RAGPerformanceMonitor()
    
    private var metrics: [String: [PerformanceMetric]] = [:]
    private let maxMetricsPerOperation = 100
    
    private struct PerformanceMetric {
        let duration: TimeInterval
        let success: Bool
        let timestamp: Date
        let metadata: [String: Any]
    }
    
    func startMeasurement() -> PerformanceMeasurement {
        return PerformanceMeasurement(startTime: Date())
    }
    
    func recordMetric(
        operation: String,
        measurement: PerformanceMeasurement,
        success: Bool,
        metadata: [String: Any] = [:]
    ) {
        let metric = PerformanceMetric(
            duration: measurement.duration,
            success: success,
            timestamp: measurement.startTime,
            metadata: metadata
        )
        
        if metrics[operation] == nil {
            metrics[operation] = []
        }
        
        metrics[operation]?.append(metric)
        
        // 最新のメトリクスのみ保持
        if let count = metrics[operation]?.count, count > maxMetricsPerOperation {
            metrics[operation] = Array(metrics[operation]!.suffix(maxMetricsPerOperation))
        }
    }
    
    func getAveragePerformance(for operation: String) -> PerformanceStats? {
        guard let operationMetrics = metrics[operation], !operationMetrics.isEmpty else {
            return nil
        }
        
        let successfulMetrics = operationMetrics.filter { $0.success }
        let averageDuration = operationMetrics.map { $0.duration }.reduce(0, +) / Double(operationMetrics.count)
        let successRate = Double(successfulMetrics.count) / Double(operationMetrics.count)
        
        return PerformanceStats(
            operation: operation,
            averageDuration: averageDuration,
            successRate: successRate,
            totalOperations: operationMetrics.count,
            recentOperations: operationMetrics.suffix(10).map { "\($0.timestamp)" }
        )
    }
    
    func getAllPerformanceStats() -> [PerformanceStats] {
        return metrics.compactMap { operation, _ in
            getAveragePerformance(for: operation)
        }
    }
}

struct PerformanceMeasurement {
    let startTime: Date
    
    var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
}

struct PerformanceStats {
    let operation: String
    let averageDuration: TimeInterval
    let successRate: Double
    let totalOperations: Int
    let recentOperations: [String] // Simplified to avoid exposing private types
}

// MARK: - ログとデバッグのための統一インターフェース

enum RAGLogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}

protocol RAGLoggerProtocol {
    func log(level: RAGLogLevel, message: String, context: [String: Any]?)
}

class RAGLogger: RAGLoggerProtocol {
    static let shared = RAGLogger()
    
    private let isDebugMode = true // TODO: 設定から取得
    
    func log(level: RAGLogLevel, message: String, context: [String: Any]? = nil) {
        guard shouldLog(level: level) else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = levelString(for: level)
        let contextString = formatContext(context)
        
        print("[\(timestamp)] [\(levelString)] [RAG] \(message)\(contextString)")
    }
    
    private func shouldLog(level: RAGLogLevel) -> Bool {
        if !isDebugMode && level == .debug {
            return false
        }
        return true
    }
    
    private func levelString(for level: RAGLogLevel) -> String {
        switch level {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    private func formatContext(_ context: [String: Any]?) -> String {
        guard let context = context, !context.isEmpty else { return "" }
        
        let contextItems = context.map { key, value in
            "\(key)=\(value)"
        }.joined(separator: ", ")
        
        return " {\(contextItems)}"
    }
}

// MARK: - RAG設定の統一管理

struct RAGConfiguration {
    let embeddingModel: EmbeddingModel
    let searchOptions: UnifiedSearchOptions
    let cacheConfiguration: CacheConfiguration
    let performanceSettings: PerformanceSettings
    let loggingSettings: LoggingSettings
    
    static let defaultConfiguration = RAGConfiguration(
        embeddingModel: .openaiTextEmbedding3Small,
        searchOptions: .defaultOptions,
        cacheConfiguration: CacheConfiguration.defaultConfiguration,
        performanceSettings: PerformanceSettings.defaultSettings,
        loggingSettings: LoggingSettings.defaultSettings
    )
}

struct CacheConfiguration {
    let enableCaching: Bool
    let defaultExpiration: TimeInterval
    let maxCacheSize: Int
    let evictionPolicy: CacheEvictionPolicy
    
    static let defaultConfiguration = CacheConfiguration(
        enableCaching: true,
        defaultExpiration: 3600, // 1時間
        maxCacheSize: 1000,
        evictionPolicy: .leastRecentlyUsed
    )
}

enum CacheEvictionPolicy {
    case leastRecentlyUsed
    case leastFrequentlyUsed
    case timeToLive
}

struct PerformanceSettings {
    let enableMetrics: Bool
    let metricsRetentionCount: Int
    let slowOperationThreshold: TimeInterval
    
    static let defaultSettings = PerformanceSettings(
        enableMetrics: true,
        metricsRetentionCount: 100,
        slowOperationThreshold: 5.0
    )
}

struct LoggingSettings {
    let enableLogging: Bool
    let logLevel: RAGLogLevel
    let logToFile: Bool
    let logFileURL: URL?
    
    static let defaultSettings = LoggingSettings(
        enableLogging: true,
        logLevel: .info,
        logToFile: false,
        logFileURL: nil
    )
}

// MARK: - ヘルパー拡張

extension TimeInterval {
    var formattedDuration: String {
        if self < 1.0 {
            return String(format: "%.0fms", self * 1000)
        } else if self < 60.0 {
            return String(format: "%.2fs", self)
        } else {
            let minutes = Int(self / 60)
            let seconds = Int(self.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

extension Double {
    var percentageString: String {
        return String(format: "%.1f%%", self * 100)
    }
    
    var confidenceString: String {
        switch self {
        case 0.9...1.0: return "非常に高い"
        case 0.7..<0.9: return "高い"
        case 0.5..<0.7: return "中程度"
        case 0.3..<0.5: return "低い"
        default: return "非常に低い"
        }
    }
}

// MARK: - RAG操作の統一インターフェース

protocol RAGOperationProtocol {
    associatedtype Input
    associatedtype Output
    
    func execute(input: Input) async throws -> RAGResult<Output>
    var operationName: String { get }
}

// MARK: - 型安全なキーチェーン拡張

extension String {
    static func cacheKey(
        operation: String,
        parameters: [String: Any]
    ) -> String {
        let parameterString = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        
        return "\(operation)_\(parameterString.djb2hash)"
    }
    
    var djb2hash: Int {
        return self.unicodeScalars.reduce(5381) { hash, scalar in
            return ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
    }
}