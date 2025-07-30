import Foundation

// MARK: - 予測分析関連の型定義

enum PredictionType: String, CaseIterable, Codable {
    case activityLevel = "activity_level"
    case teamEngagement = "team_engagement"
    case projectCompletion = "project_completion"
    case resourceRequirement = "resource_requirement"
    case qualityMetrics = "quality_metrics"
    case riskFactors = "risk_factors"
    
    var displayName: String {
        switch self {
        case .activityLevel: return "活動レベル予測"
        case .teamEngagement: return "チームエンゲージメント予測"
        case .projectCompletion: return "プロジェクト完了予測"
        case .resourceRequirement: return "リソース要求予測"
        case .qualityMetrics: return "品質指標予測"
        case .riskFactors: return "リスク要因予測"
        }
    }
}

struct PredictiveAnalysisResult: Codable {
    let projectId: UUID
    let predictionType: PredictionType
    let timeHorizon: TimeInterval
    let predictions: [Prediction]
    let confidence: Double
    let influencingFactors: [InfluencingFactor]
    let recommendations: [String]
    let historicalDataPoints: Int
    let generatedAt: Date
    let metadata: PredictiveAnalysisMetadata
}

struct Prediction: Codable {
    let id: String
    let timestamp: Date
    let predictedValue: Double
    let confidenceInterval: ConfidenceInterval
    let contributingFactors: [String]
    let scenario: PredictionScenario
}

struct ConfidenceInterval: Codable {
    let lower: Double
    let upper: Double
    let level: Double // e.g., 0.95 for 95% confidence
}

enum PredictionScenario: String, CaseIterable, Codable {
    case optimistic = "optimistic"
    case realistic = "realistic"
    case pessimistic = "pessimistic"
    
    var displayName: String {
        switch self {
        case .optimistic: return "楽観的シナリオ"
        case .realistic: return "現実的シナリオ"
        case .pessimistic: return "悲観的シナリオ"
        }
    }
}

struct InfluencingFactor: Codable {
    let name: String
    let impact: Double // -1.0 to 1.0
    let confidence: Double
    let category: FactorCategory
    let explanation: String
}

enum FactorCategory: String, CaseIterable, Codable {
    case `internal` = "internal"
    case external = "external"
    case temporal = "temporal"
    case resource = "resource"
    case quality = "quality"
}

struct PredictiveAnalysisMetadata: Codable {
    let modelType: String
    let dataQuality: Double
    let assumptions: [String]
    let limitations: [String]
}

struct HistoricalDataPoint: Codable {
    let timestamp: Date
    let value: Double
    let category: String
    let metadata: [String: String]  // Changed from Any to String for Codable compliance
}

enum AnalyticsTrendType: String, CaseIterable, Codable {
    case linear = "linear"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case polynomial = "polynomial"
    case seasonal = "seasonal"
}

enum AnalyticsTrendDirection: String, CaseIterable, Codable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

struct TrendPattern: Codable {
    let type: AnalyticsTrendType
    let strength: Double
    let direction: AnalyticsTrendDirection
    let duration: TimeInterval
    let significance: Double
}

// MARK: - 異常検知関連の型定義

enum AnomalyDetectionType: String, CaseIterable, Codable {
    case activityPatterns = "activity_patterns"
    case communicationFrequency = "communication_frequency"
    case productivityMetrics = "productivity_metrics"
    case qualityIndicators = "quality_indicators"
    case resourceUsage = "resource_usage"
    case timelineDeviations = "timeline_deviations"
    
    var displayName: String {
        switch self {
        case .activityPatterns: return "活動パターン異常"
        case .communicationFrequency: return "コミュニケーション頻度異常"
        case .productivityMetrics: return "生産性指標異常"
        case .qualityIndicators: return "品質指標異常"
        case .resourceUsage: return "リソース使用異常"
        case .timelineDeviations: return "タイムライン逸脱"
        }
    }
}

enum AnomalySensitivity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var threshold: Double {
        switch self {
        case .low: return 3.0      // 3σ
        case .medium: return 2.5   // 2.5σ
        case .high: return 2.0     // 2σ
        case .veryHigh: return 1.5 // 1.5σ
        }
    }
}

