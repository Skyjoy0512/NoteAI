import Foundation

// MARK: - RAGサービスプロトコル

protocol RAGServiceProtocol {
    
    // MARK: - ベクトル検索
    func searchSimilarContent(
        query: String,
        projectId: UUID?,
        topK: Int,
        threshold: Double
    ) async throws -> [SemanticSearchResult]
    
    func indexContent(
        _ content: String,
        metadata: ContentMetadata
    ) async throws -> String
    
    func removeIndex(indexId: String) async throws
    
    // MARK: - セマンティック検索
    func semanticSearch(
        query: String,
        filters: SearchFilters?,
        options: SearchOptions
    ) async throws -> SemanticSearchResponse
    
    func generateEmbedding(text: String) async throws -> [Float]
    
    // MARK: - 文書統合
    func indexDocument(
        document: Document,
        metadata: DocumentMetadata
    ) async throws -> IndexedDocument
    
    func getRelevantContext(
        for query: String,
        projectId: UUID?,
        maxTokens: Int
    ) async throws -> RAGContext
    
    // MARK: - 知識ベース管理
    func buildKnowledgeBase(
        projectId: UUID,
        includeTranscriptions: Bool,
        includeDocuments: Bool
    ) async throws -> KnowledgeBase
    
    func updateKnowledgeBase(
        knowledgeBaseId: String,
        newContent: [ContentItem]
    ) async throws
    
    func getKnowledgeBaseSummary(
        projectId: UUID
    ) async throws -> KnowledgeBaseSummary
    
    // MARK: - RAG質問応答
    func answerQuestion(
        question: String,
        context: RAGContext,
        provider: LLMProvider
    ) async throws -> RAGResponse
}

// MARK: - データ構造

struct SemanticSearchResult: Codable {
    let id: String
    let content: String
    let metadata: ContentMetadata
    let similarityScore: Double
    let chunks: [ContentChunk]
}

struct ContentMetadata: Codable {
    let id: String
    let type: ContentType
    let projectId: UUID
    let recordingId: UUID?
    let documentId: String?
    let timestamp: Date
    let language: SupportedLanguage
    let tags: [String]
    let sourceInfo: SourceInfo
}

enum ContentType: String, CaseIterable, Codable {
    case transcription = "transcription"
    case document = "document"
    case summary = "summary"
    case note = "note"
    case webpage = "webpage"
    
    var displayName: String {
        switch self {
        case .transcription: return "音声文字起こし"
        case .document: return "文書"
        case .summary: return "要約"
        case .note: return "ノート"
        case .webpage: return "Webページ"
        }
    }
}

struct SourceInfo: Codable {
    let title: String?
    let author: String?
    let url: String?
    let filePath: String?
    let pageNumber: Int?
    let duration: TimeInterval?
}

struct ContentChunk: Codable {
    let id: String
    let text: String
    let startIndex: Int
    let endIndex: Int
    let embedding: [Float]?
    let chunkMetadata: ChunkMetadata
}

struct ChunkMetadata: Codable {
    let chunkNumber: Int
    let totalChunks: Int
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let speaker: String?
}

struct SearchFilters: Codable {
    let projectIds: [UUID]?
    let contentTypes: [ContentType]?
    let dateRange: DateInterval?
    let languages: [SupportedLanguage]?
    let tags: [String]?
    let minSimilarityScore: Double?
}

struct SearchOptions: Codable {
    let topK: Int
    let threshold: Double
    let includeChunks: Bool
    let includeEmbeddings: Bool
    let maxContextLength: Int
    let enableReranking: Bool
}

struct SemanticSearchResponse: Codable {
    let query: String
    let results: [SemanticSearchResult]
    let totalResults: Int
    let searchTime: TimeInterval
    let usedFilters: SearchFilters?
    let suggestions: [String]
}

// MARK: - 文書関連

struct Document: Codable {
    let id: String
    let title: String
    let content: String
    let type: DocumentType
    let metadata: DocumentMetadata
}

enum DocumentType: String, CaseIterable, Codable {
    case pdf = "pdf"
    case word = "word"
    case text = "text"
    case markdown = "markdown"
    case webpage = "webpage"
    case note = "note"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .word: return "Word文書"
        case .text: return "テキスト"
        case .markdown: return "Markdown"
        case .webpage: return "Webページ"
        case .note: return "ノート"
        }
    }
}

