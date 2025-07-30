import Foundation
import SwiftUI

// MARK: - 高度な分析ViewModel

@MainActor
class AdvancedAnalyticsViewModel: ObservableObject {
    
    // MARK: - 依存関係
    private let project: Project
    private let projectAIUseCase: ProjectAIUseCaseProtocol
    
    // MARK: - UI状態
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentOperation: String?
    @Published var showingAnalysisSettings = false
    @Published var showingExportOptions = false
    @Published var showingAnomalyDetail = false
    
    // MARK: - 予測分析
    @Published var selectedPredictionType: PredictionType = .activityLevel
    @Published var currentPrediction: PredictiveAnalysisResult?
    @Published var predictionHistory: [PredictiveAnalysisResult] = []
    @Published var influencingFactors: [InfluencingFactor] = []
    @Published var predictionTimeHorizon: TimeInterval = 86400 * 30 // 30日
    @Published var predictionConfidence: Double = 0.8
    
    // MARK: - 異常検知
    @Published var selectedAnomalyType: AnomalyDetectionType = .activityPatterns
    @Published var anomalySensitivity: AnomalySensitivity = .medium
    @Published var detectedAnomalies: [Anomaly] = []
    @Published var selectedAnomaly: Anomaly?
    @Published var anomalyTimeRange: DateInterval?
    
    // MARK: - 相関分析
    @Published var selectedVariables: [AnalysisVariable] = []
    @Published var correlationType: CorrelationType = .pearson
    @Published var correlationResults: [CorrelationPair] = []
    @Published var correlationInsights: [CorrelationInsight] = []
    @Published var availableVariables: [AnalysisVariable] = []
    
    // MARK: - クラスタリング分析
    @Published var clusteringType: ClusteringType = .kMeans
    @Published var selectedFeatures: [ClusteringFeature] = []
    @Published var targetClusters: Int? = nil
    @Published var clusters: [Cluster] = []
    @Published var clusterQualityMetrics: ClusterQualityMetrics?
    @Published var clusteringInsights: [ClusteringInsight] = []
    @Published var availableFeatures: [ClusteringFeature] = []
    
    // MARK: - 影響度分析
    @Published var selectedScenario: ChangeScenario?
    @Published var impactScope: ImpactScope = .project
    @Published var impactAnalysisResult: ImpactAnalysisResult?
    @Published var availableScenarios: [ChangeScenario] = []
    
    // MARK: - 分析設定
    @Published var analysisSettings = AnalysisSettings()
    
    init(project: Project, projectAIUseCase: ProjectAIUseCaseProtocol) {
        self.project = project
        self.projectAIUseCase = projectAIUseCase
        
        setupDefaultVariables()
        setupDefaultFeatures()
        setupDefaultScenarios()
    }
    
    // MARK: - 初期化メソッド
    
    func loadInitialAnalytics() async {
        isLoading = true
        currentOperation = "初期分析データを読み込み中..."
        
        // 基本的な分析データを並行して読み込み
        async let predictionTask: Void = loadDefaultPrediction()
        async let anomalyTask: Void = loadRecentAnomalies()
        async let correlationTask: Void = loadDefaultCorrelations()
        
        await predictionTask
        await anomalyTask
        await correlationTask
        
        currentOperation = nil
        
        isLoading = false
    }
    
    func switchAnalysisType(to type: AdvancedAnalysisType) async {
        currentOperation = "\(type.displayName)に切り替え中..."
        
        switch type {
        case .predictive:
            if currentPrediction == nil {
                await generatePrediction(type: selectedPredictionType)
            }
        case .anomaly:
            if detectedAnomalies.isEmpty {
                await detectAnomalies()
            }
        case .correlation:
            if correlationResults.isEmpty && selectedVariables.count >= 2 {
                await analyzeCorrelations()
            }
        case .clustering:
            if clusters.isEmpty && !selectedFeatures.isEmpty {
                await performClustering()
            }
        case .impact:
            if impactAnalysisResult == nil && selectedScenario != nil {
                await analyzeImpact()
            }
        }
        
        currentOperation = nil
    }
    
    func refreshAnalysis(for type: AdvancedAnalysisType) async {
        switch type {
        case .predictive:
            await generatePrediction(type: selectedPredictionType)
        case .anomaly:
            await detectAnomalies()
        case .correlation:
            await analyzeCorrelations()
        case .clustering:
            await performClustering()
        case .impact:
            await analyzeImpact()
        }
    }
    
