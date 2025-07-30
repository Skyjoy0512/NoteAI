import Foundation

// MARK: - プロジェクト分析サービス（ProjectAIUseCaseから分離）

@MainActor
class ProjectAnalysisService {
    
    // MARK: - 依存関係
    private let ragService: RAGServiceProtocol
    private let llmService: LLMServiceProtocol
    private let cache: [String: Any] = [:]
    private let logger = RAGLogger.shared
    
    init(ragService: RAGServiceProtocol, llmService: LLMServiceProtocol) {
        self.ragService = ragService
        self.llmService = llmService
    }
    
    // MARK: - 分析実行
    
    func performAnalysis(
        projectId: UUID,
        analysisType: ProjectAnalysisType,
        context: ProjectContext
    ) async throws -> ProjectAnalysisResult {
        
        logger.log(level: .info, message: "Starting project analysis", context: [
            "projectId": projectId.uuidString,
            "analysisType": analysisType.rawValue
        ])
        
        let startTime = Date()
        
        do {
            let content = try await generateAnalysisContent(
                type: analysisType,
                context: context
            )
            
            let sources = extractAnalysisSources(from: context)
            let processingTime = Date().timeIntervalSince(startTime)
            
            let result = ProjectAnalysisResult(
                projectId: projectId,
                analysisType: analysisType,
                result: content,
                confidence: calculateAnalysisConfidence(type: analysisType, context: context),
                sources: sources,
                generatedAt: Date(),
                metadata: AnalysisMetadata(
                    processingTime: processingTime,
                    tokenCount: estimateTokenCount(content.summary),
                    modelUsed: "GPT-4",
                    analysisVersion: "1.0.0",
                    qualityScore: calculateQualityScore(content, sources: sources)
                )
            )
            
            logger.log(level: .info, message: "Project analysis completed", context: [
                "duration": processingTime.formattedDuration,
                "confidence": result.confidence
            ])
            
            return result
            
        } catch {
            logger.log(level: .error, message: "Project analysis failed", context: [
                "error": error.localizedDescription
            ])
            throw ProjectAIError.analysisError(error.localizedDescription)
        }
    }
    
    // MARK: - プロジェクト比較
    
    func compareProjects(
        contexts: [UUID: ProjectContext],
        comparisonType: ProjectComparisonType
    ) async throws -> ProjectComparisonResult {
        
        logger.log(level: .info, message: "Starting project comparison", context: [
            "projectCount": contexts.count,
            "comparisonType": comparisonType.rawValue
        ])
        
        let startTime = Date()
        
        do {
            let comparison = try await performProjectComparison(
                contexts: contexts,
                comparisonType: comparisonType
            )
            
            logger.log(level: .info, message: "Project comparison completed", context: [
                "duration": Date().timeIntervalSince(startTime).formattedDuration
            ])
            
            return comparison
            
        } catch {
            logger.log(level: .error, message: "Project comparison failed", context: [
                "error": error.localizedDescription
            ])
            throw ProjectAIError.analysisError(error.localizedDescription)
        }
    }
    
    // MARK: - インサイト生成
    
    func generateInsights(from context: ProjectContext) async throws -> [ProjectInsight] {
        logger.log(level: .info, message: "Generating project insights")
        
        var insights: [ProjectInsight] = []
        
        // トレンドインサイト
        insights.append(contentsOf: try await generateTrendInsights(context: context))
        
        // 異常値インサイト
        insights.append(contentsOf: try await generateAnomalyInsights(context: context))
        
        // 機会インサイト
        insights.append(contentsOf: try await generateOpportunityInsights(context: context))
        
        // リスクインサイト
        insights.append(contentsOf: try await generateRiskInsights(context: context))
        
        // 成果インサイト
        insights.append(contentsOf: try await generateAchievementInsights(context: context))
        
        // 推奨事項インサイト
        insights.append(contentsOf: try await generateRecommendationInsights(context: context))
        
        logger.log(level: .info, message: "Generated insights", context: [
            "insightsCount": insights.count
        ])
        
        return insights.sorted { $0.importance.priority > $1.importance.priority }
    }
    
    // MARK: - 内部メソッド
    
