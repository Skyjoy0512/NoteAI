import SwiftUI

// MARK: - プロジェクトAI機能メインビュー

struct ProjectAIView: View {
    @StateObject private var viewModel: ProjectAIViewModel
    @State private var selectedTab: AITab = .overview
    
    init(project: Project, projectAIUseCase: ProjectAIUseCaseProtocol) {
        self._viewModel = StateObject(wrappedValue: ProjectAIViewModel(
            project: project,
            projectAIUseCase: projectAIUseCase
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブバー
                CustomTabBar(
                    selectedTab: $selectedTab,
                    tabs: AITab.allCases
                )
                
                // メインコンテンツ
                TabView(selection: $selectedTab) {
                    ForEach(AITab.allCases, id: \.self) { tab in
                        tabContent(for: tab)
                            .tag(tab)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)
            }
            .navigationTitle("AI分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("ナレッジベース更新") {
                            Task { await viewModel.refreshKnowledgeBase() }
                        }
                        Button("エクスポート") {
                            viewModel.showingExportOptions = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showingExportOptions) {
            ExportOptionsView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.switchTab(selectedTab)
        }
        .onChange(of: selectedTab) { newTab in
            viewModel.switchTab(newTab)
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: AITab) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch tab {
                case .overview:
                    OverviewTabView(viewModel: viewModel)
                case .analysis:
                    AnalysisTabView(viewModel: viewModel)
                case .chat:
                    ChatTabView(viewModel: viewModel)
                case .timeline:
                    TimelineTabView(viewModel: viewModel)
                case .sentiment:
                    SentimentTabView(viewModel: viewModel)
                case .engagement:
                    EngagementTabView(viewModel: viewModel)
                case .progress:
                    ProgressTabView(viewModel: viewModel)
                case .actions:
                    ActionsTabView(viewModel: viewModel)
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadInitialData()
        }
    }
}

// MARK: - カスタムタブバー

struct CustomTabBar: View {
    @Binding var selectedTab: AITab
    let tabs: [AITab]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(tabs, id: \.self) { tab in
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.title2)
                        Text(tab.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.tint.opacity(0.1))
                        }
                    }
                    .onTapGesture {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

// MARK: - 概要タブ

struct OverviewTabView: View {
    @ObservedObject var viewModel: ProjectAIViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // プロジェクト概要
            ProjectOverviewCard(viewModel: viewModel)
            
            // コンテキストサマリー
            if let summary = viewModel.contextSummary {
                ContextSummaryCard(summary: summary)
            }
            
            // インサイト
            if !viewModel.insights.isEmpty {
                InsightsCard(insights: viewModel.insights)
            }
            
            // 最新の分析結果
            if !viewModel.analysisResults.isEmpty {
                RecentAnalysisCard(results: viewModel.analysisResults)
            }
        }
    }
}

// MARK: - プロジェクト概要カード

struct ProjectOverviewCard: View {
    @ObservedObject var viewModel: ProjectAIViewModel
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.project.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let description = viewModel.project.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    AsyncImage(url: nil) { _ in
                        // プロジェクト画像
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                }
                
                if let context = viewModel.projectContext {
                    Divider()
                    
                    HStack {
                        MetricView(
                            title: "総コンテンツ",
                            value: "\(context.totalContent)",
                            icon: "doc.text.fill"
                        )
                        
                        Spacer()
                        
                        MetricView(
                            title: "参加者",
                            value: "\(context.participants.count)",
                            icon: "person.2.fill"
                        )
                        
                        Spacer()
                        
                        MetricView(
                            title: "完全性",
                            value: "\(Int(context.metadata.completeness * 100))%",
                            icon: "checkmark.circle.fill"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - コンテキストサマリーカード

struct ContextSummaryCard: View {
    let summary: ContextSummary
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("プロジェクトサマリー")
                    .font(.headline)
                
                Text(summary.overallSummary)
                    .font(.body)
                
                if !summary.keyMetrics.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主要メトリクス")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(summary.keyMetrics, id: \.name) { metric in
                                MetricRowView(metric: metric)
                            }
                        }
                    }
                }
                