struct AnomalyDetectionResult: Codable {
    let projectId: UUID
    let detectionType: AnomalyDetectionType
    let timeRange: DateInterval
    let anomalies: [Anomaly]
    let baseline: BaselinePattern
    let sensitivity: AnomalySensitivity
    let rootCauseAnalysis: [RootCauseAnalysis]
    let totalDataPoints: Int
    let detectionAccuracy: Double
    let generatedAt: Date
}

struct Anomaly: Codable {
    let id: String
    let timestamp: Date
    let value: Double
    let severity: AnomalySeverity
    let deviationScore: Double
    let type: AnomalyType
    let description: String
    let affectedMetrics: [String]
    let potentialCauses: [String]
}

enum AnomalySeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

enum AnomalyType: String, CaseIterable, Codable {
    case spike = "spike"           // 急激な上昇
    case drop = "drop"             // 急激な下降
    case plateau = "plateau"       // 異常な平坦化
    case oscillation = "oscillation" // 異常な振動
    case trend = "trend"           // 異常なトレンド
}

struct BaselinePattern: Codable {
    let mean: Double
    let standardDeviation: Double
    let patterns: [PatternSignature]
}

struct PatternSignature: Codable {
    let type: String
    let parameters: [String: Double]
    let confidence: Double
}

struct RootCauseAnalysis: Codable {
    let anomalyId: String
    let probableCauses: [ProbableCause]
    let investigationSteps: [String]
    let recommendedActions: [String]
}

struct ProbableCause: Codable {
    let cause: String
    let probability: Double
    let evidence: [String]
    let category: CauseCategory
}

enum CauseCategory: String, CaseIterable, Codable {
    case technical = "technical"
    case process = "process"
    case human = "human"
    case external = "external"
}

struct TimeSeriesDataPoint: Codable {
    let timestamp: Date
    let value: Double
    let metadata: [String: String]  // Changed from Any to String for Codable compliance
}

// MARK: - 相関分析関連の型定義

enum CorrelationType: String, CaseIterable, Codable {
    case pearson = "pearson"
    case spearman = "spearman"
    case kendall = "kendall"
    case partial = "partial"
    
    var displayName: String {
        switch self {
        case .pearson: return "ピアソン相関"
        case .spearman: return "スピアマン相関"
        case .kendall: return "ケンドール相関"
        case .partial: return "偏相関"
        }
    }
}

struct AnalysisVariable: Hashable, Codable {
    let name: String
    let type: VariableType
    let description: String
    let unit: String?
}

enum VariableType: String, CaseIterable, Hashable, Codable {
    case continuous = "continuous"
    case ordinal = "ordinal"
    case categorical = "categorical"
    case binary = "binary"
}

struct CorrelationAnalysisResult: Codable {
    let projectId: UUID
    let variables: [AnalysisVariable]
    let correlationType: CorrelationType
    let timeRange: DateInterval
    let correlationMatrix: [CorrelationPair]
    let significanceTests: [SignificanceTest]
    let causalHypotheses: [CausalHypothesis]
    let insights: [CorrelationInsight]
    let dataQuality: DataQualityMetrics
    let generatedAt: Date
}

struct CorrelationPair: Codable {
    let variable1: AnalysisVariable
    let variable2: AnalysisVariable
    let correlation: Double
    let coefficient: Double  // Added missing coefficient property
    let strength: CorrelationStrength
    let direction: CorrelationDirection
}

enum CorrelationStrength: String, CaseIterable, Codable {
    case negligible = "negligible"  // |r| < 0.1
    case weak = "weak"              // 0.1 ≤ |r| < 0.3
    case moderate = "moderate"      // 0.3 ≤ |r| < 0.5
    case strong = "strong"          // 0.5 ≤ |r| < 0.7
    case veryStrong = "very_strong" // |r| ≥ 0.7
    
    static func from(correlation: Double) -> CorrelationStrength {
        let abs = Swift.abs(correlation)
        if abs < 0.1 { return .negligible }
        else if abs < 0.3 { return .weak }
        else if abs < 0.5 { return .moderate }
        else if abs < 0.7 { return .strong }
        else { return .veryStrong }
    }
}

enum CorrelationDirection: String, CaseIterable, Codable {
    case positive = "positive"
    case negative = "negative"
    case none = "none"
    
