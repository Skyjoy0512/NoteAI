import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - エクスポートビュー

struct ExportView: View {
    @StateObject private var viewModel: ExportViewModel
    @State private var selectedExportType: ExportType = .project
    @State private var showingExportSheet = false
    @State private var showingFormatPicker = false
    
    init(project: Project, exportService: ExportServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: ExportViewModel(
            project: project,
            exportService: exportService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // エクスポートタイプ選択
                ExportTypeSelector(
                    selectedType: $selectedExportType,
                    availableTypes: ExportType.allCases
                )
                
                // メインコンテンツ
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedExportType {
                        case .project:
                            ProjectExportSection(viewModel: viewModel)
                        case .analysis:
                            AnalysisExportSection(viewModel: viewModel)
                        case .recording:
                            RecordingExportSection(viewModel: viewModel)
                        case .data:
                            DataExportSection(viewModel: viewModel)
                        }
                    }
                    .padding()
                }
                
                // エクスポートボタン
                ExportActionButton(
                    exportType: selectedExportType,
                    isLoading: viewModel.isExporting,
                    onExport: {
                        Task {
                            await viewModel.performExport(type: selectedExportType)
                        }
                    }
                )
                .padding()
            }
            .navigationTitle("エクスポート")
            // .navigationBarTitleDisplayMode(.large) // macOS unavailable
        }
        .overlay {
            if viewModel.isExporting {
                ExportProgressOverlay(
                    currentOperation: viewModel.currentOperation,
                    progress: viewModel.exportProgress
                )
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showingExportHistory) {
            ExportHistoryView()
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            ExportSettingsView()
        }
        .sheet(isPresented: $viewModel.showingExportResult) {
            if let result = viewModel.lastExportResult {
                ExportResultView(result: result, onDismiss: {
                    viewModel.showingExportResult = false
                })
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
    }
}

// MARK: - エクスポートタイプ選択器

struct ExportTypeSelector: View {
    @Binding var selectedType: ExportType
    let availableTypes: [ExportType]
    
    var body: some View {
        Picker("エクスポートタイプ", selection: $selectedType) {
            ForEach(availableTypes, id: \.self) { type in
                Label(type.displayName, systemImage: type.iconName)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

// MARK: - プロジェクトエクスポートセクション

struct ProjectExportSection: View {
    @ObservedObject var viewModel: ExportViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // フォーマット選択
            ProjectFormatPicker(
                selectedFormat: $viewModel.selectedProjectFormat,
                availableFormats: viewModel.availableProjectFormats.map { $0.format }
            )
            
            // オプション設定
            ProjectExportOptionsView(
                options: $viewModel.projectExportOptions
            )
            
            // サイズ見積もり
            if let sizeEstimate = viewModel.projectSizeEstimate {
                ExportSizeEstimateCard(estimate: sizeEstimate)
            }
        }
    }
}

// MARK: - 分析エクスポートセクション

struct AnalysisExportSection: View {
    @ObservedObject var viewModel: ExportViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 分析タイプ選択
            // Note: Using selectedAnalysisTypes (Set) instead of selectedAnalysisType
            VStack {
                Text("分析タイプ選択")
                    .font(.headline)
                ForEach(AdvancedAnalysisType.allCases, id: \.self) { type in
                    HStack {
                        Text(type.displayName)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.selectedAnalysisTypes.contains(type) },
                            set: { isOn in
                                if isOn {
                                    viewModel.selectedAnalysisTypes.insert(type)
                                } else {
                                    viewModel.selectedAnalysisTypes.remove(type)
                                }
                            }
                        ))
                    }
                }
            }
            
            // フォーマット選択
            AnalysisFormatPicker(
                selectedFormat: $viewModel.selectedAnalysisFormat,
                availableFormats: viewModel.availableAnalysisFormats
            )
            
            // オプション設定
            AnalysisExportOptionsView(
                options: $viewModel.analysisExportOptions
            )
        }
    }
}

// MARK: - レコーディングエクスポートセクション

struct RecordingExportSection: View {
    @ObservedObject var viewModel: ExportViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // レコーディング選択
            RecordingSelector(
                selectedRecordings: Binding(
                    get: { Array(viewModel.selectedRecordings) },
                    set: { viewModel.selectedRecordings = Set($0) }
                ),
                availableRecordings: viewModel.availableRecordings.map { recordingInfo in
                    // Convert RecordingInfo to Recording for compatibility
                    Recording(
                        id: recordingInfo.id,
                        title: recordingInfo.title,
                        audioFileURL: URL(fileURLWithPath: "/tmp/placeholder.wav"), // RecordingInfo doesn't have audioFileURL
                        duration: recordingInfo.duration,
                        createdAt: recordingInfo.recordedAt,
                        projectId: UUID() // Placeholder - needs actual project mapping
                    )
                }
            )
            
