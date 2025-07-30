import Foundation

// MARK: - 異常検知エンジン

@MainActor
class AnomalyDetectionEngine: BaseAnalyticsEngine<AnomalyDetectionInput, AnomalyDetectionResult, AnomalyDetectionConfig> {
    
    typealias Input = AnomalyDetectionInput
    typealias Output = AnomalyDetectionResult
    typealias Configuration = AnomalyDetectionConfig
    
    // MARK: - 分析専用依存関係
    private let llmService: LLMServiceProtocol
    
    init(ragService: RAGServiceProtocol, llmService: LLMServiceProtocol) {
        self.llmService = llmService
        
        super.init(
            engineName: "AnomalyDetectionEngine",
            supportedOperations: [
                "detectStatisticalAnomalies",
                "identifyPatternBreaks",
                "analyzeOutliers",
                "performRootCauseAnalysis"
            ],
            defaultConfiguration: AnomalyDetectionConfig()
        )
    }
    
    // MARK: - プロトコル実装
    // BaseAnalyticsEngineのプロパティを直接継承
    
    override func execute(input: AnomalyDetectionInput, configuration: AnomalyDetectionConfig?) async throws -> AnalyticsResult<AnomalyDetectionResult> {
        return try await executeWithFramework(
            input: input,
            configuration: configuration,
            operation: "detectStatisticalAnomalies"
        )
    }
    
    override func validateInput(_ input: AnomalyDetectionInput) async throws {
        guard let timeRange = input.timeRange, timeRange.duration > 0 else {
            throw AnalyticsEngineError.invalidInput(engineName, "Time range must be specified and positive")
        }
        
        let maxAnalysisPeriod: TimeInterval = 86400 * 365 // 1年
        guard timeRange.duration <= maxAnalysisPeriod else {
            throw AnalyticsEngineError.invalidInput(engineName, "Time range too large (max 1 year)")
        }
    }
    
    override func estimateExecutionTime(for input: AnomalyDetectionInput) -> TimeInterval {
        let baseTime: TimeInterval = 3.0
        let sensitivityMultiplier = input.sensitivity.executionMultiplier
        let typeMultiplier = input.detectionType.complexityMultiplier
        return baseTime * sensitivityMultiplier * typeMultiplier
    }
    
    // MARK: - 分析実装
    
    override func performAnalysis(input: AnomalyDetectionInput, configuration: AnomalyDetectionConfig) async throws -> AnomalyDetectionResult {
        
        // 時系列データを収集
        let timeSeriesData = try await collectTimeSeriesData(
            projectId: input.projectId,
            detectionType: input.detectionType,
            timeRange: input.timeRange
        )
        
        // ベースライン（正常パターン）を確立
        let baseline = try await establishBaseline(
            data: timeSeriesData,
            detectionType: input.detectionType,
            config: configuration
        )
        
        // 異常値を検出
        let anomalies = try await detectAnomalies(
            data: timeSeriesData,
            baseline: baseline,
            sensitivity: input.sensitivity,
            config: configuration
        )
        
        // 異常の重要度を評価
        let prioritizedAnomalies = try await prioritizeAnomalies(
            anomalies: anomalies,
            context: input.detectionType
        )
        
        // 根本原因を分析
        let rootCauseAnalysis = try await performRootCauseAnalysis(
            anomalies: prioritizedAnomalies,
            projectId: input.projectId,
            timeSeriesData: timeSeriesData
        )
        
        return AnomalyDetectionResult(
            projectId: input.projectId,
            detectionType: input.detectionType,
            timeRange: input.timeRange ?? DateInterval(start: Date().addingTimeInterval(-86400 * 30), end: Date()),
            anomalies: prioritizedAnomalies,
            baseline: baseline,
            sensitivity: input.sensitivity,
            rootCauseAnalysis: rootCauseAnalysis,
            totalDataPoints: timeSeriesData.count,
            detectionAccuracy: calculateDetectionAccuracy(anomalies, baseline),
            generatedAt: Date()
        )
    }
    
    override func calculateQualityMetrics(input: AnomalyDetectionInput, output: AnomalyDetectionResult, configuration: AnomalyDetectionConfig) async throws -> QualityMetrics {
        
        let dataCompleteness = calculateDataCompleteness(output.totalDataPoints, configuration.minimumDataPoints)
        let detectionAccuracy = output.detectionAccuracy
        let baselineReliability = calculateBaselineReliability(output.baseline)
        
        return QualityMetrics(
            dataCompleteness: dataCompleteness,
            dataAccuracy: detectionAccuracy,
            resultReliability: baselineReliability,
            statisticalSignificance: calculateStatisticalSignificance(output.anomalies)
        )
    }
    
