import Foundation

// MARK: - プロジェクトAI機能ユースケース実装

@MainActor
class ProjectAIUseCase: ProjectAIUseCaseProtocol {
    
    // MARK: - 依存関係
    private let ragService: RAGServiceProtocol
    private let llmService: LLMServiceProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    
    // MARK: - キャッシュ
    private var analysisCache: [String: ProjectAnalysisResult] = [:]
    private var contextCache: [UUID: ProjectContext] = [:]
    private var chatHistory: [UUID: [ChatMessage]] = [:]
    
    init(
        ragService: RAGServiceProtocol,
        llmService: LLMServiceProtocol,
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol
    ) {
        self.ragService = ragService
        self.llmService = llmService
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
    }
    
    // MARK: - プロジェクト横断分析実装
    
    func analyzeProject(
        projectId: UUID,
        analysisType: ProjectAnalysisType
    ) async throws -> ProjectAnalysisResult {
        
        let cacheKey = "\(projectId)_\(analysisType.rawValue)"
        if let cached = analysisCache[cacheKey] {
            // 1時間以内のキャッシュは有効
            if Date().timeIntervalSince(cached.generatedAt) < 3600 {
                return cached
            }
        }
        
        // プロジェクトコンテキストを構築
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: nil
        )
        
        // 分析タイプに応じた処理
        let result = try await performAnalysis(
            projectId: projectId,
            analysisType: analysisType,
            context: context
        )
        
        // キャッシュに保存
        analysisCache[cacheKey] = result
        
