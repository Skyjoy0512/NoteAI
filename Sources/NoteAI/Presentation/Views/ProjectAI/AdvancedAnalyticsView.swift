import SwiftUI
import Charts

// MARK: - Advanced Analytics View Dependencies
// Note: Type definitions are imported from Core/Models/AdvancedAnalyticsTypes.swift

// MARK: - 高度な分析機能ビュー

struct AdvancedAnalyticsView: View {
    @StateObject private var viewModel: AdvancedAnalyticsViewModel
    @State private var selectedAnalysisType: AdvancedAnalysisType = .predictive
    
    init(project: Project, projectAIUseCase: ProjectAIUseCaseProtocol) {
        self._viewModel = StateObject(wrappedValue: AdvancedAnalyticsViewModel(
            project: project,
            projectAIUseCase: projectAIUseCase
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分析タイプ選択
                AnalysisTypeSelector(
                    selectedType: $selectedAnalysisType,
                    availableTypes: AdvancedAnalysisType.allCases
                )
                
                // メインコンテンツ
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedAnalysisType {
                        case .predictive:
                            PredictiveAnalysisView(viewModel: viewModel)
                        case .anomaly:
                            AnomalyDetectionView(viewModel: viewModel)
                        case .correlation:
                            CorrelationAnalysisView(viewModel: viewModel)
                        case .clustering:
                            ClusteringAnalysisView(viewModel: viewModel)
                        case .impact:
                            ImpactAnalysisView(viewModel: viewModel)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refreshAnalysis(for: selectedAnalysisType)
                }
            }
            .navigationTitle("高度な分析")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        Button("分析設定") {
                            viewModel.showingAnalysisSettings = true
                        }
                        Button("レポート生成") {
                            Task {
                                await viewModel.generateAnalysisReport()
                            }
                        }
                        Button("データエクスポート") {
                            viewModel.showingExportOptions = true
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                AdvancedAnalyticsLoadingOverlay(
                    currentOperation: viewModel.currentOperation
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
        .sheet(isPresented: $viewModel.showingAnalysisSettings) {
            AnalysisSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingExportOptions) {
            AnalyticsExportView(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadInitialAnalytics()
            }
        }
        .onChange(of: selectedAnalysisType) { oldValue, newType in
            Task {
                await viewModel.switchAnalysisType(to: newType)
            }
        }
    }
}

// MARK: - 分析タイプ選択器

struct AnalysisTypeSelector: View {
    @Binding var selectedType: AdvancedAnalysisType
    let availableTypes: [AdvancedAnalysisType]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(availableTypes, id: \.self) { type in
                    VStack(spacing: 6) {
                        Image(systemName: type.iconName)
                            .font(.title2)
                        Text(type.displayName)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(selectedType == type ? .accentColor : .secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background {
                        if selectedType == type {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.tint.opacity(0.15))
                        }
                    }
                    .onTapGesture {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

// MARK: - 予測分析ビュー

struct PredictiveAnalysisView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 予測タイプ選択
            PredictionTypeSelector(
                selectedType: $viewModel.selectedPredictionType,
                onPredict: { type in
                    Task {
                        await viewModel.generatePrediction(type: type)
                    }
                }
            )
            
            // 予測結果表示
            if let prediction = viewModel.currentPrediction {
                PredictionResultCard(prediction: prediction)
            }
            
            // 影響要因分析
            if !viewModel.influencingFactors.isEmpty {
                InfluencingFactorsCard(factors: viewModel.influencingFactors)
            }
            
            // 予測履歴
            if !viewModel.predictionHistory.isEmpty {
                PredictionHistoryCard(history: viewModel.predictionHistory)
            }
        }
    }
}

// MARK: - 異常検知ビュー

struct AnomalyDetectionView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 検知設定
            AnomalyDetectionSettings(
                detectionType: $viewModel.selectedAnomalyType,
                sensitivity: Binding(
                    get: { viewModel.anomalySensitivity.threshold },
                    set: { newValue in
                        // Convert Double back to closest AnomalySensitivity enum case
                        if newValue >= 2.75 {
                            viewModel.anomalySensitivity = .low
                        } else if newValue >= 2.25 {
                            viewModel.anomalySensitivity = .medium
                        } else if newValue >= 1.75 {
                            viewModel.anomalySensitivity = .high
                        } else {
                            viewModel.anomalySensitivity = .veryHigh
                        }
                    }
                ),
                onDetect: {
                    Task {
                        await viewModel.detectAnomalies()
                    }
                }
            )
            
            // 検知結果
            if !viewModel.detectedAnomalies.isEmpty {
                AnomaliesOverviewCard(anomalies: viewModel.detectedAnomalies)
            }
            
            // 異常詳細リスト
            if !viewModel.detectedAnomalies.isEmpty {
                AnomalyDetailsList(
                    anomalies: viewModel.detectedAnomalies,
                    onAnomalyTapped: { anomaly in
                        viewModel.selectedAnomaly = anomaly
                        viewModel.showingAnomalyDetail = true
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showingAnomalyDetail) {
            if let anomaly = viewModel.selectedAnomaly {
                AnomalyDetailView(anomaly: anomaly)
            }
        }
    }
}

// MARK: - 相関分析ビュー

struct CorrelationAnalysisView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 変数選択
            CorrelationVariableSelector(
                selectedVariables: Binding(
                    get: { Set(viewModel.selectedVariables.map(\.name)) },
                    set: { names in
                        // Convert Set<String> back to [AnalysisVariable]
                        viewModel.selectedVariables = viewModel.availableVariables.filter { names.contains($0.name) }
                    }
                ),
                correlationType: $viewModel.correlationType,
                onAnalyze: {
                    Task {
                        await viewModel.analyzeCorrelations()
                    }
                }
            )
            
            // 相関マトリクス
            if !viewModel.correlationResults.isEmpty {
                CorrelationMatrixView(correlations: viewModel.correlationResults.map { pair in
                    CorrelationResult(
                        variable1: pair.variable1.name,
                        variable2: pair.variable2.name,
                        coefficient: pair.coefficient,
                        pValue: 0.05 // デフォルト値
                    )
                })
            }
            
            // 有意な相関の洞察
            if !viewModel.correlationInsights.isEmpty {
                CorrelationInsightsCard(insights: viewModel.correlationInsights)
            }
        }
    }
}

// MARK: - クラスタリング分析ビュー

struct ClusteringAnalysisView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // クラスタリング設定
            ClusteringSettings(
                clusteringType: $viewModel.clusteringType,
                features: Binding(
                    get: { Set(viewModel.selectedFeatures.map(\.name)) },
                    set: { names in
                        viewModel.selectedFeatures = viewModel.availableFeatures.filter { names.contains($0.name) }
                    }
                ),
                targetClusters: Binding(
                    get: { viewModel.targetClusters ?? 3 },
                    set: { viewModel.targetClusters = $0 }
                ),
                onAnalyze: {
                    Task {
                        await viewModel.performClustering()
                    }
                }
            )
            
