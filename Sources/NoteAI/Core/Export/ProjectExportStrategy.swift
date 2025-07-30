import Foundation

// MARK: - プロジェクトエクスポート戦略

struct ProjectExportStrategy: ExportStrategy {
    typealias Input = ProjectExportData
    typealias Output = ExportContent
    typealias Configuration = ExportOptions
    
    // MARK: - 依存関係
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let ragService: RAGServiceProtocol
    private let exportEngineFactory: ExportEngineFactory
    
    // MARK: - プロパティ
    let strategyName = "ProjectExportStrategy"
    let supportedFormats: [ExportFormat] = [
        .pdf, .docx, .html, .markdown, .epub, .zip
    ]
    let supportedFeatures: [ExportFeature] = [
        .richText, .images, .charts, .tables, .hyperlinks, .metadata, .compression
    ]
    
    init(
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol,
        ragService: RAGServiceProtocol,
        exportEngineFactory: ExportEngineFactory
    ) {
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
        self.ragService = ragService
        self.exportEngineFactory = exportEngineFactory
    }
    
    // MARK: - ExportStrategy実装
    
    func canHandle(_ format: ExportFormat) -> Bool {
        return supportedFormats.contains(format)
    }
    
    func export(
        input: ProjectExportData,
        format: ExportFormat,
        configuration: ExportOptions
    ) async throws -> ExportResult {
        
        // フォーマットサポートチェック
        guard canHandle(format) else {
            throw ExportError.unsupportedFormat(format, strategyName)
        }
        
        // 入力検証
        try await validate(input: input, configuration: configuration)
        
        // エンジン取得
        let engine = try exportEngineFactory.createEngine(for: format)
        
        // プロジェクトデータをエンジン用に変換
        let engineInput = try await prepareEngineInput(
            projectData: input,
            configuration: configuration
        )
        
        // エクスポート実行
        let exportContent = try await engine.export(
            content: engineInput,
            options: configuration
        )
        
        // 結果構築
        return try await buildExportResult(
            content: exportContent,
            format: format,
            originalData: input,
            configuration: configuration
        )
    }
    
    func estimateSize(
        input: ProjectExportData,
        format: ExportFormat,
        configuration: ExportOptions
    ) async throws -> ExportSizeEstimate {
        
        let baseSize = input.estimatedSize
        let formatMultiplier = getFormatSizeMultiplier(format)
        let optionsMultiplier = getOptionsSizeMultiplier(configuration)
        
        let estimatedSize = Int64(Double(baseSize) * formatMultiplier * optionsMultiplier)
        
        return ExportSizeEstimate(
            estimatedSize: estimatedSize,
            confidence: 0.85,
            breakdown: calculateSizeBreakdown(input, configuration),
            estimatedDuration: calculateEstimatedDuration(estimatedSize)
        )
    }
    
    func validate(
        input: ProjectExportData,
        configuration: ExportOptions
    ) async throws {
        
        // プロジェクトデータの検証
        guard !input.isEmpty else {
            throw ExportError.validationFailed([
                ExportValidationError(
                    field: "projectData",
                    message: "Project data is empty",
                    severity: .error
                )
            ])
        }
        
        // サイズ制限チェック
        let sizeEstimate = try await estimateSize(
            input: input,
            format: .pdf, // 仮のフォーマット
            configuration: configuration
        )
        
        let maxSize: Int64 = 100 * 1024 * 1024 // 100MB
        if sizeEstimate.estimatedSize > maxSize {
            throw ExportError.sizeLimitExceeded(sizeEstimate.estimatedSize, maxSize)
        }
    }
    
    // MARK: - 内部メソッド
    
    private func prepareEngineInput(
        projectData: ProjectExportData,
        configuration: ExportOptions
    ) async throws -> ProjectDocumentContent {
        
        var sections: [DocumentSection] = []
        
        // プロジェクト概要セクション
        sections.append(createProjectOverviewSection(projectData))
        
        // レコーディングセクション
        if !projectData.recordings.isEmpty {
            sections.append(contentsOf: try await createRecordingSections(
                projectData.recordings,
                configuration: configuration
            ))
        }
        
        // 分析セクション
        if configuration.includeAnalytics, let analytics = projectData.analytics {
            sections.append(contentsOf: createAnalyticsSections(analytics))
        }
        
        // メタデータセクション
        if configuration.includeMetadata {
            sections.append(createMetadataSection(projectData))
        }
        
        return ProjectDocumentContent(
            title: projectData.project.name,
            subtitle: projectData.project.description,
            sections: sections,
            metadata: projectData.metadata,
            createdAt: Date(),
            template: configuration.template
        )
    }
    
