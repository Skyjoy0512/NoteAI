import Foundation

// MARK: - プロジェクトAI機能ユースケースプロトコル

protocol ProjectAIUseCaseProtocol {
    
    // MARK: - プロジェクト横断分析
    func analyzeProject(
        projectId: UUID,
        analysisType: ProjectAnalysisType
    ) async throws -> ProjectAnalysisResult
    
    func compareProjects(
        projectIds: [UUID],
        comparisonType: ProjectComparisonType
    ) async throws -> ProjectComparisonResult
    
    func generateProjectInsights(
        projectId: UUID,
        timeRange: DateInterval?
    ) async throws -> [ProjectInsight]
    
    // MARK: - 質問応答システム
    func askQuestion(
        projectId: UUID,
        question: String,
        context: AIQuestionContext?
    ) async throws -> AIQuestionResponse
    
    func getChatHistory(
        projectId: UUID,
        limit: Int
    ) async throws -> [ChatMessage]
    
    func deleteChatHistory(projectId: UUID) async throws
    
    // MARK: - 統合コンテキスト構築
    func buildProjectContext(
        projectId: UUID,
        includeTranscriptions: Bool,
        includeDocuments: Bool,
        timeRange: DateInterval?
    ) async throws -> ProjectContext
    
    func getContextSummary(
        projectId: UUID
    ) async throws -> ContextSummary
    
    func refreshProjectKnowledgeBase(
        projectId: UUID
    ) async throws -> KnowledgeBase
    
    // MARK: - 時系列分析
    func analyzeProjectTimeline(
        projectId: UUID,
        granularity: TimelineGranularity
    ) async throws -> ProjectTimeline
    
    func detectProjectTrends(
        projectId: UUID,
        trendType: TrendType
    ) async throws -> [ProjectTrend]
    
    func generateProgressReport(
        projectId: UUID,
        reportType: ProgressReportType,
        timeRange: DateInterval
    ) async throws -> ProgressReport
    
    // MARK: - AI駆動の提案
    func generateActionItems(
        projectId: UUID,
        priority: ActionItemPriority?
    ) async throws -> [ActionItem]
    
    func suggestNextSteps(
        projectId: UUID,
        context: NextStepContext?
    ) async throws -> [NextStepSuggestion]
    
    func generateMeetingSummary(
        recordingIds: [UUID],
        summaryType: MeetingSummaryType
    ) async throws -> MeetingSummary
    
    // MARK: - 感情・トーン分析
    func analyzeSentiment(
        projectId: UUID,
        timeRange: DateInterval?
    ) async throws -> SentimentAnalysis
    
    func analyzeEngagement(
        projectId: UUID,
        timeRange: DateInterval?
    ) async throws -> EngagementAnalysis
    
    func detectMoodChanges(
        projectId: UUID,
        timeRange: DateInterval
    ) async throws -> [MoodChange]
    
    // MARK: - 高度な分析機能
    
    /// 予測分析を実行
    func generatePredictiveAnalysis(
        projectId: UUID,
        predictionType: PredictionType,
        timeHorizon: TimeInterval,
        confidence: Double
    ) async throws -> PredictiveAnalysisResult
    
    /// 異常検知を実行
    func detectAnomalies(
        projectId: UUID,
        detectionType: AnomalyDetectionType,
        sensitivity: AnomalySensitivity,
        timeRange: DateInterval?
    ) async throws -> AnomalyDetectionResult
    
    /// 相関分析を実行
    func analyzeCorrelations(
        projectId: UUID,
        variables: [AnalysisVariable],
        correlationType: CorrelationType,
        timeRange: DateInterval?
    ) async throws -> CorrelationAnalysisResult
    
    /// クラスタリング分析を実行
    func performClusteringAnalysis(
        projectId: UUID,
        clusteringType: ClusteringType,
        targetClusters: Int?,
        features: [ClusteringFeature]
    ) async throws -> ClusteringAnalysisResult
    
    /// 影響度分析を実行
    func analyzeImpact(
        projectId: UUID,
        changeScenario: ChangeScenario,
        impactScope: ImpactScope
    ) async throws -> ImpactAnalysisResult
}

// MARK: - データ構造

