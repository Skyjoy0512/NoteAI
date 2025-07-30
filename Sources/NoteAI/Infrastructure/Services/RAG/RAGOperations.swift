import Foundation

// MARK: - RAG操作の具体実装

// MARK: - セマンティック検索操作

struct SemanticSearchOperation: RAGOperationProtocol {
    typealias Input = SemanticSearchInput
    typealias Output = [SemanticSearchResult]
    
    let operationName = "semantic_search"
    
    private let embeddingService: EmbeddingServiceProtocol
    private let vectorStore: VectorStoreProtocol
    private let cache = RAGCache.shared
    private let logger = RAGLogger.shared
    
    init(embeddingService: EmbeddingServiceProtocol, vectorStore: VectorStoreProtocol) {
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
    }
    
    func execute(input: Input) async throws -> RAGResult<[SemanticSearchResult]> {
        let startTime = Date()
        
        do {
            logger.log(level: .info, message: "Starting semantic search", context: [
                "query": input.query,
                "projectId": input.projectId?.uuidString ?? "nil"
            ])
            
            // エンベディング生成
            let queryEmbedding = try await embeddingService.generateEmbedding(text: input.query)
            
            // ベクトル検索
            let searchResults = try await vectorStore.search(
                embedding: queryEmbedding,
                topK: input.options.topK,
                threshold: input.options.threshold,
                filters: input.projectId.map { ["project_id": $0.uuidString] }
            )
            
            // 結果変換
            let results = try await convertToSemanticResults(searchResults)
            
            let processingTime = Date().timeIntervalSince(startTime)
            let metadata = RAGResultMetadata(
                modelUsed: "embedding-\(embeddingService.getCurrentModel()?.rawValue ?? "unknown")",
                tokenCount: estimateTokenCount(input.query),
                retrievalMethod: input.options.retrievalMethod,
                contextLength: results.map { $0.content.count }.reduce(0, +),
                qualityScore: calculateQualityScore(results),
                timestamp: startTime
            )
            
            return RAGResult(
                data: results,
                confidence: calculateAverageConfidence(results),
                processingTime: processingTime,
                sources: extractSourceReferences(results),
                metadata: metadata
            )
            
        } catch {
            logger.log(level: .error, message: "Semantic search failed", context: [
                "error": error.localizedDescription
            ])
            throw RAGError.searchError(error.localizedDescription)
        }
    }
    
    private func convertToSemanticResults(_ vectorResults: [VectorSearchResult]) async throws -> [SemanticSearchResult] {
        return vectorResults.compactMap { result in
            // TODO: VectorSearchResultからSemanticSearchResultへの変換
            // 実際の実装では、メタデータとチャンクの取得が必要
            return nil
        }
    }
    
    private func calculateAverageConfidence(_ results: [SemanticSearchResult]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        return results.map { $0.similarityScore }.reduce(0, +) / Double(results.count)
    }
    
    private func calculateQualityScore(_ results: [SemanticSearchResult]) -> Double {
        // 結果の品質を評価（結果数、信頼度、多様性など）
        guard !results.isEmpty else { return 0.0 }
        
        let avgConfidence = calculateAverageConfidence(results)
        let diversityScore = calculateDiversityScore(results)
        let completenessScore = min(Double(results.count) / 10.0, 1.0) // 10件を理想とする
        
        return (avgConfidence * 0.5) + (diversityScore * 0.3) + (completenessScore * 0.2)
    }
    
    private func calculateDiversityScore(_ results: [SemanticSearchResult]) -> Double {
        // 結果の多様性を評価（異なるソース、異なるトピックなど）
        let uniqueTypes = Set(results.map { $0.metadata.type })
        let uniqueSources = Set(results.map { $0.metadata.id })
        
        let typeScore = min(Double(uniqueTypes.count) / 3.0, 1.0) // 3種類以上を理想
        let sourceScore = min(Double(uniqueSources.count) / Double(results.count), 1.0)
        
        return (typeScore + sourceScore) / 2.0
    }
    
