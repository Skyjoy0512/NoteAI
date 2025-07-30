import Foundation
import UniformTypeIdentifiers

// MARK: - リファクタリングされたエクスポートサービス実装

@MainActor
class ExportService: ExportServiceProtocol {
    
    // MARK: - 依存関係
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let ragService: RAGServiceProtocol
    
    // MARK: - リファクタリングされたコンポーネント
    private let strategyFactory: ExportStrategyFactory
    private let engineFactory: ExportEngineFactory
    private let pipeline: ExportPipeline
    private let validator: ExportValidator
    
    // MARK: - ユーティリティ
    private let cache = RAGCache.shared
    private let logger = RAGLogger.shared
    private let performanceMonitor = RAGPerformanceMonitor.shared
    private let fileManager = FileManager.default
    
    // MARK: - 設定
    private let tempDirectory: URL
    private let exportDirectory: URL
    
    init(
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        ragService: RAGServiceProtocol
    ) {
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
        self.ragService = ragService
        
        // リファクタリングされたコンポーネント初期化
        self.engineFactory = DefaultExportEngineFactory()
        self.pipeline = DefaultExportPipeline()
        self.validator = DefaultExportValidator()
        self.strategyFactory = DefaultExportStrategyFactory(
            projectRepository: projectRepository,
            recordingRepository: recordingRepository,
            ragService: ragService,
            engineFactory: engineFactory
        )
        
        // ディレクトリ設定 - Safe unwrapping
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Failed to get documents directory - this should never happen on iOS/macOS")
        }
        self.tempDirectory = documentsPath.appendingPathComponent("temp")
        self.exportDirectory = documentsPath.appendingPathComponent("exports")
        
