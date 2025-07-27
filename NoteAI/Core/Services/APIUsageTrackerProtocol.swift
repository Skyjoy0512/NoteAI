import Foundation

enum APIUsageTrackerError: Error, LocalizedError {
    case databaseError(String)
    case rateLimitExceeded
    case usageLimitExceeded
    case invalidProvider
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "データベースエラー: \(message)"
        case .rateLimitExceeded:
            return "レート制限に達しました"
        case .usageLimitExceeded:
            return "使用制限に達しました"
        case .invalidProvider:
            return "無効なプロバイダーです"
        case .configurationError:
            return "設定エラーが発生しました"
        }
    }
}

struct APIUsageRecord {
    let id: UUID
    let provider: LLMProvider
    let model: String
    let tokensUsed: Int
    let cost: Double
    let timestamp: Date
    let responseTime: TimeInterval?
    let success: Bool
    let errorMessage: String?
}

struct DailyUsage {
    let date: Date
    let provider: LLMProvider
    let apiCalls: Int
    let tokensUsed: Int
    let totalCost: Double
    let averageResponseTime: TimeInterval
}

struct MonthlyUsage {
    let month: Date
    let totalAPICalls: Int
    let totalTokens: Int
    let totalCost: Double
    let providerBreakdown: [LLMProvider: DailyUsage]
}

struct ProviderUsageStats {
    let provider: LLMProvider
    let apiCalls: Int
    let tokens: Int
    let cost: Double
    let lastUsed: Date?
    let averageResponseTime: TimeInterval
    let successRate: Double
    let topModels: [String]
}

struct UsageTrend {
    let period: String // "daily", "weekly", "monthly"
    let data: [UsageDataPoint]
}

struct UsageDataPoint {
    let date: Date
    let apiCalls: Int
    let tokens: Int
    let cost: Double
}

struct RateLimitStatus {
    let provider: LLMProvider
    let requestsInCurrentMinute: Int
    let requestsInCurrentHour: Int
    let requestsInCurrentDay: Int
    let maxRequestsPerMinute: Int
    let maxRequestsPerHour: Int
    let maxRequestsPerDay: Int
    let canMakeRequest: Bool
    let nextAvailableTime: Date?
}

struct CostPrediction {
    let currentMonthProjected: Double
    let nextMonthEstimated: Double
    let recommendedBudget: Double
    let savingsOpportunities: [String]
}

protocol APIUsageTrackerProtocol {
    // Core Usage Recording
    func recordAPICall(provider: LLMProvider, model: String, tokensUsed: Int, cost: Double) async throws
    func recordFailedAPICall(provider: LLMProvider, model: String, error: String) async throws
    func recordResponseTime(provider: LLMProvider, responseTime: TimeInterval) async throws
    
    // Rate Limiting
    func checkRateLimit(for provider: LLMProvider) async throws -> Bool
    func getRateLimitStatus(for provider: LLMProvider) async throws -> RateLimitStatus
    func updateRateLimits(for provider: LLMProvider, limits: RateLimitStatus) async throws
    
    // Usage Queries
    func getMonthlyUsage(for month: Date? = nil) async throws -> MonthlyUsage
    func getDailyUsage(for date: Date) async throws -> [DailyUsage]
    func getProviderUsage(_ provider: LLMProvider, period: DateInterval? = nil) async throws -> ProviderUsageStats
    func getUsageHistory(provider: LLMProvider?, limit: Int) async throws -> [APIUsageRecord]
    
    // Analytics & Trends
    func getUsageTrend(period: String, days: Int) async throws -> UsageTrend
    func getCostBreakdown(for month: Date? = nil) async throws -> [LLMProvider: Double]
    func getPredictedCosts() async throws -> CostPrediction
    func getTopModels(limit: Int) async throws -> [(model: String, usage: Int)]
    
    // Limits & Alerts
    func setUsageLimit(provider: LLMProvider, limit: Int, period: String) async throws
    func getUsageAlerts() async throws -> [UsageAlert]
    func checkUsageLimits() async throws -> [LimitStatus]
    
    // Optimization
    func getSavingsSuggestions() async throws -> [SavingSuggestion]
    func getUnusedProviders(days: Int) async throws -> [LLMProvider]
    func getExpensiveOperations(limit: Int) async throws -> [APIUsageRecord]
    
    // Data Management
    func exportUsageData(format: ExportFormat, period: DateInterval) async throws -> Data
    func cleanupOldData(olderThan: Date) async throws
    func resetMonthlyUsage() async throws
    
    // Configuration
    func configure(database: Any?) async throws
    func setRetentionPeriod(_ days: Int) async throws
    func enableRealTimeTracking(_ enabled: Bool) async throws
}

struct UsageAlert {
    let id: UUID
    let type: AlertType
    let provider: LLMProvider?
    let threshold: Double
    let currentValue: Double
    let message: String
    let createdAt: Date
    let isActive: Bool
}

enum AlertType: String, CaseIterable {
    case costThreshold = "cost_threshold"
    case usageThreshold = "usage_threshold"
    case rateLimitApproaching = "rate_limit_approaching"
    case dailyLimitReached = "daily_limit_reached"
    case monthlyLimitReached = "monthly_limit_reached"
    case unusualActivity = "unusual_activity"
}

struct LimitStatus {
    let provider: LLMProvider
    let limitType: String
    let currentUsage: Int
    let limit: Int
    let percentage: Double
    let timeUntilReset: TimeInterval
    let isExceeded: Bool
}

struct SavingSuggestion {
    let id: UUID
    let type: SuggestionType
    let provider: LLMProvider?
    let currentCost: Double
    let potentialSavings: Double
    let description: String
    let actionRequired: String
    let priority: SuggestionPriority
}

enum SuggestionType: String, CaseIterable {
    case modelDowngrade = "model_downgrade"
    case providerSwitch = "provider_switch"
    case batchRequests = "batch_requests"
    case cacheResponses = "cache_responses"
    case optimizePrompts = "optimize_prompts"
    case removeUnusedProviders = "remove_unused_providers"
}

enum SuggestionPriority: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    case pdf = "pdf"
    case xlsx = "xlsx"
}