    static func from(correlation: Double) -> CorrelationDirection {
        if correlation > 0.05 { return .positive }
        else if correlation < -0.05 { return .negative }
        else { return .none }
    }
}

struct SignificanceTest: Codable {
    let correlationPair: CorrelationPair
    let pValue: Double
    let isSignificant: Bool
    let confidenceLevel: Double
}

struct CausalHypothesis: Codable {
    let cause: AnalysisVariable
    let effect: AnalysisVariable
    let likelihood: Double
    let supportingEvidence: [String]
    let alternativeExplanations: [String]
}

struct CorrelationInsight: Identifiable, Codable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let actionable: Bool
    let priority: InsightPriority
    let relatedVariables: [AnalysisVariable]
    
    private enum CodingKeys: String, CodingKey {
        case title, description, actionable, priority, relatedVariables
    }
}

enum InsightPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct DataQualityMetrics: Codable {
    let completeness: Double  // 0.0 - 1.0
    let accuracy: Double      // 0.0 - 1.0
    let consistency: Double   // 0.0 - 1.0
}

struct DataPoint: Codable {
    let timestamp: Date
    let value: Double
    let quality: Double
}

// MARK: - クラスタリング分析関連の型定義

enum ClusteringType: String, CaseIterable, Codable {
    case kMeans = "k_means"
    case hierarchical = "hierarchical"
    case dbscan = "dbscan"
    case gaussianMixture = "gaussian_mixture"
    
    var displayName: String {
        switch self {
        case .kMeans: return "K-Means"
        case .hierarchical: return "階層クラスタリング"
        case .dbscan: return "DBSCAN"
        case .gaussianMixture: return "混合ガウシアンモデル"
        }
    }
}

struct ClusteringFeature: Codable {
    let name: String
    let type: FeatureType
    let weight: Double
    let description: String
}

enum FeatureType: String, CaseIterable, Codable {
    case numerical = "numerical"
    case categorical = "categorical"
    case boolean = "boolean"
    case text = "text"
}

struct ClusteringAnalysisResult: Codable {
    let projectId: UUID
    let clusteringType: ClusteringType
    let features: [ClusteringFeature]
    let clusters: [Cluster]
    let qualityMetrics: ClusterQualityMetrics
    let characteristics: [ClusterCharacteristic]
    let insights: [ClusteringInsight]
    let dataPoints: Int
    let optimalClusterCount: Int
    let generatedAt: Date
}

struct Cluster: Codable {
    let id: String
    let label: String
    let centroid: [Double]
    let members: [ClusterMember]
    let size: Int
    let cohesion: Double
    let separation: Double
}

struct ClusterMember: Codable {
    let id: String
    let dataPoint: [Double]
    let distanceToCenter: Double
    let membershipProbability: Double?
}

struct ClusterQualityMetrics: Codable {
    let silhouetteScore: Double    // -1 to 1, higher is better
    let inertia: Double           // Lower is better for k-means
    let calinskiHarabasz: Double  // Higher is better
}

struct ClusterCharacteristic: Codable {
    let clusterId: String
    let feature: ClusteringFeature
    let averageValue: Double
    let variance: Double
    let distinctiveness: Double
}

struct ClusteringInsight: Identifiable, Codable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let clustersInvolved: [String]
    let businessRelevance: BusinessRelevance
    let recommendedActions: [String]
    
    private enum CodingKeys: String, CodingKey {
        case title, description, clustersInvolved, businessRelevance, recommendedActions
    }
}

enum BusinessRelevance: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

struct FeatureVector: Codable {
    let id: String
    let features: [Double]
    let metadata: [String: String]  // Changed from Any to String for Codable compliance
}

struct NormalizedFeatureVector: Codable {
    let id: String
    let normalizedFeatures: [Double]
    let originalFeatures: [Double]
}

// MARK: - 影響度分析関連の型定義

struct ChangeScenario: Codable {
    let id: String
    let name: String
    let type: ChangeType
    let description: String
    let parameters: [String: String]  // Changed from Any to String for Codable compliance
    let timeline: DateInterval
}

enum ChangeType: String, CaseIterable, Codable {
    case teamRestructure = "team_restructure"
    case processChange = "process_change"
    case technologyAdoption = "technology_adoption"
    case resourceReallocation = "resource_reallocation"
    case scopeModification = "scope_modification"
    case timelineAdjustment = "timeline_adjustment"
    
