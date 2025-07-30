import Foundation

// MARK: - ベクトルストアプロトコル

protocol VectorStoreProtocol {
    
    // MARK: - ベクトル操作
    func store(
        id: String,
        embeddings: [[Float]],
        metadata: ContentMetadata,
        chunks: [ContentChunk]
    ) async throws
    
    func search(
        embedding: [Float],
        topK: Int,
        threshold: Double,
        filters: [String: Any]?
    ) async throws -> [VectorSearchResult]
    
    func remove(id: String) async throws
    
    func update(
        id: String,
        embeddings: [[Float]]?,
        metadata: ContentMetadata?
    ) async throws
    
    // MARK: - インデックス管理
    func createIndex(
        name: String,
        dimension: Int,
        metric: VectorMetric
    ) async throws
    
    func deleteIndex(name: String) async throws
    
    func optimizeIndex(name: String) async throws
    
    func getIndexInfo(name: String) async throws -> VectorIndexInfo
    
    // MARK: - バッチ操作
    func batchStore(
        items: [VectorStoreItem]
    ) async throws
    
    func batchSearch(
        embeddings: [[Float]],
        topK: Int,
        threshold: Double,
        filters: [String: Any]?
    ) async throws -> [[VectorSearchResult]]
    
    // MARK: - 統計・メトリクス
    func getStorageStats() async throws -> VectorStorageStats
    
    func getSearchPerformance() async throws -> SearchPerformanceMetrics
}

// MARK: - データ構造

struct VectorSearchResult: Codable {
    let id: String
    let content: String
    let score: Double
    let metadata: Data? // JSON encoded metadata
    let chunkIndex: Int?
}

enum VectorMetric: String, CaseIterable, Codable {
    case cosine = "cosine"
    case euclidean = "euclidean"
    case dotProduct = "dot_product"
    case manhattan = "manhattan"
    
    var displayName: String {
        switch self {
        case .cosine: return "コサイン類似度"
        case .euclidean: return "ユークリッド距離"
        case .dotProduct: return "内積"
        case .manhattan: return "マンハッタン距離"
        }
    }
}

struct VectorIndexInfo: Codable {
    let name: String
    let dimension: Int
    let metric: VectorMetric
    let totalVectors: Int
    let indexSize: Int64
    let createdAt: Date
    let lastOptimized: Date?
    let configuration: IndexConfiguration
}

struct IndexConfiguration: Codable {
    let efConstruction: Int?
    let mLinks: Int?
    let numLists: Int?
    let numProbes: Int?
    let algorithm: IndexAlgorithm
}

enum IndexAlgorithm: String, CaseIterable, Codable {
    case hnsw = "hnsw"
    case ivf = "ivf"
    case flat = "flat"
    case pq = "pq"
    
    var displayName: String {
        switch self {
        case .hnsw: return "HNSW"
        case .ivf: return "IVF"
        case .flat: return "Flat"
        case .pq: return "PQ"
        }
    }
}

struct VectorStoreItem: Codable {
    let id: String
    let embeddings: [[Float]]
    let metadata: ContentMetadata
    let chunks: [ContentChunk]
}

struct VectorStorageStats: Codable {
    let totalVectors: Int
    let totalIndices: Int
    let totalStorageSize: Int64
    let averageVectorDimension: Int
    let indexDistribution: [String: Int]
    let memoryUsage: MemoryUsageStats
}

struct MemoryUsageStats: Codable {
    let totalMemory: Int64
    let usedMemory: Int64
    let indexMemory: Int64
    let cacheMemory: Int64
    let availableMemory: Int64
}

struct SearchPerformanceMetrics: Codable {
    let averageSearchTime: TimeInterval
    let recentSearchTimes: [TimeInterval]
    let throughputPerSecond: Double
    let cacheHitRate: Double
    let indexEfficiency: Double
    let lastMeasuredAt: Date
}

// MARK: - エンベディングサービスプロトコル

protocol EmbeddingServiceProtocol {
    
    // MARK: - エンベディング生成
    func generateEmbedding(text: String) async throws -> [Float]
    
    func generateEmbeddings(texts: [String]) async throws -> [[Float]]
    
    func generateEmbeddingBatch(
        texts: [String],
        batchSize: Int
    ) async throws -> [[Float]]
    
    // MARK: - モデル管理
    func loadModel(model: EmbeddingModel) async throws
    
    func unloadModel() async throws
    
    func getCurrentModel() -> EmbeddingModel?
    
    func getAvailableModels() async -> [EmbeddingModel]
    
    // MARK: - 設定・最適化
    func updateConfiguration(_ configuration: EmbeddingConfiguration) async throws
    
    func getConfiguration() -> EmbeddingConfiguration
    
    func optimizeForPerformance() async throws
    
    func optimizeForAccuracy() async throws
    
    // MARK: - メトリクス
    func getProcessingStats() async throws -> EmbeddingProcessingStats
    
    func getModelInfo() async throws -> EmbeddingModelInfo
}

// MARK: - エンベディング関連データ構造

enum EmbeddingModel: String, CaseIterable, Codable {
    case openaiTextEmbedding3Small = "text-embedding-3-small"
    case openaiTextEmbedding3Large = "text-embedding-3-large"
    case openaiTextEmbeddingAda002 = "text-embedding-ada-002"
    case sentenceTransformersMultilingual = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    case localJapanese = "local-japanese-bert"
    
    var displayName: String {
        switch self {
        case .openaiTextEmbedding3Small:
            return "OpenAI Text Embedding 3 Small"
        case .openaiTextEmbedding3Large:
            return "OpenAI Text Embedding 3 Large"
        case .openaiTextEmbeddingAda002:
            return "OpenAI Ada 002"
        case .sentenceTransformersMultilingual:
            return "Sentence Transformers Multilingual"
        case .localJapanese:
            return "Local Japanese BERT"
        }
    }
    