                if !summary.recentHighlights.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近のハイライト")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(summary.recentHighlights, id: \.self) { highlight in
                            HStack {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 6, height: 6)
                                Text(highlight)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - インサイトカード

struct InsightsCard: View {
    let insights: [ProjectInsight]
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("インサイト")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(insights.count)件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(insights.prefix(3), id: \.id) { insight in
                        InsightRowView(insight: insight)
                    }
                }
                
                if insights.count > 3 {
                    Button("すべて表示 (\(insights.count - 3)件)") {
                        // 詳細表示
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - 最新分析結果カード

struct RecentAnalysisCard: View {
    let results: [ProjectAnalysisResult]
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("最新の分析")
                    .font(.headline)
                
                LazyVStack(spacing: 8) {
                    ForEach(results.prefix(3), id: \.analysisType) { result in
                        AnalysisResultRowView(result: result)
                    }
                }
            }
        }
    }
}

// MARK: - 分析タブ

struct AnalysisTabView: View {
    @ObservedObject var viewModel: ProjectAIViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 分析タイプ選択
            AnalysisTypeSelector(
                selectedType: $viewModel.selectedAnalysisType,
                onAnalyze: { type in
                    Task {
                        await viewModel.performAnalysis(type: type)
                    }
                }
            )
            
            // 分析結果
            if let analysis = viewModel.currentAnalysis {
                AnalysisResultView(result: analysis)
            }
            
            // 分析履歴
            if !viewModel.analysisResults.isEmpty {
                AnalysisHistoryView(results: viewModel.analysisResults) { result in
                    viewModel.currentAnalysis = result
                    viewModel.showingAnalysisDetail = true
                }
            }
        }
    }
}

// MARK: - チャットタブ

struct ChatTabView: View {
    @ObservedObject var viewModel: ProjectAIViewModel
    @State private var scrollProxy: ScrollViewReader?
    
