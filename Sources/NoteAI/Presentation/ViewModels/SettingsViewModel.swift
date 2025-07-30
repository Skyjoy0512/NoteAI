import SwiftUI
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
class SettingsViewModel: ViewModelCapable {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Subscription Status
    @Published var isSubscriptionActive = false
    @Published var currentPlan: SubscriptionPlan = .free
    
    // Recording Settings
    @Published var recordingQuality: AudioQuality = .standard
    @Published var audioFormat: AudioFormat = .m4a
    @Published var allowBackgroundRecording = true
    @Published var autoStopRecording = false
    @Published var autoStopDuration = 60
    
    // AI & Transcription Settings
    @Published var defaultLanguage: SupportedLanguage = .japanese
    @Published var transcriptionMethod: TranscriptionMethod = .local(.base)
    @Published var preferredAIProvider: LLMProvider = .openAI(.gpt35turbo)
    @Published var autoSummarize = false
    @Published var autoExtractKeywords = false
    
    // App Settings
    @Published var appTheme: AppTheme = .auto
    @Published var appLanguage: AppLanguage = .japanese
    @Published var hapticFeedback = true
    @Published var autoBackup = true
    @Published var backupFrequency: BackupFrequency = .daily
    
    // API & Usage Info
    @Published var hasAPIKeys = false
    @Published var configuredProviders: [LLMProvider] = []
    @Published var hasUsageData = false
    @Published var monthlyUsageText = "0"
    @Published var monthlyCostText = "$0.00"
    @Published var monthlyAPICalls = 0
    @Published var monthlyRecordingMinutes = 0
    
    // MARK: - Dependencies
    private let subscriptionService: SubscriptionServiceProtocol
    private let apiKeyManager: APIKeyManagerProtocol
    private let usageTracker: APIUsageTrackerProtocol
    
    // MARK: - Child ViewModels
    // Temporarily disabled - these will be implemented in a later phase
    /*
    lazy var apiKeySettingsViewModel: APIKeySettingsViewModel = {
        APIKeySettingsViewModel(apiKeyManager: apiKeyManager)
    }()
    
    lazy var subscriptionViewModel: SubscriptionViewModel = {
        SubscriptionViewModel(subscriptionService: subscriptionService)
    }()
    */
    
