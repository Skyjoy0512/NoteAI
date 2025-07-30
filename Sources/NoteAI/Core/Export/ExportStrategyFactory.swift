import Foundation

// MARK: - エクスポート戦略ファクトリ実装

class DefaultExportStrategyFactory: ExportStrategyFactory {
    
    // MARK: - 依存関係
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let ragService: RAGServiceProtocol
    private let engineFactory: ExportEngineFactory
    
    // MARK: - 戦略キャッシュ
    private var strategies: [ExportType: any ExportStrategy] = [:]
    
    init(
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        ragService: RAGServiceProtocol,
        engineFactory: ExportEngineFactory
    ) {
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
        self.ragService = ragService
        self.engineFactory = engineFactory
        
        setupDefaultStrategies()
    }
    
    // MARK: - ExportStrategyFactory実装
    
    func createStrategy(for exportType: ExportType) -> any ExportStrategy {
        if let existingStrategy = strategies[exportType] {
            return existingStrategy
        }
        
        let strategy = createNewStrategy(for: exportType)
        strategies[exportType] = strategy
        return strategy
    }
    
    func createPipeline() -> ExportPipeline {
        return DefaultExportPipeline()
    }
    
    func registerStrategy<T: ExportStrategy>(_ strategy: T, for type: ExportType) {
        strategies[type] = strategy
    }
    
    // MARK: - 戦略作成メソッド
    
    private func createNewStrategy(for exportType: ExportType) -> any ExportStrategy {
        switch exportType {
        case .project:
            return ProjectExportStrategy(
                projectRepository: projectRepository,
                recordingRepository: recordingRepository,
                ragService: ragService,
                exportEngineFactory: engineFactory
            )
            
        case .analysis:
            return AnalysisExportStrategy(
                ragService: ragService,
                engineFactory: engineFactory
            )
            
        case .recording:
            return RecordingExportStrategy(
                recordingRepository: recordingRepository,
                engineFactory: engineFactory
            )
            
        case .data:
            return DataExportStrategy(
                projectRepository: projectRepository,
                recordingRepository: recordingRepository,
                ragService: ragService,
                engineFactory: engineFactory
            )
        }
    }
    
    private func setupDefaultStrategies() {
        // プロジェクトエクスポート戦略
        registerStrategy(
            ProjectExportStrategy(
                projectRepository: projectRepository,
                recordingRepository: recordingRepository,
                ragService: ragService,
                exportEngineFactory: engineFactory
            ),
            for: .project
        )
        
        // 分析エクスポート戦略
        registerStrategy(
            AnalysisExportStrategy(
                ragService: ragService,
                engineFactory: engineFactory
            ),
            for: .analysis
        )
        
        // レコーディングエクスポート戦略
        registerStrategy(
            RecordingExportStrategy(
                recordingRepository: recordingRepository,
                engineFactory: engineFactory
            ),
            for: .recording
        )
        
        // データエクスポート戦略
        registerStrategy(
            DataExportStrategy(
                projectRepository: projectRepository,
                recordingRepository: recordingRepository,
                ragService: ragService,
                engineFactory: engineFactory
            ),
            for: .data
        )
    }
}

// MARK: - 各エクスポート戦略の実装

// MARK: - 分析エクスポート戦略

struct AnalysisExportStrategy: ExportStrategy {
    typealias Input = ComprehensiveAnalysisResult
    typealias Output = ExportContent
    typealias Configuration = AnalysisExportOptions
    
    let strategyName = "AnalysisExportStrategy"
    let supportedFormats: [ExportFormat] = [.pdf, .docx, .html, .markdown, .json]
    let supportedFeatures: [ExportFeature] = [.richText, .charts, .tables, .metadata]
    
    private let ragService: RAGServiceProtocol
    private let engineFactory: ExportEngineFactory
    
    init(ragService: RAGServiceProtocol, engineFactory: ExportEngineFactory) {
        self.ragService = ragService
        self.engineFactory = engineFactory
    }
    
    func canHandle(_ format: ExportFormat) -> Bool {
        return supportedFormats.contains(format)
    }
    