    var dimension: Int {
        switch self {
        case .openaiTextEmbedding3Small:
            return 1536
        case .openaiTextEmbedding3Large:
            return 3072
        case .openaiTextEmbeddingAda002:
            return 1536
        case .sentenceTransformersMultilingual:
            return 384
        case .localJapanese:
            return 768
        }
    }
    
    var isLocal: Bool {
        switch self {
        case .openaiTextEmbedding3Small, .openaiTextEmbedding3Large, .openaiTextEmbeddingAda002:
            return false
        case .sentenceTransformersMultilingual, .localJapanese:
            return true
        }
    }
    
    var costPerToken: Double? {
        switch self {
        case .openaiTextEmbedding3Small:
            return 0.00002 / 1000.0
        case .openaiTextEmbedding3Large:
            return 0.00013 / 1000.0
        case .openaiTextEmbeddingAda002:
            return 0.0001 / 1000.0
        case .sentenceTransformersMultilingual, .localJapanese:
            return nil // ローカルモデルは無料
        }
    }
}

struct EmbeddingConfiguration {
    let model: EmbeddingModel
    let maxTokens: Int
    let batchSize: Int
    let timeout: TimeInterval
    let retryCount: Int
    let enableCaching: Bool
    let cacheExpiration: TimeInterval
    let preprocessingOptions: PreprocessingOptions
}

struct PreprocessingOptions {
    let normalizeWhitespace: Bool
    let removeSpecialCharacters: Bool
    let lowercaseText: Bool
    let removeStopWords: Bool
    let stemming: Bool
    let maxLength: Int?
    let minLength: Int?
}

struct EmbeddingProcessingStats {
    var totalEmbeddingsGenerated: Int
    var averageProcessingTime: TimeInterval
    var successRate: Double
    var totalTokensProcessed: Int
    var cacheHitRate: Double
    var recentProcessingTimes: [TimeInterval]
    var errorCounts: [String: Int]
    var lastMeasuredAt: Date
}

struct EmbeddingModelInfo {
    let model: EmbeddingModel
    let dimension: Int
    let maxTokens: Int
    let isLoaded: Bool
    let loadedAt: Date?
    let memoryUsage: Int64
    let supportedLanguages: [SupportedLanguage]
    let accuracy: EmbeddingAccuracyMetrics?
}

struct EmbeddingAccuracyMetrics {
    let averageSimilarityScore: Double
    let semanticAccuracy: Double
    let multilingualSupport: Double
    let domainSpecificAccuracy: [String: Double]
    let lastEvaluated: Date
}

// MARK: - テキストチャンキングサービス

class TextChunkingService {
    
    struct ChunkOptions {
        let maxSize: Int
        let overlap: Int
        let preserveSentences: Bool
        let preserveParagraphs: Bool
        let splitOnHeaders: Bool
        let minChunkSize: Int
    }
    
    struct TextChunk {
        let text: String
        let startIndex: Int
        let endIndex: Int
        let chunkNumber: Int
        let metadata: ChunkMetadata?
    }
    
    func chunkText(
        _ text: String,
        maxSize: Int = 1000,
        overlap: Int = 200,
        options: ChunkOptions? = nil
    ) -> [TextChunk] {
        
        let effectiveOptions = options ?? ChunkOptions(
            maxSize: maxSize,
            overlap: overlap,
            preserveSentences: true,
            preserveParagraphs: true,
            splitOnHeaders: false,
            minChunkSize: 100
        )
        
        var chunks: [TextChunk] = []
        var currentPosition = 0
        var chunkNumber = 1
        
        while currentPosition < text.count {
            let startIndex = max(0, currentPosition - effectiveOptions.overlap)
            let endIndex = min(text.count, currentPosition + effectiveOptions.maxSize)
            
            let chunkText = extractChunk(
                from: text,
                startIndex: startIndex,
                endIndex: endIndex,
                options: effectiveOptions
            )
            
            if chunkText.count >= effectiveOptions.minChunkSize {
                let chunk = TextChunk(
                    text: chunkText,
                    startIndex: startIndex,
                    endIndex: endIndex,
                    chunkNumber: chunkNumber,
                    metadata: nil
                )
                chunks.append(chunk)
                chunkNumber += 1
            }
            
            currentPosition += effectiveOptions.maxSize - effectiveOptions.overlap
        }
        
        return chunks
    }
    
    private func extractChunk(
        from text: String,
        startIndex: Int,
        endIndex: Int,
        options: ChunkOptions
    ) -> String {
        
        let startIdx = text.index(text.startIndex, offsetBy: startIndex)
        let endIdx = text.index(text.startIndex, offsetBy: endIndex)
        var chunkText = String(text[startIdx..<endIdx])
        
        // 文の境界を保持
        if options.preserveSentences {
            chunkText = preserveSentenceBoundaries(chunkText)
        }
        
        // 段落の境界を保持
        if options.preserveParagraphs {
            chunkText = preserveParagraphBoundaries(chunkText)
        }
        
        return chunkText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func preserveSentenceBoundaries(_ text: String) -> String {
        // 文の境界を保持する簡単な実装
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？"))
        return sentences.dropLast().joined(separator: "。") + (sentences.last?.isEmpty == false ? "。" : "")
    }
    
    private func preserveParagraphBoundaries(_ text: String) -> String {
        // 段落の境界を保持する簡単な実装
        let paragraphs = text.components(separatedBy: "\n\n")
        return paragraphs.joined(separator: "\n\n")
    }
}