            // クラスタリング結果
            if !viewModel.clusters.isEmpty {
                ClusteringResultsView(
                    clusters: viewModel.clusters.map { cluster in
                        ClusterResult(
                            clusterID: Int(cluster.id) ?? 0,
                            size: cluster.size,
                            centroid: cluster.centroid,
                            characteristics: [:]
                        )
                    },
                    qualityMetrics: viewModel.clusterQualityMetrics ?? ClusterQualityMetrics(
                        silhouetteScore: 0.0,
                        inertia: 0.0,
                        calinskiHarabasz: 0.0
                    )
                )
            }
            
            // ビジネス洞察
            if !viewModel.clusteringInsights.isEmpty {
                ClusteringInsightsCard(insights: viewModel.clusteringInsights)
            }
        }
    }
}

// MARK: - 影響度分析ビュー

struct ImpactAnalysisView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // シナリオ設定
            ImpactScenarioSelector(
                scenario: Binding(
                    get: { 
                        // Convert ChangeScenario to ImpactScenario from Core
                        if let changeScenario = viewModel.selectedScenario {
                            // Map to existing ImpactScenario cases from Core
                            switch changeScenario.type {
                            case .teamRestructure:
                                return .optimistic
                            case .processChange:
                                return .realistic
                            default:
                                return .pessimistic
                            }
                        } else {
                            return .realistic
                        }
                    },
                    set: { (impactScenario: ImpactScenario) in
                        // Convert ImpactScenario back to ChangeScenario
                        let changeType: ChangeType
                        let name: String
                        let description: String
                        
                        switch impactScenario {
                        case .optimistic:
                            changeType = .teamRestructure
                            name = "チーム拡大"
                            description = "チームメンバーを20%増員する"
                        case .realistic:
                            changeType = .processChange
                            name = "プロセス自動化" 
                            description = "定型タスクの50%を自動化する"
                        case .pessimistic:
                            changeType = .technologyAdoption
                            name = "新技術導入"
                            description = "AI支援ツールを導入する"
                        }
                        
                        viewModel.selectedScenario = ChangeScenario(
                            id: UUID().uuidString,
                            name: name,
                            type: changeType,
                            description: description,
                            parameters: [:],
                            timeline: DateInterval(start: Date(), duration: 86400 * 30)
                        )
                    }
                ),
                impactScope: $viewModel.impactScope,
                onAnalyze: {
                    Task {
                        await viewModel.analyzeImpact()
                    }
                }
            )
            
            // 影響度結果
            if let impactResult = viewModel.impactAnalysisResult {
                ImpactAnalysisResultView(result: impactResult)
            }
            
            // リスクと機会
            if let impactResult = viewModel.impactAnalysisResult {
                RiskOpportunityView(
                    risks: impactResult.riskAssessment.risks.map { risk in
                        RiskAssessmentItem(
                            description: risk.description,
                            probability: risk.probability,
                            impact: risk.impact.numericValue
                        )
                    },
                    opportunities: impactResult.opportunityAssessment.opportunities.map { opportunity in
                        OpportunityAssessmentItem(
                            description: opportunity.description,
                            probability: opportunity.likelihood,
                            benefit: opportunity.benefit.numericValue
                        )
                    }
                )
            }
            
            // 緩和策
            if let impactResult = viewModel.impactAnalysisResult {
                MitigationStrategiesCard(strategies: impactResult.mitigationStrategies.map { strategy in
                    MitigationStrategyItem(
                        description: strategy.description,
                        effectiveness: strategy.effectiveness,
                        cost: strategy.cost.rawValue == "low" ? 0.25 : 
                              strategy.cost.rawValue == "medium" ? 0.5 :
                              strategy.cost.rawValue == "high" ? 0.75 : 1.0
                    )
                })
            }
        }
    }
}