    private func generateAnalysisContent(
        type: ProjectAnalysisType,
        context: ProjectContext
    ) async throws -> AnalysisContent {
        
        let prompt = AnalysisPromptBuilder.buildPrompt(type: type, context: context)
        
        let llmRequest = LLMRequest(
            model: .gpt4o,
            messages: [
                LLMMessage(role: "system", content: "あなたはプロジェクト分析の専門家です。データに基づいて客観的で実用的な分析を提供してください。"),
                LLMMessage(role: "user", content: prompt)
            ],
            maxTokens: 2000,
            temperature: 0.3,
            systemPrompt: nil
        )
        
        let response = try await llmService.sendMessage(request: llmRequest)
        
        return AnalysisContentParser.parse(
            response: response.content,
            analysisType: type
        )
    }
    
    private func performProjectComparison(
        contexts: [UUID: ProjectContext],
        comparisonType: ProjectComparisonType
    ) async throws -> ProjectComparisonResult {
        
        let comparator = ProjectComparator(type: comparisonType)
        return try await comparator.compare(contexts: contexts)
    }
    
    private func generateTrendInsights(context: ProjectContext) async throws -> [ProjectInsight] {
        var insights: [ProjectInsight] = []
        
        // 活動量のトレンド分析
        if let activityTrend = analyzeActivityTrend(context: context) {
            insights.append(activityTrend)
        }
        
        // 参加者エンゲージメントのトレンド
        if let engagementTrend = analyzeEngagementTrend(context: context) {
            insights.append(engagementTrend)
        }
        
        return insights
    }
    
    private func generateAnomalyInsights(context: ProjectContext) async throws -> [ProjectInsight] {
        var insights: [ProjectInsight] = []
        
        // 活動の異常値検出
        if let activityAnomaly = detectActivityAnomalies(context: context) {
            insights.append(activityAnomaly)
        }
        
        return insights
    }
    
    private func generateOpportunityInsights(context: ProjectContext) async throws -> [ProjectInsight] {
        var insights: [ProjectInsight] = []
        
        // 未活用のリソース発見
        if let resourceOpportunity = identifyResourceOpportunities(context: context) {
            insights.append(resourceOpportunity)
        }
        
        return insights
    }
    
    private func generateRiskInsights(context: ProjectContext) async throws -> [ProjectInsight] {
        var insights: [ProjectInsight] = []
        
        // コミュニケーションリスク
        if let communicationRisk = assessCommunicationRisks(context: context) {
            insights.append(communicationRisk)
        }
        
        return insights
    }
    
    private func generateAchievementInsights(context: ProjectContext) async throws -> [ProjectInsight] {
        var insights: [ProjectInsight] = []
        
        // マイルストーン達成
        if let milestoneAchievement = identifyMilestoneAchievements(context: context) {
            insights.append(milestoneAchievement)
        }
        
        return insights
    }
    
    private func generateRecommendationInsights(context: ProjectContext) async throws -> [ProjectInsight] {
        var insights: [ProjectInsight] = []
        
        // プロセス改善提案
        if let processRecommendation = generateProcessRecommendations(context: context) {
            insights.append(processRecommendation)
        }
        
        return insights
    }
    
    // MARK: - 具体的な分析メソッド
    
    private func analyzeActivityTrend(context: ProjectContext) -> ProjectInsight? {
        guard context.recentActivity.count >= 3 else { return nil }
        
        let recentActivities = context.recentActivity.sorted { $0.timestamp > $1.timestamp }
        let weeklyActivity = groupActivitiesByWeek(recentActivities)
        
        if weeklyActivity.count >= 3 {
            let trend = calculateTrendDirection(weeklyActivity)
            
            return ProjectInsight(
                id: UUID().uuidString,
                type: InsightType.trend,
                title: "活動量トレンド",
                description: "過去数週間の活動量が\(trend.description)しています",
                importance: trend == .increasing ? InsightImportance.medium : InsightImportance.high,
                actionable: true,
                relatedSources: [],
                generatedAt: Date(),
                expiresAt: Date().addingTimeInterval(86400 * 7) // 1週間で期限切れ
            )
        }
        
        return nil
    }
    
    private func analyzeEngagementTrend(context: ProjectContext) -> ProjectInsight? {
        guard context.participants.count >= 2 else { return nil }
        
        let avgEngagement = context.participants.map { $0.engagementScore }.reduce(0, +) / Double(context.participants.count)
        
        if avgEngagement < 0.3 {
            return ProjectInsight(
                id: UUID().uuidString,
                type: InsightType.risk,
                title: "エンゲージメント低下",
                description: "参加者のエンゲージメントが低下しています。アクティビティの見直しを検討してください。",
                importance: InsightImportance.high,
                actionable: true,
                relatedSources: [],
                generatedAt: Date(),
                expiresAt: Date().addingTimeInterval(86400 * 3) // 3日で期限切れ
            )
        }
        
        return nil
    }
    
