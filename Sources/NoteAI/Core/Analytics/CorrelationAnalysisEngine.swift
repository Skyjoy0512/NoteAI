import Foundation

// MARK: - 相関分析エンジン

@MainActor
class CorrelationAnalysisEngine: BaseAnalyticsEngine<CorrelationAnalysisInput, CorrelationAnalysisResult, CorrelationAnalysisConfig> {
    
    typealias Input = CorrelationAnalysisInput
    typealias Output = CorrelationAnalysisResult
    typealias Configuration = CorrelationAnalysisConfig
    
    // MARK: - 分析専用依存関係
    private let llmService: LLMServiceProtocol
    
    init(ragService: RAGServiceProtocol, llmService: LLMServiceProtocol) {
        self.llmService = llmService
        
        super.init(
            engineName: "CorrelationAnalysisEngine",
            supportedOperations: [
                "calculatePearsonCorrelation",
                "calculateSpearmanCorrelation",
                "calculateKendallTau",
                "performSignificanceTest",
                "generateCausalHypotheses"
            ],
            defaultConfiguration: CorrelationAnalysisConfig()
        )
    }
    
    // MARK: - プロトコル実装
    // BaseAnalyticsEngineのプロパティを直接継承
    
    override func execute(input: CorrelationAnalysisInput, configuration: CorrelationAnalysisConfig?) async throws -> AnalyticsResult<CorrelationAnalysisResult> {
        return try await executeWithFramework(
            input: input,
            configuration: configuration,
            operation: getOperationName(for: input.correlationType)
        )
    }
    
    override func validateInput(_ input: CorrelationAnalysisInput) async throws {
        guard input.variables.count >= 2 else {
            throw AnalyticsEngineError.invalidInput(engineName, "At least 2 variables required for correlation analysis")
        }
        
        guard input.variables.count <= 20 else {
            throw AnalyticsEngineError.invalidInput(engineName, "Too many variables (max 20)")
        }
    }
    
    override func estimateExecutionTime(for input: CorrelationAnalysisInput) -> TimeInterval {
        let baseTime: TimeInterval = 2.0
        let variableComplexity = Double(input.variables.count * input.variables.count) / 4.0 // n^2 complexity
        let typeMultiplier = input.correlationType.complexityMultiplier
        return baseTime * variableComplexity * typeMultiplier
    }
    
    // MARK: - 分析実装
    
    override func performAnalysis(input: CorrelationAnalysisInput, configuration: CorrelationAnalysisConfig) async throws -> CorrelationAnalysisResult {
        
        // 各変数のデータを収集
        var variableData: [AnalysisVariable: [DataPoint]] = [:]
        for variable in input.variables {
            let data = try await collectVariableData(
                projectId: input.projectId,
                variable: variable,
                timeRange: input.timeRange,
                config: configuration
            )
            variableData[variable] = data
        }
        
        // データ品質を検証
        try await validateDataQuality(variableData, configuration)
        
        // 相関係数を計算
        let correlationMatrix = try await calculateCorrelationMatrix(
            data: variableData,
            type: input.correlationType,
            config: configuration
        )
        
        // 統計的有意性を検定
        let significanceTests = try await performSignificanceTests(
            correlations: correlationMatrix,
            dataSize: variableData.values.first?.count ?? 0,
            config: configuration
        )
        
        // 因果関係の仮説を生成
        let causalHypotheses = try await generateCausalHypotheses(
            correlations: correlationMatrix,
            variables: input.variables,
            significanceTests: significanceTests
        )
        
        // 実用的な洞察を抽出
        let insights = try await extractCorrelationInsights(
            correlations: correlationMatrix,
            significance: significanceTests,
            hypotheses: causalHypotheses,
            variables: input.variables
        )
        
        return CorrelationAnalysisResult(
            projectId: input.projectId,
            variables: input.variables,
            correlationType: input.correlationType,
            timeRange: input.timeRange ?? DateInterval(start: Date().addingTimeInterval(-86400 * 30), end: Date()),
            correlationMatrix: correlationMatrix,
            significanceTests: significanceTests,
            causalHypotheses: causalHypotheses,
            insights: insights,
            dataQuality: assessDataQuality(variableData),
            generatedAt: Date()
        )
    }
    
