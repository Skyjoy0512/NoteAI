import Foundation
import SwiftUI

// MARK: - エクスポートViewModel

@MainActor
class ExportViewModel: ObservableObject {
    
    // MARK: - 依存関係
    private let project: Project
    private let exportService: ExportServiceProtocol
    
    // MARK: - UI状態
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var currentOperation: String?
    @Published var errorMessage: String?
    @Published var showingExportHistory = false
    @Published var showingSettings = false
    @Published var showingExportResult = false
    @Published var lastExportResult: ExportResult?
    
    // MARK: - プロジェクトエクスポート
    @Published var selectedProjectFormat: ExportFormat = .pdf
    @Published var projectExportOptions = ExportOptions()
    @Published var availableProjectFormats: [ExportFormatInfo] = []
    @Published var projectSizeEstimate: ExportSizeEstimate?
    
    // MARK: - 分析エクスポート
    @Published var selectedAnalysisTypes: Set<AdvancedAnalysisType> = [.predictive, .anomaly]
    @Published var selectedAnalysisFormat: AnalysisExportFormat = .detailedReport
    @Published var analysisExportOptions = AnalysisExportOptions()
    @Published var availableAnalysisFormats: [AnalysisExportFormat] = AnalysisExportFormat.allCases
    @Published var analysisResults: ComprehensiveAnalysisResult?
    
    // MARK: - レコーディングエクスポート
    @Published var selectedRecordings: Set<UUID> = []
    @Published var selectedRecordingFormat: RecordingExportFormat = .audioWithTranscript
    @Published var recordingExportOptions = RecordingExportOptions()
    @Published var availableRecordings: [RecordingInfo] = []
    @Published var availableRecordingFormats: [RecordingExportFormat] = RecordingExportFormat.allCases
    
    // MARK: - データエクスポート
    @Published var selectedDataTypes: Set<ExportDataType> = [.transcriptions, .summaries]
    @Published var selectedDataFormat: DataExportFormat = .structured
    @Published var dataExportOptions = DataExportOptions()
    @Published var availableDataFormats: [DataExportFormat] = DataExportFormat.allCases
    
    // MARK: - 設定
    @Published var exportSettings = ExportSettings()
    @Published var exportHistory: [ExportHistoryItem] = []
    
    init(project: Project, exportService: ExportServiceProtocol) {
        self.project = project
        self.exportService = exportService
        
        setupDefaultSettings()
    }
    
    // MARK: - 初期化メソッド
    