    private func createProjectOverviewSection(_ projectData: ProjectExportData) -> DocumentSection {
        return DocumentSection(
            title: "プロジェクト概要",
            content: DocumentContent.richText([
                DocumentElement.heading(text: projectData.project.name, level: 1),
                DocumentElement.paragraph(text: projectData.project.description ?? ""),
                DocumentElement.metadata([
                    "Created": projectData.project.createdAt,
                    "Last Updated": projectData.project.updatedAt,
                    "Recordings": projectData.recordings.count,
                    "Total Duration": projectData.totalDuration
                ])
            ]),
            subsections: [],
            importance: .high
        )
    }
    
    private func createRecordingSections(
        _ recordings: [Recording],
        configuration: ExportOptions
    ) async throws -> [DocumentSection] {
        
        var sections: [DocumentSection] = []
        
        for recording in recordings {
            let content = try await createRecordingContent(
                recording,
                includeAudio: configuration.includeAudio
            )
            
            sections.append(DocumentSection(
                title: recording.title.isEmpty ? "Recording \(recording.id.uuidString.prefix(8))" : recording.title,
                content: content,
                subsections: [],
                importance: .medium
            ))
        }
        
        return sections
    }
    
    private func createRecordingContent(
        _ recording: Recording,
        includeAudio: Bool
    ) async throws -> DocumentContent {
        
        var elements: [DocumentElement] = []
        
        // レコーディング情報
        elements.append(.metadata([
            "Duration": recording.duration,
            "Recorded At": recording.createdAt,
            "File URL": recording.audioFileURL.path
        ]))
        
        // TODO: 文字起こしデータを取得して追加
        // elements.append(.paragraph(text: transcription))
        
        // 音声ファイル（オプション）
        if includeAudio {
            // TODO: 音声ファイルの埋め込みまたはリンク
            // elements.append(.audio(url: recording.fileURL))
        }
        
        return .richText(elements)
    }
    
    private func createAnalyticsSections(_ analytics: AnalyticsData) -> [DocumentSection] {
        // TODO: 分析データをドキュメントセクションに変換
        return []
    }
    
    private func createMetadataSection(_ projectData: ProjectExportData) -> DocumentSection {
        return DocumentSection(
            title: "メタデータ",
            content: .richText([
                DocumentElement.metadata(projectData.metadata)
            ]),
            subsections: [],
            importance: .low
        )
    }
    