    private func extractSourceReferences(_ results: [SemanticSearchResult]) -> [SourceReference] {
        return results.map { result in
            SourceReference(
                id: result.id,
                title: result.metadata.sourceInfo.title ?? "Untitled",
                type: result.metadata.type,
                relevanceScore: result.similarityScore,
                chunkIds: result.chunks.map { $0.id },
                projectId: result.metadata.projectId
            )
        }
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // 簡単なトークン数推定
        return text.split(separator: " ").count
    }
}

struct SemanticSearchInput {
    let query: String
    let projectId: UUID?
    let options: UnifiedSearchOptions
    
    init(query: String, projectId: UUID? = nil, options: UnifiedSearchOptions = .defaultOptions) {
        self.query = query
        self.projectId = projectId
        self.options = options
    }
}

// MARK: - コンテンツインデックス操作

struct ContentIndexingOperation: RAGOperationProtocol {
    typealias Input = ContentIndexingInput
    typealias Output = String
    
    let operationName = "content_indexing"
    
    private let embeddingService: EmbeddingServiceProtocol
    private let vectorStore: VectorStoreProtocol
    private let chunkingService: TextChunkingService
    private let logger = RAGLogger.shared
    
    init(
        embeddingService: EmbeddingServiceProtocol,
        vectorStore: VectorStoreProtocol,
        chunkingService: TextChunkingService
    ) {
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
        self.chunkingService = chunkingService
    }
    
    func execute(input: Input) async throws -> RAGResult<String> {
        let startTime = Date()
        
        do {
            logger.log(level: .info, message: "Starting content indexing", context: [
                "contentLength": input.content.count,
                "contentType": input.metadata.type.rawValue
            ])
            
            // テキストをチャンクに分割
            let chunks = chunkingService.chunkText(
                input.content,
                maxSize: input.chunkSize,
                overlap: input.chunkOverlap
            )
            
            // 各チャンクのベクトル化
            let embeddings = try await embeddingService.generateEmbeddings(
                texts: chunks.map { $0.text }
            )
            
            // ContentChunkに変換
            let contentChunks = zip(chunks, embeddings).enumerated().map { index, pair in
                let (chunk, embedding) = pair
                return ContentChunk(
                    id: UUID().uuidString,
                    text: chunk.text,
                    startIndex: chunk.startIndex,
                    endIndex: chunk.endIndex,
                    embedding: embedding,
                    chunkMetadata: ChunkMetadata(
                        chunkNumber: chunk.chunkNumber,
                        totalChunks: chunks.count,
                        startTime: nil,
                        endTime: nil,
                        speaker: nil
                    )
                )
            }
            
            // ベクトルストアに保存
            let indexId = UUID().uuidString
            try await vectorStore.store(
                id: indexId,
                embeddings: embeddings,
                metadata: input.metadata,
                chunks: contentChunks
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            let metadata = RAGResultMetadata(
                modelUsed: "embedding-\(embeddingService.getCurrentModel()?.rawValue ?? "unknown")",
                tokenCount: estimateTokenCount(input.content),
                retrievalMethod: .dense,
                contextLength: input.content.count,
                qualityScore: calculateIndexingQuality(contentChunks),
                timestamp: startTime
            )
            
            logger.log(level: .info, message: "Content indexing completed", context: [
                "indexId": indexId,
                "chunksCount": contentChunks.count,
                "duration": processingTime.formattedDuration
            ])
            
            return RAGResult(
                data: indexId,
                confidence: 1.0, // インデックス処理は確定的
                processingTime: processingTime,
                sources: [],
                metadata: metadata
            )
            
        } catch {
            logger.log(level: .error, message: "Content indexing failed", context: [
                "error": error.localizedDescription
            ])
            throw RAGError.indexingError(error.localizedDescription)
        }
    }
    
    private func calculateIndexingQuality(_ chunks: [ContentChunk]) -> Double {
        // インデックス品質の評価
        guard !chunks.isEmpty else { return 0.0 }
        
        let avgChunkSize = chunks.map { $0.text.count }.reduce(0, +) / chunks.count
        let sizeScore = min(Double(avgChunkSize) / 1000.0, 1.0) // 1000文字を理想サイズとする
        
        let completenessScore = chunks.allSatisfy { $0.embedding != nil } ? 1.0 : 0.5
        
        return (sizeScore + completenessScore) / 2.0
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        return text.split(separator: " ").count
    }
}

struct ContentIndexingInput {
    let content: String
    let metadata: ContentMetadata
    let chunkSize: Int
    let chunkOverlap: Int
    