    override func identifyWarnings(input: AnomalyDetectionInput, output: AnomalyDetectionResult) async throws -> [AnalyticsWarning] {
        var warnings: [AnalyticsWarning] = []
        
        // データ不足の警告
        if output.totalDataPoints < 100 {
            warnings.append(AnalyticsWarning(
                level: .warning,
                message: "データポイントが少ないため、検知精度が低下する可能性があります（\(output.totalDataPoints)件）",
                recommendation: "より長い期間のデータを使用することを推奨します",
                affectedMetrics: ["detectionAccuracy", "falsePositiveRate"]
            ))
        }
        
        // 高感度設定の警告
        if input.sensitivity == .high && output.anomalies.count > 50 {
            warnings.append(AnalyticsWarning(
                level: .info,
                message: "高感度設定により多数の異常が検出されました（\(output.anomalies.count)件）",
                recommendation: "感度を調整するか、検出タイプを絞り込むことを検討してください",
                affectedMetrics: ["falsePositiveRate"]
            ))
        }
        
        // 異常なしの警告
        if output.anomalies.isEmpty {
            warnings.append(AnalyticsWarning(
                level: .info,
                message: "指定期間内で異常は検出されませんでした",
                recommendation: "感度設定を上げるか、検出期間を延長することを検討してください",
                affectedMetrics: ["coverage"]
            ))
        }
        
        return warnings
    }
    
    // MARK: - 内部実装メソッド
    
    private func collectTimeSeriesData(
        projectId: UUID,
        detectionType: AnomalyDetectionType,
        timeRange: DateInterval?
    ) async throws -> [TimeSeriesDataPoint] {
        // TODO: 実際の時系列データ収集実装
        // プロジェクトの活動ログ、メトリクス、イベントデータなどを収集
        return []
    }
    
    private func establishBaseline(
        data: [TimeSeriesDataPoint],
        detectionType: AnomalyDetectionType,
        config: AnomalyDetectionConfig
    ) async throws -> BaselinePattern {
        // TODO: 統計的ベースライン確立の実装
        // 移動平均、標準偏差、季節性パターンなどを計算
        return BaselinePattern(
            mean: 0.0,
            standardDeviation: 1.0,
            patterns: []
        )
    }
    
    private func detectAnomalies(
        data: [TimeSeriesDataPoint],
        baseline: BaselinePattern,
        sensitivity: AnomalySensitivity,
        config: AnomalyDetectionConfig
    ) async throws -> [Anomaly] {
        // TODO: 異常検知アルゴリズムの実装
        // Z-Score、IQR、Isolation Forest、LOFなどの手法を使用
        return []
    }
    
    private func prioritizeAnomalies(
        anomalies: [Anomaly],
        context: AnomalyDetectionType
    ) async throws -> [Anomaly] {
        // TODO: 異常の重要度評価と優先順位付け
        // ビジネスインパクト、発生頻度、深刻度などを考慮
        return anomalies.sorted { $0.severity.priority > $1.severity.priority }
    }
    
    private func performRootCauseAnalysis(
        anomalies: [Anomaly],
        projectId: UUID,
        timeSeriesData: [TimeSeriesDataPoint]
    ) async throws -> [RootCauseAnalysis] {
        // TODO: 根本原因分析の実装
        // 相関分析、時系列パターン分析、外部要因の検討など
        return []
    }
    
    private func calculateDetectionAccuracy(_ anomalies: [Anomaly], _ baseline: BaselinePattern) -> Double {
        // TODO: 検知精度の統計的計算
        return 0.85
    }
    
    private func calculateDataCompleteness(_ dataPoints: Int, _ minimumRequired: Int) -> Double {
        return min(Double(dataPoints) / Double(minimumRequired), 1.0)
    }
    
    private func calculateBaselineReliability(_ baseline: BaselinePattern) -> Double {
        // TODO: ベースラインの信頼性評価
        return 0.8
    }
    
    private func calculateStatisticalSignificance(_ anomalies: [Anomaly]) -> Double? {
        // TODO: 統計的有意性検定
        guard !anomalies.isEmpty else { return nil }
        return 0.01
    }
}

// MARK: - 異常検知用データ型

struct AnomalyDetectionInput {
    let projectId: UUID
    let detectionType: AnomalyDetectionType
    let sensitivity: AnomalySensitivity
    let timeRange: DateInterval?
}

struct AnomalyDetectionConfig {
    let algorithm: AnomalyDetectionAlgorithm
    let minimumDataPoints: Int
    let outlierThreshold: Double
    let enableSeasonalityDetection: Bool
    let maxAnomaliesPerPeriod: Int
    
    init(
        algorithm: AnomalyDetectionAlgorithm = .statistical,
        minimumDataPoints: Int = 50,
        outlierThreshold: Double = 2.5, // 標準偏差の倍数
        enableSeasonalityDetection: Bool = true,
        maxAnomaliesPerPeriod: Int = 100
    ) {
        self.algorithm = algorithm
        self.minimumDataPoints = minimumDataPoints
        self.outlierThreshold = outlierThreshold
        self.enableSeasonalityDetection = enableSeasonalityDetection
        self.maxAnomaliesPerPeriod = maxAnomaliesPerPeriod
    }
}

enum AnomalyDetectionAlgorithm: String, CaseIterable {
    case statistical = "statistical"
    case isolationForest = "isolation_forest"
    case localOutlierFactor = "lof"
    case autoencoder = "autoencoder"
}

extension AnomalySensitivity {
    var executionMultiplier: Double {
        switch self {
        case .low: return 0.8
        case .medium: return 1.0
        case .high: return 1.3
        case .veryHigh: return 1.6
        }
    }
}

extension AnomalyDetectionType {
    var complexityMultiplier: Double {
        switch self {
        case .activityPatterns: return 1.0
        case .communicationFrequency: return 1.1
        case .productivityMetrics: return 1.3
        case .qualityIndicators: return 1.2
        case .resourceUsage: return 1.4
        case .timelineDeviations: return 1.5
        }
    }
}