import Foundation
import SwiftUI

// MARK: - プロジェクトAI機能ViewModel

@MainActor
class ProjectAIViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var project: Project
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 分析結果
    @Published var analysisResults: [ProjectAnalysisResult] = []
    @Published var currentAnalysis: ProjectAnalysisResult?
    @Published var selectedAnalysisType: ProjectAnalysisType = .summary
    
    // 質問応答
    @Published var chatHistory: [ChatMessage] = []
    @Published var currentQuestion = ""
    @Published var isAnswering = false
    @Published var lastResponse: AIQuestionResponse?
    
    // プロジェクトコンテキスト
    @Published var projectContext: ProjectContext?
    @Published var contextSummary: ContextSummary?
    @Published var knowledgeBase: KnowledgeBase?
    
    // インサイト
    @Published var insights: [ProjectInsight] = []
    @Published var selectedInsightType: InsightType?
    
    // タイムライン分析
    @Published var timeline: ProjectTimeline?
    @Published var selectedGranularity: TimelineGranularity = .day
    @Published var trends: [ProjectTrend] = []
    @Published var selectedTrendType: TrendType = .activity
    
    // 進捗レポート
    @Published var progressReport: ProgressReport?
    @Published var selectedReportType: ProgressReportType = .weekly
    @Published var reportTimeRange: DateInterval
    
    // アクション・提案
    @Published var actionItems: [ActionItem] = []
    @Published var nextStepSuggestions: [NextStepSuggestion] = []
    @Published var meetingSummaries: [MeetingSummary] = []
    
    // 感情・エンゲージメント分析
    @Published var sentimentAnalysis: SentimentAnalysis?
    @Published var engagementAnalysis: EngagementAnalysis?
    @Published var moodChanges: [MoodChange] = []
    
    // UI状態
    @Published var activeTab: AITab = .overview
    @Published var showingAnalysisDetail = false
    @Published var showingQuestionContext = false
    @Published var showingExportOptions = false
    
    // MARK: - 依存関係
    private let projectAIUseCase: ProjectAIUseCaseProtocol
    
    // MARK: - 初期化
    init(
        project: Project,
        projectAIUseCase: ProjectAIUseCaseProtocol
    ) {
        self.project = project
        self.projectAIUseCase = projectAIUseCase
        self.reportTimeRange = DateInterval(
            start: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date(),
            end: Date()
        )
        
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - データ読み込み
    
    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 並列でデータを読み込み
            async let contextTask: Void = loadProjectContext()
            async let insightsTask: Void = loadProjectInsights()
            async let chatHistoryTask: Void = loadChatHistory()
            
            _ = try await (contextTask, insightsTask, chatHistoryTask)
            
        } catch {
            await setError(error)
        }
    }
    
    func loadProjectContext() async throws {
        projectContext = try await projectAIUseCase.buildProjectContext(
            projectId: project.id,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: nil
        )
        
        contextSummary = try await projectAIUseCase.getContextSummary(
            projectId: project.id
        )
    }
    
    func loadProjectInsights() async throws {
        insights = try await projectAIUseCase.generateProjectInsights(
            projectId: project.id,
            timeRange: nil
        )
    }
    
    func loadChatHistory() async throws {
        chatHistory = try await projectAIUseCase.getChatHistory(
            projectId: project.id,
            limit: 50
        )
    }
    
    // MARK: - 分析機能
    
    func performAnalysis(type: ProjectAnalysisType) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await projectAIUseCase.analyzeProject(
                projectId: project.id,
                analysisType: type
            )
            
            currentAnalysis = result
            
            // 結果をリストに追加（重複チェック）
            if !analysisResults.contains(where: { $0.analysisType == type }) {
                analysisResults.append(result)
            } else {
                // 既存の結果を更新
                if let index = analysisResults.firstIndex(where: { $0.analysisType == type }) {
                    analysisResults[index] = result
                }
            }
            
            showingAnalysisDetail = true
            
        } catch {
            await setError(error)
        }
    }
    
    func compareWithProjects(_ projectIds: [UUID], type: ProjectComparisonType) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await projectAIUseCase.compareProjects(
                projectIds: [project.id] + projectIds,
                comparisonType: type
            )
            
            // 比較結果の処理
            // TODO: 比較結果の表示を実装
            
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - 質問応答機能
    
    func askQuestion() async {
        guard !currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isAnswering = true
        defer { isAnswering = false }
        
        do {
            let context = AIQuestionContext(
                includeRecordings: true,
                includeDocuments: true,
                timeRange: nil,
                specificSources: nil,
                language: .japanese,
                responseStyle: .detailed
            )
            
            let response = try await projectAIUseCase.askQuestion(
                projectId: project.id,
                question: currentQuestion,
                context: context
            )
            
            lastResponse = response
            
            // チャット履歴を更新
            try await loadChatHistory()
            
            // 質問をクリア
            currentQuestion = ""
            
        } catch {
            await setError(error)
        }
    }
    
    func clearChatHistory() async {
        do {
            try await projectAIUseCase.deleteChatHistory(projectId: project.id)
            chatHistory = []
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - タイムライン分析
    
    func analyzeTimeline() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            timeline = try await projectAIUseCase.analyzeProjectTimeline(
                projectId: project.id,
                granularity: selectedGranularity
            )
        } catch {
            await setError(error)
        }
    }
    
    func detectTrends() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            trends = try await projectAIUseCase.detectProjectTrends(
                projectId: project.id,
                trendType: selectedTrendType
            )
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - 進捗レポート
    
    func generateProgressReport() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            progressReport = try await projectAIUseCase.generateProgressReport(
                projectId: project.id,
                reportType: selectedReportType,
                timeRange: reportTimeRange
            )
        } catch {
            await setError(error)
        }
    }
    
    func updateReportTimeRange(start: Date, end: Date) {
        reportTimeRange = DateInterval(start: start, end: end)
    }
    
    // MARK: - アクション・提案
    
    func generateActionItems(priority: ActionItemPriority? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            actionItems = try await projectAIUseCase.generateActionItems(
                projectId: project.id,
                priority: priority
            )
        } catch {
            await setError(error)
        }
    }
    
    func generateNextStepSuggestions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            nextStepSuggestions = try await projectAIUseCase.suggestNextSteps(
                projectId: project.id,
                context: nil
            )
        } catch {
            await setError(error)
        }
    }
    
    func generateMeetingSummary(recordingIds: [UUID], type: MeetingSummaryType) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let summary = try await projectAIUseCase.generateMeetingSummary(
                recordingIds: recordingIds,
                summaryType: type
            )
            
            meetingSummaries.append(summary)
            
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - 感情・エンゲージメント分析
    
    func analyzeSentiment(timeRange: DateInterval? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            sentimentAnalysis = try await projectAIUseCase.analyzeSentiment(
                projectId: project.id,
                timeRange: timeRange
            )
        } catch {
            await setError(error)
        }
    }
    
    func analyzeEngagement(timeRange: DateInterval? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            engagementAnalysis = try await projectAIUseCase.analyzeEngagement(
                projectId: project.id,
                timeRange: timeRange
            )
        } catch {
            await setError(error)
        }
    }
    
    func detectMoodChanges(timeRange: DateInterval) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            moodChanges = try await projectAIUseCase.detectMoodChanges(
                projectId: project.id,
                timeRange: timeRange
            )
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - ナレッジベース管理
    
    func refreshKnowledgeBase() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            knowledgeBase = try await projectAIUseCase.refreshProjectKnowledgeBase(
                projectId: project.id
            )
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - UI アクション
    
    func selectAnalysisType(_ type: ProjectAnalysisType) {
        selectedAnalysisType = type
        if let existing = analysisResults.first(where: { $0.analysisType == type }) {
            currentAnalysis = existing
            showingAnalysisDetail = true
        }
    }
    
    func selectInsightType(_ type: InsightType) {
        selectedInsightType = type
    }
    
    func updateGranularity(_ granularity: TimelineGranularity) {
        selectedGranularity = granularity
        Task {
            await analyzeTimeline()
        }
    }
    
    func updateTrendType(_ type: TrendType) {
        selectedTrendType = type
        Task {
            await detectTrends()
        }
    }
    
    func switchTab(_ tab: AITab) {
        activeTab = tab
        
        // タブ切り替え時にデータを読み込み
        Task {
            switch tab {
            case .timeline:
                if timeline == nil {
                    await analyzeTimeline()
                }
            case .sentiment:
                if sentimentAnalysis == nil {
                    await analyzeSentiment()
                }
            case .engagement:
                if engagementAnalysis == nil {
                    await analyzeEngagement()
                }
            case .progress:
                if progressReport == nil {
                    await generateProgressReport()
                }
            default:
                break
            }
        }
    }
    
    // MARK: - エクスポート機能
    
    func exportAnalysis(_ analysis: ProjectAnalysisResult, format: ExportFormat) async {
        // エクスポート機能の実装
        showingExportOptions = false
    }
    
    func exportProgressReport(format: ExportFormat) async {
        guard progressReport != nil else { return }
        // レポートエクスポートの実装
    }
    
    // MARK: - フィードバック機能
    
    func provideFeedback(
        for messageId: String,
        rating: Int,
        helpful: Bool,
        accurate: Bool,
        comment: String?
    ) async {
        // フィードバック送信の実装
        if let index = chatHistory.firstIndex(where: { $0.id == messageId }) {
            let feedback = MessageFeedback(
                rating: rating,
                helpful: helpful,
                accurate: accurate,
                comment: comment,
                providedAt: Date()
            )
            
            let message = chatHistory[index]
            let newMetadata: MessageMetadata
            
            if let existingMetadata = message.metadata {
                newMetadata = MessageMetadata(
                    sources: existingMetadata.sources,
                    confidence: existingMetadata.confidence,
                    processingTime: existingMetadata.processingTime,
                    feedback: feedback
                )
            } else {
                newMetadata = MessageMetadata(
                    sources: nil,
                    confidence: nil,
                    processingTime: nil,
                    feedback: feedback
                )
            }
            
            let updatedMessage = ChatMessage(
                id: message.id,
                projectId: message.projectId,
                type: message.type,
                content: message.content,
                timestamp: message.timestamp,
                metadata: newMetadata
            )
            
            chatHistory[index] = updatedMessage
        }
    }
    
    // MARK: - エラーハンドリング
    
    private func setError(_ error: Error) async {
        errorMessage = error.localizedDescription
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - フォーマッター
    
    func formatConfidence(_ confidence: Double) -> String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    func formatSentimentScore(_ score: Double) -> String {
        switch score {
        case 0.5...1.0:
            return "ポジティブ"
        case 0.1..<0.5:
            return "やや ポジティブ"
        case -0.1...0.1:
            return "中立"
        case -0.5..<(-0.1):
            return "やや ネガティブ"
        default:
            return "ネガティブ"
        }
    }
    
    func formatEngagementLevel(_ level: EngagementLevel) -> (String, Color) {
        switch level {
        case .veryHigh:
            return ("非常に高い", .green)
        case .high:
            return ("高い", .green)
        case .moderate:
            return ("普通", .orange)
        case .low:
            return ("低い", .red)
        case .veryLow:
            return ("非常に低い", .red)
        }
    }
    
    func formatTrendDirection(_ direction: TrendDirection) -> (String, Color) {
        switch direction {
        case .upward:
            return ("上昇", .green)
        case .downward:
            return ("下降", .red)
        case .stable:
            return ("安定", .blue)
        case .volatile:
            return ("変動", .orange)
        default:
            return ("不明", .gray)
        }
    }
    
    func formatPriority(_ priority: ActionItemPriority) -> (String, Color) {
        switch priority {
        case .urgent:
            return ("緊急", .red)
        case .high:
            return ("高", .orange)
        case .medium:
            return ("中", .yellow)
        case .low:
            return ("低", .gray)
        }
    }
}

// MARK: - 列挙型
// Note: AITab is defined in ProjectAIView.swift

// ExportFormat is now defined in Core/Export/ExportTypes.swift