    func loadInitialData() async {
        currentOperation = "初期データを読み込み中..."
        
        // 並行実行
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAvailableFormats() }
            group.addTask { await self.loadAvailableRecordings() }
            group.addTask { await self.loadExportHistory() }
            group.addTask { await self.updateProjectSizeEstimate() }
        }
        
        currentOperation = nil
    }
    
    func performExport(type: ExportType) async {
        guard !isExporting else { return }
        
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil
        
        do {
            let result: ExportResult
            
            switch type {
            case .project:
                result = try await exportProject()
            case .analysis:
                result = try await exportAnalysis()
            case .recording:
                result = try await exportRecordings()
            case .data:
                result = try await exportData()
            }
            
            lastExportResult = result
            showingExportResult = true
            
            // 履歴に追加
            await addToExportHistory(result: result)
            
        } catch {
            errorMessage = "エクスポートに失敗しました: \(error.localizedDescription)"
        }
        
        isExporting = false
        exportProgress = 0.0
        currentOperation = nil
    }
    
    // MARK: - エクスポート実行メソッド
    
    private func exportProject() async throws -> ExportResult {
        currentOperation = "プロジェクトデータを収集中..."
        exportProgress = 0.1
        
        // サイズ見積もり更新
        await updateProjectSizeEstimate()
        exportProgress = 0.3
        
        currentOperation = "エクスポートを実行中..."
        exportProgress = 0.5
        
        let result = try await exportService.exportProject(
            projectId: project.id,
            format: selectedProjectFormat,
            options: projectExportOptions
        )
        
        exportProgress = 1.0
        currentOperation = "エクスポート完了"
        
        return result
    }
    
    private func exportAnalysis() async throws -> ExportResult {
        guard let analysisResults = analysisResults else {
            throw ExportViewModelError.noAnalysisResults
        }
        
        currentOperation = "分析レポートを生成中..."
        exportProgress = 0.3
        
        let result = try await exportService.exportAnalysisResults(
            analysisResults: analysisResults,
            format: selectedAnalysisFormat,
            options: analysisExportOptions
        )
        
        exportProgress = 1.0
        currentOperation = "分析エクスポート完了"
        
        return result
    }
    
    private func exportRecordings() async throws -> ExportResult {
        guard !selectedRecordings.isEmpty else {
            throw ExportViewModelError.noRecordingsSelected
        }
        
        currentOperation = "レコーディングデータを処理中..."
        exportProgress = 0.3
        
        let result = try await exportService.exportRecordings(
            recordingIds: Array(selectedRecordings),
            format: selectedRecordingFormat,
            options: recordingExportOptions
        )
        
        exportProgress = 1.0
        currentOperation = "レコーディングエクスポート完了"
        
        return result
    }
    
    private func exportData() async throws -> ExportResult {
        guard !selectedDataTypes.isEmpty else {
            throw ExportViewModelError.noDataTypesSelected
        }
        
        currentOperation = "データを変換中..."
        exportProgress = 0.3
        
        let result = try await exportService.exportData(
            projectId: project.id,
            dataTypes: Array(selectedDataTypes),
            format: selectedDataFormat,
            options: dataExportOptions
        )
        
        exportProgress = 1.0
        currentOperation = "データエクスポート完了"
        
        return result
    }
    
    // MARK: - データ読み込みメソッド
    
    private func loadAvailableFormats() async {
        availableProjectFormats = exportService.getAvailableFormats(for: .project)
    }
    
    private func loadAvailableRecordings() async {
        // TODO: 実際のレコーディングデータ読み込み
        availableRecordings = [
            RecordingInfo(
                id: UUID(),
                title: "サンプルレコーディング 1",
                duration: 1800,
                recordedAt: Date(),
                fileSize: 1024 * 1024
            )
        ]
    }
    
    private func loadExportHistory() async {
        // TODO: 実際のエクスポート履歴読み込み
        exportHistory = []
    }
    
    private func updateProjectSizeEstimate() async {
        do {
            projectSizeEstimate = try await exportService.estimateExportSize(
                projectId: project.id,
                format: selectedProjectFormat,
                options: projectExportOptions
            )
        } catch {
            // エラーをログに記録し、サイズ見積もりをクリア
            projectSizeEstimate = nil
        }
    }
    
    private func addToExportHistory(result: ExportResult) async {
        let historyItem = ExportHistoryItem(
            id: result.exportId,
            projectId: project.id,
            projectName: project.name,
            format: result.format,
            fileName: result.fileName,
            fileSize: result.fileSize,
            createdAt: result.createdAt,
            expiresAt: result.expiresAt,
            status: .completed
        )
        
        exportHistory.insert(historyItem, at: 0)
        
        // TODO: 永続化ストレージに保存
    }
    
    // MARK: - 設定関連メソッド
    
    private func setupDefaultSettings() {
        // デフォルト設定をロード
        exportSettings = ExportSettings()
        
        // 設定に基づいてオプションを初期化
        projectExportOptions = ExportOptions(
            includeMetadata: exportSettings.includeMetadata,
            includeImages: exportSettings.includeImages,
            includeAudio: exportSettings.includeAudio,
            includeAnalytics: exportSettings.includeAnalytics,
            compressionLevel: exportSettings.compressionLevel
        )
    }
    
    func updateExportSettings(_ newSettings: ExportSettings) {
        exportSettings = newSettings
        
        // 設定変更に応じてオプションを更新
        projectExportOptions = ExportOptions(
            includeMetadata: newSettings.includeMetadata,
            includeImages: newSettings.includeImages,
            includeAudio: newSettings.includeAudio,
            includeAnalytics: newSettings.includeAnalytics,
            compressionLevel: newSettings.compressionLevel
        )
    }
    
    // MARK: - アクションメソッド
    
    func clearError() {
        errorMessage = nil
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func selectAllRecordings() {
        selectedRecordings = Set(availableRecordings.map { $0.id })
    }
    
    func deselectAllRecordings() {
        selectedRecordings.removeAll()
    }
    
    func selectAllDataTypes() {
        selectedDataTypes = Set(ExportDataType.allCases)
    }
    
    func deselectAllDataTypes() {
        selectedDataTypes.removeAll()
    }
    
    func deleteExportHistoryItem(_ item: ExportHistoryItem) {
        exportHistory.removeAll { $0.id == item.id }
        // TODO: ファイルも削除
    }
    
    func clearExportHistory() {
        exportHistory.removeAll()
        // TODO: 関連ファイルも削除
    }
    
    // MARK: - フォーマット変更処理
    
    func onProjectFormatChanged() {
        Task {
            await updateProjectSizeEstimate()
        }
    }
    
    func onProjectOptionsChanged() {
        Task {
            await updateProjectSizeEstimate()
        }
    }
}

// MARK: - サポートデータ型

struct RecordingInfo {
    let id: UUID
    let title: String
    let duration: TimeInterval
    let recordedAt: Date
    let fileSize: Int64
}

struct ExportHistoryItem: Identifiable {
    let id: UUID
    let projectId: UUID
    let projectName: String
    let format: ExportFormat
    let fileName: String
    let fileSize: Int64
    let createdAt: Date
    let expiresAt: Date?
    let status: ExportStatus
}

enum ExportStatus: String, CaseIterable {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .inProgress: return "エクスポート中"
        case .completed: return "完了"
        case .failed: return "失敗"
        case .expired: return "期限切れ"
        }
    }
}

struct ExportSettings {
    var includeMetadata: Bool = true
    var includeImages: Bool = true
    var includeAudio: Bool = false
    var includeAnalytics: Bool = true
    var compressionLevel: CompressionLevel = .medium
    var defaultFormat: ExportFormat = .pdf
    var autoCleanupExpiredFiles: Bool = true
    var maxHistoryItems: Int = 50
    var enableNotifications: Bool = true
}

// MARK: - エラー定義

enum ExportViewModelError: Error, LocalizedError {
    case noAnalysisResults
    case noRecordingsSelected
    case noDataTypesSelected
    case exportInProgress
    case invalidSettings
    
    var errorDescription: String? {
        switch self {
        case .noAnalysisResults:
            return "エクスポートする分析結果がありません"
        case .noRecordingsSelected:
            return "レコーディングが選択されていません"
        case .noDataTypesSelected:
            return "エクスポートするデータタイプが選択されていません"
        case .exportInProgress:
            return "エクスポートが既に実行中です"
        case .invalidSettings:
            return "エクスポート設定が無効です"
        }
    }
}