    func export(
        input: ComprehensiveAnalysisResult,
        format: ExportFormat,
        configuration: AnalysisExportOptions
    ) async throws -> ExportResult {
        
        guard canHandle(format) else {
            throw ExportError.unsupportedFormat(format, strategyName)
        }
        
        // 分析レポート生成
        let reportContent = try await generateAnalysisReport(
            analysisResult: input,
            configuration: configuration
        )
        
        // エンジン取得とエクスポート実行
        let engine = try engineFactory.createEngine(for: format)
        let exportContent = try await engine.export(
            content: reportContent,
            options: configuration
        )
        
        // 結果構築
        return ExportResult(
            exportId: UUID(),
            format: format,
            fileUrl: URL(fileURLWithPath: "/tmp/analysis_export.\(format.fileExtension)"),
            fileName: "analysis_export.\(format.fileExtension)",
            fileSize: Int64(exportContent.data.count),
            checksum: exportContent.data.sha256,
            metadata: ExportMetadata.default,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )
    }
    
    func estimateSize(
        input: ComprehensiveAnalysisResult,
        format: ExportFormat,
        configuration: AnalysisExportOptions
    ) async throws -> ExportSizeEstimate {
        
        let baseSize: Int64 = 512 * 1024 // 512KB基本サイズ
        let formatMultiplier = getFormatMultiplier(format)
        
        return ExportSizeEstimate(
            estimatedSize: Int64(Double(baseSize) * formatMultiplier),
            confidence: 0.85,
            breakdown: ExportSizeBreakdown(
                textContent: baseSize / 2,
                images: 0,
                audio: 0,
                metadata: 1024,
                charts: baseSize / 4,
                other: baseSize / 4
            ),
            estimatedDuration: 15.0
        )
    }
    
    func validate(input: ComprehensiveAnalysisResult, configuration: AnalysisExportOptions) async throws {
        // 分析結果の検証
        let hasAnalysisData = input.predictiveResults != nil || 
                             input.anomalyResults != nil || 
                             input.correlationResults != nil || 
                             input.clusteringResults != nil
        
        if !hasAnalysisData {
            throw ExportError.validationFailed([
                ExportValidationError(
                    field: "analysisResults",
                    message: "No analysis results to export",
                    severity: .error
                )
            ])
        }
    }
    
    private func generateAnalysisReport(
        analysisResult: ComprehensiveAnalysisResult,
        configuration: AnalysisExportOptions
    ) async throws -> AnalysisReportContent {
        
        // TODO: 実際の分析レポート生成ロジック
        return AnalysisReportContent(
            title: "分析レポート",
            summary: "分析結果のサマリー",
            analyses: [
                "predictive": analysisResult.predictiveResults as Any,
                "anomaly": analysisResult.anomalyResults as Any,
                "correlation": analysisResult.correlationResults as Any,
                "clustering": analysisResult.clusteringResults as Any
            ],
            charts: [],
            metadata: [:]
        )
    }
    
    private func getFormatMultiplier(_ format: ExportFormat) -> Double {
        switch format {
        case .pdf: return 1.2
        case .docx: return 1.5
        case .html: return 0.8
        case .markdown: return 0.6
        case .json: return 0.7
        default: return 1.0
        }
    }
}

// MARK: - レコーディングエクスポート戦略

struct RecordingExportStrategy: ExportStrategy {
    typealias Input = [UUID] // Recording IDs
    typealias Output = ExportContent
    typealias Configuration = RecordingExportOptions
    
    let strategyName = "RecordingExportStrategy"
    let supportedFormats: [ExportFormat] = [.zip, .json, .csv]
    let supportedFeatures: [ExportFeature] = [.compression, .metadata]
    
    private let recordingRepository: RecordingRepositoryProtocol
    private let engineFactory: ExportEngineFactory
    
    init(recordingRepository: RecordingRepositoryProtocol, engineFactory: ExportEngineFactory) {
        self.recordingRepository = recordingRepository
        self.engineFactory = engineFactory
    }
    
    func canHandle(_ format: ExportFormat) -> Bool {
        return supportedFormats.contains(format)
    }
    
