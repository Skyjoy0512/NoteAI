import Foundation

// MARK: - エクスポート関連の型定義

// MARK: - エクスポートタイプ
enum ExportType: String, CaseIterable {
    case project = "project"
    case analysis = "analysis"
    case recording = "recording"
    case data = "data"
}

// MARK: - エクスポートフォーマット
enum ExportFormat: String, CaseIterable {
    case pdf = "pdf"
    case docx = "docx"
    case html = "html"
    case markdown = "markdown"
    case json = "json"
    case csv = "csv"
    case xml = "xml"
    case zip = "zip"
    case epub = "epub"
}

// MARK: - エクスポート機能
enum ExportFeature: String, CaseIterable {
    case richText = "rich_text"
    case images = "images"
    case charts = "charts"
    case tables = "tables"
    case hyperlinks = "hyperlinks"
    case metadata = "metadata"
    case compression = "compression"
    case interactivity = "interactivity"
}

// MARK: - 分析エクスポートフォーマット
enum AnalysisExportFormat: String, CaseIterable {
    case detailedReport = "detailed_report"
    case summary = "summary"
    case charts = "charts"
    case rawData = "raw_data"
}

// MARK: - レコーディングエクスポートフォーマット
enum RecordingExportFormat: String, CaseIterable {
    case audioWithTranscript = "audio_with_transcript"
    case transcriptOnly = "transcript_only"
    case audioOnly = "audio_only"
    case summaryReport = "summary_report"
}

// MARK: - データエクスポートフォーマット
enum DataExportFormat: String, CaseIterable {
    case structured = "structured"
    case tabular = "tabular"
    case hierarchical = "hierarchical"
    case compressed = "compressed"
}

// MARK: - エクスポートデータタイプ
enum ExportDataType: String, CaseIterable {
    case transcriptions = "transcriptions"
    case summaries = "summaries"
    case analytics = "analytics"
    case recordings = "recordings"
    case metadata = "metadata"
    case projects = "projects"
}

// MARK: - 圧縮レベル
enum CompressionLevel: String, CaseIterable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"
}

// MARK: - エクスポートテンプレート
enum ExportTemplate: String, CaseIterable {
    case standard = "standard"
    case minimal = "minimal"
    case detailed = "detailed"
    case academic = "academic"
    case business = "business"
}

// MARK: - セクション重要度
enum SectionImportance: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - エクスポートオプション
struct ExportOptions {
    var includeMetadata: Bool = true
    var includeImages: Bool = true
    var includeAudio: Bool = false
    var includeAnalytics: Bool = true
    var compressionLevel: CompressionLevel = .medium
    var template: ExportTemplate? = nil
    
    init(
        includeMetadata: Bool = true,
        includeImages: Bool = true,
        includeAudio: Bool = false,
        includeAnalytics: Bool = true,
        compressionLevel: CompressionLevel = .medium,
        template: ExportTemplate? = nil
    ) {
        self.includeMetadata = includeMetadata
        self.includeImages = includeImages
        self.includeAudio = includeAudio
        self.includeAnalytics = includeAnalytics
        self.compressionLevel = compressionLevel
        self.template = template
    }
}

// MARK: - 分析エクスポートオプション
struct AnalysisExportOptions {
    var includeCharts: Bool = true
    var includeRawData: Bool = false
    var detailLevel: AnalysisDetailLevel = .standard
    var format: AnalysisExportFormat = .detailedReport
    
    init(
        includeCharts: Bool = true,
        includeRawData: Bool = false,
        detailLevel: AnalysisDetailLevel = .standard,
        format: AnalysisExportFormat = .detailedReport
    ) {
        self.includeCharts = includeCharts
        self.includeRawData = includeRawData
        self.detailLevel = detailLevel
        self.format = format
    }
}

enum AnalysisDetailLevel: String, CaseIterable {
    case minimal = "minimal"
    case standard = "standard"
    case detailed = "detailed"
    case comprehensive = "comprehensive"
}

// MARK: - レコーディングエクスポートオプション
struct RecordingExportOptions {
    var includeTranscripts: Bool = true
    var includeAudio: Bool = true
    var audioQuality: AudioQuality = .standard
    var transcriptFormat: TranscriptFormat = .timestamped
    
    init(
        includeTranscripts: Bool = true,
        includeAudio: Bool = true,
        audioQuality: AudioQuality = .standard,
        transcriptFormat: TranscriptFormat = .timestamped
    ) {
        self.includeTranscripts = includeTranscripts
        self.includeAudio = includeAudio
        self.audioQuality = audioQuality
        self.transcriptFormat = transcriptFormat
    }
}

// AudioQuality is defined in Domain/Entities/Enums.swift
// Import and use the canonical AudioQuality enum from the Domain layer