// MARK: - 高度分析ローディングオーバーレイ

struct AdvancedAnalyticsLoadingOverlay: View {
    let currentOperation: String?
    
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
                
                if let operation = currentOperation {
                    Text(operation)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - 高度分析タイプ定義

enum AdvancedAnalysisType: String, CaseIterable {
    case predictive = "predictive"
    case anomaly = "anomaly"
    case correlation = "correlation"
    case clustering = "clustering"
    case impact = "impact"
    
    var displayName: String {
        switch self {
        case .predictive: return "予測分析"
        case .anomaly: return "異常検知"
        case .correlation: return "相関分析"
        case .clustering: return "クラスタリング"
        case .impact: return "影響度分析"
        }
    }
    
    var iconName: String {
        switch self {
        case .predictive: return "chart.line.uptrend.xyaxis"
        case .anomaly: return "exclamationmark.triangle"
        case .correlation: return "arrow.triangle.2.circlepath"
        case .clustering: return "circle.hexagongrid"
        case .impact: return "target"
        }
    }
}

// MARK: - Placeholder Components for Missing Views

// MARK: - Predictive Analysis Components
struct PredictionTypeSelector: View {
    @Binding var selectedType: PredictionType
    let onPredict: (PredictionType) -> Void
    
    var body: some View {
        VStack {
            Text("予測タイプ選択")
                .font(.headline)
            HStack {
                ForEach(PredictionType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        selectedType = type
                        onPredict(type)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
}

struct PredictionResultCard: View {
    let prediction: PredictiveAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予測結果")
                .font(.headline)
            if let firstPrediction = prediction.predictions.first {
                Text("予測値: \(firstPrediction.predictedValue, specifier: "%.2f")")
            }
            Text("信頼度: \(prediction.confidence * 100, specifier: "%.1f")%")
            Text("予測タイプ: \(prediction.predictionType.displayName)")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct InfluencingFactorsCard: View {
    let factors: [InfluencingFactor]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("影響要因")
                .font(.headline)
            ForEach(Array(factors.prefix(3)), id: \.name) { factor in
                HStack {
                    Text(factor.name)
                    Spacer()
                    Text("\(factor.impact, specifier: "%.1f")%")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PredictionHistoryCard: View {
    let history: [PredictiveAnalysisResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予測履歴")
                .font(.headline)
            Text("\(history.count)件の予測履歴")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Anomaly Detection Components
struct AnomalyDetectionSettings: View {
    @Binding var detectionType: AnomalyDetectionType
    @Binding var sensitivity: Double
    let onDetect: () -> Void
    
    var body: some View {
        VStack {
            Text("異常検知設定")
                .font(.headline)
            Picker("検知タイプ", selection: $detectionType) {
                ForEach(AnomalyDetectionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack {
                Text("感度: \(sensitivity, specifier: "%.1f")")
                Slider(value: $sensitivity, in: 0.1...1.0)
            }
            
            Button("異常検知実行", action: onDetect)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AnomaliesOverviewCard: View {
    let anomalies: [Anomaly]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("検知された異常")
                .font(.headline)
            Text("\(anomalies.count)件の異常を検知")
                .foregroundColor(anomalies.isEmpty ? .green : .red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AnomalyDetailsList: View {
    let anomalies: [Anomaly]
    let onAnomalyTapped: (Anomaly) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("異常詳細")
                .font(.headline)
            ForEach(Array(anomalies.prefix(5)), id: \.id) { anomaly in
                Button(action: { onAnomalyTapped(anomaly) }) {
                    HStack {
                        Text(anomaly.type.rawValue)
                        Spacer()
                        Text("スコア: \(anomaly.deviationScore, specifier: "%.2f")")
                        Image(systemName: "chevron.right")
                    }
                    .padding(8)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AnomalyDetailView: View {
    let anomaly: Anomaly
    @Environment(\.dismiss) private var dismiss
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("異常の詳細")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("タイプ: \(anomaly.type.rawValue)")
                    Text("スコア: \(anomaly.deviationScore, specifier: "%.3f")")
                    Text("重要度: \(anomaly.severity.rawValue)")
                    Text("発生時刻: \(anomaly.timestamp, formatter: Self.dateFormatter)")
                    Text("説明: \(anomaly.description)")
                    
                    if !anomaly.affectedMetrics.isEmpty {
                        Text("影響を受けた指標: \(anomaly.affectedMetrics.joined(separator: ", "))")
                    }
                    
                    if !anomaly.potentialCauses.isEmpty {
                        Text("考えられる原因:")
                        ForEach(anomaly.potentialCauses, id: \.self) { cause in
                            Text("• \(cause)")
                                .padding(.leading, 16)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("異常詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Correlation Analysis Components
struct CorrelationVariableSelector: View {
    @Binding var selectedVariables: Set<String>
    @Binding var correlationType: CorrelationType
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack {
            Text("相関分析設定")
                .font(.headline)
            Text("\(selectedVariables.count)個の変数を選択")
            Picker("相関タイプ", selection: $correlationType) {
                ForEach(CorrelationType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("相関分析実行", action: onAnalyze)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CorrelationMatrixView: View {
    let correlations: [CorrelationResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相関マトリクス")
                .font(.headline)
            Text("\(correlations.count)個の相関を分析")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CorrelationInsightsCard: View {
    let insights: [CorrelationInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相関分析の洞察")
                .font(.headline)
            ForEach(Array(insights.prefix(3)), id: \.id) { insight in
                Text("• \(insight.description)")
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Clustering Analysis Components
struct ClusteringSettings: View {
    @Binding var clusteringType: ClusteringType
    @Binding var features: Set<String>
    @Binding var targetClusters: Int
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack {
            Text("クラスタリング設定")
                .font(.headline)
            
            Picker("アルゴリズム", selection: $clusteringType) {
                ForEach(ClusteringType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Stepper("クラスタ数: \(targetClusters)", value: $targetClusters, in: 2...10)
            
            Button("クラスタリング実行", action: onAnalyze)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ClusteringResultsView: View {
    let clusters: [ClusterResult]
    let qualityMetrics: ClusterQualityMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クラスタリング結果")
                .font(.headline)
            Text("\(clusters.count)個のクラスタを生成")
            Text("品質スコア: \(qualityMetrics.silhouetteScore, specifier: "%.3f")")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ClusteringInsightsCard: View {
    let insights: [ClusteringInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クラスタリング洞察")
                .font(.headline)
            ForEach(Array(insights.prefix(3)), id: \.id) { insight in
                Text("• \(insight.description)")
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Impact Analysis Type Extensions
// Use ImpactScenario from Core layer

// MARK: - Impact Analysis Components
struct ImpactScenarioSelector: View {
    @Binding var scenario: ImpactScenario
    @Binding var impactScope: ImpactScope
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack {
            Text("影響度分析設定")
                .font(.headline)
            
            Picker("シナリオ", selection: $scenario) {
                ForEach(ImpactScenario.allCases, id: \.self) { scenario in
                    Text(scenario.displayName).tag(scenario)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Picker("分析範囲", selection: $impactScope) {
                ForEach(ImpactScope.allCases, id: \.self) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("影響度分析実行", action: onAnalyze)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ImpactAnalysisResultView: View {
    let result: ImpactAnalysisResult
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("影響度分析結果")
                .font(.headline)
            Text("総合影響度: \(result.overallImpact, specifier: "%.1f")%")
            Text("分析完了時刻: \(result.completedAt, formatter: Self.dateFormatter)")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RiskOpportunityView: View {
    let risks: [RiskAssessmentItem]
    let opportunities: [OpportunityAssessmentItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("リスクと機会")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("リスク (\(risks.count))")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    ForEach(Array(risks.prefix(2)), id: \.id) { risk in
                        Text("• \(risk.description)")
                            .font(.caption)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("機会 (\(opportunities.count))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    ForEach(Array(opportunities.prefix(2)), id: \.id) { opportunity in
                        Text("• \(opportunity.description)")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MitigationStrategiesCard: View {
    let strategies: [MitigationStrategyItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("緩和策")
                .font(.headline)
            ForEach(Array(strategies.prefix(3)), id: \.id) { strategy in
                HStack {
                    Image(systemName: "shield")
                        .foregroundColor(.blue)
                    Text(strategy.description)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Settings and Export Views
struct AnalysisSettingsView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("分析設定") {
                    Text("分析設定の実装")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("分析設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

struct AnalyticsExportView: View {
    @ObservedObject var viewModel: AdvancedAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("分析データエクスポート")
                    .font(.headline)
                    .padding()
                
                Text("エクスポート機能の実装")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("データエクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// プレビュー用のモック実装
#if DEBUG
struct AdvancedAnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockProject = Project(
            id: UUID(),
            name: "Advanced Analytics Test",
            description: "高度分析のテストプロジェクト",
            coverImageData: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: ProjectMetadata()
        )
        
        AdvancedAnalyticsView(
            project: mockProject,
            projectAIUseCase: MockProjectAIUseCase()
        )
    }
}
#endif