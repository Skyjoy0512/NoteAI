import Foundation
import GRDB

// MARK: - RAGサービス実装

@MainActor
class RAGService: RAGServiceProtocol {
    
    // MARK: - 依存関係
    private let llmService: LLMServiceProtocol
    private let database: DatabaseWriter
    private let embeddingService: EmbeddingServiceProtocol
    private let vectorStore: VectorStoreProtocol
    private let chunkingService: TextChunkingService
    
    // MARK: - 設定
    private let defaultChunkSize = 1000
    private let defaultChunkOverlap = 200
    private let defaultTopK = 10
    private let defaultThreshold = 0.7
    
    init(
        llmService: LLMServiceProtocol,
        database: DatabaseWriter,
        embeddingService: EmbeddingServiceProtocol,
        vectorStore: VectorStoreProtocol,
        chunkingService: TextChunkingService
    ) {
        self.llmService = llmService
        self.database = database
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
        self.chunkingService = chunkingService
    }
    
    // MARK: - ベクトル検索実装
    
    func searchSimilarContent(
        query: String,
        projectId: UUID?,
        topK: Int = 10,
        threshold: Double = 0.7
    ) async throws -> [SemanticSearchResult] {
        
        // クエリのベクトル化
        let queryEmbedding = try await generateEmbedding(text: query)
        
        // ベクトル検索実行
        let searchResults = try await vectorStore.search(
            embedding: queryEmbedding,
            topK: topK,
            threshold: threshold,
            filters: projectId.map { ["project_id": $0.uuidString] }
        )
        
        // 結果をSemanticSearchResultに変換
        var results: [SemanticSearchResult] = []
        
        for searchResult in searchResults {
            let metadata = try await getContentMetadata(indexId: searchResult.id)
            let chunks = try await getContentChunks(indexId: searchResult.id)
            
            let result = SemanticSearchResult(
                id: searchResult.id,
                content: searchResult.content,
                metadata: metadata,
                similarityScore: searchResult.score,
                chunks: chunks
            )
            results.append(result)
        }
        
        return results
    }
    
    func indexContent(
        _ content: String,
        metadata: ContentMetadata
    ) async throws -> String {
        
        // テキストをチャンクに分割
        let chunks = chunkingService.chunkText(
            content,
            maxSize: defaultChunkSize,
            overlap: defaultChunkOverlap
        )
        
        // 各チャンクのベクトル化
        var contentChunks: [ContentChunk] = []
        
        for (index, chunk) in chunks.enumerated() {
            let embedding = try await generateEmbedding(text: chunk.text)
            
            let contentChunk = ContentChunk(
                id: UUID().uuidString,
                text: chunk.text,
                startIndex: chunk.startIndex,
                endIndex: chunk.endIndex,
                embedding: embedding,
                chunkMetadata: ChunkMetadata(
                    chunkNumber: index + 1,
                    totalChunks: chunks.count,
                    startTime: nil,
                    endTime: nil,
                    speaker: nil
                )
            )
            contentChunks.append(contentChunk)
        }
        
        // ベクトルストアに保存
        let indexId = UUID().uuidString
        try await vectorStore.store(
            id: indexId,
            embeddings: contentChunks.compactMap { $0.embedding },
            metadata: metadata,
            chunks: contentChunks
        )
        
        // データベースにメタデータを保存
        try await saveContentMetadata(indexId: indexId, metadata: metadata, chunks: contentChunks)
        
        return indexId
    }
    
    func removeIndex(indexId: String) async throws {
        try await vectorStore.remove(id: indexId)
        try await removeContentMetadata(indexId: indexId)
    }
    
    // MARK: - セマンティック検索実装
    