enum ProjectAnalysisType: String, CaseIterable, Codable {
    case summary = "summary"
    case keyTopics = "key_topics"
    case decisions = "decisions"
    case actionItems = "action_items"
    case participants = "participants"
    case timeline = "timeline"
    case sentiment = "sentiment"
    case productivity = "productivity"
    
    var displayName: String {
        switch self {
        case .summary: return "プロジェクト要約"
        case .keyTopics: return "主要トピック"
        case .decisions: return "決定事項"
        case .actionItems: return "アクションアイテム"
        case .participants: return "参加者分析"
        case .timeline: return "タイムライン分析"
        case .sentiment: return "感情分析"
        case .productivity: return "生産性分析"
        }
    }
    
    var iconName: String {
        switch self {
        case .summary: return "doc.text"
        case .keyTopics: return "tag"
        case .decisions: return "checkmark.circle"
        case .actionItems: return "list.bullet"
        case .participants: return "person.2"
        case .timeline: return "clock"
        case .sentiment: return "heart"
        case .productivity: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum ProjectComparisonType: String, CaseIterable {
    case topics = "topics"
    case progress = "progress"
    case sentiment = "sentiment"
    case productivity = "productivity"
    case participants = "participants"
    case outcomes = "outcomes"
    
    var displayName: String {
        switch self {
        case .topics: return "トピック比較"
        case .progress: return "進捗比較"
        case .sentiment: return "感情比較"
        case .productivity: return "生産性比較"
        case .participants: return "参加者比較"
        case .outcomes: return "成果比較"
        }
    }
}

struct ProjectAnalysisResult: Codable {
    let projectId: UUID
    let analysisType: ProjectAnalysisType
    let result: AnalysisContent
    let confidence: Double
    let sources: [AnalysisSource]
    let generatedAt: Date
    let metadata: AnalysisMetadata
}

struct AnalysisContent: Codable {
    let summary: String
    let keyPoints: [String]
    let details: [String: String] // Changed from Any to String for Codable compliance
    let visualData: VisualizationData?
    let recommendations: [String]
}

struct AnalysisSource: Codable {
    let id: String
    let type: SourceType
    let title: String
    let relevanceScore: Double
    let extractedText: String?
    let timestamp: Date
}

enum SourceType: String, CaseIterable, Codable {
    case recording = "recording"
    case document = "document"
    case note = "note"
    case summary = "summary"
}

struct AnalysisMetadata: Codable {
    let processingTime: TimeInterval
    let tokenCount: Int
    let modelUsed: String
    let analysisVersion: String
    let qualityScore: Double
}

struct VisualizationData: Codable {
    let chartType: ChartType
    let data: [ChartDataPoint]
    let labels: [String]
    let colors: [String]?
    let configuration: ChartConfiguration
}

enum ChartType: String, CaseIterable, Codable {
    case line = "line"
    case bar = "bar"
    case pie = "pie"
    case timeline = "timeline"
    case wordCloud = "word_cloud"
    case network = "network"
}

struct ChartDataPoint: Codable {
    let x: Double
    let y: Double
    let label: String?
    let metadata: [String: String]?
}

struct ChartConfiguration: Codable {
    let title: String?
    let xAxisLabel: String?
    let yAxisLabel: String?
    let showLegend: Bool
    let animationEnabled: Bool
    let theme: String?
}

struct ProjectComparisonResult {
    let projectIds: [UUID]
    let comparisonType: ProjectComparisonType
    let similarities: [ComparisonItem]
    let differences: [ComparisonItem]
    let overallScore: Double
    let recommendations: [String]
    let generatedAt: Date
}

struct ComparisonItem {
    let aspect: String
    let projects: [UUID: Any]
    let score: Double
    let description: String
}

struct ProjectInsight {
    let id: String
    let type: InsightType
    let title: String
    let description: String
    let importance: InsightImportance
    let actionable: Bool
    let relatedSources: [AnalysisSource]
    let generatedAt: Date
    let expiresAt: Date?
}

enum InsightType: String, CaseIterable {
    case trend = "trend"
    case anomaly = "anomaly"
    case opportunity = "opportunity"
    case risk = "risk"
    case achievement = "achievement"
    case recommendation = "recommendation"
    
    var displayName: String {
        switch self {
        case .trend: return "トレンド"
        case .anomaly: return "異常値"
        case .opportunity: return "機会"
        case .risk: return "リスク"
        case .achievement: return "達成"
        case .recommendation: return "推奨事項"
        }
    }
}

enum InsightImportance: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "重要"
        }
    }
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - 質問応答システム

struct AIQuestionContext {
    let includeRecordings: Bool
    let includeDocuments: Bool
    let timeRange: DateInterval?
    let specificSources: [String]?
    let language: SupportedLanguage
    let responseStyle: ResponseStyle
}

enum ResponseStyle: String, CaseIterable {
    case concise = "concise"
    case detailed = "detailed"
    case bullet = "bullet"
    case narrative = "narrative"
    case technical = "technical"
    