    var displayName: String {
        switch self {
        case .teamRestructure: return "チーム再編"
        case .processChange: return "プロセス変更"
        case .technologyAdoption: return "技術導入"
        case .resourceReallocation: return "リソース再配分"
        case .scopeModification: return "スコープ変更"
        case .timelineAdjustment: return "タイムライン調整"
        }
    }
}

enum ImpactScope: String, CaseIterable, Codable {
    case task = "task"
    case project = "project"
    case team = "team"
    case organization = "organization"
    case stakeholders = "stakeholders"
    
    var displayName: String {
        switch self {
        case .task: return "タスク"
        case .project: return "プロジェクト"
        case .team: return "チーム"
        case .organization: return "組織"
        case .stakeholders: return "ステークホルダー"
        }
    }
}

struct ImpactAnalysisResult: Codable {
    let projectId: UUID
    let changeScenario: ChangeScenario
    let impactScope: ImpactScope
    let baseline: ImpactBaseline
    let directImpacts: [DirectImpact]
    let rippleEffects: [RippleEffect]
    let riskAssessment: RiskAssessment
    let opportunityAssessment: OpportunityAssessment
    let mitigationStrategies: [MitigationStrategy]
    let confidenceLevel: Double
    let generatedAt: Date
    
    // Additional properties expected by View files
    let overallImpact: Double
    let completedAt: Date
    
    init(projectId: UUID, changeScenario: ChangeScenario, impactScope: ImpactScope, baseline: ImpactBaseline, directImpacts: [DirectImpact], rippleEffects: [RippleEffect], riskAssessment: RiskAssessment, opportunityAssessment: OpportunityAssessment, mitigationStrategies: [MitigationStrategy], confidenceLevel: Double, generatedAt: Date = Date(), overallImpact: Double = 0.0, completedAt: Date = Date()) {
        self.projectId = projectId
        self.changeScenario = changeScenario
        self.impactScope = impactScope
        self.baseline = baseline
        self.directImpacts = directImpacts
        self.rippleEffects = rippleEffects
        self.riskAssessment = riskAssessment
        self.opportunityAssessment = opportunityAssessment
        self.mitigationStrategies = mitigationStrategies
        self.confidenceLevel = confidenceLevel
        self.generatedAt = generatedAt
        self.overallImpact = overallImpact
        self.completedAt = completedAt
    }
}

struct ImpactBaseline: Codable {
    let metrics: [String: Double]
    let timestamp: Date
}

struct SimulationResult: Codable {
    let projectedMetrics: [String: Double]
    let confidence: Double
}

struct DirectImpact: Codable {
    let metric: String
    let baselineValue: Double
    let projectedValue: Double
    let percentageChange: Double
    let impactMagnitude: ImpactMagnitude
    let timeToEffect: TimeInterval
}

enum ImpactMagnitude: String, CaseIterable, Codable {
    case negligible = "negligible"
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case severe = "severe"
    
    var numericValue: Double {
        switch self {
        case .negligible: return 0.05
        case .minor: return 0.15
        case .moderate: return 0.30
        case .major: return 0.50
        case .severe: return 0.75
        }
    }
}

struct RippleEffect: Codable {
    let source: DirectImpact
    let affectedArea: String
    let propagationDelay: TimeInterval
    let amplificationFactor: Double
    let description: String
}

struct RiskAssessment: Codable {
    let risks: [IdentifiedRisk]
    let overallRiskLevel: RiskLevel
}

struct IdentifiedRisk: Codable {
    let name: String
    let probability: Double
    let impact: ImpactMagnitude
    let category: RiskCategory
    let description: String
    let triggers: [String]
}

enum RiskLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum RiskCategory: String, CaseIterable, Codable {
    case operational = "operational"
    case strategic = "strategic"
    case financial = "financial"
    case technical = "technical"
    case human = "human"
}

struct OpportunityAssessment: Codable {
    let opportunities: [IdentifiedOpportunity]
    let overallOpportunityLevel: OpportunityLevel
}