    func semanticSearch(
        query: String,
        filters: SearchFilters?,
        options: SearchOptions
    ) async throws -> SemanticSearchResponse {
        
        let startTime = Date()
        
        // クエリのベクトル化
        let queryEmbedding = try await generateEmbedding(text: query)
        
        // フィルターをベクトルストア用に変換
        let vectorFilters = convertFilters(filters)
        
        // ベクトル検索実行
        let searchResults = try await vectorStore.search(
            embedding: queryEmbedding,
            topK: options.topK,
            threshold: options.threshold,
            filters: vectorFilters
        )
        
        // 結果をSemanticSearchResultに変換
        var results: [SemanticSearchResult] = []
        
        for searchResult in searchResults {
            let metadata = try await getContentMetadata(indexId: searchResult.id)
            let chunks = options.includeChunks ? 
                try await getContentChunks(indexId: searchResult.id) : []
            
            let result = SemanticSearchResult(
                id: searchResult.id,
                content: searchResult.content,
                metadata: metadata,
                similarityScore: searchResult.score,
                chunks: chunks
            )
            results.append(result)
        }
        
        // 再ランキング（オプション）
        if options.enableReranking {
            results = try await rerankResults(query: query, results: results)
        }
        
        let searchTime = Date().timeIntervalSince(startTime)
        
        // クエリ提案生成
        let suggestions = try await generateQuerySuggestions(
            originalQuery: query,
            results: results
        )
        
        return SemanticSearchResponse(
            query: query,
            results: results,
            totalResults: results.count,
            searchTime: searchTime,
            usedFilters: filters,
            suggestions: suggestions
        )
    }
    
    func generateEmbedding(text: String) async throws -> [Float] {
        return try await embeddingService.generateEmbedding(text: text)
    }
    
    // MARK: - 文書統合実装
    
    func indexDocument(
        document: Document,
        metadata: DocumentMetadata
    ) async throws -> IndexedDocument {
        
        let indexingStartTime = Date()
        
        // 文書をチャンクに分割
        let chunks = chunkingService.chunkText(
            document.content,
            maxSize: defaultChunkSize,
            overlap: defaultChunkOverlap
        )
        
        var contentChunks: [ContentChunk] = []
        
        // 各チャンクのベクトル化
        for (index, chunk) in chunks.enumerated() {
            let embedding = try await generateEmbedding(text: chunk.text)
            
            let contentChunk = ContentChunk(
                id: UUID().uuidString,
                text: chunk.text,
                startIndex: chunk.startIndex,
                endIndex: chunk.endIndex,
                embedding: embedding,
                chunkMetadata: ChunkMetadata(
                    chunkNumber: index + 1,
                    totalChunks: chunks.count,
                    startTime: nil,
                    endTime: nil,
                    speaker: nil
                )
            )
            contentChunks.append(contentChunk)
        }
        
        // ContentMetadataに変換
        let contentMetadata = ContentMetadata(
            id: document.id,
            type: .document,
            projectId: metadata.projectId,
            recordingId: nil,
            documentId: document.id,
            timestamp: Date(),
            language: metadata.language,
            tags: metadata.tags,
            sourceInfo: SourceInfo(
                title: document.title,
                author: metadata.author,
                url: nil,
                filePath: metadata.fileName,
                pageNumber: nil,
                duration: nil
            )
        )
        
        // ベクトルストアに保存
        try await vectorStore.store(
            id: document.id,
            embeddings: contentChunks.compactMap { $0.embedding },
            metadata: contentMetadata,
            chunks: contentChunks
        )
        
        // データベースに保存
        try await saveDocumentMetadata(document: document, metadata: metadata, chunks: contentChunks)
        
        return IndexedDocument(
            id: document.id,
            document: document,
            chunks: contentChunks,
            indexedAt: indexingStartTime,
            vectorCount: contentChunks.count,
            indexStatus: .completed
        )
    }
    