struct DocumentMetadata: Codable {
    let projectId: UUID
    let fileName: String?
    let fileSize: Int64?
    let mimeType: String?
    let pageCount: Int?
    let wordCount: Int?
    let language: SupportedLanguage
    let createdAt: Date
    let lastModified: Date?
    let author: String?
    let tags: [String]
    let extractionMethod: ExtractionMethod
}

enum ExtractionMethod: String, CaseIterable, Codable {
    case manual = "manual"
    case ocr = "ocr"
    case api = "api"
    case `import` = "import"
}

struct IndexedDocument: Codable {
    let id: String
    let document: Document
    let chunks: [ContentChunk]
    let indexedAt: Date
    let vectorCount: Int
    let indexStatus: IndexStatus
}

enum IndexStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending: return "待機中"
        case .processing: return "処理中"
        case .completed: return "完了"
        case .failed: return "失敗"
        }
    }
}

// MARK: - RAGコンテキスト

struct RAGContext: Codable {
    let query: String
    let relevantChunks: [ContentChunk]
    let totalTokens: Int
    let sources: [SourceReference]
    let confidence: Double
    let retrievalMethod: RetrievalMethod
}

struct SourceReference: Codable {
    let id: String
    let title: String
    let type: ContentType
    let relevanceScore: Double
    let chunkIds: [String]
    let projectId: UUID
}

enum RetrievalMethod: String, CaseIterable, Codable {
    case semantic = "semantic"
    case keyword = "keyword"
    case hybrid = "hybrid"
    case dense = "dense"
    case sparse = "sparse"
}

// MARK: - 知識ベース

struct KnowledgeBase: Codable {
    let id: String
    let projectId: UUID
    let name: String
    let description: String?
    let totalDocuments: Int
    let totalChunks: Int
    let totalTokens: Int
    let createdAt: Date
    let lastUpdated: Date
    let version: String
    let metadata: KnowledgeBaseMetadata
}

struct KnowledgeBaseMetadata: Codable {
    let contentTypes: [ContentType]
    let languages: [SupportedLanguage]
    let dateRange: DateInterval?
    let tags: [String]
    let statistics: KnowledgeBaseStatistics
}

struct KnowledgeBaseStatistics: Codable {
    let averageChunkSize: Int
    let totalVectors: Int
    let indexSize: Int64
    let averageSimilarity: Double?
    let lastOptimized: Date?
}

struct KnowledgeBaseSummary: Codable {
    let knowledgeBase: KnowledgeBase
    let recentContent: [ContentMetadata]
    let topTags: [TagFrequency]
    let contentDistribution: [ContentTypeCount]
    let recommendations: [KnowledgeBaseRecommendation]
}

struct TagFrequency: Codable {
    let tag: String
    let count: Int
    let percentage: Double
}

struct ContentTypeCount: Codable {
    let type: ContentType
    let count: Int
    let percentage: Double
}

struct KnowledgeBaseRecommendation: Codable {
    let type: RecommendationType
    let title: String
    let description: String
    let priority: RecommendationPriority
    let actionable: Bool
}

enum RecommendationType: String, CaseIterable, Codable {
    case optimization = "optimization"
    case expansion = "expansion"
    case cleanup = "cleanup"
    case reindexing = "reindexing"
}

enum RecommendationPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - RAG応答

struct RAGResponse: Codable {
    let question: String
    let answer: String
    let confidence: Double
    let sources: [SourceReference]
    let context: RAGContext
    let responseTime: TimeInterval
    let model: String
    let tokenUsage: RAGTokenUsage
    let metadata: RAGResponseMetadata
}

struct RAGTokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let estimatedCost: Double?
}

struct RAGResponseMetadata: Codable {
    let retrievalMethod: RetrievalMethod
    let rerankingUsed: Bool
    let contextTruncated: Bool
    let additionalSources: Int
    let queryExpansions: [String]?
}

// MARK: - コンテンツアイテム

struct ContentItem: Codable {
    let id: String
    let content: String
    let metadata: ContentMetadata
    let chunks: [ContentChunk]?
    let lastUpdated: Date
}