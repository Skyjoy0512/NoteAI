import Foundation

// Import required protocols to avoid duplication

// MARK: - モック用の軽量実装（動作確認用）

// MARK: - RAGLogger Mock
class MockRAGLogger {
    static let shared = MockRAGLogger()
    
    enum LogLevel {
        case debug, info, warning, error
    }
    
    func log(level: LogLevel, message: String, context: [String: Any] = [:]) {
        print("[\(level)] \(message)")
        if !context.isEmpty {
            print("Context: \(context)")
        }
    }
}

// MARK: - RAGPerformanceMonitor Mock
class MockRAGPerformanceMonitor {
    static let shared = MockRAGPerformanceMonitor()
    
    struct Measurement {
        let startTime: Date = Date()
        var duration: TimeInterval {
            return Date().timeIntervalSince(startTime)
        }
    }
    
    func startMeasurement() -> Measurement {
        return Measurement()
    }
    
    func recordMetric(
        operation: String,
        measurement: Measurement,
        success: Bool,
        metadata: [String: Any] = [:]
    ) {
        print("Operation: \(operation), Duration: \(measurement.duration)s, Success: \(success)")
    }
}

// MARK: - RAGCache Mock
class MockRAGCache {
    static let shared = MockRAGCache()
    private var storage: [String: Any] = [:]
    
    func set<T>(_ value: T, forKey key: String) {
        storage[key] = value
    }
    
    func get<T>(_ type: T.Type, forKey key: String) -> T? {
        return storage[key] as? T
    }
    
    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Repository Protocol Mocks
// Protocols are defined in their respective domain files:
// - ProjectRepositoryProtocol in Domain/Repositories/ProjectRepositoryProtocol.swift
// - RecordingRepositoryProtocol in Domain/Repositories/RecordingRepositoryProtocol.swift
// - RAGServiceProtocol in Core/Services/RAG/RAGServiceProtocol.swift

// MARK: - Mock Implementations
class MockProjectRepository: ProjectRepositoryProtocol {
    func save(_ project: Project) async throws {
        // Mock implementation
    }
    
    func findById(_ id: UUID) async throws -> Project? {
        return Project(
            id: id,
            name: "Sample Project",
            description: "A sample project for testing",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func findAll() async throws -> [Project] {
        return [
            Project(
                id: UUID(),
                name: "Project 1",
                description: "First project",
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    func delete(_ id: UUID) async throws {
        // Mock implementation
    }
    
    func findByIds(_ ids: [UUID]) async throws -> [Project] {
        return []
    }
    
    func search(query: String) async throws -> [Project] {
        return []
    }
}

class MockRecordingRepository: RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws {
        // Mock implementation
    }
    
    func findById(_ id: UUID) async throws -> Recording? {
        return Recording(
            id: id,
            title: "Sample Recording",
            audioFileURL: URL(fileURLWithPath: "/tmp/sample.m4a"),
            duration: 1800,
            projectId: UUID()
        )
    }
    
    func findByProjectId(_ projectId: UUID) async throws -> [Recording] {
        return [
            Recording(
                id: UUID(),
                title: "Sample Recording",
                audioFileURL: URL(fileURLWithPath: "/tmp/sample.m4a"),
                duration: 1800,
                projectId: projectId
            )
        ]
    }
    
    func findAll() async throws -> [Recording] {
        return []
    }
    
    func delete(_ id: UUID) async throws {
        // Mock implementation
    }
    
    func search(query: String) async throws -> [Recording] {
        return []
    }
    
    func findRecent(limit: Int) async throws -> [Recording] {
        return []
    }
}

class MockRAGService: RAGServiceProtocol {
    func generateSummary(for content: String) async throws -> String {
        return "Generated summary for: \(content.prefix(50))..."
    }
    
    func searchSimilarContent(
        query: String,
        projectId: UUID?,
        topK: Int,
        threshold: Double
    ) async throws -> [SemanticSearchResult] {
        return []
    }
    
    func indexContent(_ content: String, metadata: ContentMetadata) async throws -> String {
        return UUID().uuidString
    }
    
    func removeIndex(indexId: String) async throws {
        // Mock implementation
    }
    
    func semanticSearch(
        query: String,
        filters: SearchFilters?,
        options: SearchOptions
    ) async throws -> SemanticSearchResponse {
        return SemanticSearchResponse(
            query: query,
            results: [],
            totalResults: 0,
            searchTime: 0,
            usedFilters: filters,
            suggestions: []
        )
    }
    
    func generateEmbedding(text: String) async throws -> [Float] {
        return Array(repeating: 0.5, count: 1024)
    }
    
    func indexDocument(
        document: Document,
        metadata: DocumentMetadata
    ) async throws -> IndexedDocument {
        return IndexedDocument(
            id: UUID().uuidString,
            document: document,
            chunks: [],
            indexedAt: Date(),
            vectorCount: 0,
            indexStatus: .completed
        )
    }
    
    func getRelevantContext(
        for query: String,
        projectId: UUID?,
        maxTokens: Int
    ) async throws -> RAGContext {
        return RAGContext(
            query: query,
            relevantChunks: [],
            totalTokens: 0,
            sources: [],
            confidence: 0.5,
            retrievalMethod: .semantic
        )
    }
    
    func buildKnowledgeBase(
        projectId: UUID,
        includeTranscriptions: Bool,
        includeDocuments: Bool
    ) async throws -> KnowledgeBase {
        return KnowledgeBase(
            id: UUID().uuidString,
            projectId: projectId,
            name: "Mock Knowledge Base",
            description: nil,
            totalDocuments: 0,
            totalChunks: 0,
            totalTokens: 0,
            createdAt: Date(),
            lastUpdated: Date(),
            version: "1.0.0",
            metadata: KnowledgeBaseMetadata(
                contentTypes: [],
                languages: [],
                dateRange: nil,
                tags: [],
                statistics: KnowledgeBaseStatistics(
                    averageChunkSize: 0,
                    totalVectors: 0,
                    indexSize: 0,
                    averageSimilarity: nil,
                    lastOptimized: nil
                )
            )
        )
    }
    
    func updateKnowledgeBase(
        knowledgeBaseId: String,
        newContent: [ContentItem]
    ) async throws {
        // Mock implementation
    }
    
    func getKnowledgeBaseSummary(
        projectId: UUID
    ) async throws -> KnowledgeBaseSummary {
        let mockKB = try await buildKnowledgeBase(projectId: projectId, includeTranscriptions: true, includeDocuments: true)
        return KnowledgeBaseSummary(
            knowledgeBase: mockKB,
            recentContent: [],
            topTags: [],
            contentDistribution: [],
            recommendations: []
        )
    }
    
    func answerQuestion(
        question: String,
        context: RAGContext,
        provider: LLMProvider
    ) async throws -> RAGResponse {
        return RAGResponse(
            question: question,
            answer: "Mock answer",
            confidence: 0.5,
            sources: [],
            context: context,
            responseTime: 0.1,
            model: "mock-model",
            tokenUsage: RAGTokenUsage(
                promptTokens: 100,
                completionTokens: 50,
                totalTokens: 150,
                estimatedCost: 0.01
            ),
            metadata: RAGResponseMetadata(
                retrievalMethod: .semantic,
                rerankingUsed: false,
                contextTruncated: false,
                additionalSources: 0,
                queryExpansions: nil
            )
        )
    }
}

// ComprehensiveAnalysisResult is defined in Core/Analytics/AdvancedAnalyticsService.swift