    func getRelevantContext(
        for query: String,
        projectId: UUID?,
        maxTokens: Int = 4000
    ) async throws -> RAGContext {
        
        // セマンティック検索実行
        let searchOptions = SearchOptions(
            topK: 20,
            threshold: 0.6,
            includeChunks: true,
            includeEmbeddings: false,
            maxContextLength: maxTokens,
            enableReranking: true
        )
        
        let searchResponse = try await semanticSearch(
            query: query,
            filters: SearchFilters(
                projectIds: projectId.map { [$0] },
                contentTypes: nil,
                dateRange: nil,
                languages: nil,
                tags: nil,
                minSimilarityScore: 0.6
            ),
            options: searchOptions
        )
        
        // トークン数を制限してチャンクを選択
        var relevantChunks: [ContentChunk] = []
        var totalTokens = 0
        
        for result in searchResponse.results {
            for chunk in result.chunks {
                let chunkTokens = estimateTokenCount(chunk.text)
                if totalTokens + chunkTokens <= maxTokens {
                    relevantChunks.append(chunk)
                    totalTokens += chunkTokens
                } else {
                    break
                }
            }
            if totalTokens >= maxTokens { break }
        }
        
        // ソース参照を作成
        let sources = searchResponse.results.map { result in
            SourceReference(
                id: result.id,
                title: result.metadata.sourceInfo.title ?? "Untitled",
                type: result.metadata.type,
                relevanceScore: result.similarityScore,
                chunkIds: result.chunks.map { $0.id },
                projectId: result.metadata.projectId
            )
        }
        
        // 信頼度計算
        let averageScore = searchResponse.results.isEmpty ? 0.0 :
            searchResponse.results.map { $0.similarityScore }.reduce(0, +) / Double(searchResponse.results.count)
        
        return RAGContext(
            query: query,
            relevantChunks: relevantChunks,
            totalTokens: totalTokens,
            sources: sources,
            confidence: averageScore,
            retrievalMethod: .semantic
        )
    }
    
    // MARK: - 知識ベース管理実装
    
    func buildKnowledgeBase(
        projectId: UUID,
        includeTranscriptions: Bool,
        includeDocuments: Bool
    ) async throws -> KnowledgeBase {
        
        let knowledgeBaseId = UUID().uuidString
        let startTime = Date()
        
        var contentItems: [ContentItem] = []
        var totalTokens = 0
        var contentTypes: Set<ContentType> = []
        var languages: Set<SupportedLanguage> = []
        var tags: Set<String> = []
        
        // 音声文字起こしを含める
        if includeTranscriptions {
            let transcriptions = try await getProjectTranscriptions(projectId: projectId)
            for transcription in transcriptions {
                let contentMetadata = ContentMetadata(
                    id: transcription.id.uuidString,
                    type: .transcription,
                    projectId: projectId,
                    recordingId: transcription.id,
                    documentId: nil,
                    timestamp: transcription.createdAt,
                    language: SupportedLanguage(rawValue: transcription.language) ?? .japanese,
                    tags: [], // TODO: タグシステム実装後に追加
                    sourceInfo: SourceInfo(
                        title: transcription.title,
                        author: nil,
                        url: nil,
                        filePath: transcription.audioFileURL,
                        pageNumber: nil,
                        duration: transcription.duration
                    )
                )
                
                let indexId = try await indexContent(transcription.transcription ?? "", metadata: contentMetadata)
                let chunks = try await getContentChunks(indexId: indexId)
                
                let contentItem = ContentItem(
                    id: indexId,
                    content: transcription.transcription ?? "",
                    metadata: contentMetadata,
                    chunks: chunks,
                    lastUpdated: transcription.updatedAt
                )
                
                contentItems.append(contentItem)
                totalTokens += estimateTokenCount(transcription.transcription ?? "")
                contentTypes.insert(.transcription)
                languages.insert(contentMetadata.language)
            }
        }
        
        // 文書を含める
        if includeDocuments {
            let documents = try await getProjectDocuments(projectId: projectId)
            for document in documents {
                let indexedDoc = try await indexDocument(document: document.document, metadata: document.metadata)
                
                let contentItem = ContentItem(
                    id: indexedDoc.id,
                    content: document.document.content,
                    metadata: ContentMetadata(
                        id: document.document.id,
                        type: .document,
                        projectId: projectId,
                        recordingId: nil,
                        documentId: document.document.id,
                        timestamp: document.metadata.createdAt,
                        language: document.metadata.language,
                        tags: document.metadata.tags,
                        sourceInfo: SourceInfo(
                            title: document.document.title,
                            author: document.metadata.author,
                            url: nil,
                            filePath: document.metadata.fileName,
                            pageNumber: nil,
                            duration: nil
                        )
                    ),
                    chunks: indexedDoc.chunks,
                    lastUpdated: document.metadata.lastModified ?? document.metadata.createdAt
                )
                
                contentItems.append(contentItem)
                totalTokens += estimateTokenCount(document.document.content)
                contentTypes.insert(.document)
                languages.insert(document.metadata.language)
                tags.formUnion(document.metadata.tags)
            }
        }
        
        // 統計情報計算
        let statistics = KnowledgeBaseStatistics(
            averageChunkSize: contentItems.isEmpty ? 0 : 
                contentItems.flatMap { $0.chunks ?? [] }.map { $0.text.count }.reduce(0, +) / 
                contentItems.flatMap { $0.chunks ?? [] }.count,
            totalVectors: contentItems.flatMap { $0.chunks ?? [] }.count,
            indexSize: Int64(totalTokens * 4), // 概算
            averageSimilarity: nil,
            lastOptimized: startTime
        )
        
        let metadata = KnowledgeBaseMetadata(
            contentTypes: Array(contentTypes),
            languages: Array(languages),
            dateRange: nil, // TODO: 実装
            tags: Array(tags),
            statistics: statistics
        )
        
        let knowledgeBase = KnowledgeBase(
            id: knowledgeBaseId,
            projectId: projectId,
            name: "Project Knowledge Base",
            description: "Auto-generated knowledge base for project",
            totalDocuments: contentItems.count,
            totalChunks: contentItems.flatMap { $0.chunks ?? [] }.count,
            totalTokens: totalTokens,
            createdAt: startTime,
            lastUpdated: startTime,
            version: "1.0.0",
            metadata: metadata
        )
        
        // データベースに保存
        try await saveKnowledgeBase(knowledgeBase)
        
        return knowledgeBase
    }
    