    private func detectActivityAnomalies(context: ProjectContext) -> ProjectInsight? {
        // 異常値検出の実装
        return nil
    }
    
    private func identifyResourceOpportunities(context: ProjectContext) -> ProjectInsight? {
        // リソース機会の実装
        return nil
    }
    
    private func assessCommunicationRisks(context: ProjectContext) -> ProjectInsight? {
        // コミュニケーションリスクの実装
        return nil
    }
    
    private func identifyMilestoneAchievements(context: ProjectContext) -> ProjectInsight? {
        // マイルストーン達成の実装
        return nil
    }
    
    private func generateProcessRecommendations(context: ProjectContext) -> ProjectInsight? {
        // プロセス推奨事項の実装
        return nil
    }
    
    // MARK: - ヘルパーメソッド
    
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
    
    private func calculateAnalysisConfidence(
        type: ProjectAnalysisType,
        context: ProjectContext
    ) -> Double {
        let dataCompleteness = context.metadata.completeness
        let dataQuality = context.metadata.accuracy
        let contentAmount = min(Double(context.totalContent) / 20.0, 1.0) // 20件を十分な量とする
        
        return (dataCompleteness * 0.4) + (dataQuality * 0.3) + (contentAmount * 0.3)
    }
    
    private func calculateQualityScore(
        _ content: AnalysisContent,
        sources: [AnalysisSource]
    ) -> Double {
        let contentQuality = min(Double(content.keyPoints.count) / 5.0, 1.0) // 5つのキーポイントを理想とする
        let sourceQuality = min(Double(sources.count) / 10.0, 1.0) // 10のソースを理想とする
        let recommendationQuality = min(Double(content.recommendations.count) / 3.0, 1.0) // 3つの推奨事項を理想とする
        
        return (contentQuality * 0.4) + (sourceQuality * 0.3) + (recommendationQuality * 0.3)
    }
    
    private func groupActivitiesByWeek(_ activities: [ActivityItem]) -> [Int] {
        // 週ごとの活動数を計算
        let calendar = Calendar.current
        var weeklyCount: [Int: Int] = [:]
        
        for activity in activities {
            let weekOfYear = calendar.component(.weekOfYear, from: activity.timestamp)
            weeklyCount[weekOfYear, default: 0] += 1
        }
        
        return Array(weeklyCount.values)
    }
    
    private func calculateTrendDirection(_ values: [Int]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let recent = values.suffix(3)
        let sum = recent.reduce(0, +)
        let avg = Double(sum) / Double(recent.count)
        
        let lastValue = Double(values.last ?? 0)
        
        if lastValue > avg * 1.2 {
            return .increasing
        } else if lastValue < avg * 0.8 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        return text.split(separator: " ").count
    }
}

// MARK: - 分析プロンプトビルダー

struct AnalysisPromptBuilder {
    static func buildPrompt(type: ProjectAnalysisType, context: ProjectContext) -> String {
        let baseContext = buildBaseContext(context)
        
        switch type {
        case .summary:
            return buildSummaryPrompt(baseContext: baseContext, context: context)
        case .keyTopics:
            return buildKeyTopicsPrompt(baseContext: baseContext, context: context)
        case .decisions:
            return buildDecisionsPrompt(baseContext: baseContext, context: context)
        case .actionItems:
            return buildActionItemsPrompt(baseContext: baseContext, context: context)
        case .participants:
            return buildParticipantsPrompt(baseContext: baseContext, context: context)
        case .timeline:
            return buildTimelinePrompt(baseContext: baseContext, context: context)
        case .sentiment:
            return buildSentimentPrompt(baseContext: baseContext, context: context)
        case .productivity:
            return buildProductivityPrompt(baseContext: baseContext, context: context)
        }
    }
    
    private static func buildBaseContext(_ context: ProjectContext) -> String {
        return """
        プロジェクト基本情報:
        - プロジェクトID: \(context.projectId)
        - 総コンテンツ数: \(context.totalContent)
        - 期間: \(formatDateInterval(context.timeRange))
        - 参加者数: \(context.participants.count)
        - データ完全性: \(Int(context.metadata.completeness * 100))%
        
        主要トピック:
        \(context.keyTopics.prefix(5).map { "- \($0.name) (頻度: \($0.frequency), 重要度: \(String(format: "%.1f", $0.importance)))" }.joined(separator: "\n"))
        
        最近の活動:
        \(context.recentActivity.prefix(10).map { "- \($0.title) (\(formatDate($0.timestamp)), 重要度: \($0.importance.rawValue))" }.joined(separator: "\n"))
        
        参加者情報:
        \(context.participants.prefix(5).map { "- \($0.name): \($0.contributionCount)件の貢献, エンゲージメント: \(String(format: "%.1f", $0.engagementScore))" }.joined(separator: "\n"))
        """
    }
    
