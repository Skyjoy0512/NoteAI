import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import GRDB
#endif

// MARK: - ベクトルストア実装

@MainActor
class VectorStore: VectorStoreProtocol {
    
    // MARK: - 依存関係
    #if !MINIMAL_BUILD && !NO_COREDATA
    private let database: DatabaseWriter?
    #else
    private var memoryVectors: [String: [CandidateVector]] = [:]
    #endif
    private let indexManager: VectorIndexManager
    private let similarityCalculator: SimilarityCalculator
    
    // MARK: - 設定
    private let defaultIndexName = "default_index"
    private let defaultMetric = VectorMetric.cosine
    private let defaultDimension = 1536
    
    init(database: Any? = nil) {
        #if !MINIMAL_BUILD && !NO_COREDATA
        self.database = database as? DatabaseWriter
        #endif
        self.indexManager = VectorIndexManager()
        self.similarityCalculator = SimilarityCalculator()
        
        Task {
            try await initializeDefaultIndex()
        }
    }
    
    // MARK: - ベクトル操作実装
    
    func store(
        id: String,
        embeddings: [[Float]],
        metadata: ContentMetadata,
        chunks: [ContentChunk]
    ) async throws {
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                // メインレコードを保存
                try db.execute(sql: """
                    INSERT OR REPLACE INTO vector_documents (
                        id, project_id, content_type, title, created_at, metadata
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [
                        id,
                        metadata.projectId.uuidString,
                        metadata.type.rawValue,
                        metadata.sourceInfo.title ?? "",
                        metadata.timestamp,
                        try JSONEncoder().encode(metadata)
                    ])
                
                // 既存のベクトルを削除
                try db.execute(sql: "DELETE FROM vectors WHERE document_id = ?", arguments: [id])
                
                // 新しいベクトルを保存
                for (index, embedding) in embeddings.enumerated() {
                    let chunkId = index < chunks.count ? chunks[index].id : UUID().uuidString
                    
                    try db.execute(sql: """
                        INSERT INTO vectors (
                            id, document_id, chunk_id, chunk_index, embedding, 
                            dimension, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """, arguments: [
                            UUID().uuidString,
                            id,
                            chunkId,
                            index,
                            try JSONEncoder().encode(embedding),
                            embedding.count,
                            Date()
                        ])
                }
                
                // チャンク情報を保存
                for chunk in chunks {
                    try db.execute(sql: """
                        INSERT OR REPLACE INTO vector_chunks (
                            id, document_id, text, start_index, end_index,
                            chunk_number, total_chunks, metadata
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """, arguments: [
                            chunk.id,
                            id,
                            chunk.text,
                            chunk.startIndex,
                            chunk.endIndex,
                            chunk.chunkMetadata.chunkNumber,
                            chunk.chunkMetadata.totalChunks,
                            try JSONEncoder().encode(chunk.chunkMetadata)
                        ])
                }
            }
        }
        #else
        // Minimal build - store in memory
        memoryVectors[id] = embeddings.enumerated().map { index, embedding in
            CandidateVector(
                id: index < chunks.count ? chunks[index].id : UUID().uuidString,
                documentId: id,
                chunkId: index < chunks.count ? chunks[index].id : UUID().uuidString,
                chunkIndex: index,
                embedding: embedding,
                content: index < chunks.count ? chunks[index].text : "",
                metadata: ["projectId": metadata.projectId.uuidString, "type": metadata.type.rawValue]
            )
        }
        #endif
        
        // インデックスを更新
        try await indexManager.updateIndex(
            name: defaultIndexName,
            documentId: id,
            embeddings: embeddings
        )
    }
    
    func search(
        embedding: [Float],
        topK: Int,
        threshold: Double,
        filters: [String: Any]?
    ) async throws -> [VectorSearchResult] {
        
        // データベースから候補ベクトルを取得
        let candidates = try await getCandidateVectors(filters: filters)
        
        // 類似度計算
        var results: [(VectorSearchResult, Double)] = []
        
        for candidate in candidates {
            let similarity = similarityCalculator.calculate(
                embedding1: embedding,
                embedding2: candidate.embedding,
                metric: defaultMetric
            )
            
            if similarity >= threshold {
                let result = VectorSearchResult(
                    id: candidate.documentId,
                    content: candidate.content,
                    score: similarity,
                    metadata: try JSONSerialization.data(withJSONObject: candidate.metadata ?? [:]),
                    chunkIndex: candidate.chunkIndex
                )
                results.append((result, similarity))
            }
        }
        
        // スコア順でソートして上位K件を返す
        return results
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { $0.0 }
    }
    
    func remove(id: String) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                try db.execute(sql: "DELETE FROM vector_documents WHERE id = ?", arguments: [id])
                try db.execute(sql: "DELETE FROM vectors WHERE document_id = ?", arguments: [id])
                try db.execute(sql: "DELETE FROM vector_chunks WHERE document_id = ?", arguments: [id])
            }
        }
        #else
        memoryVectors.removeValue(forKey: id)
        #endif
        
        try await indexManager.removeFromIndex(name: defaultIndexName, documentId: id)
    }
    
    func update(
        id: String,
        embeddings: [[Float]]?,
        metadata: ContentMetadata?
    ) async throws {
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                if let metadata = metadata {
                    try db.execute(sql: """
                        UPDATE vector_documents 
                        SET metadata = ?, title = ?, updated_at = ?
                        WHERE id = ?
                        """, arguments: [
                            try JSONEncoder().encode(metadata),
                            metadata.sourceInfo.title ?? "",
                            Date(),
                            id
                        ])
                }
                
                if let embeddings = embeddings {
                    try db.execute(sql: "DELETE FROM vectors WHERE document_id = ?", arguments: [id])
                    
                    for (index, embedding) in embeddings.enumerated() {
                        try db.execute(sql: """
                            INSERT INTO vectors (
                                id, document_id, chunk_id, chunk_index, embedding,
                                dimension, created_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?)
                            """, arguments: [
                                UUID().uuidString,
                                id,
                                "chunk_\\(index)",
                                index,
                                try JSONEncoder().encode(embedding),
                                embedding.count,
                                Date()
                            ])
                    }
                }
            }
        }
        #else
        // Minimal build - update memory storage
        if let existingVectors = memoryVectors[id] {
            var updatedVectors = existingVectors
            if let embeddings = embeddings {
                updatedVectors = embeddings.enumerated().map { index, embedding in
                    CandidateVector(
                        id: index < existingVectors.count ? existingVectors[index].id : UUID().uuidString,
                        documentId: id,
                        chunkId: index < existingVectors.count ? existingVectors[index].chunkId : UUID().uuidString,
                        chunkIndex: index,
                        embedding: embedding,
                        content: index < existingVectors.count ? existingVectors[index].content : "",
                        metadata: metadata != nil ? ["projectId": metadata!.projectId.uuidString, "type": metadata!.type.rawValue] : existingVectors[index].metadata
                    )
                }
            }
            memoryVectors[id] = updatedVectors
        }
        #endif
        
        if let embeddings = embeddings {
            try await indexManager.updateIndex(
                name: defaultIndexName,
                documentId: id,
                embeddings: embeddings
            )
        }
    }
    
    // MARK: - インデックス管理実装
    
    func createIndex(
        name: String,
        dimension: Int,
        metric: VectorMetric
    ) async throws {
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                try db.execute(sql: """
                    INSERT INTO vector_indices (
                        name, dimension, metric, created_at, configuration
                    ) VALUES (?, ?, ?, ?, ?)
                    """, arguments: [
                        name,
                        dimension,
                        metric.rawValue,
                        Date(),
                        try JSONEncoder().encode(IndexConfiguration(
                            efConstruction: 200,
                            mLinks: 16,
                            numLists: nil,
                            numProbes: nil,
                            algorithm: .hnsw
                        ))
                    ])
            }
        }
        #endif
        
        try await indexManager.createIndex(
            name: name,
            dimension: dimension,
            metric: metric
        )
    }
    
    func deleteIndex(name: String) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                try db.execute(sql: "DELETE FROM vector_indices WHERE name = ?", arguments: [name])
            }
        }
        #endif
        
        try await indexManager.deleteIndex(name: name)
    }
    
    func optimizeIndex(name: String) async throws {
        try await indexManager.optimizeIndex(name: name)
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                try db.execute(sql: """
                    UPDATE vector_indices 
                    SET last_optimized = ?
                    WHERE name = ?
                    """, arguments: [Date(), name])
            }
        }
        #endif
    }
    
    func getIndexInfo(name: String) async throws -> VectorIndexInfo {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            return try await database.read { db in
                guard let row = try Row.fetchOne(db, sql: """
                    SELECT * FROM vector_indices WHERE name = ?
                    """, arguments: [name]) else {
                    throw VectorStoreError.indexNotFound(name)
                }
                
                let vectorCount = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM vectors v
                    JOIN vector_documents d ON v.document_id = d.id
                    """) ?? 0
                
                let configuration = try JSONDecoder().decode(
                    IndexConfiguration.self,
                    from: row["configuration"]
                )
                
                return VectorIndexInfo(
                    name: row["name"],
                    dimension: row["dimension"],
                    metric: VectorMetric(rawValue: row["metric"]) ?? .cosine,
                    totalVectors: vectorCount,
                    indexSize: estimateIndexSize(vectorCount: vectorCount, dimension: row["dimension"]),
                    createdAt: row["created_at"],
                    lastOptimized: row["last_optimized"],
                    configuration: configuration
                )
            }
        }
        #endif
        
        // Fallback - return mock info
        return VectorIndexInfo(
            name: name,
            dimension: defaultDimension,
            metric: defaultMetric,
            totalVectors: memoryVectors.values.reduce(0) { $0 + $1.count },
            indexSize: Int64(memoryVectors.values.reduce(0) { $0 + $1.count } * defaultDimension * 4),
            createdAt: Date(),
            lastOptimized: nil,
            configuration: IndexConfiguration(
                efConstruction: 200,
                mLinks: 16,
                numLists: nil,
                numProbes: nil,
                algorithm: .hnsw
            )
        )
    }
    