    var displayName: String {
        switch self {
        case .concise: return "簡潔"
        case .detailed: return "詳細"
        case .bullet: return "箇条書き"
        case .narrative: return "物語調"
        case .technical: return "技術的"
        }
    }
}

struct AIQuestionResponse {
    let question: String
    let answer: String
    let confidence: Double
    let sources: [AnalysisSource]
    let relatedQuestions: [String]
    let followUpSuggestions: [String]
    let responseTime: TimeInterval
    let metadata: ResponseMetadata
}

struct ResponseMetadata {
    let modelUsed: String
    let tokenCount: Int
    let retrievalMethod: String
    let contextLength: Int
    let qualityScore: Double
}

struct ChatMessage {
    let id: String
    let projectId: UUID
    let type: MessageType
    let content: String
    let timestamp: Date
    let metadata: MessageMetadata?
}

enum MessageType: String, CaseIterable {
    case question = "question"
    case answer = "answer"
    case system = "system"
    case suggestion = "suggestion"
}

struct MessageMetadata {
    let sources: [AnalysisSource]?
    let confidence: Double?
    let processingTime: TimeInterval?
    let feedback: MessageFeedback?
}

struct MessageFeedback {
    let rating: Int // 1-5
    let helpful: Bool
    let accurate: Bool
    let comment: String?
    let providedAt: Date
}

// MARK: - プロジェクトコンテキスト

struct ProjectContext {
    let projectId: UUID
    let summary: String
    let totalContent: Int
    let contentBreakdown: [ContentType: Int]
    let timeRange: DateInterval
    let participants: [Participant]
    let keyTopics: [Topic]
    let recentActivity: [ActivityItem]
    let metadata: ProjectContextMetadata
}

struct Participant: Hashable {
    let id: String
    let name: String
    let role: String?
    let contributionCount: Int
    let lastActivity: Date
    let engagementScore: Double
}

struct Topic {
    let name: String
    let frequency: Int
    let importance: Double
    let trend: TopicTrend
    let relatedSources: [String]
}

enum TopicTrend: String, CaseIterable {
    case increasing = "increasing"
    case stable = "stable"
    case decreasing = "decreasing"
    case emerging = "emerging"
    case declining = "declining"
}

struct ActivityItem {
    let type: ProjectActivityType
    let title: String
    let timestamp: Date
    let importance: ActivityImportance
    let relatedSourceId: String
}

enum ProjectActivityType: String, CaseIterable {
    case recording = "recording"
    case document = "document"
    case decision = "decision"
    case actionItem = "action_item"
    case milestone = "milestone"
}

enum ActivityImportance: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

struct ProjectContextMetadata {
    let lastUpdated: Date
    let version: String
    let sources: [String]
    let completeness: Double
    let accuracy: Double
}

struct ContextSummary {
    let projectId: UUID
    let overallSummary: String
    let keyMetrics: [Metric]
    let recentHighlights: [String]
    let upcomingItems: [String]
    let recommendations: [String]
    let lastUpdated: Date
}

struct Metric {
    let name: String
    let value: Double
    let unit: String?
    let trend: MetricTrend
    let benchmark: Double?
}

enum MetricTrend: String, CaseIterable {
    case up = "up"
    case down = "down"
    case stable = "stable"
    case unknown = "unknown"
}

// MARK: - 時系列分析

enum TimelineGranularity: String, CaseIterable {
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    
    var displayName: String {
        switch self {
        case .hour: return "時間"
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
        case .quarter: return "四半期"
        }
    }
}

struct ProjectTimeline {
    let projectId: UUID
    let granularity: TimelineGranularity
    let timeRange: DateInterval
    let events: [TimelineEvent]
    let patterns: [TimelinePattern]
    let milestones: [Milestone]
    let metadata: TimelineMetadata
}

struct TimelineEvent {
    let id: String
    let timestamp: Date
    let type: EventType
    let title: String
    let description: String?
    let importance: EventImportance
    let participants: [String]
    let relatedSources: [String]
}

enum EventType: String, CaseIterable {
    case meeting = "meeting"
    case decision = "decision"
    case deliverable = "deliverable"
    case milestone = "milestone"
    case issue = "issue"
    case resolution = "resolution"
}

enum EventImportance: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct TimelinePattern {
    let type: PatternType
    let description: String
    let confidence: Double
    let timeRange: DateInterval
    let evidence: [String]
}

enum PatternType: String, CaseIterable {
    case recurring = "recurring"
    case seasonal = "seasonal"
    case growth = "growth"
    case decline = "decline"
    case cyclical = "cyclical"
}

struct Milestone {
    let id: String
    let title: String
    let description: String?
    let targetDate: Date
    let actualDate: Date?
    let status: MilestoneStatus
    let progress: Double // 0.0 - 1.0
    let relatedEvents: [String]
}

enum MilestoneStatus: String, CaseIterable {
    case planned = "planned"
    case inProgress = "in_progress"
    case completed = "completed"
    case delayed = "delayed"
    case cancelled = "cancelled"
}

struct TimelineMetadata {
    let totalEvents: Int
    let completeness: Double
    let accuracy: Double
    let lastAnalyzed: Date
    let analysisVersion: String
}

// MARK: - トレンド分析

enum TrendType: String, CaseIterable {
    case activity = "activity"
    case sentiment = "sentiment"
    case productivity = "productivity"
    case participation = "participation"
    case topics = "topics"
    case decisions = "decisions"
    
