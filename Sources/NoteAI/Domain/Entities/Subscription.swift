import Foundation

struct Subscription: Identifiable, Equatable {
    let id: UUID
    let subscriptionType: SubscriptionType
    let planType: SubscriptionPlan // Added for Entity compatibility
    var isActive: Bool
    let startDate: Date
    var expirationDate: Date?
    let endDate: Date? // Added for Entity compatibility
    var receiptData: Data?
    var lastValidated: Date?
    let autoRenew: Bool // Added for Entity compatibility
    let transactionId: String? // Added for Entity compatibility
    let createdAt: Date // Added for Entity compatibility
    let updatedAt: Date // Added for Entity compatibility
    
    init(
        id: UUID = UUID(),
        subscriptionType: SubscriptionType = .free,
        planType: SubscriptionPlan = .free,
        isActive: Bool = true,
        startDate: Date = Date(),
        expirationDate: Date? = nil,
        endDate: Date? = nil,
        receiptData: Data? = nil,
        lastValidated: Date? = nil,
        autoRenew: Bool = false,
        transactionId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.subscriptionType = subscriptionType
        self.planType = planType
        self.isActive = isActive
        self.startDate = startDate
        self.expirationDate = expirationDate
        self.endDate = endDate
        self.receiptData = receiptData
        self.lastValidated = lastValidated
        self.autoRenew = autoRenew
        self.transactionId = transactionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isPremium: Bool {
        return subscriptionType == .premium && isActive
    }
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expirationDate)
        return components.day
    }
}

struct SubscriptionAPIUsage: Identifiable, Equatable {
    let id: UUID
    let provider: LLMProvider
    let date: Date
    var tokenUsage: TokenUsage?
    let requestCount: Int
    let audioMinutes: Double
    let estimatedCost: Double
    let month: String // "2025-01" format
    
    init(
        id: UUID = UUID(),
        provider: LLMProvider,
        date: Date = Date(),
        tokenUsage: TokenUsage? = nil,
        requestCount: Int = 1,
        audioMinutes: Double = 0,
        estimatedCost: Double = 0
    ) {
        self.id = id
        self.provider = provider
        self.date = date
        self.tokenUsage = tokenUsage
        self.requestCount = requestCount
        self.audioMinutes = audioMinutes
        self.estimatedCost = estimatedCost
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.month = formatter.string(from: date)
    }
}

struct TokenUsage: Codable, Equatable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    init(promptTokens: Int, completionTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = promptTokens + completionTokens
    }
}

struct MonthlyUsage {
    let provider: LLMProvider?
    let totalTokens: Int
    let totalCost: Double
    let requestCount: Int
    let audioMinutes: Double
    let period: DateInterval
    
    // APIUsageTracker で期待されるプロパティ
    let month: Date
    let totalAPICalls: Int
    let providerBreakdown: [LLMProvider: DailyUsage]
    
    init(
        provider: LLMProvider? = nil,
        totalTokens: Int,
        totalCost: Double,
        requestCount: Int,
        audioMinutes: Double = 0,
        period: DateInterval,
        month: Date? = nil,
        totalAPICalls: Int? = nil,
        providerBreakdown: [LLMProvider: DailyUsage] = [:]
    ) {
        self.provider = provider
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.requestCount = requestCount
        self.audioMinutes = audioMinutes
        self.period = period
        self.month = month ?? period.start
        self.totalAPICalls = totalAPICalls ?? requestCount
        self.providerBreakdown = providerBreakdown
    }
    
    var averageCostPerRequest: Double {
        guard requestCount > 0 else { return 0 }
        return totalCost / Double(requestCount)
    }
    
    var averageTokensPerRequest: Double {
        guard requestCount > 0 else { return 0 }
        return Double(totalTokens) / Double(requestCount)
    }
}

struct UsageLimitStatus {
    let provider: LLMProvider
    let currentUsage: Double
    let limit: Double
    let percentage: Double
    
    var shouldAlert: Bool {
        return percentage >= 80.0
    }
    
    var isOverLimit: Bool {
        return percentage >= 100.0
    }
    
    var alertLevel: AlertLevel {
        switch percentage {
        case 0..<80:
            return .none
        case 80..<90:
            return .warning
        case 90..<100:
            return .critical
        default:
            return .overLimit
        }
    }
}

enum AlertLevel {
    case none
    case warning
    case critical
    case overLimit
    
    var displayName: String {
        switch self {
        case .none: return "正常"
        case .warning: return "注意"
        case .critical: return "警告"
        case .overLimit: return "上限超過"
        }
    }
}