        return result
    }
    
    func compareProjects(
        projectIds: [UUID],
        comparisonType: ProjectComparisonType
    ) async throws -> ProjectComparisonResult {
        
        // 各プロジェクトのコンテキストを構築
        var projectContexts: [UUID: ProjectContext] = [:]
        
        for projectId in projectIds {
            let context = try await buildProjectContext(
                projectId: projectId,
                includeTranscriptions: true,
                includeDocuments: true,
                timeRange: nil
            )
            projectContexts[projectId] = context
        }
        
        return try await performProjectComparison(
            contexts: projectContexts,
            comparisonType: comparisonType
        )
    }
    
    func generateProjectInsights(
        projectId: UUID,
        timeRange: DateInterval?
    ) async throws -> [ProjectInsight] {
        
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: timeRange
        )
        
        return try await extractInsights(from: context)
    }
    
    // MARK: - 質問応答システム実装
    
    func askQuestion(
        projectId: UUID,
        question: String,
        context: AIQuestionContext?
    ) async throws -> AIQuestionResponse {
        
        // RAGコンテキストを取得
        let ragContext = try await ragService.getRelevantContext(
            for: question,
            projectId: projectId,
            maxTokens: 4000
        )
        
        // LLMに質問
        let ragResponse = try await ragService.answerQuestion(
            question: question,
            context: ragContext,
            provider: .openai
        )
        
        // 関連質問を生成
        let relatedQuestions = try await generateRelatedQuestions(
            originalQuestion: question,
            answer: ragResponse.answer,
            context: ragContext
        )
        
        // フォローアップ提案を生成
        let followUpSuggestions = try await generateFollowUpSuggestions(
            question: question,
            answer: ragResponse.answer,
            projectId: projectId
        )
        
        let response = AIQuestionResponse(
            question: question,
            answer: ragResponse.answer,
            confidence: ragResponse.confidence,
            sources: ragResponse.sources.map { source in
                AnalysisSource(
                    id: source.id,
                    type: SourceType(rawValue: source.type.rawValue) ?? .recording,
                    title: source.title,
                    relevanceScore: source.relevanceScore,
                    extractedText: nil,
                    timestamp: Date()
                )
            },
            relatedQuestions: relatedQuestions,
            followUpSuggestions: followUpSuggestions,
            responseTime: ragResponse.responseTime,
            metadata: ResponseMetadata(
                modelUsed: ragResponse.model,
                tokenCount: ragResponse.tokenUsage.totalTokens,
                retrievalMethod: ragResponse.metadata.retrievalMethod.rawValue,
                contextLength: ragResponse.context.totalTokens,
                qualityScore: ragResponse.confidence
            )
        )
        
        // チャット履歴に追加
        addToChatHistory(projectId: projectId, question: question, response: response)
        
        return response
    }
    
    func getChatHistory(
        projectId: UUID,
        limit: Int = 50
    ) async throws -> [ChatMessage] {
        
        let history = chatHistory[projectId] ?? []
        return Array(history.suffix(limit))
    }
    
    func deleteChatHistory(projectId: UUID) async throws {
        chatHistory.removeValue(forKey: projectId)
    }
    
    // MARK: - 統合コンテキスト構築実装
    
    func buildProjectContext(
        projectId: UUID,
        includeTranscriptions: Bool = true,
        includeDocuments: Bool = true,
        timeRange: DateInterval? = nil
    ) async throws -> ProjectContext {
        
        if let cached = contextCache[projectId] {
            // 1時間以内のキャッシュは有効
            if Date().timeIntervalSince(cached.metadata.lastUpdated) < 3600 {
                return cached
            }
        }
        
        // プロジェクト基本情報を取得
        guard let project = try await projectRepository.getProject(id: projectId) else {
            throw ProjectAIError.projectNotFound(projectId)
        }
        
        var totalContent = 0
        var contentBreakdown: [ContentType: Int] = [:]
        var participants: [Participant] = []
        var keyTopics: [Topic] = []
        var recentActivity: [ActivityItem] = []
        
        // 音声文字起こしデータを含める
        if includeTranscriptions {
            let recordings = try await recordingRepository.getRecordings(for: projectId)
            let filteredRecordings = timeRange != nil ? 
                recordings.filter { timeRange!.contains($0.createdAt) } : recordings
            
            totalContent += filteredRecordings.count
            contentBreakdown[.transcription] = filteredRecordings.count
            
            // 参加者情報を抽出
            participants.append(contentsOf: extractParticipants(from: filteredRecordings))
            
            // トピック情報を抽出
            keyTopics.append(contentsOf: try await extractTopics(from: filteredRecordings))
            
            // 最近の活動を追加
            recentActivity.append(contentsOf: filteredRecordings.map { recording in
                ActivityItem(
                    type: .recording,
                    title: recording.title,
                    timestamp: recording.createdAt,
                    importance: .medium,
                    relatedSourceId: recording.id.uuidString
                )
            })
        }
        
        // 文書データを含める（将来実装）
        if includeDocuments {
            // TODO: 文書データの処理を実装
            contentBreakdown[.document] = 0
        }
        
        // 使用する時間範囲を決定
        let effectiveTimeRange = timeRange ?? DateInterval(
            start: project.createdAt,
            end: Date()
        )
        
        let context = ProjectContext(
            projectId: projectId,
            summary: try await generateProjectSummary(
                projectId: projectId,
                contentBreakdown: contentBreakdown
            ),
            totalContent: totalContent,
            contentBreakdown: contentBreakdown,
            timeRange: effectiveTimeRange,
            participants: Array(Set(participants)), // 重複を削除
            keyTopics: keyTopics,
            recentActivity: Array(recentActivity.sorted { $0.timestamp > $1.timestamp }.prefix(20)),
            metadata: ProjectContextMetadata(
                lastUpdated: Date(),
                version: "1.0.0",
                sources: [], // TODO: ソース情報を実装
                completeness: calculateCompleteness(
                    includeTranscriptions: includeTranscriptions,
                    includeDocuments: includeDocuments,
                    totalContent: totalContent
                ),
                accuracy: 0.9 // TODO: 精度計算を実装
            )
        )
        
        // キャッシュに保存
        contextCache[projectId] = context
        
        return context
    }
    
    func getContextSummary(
        projectId: UUID
    ) async throws -> ContextSummary {
        
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: nil
        )
        
        let keyMetrics = try await calculateKeyMetrics(context: context)
        let recentHighlights = extractRecentHighlights(from: context)
        let upcomingItems = try await generateUpcomingItems(context: context)
        let recommendations = try await generateContextRecommendations(context: context)
        
        return ContextSummary(
            projectId: projectId,
            overallSummary: context.summary,
            keyMetrics: keyMetrics,
            recentHighlights: recentHighlights,
            upcomingItems: upcomingItems,
            recommendations: recommendations,
            lastUpdated: Date()
        )
    }
    
    func refreshProjectKnowledgeBase(
        projectId: UUID
    ) async throws -> KnowledgeBase {
        
        return try await ragService.buildKnowledgeBase(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true
        )
    }
    
    // MARK: - 時系列分析実装
    
    func analyzeProjectTimeline(
        projectId: UUID,
        granularity: TimelineGranularity
    ) async throws -> ProjectTimeline {
        
        let recordings = try await recordingRepository.getRecordings(for: projectId)
        let events = try await extractTimelineEvents(from: recordings, granularity: granularity)
        let patterns = try await detectTimelinePatterns(events: events, granularity: granularity)
        let milestones = try await extractMilestones(from: events)
        
        let timeRange = DateInterval(
            start: recordings.map { $0.createdAt }.min() ?? Date(),
            end: recordings.map { $0.createdAt }.max() ?? Date()
        )
        
        return ProjectTimeline(
            projectId: projectId,
            granularity: granularity,
            timeRange: timeRange,
            events: events,
            patterns: patterns,
            milestones: milestones,
            metadata: TimelineMetadata(
                totalEvents: events.count,
                completeness: 0.9,
                accuracy: 0.85,
                lastAnalyzed: Date(),
                analysisVersion: "1.0.0"
            )
        )
    }
    
    func detectProjectTrends(
        projectId: UUID,
        trendType: TrendType
    ) async throws -> [ProjectTrend] {
        
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: nil
        )
        
        return try await analyzeTrends(context: context, trendType: trendType)
    }
    
    func generateProgressReport(
        projectId: UUID,
        reportType: ProgressReportType,
        timeRange: DateInterval
    ) async throws -> ProgressReport {
        
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: timeRange
        )
        
        let achievements = try await extractAchievements(from: context, timeRange: timeRange)
        let challenges = try await identifyChallenges(from: context)
        let metrics = try await calculateProgressMetrics(context: context, timeRange: timeRange)
        let nextSteps = try await generateNextSteps(context: context)
        let recommendations = try await generateProgressRecommendations(context: context)
        
        return ProgressReport(
            id: UUID().uuidString,
            projectId: projectId,
            type: reportType,
            timeRange: timeRange,
            summary: try await generateProgressSummary(context: context, timeRange: timeRange),
            achievements: achievements,
            challenges: challenges,
            metrics: metrics,
            nextSteps: nextSteps,
            recommendations: recommendations,
            generatedAt: Date()
        )
    }
    
    // MARK: - AI駆動の提案実装
    
    func generateActionItems(
        projectId: UUID,
        priority: ActionItemPriority? = nil
    ) async throws -> [ActionItem] {
        
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: nil
        )
        
        return try await extractActionItemsFromContext(context: context, priority: priority)
    }
    
    func suggestNextSteps(
        projectId: UUID,
        context nextStepContext: NextStepContext? = nil
    ) async throws -> [NextStepSuggestion] {
        
        let projectContext = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: nil
        )
        
        return try await generateNextStepSuggestions(
            projectContext: projectContext,
            nextStepContext: nextStepContext
        )
    }
    
    func generateMeetingSummary(
        recordingIds: [UUID],
        summaryType: MeetingSummaryType
    ) async throws -> MeetingSummary {
        
        var recordings: [Recording] = []
        for recordingId in recordingIds {
            if let recording = try await recordingRepository.getRecording(id: recordingId) {
                recordings.append(recording)
            }
        }
        
        return try await createMeetingSummary(recordings: recordings, summaryType: summaryType)
    }
    
    // MARK: - 感情・トーン分析実装
    
    func analyzeSentiment(
        projectId: UUID,
        timeRange: DateInterval? = nil
    ) async throws -> SentimentAnalysis {
        
        let recordings = try await recordingRepository.getRecordings(for: projectId)
        let filteredRecordings = timeRange != nil ?
            recordings.filter { timeRange!.contains($0.createdAt) } : recordings
        
        return try await performSentimentAnalysis(recordings: filteredRecordings, projectId: projectId)
    }
    
    func analyzeEngagement(
        projectId: UUID,
        timeRange: DateInterval? = nil
    ) async throws -> EngagementAnalysis {
        
        let context = try await buildProjectContext(
            projectId: projectId,
            includeTranscriptions: true,
            includeDocuments: true,
            timeRange: timeRange
        )
        
        return try await performEngagementAnalysis(context: context)
    }
    
    func detectMoodChanges(
        projectId: UUID,
        timeRange: DateInterval
    ) async throws -> [MoodChange] {
        
        let recordings = try await recordingRepository.getRecordings(for: projectId)
        let filteredRecordings = recordings.filter { timeRange.contains($0.createdAt) }
        
        return try await detectMoodChangesInRecordings(filteredRecordings)
    }
    
    // MARK: - 内部メソッド
    
    private func performAnalysis(
        projectId: UUID,
        analysisType: ProjectAnalysisType,
        context: ProjectContext
    ) async throws -> ProjectAnalysisResult {
        
        let startTime = Date()
        
        // 分析タイプに応じた処理
        let content = try await generateAnalysisContent(type: analysisType, context: context)
        let sources = extractAnalysisSources(from: context)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return ProjectAnalysisResult(
            projectId: projectId,
            analysisType: analysisType,
            result: content,
            confidence: 0.8, // TODO: 信頼度計算を実装
            sources: sources,
            generatedAt: Date(),
            metadata: AnalysisMetadata(
                processingTime: processingTime,
                tokenCount: estimateTokenCount(content.summary),
                modelUsed: "GPT-4",
                analysisVersion: "1.0.0",
                qualityScore: 0.85
            )
        )
    }
    
    private func generateAnalysisContent(
        type: ProjectAnalysisType,
        context: ProjectContext
    ) async throws -> AnalysisContent {
        
        let prompt = buildAnalysisPrompt(type: type, context: context)
        
        let llmRequest = LLMRequest(
            model: .gpt4,
            messages: [
                LLMMessage(role: "system", content: "あなたはプロジェクト分析の専門家です。"),
                LLMMessage(role: "user", content: prompt)
            ],
            maxTokens: 2000,
            temperature: 0.3,
            systemPrompt: nil
        )
        
        let response = try await llmService.chat(request: llmRequest, provider: .openai)
        
        return AnalysisContent(
            summary: response.content,
            keyPoints: extractKeyPoints(from: response.content),
            details: [:], // TODO: 詳細情報を実装
            visualData: nil, // TODO: 可視化データを実装
            recommendations: extractRecommendations(from: response.content)
        )
    }
    
    private func buildAnalysisPrompt(type: ProjectAnalysisType, context: ProjectContext) -> String {
        let baseContext = """
        プロジェクト情報:
        - プロジェクトID: \(context.projectId)
        - 総コンテンツ数: \(context.totalContent)
        - 期間: \(formatDateInterval(context.timeRange))
        - 参加者数: \(context.participants.count)
        
        主要トピック:
        \(context.keyTopics.map { "- \($0.name) (頻度: \($0.frequency))" }.joined(separator: "\n"))
        
        最近の活動:
        \(context.recentActivity.prefix(5).map { "- \($0.title) (\(formatDate($0.timestamp)))" }.joined(separator: "\n"))
        """
        
        switch type {
        case .summary:
            return """
            \(baseContext)
            
            上記のプロジェクト情報に基づいて、包括的なプロジェクトサマリーを生成してください。
            以下の観点を含めてください：
            - プロジェクトの全体像
            - 主要な成果と進捗
            - 重要な決定事項
            - 今後の方向性
            """
            
        case .keyTopics:
            return """
            \(baseContext)
            
            プロジェクトの主要トピックを分析し、以下を含む詳細な分析を提供してください：
            - トピックの重要度ランキング
            - トピック間の関連性
            - トピックの時系列変化
            - 新興トピックの特定
            """
            
        case .decisions:
            return """
            \(baseContext)
            
            プロジェクトで行われた重要な決定事項を分析してください：
            - 主要な決定の一覧
            - 決定の理由と背景
            - 決定による影響
            - 未解決の課題
            """
            
        default:
            return """
            \(baseContext)
            
            \(type.displayName)の観点からプロジェクトを分析してください。
            """
        }
    }
    
    private func performProjectComparison(
        contexts: [UUID: ProjectContext],
        comparisonType: ProjectComparisonType
    ) async throws -> ProjectComparisonResult {
        
        // 比較ロジックの実装（プレースホルダー）
        let similarities: [ComparisonItem] = []
        let differences: [ComparisonItem] = []
        
        return ProjectComparisonResult(
            projectIds: Array(contexts.keys),
            comparisonType: comparisonType,
            similarities: similarities,
            differences: differences,
            overallScore: 0.7,
            recommendations: [],
            generatedAt: Date()
        )
    }
    
    private func extractInsights(from context: ProjectContext) async throws -> [ProjectInsight] {
        // インサイト抽出ロジック（プレースホルダー）
        return []
    }
    
    private func generateRelatedQuestions(
        originalQuestion: String,
        answer: String,
        context: RAGContext
    ) async throws -> [String] {
        
        let prompt = """
        元の質問: \(originalQuestion)
        回答: \(answer)
        
        この質問と回答に基づいて、ユーザーが興味を持ちそうな関連質問を3つ生成してください。
        """
        
        let llmRequest = LLMRequest(
            model: .gpt35Turbo,
            messages: [LLMMessage(role: "user", content: prompt)],
            maxTokens: 300,
            temperature: 0.7,
            systemPrompt: nil
        )
        
        let response = try await llmService.chat(request: llmRequest, provider: .openai)
        
        return response.content.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(3)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private func generateFollowUpSuggestions(
        question: String,
        answer: String,
        projectId: UUID
    ) async throws -> [String] {
        
        return [
            "より詳細な情報を確認する",
            "関連するドキュメントを表示する",
            "この内容を他のプロジェクトと比較する"
        ]
    }
    
    private func addToChatHistory(
        projectId: UUID,
        question: String,
        response: AIQuestionResponse
    ) {
        var history = chatHistory[projectId] ?? []
        
        // 質問を追加
        let questionMessage = ChatMessage(
            id: UUID().uuidString,
            projectId: projectId,
            type: .question,
            content: question,
            timestamp: Date(),
            metadata: nil
        )
        history.append(questionMessage)
        
        // 回答を追加
        let answerMessage = ChatMessage(
            id: UUID().uuidString,
            projectId: projectId,
            type: .answer,
            content: response.answer,
            timestamp: Date(),
            metadata: MessageMetadata(
                sources: response.sources,
                confidence: response.confidence,
                processingTime: response.responseTime,
                feedback: nil
            )
        )
        history.append(answerMessage)
        
        // 最新100件のみ保持
        if history.count > 100 {
            history = Array(history.suffix(100))
        }
        
        chatHistory[projectId] = history
    }
    
    // MARK: - ヘルパーメソッド
    
    private func extractParticipants(from recordings: [Recording]) -> [Participant] {
        // 参加者抽出ロジック（プレースホルダー）
        return []
    }
    
    private func extractTopics(from recordings: [Recording]) async throws -> [Topic] {
        // トピック抽出ロジック（プレースホルダー）
        return []
    }
    
    private func generateProjectSummary(
        projectId: UUID,
        contentBreakdown: [ContentType: Int]
    ) async throws -> String {
        
        let totalContent = contentBreakdown.values.reduce(0, +)
        
        return """
        このプロジェクトには\(totalContent)件のコンテンツが含まれています。
        内訳: 音声録音\(contentBreakdown[.transcription] ?? 0)件、文書\(contentBreakdown[.document] ?? 0)件
        """
    }
    
    private func calculateCompleteness(
        includeTranscriptions: Bool,
        includeDocuments: Bool,
        totalContent: Int
    ) -> Double {
        var completeness = 0.0
        
        if includeTranscriptions { completeness += 0.6 }
        if includeDocuments { completeness += 0.4 }
        
        // コンテンツ量に応じた調整
        if totalContent > 10 { completeness *= 1.0 }
        else if totalContent > 5 { completeness *= 0.8 }
        else { completeness *= 0.6 }
        
        return min(completeness, 1.0)
    }
    
    private func calculateKeyMetrics(context: ProjectContext) async throws -> [Metric] {
        return [
            Metric(
                name: "総活動数",
                value: Double(context.totalContent),
                unit: "件",
                trend: .stable,
                benchmark: nil
            ),
            Metric(
                name: "参加者数",
                value: Double(context.participants.count),
                unit: "人",
                trend: .stable,
                benchmark: nil
            )
        ]
    }
    
    private func extractRecentHighlights(from context: ProjectContext) -> [String] {
        return context.recentActivity.prefix(3).map { $0.title }
    }
    
    private func generateUpcomingItems(context: ProjectContext) async throws -> [String] {
        return ["今後のタスクを分析中..."]
    }
    
    private func generateContextRecommendations(context: ProjectContext) async throws -> [String] {
        return ["定期的な進捗確認を推奨します"]
    }
    
    private func extractTimelineEvents(
        from recordings: [Recording],
        granularity: TimelineGranularity
    ) async throws -> [TimelineEvent] {
        
        return recordings.map { recording in
            TimelineEvent(
                id: recording.id.uuidString,
                timestamp: recording.createdAt,
                type: .meeting,
                title: recording.title,
                description: nil,
                importance: .medium,
                participants: [],
                relatedSources: [recording.id.uuidString]
            )
        }
    }
    
    private func detectTimelinePatterns(
        events: [TimelineEvent],
        granularity: TimelineGranularity
    ) async throws -> [TimelinePattern] {
        // パターン検出ロジック（プレースホルダー）
        return []
    }
    
    private func extractMilestones(from events: [TimelineEvent]) async throws -> [Milestone] {
        // マイルストーン抽出ロジック（プレースホルダー）
        return []
    }
    
    private func analyzeTrends(
        context: ProjectContext,
        trendType: TrendType
    ) async throws -> [ProjectTrend] {
        // トレンド分析ロジック（プレースホルダー）
        return []
    }
    
    private func extractAchievements(
        from context: ProjectContext,
        timeRange: DateInterval
    ) async throws -> [Achievement] {
        // 成果抽出ロジック（プレースホルダー）
        return []
    }
    
    private func identifyChallenges(from context: ProjectContext) async throws -> [Challenge] {
        // 課題特定ロジック（プレースホルダー）
        return []
    }
    
    private func calculateProgressMetrics(
        context: ProjectContext,
        timeRange: DateInterval
    ) async throws -> [ProgressMetric] {
        // 進捗メトリクス計算ロジック（プレースホルダー）
        return []
    }
    
    private func generateNextSteps(context: ProjectContext) async throws -> [NextStep] {
        // 次のステップ生成ロジック（プレースホルダー）
        return []
    }
    
    private func generateProgressRecommendations(context: ProjectContext) async throws -> [String] {
        // 進捗推奨事項生成ロジック（プレースホルダー）
        return []
    }
    
    private func generateProgressSummary(
        context: ProjectContext,
        timeRange: DateInterval
    ) async throws -> String {
        // 進捗サマリー生成ロジック（プレースホルダー）
        return "進捗サマリーを生成中..."
    }
    
    private func extractActionItemsFromContext(
        context: ProjectContext,
        priority: ActionItemPriority?
    ) async throws -> [ActionItem] {
        // アクションアイテム抽出ロジック（プレースホルダー）
        return []
    }
    
    private func generateNextStepSuggestions(
        projectContext: ProjectContext,
        nextStepContext: NextStepContext?
    ) async throws -> [NextStepSuggestion] {
        // 次ステップ提案生成ロジック（プレースホルダー）
        return []
    }
    
    private func createMeetingSummary(
        recordings: [Recording],
        summaryType: MeetingSummaryType
    ) async throws -> MeetingSummary {
        // ミーティングサマリー作成ロジック（プレースホルダー）
        return MeetingSummary(
            id: UUID().uuidString,
            title: "ミーティングサマリー",
            type: summaryType,
            recordingIds: recordings.map { $0.id },
            participants: [],
            duration: recordings.map { $0.duration }.reduce(0, +),
            summary: "サマリーを生成中...",
            keyPoints: [],
            decisions: [],
            actionItems: [],
            nextMeeting: nil,
            metadata: MeetingMetadata(
                generatedAt: Date(),
                analysisVersion: "1.0.0",
                qualityScore: 0.8,
                completeness: 0.9,
                extractionAccuracy: 0.85
            )
        )
    }
    
    private func performSentimentAnalysis(
        recordings: [Recording],
        projectId: UUID
    ) async throws -> SentimentAnalysis {
        // 感情分析ロジック（プレースホルダー）
        return SentimentAnalysis(
            projectId: projectId,
            timeRange: DateInterval(start: Date().addingTimeInterval(-86400 * 30), end: Date()),
            overallSentiment: SentimentScore(score: 0.1, label: .positive, confidence: 0.8),
            sentimentTrend: [],
            topicSentiments: [],
            participantSentiments: [],
            insights: [],
            metadata: SentimentMetadata(
                model: "sentiment-analysis-v1",
                accuracy: 0.85,
                coverage: 0.9,
                lastAnalyzed: Date()
            )
        )
    }
    
    private func performEngagementAnalysis(context: ProjectContext) async throws -> EngagementAnalysis {
        // エンゲージメント分析ロジック（プレースホルダー）
        return EngagementAnalysis(
            projectId: context.projectId,
            timeRange: context.timeRange,
            overallEngagement: EngagementScore(score: 0.7, level: .high, confidence: 0.8),
            engagementTrend: [],
            participantEngagement: [],
            engagementFactors: [],
            recommendations: []
        )
    }
    
    private func detectMoodChangesInRecordings(_ recordings: [Recording]) async throws -> [MoodChange] {
        // 気分変化検出ロジック（プレースホルダー）
        return []
    }
    
    private func extractAnalysisSources(from context: ProjectContext) -> [AnalysisSource] {
        return context.recentActivity.map { activity in
            AnalysisSource(
                id: activity.relatedSourceId,
                type: activity.type == .recording ? .recording : .document,
                title: activity.title,
                relevanceScore: 0.8,
                extractedText: nil,
                timestamp: activity.timestamp
            )
        }
    }
    
    private func extractKeyPoints(from content: String) -> [String] {
        // キーポイント抽出の簡単な実装
        return content.components(separatedBy: "\n")
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("• ") }
            .map { String($0.dropFirst(2)) }
            .prefix(5)
            .map { String($0) }
    }
    
    private func extractRecommendations(from content: String) -> [String] {
        // 推奨事項抽出の簡単な実装
        let lines = content.components(separatedBy: "\n")
        var recommendations: [String] = []
        
        var inRecommendationSection = false
        for line in lines {
            if line.lowercased().contains("推奨") || line.lowercased().contains("提案") {
                inRecommendationSection = true
                continue
            }
            
            if inRecommendationSection && (line.hasPrefix("- ") || line.hasPrefix("• ")) {
                recommendations.append(String(line.dropFirst(2)))
            }
        }
        
        return Array(recommendations.prefix(3))
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // 簡単なトークン数推定
        return text.split(separator: " ").count
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateInterval(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: interval.end))"
    }
}

// MARK: - エラー定義

enum ProjectAIError: Error, LocalizedError {
    case projectNotFound(UUID)
    case insufficientData(String)
    case analysisError(String)
    case contextBuildingError(String)
    
    var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .insufficientData(let message):
            return "Insufficient data for analysis: \(message)"
        case .analysisError(let message):
            return "Analysis error: \(message)"
        case .contextBuildingError(let message):
            return "Context building error: \(message)"
        }
    }
}