    // MARK: - 予測分析メソッド
    
    func generatePrediction(type: PredictionType) async {
        guard !isLoading else { return }
        
        isLoading = true
        currentOperation = "\(type.displayName)を実行中..."
        
        do {
            let result = try await projectAIUseCase.generatePredictiveAnalysis(
                projectId: project.id,
                predictionType: type,
                timeHorizon: predictionTimeHorizon,
                confidence: predictionConfidence
            )
            
            currentPrediction = result
            influencingFactors = result.influencingFactors
            
            // 履歴に追加
            if !predictionHistory.contains(where: { $0.predictionType == type }) {
                predictionHistory.append(result)
            }
            
        } catch {
            errorMessage = "予測分析に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
        currentOperation = nil
    }
    
    private func loadDefaultPrediction() async {
        await generatePrediction(type: .activityLevel)
    }
    
    // MARK: - 異常検知メソッド
    
    func detectAnomalies() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentOperation = "異常を検知中..."
        
        do {
            let result = try await projectAIUseCase.detectAnomalies(
                projectId: project.id,
                detectionType: selectedAnomalyType,
                sensitivity: anomalySensitivity,
                timeRange: anomalyTimeRange
            )
            
            detectedAnomalies = result.anomalies.sorted { $0.severity.priority > $1.severity.priority }
            
        } catch {
            errorMessage = "異常検知に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
        currentOperation = nil
    }
    
    private func loadRecentAnomalies() async {
        await detectAnomalies()
    }
    
    // MARK: - 相関分析メソッド
    
    func analyzeCorrelations() async {
        guard !isLoading, selectedVariables.count >= 2 else { return }
        
        isLoading = true
        currentOperation = "相関を分析中..."
        
        do {
            let result = try await projectAIUseCase.analyzeCorrelations(
                projectId: project.id,
                variables: selectedVariables,
                correlationType: correlationType,
                timeRange: nil
            )
            
            correlationResults = result.correlationMatrix
            correlationInsights = result.insights
            
        } catch {
            errorMessage = "相関分析に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
        currentOperation = nil
    }
    
    private func loadDefaultCorrelations() async {
        if selectedVariables.count >= 2 {
            await analyzeCorrelations()
        }
    }
    
    // MARK: - クラスタリング分析メソッド
    
    func performClustering() async {
        guard !isLoading, !selectedFeatures.isEmpty else { return }
        
        isLoading = true
        currentOperation = "クラスタリング中..."
        
        do {
            let result = try await projectAIUseCase.performClusteringAnalysis(
                projectId: project.id,
                clusteringType: clusteringType,
                targetClusters: targetClusters,
                features: selectedFeatures
            )
            
            clusters = result.clusters
            clusterQualityMetrics = result.qualityMetrics
            clusteringInsights = result.insights
            
        } catch {
            errorMessage = "クラスタリング分析に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
        currentOperation = nil
    }
    
    // MARK: - 影響度分析メソッド
    
    func analyzeImpact() async {
        guard !isLoading, let scenario = selectedScenario else { return }
        
        isLoading = true
        currentOperation = "影響度を分析中..."
        
        do {
            let result = try await projectAIUseCase.analyzeImpact(
                projectId: project.id,
                changeScenario: scenario,
                impactScope: impactScope
            )
            
            impactAnalysisResult = result
            
        } catch {
            errorMessage = "影響度分析に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
        currentOperation = nil
    }
    
    // MARK: - レポート生成
    
    func generateAnalysisReport() async {
        isLoading = true
        currentOperation = "分析レポートを生成中..."
        
        do {
            // TODO: 包括的な分析レポートの生成
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒のシミュレーション
        } catch {
            errorMessage = "レポート生成に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
        currentOperation = nil
    }
    
    // MARK: - エラーハンドリング
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - 設定初期化
    
    private func setupDefaultVariables() {
        availableVariables = [
            AnalysisVariable(name: "活動頻度", type: .continuous, description: "1日あたりの活動回数", unit: "回/日"),
            AnalysisVariable(name: "参加者数", type: .continuous, description: "アクティブな参加者数", unit: "人"),
            AnalysisVariable(name: "コンテンツ量", type: .continuous, description: "生成されたコンテンツの量", unit: "文字"),
            AnalysisVariable(name: "品質スコア", type: .continuous, description: "コンテンツの品質評価", unit: "0-1"),
            AnalysisVariable(name: "エンゲージメント", type: .continuous, description: "参加者のエンゲージメント度", unit: "0-1")
        ]
        
        // デフォルトで最初の3つを選択
        selectedVariables = Array(availableVariables.prefix(3))
    }
    
    private func setupDefaultFeatures() {
        availableFeatures = [
            ClusteringFeature(name: "活動パターン", type: .numerical, weight: 1.0, description: "時系列活動パターン"),
            ClusteringFeature(name: "コミュニケーション頻度", type: .numerical, weight: 0.8, description: "参加者間のコミュニケーション"),
            ClusteringFeature(name: "タスク完了率", type: .numerical, weight: 0.9, description: "タスクの完了割合"),
            ClusteringFeature(name: "品質傾向", type: .numerical, weight: 0.7, description: "品質の傾向"),
            ClusteringFeature(name: "テーマ分布", type: .numerical, weight: 0.6, description: "扱われるテーマの分布")
        ]
        
        // デフォルトで最初の3つを選択
        selectedFeatures = Array(availableFeatures.prefix(3))
    }
    
    private func setupDefaultScenarios() {
        availableScenarios = [
            ChangeScenario(
                id: "team_expansion",
                name: "チーム拡大",
                type: .teamRestructure,
                description: "チームメンバーを20%増員する",
                parameters: ["increase_rate": "0.2"],
                timeline: DateInterval(start: Date(), duration: 86400 * 30)
            ),
            ChangeScenario(
                id: "process_automation",
                name: "プロセス自動化",
                type: .processChange,
                description: "定型タスクの50%を自動化する",
                parameters: ["automation_rate": "0.5"],
                timeline: DateInterval(start: Date(), duration: 86400 * 60)
            ),
            ChangeScenario(
                id: "new_technology",
                name: "新技術導入",
                type: .technologyAdoption,
                description: "AI支援ツールを導入する",
                parameters: ["adoption_phase": "gradual"],
                timeline: DateInterval(start: Date(), duration: 86400 * 90)
            )
        ]
        
        selectedScenario = availableScenarios.first
    }
}

// MARK: - 分析設定

struct AnalysisSettings {
    var defaultTimeHorizon: TimeInterval = 86400 * 30 // 30日
    var defaultConfidenceLevel: Double = 0.8
    var enableAutoRefresh: Bool = true
    var refreshInterval: TimeInterval = 3600 // 1時間
    var maxHistoryItems: Int = 50
    var enableNotifications: Bool = true
    var notificationThreshold: AnomalySeverity = .high
}

// MARK: - ヘルパー拡張

extension PredictionType {
    var icon: String {
        switch self {
        case .activityLevel: return "chart.bar"
        case .teamEngagement: return "person.2"
        case .projectCompletion: return "checkmark.circle"
        case .resourceRequirement: return "cpu"
        case .qualityMetrics: return "star"
        case .riskFactors: return "exclamationmark.shield"
        }
    }
}

extension AnomalyDetectionType {
    var icon: String {
        switch self {
        case .activityPatterns: return "waveform.path.ecg"
        case .communicationFrequency: return "message"
        case .productivityMetrics: return "gauge"
        case .qualityIndicators: return "checkmark.seal"
        case .resourceUsage: return "cpu"
        case .timelineDeviations: return "clock"
        }
    }
}

extension ClusteringType {
    var description: String {
        switch self {
        case .kMeans: return "データを指定された数のクラスターに分割"
        case .hierarchical: return "階層的にクラスターを形成"
        case .dbscan: return "密度ベースでクラスターを検出"
        case .gaussianMixture: return "確率分布を使用してクラスタリング"
        }
    }
}

extension ChangeType {
    var icon: String {
        switch self {
        case .teamRestructure: return "person.2.circle"
        case .processChange: return "gearshape.2"
        case .technologyAdoption: return "laptopcomputer"
        case .resourceReallocation: return "arrow.triangle.swap"
        case .scopeModification: return "scope"
        case .timelineAdjustment: return "calendar"
        }
    }
}