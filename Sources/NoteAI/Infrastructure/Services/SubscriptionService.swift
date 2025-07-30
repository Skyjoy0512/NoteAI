import Foundation
#if !MINIMAL_BUILD
import RevenueCat
#endif
import Combine

@MainActor
class SubscriptionService: @preconcurrency SubscriptionServiceProtocol {
    
    // MARK: - Core Properties and Initialization
    
    // MARK: - Published Properties
    
    @Published private var _currentSubscription: SubscriptionStatus = SubscriptionStatus(
        plan: .free,
        isActive: false,
        expirationDate: nil,
        willRenew: false,
        originalPurchaseDate: nil,
        latestPurchaseDate: nil,
        unsubscribeDetectedAt: nil,
        billingIssueDetectedAt: nil,
        entitlements: [:]
    )
    
    private var statusUpdateHandler: ((SubscriptionStatus) -> Void)?
    private var isConfigured = false
    
    // MARK: - Protocol Properties
    
    var currentSubscription: SubscriptionStatus {
        get async {
            return _currentSubscription
        }
    }
    
    var currentPlan: SubscriptionPlan {
        get async {
            return _currentSubscription.plan
        }
    }
    
    var isSubscriptionActive: Bool {
        get async {
            return _currentSubscription.isActive
        }
    }
    
    // MARK: - Initialization
    
    init() {
        #if !MINIMAL_BUILD
        setupRevenueCatDelegate()
        #endif
    }
    
    // MARK: - Configuration
    
    func configure(apiKey: String, appUserID: String?) async throws {
        #if !MINIMAL_BUILD
        guard !apiKey.isEmpty else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey, appUserID: appUserID)
        
        isConfigured = true
        