    func updateKnowledgeBase(
        knowledgeBaseId: String,
        newContent: [ContentItem]
    ) async throws {
        
        for contentItem in newContent {
            let indexId = try await indexContent(contentItem.content, metadata: contentItem.metadata)
            try await updateContentItemIndex(contentItem.id, newIndexId: indexId)
        }
        
        try await updateKnowledgeBaseTimestamp(knowledgeBaseId)
    }
    
    func getKnowledgeBaseSummary(
        projectId: UUID
    ) async throws -> KnowledgeBaseSummary {
        
        let knowledgeBase = try await getKnowledgeBase(projectId: projectId)
        let recentContent = try await getRecentContent(projectId: projectId, limit: 10)
        let topTags = try await getTopTags(projectId: projectId, limit: 10)
        let contentDistribution = try await getContentDistribution(projectId: projectId)
        let recommendations = try await generateKnowledgeBaseRecommendations(projectId: projectId)
        
        return KnowledgeBaseSummary(
            knowledgeBase: knowledgeBase,
            recentContent: recentContent,
            topTags: topTags,
            contentDistribution: contentDistribution,
            recommendations: recommendations
        )
    }
    
    // MARK: - RAG質問応答実装
    
    func answerQuestion(
        question: String,
        context: RAGContext,
        provider: LLMProvider
    ) async throws -> RAGResponse {
        
        let startTime = Date()
        
        // コンテキストを構築
        let contextText = buildContextText(from: context)
        
        // プロンプト作成
        let prompt = buildRAGPrompt(question: question, context: contextText)
        
        // LLMに質問
        let llmRequest = LLMRequest(
            model: provider.defaultModel,
            messages: [
                LLMMessage(role: "system", content: "あなたは与えられたコンテキストに基づいて正確に回答するAIアシスタントです。"),
                LLMMessage(role: "user", content: prompt)
            ],
            maxTokens: 1000,
            temperature: 0.3,
            systemPrompt: nil
        )
        
        let response = try await llmService.chat(request: llmRequest, provider: provider)
        
        let responseTime = Date().timeIntervalSince(startTime)
        
        // 信頼度計算（文脈との関連性基準）
        let confidence = calculateAnswerConfidence(
            question: question,
            answer: response.content,
            context: context
        )
        
        return RAGResponse(
            question: question,
            answer: response.content,
            confidence: confidence,
            sources: context.sources,
            context: context,
            responseTime: responseTime,
            model: provider.defaultModel.displayName,
            tokenUsage: TokenUsage(
                promptTokens: estimateTokenCount(prompt),
                completionTokens: estimateTokenCount(response.content),
                totalTokens: estimateTokenCount(prompt) + estimateTokenCount(response.content),
                estimatedCost: response.cost
            ),
            metadata: RAGResponseMetadata(
                retrievalMethod: context.retrievalMethod,
                rerankingUsed: false,
                contextTruncated: context.totalTokens >= 4000,
                additionalSources: max(0, context.sources.count - 5),
                queryExpansions: nil
            )
        )
    }
    