        setupDirectories()
    }
    
    // MARK: - 公開メソッド
    
    func exportProject(
        projectId: UUID,
        format: ExportFormat,
        options: ExportOptions
    ) async throws -> ExportResult {
        
        let measurement = performanceMonitor.startMeasurement()
        
        logger.log(level: .info, message: "Starting project export", context: [
            "projectId": projectId.uuidString,
            "format": format.rawValue
        ])
        
        do {
            // プロジェクト戦略取得
            let strategy = strategyFactory.createStrategy(for: .project) as! ProjectExportStrategy
            
            // プロジェクトデータ収集
            guard let project = try await projectRepository.findById(projectId) else {
                throw ExportError.resourceNotAvailable("Project not found")
            }
            let recordings = try await recordingRepository.findByProjectId(projectId)
            
            // プロジェクトエクスポートデータ作成
            let exportData = createProjectExportData(
                project: project,
                recordings: recordings,
                options: options
            )
            
            // ストラテジーを使用してエクスポート実行
            let result = try await strategy.export(
                input: exportData,
                format: format,
                configuration: options
            )
            
            performanceMonitor.recordMetric(
                operation: "exportProject",
                measurement: measurement,
                success: true,
                metadata: [
                    "format": format.rawValue,
                    "fileSize": result.fileSize
                ]
            )
            
            logger.log(level: .info, message: "Project export completed", context: [
                "exportId": result.exportId.uuidString,
                "fileSize": result.fileSize,
                "duration": measurement.duration
            ])
            
            return result
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "exportProject",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Project export failed", context: [
                "error": error.localizedDescription
            ])
            
            throw error
        }
    }
    
    func exportAnalysisResults(
        analysisResults: ComprehensiveAnalysisResult,
        format: AnalysisExportFormat,
        options: AnalysisExportOptions
    ) async throws -> ExportResult {
        
        let measurement = performanceMonitor.startMeasurement()
        
        logger.log(level: .info, message: "Starting analysis export", context: [
            "projectId": analysisResults.projectId.uuidString,
            "format": format.rawValue
        ])
        
        do {
            // 分析戦略取得
            let strategy = strategyFactory.createStrategy(for: .analysis) as! AnalysisExportStrategy
            
            // エクスポートフォーマット変換
            let exportFormat = mapAnalysisFormatToExportFormat(format)
            
            // ストラテジーを使用してエクスポート実行
            let result = try await strategy.export(
                input: analysisResults,
                format: exportFormat,
                configuration: options
            )
            
            performanceMonitor.recordMetric(
                operation: "exportAnalysisResults",
                measurement: measurement,
                success: true,
                metadata: [
                    "format": format.rawValue,
                    "fileSize": result.fileSize
                ]
            )
            
            logger.log(level: .info, message: "Analysis export completed", context: [
                "exportId": result.exportId.uuidString,
                "fileSize": result.fileSize,
                "duration": measurement.duration
            ])
            
            return result
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "exportAnalysisResults",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Analysis export failed", context: [
                "error": error.localizedDescription
            ])
            
            throw error
        }
    }
    
    private func mapAnalysisFormatToExportFormat(_ format: AnalysisExportFormat) -> ExportFormat {
        switch format {
        case .detailedReport: return .pdf
        case .summary: return .docx
        case .charts: return .html
        case .rawData: return .json
        }
    }
    
    func exportRecordings(
        recordingIds: [UUID],
        format: RecordingExportFormat,
        options: RecordingExportOptions
    ) async throws -> ExportResult {
        
        let measurement = performanceMonitor.startMeasurement()
        
        logger.log(level: .info, message: "Starting recordings export", context: [
            "recordingIds": recordingIds.map { $0.uuidString },
            "format": format.rawValue
        ])
        
        do {
            // レコーディング戦略取得
            let strategy = strategyFactory.createStrategy(for: .recording) as! RecordingExportStrategy
            
            // エクスポートフォーマット変換
            let exportFormat = mapRecordingFormatToExportFormat(format)
            
            // ストラテジーを使用してエクスポート実行
            let result = try await strategy.export(
                input: recordingIds,
                format: exportFormat,
                configuration: options
            )
            
            performanceMonitor.recordMetric(
                operation: "exportRecordings",
                measurement: measurement,
                success: true,
                metadata: [
                    "format": format.rawValue,
                    "recordingCount": recordingIds.count,
                    "fileSize": result.fileSize
                ]
            )
            
            logger.log(level: .info, message: "Recordings export completed", context: [
                "exportId": result.exportId.uuidString,
                "recordingCount": recordingIds.count,
                "fileSize": result.fileSize,
                "duration": measurement.duration
            ])
            
            return result
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "exportRecordings",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Recordings export failed", context: [
                "error": error.localizedDescription
            ])
            
            throw error
        }
    }
    
    private func mapRecordingFormatToExportFormat(_ format: RecordingExportFormat) -> ExportFormat {
        switch format {
        case .audioWithTranscript: return .zip
        case .transcriptOnly: return .json
        case .audioOnly: return .zip
        case .summaryReport: return .pdf
        }
    }
    
    func exportData(
        projectId: UUID,
        dataTypes: [ExportDataType],
        format: DataExportFormat,
        options: DataExportOptions
    ) async throws -> ExportResult {
        
        let measurement = performanceMonitor.startMeasurement()
        
        logger.log(level: .info, message: "Starting data export", context: [
            "projectId": projectId.uuidString,
            "dataTypes": dataTypes.map { $0.rawValue },
            "format": format.rawValue
        ])
        
        do {
            // データ戦略取得
            let strategy = strategyFactory.createStrategy(for: .data) as! DataExportStrategy
            
            // データエクスポートリクエスト作成
            let exportRequest = DataExportRequest(
                projectId: projectId,
                dataTypes: dataTypes
            )
            
            // エクスポートフォーマット変換
            let exportFormat = mapDataFormatToExportFormat(format)
            
            // ストラテジーを使用してエクスポート実行
            let result = try await strategy.export(
                input: exportRequest,
                format: exportFormat,
                configuration: options
            )
            
            performanceMonitor.recordMetric(
                operation: "exportData",
                measurement: measurement,
                success: true,
                metadata: [
                    "format": format.rawValue,
                    "dataTypes": dataTypes.count,
                    "fileSize": result.fileSize
                ]
            )
            
            logger.log(level: .info, message: "Data export completed", context: [
                "exportId": result.exportId.uuidString,
                "dataTypes": dataTypes.count,
                "fileSize": result.fileSize,
                "duration": measurement.duration
            ])
            
            return result
            
        } catch {
            performanceMonitor.recordMetric(
                operation: "exportData",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Data export failed", context: [
                "error": error.localizedDescription
            ])
            
            throw error
        }
    }
    
    private func mapDataFormatToExportFormat(_ format: DataExportFormat) -> ExportFormat {
        switch format {
        case .structured: return .json
        case .tabular: return .csv
        case .hierarchical: return .xml
        case .compressed: return .zip
        }
    }
    
    nonisolated func getAvailableFormats(for exportType: ExportType) -> [ExportFormatInfo] {
        switch exportType {
        case .project:
            return getProjectExportFormats()
        case .analysis:
            return getAnalysisExportFormats()
        case .recording:
            return getRecordingExportFormats()
        case .data:
            return getDataExportFormats()
        }
    }
    
    func estimateExportSize(
        projectId: UUID,
        format: ExportFormat,
        options: ExportOptions
    ) async throws -> ExportSizeEstimate {
        
        do {
            // プロジェクト戦略取得
            let strategy = strategyFactory.createStrategy(for: .project) as! ProjectExportStrategy
            
            // プロジェクトデータ収集
            guard let project = try await projectRepository.findById(projectId) else {
                throw ExportError.resourceNotAvailable("Project not found")
            }
            let recordings = try await recordingRepository.findByProjectId(projectId)
            
            // プロジェクトエクスポートデータ作成
            let exportData = createProjectExportData(
                project: project,
                recordings: recordings,
                options: options
            )
            
            // ストラテジーを使用してサイズ見積もり
            return try await strategy.estimateSize(
                input: exportData,
                format: format,
                configuration: options
            )
            
        } catch {
            logger.log(level: .error, message: "Size estimation failed", context: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    // MARK: - 内部メソッド
    
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        } catch {
            logger.log(level: .error, message: "Failed to create export directories", context: [
                "error": error.localizedDescription
            ])
        }
    }
    
    // MARK: - リファクタリングされたヘルパーメソッド
    
    private func createProjectExportData(
        project: Project,
        recordings: [Recording],
        options: ExportOptions
    ) -> ProjectExportData {
        
        // TODO: 実際のRAGサービスからのデータ取得を実装
        let textContent = "Sample project content" // ragService から取得
        let analytics: AnalyticsData? = options.includeAnalytics ? AnalyticsData(
            summaries: ["Sample summary"],
            insights: ["Sample insight"],
            charts: []
        ) : nil
        
        return ProjectExportData(
            project: project,
            recordings: recordings,
            analytics: analytics,
            textContent: textContent,
            metadata: [
                "projectId": project.id.uuidString,
                "createdAt": project.createdAt,
                "exportedAt": Date()
            ]
        )
    }
    
    // MARK: - フォーマット情報メソッド
    
    nonisolated private func getProjectExportFormats() -> [ExportFormatInfo] {
        return [
            ExportFormatInfo(format: .pdf, name: "PDF", description: "プロジェクトの完全なPDFレポート"),
            ExportFormatInfo(format: .docx, name: "Word", description: "編集可能なWord文書"),
            ExportFormatInfo(format: .html, name: "HTML", description: "ウェブブラウザで表示可能なHTMLページ"),
            ExportFormatInfo(format: .markdown, name: "Markdown", description: "軽量なMarkdown形式"),
            ExportFormatInfo(format: .zip, name: "ZIP", description: "すべてのファイルを含むアーカイブ")
        ]
    }
    
    nonisolated private func getAnalysisExportFormats() -> [ExportFormatInfo] {
        return [
            ExportFormatInfo(format: .pdf, name: "PDF", description: "分析レポートのPDF"),
            ExportFormatInfo(format: .docx, name: "Word", description: "編集可能な分析レポート"),
            ExportFormatInfo(format: .html, name: "HTML", description: "インタラクティブな分析ダッシュボード"),
            ExportFormatInfo(format: .json, name: "JSON", description: "構造化された分析データ")
        ]
    }
    
    nonisolated private func getRecordingExportFormats() -> [ExportFormatInfo] {
        return [
            ExportFormatInfo(format: .zip, name: "ZIP", description: "音声ファイルと文字起こしのアーカイブ"),
            ExportFormatInfo(format: .json, name: "JSON", description: "文字起こしと分析データ"),
            ExportFormatInfo(format: .csv, name: "CSV", description: "表形式の文字起こしデータ")
        ]
    }
    
    nonisolated private func getDataExportFormats() -> [ExportFormatInfo] {
        return [
            ExportFormatInfo(format: .json, name: "JSON", description: "構造化されたプロジェクトデータ"),
            ExportFormatInfo(format: .csv, name: "CSV", description: "表形式のデータエクスポート"),
            ExportFormatInfo(format: .xml, name: "XML", description: "XMLフォーマットのデータ")
        ]
    }
}

// MARK: - 補助データ型

struct ExportContent {
    let data: Data
    let mimeType: String
}

// MARK: - サポートデータ型（ExportServiceProtocolで定義済み）

// MARK: - フォーマット拡張

extension ExportFormat {
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .html: return "html"
        case .markdown: return "md"
        case .json: return "json"
        case .csv: return "csv"
        case .xml: return "xml"
        case .zip: return "zip"
        case .epub: return "epub"
        }
    }
    
    var supportedFeatures: [ExportFeature] {
        switch self {
        case .pdf:
            return [.richText, .images, .charts, .tables, .metadata]
        case .docx:
            return [.richText, .images, .charts, .tables, .hyperlinks, .metadata]
        case .html:
            return [.richText, .images, .charts, .tables, .hyperlinks, .interactivity]
        case .markdown:
            return [.richText, .images, .tables, .hyperlinks]
        case .json, .xml:
            return [.metadata, .compression]
        case .csv:
            return [.metadata]
        case .zip:
            return [.compression]
        case .epub:
            return [.richText, .images, .tables, .hyperlinks, .metadata]
        }
    }
}