    func export(
        input: [UUID],
        format: ExportFormat,
        configuration: RecordingExportOptions
    ) async throws -> ExportResult {
        
        // TODO: レコーディングエクスポート実装
        return ExportResult(
            exportId: UUID(),
            format: format,
            fileUrl: URL(fileURLWithPath: "/tmp/recordings_export.\(format.fileExtension)"),
            fileName: "recordings_export.\(format.fileExtension)",
            fileSize: 1024 * 1024,
            checksum: "placeholder",
            metadata: ExportMetadata.default,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )
    }
    
    func estimateSize(
        input: [UUID],
        format: ExportFormat,
        configuration: RecordingExportOptions
    ) async throws -> ExportSizeEstimate {
        
        // TODO: 実際のサイズ計算
        return ExportSizeEstimate(
            estimatedSize: Int64(input.count) * 1024 * 1024,
            confidence: 0.9,
            breakdown: ExportSizeBreakdown(
                textContent: 0,
                images: 0,
                audio: Int64(input.count) * 1024 * 1024,
                metadata: 1024,
                charts: 0,
                other: 0
            ),
            estimatedDuration: Double(input.count) * 10.0
        )
    }
    
    func validate(input: [UUID], configuration: RecordingExportOptions) async throws {
        guard !input.isEmpty else {
            throw ExportError.validationFailed([
                ExportValidationError(
                    field: "recordingIds",
                    message: "No recordings selected for export",
                    severity: .error
                )
            ])
        }
    }
}

// MARK: - データエクスポート戦略

struct DataExportStrategy: ExportStrategy {
    typealias Input = DataExportRequest
    typealias Output = ExportContent
    typealias Configuration = DataExportOptions
    
    let strategyName = "DataExportStrategy"
    let supportedFormats: [ExportFormat] = [.json, .csv, .xml]
    let supportedFeatures: [ExportFeature] = [.metadata, .compression]
    
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let ragService: RAGServiceProtocol
    private let engineFactory: ExportEngineFactory
    
    init(
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        ragService: RAGServiceProtocol,
        engineFactory: ExportEngineFactory
    ) {
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
        self.ragService = ragService
        self.engineFactory = engineFactory
    }
    
    func canHandle(_ format: ExportFormat) -> Bool {
        return supportedFormats.contains(format)
    }
    
    func export(
        input: DataExportRequest,
        format: ExportFormat,
        configuration: DataExportOptions
    ) async throws -> ExportResult {
        
        // TODO: データエクスポート実装
        return ExportResult(
            exportId: UUID(),
            format: format,
            fileUrl: URL(fileURLWithPath: "/tmp/data_export.\(format.fileExtension)"),
            fileName: "data_export.\(format.fileExtension)",
            fileSize: 1024 * 512,
            checksum: "placeholder",
            metadata: ExportMetadata.default,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )
    }
    
    func estimateSize(
        input: DataExportRequest,
        format: ExportFormat,
        configuration: DataExportOptions
    ) async throws -> ExportSizeEstimate {
        
        // TODO: 実際のサイズ計算
        return ExportSizeEstimate(
            estimatedSize: 1024 * 512,
            confidence: 0.8,
            breakdown: ExportSizeBreakdown(
                textContent: 1024 * 256,
                images: 0,
                audio: 0,
                metadata: 1024 * 256,
                charts: 0,
                other: 0
            ),
            estimatedDuration: 10.0
        )
    }
    
    func validate(input: DataExportRequest, configuration: DataExportOptions) async throws {
        guard !input.dataTypes.isEmpty else {
            throw ExportError.validationFailed([
                ExportValidationError(
                    field: "dataTypes",
                    message: "No data types selected for export",
                    severity: .error
                )
            ])
        }
    }
}

// MARK: - サポートデータ型

struct DataExportRequest {
    let projectId: UUID
    let dataTypes: [ExportDataType]
}

struct AnalysisReportContent {
    let title: String
    let summary: String
    let analyses: [String: Any]
    let charts: [ChartData]
    let metadata: [String: Any]
}

// MARK: - 拡張

extension Data {
    var sha256: String {
        // TODO: 実際のSHA256実装
        return "sha256_placeholder_\(count)"
    }
}