    // MARK: - ヘルパーメソッド
    
    private func convertFilters(_ filters: SearchFilters?) -> [String: Any]? {
        guard let filters = filters else { return nil }
        
        var vectorFilters: [String: Any] = [:]
        
        if let projectIds = filters.projectIds {
            vectorFilters["project_ids"] = projectIds.map { $0.uuidString }
        }
        
        if let contentTypes = filters.contentTypes {
            vectorFilters["content_types"] = contentTypes.map { $0.rawValue }
        }
        
        if let languages = filters.languages {
            vectorFilters["languages"] = languages.map { $0.rawValue }
        }
        
        if let tags = filters.tags {
            vectorFilters["tags"] = tags
        }
        
        return vectorFilters.isEmpty ? nil : vectorFilters
    }
    
    private func rerankResults(
        query: String,
        results: [SemanticSearchResult]
    ) async throws -> [SemanticSearchResult] {
        // 簡単な再ランキング実装
        return results.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    private func generateQuerySuggestions(
        originalQuery: String,
        results: [SemanticSearchResult]
    ) async throws -> [String] {
        // クエリ提案の簡単な実装
        let commonTerms = extractCommonTerms(from: results)
        return Array(commonTerms.prefix(3))
    }
    
    private func extractCommonTerms(from results: [SemanticSearchResult]) -> [String] {
        var termFrequency: [String: Int] = [:]
        
        for result in results {
            let words = result.content.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                if cleanWord.count > 2 {
                    termFrequency[cleanWord, default: 0] += 1
                }
            }
        }
        
        return termFrequency.sorted { $0.value > $1.value }.map { $0.key }
    }
    
    private func buildContextText(from context: RAGContext) -> String {
        let chunksText = context.relevantChunks.map { chunk in
            "【\(chunk.chunkMetadata.chunkNumber)/\(chunk.chunkMetadata.totalChunks)】\(chunk.text)"
        }.joined(separator: "\n\n")
        
        return """
        以下は関連するコンテキスト情報です：
        
        \(chunksText)
        """
    }
    
    private func buildRAGPrompt(question: String, context: String) -> String {
        return """
        \(context)
        
        上記のコンテキストを参考にして、以下の質問に答えてください：
        
        質問：\(question)
        
        注意事項：
        - コンテキストに基づいて正確に答えてください
        - コンテキストに情報がない場合は「提供された情報では分かりません」と答えてください
        - 推測や一般的な知識ではなく、提供されたコンテキストのみを使用してください
        """
    }
    
    private func calculateAnswerConfidence(
        question: String,
        answer: String,
        context: RAGContext
    ) -> Double {
        // 簡単な信頼度計算
        return context.confidence * 0.8 + (context.totalTokens > 1000 ? 0.2 : 0.1)
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // 簡単なトークン数推定（英語：4文字=1トークン、日本語：1.5文字=1トークン）
        let japaneseCharacters = text.unicodeScalars.filter { CharacterSet.characterSet(for: .japanese).contains($0) }.count
        let otherCharacters = text.count - japaneseCharacters
        
        return Int(Double(japaneseCharacters) / 1.5) + (otherCharacters / 4)
    }
}

// MARK: - データベース操作拡張

extension RAGService {
    
    private func getContentMetadata(indexId: String) async throws -> ContentMetadata {
        // データベースからメタデータを取得
        return try await database.read { db in
            try ContentMetadata.fetchOne(db, sql: "SELECT * FROM content_metadata WHERE index_id = ?", arguments: [indexId])
        } ?? ContentMetadata(
            id: indexId,
            type: .transcription,
            projectId: UUID(),
            recordingId: nil,
            documentId: nil,
            timestamp: Date(),
            language: .japanese,
            tags: [],
            sourceInfo: SourceInfo(title: nil, author: nil, url: nil, filePath: nil, pageNumber: nil, duration: nil)
        )
    }
    
    private func getContentChunks(indexId: String) async throws -> [ContentChunk] {
        // データベースからチャンクを取得
        return try await database.read { db in
            try ContentChunk.fetchAll(db, sql: "SELECT * FROM content_chunks WHERE index_id = ?", arguments: [indexId])
        }
    }
    
