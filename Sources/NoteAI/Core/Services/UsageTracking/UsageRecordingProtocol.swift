import Foundation

// MARK: - 使用量記録プロトコル

protocol UsageRecordingProtocol {
    /// API呼び出しを記録
    func recordAPICall(
        provider: LLMProvider,
        model: String,
        tokensUsed: Int,
        cost: Double
    ) async throws
    
    /// 失敗したAPI呼び出しを記録
    func recordFailedAPICall(
        provider: LLMProvider,
        model: String,
        error: String
    ) async throws
    
    /// レスポンス時間を記録
    func recordResponseTime(
        provider: LLMProvider,
        responseTime: TimeInterval
    ) async throws
    
    /// 使用量記録のバッチ処理
    func recordBatchUsage(
        _ records: [UsageRecord]
    ) async throws
}

// MARK: - レート制限プロトコル

protocol RateLimitingProtocol {
    /// レート制限をチェック
    func checkRateLimit(for provider: LLMProvider) async throws -> Bool
    
    /// レート制限状況を取得
    func getRateLimitStatus(for provider: LLMProvider) async throws -> RateLimitStatus
    
    /// レート制限を更新
    func updateRateLimits(
        for provider: LLMProvider,
        limits: RateLimitStatus
    ) async throws
    
    /// 次回リクエスト可能時間を取得
    func getNextAvailableTime(for provider: LLMProvider) async -> Date?
}

// MARK: - 使用量分析プロトコル

protocol UsageAnalyticsProtocol {
    /// 月間使用量を取得
    func getMonthlyUsage(for month: Date?) async throws -> MonthlyUsage
    
    /// 日別使用量を取得
    func getDailyUsage(for date: Date) async throws -> [DailyUsage]
    
    /// プロバイダー別使用量を取得
    func getProviderUsage(
        _ provider: LLMProvider,
        period: DateInterval?
    ) async throws -> ProviderUsageStats
    
    /// 使用量履歴を取得
    func getUsageHistory(
        provider: LLMProvider?,
        limit: Int
    ) async throws -> [APIUsageRecord]
    
    /// 使用量トレンドを取得
    func getUsageTrend(
        period: String,
        days: Int
    ) async throws -> UsageTrend
    
    /// コスト内訳を取得
    func getCostBreakdown(for month: Date?) async throws -> [LLMProvider: Double]
    
    /// 人気モデルランキングを取得
    func getTopModels(limit: Int) async throws -> [(model: String, usage: Int)]
}

// MARK: - 制限・アラートプロトコル

protocol UsageLimitsProtocol {
    /// 使用制限を設定
    func setUsageLimit(
        provider: LLMProvider,
        limit: Int,
        period: String
    ) async throws
    
    /// 使用アラートを取得
    func getUsageAlerts() async throws -> [UsageAlert]
    
    /// 使用制限をチェック
    func checkUsageLimits() async throws -> [LimitStatus]
    
    /// アラート設定を更新
    func updateAlertSettings(
        _ settings: AlertSettings
    ) async throws
}

// MARK: - 最適化プロトコル

protocol UsageOptimizationProtocol {
    /// コスト予測を取得
    func getPredictedCosts() async throws -> CostPrediction
    
    /// 節約提案を取得
    func getSavingsSuggestions() async throws -> [SavingSuggestion]
    
    /// 未使用プロバイダーを検出
    func getUnusedProviders(days: Int) async throws -> [LLMProvider]
    
    /// 高コスト操作を検出
    func getExpensiveOperations(limit: Int) async throws -> [APIUsageRecord]
    
    /// 使用パターン分析
    func analyzeUsagePatterns() async throws -> UsagePatternAnalysis
}

// MARK: - データ管理プロトコル

protocol UsageDataManagementProtocol {
    /// 使用量データをエクスポート
    func exportUsageData(
        format: ExportFormat,
        period: DateInterval
    ) async throws -> Data
    
    /// 古いデータをクリーンアップ
    func cleanupOldData(olderThan: Date) async throws
    
    /// 月次使用量をリセット
    func resetMonthlyUsage() async throws
    
    /// データベースを最適化
    func optimizeDatabase() async throws
    
    /// データをバックアップ
    func backupData() async throws -> Data
    
    /// データを復元
    func restoreData(from data: Data) async throws
}

// MARK: - 設定プロトコル

protocol UsageConfigurationProtocol {
    /// データベースを設定
    func configure(database: Any?) async throws
    
    /// データ保持期間を設定
    func setRetentionPeriod(_ days: Int) async throws
    
    /// リアルタイム追跡を有効化
    func enableRealTimeTracking(_ enabled: Bool) async throws
    
    /// 設定を取得
    func getConfiguration() async throws -> UsageConfiguration
    
    /// 設定を更新
    func updateConfiguration(_ config: UsageConfiguration) async throws
}

// MARK: - 統合プロトコル

protocol APIUsageTrackerProtocol: UsageRecordingProtocol,
                                   RateLimitingProtocol,
                                   UsageAnalyticsProtocol,
                                   UsageLimitsProtocol,
                                   UsageOptimizationProtocol,
                                   UsageDataManagementProtocol,
                                   UsageConfigurationProtocol {
    
    /// 使用量統計の包括的な取得
    func getUsageStats() async throws -> LLMUsageStats
}

// MARK: - サポート型

struct UsageRecord {
    let provider: LLMProvider
    let model: String
    let tokensUsed: Int
    let cost: Double
    let timestamp: Date
    let success: Bool
    let responseTime: TimeInterval?
    let errorMessage: String?
}

struct AlertSettings: Codable {
    let costThreshold: Double?
    let usageThreshold: Int?
    let dailyLimitWarning: Bool
    let monthlyLimitWarning: Bool
    let enableNotifications: Bool
}

struct UsageConfiguration {
    let retentionDays: Int
    let enableRealTimeTracking: Bool
    let enableAnalytics: Bool
    let exportFormats: [ExportFormat]
    let alertSettings: AlertSettings
}

struct UsagePatternAnalysis {
    let peakUsageHours: [Int]
    let mostUsedProviders: [LLMProvider]
    let averageCostPerRequest: Double
    let usageGrowthRate: Double
    let seasonalPatterns: [String: Double]
    let recommendedOptimizations: [String]
}