    override func calculateQualityMetrics(input: CorrelationAnalysisInput, output: CorrelationAnalysisResult, configuration: CorrelationAnalysisConfig) async throws -> QualityMetrics {
        
        let dataCompleteness = output.dataQuality.completeness
        let dataAccuracy = output.dataQuality.accuracy
        let resultReliability = calculateCorrelationReliability(output.correlationMatrix, output.significanceTests)
        let avgPValue = calculateAverageSignificance(output.significanceTests)
        
        return QualityMetrics(
            dataCompleteness: dataCompleteness,
            dataAccuracy: dataAccuracy,
            resultReliability: resultReliability,
            statisticalSignificance: avgPValue
        )
    }
    
    override func identifyWarnings(input: CorrelationAnalysisInput, output: CorrelationAnalysisResult) async throws -> [AnalyticsWarning] {
        var warnings: [AnalyticsWarning] = []
        
        // 多重検定の警告
        let numComparisons = (input.variables.count * (input.variables.count - 1)) / 2
        if numComparisons > 10 {
            warnings.append(AnalyticsWarning(
                level: .warning,
                message: "多重比較により偽陽性率が上昇しています（\(numComparisons)組み合わせ）",
                recommendation: "Bonferroni補正やFDR補正の適用を検討してください",
                affectedMetrics: ["falseDiscoveryRate", "significance"]
            ))
        }
        
        // 弱い相関の警告
        let strongCorrelations = output.correlationMatrix.filter { abs($0.coefficient) > 0.7 }
        if strongCorrelations.isEmpty {
            warnings.append(AnalyticsWarning(
                level: .info,
                message: "強い相関関係が発見されませんでした",
                recommendation: "変数の選択や時期を再検討するか、非線形相関を考慮してください",
                affectedMetrics: ["correlationStrength"]
            ))
        }
        
        // データ品質の警告
        if output.dataQuality.completeness < 0.8 {
            warnings.append(AnalyticsWarning(
                level: .warning,
                message: "データの完全性が低いです（\(String(format: "%.1f%%", output.dataQuality.completeness * 100))）",
                recommendation: "欠損データを補完するか、分析期間を調整してください",
                affectedMetrics: ["reliability", "accuracy"]
            ))
        }
        
        return warnings
    }
    
    // MARK: - 内部実装メソッド
    
    private func getOperationName(for correlationType: CorrelationType) -> String {
        switch correlationType {
        case .pearson: return "calculatePearsonCorrelation"
        case .spearman: return "calculateSpearmanCorrelation"
        case .kendall: return "calculateKendallTau"
        case .partial: return "calculatePartialCorrelation"
        }
    }
    
    private func collectVariableData(
        projectId: UUID,
        variable: AnalysisVariable,
        timeRange: DateInterval?,
        config: CorrelationAnalysisConfig
    ) async throws -> [DataPoint] {
        // TODO: 実際の変数データ収集実装
        // プロジェクトのメトリクス、アクティビティデータなどを収集
        return []
    }
    
    private func validateDataQuality(
        _ variableData: [AnalysisVariable: [DataPoint]],
        _ config: CorrelationAnalysisConfig
    ) async throws {
        for (_, data) in variableData {
            guard data.count >= config.minimumSampleSize else {
                throw AnalyticsEngineError.insufficientData(
                    engineName,
                    config.minimumSampleSize,
                    data.count
                )
            }
        }
    }
    
    private func calculateCorrelationMatrix(
        data: [AnalysisVariable: [DataPoint]],
        type: CorrelationType,
        config: CorrelationAnalysisConfig
    ) async throws -> [CorrelationPair] {
        // TODO: 相関係数計算の実装
        // Pearson, Spearman, Kendall の相関係数を計算
        var correlations: [CorrelationPair] = []
        
        let variables = Array(data.keys)
        for i in 0..<variables.count {
            for j in (i+1)..<variables.count {
                let var1 = variables[i]
                let var2 = variables[j]
                
                // サンプル相関係数（実装では実際の計算を行う）
                let coefficient = 0.5 // TODO: 実際の相関係数計算
                
                correlations.append(CorrelationPair(
                    variable1: var1,
                    variable2: var2,
                    correlation: coefficient,
                    coefficient: coefficient,
                    strength: CorrelationStrength.from(correlation: coefficient),
                    direction: CorrelationDirection.from(correlation: coefficient)
                ))
            }
        }
        
        return correlations
    }
    