    // MARK: - バッチ操作実装
    
    func batchStore(items: [VectorStoreItem]) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            try await database.write { db in
                for item in items {
                    // ドキュメント保存
                    try db.execute(sql: """
                        INSERT OR REPLACE INTO vector_documents (
                            id, project_id, content_type, title, created_at, metadata
                        ) VALUES (?, ?, ?, ?, ?, ?)
                        """, arguments: [
                            item.id,
                            item.metadata.projectId.uuidString,
                            item.metadata.type.rawValue,
                            item.metadata.sourceInfo.title ?? "",
                            item.metadata.timestamp,
                            try JSONEncoder().encode(item.metadata)
                        ])
                    
                    // ベクトル保存
                    try db.execute(sql: "DELETE FROM vectors WHERE document_id = ?", arguments: [item.id])
                    
                    for (index, embedding) in item.embeddings.enumerated() {
                        let chunkId = index < item.chunks.count ? item.chunks[index].id : UUID().uuidString
                        
                        try db.execute(sql: """
                            INSERT INTO vectors (
                                id, document_id, chunk_id, chunk_index, embedding,
                                dimension, created_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?)
                            """, arguments: [
                                UUID().uuidString,
                                item.id,
                                chunkId,
                                index,
                                try JSONEncoder().encode(embedding),
                                embedding.count,
                                Date()
                            ])
                    }
                    
                    // チャンク保存
                    for chunk in item.chunks {
                        try db.execute(sql: """
                            INSERT OR REPLACE INTO vector_chunks (
                                id, document_id, text, start_index, end_index,
                                chunk_number, total_chunks, metadata
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            """, arguments: [
                                chunk.id,
                                item.id,
                                chunk.text,
                                chunk.startIndex,
                                chunk.endIndex,
                                chunk.chunkMetadata.chunkNumber,
                                chunk.chunkMetadata.totalChunks,
                                try JSONEncoder().encode(chunk.chunkMetadata)
                            ])
                    }
                }
            }
        }
        #else
        // Minimal build - batch store in memory
        for item in items {
            memoryVectors[item.id] = item.embeddings.enumerated().map { index, embedding in
                CandidateVector(
                    id: index < item.chunks.count ? item.chunks[index].id : UUID().uuidString,
                    documentId: item.id,
                    chunkId: index < item.chunks.count ? item.chunks[index].id : UUID().uuidString,
                    chunkIndex: index,
                    embedding: embedding,
                    content: index < item.chunks.count ? item.chunks[index].text : "",
                    metadata: ["projectId": item.metadata.projectId.uuidString, "type": item.metadata.type.rawValue]
                )
            }
        }
        #endif
        
        // インデックス更新をバッチ処理
        let batchUpdates = items.map { item in
            (documentId: item.id, embeddings: item.embeddings)
        }
        
        try await indexManager.batchUpdateIndex(
            name: defaultIndexName,
            updates: batchUpdates
        )
    }
    
    func batchSearch(
        embeddings: [[Float]],
        topK: Int,
        threshold: Double,
        filters: [String: Any]?
    ) async throws -> [[VectorSearchResult]] {
        
        var allResults: [[VectorSearchResult]] = []
        
        for embedding in embeddings {
            let results = try await search(
                embedding: embedding,
                topK: topK,
                threshold: threshold,
                filters: filters
            )
            allResults.append(results)
        }
        
        return allResults
    }
    
    // MARK: - 統計・メトリクス実装
    
    func getStorageStats() async throws -> VectorStorageStats {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            return try await database.read { db in
                let totalVectors = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM vectors") ?? 0
                let totalIndices = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM vector_indices") ?? 0
                
                let avgDimension = try Int.fetchOne(db, sql: """
                    SELECT AVG(dimension) FROM vectors
                    """) ?? defaultDimension
                
                let indexDistribution = try Row.fetchAll(db, sql: """
                    SELECT 
                        vi.name,
                        COUNT(v.id) as vector_count
                    FROM vector_indices vi
                    LEFT JOIN vectors v ON 1=1
                    GROUP BY vi.name
                    """).reduce(into: [String: Int]()) { dict, row in
                    dict[row["name"]] = row["vector_count"]
                }
                
                let totalStorageSize = estimateTotalStorageSize(
                    vectorCount: totalVectors,
                    avgDimension: avgDimension
                )
                
                return VectorStorageStats(
                    totalVectors: totalVectors,
                    totalIndices: totalIndices,
                    totalStorageSize: totalStorageSize,
                    averageVectorDimension: avgDimension,
                    indexDistribution: indexDistribution,
                    memoryUsage: getMemoryUsage()
                )
            }
        }
        #endif
        
        // Fallback - return memory-based stats
        let totalVectors = memoryVectors.values.reduce(0) { $0 + $1.count }
        return VectorStorageStats(
            totalVectors: totalVectors,
            totalIndices: 1, // default index only
            totalStorageSize: Int64(totalVectors * defaultDimension * 4),
            averageVectorDimension: defaultDimension,
            indexDistribution: [defaultIndexName: totalVectors],
            memoryUsage: getMemoryUsage()
        )
    }
    
    func getSearchPerformance() async throws -> SearchPerformanceMetrics {
        // パフォーマンス統計の実装（プレースホルダー）
        return SearchPerformanceMetrics(
            averageSearchTime: 0.1,
            recentSearchTimes: [0.08, 0.12, 0.09, 0.11, 0.10],
            throughputPerSecond: 100.0,
            cacheHitRate: 0.75,
            indexEfficiency: 0.85,
            lastMeasuredAt: Date()
        )
    }
    
    // MARK: - 内部メソッド
    
    private func initializeDefaultIndex() async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            let indexExists = try await database.read { db in
                try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM vector_indices WHERE name = ?
                    """, arguments: [defaultIndexName]) ?? 0 > 0
            }
            
            if !indexExists {
                try await createIndex(
                    name: defaultIndexName,
                    dimension: defaultDimension,
                    metric: defaultMetric
                )
            }
        } else {
            // Fallback when database is not available
            try await createIndex(
                name: defaultIndexName,
                dimension: defaultDimension,
                metric: defaultMetric
            )
        }
        #else
        // Minimal build - always create default index
        try await createIndex(
            name: defaultIndexName,
            dimension: defaultDimension,
            metric: defaultMetric
        )
        #endif
    }
    
    private func getCandidateVectors(filters: [String: Any]?) async throws -> [CandidateVector] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        if let database = database {
            var sql = """
                SELECT 
                    v.id, v.document_id, v.chunk_id, v.chunk_index, v.embedding,
                    d.title, d.metadata,
                    c.text
                FROM vectors v
                JOIN vector_documents d ON v.document_id = d.id
                LEFT JOIN vector_chunks c ON v.chunk_id = c.id
                """
            
            var arguments: [Any] = []
            var whereConditions: [String] = []
            
            if let filters = filters {
                if let projectIds = filters["project_ids"] as? [String] {
                    let placeholders = projectIds.map { _ in "?" }.joined(separator: ",")
                    whereConditions.append("d.project_id IN (\\(placeholders))")
                    arguments.append(contentsOf: projectIds)
                }
                
                if let contentTypes = filters["content_types"] as? [String] {
                    let placeholders = contentTypes.map { _ in "?" }.joined(separator: ",")
                    whereConditions.append("d.content_type IN (\\(placeholders))")
                    arguments.append(contentsOf: contentTypes)
                }
            }
            
            if !whereConditions.isEmpty {
                sql += " WHERE " + whereConditions.joined(separator: " AND ")
            }
            
            return try await database.read { db in
                try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments)).map { row in
                    let embeddingData: Data = row["embedding"]
                    let embedding = try JSONDecoder().decode([Float].self, from: embeddingData)
                    
                    let metadataData: Data = row["metadata"]
                    let metadata = try JSONDecoder().decode([String: String].self, from: metadataData)
                    
                    return CandidateVector(
                        id: row["id"],
                        documentId: row["document_id"],
                        chunkId: row["chunk_id"],
                        chunkIndex: row["chunk_index"],
                        embedding: embedding,
                        content: row["text"] ?? row["title"] ?? "",
                        metadata: metadata
                    )
                }
            }
        }
        #endif
        
        // Minimal build or fallback - search in memory
        var candidates: [CandidateVector] = []
        
        for (documentId, vectors) in memoryVectors {
            for vector in vectors {
                // Apply filters if provided
                var passesFilter = true
                if let filters = filters {
                    if let projectIds = filters["project_ids"] as? [String] {
                        passesFilter = passesFilter && (vector.metadata?["projectId"] as? String).map { projectIds.contains($0) } ?? false
                    }
                    if let contentTypes = filters["content_types"] as? [String] {
                        passesFilter = passesFilter && (vector.metadata?["type"] as? String).map { contentTypes.contains($0) } ?? false
                    }
                }
                
                if passesFilter {
                    candidates.append(vector)
                }
            }
        }
        
        return candidates
    }
    
    private func estimateIndexSize(vectorCount: Int, dimension: Int) -> Int64 {
        // HNSW インデックスのサイズ推定
        let vectorSize = vectorCount * dimension * 4 // Float = 4 bytes
        let graphSize = vectorCount * 16 * 4 // 平均16接続 * 4 bytes per link
        return Int64(vectorSize + graphSize)
    }
    
    private func estimateTotalStorageSize(vectorCount: Int, avgDimension: Int) -> Int64 {
        let vectorSize = vectorCount * avgDimension * 4
        let metadataSize = vectorCount * 1024 // 平均1KB per metadata
        let indexOverhead = Int(Double(vectorSize) * 0.3) // 30%オーバーヘッド
        return Int64(vectorSize + metadataSize + indexOverhead)
    }
    
    private func getMemoryUsage() -> MemoryUsageStats {
        // メモリ使用量の取得（プレースホルダー）
        return MemoryUsageStats(
            totalMemory: 8 * 1024 * 1024 * 1024, // 8GB
            usedMemory: 2 * 1024 * 1024 * 1024, // 2GB
            indexMemory: 512 * 1024 * 1024, // 512MB
            cacheMemory: 256 * 1024 * 1024, // 256MB
            availableMemory: 6 * 1024 * 1024 * 1024 // 6GB
        )
    }
}

// MARK: - ベクトルインデックスマネージャー

class VectorIndexManager {
    
    private var indices: [String: VectorIndex] = [:]
    
    func createIndex(
        name: String,
        dimension: Int,
        metric: VectorMetric
    ) async throws {
        let index = VectorIndex(
            name: name,
            dimension: dimension,
            metric: metric
        )
        indices[name] = index
    }
    
    func deleteIndex(name: String) async throws {
        indices.removeValue(forKey: name)
    }
    
    func updateIndex(
        name: String,
        documentId: String,
        embeddings: [[Float]]
    ) async throws {
        guard let index = indices[name] else {
            throw VectorStoreError.indexNotFound(name)
        }
        
        try await index.update(documentId: documentId, embeddings: embeddings)
    }
    
    func removeFromIndex(name: String, documentId: String) async throws {
        guard let index = indices[name] else {
            throw VectorStoreError.indexNotFound(name)
        }
        
        try await index.remove(documentId: documentId)
    }
    
    func optimizeIndex(name: String) async throws {
        guard let index = indices[name] else {
            throw VectorStoreError.indexNotFound(name)
        }
        
        try await index.optimize()
    }
    
    func batchUpdateIndex(
        name: String,
        updates: [(documentId: String, embeddings: [[Float]])]
    ) async throws {
        guard let index = indices[name] else {
            throw VectorStoreError.indexNotFound(name)
        }
        
        try await index.batchUpdate(updates: updates)
    }
}

// MARK: - ベクトルインデックス

class VectorIndex {
    let name: String
    let dimension: Int
    let metric: VectorMetric
    private var vectors: [String: [[Float]]] = [:]
    
    init(name: String, dimension: Int, metric: VectorMetric) {
        self.name = name
        self.dimension = dimension
        self.metric = metric
    }
    
    func update(documentId: String, embeddings: [[Float]]) async throws {
        vectors[documentId] = embeddings
    }
    
    func remove(documentId: String) async throws {
        vectors.removeValue(forKey: documentId)
    }
    
    func optimize() async throws {
        // インデックス最適化処理（プレースホルダー）
    }
    
    func batchUpdate(updates: [(documentId: String, embeddings: [[Float]])]) async throws {
        for update in updates {
            vectors[update.documentId] = update.embeddings
        }
    }
}

// MARK: - 類似度計算

class SimilarityCalculator {
    
    func calculate(
        embedding1: [Float],
        embedding2: [Float],
        metric: VectorMetric
    ) -> Double {
        guard embedding1.count == embedding2.count else { return 0.0 }
        
        switch metric {
        case .cosine:
            return cosineSimilarity(embedding1, embedding2)
        case .euclidean:
            return 1.0 / (1.0 + euclideanDistance(embedding1, embedding2))
        case .dotProduct:
            return dotProduct(embedding1, embedding2)
        case .manhattan:
            return 1.0 / (1.0 + manhattanDistance(embedding1, embedding2))
        }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard normA > 0 && normB > 0 else { return 0.0 }
        return Double(dotProduct / (normA * normB))
    }
    
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Double {
        let squaredDiffs = zip(a, b).map { ($0 - $1) * ($0 - $1) }
        return Double(sqrt(squaredDiffs.reduce(0, +)))
    }
    
    private func dotProduct(_ a: [Float], _ b: [Float]) -> Double {
        return Double(zip(a, b).map(*).reduce(0, +))
    }
    
    private func manhattanDistance(_ a: [Float], _ b: [Float]) -> Double {
        return Double(zip(a, b).map { abs($0 - $1) }.reduce(0, +))
    }
}

// MARK: - データ構造

struct CandidateVector {
    let id: String
    let documentId: String
    let chunkId: String
    let chunkIndex: Int
    let embedding: [Float]
    let content: String
    let metadata: [String: Any]?
}

// MARK: - エラー定義

enum VectorStoreError: Error, LocalizedError {
    case indexNotFound(String)
    case invalidDimension(expected: Int, actual: Int)
    case storageError(String)
    case searchError(String)
    
    var errorDescription: String? {
        switch self {
        case .indexNotFound(let name):
            return "Vector index not found: \(name)"
        case .invalidDimension(let expected, let actual):
            return "Invalid vector dimension: expected \(expected), got \(actual)"
        case .storageError(let message):
            return "Vector storage error: \(message)"
        case .searchError(let message):
            return "Vector search error: \(message)"
        }
    }
}