    init(
        content: String,
        metadata: ContentMetadata,
        chunkSize: Int = 1000,
        chunkOverlap: Int = 200
    ) {
        self.content = content
        self.metadata = metadata
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
    }
}

// MARK: - RAG質問応答操作

struct RAGQuestionAnsweringOperation: RAGOperationProtocol {
    typealias Input = RAGQuestionInput
    typealias Output = RAGResponse
    
    let operationName = "rag_question_answering"
    
    private let semanticSearchOperation: SemanticSearchOperation
    private let llmService: LLMServiceProtocol
    private let logger = RAGLogger.shared
    
    init(
        semanticSearchOperation: SemanticSearchOperation,
        llmService: LLMServiceProtocol
    ) {
        self.semanticSearchOperation = semanticSearchOperation
        self.llmService = llmService
    }
    
    func execute(input: Input) async throws -> RAGResult<RAGResponse> {
        let startTime = Date()
        
        do {
            logger.log(level: .info, message: "Starting RAG question answering", context: [
                "question": input.question,
                "provider": input.provider.rawValue
            ])
            
            // 関連コンテンツを検索
            let searchInput = SemanticSearchInput(
                query: input.question,
                projectId: input.projectId,
                options: UnifiedSearchOptions(
                    topK: 10,
                    threshold: 0.6,
                    includeMetadata: true,
                    enableReranking: true,
                    maxContextLength: input.maxTokens,
                    filters: nil,
                    retrievalMethod: .semantic
                )
            )
            
            let searchResult = try await semanticSearchOperation.execute(input: searchInput)
            
            // コンテキストを構築
            let context = buildRAGContext(
                question: input.question,
                searchResults: searchResult.data,
                maxTokens: input.maxTokens
            )
            
            // LLMで回答生成
            let prompt = buildRAGPrompt(question: input.question, context: context)
            let llmRequest = LLMRequest(
                model: LLMModel.gpt4oMini,
                messages: [
                    LLMMessage(role: "system", content: "あなたは与えられたコンテキストに基づいて正確に回答するAIアシスタントです。"),
                    LLMMessage(role: "user", content: prompt)
                ],
                maxTokens: 1000,
                temperature: 0.3,
                systemPrompt: nil
            )
            
            let llmResponse = try await llmService.sendMessage(request: llmRequest)
            
            // RAG応答を構築
            let ragResponse = RAGResponse(
                question: input.question,
                answer: llmResponse.content,
                confidence: calculateAnswerConfidence(context: context, answer: llmResponse.content),
                sources: searchResult.sources,
                context: context,
                responseTime: Date().timeIntervalSince(startTime),
                model: llmResponse.model.displayName,
                tokenUsage: RAGTokenUsage(
                    promptTokens: llmResponse.tokensUsed.inputTokens,
                    completionTokens: llmResponse.tokensUsed.outputTokens,
                    totalTokens: llmResponse.tokensUsed.totalTokens,
                    estimatedCost: llmResponse.cost
                ),
                metadata: RAGResponseMetadata(
                    retrievalMethod: .semantic,
                    rerankingUsed: searchInput.options.enableReranking,
                    contextTruncated: context.totalTokens >= input.maxTokens,
                    additionalSources: max(0, searchResult.sources.count - 5),
                    queryExpansions: nil
                )
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            let metadata = RAGResultMetadata(
                modelUsed: LLMModel.gpt4oMini.displayName,
                tokenCount: ragResponse.tokenUsage.totalTokens,
                retrievalMethod: .semantic,
                contextLength: context.totalTokens,
                qualityScore: ragResponse.confidence,
                timestamp: startTime
            )
            
            logger.log(level: .info, message: "RAG question answering completed", context: [
                "confidence": ragResponse.confidence,
                "sourcesCount": ragResponse.sources.count,
                "duration": processingTime.formattedDuration
            ])
            
            return RAGResult(
                data: ragResponse,
                confidence: ragResponse.confidence,
                processingTime: processingTime,
                sources: ragResponse.sources,
                metadata: metadata
            )
            
        } catch {
            logger.log(level: .error, message: "RAG question answering failed", context: [
                "error": error.localizedDescription
            ])
            throw RAGError.contextBuildingError(error.localizedDescription)
        }
    }
    
    private func buildRAGContext(
        question: String,
        searchResults: [SemanticSearchResult],
        maxTokens: Int
    ) -> RAGContext {
        
        var relevantChunks: [ContentChunk] = []
        var totalTokens = 0
        
        for result in searchResults {
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
        
        let sources = searchResults.map { result in
            SourceReference(
                id: result.id,
                title: result.metadata.sourceInfo.title ?? "Untitled",
                type: result.metadata.type,
                relevanceScore: result.similarityScore,
                chunkIds: result.chunks.map { $0.id },
                projectId: result.metadata.projectId
            )
        }
        
        let averageScore = searchResults.isEmpty ? 0.0 :
            searchResults.map { $0.similarityScore }.reduce(0, +) / Double(searchResults.count)
        
        return RAGContext(
            query: question,
            relevantChunks: relevantChunks,
            totalTokens: totalTokens,
            sources: sources,
            confidence: averageScore,
            retrievalMethod: .semantic
        )
    }
    
    private func buildRAGPrompt(question: String, context: RAGContext) -> String {
        let chunksText = context.relevantChunks.map { chunk in
            "【\(chunk.chunkMetadata.chunkNumber)/\(chunk.chunkMetadata.totalChunks)】\(chunk.text)"
        }.joined(separator: "\n\n")
        
        return """
        以下は関連するコンテキスト情報です：
        
        \(chunksText)
        
        上記のコンテキストを参考にして、以下の質問に答えてください：
        
        質問：\(question)
        
        注意事項：
        - コンテキストに基づいて正確に答えてください
        - コンテキストに情報がない場合は「提供された情報では分かりません」と答えてください
        - 推測や一般的な知識ではなく、提供されたコンテキストのみを使用してください
        """
    }
    
    private func calculateAnswerConfidence(context: RAGContext, answer: String) -> Double {
        // 回答の信頼度を計算
        let contextConfidence = context.confidence
        let contextCompletenessScore = context.totalTokens > 1000 ? 0.9 : Double(context.totalTokens) / 1000.0
        let answerLengthScore = min(Double(answer.count) / 500.0, 1.0) // 500文字を適切な長さとする
        
        return (contextConfidence * 0.5) + (contextCompletenessScore * 0.3) + (answerLengthScore * 0.2)
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        return text.split(separator: " ").count
    }
}

struct RAGQuestionInput {
    let question: String
    let projectId: UUID?
    let provider: LLMProvider
    let maxTokens: Int
    
    init(
        question: String,
        projectId: UUID? = nil,
        provider: LLMProvider = .openai,
        maxTokens: Int = 4000
    ) {
        self.question = question
        self.projectId = projectId
        self.provider = provider
        self.maxTokens = maxTokens
    }
}

// MARK: - 操作ファクトリー

class RAGOperationFactory {
    private let embeddingService: EmbeddingServiceProtocol
    private let vectorStore: VectorStoreProtocol
    private let chunkingService: TextChunkingService
    private let llmService: LLMServiceProtocol
    
    init(
        embeddingService: EmbeddingServiceProtocol,
        vectorStore: VectorStoreProtocol,
        chunkingService: TextChunkingService,
        llmService: LLMServiceProtocol
    ) {
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
        self.chunkingService = chunkingService
        self.llmService = llmService
    }
    
    func createSemanticSearchOperation() -> SemanticSearchOperation {
        return SemanticSearchOperation(
            embeddingService: embeddingService,
            vectorStore: vectorStore
        )
    }
    
    func createContentIndexingOperation() -> ContentIndexingOperation {
        return ContentIndexingOperation(
            embeddingService: embeddingService,
            vectorStore: vectorStore,
            chunkingService: chunkingService
        )
    }
    
    func createRAGQuestionAnsweringOperation() -> RAGQuestionAnsweringOperation {
        return RAGQuestionAnsweringOperation(
            semanticSearchOperation: createSemanticSearchOperation(),
            llmService: llmService
        )
    }
}