    private func performSignificanceTests(
        correlations: [CorrelationPair],
        dataSize: Int,
        config: CorrelationAnalysisConfig
    ) async throws -> [SignificanceTest] {
        // TODO: 統計的有意性検定の実装
        // t検定、ブートストラップ法など
        return correlations.map { correlation in
            SignificanceTest(
                correlationPair: correlation,
                pValue: 0.05, // TODO: 実際の検定結果
                isSignificant: true,
                confidenceLevel: 0.95
            )
        }
    }
    
    private func generateCausalHypotheses(
        correlations: [CorrelationPair],
        variables: [AnalysisVariable],
        significanceTests: [SignificanceTest]
    ) async throws -> [CausalHypothesis] {
        // TODO: 因果関係仮説生成の実装
        // 相関の強さ、時間的順序、ドメイン知識などを考慮
        return []
    }
    
    private func extractCorrelationInsights(
        correlations: [CorrelationPair],
        significance: [SignificanceTest],
        hypotheses: [CausalHypothesis],
        variables: [AnalysisVariable]
    ) async throws -> [CorrelationInsight] {
        // TODO: ビジネス洞察の抽出実装
        // 強い相関、適定な関係、アクショナブルな知見など
        return []
    }
    
    private func assessDataQuality(_ data: [AnalysisVariable: [DataPoint]]) -> DataQualityMetrics {
        // TODO: データ品質評価の実装
        return DataQualityMetrics(
            completeness: 0.9,
            accuracy: 0.8,
            consistency: 0.85
        )
    }
    
    private func calculateCorrelationReliability(
        _ correlations: [CorrelationPair],
        _ significance: [SignificanceTest]
    ) -> Double {
        // TODO: 相関結果の信頼性計算
        let significantCount = significance.filter { $0.isSignificant }.count
        guard !significance.isEmpty else { return 0.0 }
        return Double(significantCount) / Double(significance.count)
    }
    
    private func calculateAverageSignificance(_ tests: [SignificanceTest]) -> Double? {
        guard !tests.isEmpty else { return nil }
        let totalPValue = tests.reduce(0.0) { $0 + $1.pValue }
        return totalPValue / Double(tests.count)
    }
}

// MARK: - 相関分析用データ型

struct CorrelationAnalysisInput {
    let projectId: UUID
    let variables: [AnalysisVariable]
    let correlationType: CorrelationType
    let timeRange: DateInterval?
}

struct CorrelationAnalysisConfig {
    let minimumSampleSize: Int
    let significanceLevel: Double
    let enableMultipleTestingCorrection: Bool
    let correctionMethod: MultipleTestingCorrectionMethod
    let includeNonLinearCorrelations: Bool
    
    init(
        minimumSampleSize: Int = 30,
        significanceLevel: Double = 0.05,
        enableMultipleTestingCorrection: Bool = true,
        correctionMethod: MultipleTestingCorrectionMethod = .bonferroni,
        includeNonLinearCorrelations: Bool = false
    ) {
        self.minimumSampleSize = minimumSampleSize
        self.significanceLevel = significanceLevel
        self.enableMultipleTestingCorrection = enableMultipleTestingCorrection
        self.correctionMethod = correctionMethod
        self.includeNonLinearCorrelations = includeNonLinearCorrelations
    }
}

enum MultipleTestingCorrectionMethod: String, CaseIterable {
    case bonferroni = "bonferroni"
    case benjaminiHochberg = "benjamini_hochberg"
    case holm = "holm"
    case none = "none"
}

// ConfidenceInterval and SignificanceTest are defined in Core/Models/AdvancedAnalyticsTypes.swift
// Using the canonical definitions from AdvancedAnalyticsTypes

extension CorrelationType {
    var complexityMultiplier: Double {
        switch self {
        case .pearson: return 1.0
        case .spearman: return 1.2
        case .kendall: return 1.5
        case .partial: return 1.8
        }
    }
}