    private func buildExportResult(
        content: ExportContent,
        format: ExportFormat,
        originalData: ProjectExportData,
        configuration: ExportOptions
    ) async throws -> ExportResult {
        
        let exportId = UUID()
        let fileName = generateFileName(exportId: exportId, format: format)
        
        // TODO: 実際のファイル保存処理
        let fileUrl = URL(fileURLWithPath: "/tmp/\(fileName)")
        
        return ExportResult(
            exportId: exportId,
            format: format,
            fileUrl: fileUrl,
            fileName: fileName,
            fileSize: Int64(content.data.count),
            checksum: content.data.sha256,
            metadata: ExportMetadata(
                originalDataSize: originalData.estimatedSize,
                compressionRatio: Double(content.data.count) / Double(originalData.estimatedSize),
                exportDuration: 0.0, // TODO: 実際の時間計測
                itemCount: originalData.itemCount,
                includedDataTypes: getIncludedDataTypes(configuration),
                qualityMetrics: ExportQualityMetrics(
                    dataCompleteness: 1.0,
                    formatConsistency: 1.0,
                    validationScore: 0.95,
                    errorCount: 0
                ),
                warnings: []
            ),
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400 * 7)
        )
    }
    
    private func getFormatSizeMultiplier(_ format: ExportFormat) -> Double {
        switch format {
        case .pdf: return 1.2
        case .docx: return 1.5
        case .html: return 0.8
        case .markdown: return 0.6
        case .epub: return 1.1
        case .zip: return 0.7
        default: return 1.0
        }
    }
    
    private func getOptionsSizeMultiplier(_ options: ExportOptions) -> Double {
        var multiplier = 1.0
        
        if options.includeImages { multiplier += 0.5 }
        if options.includeAudio { multiplier += 2.0 }
        if options.includeAnalytics { multiplier += 0.3 }
        
        switch options.compressionLevel {
        case .none: multiplier *= 1.0
        case .low: multiplier *= 0.9
        case .medium: multiplier *= 0.7
        case .high: multiplier *= 0.5
        case .maximum: multiplier *= 0.3
        }
        
        return multiplier
    }
    
    private func calculateSizeBreakdown(
        _ projectData: ProjectExportData,
        _ configuration: ExportOptions
    ) -> ExportSizeBreakdown {
        
        let textSize = Int64(projectData.textContent.count * 2) // UTF-8エンコードを仮定
        let imageSize = configuration.includeImages ? projectData.estimatedImageSize : 0
        let audioSize = configuration.includeAudio ? projectData.estimatedAudioSize : 0
        let metadataSize: Int64 = 1024 // 1KB仮定
        
        return ExportSizeBreakdown(
            textContent: textSize,
            images: imageSize,
            audio: audioSize,
            metadata: metadataSize,
            charts: 0, // TODO: チャートサイズ計算
            other: 0
        )
    }
    
    private func calculateEstimatedDuration(_ estimatedSize: Int64) -> TimeInterval {
        // 1MB/秒の処理速度を仮定
        let processingSpeedMBPerSecond: Double = 1.0
        let sizeMB = Double(estimatedSize) / (1024 * 1024)
        return sizeMB / processingSpeedMBPerSecond
    }
    
    private func generateFileName(exportId: UUID, format: ExportFormat) -> String {
        let timestamp = DateFormatter().string(from: Date())
        return "project_export_\(exportId.uuidString.prefix(8))_\(timestamp).\(format.fileExtension)"
    }
    
    private func getIncludedDataTypes(_ configuration: ExportOptions) -> [ExportDataType] {
        var dataTypes: [ExportDataType] = []
        
        if configuration.includeMetadata { dataTypes.append(.metadata) }
        if configuration.includeAnalytics { dataTypes.append(.analytics) }
        if configuration.includeAudio { dataTypes.append(.recordings) }
        // TODO: 他のデータタイプも追加
        
        return dataTypes
    }
}

// MARK: - サポートデータ型

struct ProjectExportData {
    let project: Project
    let recordings: [Recording]
    let analytics: AnalyticsData?
    let textContent: String
    let metadata: [String: Any]
    
    var isEmpty: Bool {
        return recordings.isEmpty && textContent.isEmpty
    }
    
    var itemCount: Int {
        return recordings.count + (analytics != nil ? 1 : 0)
    }
    
    var estimatedSize: Int64 {
        return Int64(textContent.count) + estimatedImageSize + estimatedAudioSize
    }
    
    var estimatedImageSize: Int64 {
        // TODO: 実際の画像サイズ計算
        return 1024 * 1024 // 1MB仮定
    }
    
    var estimatedAudioSize: Int64 {
        return recordings.reduce(into: 0) { total, recording in
            // Note: Recording does not have fileSize property, so we estimate based on duration
            total += Int64(recording.duration * 16000) // Rough estimate based on duration
        }
    }
    
    var totalDuration: TimeInterval {
        return recordings.reduce(0) { $0 + $1.duration }
    }
}

struct AnalyticsData {
    let summaries: [String]
    let insights: [String]
    let charts: [ChartData]
}

struct ChartData {
    let title: String
    let type: String
    let data: [String: Any]
}

struct ProjectDocumentContent {
    let title: String
    let subtitle: String?
    let sections: [DocumentSection]
    let metadata: [String: Any]
    let createdAt: Date
    let template: ExportTemplate?
}

struct DocumentSection {
    let title: String
    let content: DocumentContent
    let subsections: [DocumentSection]
    let importance: SectionImportance
}

enum DocumentContent {
    case richText([DocumentElement])
    case plainText(String)
    case html(String)
    case markdown(String)
}

enum DocumentElement {
    case heading(text: String, level: Int)
    case paragraph(text: String)
    case list(items: [String], ordered: Bool)
    case table(headers: [String], rows: [[String]])
    case image(url: URL, caption: String?)
    case audio(url: URL, caption: String?)
    case chart(data: ChartData)
    case metadata([String: Any])
    case separator
}