    var displayName: String {
        switch self {
        case .activity: return "活動トレンド"
        case .sentiment: return "感情トレンド"
        case .productivity: return "生産性トレンド"
        case .participation: return "参加トレンド"
        case .topics: return "トピックトレンド"
        case .decisions: return "決定トレンド"
        }
    }
}

struct ProjectTrend {
    let type: TrendType
    let title: String
    let description: String
    let direction: TrendDirection
    let strength: TrendStrength
    let timeRange: DateInterval
    let dataPoints: [TrendDataPoint]
    let significance: Double
    let projections: [TrendProjection]?
}

enum TrendDirection: String, CaseIterable {
    case upward = "upward"
    case downward = "downward"
    case stable = "stable"
    case volatile = "volatile"
    case increasing = "increasing"
    case decreasing = "decreasing"
}

enum TrendStrength: String, CaseIterable {
    case weak = "weak"
    case moderate = "moderate"
    case strong = "strong"
    case veryStrong = "very_strong"
}

struct TrendDataPoint {
    let timestamp: Date
    let value: Double
    let confidence: Double
    let metadata: [String: Any]?
}

struct TrendProjection {
    let targetDate: Date
    let projectedValue: Double
    let confidenceInterval: (lower: Double, upper: Double)
    let assumptions: [String]
}

// MARK: - 進捗レポート

enum ProgressReportType: String, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case milestone = "milestone"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .weekly: return "週次レポート"
        case .monthly: return "月次レポート"
        case .quarterly: return "四半期レポート"
        case .milestone: return "マイルストーンレポート"
        case .custom: return "カスタムレポート"
        }
    }
}

struct ProgressReport {
    let id: String
    let projectId: UUID
    let type: ProgressReportType
    let timeRange: DateInterval
    let summary: String
    let achievements: [Achievement]
    let challenges: [Challenge]
    let metrics: [ProgressMetric]
    let nextSteps: [NextStep]
    let recommendations: [String]
    let generatedAt: Date
}

struct Achievement {
    let title: String
    let description: String
    let impact: ImpactLevel
    let completedAt: Date
    let contributors: [String]
    let evidence: [String]
}

enum ImpactLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case transformational = "transformational"
}

