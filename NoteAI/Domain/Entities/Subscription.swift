import Foundation

struct Subscription: Identifiable, Equatable {
    let id: UUID
    let subscriptionType: SubscriptionType
    var isActive: Bool
    let startDate: Date
    var expirationDate: Date?
    var receiptData: Data?
    var lastValidated: Date?
    
    init(
        id: UUID = UUID(),
        subscriptionType: SubscriptionType = .free,
        isActive: Bool = true,
        startDate: Date = Date(),
        expirationDate: Date? = nil,
        receiptData: Data? = nil,
        lastValidated: Date? = nil
    ) {
        self.id = id
        self.subscriptionType = subscriptionType
        self.isActive = isActive
        self.startDate = startDate
        self.expirationDate = expirationDate
        self.receiptData = receiptData
        self.lastValidated = lastValidated
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

struct APIUsage: Identifiable, Equatable {
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
    let provider: LLMProvider
    let totalTokens: Int
    let totalCost: Double
    let requestCount: Int
    let audioMinutes: Double
    let period: DateInterval
    
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