    lazy var usageMonitorViewModel: UsageMonitorViewModel = {
        UsageMonitorViewModel(usageTracker: usageTracker)
    }()
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        subscriptionService: SubscriptionServiceProtocol,
        apiKeyManager: APIKeyManagerProtocol,
        usageTracker: APIUsageTrackerProtocol
    ) {
        self.subscriptionService = subscriptionService
        self.apiKeyManager = apiKeyManager
        self.usageTracker = usageTracker
        
        setupBindings()
        loadSettings()
        Task {
            await refreshSettings()
        }
    }
    
    // MARK: - Public Methods
    
    func refreshSettings() async {
        await withLoadingNoReturn {
            await self.loadSubscriptionStatus()
            await self.loadAPIKeyStatus()
            await self.loadUsageData()
        }
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://noteai.app/privacy") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    func openTermsOfService() {
        if let url = URL(string: "https://noteai.app/terms") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    func sendFeedback() {
        let email = "support@noteai.app"
        let subject = "NoteAI Feedback"
        let deviceInfo: String
        #if canImport(UIKit)
        deviceInfo = """
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
        #elseif canImport(AppKit)
        deviceInfo = """
        macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Device: Mac
        """
        #else
        deviceInfo = "Unknown Platform"
        #endif
        
        let body = """
        App Version: \(appVersion)
        
        \(deviceInfo)
        
        Your feedback:
        
        """
        
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(forURLQueryValue: true) ?? "")&body=\(body.addingPercentEncoding(forURLQueryValue: true) ?? "")"
        
        if let url = URL(string: urlString) {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 設定変更を監視してUserDefaultsに保存
        Publishers.CombineLatest4(
            $recordingQuality,
            $audioFormat,
            $allowBackgroundRecording,
            $autoStopRecording
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] quality, format, background, autoStop in
            self?.saveRecordingSettings(quality, format, background, autoStop)
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $defaultLanguage,
            $transcriptionMethod,
            $preferredAIProvider,
            $autoSummarize
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] language, method, provider, summarize in
            self?.saveAISettings(language, method, provider, summarize)
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest4(
            $appTheme,
            $appLanguage,
            $hapticFeedback,
            $autoBackup
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] theme, language, haptic, backup in
            self?.saveAppSettings(theme, language, haptic, backup)
        }
        .store(in: &cancellables)
        
        // サブスクリプション状態の監視
        subscriptionService.startListening { [weak self] status in
            Task { @MainActor [weak self] in
                self?.isSubscriptionActive = status.isActive
                self?.currentPlan = status.plan
            }
        }
    }
    
    private func loadSettings() {
        // Recording Settings
        if let qualityRaw = UserDefaults.standard.object(forKey: "recording_quality") as? String,
           let quality = AudioQuality(rawValue: qualityRaw) {
            recordingQuality = quality
        }
        
        if let formatRaw = UserDefaults.standard.object(forKey: "audio_format") as? String,
           let format = AudioFormat(rawValue: formatRaw) {
            audioFormat = format
        }
        
        allowBackgroundRecording = UserDefaults.standard.bool(forKey: "allow_background_recording")
        autoStopRecording = UserDefaults.standard.bool(forKey: "auto_stop_recording")
        autoStopDuration = UserDefaults.standard.integer(forKey: "auto_stop_duration")
        
        // AI Settings
        if let languageRaw = UserDefaults.standard.object(forKey: "default_language") as? String,
           let language = SupportedLanguage(rawValue: languageRaw) {
            defaultLanguage = language
        }
        
        if let methodRaw = UserDefaults.standard.object(forKey: "transcription_method") as? String {
            // Map string to TranscriptionMethod enum
            switch methodRaw {
            case "local_tiny":
                transcriptionMethod = .local(.tiny)
            case "local_base":
                transcriptionMethod = .local(.base)
            case "local_small":
                transcriptionMethod = .local(.small)
            case "api_openai":
                transcriptionMethod = .api(.openAI(.gpt4))
            case "api_gemini":
                transcriptionMethod = .api(.gemini(.geminipro))
            case "api_claude":
                transcriptionMethod = .api(.anthropic(.claude3Sonnet))
            default:
                transcriptionMethod = .local(.base)
            }
        }
        
        if let providerRaw = UserDefaults.standard.object(forKey: "preferred_ai_provider") as? String,
           let provider = LLMProvider(rawValue: providerRaw) {
            preferredAIProvider = provider
        }
        
        autoSummarize = UserDefaults.standard.bool(forKey: "auto_summarize")
        autoExtractKeywords = UserDefaults.standard.bool(forKey: "auto_extract_keywords")
        
        // App Settings
        if let themeRaw = UserDefaults.standard.object(forKey: "app_theme") as? String,
           let theme = AppTheme(rawValue: themeRaw) {
            appTheme = theme
        }
        
        if let languageRaw = UserDefaults.standard.object(forKey: "app_language") as? String,
           let language = AppLanguage(rawValue: languageRaw) {
            appLanguage = language
        }
        
        hapticFeedback = UserDefaults.standard.bool(forKey: "haptic_feedback")
        autoBackup = UserDefaults.standard.bool(forKey: "auto_backup")
        
        if let frequencyRaw = UserDefaults.standard.object(forKey: "backup_frequency") as? String,
           let frequency = BackupFrequency(rawValue: frequencyRaw) {
            backupFrequency = frequency
        }
    }
    
    private func saveRecordingSettings(
        _ quality: AudioQuality,
        _ format: AudioFormat,
        _ background: Bool,
        _ autoStop: Bool
    ) {
        UserDefaults.standard.set(quality.rawValue, forKey: "recording_quality")
        UserDefaults.standard.set(format.rawValue, forKey: "audio_format")
        UserDefaults.standard.set(background, forKey: "allow_background_recording")
        UserDefaults.standard.set(autoStop, forKey: "auto_stop_recording")
        UserDefaults.standard.set(autoStopDuration, forKey: "auto_stop_duration")
    }
    
    private func saveAISettings(
        _ language: SupportedLanguage,
        _ method: TranscriptionMethod,
        _ provider: LLMProvider,
        _ summarize: Bool
    ) {
        UserDefaults.standard.set(language.rawValue, forKey: "default_language")
        UserDefaults.standard.set(method.displayName, forKey: "transcription_method")
        UserDefaults.standard.set(provider.rawValue, forKey: "preferred_ai_provider")
        UserDefaults.standard.set(summarize, forKey: "auto_summarize")
        UserDefaults.standard.set(autoExtractKeywords, forKey: "auto_extract_keywords")
    }
    
    private func saveAppSettings(
        _ theme: AppTheme,
        _ language: AppLanguage,
        _ haptic: Bool,
        _ backup: Bool
    ) {
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        UserDefaults.standard.set(haptic, forKey: "haptic_feedback")
        UserDefaults.standard.set(backup, forKey: "auto_backup")
        UserDefaults.standard.set(backupFrequency.rawValue, forKey: "backup_frequency")
    }
    
    private func loadSubscriptionStatus() async {
        let subscription = await subscriptionService.currentSubscription
        isSubscriptionActive = subscription.isActive
        currentPlan = subscription.plan
    }
    
    private func loadAPIKeyStatus() async {
        do {
            configuredProviders = try await apiKeyManager.getAllStoredProviders()
            hasAPIKeys = !configuredProviders.isEmpty
        } catch {
            handleError(error)
        }
    }
    
    private func loadUsageData() async {
        do {
            let stats = try await usageTracker.getUsageStats()
            hasUsageData = stats.totalAPICallsThisMonth > 0
            monthlyUsageText = "\(stats.totalAPICallsThisMonth)"
            monthlyCostText = String(format: "$%.2f", stats.totalCostThisMonth)
            monthlyAPICalls = stats.totalAPICallsThisMonth
            
            // 録音時間の取得（仮実装）
            monthlyRecordingMinutes = UserDefaults.standard.integer(forKey: "monthly_recording_minutes")
        } catch {
            handleError(error)
        }
    }
    
    // handleError はプロトコルで実装済み
}

// MARK: - String Extension for URL Encoding

extension String {
    func addingPercentEncoding(forURLQueryValue: Bool) -> String? {
        let allowedCharacters = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&="))
        return addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
}

// MARK: - Mock Implementations for Preview

class MockSubscriptionServiceForPreview: SubscriptionServiceProtocol {
    var currentSubscription: SubscriptionStatus {
        get async {
            SubscriptionStatus(
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
        }
    }
    
    var currentPlan: SubscriptionPlan {
        get async { .free }
    }
    
    var isSubscriptionActive: Bool {
        get async { false }
    }
    
    func purchaseSubscription(_ plan: SubscriptionPlan) async throws -> SubscriptionStatus {
        throw SubscriptionError.unknownError
    }
    
    func restorePurchases() async throws -> SubscriptionStatus {
        throw SubscriptionError.unknownError
    }
    
    func hasEntitlement(_ entitlement: String) async -> Bool { false }
    func canUseFeature(_ feature: String) async -> Bool { false }
    func checkUsageLimits() async throws -> UsageStats {
        UsageStats(currentPeriodStart: Date(), currentPeriodEnd: Date(), projectsUsed: 0, recordingMinutesUsed: 0, apiCallsUsed: 0)
    }
    func getCurrentLimits() async -> SubscriptionLimits {
        SubscriptionPlan.free.limits
    }
    func recordProjectCreation() async throws {}
    func recordRecordingMinutes(_ minutes: Int) async throws {}
    func recordAPICall() async throws {}
    func getAvailableProducts() async throws -> [SubscriptionPlan] { [] }
    func getPriceString(for plan: SubscriptionPlan) async -> String? { nil }
    func configure(apiKey: String, appUserID: String?) async throws {}
    func setUserAttributes(_ attributes: [String: String]) async throws {}
    func startListening(onUpdate: @escaping (SubscriptionStatus) -> Void) {}
    func stopListening() {}
}

class MockAPIKeyManagerForPreview: APIKeyManagerProtocol {
    func storeAPIKey(_ key: String, for provider: LLMProvider) async throws {}
    func getAPIKey(for provider: LLMProvider) async throws -> String? { nil }
    func deleteAPIKey(for provider: LLMProvider) async throws {}
    func validateAPIKey(_ key: String, for provider: LLMProvider) async throws -> Bool { false }
    func getAllStoredProviders() async throws -> [LLMProvider] { [] }
    func getAPIKeyInfo(for provider: LLMProvider) async throws -> APIKeyInfo? { nil }
    func clearAllAPIKeys() async throws {}
    func hasValidAPIKey(for provider: LLMProvider) async -> Bool { false }
}

class MockAPIUsageTrackerForPreview: APIUsageTrackerProtocol {
    func recordAPICall(provider: LLMProvider, model: String, tokensUsed: Int, cost: Double) async throws {}
    func recordFailedAPICall(provider: LLMProvider, model: String, error: String) async throws {}
    func recordResponseTime(provider: LLMProvider, responseTime: TimeInterval) async throws {}
    func checkRateLimit(for provider: LLMProvider) async throws -> Bool { true }
    func getRateLimitStatus(for provider: LLMProvider) async throws -> RateLimitStatus {
        RateLimitStatus(provider: provider, requestsInCurrentMinute: 0, requestsInCurrentHour: 0, requestsInCurrentDay: 0, maxRequestsPerMinute: 60, maxRequestsPerHour: 3600, maxRequestsPerDay: 10000, canMakeRequest: true, nextAvailableTime: nil)
    }
    func updateRateLimits(for provider: LLMProvider, limits: RateLimitStatus) async throws {}
    func getMonthlyUsage(for month: Date?) async throws -> MonthlyUsage {
        MonthlyUsage(provider: .openAI(.gpt4), totalTokens: 0, totalCost: 0.0, requestCount: 0, audioMinutes: 0, period: DateInterval(start: Date(), duration: 86400 * 30), month: Date(), totalAPICalls: 0, providerBreakdown: [:])
    }
    func getDailyUsage(for date: Date) async throws -> [DailyUsage] { [] }
    func getProviderUsage(_ provider: LLMProvider, period: DateInterval?) async throws -> ProviderUsageStats {
        ProviderUsageStats(provider: provider, apiCalls: 0, tokens: 0, cost: 0.0, lastUsed: nil, averageResponseTime: 0.0, successRate: 0.0, topModels: [])
    }
    func getUsageHistory(provider: LLMProvider?, limit: Int) async throws -> [APIUsageRecord] { [] }
    func getUsageTrend(period: String, days: Int) async throws -> UsageTrend {
        UsageTrend(period: period, data: [])
    }
    func getCostBreakdown(for month: Date?) async throws -> [LLMProvider: Double] { [:] }
    func getPredictedCosts() async throws -> CostPrediction {
        CostPrediction(currentMonthProjected: 0.0, nextMonthEstimated: 0.0, recommendedBudget: 0.0, savingsOpportunities: [])
    }
    func getTopModels(limit: Int) async throws -> [(model: String, usage: Int)] { [] }
    func setUsageLimit(provider: LLMProvider, limit: Int, period: String) async throws {}
    func getUsageAlerts() async throws -> [UsageAlert] { [] }
    func checkUsageLimits() async throws -> [LimitStatus] { [] }
    func getSavingsSuggestions() async throws -> [SavingSuggestion] { [] }
    func getUnusedProviders(days: Int) async throws -> [LLMProvider] { [] }
    func getExpensiveOperations(limit: Int) async throws -> [APIUsageRecord] { [] }
    func exportUsageData(format: ExportFormat, period: DateInterval) async throws -> Data { Data() }
    func cleanupOldData(olderThan: Date) async throws {}
    func resetMonthlyUsage() async throws {}
    func configure(database: Any?) async throws {}
    func setRetentionPeriod(_ days: Int) async throws {}
    func enableRealTimeTracking(_ enabled: Bool) async throws {}
    
    func getUsageStats() async throws -> LLMUsageStats {
        LLMUsageStats(
            totalAPICallsThisMonth: 0,
            totalTokensThisMonth: 0,
            totalCostThisMonth: 0.0,
            remainingAPICallsThisMonth: 0,
            providerBreakdown: [:]
        )
    }
    
    // MARK: - UsageRecordingProtocol methods
    func recordBatchUsage(_ records: [UsageRecord]) async throws {}
    func getNextAvailableTime(for provider: LLMProvider) async -> Date? { nil }
    
    // MARK: - UsageLimitsProtocol methods
    func updateAlertSettings(_ settings: AlertSettings) async throws {}
    
    // MARK: - UsageOptimizationProtocol methods
    func analyzeUsagePatterns() async throws -> UsagePatternAnalysis {
        UsagePatternAnalysis(
            peakUsageHours: [],
            mostUsedProviders: [],
            averageCostPerRequest: 0.0,
            usageGrowthRate: 0.0,
            seasonalPatterns: [:],
            recommendedOptimizations: []
        )
    }
    
    // MARK: - UsageDataManagementProtocol methods
    func optimizeDatabase() async throws {}
    func backupData() async throws -> Data { Data() }
    func restoreData(from data: Data) async throws {}
    
    // MARK: - UsageConfigurationProtocol methods
    func getConfiguration() async throws -> UsageConfiguration {
        UsageConfiguration(
            retentionDays: 90,
            enableRealTimeTracking: true,
            enableAnalytics: true,
            exportFormats: [.json, .csv],
            alertSettings: AlertSettings(
                costThreshold: nil,
                usageThreshold: nil,
                dailyLimitWarning: true,
                monthlyLimitWarning: true,
                enableNotifications: true
            )
        )
    }
    func updateConfiguration(_ config: UsageConfiguration) async throws {}
}