    private func saveContentMetadata(
        indexId: String,
        metadata: ContentMetadata,
        chunks: [ContentChunk]
    ) async throws {
        // データベースに保存
        try await database.write { db in
            // メタデータ保存
            try db.execute(sql: """
                INSERT INTO content_metadata (
                    index_id, id, type, project_id, recording_id, document_id,
                    timestamp, language, tags, source_info
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    indexId, metadata.id, metadata.type.rawValue,
                    metadata.projectId.uuidString, metadata.recordingId?.uuidString,
                    metadata.documentId, metadata.timestamp, metadata.language.rawValue,
                    try JSONEncoder().encode(metadata.tags),
                    try JSONEncoder().encode(metadata.sourceInfo)
                ])
            
            // チャンク保存
            for chunk in chunks {
                try db.execute(sql: """
                    INSERT INTO content_chunks (
                        index_id, id, text, start_index, end_index,
                        embedding, chunk_metadata
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        indexId, chunk.id, chunk.text, chunk.startIndex, chunk.endIndex,
                        try JSONEncoder().encode(chunk.embedding),
                        try JSONEncoder().encode(chunk.chunkMetadata)
                    ])
            }
        }
    }
    
    private func removeContentMetadata(indexId: String) async throws {
        try await database.write { db in
            try db.execute(sql: "DELETE FROM content_metadata WHERE index_id = ?", arguments: [indexId])
            try db.execute(sql: "DELETE FROM content_chunks WHERE index_id = ?", arguments: [indexId])
        }
    }
    
    private func saveDocumentMetadata(
        document: Document,
        metadata: DocumentMetadata,
        chunks: [ContentChunk]
    ) async throws {
        try await database.write { db in
            try db.execute(sql: """
                INSERT INTO documents (
                    id, title, content, type, metadata
                ) VALUES (?, ?, ?, ?, ?)
                """, arguments: [
                    document.id, document.title, document.content,
                    document.type.rawValue, try JSONEncoder().encode(metadata)
                ])
        }
    }
    
    private func getProjectTranscriptions(projectId: UUID) async throws -> [Recording] {
        // RecordingRepositoryから取得
        return []
    }
    
    private func getProjectDocuments(projectId: UUID) async throws -> [(document: Document, metadata: DocumentMetadata)] {
        // DocumentRepositoryから取得
        return []
    }
    
    private func saveKnowledgeBase(_ knowledgeBase: KnowledgeBase) async throws {
        try await database.write { db in
            try db.execute(sql: """
                INSERT INTO knowledge_bases (
                    id, project_id, name, description, total_documents,
                    total_chunks, total_tokens, created_at, last_updated,
                    version, metadata
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    knowledgeBase.id, knowledgeBase.projectId.uuidString,
                    knowledgeBase.name, knowledgeBase.description,
                    knowledgeBase.totalDocuments, knowledgeBase.totalChunks,
                    knowledgeBase.totalTokens, knowledgeBase.createdAt,
                    knowledgeBase.lastUpdated, knowledgeBase.version,
                    try JSONEncoder().encode(knowledgeBase.metadata)
                ])
        }
    }
    
    private func getKnowledgeBase(projectId: UUID) async throws -> KnowledgeBase {
        // データベースから取得（プレースホルダー）
        return KnowledgeBase(
            id: UUID().uuidString,
            projectId: projectId,
            name: "Default Knowledge Base",
            description: "Default knowledge base",
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
    
    private func getRecentContent(projectId: UUID, limit: Int) async throws -> [ContentMetadata] {
        return []
    }
    
    private func getTopTags(projectId: UUID, limit: Int) async throws -> [TagFrequency] {
        return []
    }
    
    private func getContentDistribution(projectId: UUID) async throws -> [ContentTypeCount] {
        return []
    }
    
    private func generateKnowledgeBaseRecommendations(projectId: UUID) async throws -> [KnowledgeBaseRecommendation] {
        return []
    }
    
    private func updateContentItemIndex(contentItemId: String, newIndexId: String) async throws {
        // 実装
    }
    
    private func updateKnowledgeBaseTimestamp(_ knowledgeBaseId: String) async throws {
        try await database.write { db in
            try db.execute(sql: """
                UPDATE knowledge_bases SET last_updated = ? WHERE id = ?
                """, arguments: [Date(), knowledgeBaseId])
        }
    }
}