struct Challenge {
    let title: String
    let description: String
    let severity: ChallengeSeverity
    let status: ChallengeStatus
    let proposedSolutions: [String]
    let impact: String?
}

enum ChallengeSeverity: String, CaseIterable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case critical = "critical"
}

enum ChallengeStatus: String, CaseIterable {
    case identified = "identified"
    case investigating = "investigating"
    case addressing = "addressing"
    case resolved = "resolved"
    case escalated = "escalated"
}

struct ProgressMetric {
    let name: String
    let currentValue: Double
    let targetValue: Double?
    let previousValue: Double?
    let unit: String
    let trend: MetricTrend
    let interpretation: String
}

struct NextStep {
    let title: String
    let description: String
    let priority: ActionItemPriority
    let estimatedEffort: String?
    let dependencies: [String]
    let suggestedOwner: String?
}

// MARK: - アクションアイテム

enum ActionItemPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "緊急"
        }
    }
}

struct ActionItem {
    let id: String
    let title: String
    let description: String
    let priority: ActionItemPriority
    let status: ActionItemStatus
    let assignee: String?
    let dueDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let source: ActionItemSource
    let context: String
    let dependencies: [String]
    let tags: [String]
}

enum ActionItemStatus: String, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case blocked = "blocked"
}

struct ActionItemSource {
    let type: SourceType
    let id: String
    let title: String
    let timestamp: Date
    let relevantSection: String?
}

// MARK: - 次のステップ提案

struct NextStepContext {
    let recentActivities: [ActivityItem]
    let currentChallenges: [Challenge]
    let availableResources: [String]
    let timeConstraints: TimeConstraint?
    let priorities: [String]
}

struct TimeConstraint {
    let deadline: Date
    let availableHours: Double?
    let urgency: UrgencyLevel
}

enum UrgencyLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct NextStepSuggestion {
    let id: String
    let title: String
    let description: String
    let rationale: String
    let estimatedEffort: EffortEstimate
    let expectedOutcome: String
    let risks: [String]
    let dependencies: [String]
    let priority: ActionItemPriority
    let timeframe: Timeframe
}

struct EffortEstimate {
    let hours: Double?
    let complexity: ComplexityLevel
    let skillsRequired: [String]
    let resourcesNeeded: [String]
}

enum ComplexityLevel: String, CaseIterable {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    case veryComplex = "very_complex"
}

struct Timeframe {
    let start: Date?
    let end: Date?
    let duration: TimeInterval?
    let flexibility: TimeflexibilityLevel
}

enum TimeflexibilityLevel: String, CaseIterable {
    case fixed = "fixed"
    case flexible = "flexible"
    case negotiable = "negotiable"
}

// MARK: - ミーティング要約

enum MeetingSummaryType: String, CaseIterable {
    case executive = "executive"
    case detailed = "detailed"
    case actionItems = "action_items"
    case decisions = "decisions"
    case notes = "notes"
    
    var displayName: String {
        switch self {
        case .executive: return "エグゼクティブサマリー"
        case .detailed: return "詳細要約"
        case .actionItems: return "アクションアイテム"
        case .decisions: return "決定事項"
        case .notes: return "議事録"
        }
    }
}

struct MeetingSummary {
    let id: String
    let title: String
    let type: MeetingSummaryType
    let recordingIds: [UUID]
    let participants: [Participant]
    let duration: TimeInterval
    let summary: String
    let keyPoints: [String]
    let decisions: [Decision]
    let actionItems: [ActionItem]
    let nextMeeting: NextMeetingInfo?
    let metadata: MeetingMetadata
}

struct Decision {
    let id: String
    let title: String
    let description: String
    let decisionMaker: String?
    let decidedAt: Date
    let rationale: String?
    let impact: ImpactLevel
    let relatedTopics: [String]
}

struct NextMeetingInfo {
    let suggestedDate: Date?
    let topics: [String]
    let requiredParticipants: [String]
    let preparation: [String]
}

struct MeetingMetadata {
    let generatedAt: Date
    let analysisVersion: String
    let qualityScore: Double
    let completeness: Double
    let extractionAccuracy: Double
}

// MARK: - 感情・エンゲージメント分析