        // 初期状態を取得
        await refreshSubscriptionStatus()
        #else
        // Minimal build - subscription features disabled
        throw SubscriptionError.revenueCatNotConfigured
        #endif
    }
    
    func setUserAttributes(_ attributes: [String: String]) async throws {
        #if !MINIMAL_BUILD
        guard isConfigured else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        
        for (key, value) in attributes {
            Purchases.shared.attribution.setAttributes([key: value])
        }
        #else
        throw SubscriptionError.revenueCatNotConfigured
        #endif
    }
    
    // MARK: - Purchase & Restore
    
    func purchaseSubscription(_ plan: SubscriptionPlan) async throws -> SubscriptionStatus {
        #if !MINIMAL_BUILD
        guard isConfigured else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current,
                  let package = getPackage(for: plan, from: currentOffering) else {
                throw SubscriptionError.subscriptionNotFound
            }
            
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                await refreshSubscriptionStatus()
                return _currentSubscription
            } else {
                throw SubscriptionError.userCancelled
            }
            
        } catch {
            if let rcError = error as? RevenueCatError {
                throw SubscriptionError.purchaseFailed(rcError.localizedDescription)
            } else {
                throw SubscriptionError.purchaseFailed(error.localizedDescription)
            }
        }
        #else
        throw SubscriptionError.revenueCatNotConfigured
        #endif
    }
    
    func restorePurchases() async throws -> SubscriptionStatus {
        #if !MINIMAL_BUILD
        guard isConfigured else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        
        do {
            _ = try await Purchases.shared.restorePurchases()
            await refreshSubscriptionStatus()
            return _currentSubscription
        } catch {
            if let rcError = error as? RevenueCatError {
                throw SubscriptionError.restoreFailed(rcError.localizedDescription)
            } else {
                throw SubscriptionError.restoreFailed(error.localizedDescription)
            }
        }
        #else
        throw SubscriptionError.revenueCatNotConfigured
        #endif
    }
    
    // MARK: - Entitlements & Limits
    
    func hasEntitlement(_ entitlement: String) async -> Bool {
        return _currentSubscription.entitlements[entitlement] == true
    }
    
    func canUseFeature(_ feature: String) async -> Bool {
        switch feature {
        case "ai_features":
            return _currentSubscription.plan.limits.hasAIFeatures
        case "speaker_separation":
            return _currentSubscription.plan.limits.hasSpeakerSeparation
        case "export":
            return _currentSubscription.plan.limits.hasExport
        case "priority_support":
            return _currentSubscription.plan.limits.hasPrioritySupport
        default:
            return false
        }
    }
    
    func checkUsageLimits() async throws -> UsageStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        // UserDefaultsから使用統計を取得
        let projectsUsed = UserDefaults.standard.integer(forKey: "usage_projects_\(formatMonth(now))")
        let recordingMinutes = UserDefaults.standard.integer(forKey: "usage_recording_\(formatMonth(now))")
        let apiCalls = UserDefaults.standard.integer(forKey: "usage_api_\(formatMonth(now))")
        
        return UsageStats(
            currentPeriodStart: startOfMonth,
            currentPeriodEnd: endOfMonth,
            projectsUsed: projectsUsed,
            recordingMinutesUsed: recordingMinutes,
            apiCallsUsed: apiCalls
        )
    }
    
    func getCurrentLimits() async -> SubscriptionLimits {
        return _currentSubscription.plan.limits
    }
    
    // MARK: - Usage Tracking
    
    func recordProjectCreation() async throws {
        let limits = await getCurrentLimits()
        let stats = try await checkUsageLimits()
        
        // 制限チェック
        if !limits.isUnlimited(for: limits.maxProjects) && 
           stats.projectsUsed >= limits.maxProjects {
            throw SubscriptionError.subscriptionNotFound // 制限に達している
        }
        
        // 使用量を記録
        let key = "usage_projects_\(formatMonth(Date()))"
        let currentUsage = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentUsage + 1, forKey: key)
    }
    
    func recordRecordingMinutes(_ minutes: Int) async throws {
        let limits = await getCurrentLimits()
        let stats = try await checkUsageLimits()
        
        // 制限チェック
        if !limits.isUnlimited(for: limits.maxRecordingMinutesPerMonth) && 
           (stats.recordingMinutesUsed + minutes) > limits.maxRecordingMinutesPerMonth {
            throw SubscriptionError.subscriptionNotFound // 制限に達している
        }
        
        // 使用量を記録
        let key = "usage_recording_\(formatMonth(Date()))"
        let currentUsage = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentUsage + minutes, forKey: key)
    }
    
    func recordAPICall() async throws {
        let limits = await getCurrentLimits()
        let stats = try await checkUsageLimits()
        
        // 制限チェック
        if stats.apiCallsUsed >= limits.maxAPICallsPerMonth {
            throw SubscriptionError.subscriptionNotFound // 制限に達している
        }
        
        // 使用量を記録
        let key = "usage_api_\(formatMonth(Date()))"
        let currentUsage = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentUsage + 1, forKey: key)
    }
    
    // MARK: - UI Support
    
    func getAvailableProducts() async throws -> [SubscriptionPlan] {
        #if !MINIMAL_BUILD
        guard isConfigured else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        
        return SubscriptionPlan.allCases
        #else
        return [.free]  // Only free plan available in minimal build
        #endif
    }
    
    func getPriceString(for plan: SubscriptionPlan) async -> String? {
        #if !MINIMAL_BUILD
        guard isConfigured else { return nil }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current,
                  let package = getPackage(for: plan, from: currentOffering) else {
                return plan.monthlyPrice // フォールバック価格
            }
            
            return package.storeProduct.localizedPriceString
        } catch {
            return plan.monthlyPrice // フォールバック価格
        }
        #else
        return plan.monthlyPrice // フォールバック価格
        #endif
    }
    
    // MARK: - Observers
    
    func startListening(onUpdate: @escaping (SubscriptionStatus) -> Void) {
        statusUpdateHandler = onUpdate
    }
    
    func stopListening() {
        statusUpdateHandler = nil
    }
    
    // MARK: - Private Methods
    
    #if !MINIMAL_BUILD
    private func setupRevenueCatDelegate() {
        Purchases.shared.delegate = self
    }
    #endif
    
    private func refreshSubscriptionStatus() async {
        #if !MINIMAL_BUILD
        guard isConfigured else { return }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let newStatus = createSubscriptionStatus(from: customerInfo)
            
            if newStatus.plan != _currentSubscription.plan || 
               newStatus.isActive != _currentSubscription.isActive {
                _currentSubscription = newStatus
                statusUpdateHandler?(newStatus)
            } else {
                _currentSubscription = newStatus
            }
        } catch {
            print("Failed to refresh subscription status: \(error)")
        }
        #endif
    }
    
    #if !MINIMAL_BUILD && !NO_COREDATA
    private func createSubscriptionStatus(from customerInfo: CustomerInfo) -> SubscriptionStatus {
        let hasPremiumEntitlement = customerInfo.entitlements["premium"]?.isActive == true
        let plan: SubscriptionPlan = hasPremiumEntitlement ? .premium : .free
        
        var entitlements: [String: Bool] = [:]
        for (key, entitlement) in customerInfo.entitlements {
            entitlements[key] = entitlement.isActive
        }
        
        let activeEntitlement = customerInfo.entitlements["premium"]
        
        return SubscriptionStatus(
            plan: plan,
            isActive: hasPremiumEntitlement,
            expirationDate: activeEntitlement?.expirationDate,
            willRenew: activeEntitlement?.willRenew ?? false,
            originalPurchaseDate: activeEntitlement?.originalPurchaseDate,
            latestPurchaseDate: activeEntitlement?.latestPurchaseDate,
            unsubscribeDetectedAt: activeEntitlement?.unsubscribeDetectedAt,
            billingIssueDetectedAt: activeEntitlement?.billingIssueDetectedAt,
            entitlements: entitlements
        )
    }
    
    private func getPackage(for plan: SubscriptionPlan, from offering: Offering) -> Package? {
        switch plan {
        case .free:
            return nil // 無料プランは購入不要
        case .premium:
            return offering.monthly // またはoffering.availablePackages.first
        }
    }
    #endif
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

#if !MINIMAL_BUILD && !NO_COREDATA
// MARK: - PurchasesDelegate

extension SubscriptionService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            let newStatus = createSubscriptionStatus(from: customerInfo)
            _currentSubscription = newStatus
            statusUpdateHandler?(newStatus)
        }
    }
    
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase makeDeferredPurchase: @escaping (@MainActor @Sendable (StoreTransaction?, CustomerInfo?, PublicError?, Bool) -> Void)) {
        // プロモーション商品の処理（必要に応じて実装）
    }
}
#endif
