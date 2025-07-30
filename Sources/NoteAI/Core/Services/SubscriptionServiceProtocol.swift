import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import RevenueCat
#endif

enum SubscriptionError: Error, LocalizedError {
    case revenueCatNotConfigured
    case purchaseFailed(String)
    case restoreFailed(String)
    case subscriptionNotFound
    case networkError
    case userCancelled
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .revenueCatNotConfigured:
            return "課金システムが設定されていません"
        case .purchaseFailed(let reason):
            return "購入に失敗しました: \(reason)"
        case .restoreFailed(let reason):
            return "復元に失敗しました: \(reason)"
        case .subscriptionNotFound:
            return "サブスクリプションが見つかりません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .userCancelled:
            return "ユーザーによってキャンセルされました"
        case .unknownError:
            return "不明なエラーが発生しました"
        }
    }
    
    var userMessage: String {
        return errorDescription ?? "サブスクリプションエラーが発生しました"
    }
    
    var errorCode: String {
        switch self {
        case .revenueCatNotConfigured: return "REVENUECAT_NOT_CONFIGURED"
        case .purchaseFailed: return "PURCHASE_FAILED"
        case .restoreFailed: return "RESTORE_FAILED"
        case .subscriptionNotFound: return "SUBSCRIPTION_NOT_FOUND"
        case .networkError: return "NETWORK_ERROR"
        case .userCancelled: return "USER_CANCELLED"
        case .unknownError: return "UNKNOWN_ERROR"
        }
    }
    
    var debugInfo: String? {
        return "Subscription Service Error: \(errorCode)"
    }
}

enum SubscriptionPlan: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "無料プラン"
        case .premium: return "プレミアムプラン"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .free: return "¥0"
        case .premium: return "¥980"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "基本的な音声録音",
                "ローカル文字起こし（WhisperKit）",
                "5プロジェクトまで",
                "月100分まで録音可能"
            ]
        case .premium:
            return [
                "無制限の音声録音",
                "高精度API文字起こし",
                "無制限プロジェクト",
                "AI要約・分析機能",
                "話者分離機能",
                "プロジェクト横断検索",
                "エクスポート機能",
                "優先サポート"
            ]
        }
    }
    
    var limits: SubscriptionLimits {
        switch self {
        case .free:
            return SubscriptionLimits(
                maxProjects: 5,
                maxRecordingMinutesPerMonth: 100,
                maxAPICallsPerMonth: 0,
                hasAIFeatures: false,
                hasSpeakerSeparation: false,
                hasExport: false,
                hasPrioritySupport: false
            )
        case .premium:
            return SubscriptionLimits(
                maxProjects: -1, // unlimited
                maxRecordingMinutesPerMonth: -1, // unlimited
                maxAPICallsPerMonth: 10000,
                hasAIFeatures: true,
                hasSpeakerSeparation: true,
                hasExport: true,
                hasPrioritySupport: true
            )
        }
    }
}

struct SubscriptionLimits {
    let maxProjects: Int // -1 for unlimited
    let maxRecordingMinutesPerMonth: Int // -1 for unlimited
    let maxAPICallsPerMonth: Int
    let hasAIFeatures: Bool
    let hasSpeakerSeparation: Bool
    let hasExport: Bool
    let hasPrioritySupport: Bool
    
    func isUnlimited(for limit: Int) -> Bool {
        return limit == -1
    }
}

struct SubscriptionStatus {
    let plan: SubscriptionPlan
    let isActive: Bool
    let expirationDate: Date?
    let willRenew: Bool
    let originalPurchaseDate: Date?
    let latestPurchaseDate: Date?
    let unsubscribeDetectedAt: Date?
    let billingIssueDetectedAt: Date?
    let entitlements: [String: Bool]
}

struct UsageStats {
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let projectsUsed: Int
    let recordingMinutesUsed: Int
    let apiCallsUsed: Int
    
    func usagePercentage(for limit: Int) -> Double {
        guard limit > 0 else { return 0.0 }
        switch limit {
        case projectsUsed: return Double(projectsUsed) / Double(limit)
        case recordingMinutesUsed: return Double(recordingMinutesUsed) / Double(limit)
        case apiCallsUsed: return Double(apiCallsUsed) / Double(limit)
        default: return 0.0
        }
    }
}

protocol SubscriptionServiceProtocol {
    // Subscription Status
    var currentSubscription: SubscriptionStatus { get async }
    var currentPlan: SubscriptionPlan { get async }
    var isSubscriptionActive: Bool { get async }
    
    // Purchase & Restore
    func purchaseSubscription(_ plan: SubscriptionPlan) async throws -> SubscriptionStatus
    func restorePurchases() async throws -> SubscriptionStatus
    
    // Entitlements & Limits
    func hasEntitlement(_ entitlement: String) async -> Bool
    func canUseFeature(_ feature: String) async -> Bool
    func checkUsageLimits() async throws -> UsageStats
    func getCurrentLimits() async -> SubscriptionLimits
    
    // Usage Tracking
    func recordProjectCreation() async throws
    func recordRecordingMinutes(_ minutes: Int) async throws
    func recordAPICall() async throws
    
    // UI Support
    func getAvailableProducts() async throws -> [SubscriptionPlan]
    func getPriceString(for plan: SubscriptionPlan) async -> String?
    
    // Configuration
    func configure(apiKey: String, appUserID: String?) async throws
    func setUserAttributes(_ attributes: [String: String]) async throws
    
    // Observers
    func startListening(onUpdate: @escaping (SubscriptionStatus) -> Void)
    func stopListening()
}