            // フォーマット選択
            RecordingFormatPicker(
                selectedFormat: $viewModel.selectedRecordingFormat,
                availableFormats: viewModel.availableRecordingFormats
            )
            
            // オプション設定
            RecordingExportOptionsView(
                options: $viewModel.recordingExportOptions
            )
        }
    }
}

// MARK: - データエクスポートセクション

struct DataExportSection: View {
    @ObservedObject var viewModel: ExportViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // データタイプ選択
            DataTypeSelector(
                selectedTypes: $viewModel.selectedDataTypes,
                availableTypes: ExportDataType.allCases
            )
            
            // フォーマット選択
            DataFormatPicker(
                selectedFormat: $viewModel.selectedDataFormat,
                availableFormats: viewModel.availableDataFormats
            )
            
            // オプション設定
            DataExportOptionsView(
                options: $viewModel.dataExportOptions
            )
        }
    }
}

// MARK: - エクスポートボタン

struct ExportActionButton: View {
    let exportType: ExportType
    let isLoading: Bool
    let onExport: () -> Void
    
    var body: some View {
        Button(action: onExport) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Text(isLoading ? "エクスポート中..." : "\(exportType.displayName)をエクスポート")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
}

// MARK: - エクスポート進行状況オーバーレイ

struct ExportProgressOverlay: View {
    let currentOperation: String?
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                VStack(spacing: 8) {
                    Text("エクスポート中...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let operation = currentOperation {
                        Text(operation)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(30)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - エクスポート結果ビュー

struct ExportResultView: View {
    let result: ExportResult
    let onDismiss: () -> Void
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 成功アイコン
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                // 結果情報
                VStack(spacing: 12) {
                    Text("エクスポート完了")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(result.fileName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("ファイルサイズ", systemImage: "doc")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: result.fileSize, countStyle: .file))
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Label("フォーマット", systemImage: "doc.text")
                        Spacer()
                        Text(result.format.displayName)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                
                // アクションボタン
                VStack(spacing: 12) {
                    Button("ファイルを共有") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("関連アプリで開く") {
                        openFile()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("エクスポート結果")
            // .navigationBarTitleDisplayMode(.inline) // macOS unavailable
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [result.fileUrl])
        }
    }
    
    private func openFile() {
        // TODO: ファイルを関連アプリで開く実装
    }
}

// MARK: - 共有シート

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
// macOS用の共有実装
struct ShareSheet: View {
    let activityItems: [Any]
    
    var body: some View {
        VStack {
            Text("macOSでは別の共有方法を実装する必要があります")
            Button("Finderで表示") {
                // TODO: Finderで表示する実装
            }
        }
    }
}
#endif

// MARK: - 拡張

extension ExportType {
    var displayName: String {
        switch self {
        case .project: return "プロジェクト"
        case .analysis: return "分析結果"
        case .recording: return "レコーディング"
        case .data: return "データ"
        }
    }
    
    var iconName: String {
        switch self {
        case .project: return "folder"
        case .analysis: return "chart.bar"
        case .recording: return "waveform"
        case .data: return "table"
        }
    }
}

// プレビュー用のモック実装
#if DEBUG
struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        let mockProject = Project(
            id: UUID(),
            name: "Export Test Project",
            description: "エクスポートテストプロジェクト",
            coverImageData: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: ProjectMetadata()
        )
        
        ExportView(
            project: mockProject,
            exportService: MockExportService()
        )
    }
}

class MockExportService: ExportServiceProtocol {
    func exportProject(projectId: UUID, format: ExportFormat, options: ExportOptions) async throws -> ExportResult {
        // モック実装
        return ExportResult(
            exportId: UUID(),
            format: format,
            fileUrl: URL(fileURLWithPath: "/tmp/test.pdf"),
            fileName: "test.pdf",
            fileSize: 1024,
            checksum: "mock_checksum",
            metadata: ExportMetadata(
                originalDataSize: 1024,
                compressionRatio: 1.0,
                exportDuration: 1.0,
                itemCount: 1,
                includedDataTypes: [],
                qualityMetrics: ExportQualityMetrics(
                    dataCompleteness: 1.0,
                    formatConsistency: 1.0,
                    validationScore: 1.0,
                    errorCount: 0
                ),
                warnings: []
            ),
            createdAt: Date(),
            expiresAt: nil
        )
    }
    
    func exportAnalysisResults(analysisResults: ComprehensiveAnalysisResult, format: AnalysisExportFormat, options: AnalysisExportOptions) async throws -> ExportResult {
        fatalError("Mock not implemented")
    }
    