    private static func buildSummaryPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        上記のプロジェクト情報に基づいて、包括的なプロジェクトサマリーを日本語で生成してください。
        
        以下の観点を含めてください：
        1. プロジェクトの全体像と現状
        2. 主要な成果と進捗状況
        3. 重要な決定事項と方向性
        4. 参加者の貢献と役割
        5. 今後の課題と機会
        
        回答は以下の形式で提供してください：
        # 概要
        [全体的な要約]
        
        # 主要ポイント
        - [ポイント1]
        - [ポイント2]
        - [ポイント3]
        
        # 推奨事項
        - [推奨1]
        - [推奨2]
        """
    }
    
    private static func buildKeyTopicsPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクトの主要トピックを分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. トピックの重要度ランキング（理由付き）
        2. トピック間の関連性と依存関係
        3. トピックの時系列変化とトレンド
        4. 新興トピックと衰退トピックの特定
        5. 未カバー領域や注目すべき空白の特定
        
        各トピックについて、具体的な根拠と改善提案を含めてください。
        """
    }
    
    private static func buildDecisionsPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクトで行われた重要な決定事項を分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. 主要な決定の一覧と時系列
        2. 各決定の理由と背景情報
        3. 決定による影響と結果の評価
        4. 未解決の課題と今後の決定事項
        5. 意思決定プロセスの改善提案
        """
    }
    
    private static func buildActionItemsPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクトのアクションアイテムを分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. 現在のアクションアイテムの一覧
        2. アイテムの優先度と締切の評価
        3. 進捗状況と完了率の分析
        4. 新たに必要なアクションアイテムの提案
        5. 実行可能性の向上のための提案
        """
    }
    
    private static func buildParticipantsPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクト参加者の活動を分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. 参加者別の貢献度と活動量
        2. エンゲージメントレベルの評価
        3. 役割分担と責任の明確性
        4. コミュニケーションパターンの分析
        5. チーム効率性向上のための提案
        """
    }
    
    private static func buildTimelinePrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクトのタイムラインを分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. 主要なマイルストーンと達成時期
        2. 活動量の時系列変化とパターン
        3. 進捗の遅れや加速の要因分析
        4. 今後のスケジュール予測
        5. タイムライン最適化のための提案
        """
    }
    
    private static func buildSentimentPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクトの感情やトーンを分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. 全体的な感情の傾向とトーンの評価
        2. 時系列での感情変化のパターン
        3. ポジティブ・ネガティブ要因の特定
        4. 参加者間の感情的な相互作用
        5. チームの士気向上のための提案
        """
    }
    
    private static func buildProductivityPrompt(baseContext: String, context: ProjectContext) -> String {
        return """
        \(baseContext)
        
        プロジェクトの生産性を分析し、以下を含む詳細な分析を日本語で提供してください：
        
        1. 生産性指標の現状評価
        2. 効率的な作業パターンの特定
        3. ボトルネックや阻害要因の分析
        4. リソース配分の最適化提案
        5. 生産性向上のための具体的なアクション
        """
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private static func formatDateInterval(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: interval.end))"
    }
}

// MARK: - 分析コンテンツパーサー

struct AnalysisContentParser {
    static func parse(response: String, analysisType: ProjectAnalysisType) -> AnalysisContent {
        let keyPoints = extractKeyPoints(from: response)
        let recommendations = extractRecommendations(from: response)
        let summary = extractSummary(from: response)
        
        return AnalysisContent(
            summary: summary,
            keyPoints: keyPoints,
            details: [:], // TODO: 詳細情報の抽出を実装
            visualData: nil, // TODO: 可視化データの生成を実装
            recommendations: recommendations
        )
    }
    
    private static func extractSummary(from response: String) -> String {
        let lines = response.components(separatedBy: "\n")
        
        // "# 概要" セクションを探す
        if let overviewIndex = lines.firstIndex(where: { $0.hasPrefix("# 概要") }) {
            let summaryLines = lines.dropFirst(overviewIndex + 1)
                .prefix(while: { !$0.hasPrefix("#") && !$0.isEmpty })
            return summaryLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // セクションが見つからない場合は最初の段落を使用
        return lines.prefix(while: { !$0.isEmpty }).joined(separator: "\n")
    }
    
    private static func extractKeyPoints(from response: String) -> [String] {
        let lines = response.components(separatedBy: "\n")
        var keyPoints: [String] = []
        var inKeyPointsSection = false
        
        for line in lines {
            if line.hasPrefix("# 主要ポイント") || line.contains("主要ポイント") {
                inKeyPointsSection = true
                continue
            }
            
            if inKeyPointsSection {
                if line.hasPrefix("#") && !line.contains("主要ポイント") {
                    break
                }
                
                if line.hasPrefix("- ") || line.hasPrefix("• ") {
                    let point = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !point.isEmpty {
                        keyPoints.append(point)
                    }
                }
            }
        }
        
        // セクションが見つからない場合は、箇条書きのすべてを抽出
        if keyPoints.isEmpty {
            keyPoints = lines.compactMap { line in
                if line.hasPrefix("- ") || line.hasPrefix("• ") {
                    return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
        }
        
        return Array(keyPoints.prefix(10)) // 最大10個まで
    }
    
    private static func extractRecommendations(from response: String) -> [String] {
        let lines = response.components(separatedBy: "\n")
        var recommendations: [String] = []
        var inRecommendationsSection = false
        
        for line in lines {
            if line.hasPrefix("# 推奨事項") || line.contains("推奨") || line.contains("提案") {
                inRecommendationsSection = true
                continue
            }
            
            if inRecommendationsSection {
                if line.hasPrefix("#") && !line.contains("推奨") {
                    break
                }
                
                if line.hasPrefix("- ") || line.hasPrefix("• ") {
                    let recommendation = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !recommendation.isEmpty {
                        recommendations.append(recommendation)
                    }
                }
            }
        }
        
        return Array(recommendations.prefix(5)) // 最大5個まで
    }
}

// MARK: - プロジェクト比較器

struct ProjectComparator {
    let type: ProjectComparisonType
    
    func compare(contexts: [UUID: ProjectContext]) async throws -> ProjectComparisonResult {
        let projectIds = Array(contexts.keys)
        
        switch type {
        case .topics:
            return try await compareTopics(contexts: contexts, projectIds: projectIds)
        case .progress:
            return try await compareProgress(contexts: contexts, projectIds: projectIds)
        case .sentiment:
            return try await compareSentiment(contexts: contexts, projectIds: projectIds)
        case .productivity:
            return try await compareProductivity(contexts: contexts, projectIds: projectIds)
        case .participants:
            return try await compareParticipants(contexts: contexts, projectIds: projectIds)
        case .outcomes:
            return try await compareOutcomes(contexts: contexts, projectIds: projectIds)
        }
    }
    
    private func compareTopics(
        contexts: [UUID: ProjectContext],
        projectIds: [UUID]
    ) async throws -> ProjectComparisonResult {
        // トピック比較の実装
        return ProjectComparisonResult(
            projectIds: projectIds,
            comparisonType: type,
            similarities: [],
            differences: [],
            overallScore: 0.7,
            recommendations: [],
            generatedAt: Date()
        )
    }
    
    // 他の比較メソッドも同様に実装...
    
    private func compareProgress(contexts: [UUID: ProjectContext], projectIds: [UUID]) async throws -> ProjectComparisonResult {
        fatalError("Not implemented")
    }
    
    private func compareSentiment(contexts: [UUID: ProjectContext], projectIds: [UUID]) async throws -> ProjectComparisonResult {
        fatalError("Not implemented")
    }
    
    private func compareProductivity(contexts: [UUID: ProjectContext], projectIds: [UUID]) async throws -> ProjectComparisonResult {
        fatalError("Not implemented")
    }
    
    private func compareParticipants(contexts: [UUID: ProjectContext], projectIds: [UUID]) async throws -> ProjectComparisonResult {
        fatalError("Not implemented")
    }
    
    private func compareOutcomes(contexts: [UUID: ProjectContext], projectIds: [UUID]) async throws -> ProjectComparisonResult {
        fatalError("Not implemented")
    }
}

// MARK: - トレンド方向の拡張

extension TrendDirection: CustomStringConvertible {
    var description: String {
        switch self {
        case .upward: return "増加"
        case .downward: return "減少"
        case .stable: return "安定"
        case .volatile: return "変動"
        case .increasing: return "増加傾向"
        case .decreasing: return "減少傾向"
        }
    }
}