struct IdentifiedOpportunity: Codable {
    let name: String
    let likelihood: Double
    let benefit: ImpactMagnitude
    let description: String
    let requirements: [String]
}

enum OpportunityLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case exceptional = "exceptional"
}

struct MitigationStrategy: Identifiable, Codable {
    let id: UUID = UUID()
    let risk: IdentifiedRisk
    let strategy: String
    let effectiveness: Double
    let cost: MitigationCost
    let timeline: TimeInterval
    let resources: [String]
    
    // Convenience property for description
    var description: String {
        strategy
    }
    
    private enum CodingKeys: String, CodingKey {
        case risk, strategy, effectiveness, cost, timeline, resources
    }
}

enum MitigationCost: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
}

// MARK: - Additional Types for UI Support

// Simple types that don't exist in Core but are needed by Views
struct PredictionResult: Identifiable {
    let id: UUID = UUID()
    let type: PredictionType
    let value: Double
    let confidence: Double
    let timestamp: Date
    
    init(type: PredictionType, value: Double, confidence: Double, timestamp: Date = Date()) {
        self.type = type
        self.value = value
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

struct DetectedAnomaly {
    let id: UUID = UUID()
    let type: String
    let score: Double
    let timestamp: Date
    let description: String?
    
    init(type: String, score: Double, timestamp: Date = Date(), description: String? = nil) {
        self.type = type
        self.score = score
        self.timestamp = timestamp
        self.description = description
    }
}

struct CorrelationResult: Identifiable {
    let id: UUID = UUID()
    let variable1: String
    let variable2: String
    let coefficient: Double
    let pValue: Double
    
    init(variable1: String, variable2: String, coefficient: Double, pValue: Double) {
        self.variable1 = variable1
        self.variable2 = variable2
        self.coefficient = coefficient
        self.pValue = pValue
    }
}

struct ClusterResult: Identifiable {
    let id: UUID = UUID()
    let clusterID: Int
    let size: Int
    let centroid: [Double]
    let characteristics: [String: Double]
    
    init(clusterID: Int, size: Int, centroid: [Double], characteristics: [String: Double]) {
        self.clusterID = clusterID
        self.size = size
        self.centroid = centroid
        self.characteristics = characteristics
    }
}

// Simplified types for View layer compatibility
typealias ViewInfluencingFactor = InfluencingFactor
typealias ViewCorrelationInsight = CorrelationInsight
typealias ViewClusteringInsight = ClusteringInsight

// Additional enums for Impact Scenarios (these were in the view files)
enum ImpactScenario: String, CaseIterable {
    case optimistic = "optimistic"
    case realistic = "realistic"
    case pessimistic = "pessimistic"
    
    var displayName: String {
        switch self {
        case .optimistic: return "楽観シナリオ"
        case .realistic: return "現実シナリオ"
        case .pessimistic: return "悲観シナリオ"
        }
    }
}

// Risk/Opportunity Assessment types for View compatibility
struct RiskAssessmentItem: Identifiable, Codable {
    let id: UUID = UUID()
    let description: String
    let probability: Double
    let impact: Double
    
    private enum CodingKeys: String, CodingKey {
        case description, probability, impact
    }
    
    init(description: String, probability: Double, impact: Double) {
        self.description = description
        self.probability = probability
        self.impact = impact
    }
}

struct OpportunityAssessmentItem: Identifiable, Codable {
    let id: UUID = UUID()
    let description: String
    let probability: Double
    let benefit: Double
    
    private enum CodingKeys: String, CodingKey {
        case description, probability, benefit
    }
    
    init(description: String, probability: Double, benefit: Double) {
        self.description = description
        self.probability = probability
        self.benefit = benefit
    }
}

struct MitigationStrategyItem: Identifiable, Codable {
    let id: UUID = UUID()
    let description: String
    let effectiveness: Double
    let cost: Double
    
    private enum CodingKeys: String, CodingKey {
        case description, effectiveness, cost
    }
    
    init(description: String, effectiveness: Double, cost: Double) {
        self.description = description
        self.effectiveness = effectiveness
        self.cost = cost
    }
}

// MARK: - Additional Types from View Files
// Note: InsightType and InsightImportance are imported from existing Core definitions

// Note: Metric and MetricTrend are imported from Core/UseCases/ProjectAIUseCaseProtocol.swift