struct SentimentAnalysis {
    let projectId: UUID
    let timeRange: DateInterval
    let overallSentiment: SentimentScore
    let sentimentTrend: [SentimentDataPoint]
    let topicSentiments: [TopicSentiment]
    let participantSentiments: [ParticipantSentiment]
    let insights: [SentimentInsight]
    let metadata: SentimentMetadata
}

struct SentimentScore {
    let score: Double // -1.0 to 1.0
    let label: SentimentLabel
    let confidence: Double
}

enum SentimentLabel: String, CaseIterable {
    case veryNegative = "very_negative"
    case negative = "negative"
    case neutral = "neutral"
    case positive = "positive"
    case veryPositive = "very_positive"
    
    var displayName: String {
        switch self {
        case .veryNegative: return "非常にネガティブ"
        case .negative: return "ネガティブ"
        case .neutral: return "中立"
        case .positive: return "ポジティブ"
        case .veryPositive: return "非常にポジティブ"
        }
    }
}

struct SentimentDataPoint {
    let timestamp: Date
    let sentiment: SentimentScore
    let context: String?
    let sourceId: String
}

struct TopicSentiment {
    let topic: String
    let sentiment: SentimentScore
    let frequency: Int
    let examples: [String]
}

struct ParticipantSentiment {
    let participantId: String
    let sentiment: SentimentScore
    let contribution: Double
    let topics: [String]
}

struct SentimentInsight {
    let type: SentimentInsightType
    let description: String
    let significance: Double
    let timeRange: DateInterval?
    let evidence: [String]
}

enum SentimentInsightType: String, CaseIterable {
    case trendChange = "trend_change"
    case outlier = "outlier"
    case pattern = "pattern"
    case correlation = "correlation"
}

struct SentimentMetadata {
    let model: String
    let accuracy: Double
    let coverage: Double
    let lastAnalyzed: Date
}

struct EngagementAnalysis {
    let projectId: UUID
    let timeRange: DateInterval
    let overallEngagement: EngagementScore
    let engagementTrend: [EngagementDataPoint]
    let participantEngagement: [ParticipantEngagement]
    let engagementFactors: [EngagementFactor]
    let recommendations: [EngagementRecommendation]
}

struct EngagementScore {
    let score: Double // 0.0 to 1.0
    let level: EngagementLevel
    let confidence: Double
}

enum EngagementLevel: String, CaseIterable {
    case veryLow = "very_low"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow: return "非常に低い"
        case .low: return "低い"
        case .moderate: return "普通"
        case .high: return "高い"
        case .veryHigh: return "非常に高い"
        }
    }
}

struct EngagementDataPoint {
    let timestamp: Date
    let engagement: EngagementScore
    let factors: [String]
    let sourceId: String
}

struct ParticipantEngagement {
    let participantId: String
    let engagement: EngagementScore
    let contributionMetrics: ContributionMetrics
    let trends: [EngagementTrend]
}

struct ContributionMetrics {
    let speakingTime: TimeInterval
    let questionCount: Int
    let ideaCount: Int
    let interactionCount: Int
    let leadershipMoments: Int
}

struct EngagementTrend {
    let period: DateInterval
    let direction: TrendDirection
    let significance: Double
}

struct EngagementFactor {
    let name: String
    let impact: Double // -1.0 to 1.0
    let confidence: Double
    let description: String
    let examples: [String]
}

struct EngagementRecommendation {
    let title: String
    let description: String
    let expectedImpact: ImpactLevel
    let effort: EffortEstimate
    let priority: ActionItemPriority
}

struct MoodChange {
    let timestamp: Date
    let previousMood: SentimentScore
    let newMood: SentimentScore
    let magnitude: Double
    let cause: MoodChangeCause?
    let context: String
    let sourceId: String
    let participants: [String]
}

struct MoodChangeCause {
    let type: MoodChangeCauseType
    let description: String
    let confidence: Double
    let relatedEvents: [String]
}

enum MoodChangeCauseType: String, CaseIterable {
    case topic = "topic"
    case decision = "decision"
    case announcement = "announcement"
    case conflict = "conflict"
    case achievement = "achievement"
    case setback = "setback"
    case external = "external"
    case unknown = "unknown"
}