enum TranscriptFormat: String, CaseIterable {
    case plain = "plain"
    case timestamped = "timestamped"
    case speakerLabeled = "speaker_labeled"
    case full = "full"
}

// MARK: - データエクスポートオプション
struct DataExportOptions {
    var includeMetadata: Bool = true
    var flattenStructure: Bool = false
    var includeSystemFields: Bool = false
    var format: DataExportFormat = .structured
    
    init(
        includeMetadata: Bool = true,
        flattenStructure: Bool = false,
        includeSystemFields: Bool = false,
        format: DataExportFormat = .structured
    ) {
        self.includeMetadata = includeMetadata
        self.flattenStructure = flattenStructure
        self.includeSystemFields = includeSystemFields
        self.format = format
    }
}

// MARK: - エクスポート結果
struct ExportResult {
    let exportId: UUID
    let format: ExportFormat
    let fileUrl: URL
    let fileName: String
    let fileSize: Int64
    let checksum: String
    let metadata: ExportMetadata
    let createdAt: Date
    let expiresAt: Date?
    
    init(
        exportId: UUID,
        format: ExportFormat,
        fileUrl: URL,
        fileName: String,
        fileSize: Int64,
        checksum: String,
        metadata: ExportMetadata,
        createdAt: Date,
        expiresAt: Date? = nil
    ) {
        self.exportId = exportId
        self.format = format
        self.fileUrl = fileUrl
        self.fileName = fileName
        self.fileSize = fileSize
        self.checksum = checksum
        self.metadata = metadata
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

// MARK: - エクスポートメタデータ
struct ExportMetadata {
    let originalDataSize: Int64
    var compressionRatio: Double
    let exportDuration: TimeInterval
    let itemCount: Int
    let includedDataTypes: [ExportDataType]
    let qualityMetrics: ExportQualityMetrics
    var warnings: [ExportWarning]
    
    init(
        originalDataSize: Int64,
        compressionRatio: Double,
        exportDuration: TimeInterval,
        itemCount: Int,
        includedDataTypes: [ExportDataType],
        qualityMetrics: ExportQualityMetrics,
        warnings: [ExportWarning] = []
    ) {
        self.originalDataSize = originalDataSize
        self.compressionRatio = compressionRatio
        self.exportDuration = exportDuration
        self.itemCount = itemCount
        self.includedDataTypes = includedDataTypes
        self.qualityMetrics = qualityMetrics
        self.warnings = warnings
    }
}

// MARK: - エクスポート品質メトリクス
struct ExportQualityMetrics {
    let dataCompleteness: Double // 0.0-1.0
    let formatConsistency: Double // 0.0-1.0
    let validationScore: Double // 0.0-1.0
    let errorCount: Int
    
    init(
        dataCompleteness: Double,
        formatConsistency: Double,
        validationScore: Double,
        errorCount: Int
    ) {
        self.dataCompleteness = dataCompleteness
        self.formatConsistency = formatConsistency
        self.validationScore = validationScore
        self.errorCount = errorCount
    }
}

// MARK: - エクスポート警告
struct ExportWarning {
    let type: ExportWarningType
    let message: String
    let affectedItems: [String]
    let severity: WarningSeverity
    
    init(
        type: ExportWarningType,
        message: String,
        affectedItems: [String],
        severity: WarningSeverity
    ) {
        self.type = type
        self.message = message
        self.affectedItems = affectedItems
        self.severity = severity
    }
}

enum ExportWarningType: String, CaseIterable {
    case dataTruncation = "data_truncation"
    case formatLimitation = "format_limitation"
    case qualityDegradation = "quality_degradation"
    case compatibilityIssue = "compatibility_issue"
    case performanceImpact = "performance_impact"
}

enum WarningSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

// MARK: - エクスポートサイズ見積もり
struct ExportSizeEstimate {
    let estimatedSize: Int64
    let confidence: Double // 0.0-1.0
    let breakdown: ExportSizeBreakdown
    let estimatedDuration: TimeInterval
    
    init(
        estimatedSize: Int64,
        confidence: Double,
        breakdown: ExportSizeBreakdown,
        estimatedDuration: TimeInterval
    ) {
        self.estimatedSize = estimatedSize
        self.confidence = confidence
        self.breakdown = breakdown
        self.estimatedDuration = estimatedDuration
    }
}

// MARK: - エクスポートサイズ内訳
struct ExportSizeBreakdown {
    let textContent: Int64
    let images: Int64
    let audio: Int64
    let metadata: Int64
    let charts: Int64
    let other: Int64
    
    var total: Int64 {
        return textContent + images + audio + metadata + charts + other
    }
    
    init(
        textContent: Int64,
        images: Int64,
        audio: Int64,
        metadata: Int64,
        charts: Int64,
        other: Int64
    ) {
        self.textContent = textContent
        self.images = images
        self.audio = audio
        self.metadata = metadata
        self.charts = charts
        self.other = other
    }
}