    func exportRecordings(recordingIds: [UUID], format: RecordingExportFormat, options: RecordingExportOptions) async throws -> ExportResult {
        fatalError("Mock not implemented")
    }
    
    func exportData(projectId: UUID, dataTypes: [ExportDataType], format: DataExportFormat, options: DataExportOptions) async throws -> ExportResult {
        fatalError("Mock not implemented")
    }
    
    func getAvailableFormats(for exportType: ExportType) -> [ExportFormatInfo] {
        return []
    }
    
    func estimateExportSize(projectId: UUID, format: ExportFormat, options: ExportOptions) async throws -> ExportSizeEstimate {
        return ExportSizeEstimate(
            estimatedSize: 1024,
            confidence: 0.8,
            breakdown: ExportSizeBreakdown(
                textContent: 512,
                images: 256,
                audio: 0,
                metadata: 128,
                charts: 128,
                other: 0
            ),
            estimatedDuration: 1.0
        )
    }
}

// MARK: - Placeholder Views for Missing Components

struct ExportHistoryView: View {
    var body: some View {
        Text("エクスポート履歴")
            .navigationTitle("エクスポート履歴")
    }
}

struct ProjectFormatPicker: View {
    @Binding var selectedFormat: ExportFormat
    let availableFormats: [ExportFormat]
    
    var body: some View {
        VStack {
            Text("プロジェクトフォーマット選択")
            Picker("フォーマット", selection: $selectedFormat) {
                ForEach(availableFormats, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}

struct ProjectExportOptionsView: View {
    @Binding var options: ExportOptions
    
    var body: some View {
        Text("プロジェクトエクスポートオプション")
    }
}

struct ExportSizeEstimateCard: View {
    let estimate: ExportSizeEstimate
    
    var body: some View {
        VStack {
            Text("推定サイズ: \(estimate.estimatedSize) bytes")
            Text("信頼度: \(estimate.confidence)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AnalysisFormatPicker: View {
    @Binding var selectedFormat: AnalysisExportFormat
    let availableFormats: [AnalysisExportFormat]
    
    var body: some View {
        VStack {
            Text("分析フォーマット選択")
            Picker("フォーマット", selection: $selectedFormat) {
                ForEach(availableFormats, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
        }
    }
}

struct RecordingSelector: View {
    @Binding var selectedRecordings: [UUID]
    let availableRecordings: [Recording]
    
    var body: some View {
        Text("レコーディング選択")
    }
}

struct RecordingFormatPicker: View {
    @Binding var selectedFormat: RecordingExportFormat
    let availableFormats: [RecordingExportFormat]
    
    var body: some View {
        VStack {
            Text("レコーディングフォーマット選択")
            Picker("フォーマット", selection: $selectedFormat) {
                ForEach(availableFormats, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
        }
    }
}

struct DataTypeSelector: View {
    @Binding var selectedTypes: Set<ExportDataType>
    let availableTypes: [ExportDataType]
    
    var body: some View {
        VStack {
            Text("データタイプ選択")
            ForEach(availableTypes, id: \.self) { type in
                HStack {
                    Text(type.displayName)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { selectedTypes.contains(type) },
                        set: { isOn in
                            if isOn {
                                selectedTypes.insert(type)
                            } else {
                                selectedTypes.remove(type)
                            }
                        }
                    ))
                }
            }
        }
    }
}

struct DataFormatPicker: View {
    @Binding var selectedFormat: DataExportFormat
    let availableFormats: [DataExportFormat]
    
    var body: some View {
        VStack {
            Text("データフォーマット選択")
            Picker("フォーマット", selection: $selectedFormat) {
                ForEach(availableFormats, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
        }
    }
}

struct AnalysisExportOptionsView: View {
    @Binding var options: AnalysisExportOptions
    
    var body: some View {
        Text("分析エクスポートオプション")
    }
}

struct RecordingExportOptionsView: View {
    @Binding var options: RecordingExportOptions
    
    var body: some View {
        Text("レコーディングエクスポートオプション")
    }
}

struct DataExportOptionsView: View {
    @Binding var options: DataExportOptions
    
    var body: some View {
        Text("データエクスポートオプション")
    }
}

// Note: AnalysisTypeSelector is defined in AdvancedAnalyticsView.swift

// MARK: - Type Extensions

extension ExportDataType {
    var displayName: String {
        switch self {
        case .transcriptions: return "文字起こし"
        case .summaries: return "要約"
        case .analytics: return "分析結果"
        case .recordings: return "録音データ"
        case .metadata: return "メタデータ"
        case .projects: return "プロジェクト情報"
        }
    }
}

#endif
