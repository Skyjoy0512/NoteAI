import Foundation

// MARK: - エクスポートサービスプロトコル

protocol ExportServiceProtocol {
    func exportProject(
        projectId: UUID,
        format: ExportFormat,
        options: ExportOptions
    ) async throws -> ExportResult
    
    func exportAnalysisResults(
        analysisResults: ComprehensiveAnalysisResult,
        format: AnalysisExportFormat,
        options: AnalysisExportOptions
    ) async throws -> ExportResult
    
    func exportRecordings(
        recordingIds: [UUID],
        format: RecordingExportFormat,
        options: RecordingExportOptions
    ) async throws -> ExportResult
    
    func exportData(
        projectId: UUID,
        dataTypes: [ExportDataType],
        format: DataExportFormat,
        options: DataExportOptions
    ) async throws -> ExportResult
    
    func getAvailableFormats(for exportType: ExportType) -> [ExportFormatInfo]
    
    func estimateExportSize(
        projectId: UUID,
        format: ExportFormat,
        options: ExportOptions
    ) async throws -> ExportSizeEstimate
}

// MARK: - エクスポートフォーマット情報
struct ExportFormatInfo {
    let format: ExportFormat
    let name: String
    let description: String
    let fileExtension: String
    let supportedFeatures: [ExportFeature]
    
    init(format: ExportFormat, name: String, description: String) {
        self.format = format
        self.name = name
        self.description = description
        self.fileExtension = format.fileExtension
        self.supportedFeatures = format.supportedFeatures
    }
}