    var body: some View {
        VStack(spacing: 0) {
            // チャット履歴
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.chatHistory, id: \.id) { message in
                            ChatMessageView(
                                message: message,
                                onFeedback: { messageId, rating, helpful, accurate, comment in
                                    Task {
                                        await viewModel.provideFeedback(
                                            for: messageId,
                                            rating: rating,
                                            helpful: helpful,
                                            accurate: accurate,
                                            comment: comment
                                        )
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                .onAppear {
                    self.scrollProxy = proxy
                }
                .onChange(of: viewModel.chatHistory.count) { _ in
                    // 新しいメッセージにスクロール
                    if let lastMessage = viewModel.chatHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // 質問入力
            QuestionInputView(
                question: $viewModel.currentQuestion,
                isAnswering: viewModel.isAnswering,
                onAsk: {
                    Task {
                        await viewModel.askQuestion()
                    }
                },
                onClearHistory: {
                    Task {
                        await viewModel.clearChatHistory()
                    }
                }
            )
        }
    }
}

// MARK: - 共通コンポーネント

struct Card<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct MetricRowView: View {
    let metric: Metric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", metric.value))
                        .font(.headline)
                    
                    if let unit = metric.unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    TrendIndicator(trend: metric.trend)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TrendIndicator: View {
    let trend: MetricTrend
    
    var body: some View {
        Image(systemName: iconName)
            .font(.caption)
            .foregroundColor(color)
    }
    
    private var iconName: String {
        switch trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        case .unknown: return "questionmark"
        }
    }
    
    private var color: Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .blue
        case .unknown: return .gray
        }
    }
}

struct InsightRowView: View {
    let insight: ProjectInsight
    
    var body: some View {
        HStack(spacing: 12) {
            // インサイトタイプアイコン
            Image(systemName: insight.type.iconName)
                .font(.title3)
                .foregroundColor(insight.type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // 重要度インジケーター
            ImportanceIndicator(importance: insight.importance)
        }
        .padding(.vertical, 4)
    }
}

struct ImportanceIndicator: View {
    let importance: InsightImportance
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
    
    private var color: Color {
        switch importance {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .gray
        }
    }
}

struct AnalysisResultRowView: View {
    let result: ProjectAnalysisResult
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.analysisType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("信頼度: \(Int(result.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(RelativeDateTimeFormatter().localizedString(for: result.generatedAt, relativeTo: Date()))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("分析中...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - 拡張

extension InsightType {
    var iconName: String {
        switch self {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .anomaly: return "exclamationmark.triangle"
        case .opportunity: return "lightbulb"
        case .risk: return "exclamationmark.shield"
        case .achievement: return "trophy"
        case .recommendation: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .trend: return .blue
        case .anomaly: return .orange
        case .opportunity: return .green
        case .risk: return .red
        case .achievement: return .yellow
        case .recommendation: return .purple
        }
    }
}

// プレビュー用のモック実装
#if DEBUG
struct ProjectAIView_Previews: PreviewProvider {
    static var previews: some View {
        let mockProject = Project(
            id: UUID(),
            name: "サンプルプロジェクト",
            description: "テスト用のプロジェクトです",
            coverImageData: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: nil
        )
        
        ProjectAIView(
            project: mockProject,
            projectAIUseCase: MockProjectAIUseCase()
        )
    }
}

class MockProjectAIUseCase: ProjectAIUseCaseProtocol {
    // モック実装...
    func analyzeProject(projectId: UUID, analysisType: ProjectAnalysisType) async throws -> ProjectAnalysisResult {
        // モック実装
        return ProjectAnalysisResult(
            projectId: projectId,
            analysisType: analysisType,
            result: AnalysisContent(
                summary: "サンプル分析結果",
                keyPoints: ["ポイント1", "ポイント2"],
                details: [:],
                visualData: nil,
                recommendations: ["推奨事項1"]
            ),
            confidence: 0.85,
            sources: [],
            generatedAt: Date(),
            metadata: AnalysisMetadata(
                processingTime: 1.5,
                tokenCount: 500,
                modelUsed: "GPT-4",
                analysisVersion: "1.0.0",
                qualityScore: 0.9
            )
        )
    }
    
    // 他のメソッドもモック実装を追加
    func compareProjects(projectIds: [UUID], comparisonType: ProjectComparisonType) async throws -> ProjectComparisonResult {
        fatalError("Not implemented")
    }
    
    func generateProjectInsights(projectId: UUID, timeRange: DateInterval?) async throws -> [ProjectInsight] {
        return []
    }
    
    func askQuestion(projectId: UUID, question: String, context: AIQuestionContext?) async throws -> AIQuestionResponse {
        fatalError("Not implemented")
    }
    
    func getChatHistory(projectId: UUID, limit: Int) async throws -> [ChatMessage] {
        return []
    }
    
    func deleteChatHistory(projectId: UUID) async throws {
        // Mock implementation
    }
    
    func buildProjectContext(projectId: UUID, includeTranscriptions: Bool, includeDocuments: Bool, timeRange: DateInterval?) async throws -> ProjectContext {
        fatalError("Not implemented")
    }
    
    func getContextSummary(projectId: UUID) async throws -> ContextSummary {
        fatalError("Not implemented")
    }
    
    func refreshProjectKnowledgeBase(projectId: UUID) async throws -> KnowledgeBase {
        fatalError("Not implemented")
    }
    
    func analyzeProjectTimeline(projectId: UUID, granularity: TimelineGranularity) async throws -> ProjectTimeline {
        fatalError("Not implemented")
    }
    
    func detectProjectTrends(projectId: UUID, trendType: TrendType) async throws -> [ProjectTrend] {
        return []
    }
    
    func generateProgressReport(projectId: UUID, reportType: ProgressReportType, timeRange: DateInterval) async throws -> ProgressReport {
        fatalError("Not implemented")
    }
    
    func generateActionItems(projectId: UUID, priority: ActionItemPriority?) async throws -> [ActionItem] {
        return []
    }
    
    func suggestNextSteps(projectId: UUID, context: NextStepContext?) async throws -> [NextStepSuggestion] {
        return []
    }
    
    func generateMeetingSummary(recordingIds: [UUID], summaryType: MeetingSummaryType) async throws -> MeetingSummary {
        fatalError("Not implemented")
    }
    
    func analyzeSentiment(projectId: UUID, timeRange: DateInterval?) async throws -> SentimentAnalysis {
        fatalError("Not implemented")
    }
    
    func analyzeEngagement(projectId: UUID, timeRange: DateInterval?) async throws -> EngagementAnalysis {
        fatalError("Not implemented")
    }
    
    func detectMoodChanges(projectId: UUID, timeRange: DateInterval) async throws -> [MoodChange] {
        return []
    }
}
#endif