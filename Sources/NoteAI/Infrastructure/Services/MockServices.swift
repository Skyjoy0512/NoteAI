import Foundation

// MARK: - Temporary Mock Services for Phase 2
// These will be replaced with actual implementations in Phase 4

class MockAPITranscriptionService: APITranscriptionServiceProtocol {
    func transcribe(audioURL: URL, options: APITranscriptionOptions) async throws -> TranscriptionResult {
        // Mock implementation that throws subscription required error
        throw ApplicationError.featureNotAvailable("API文字起こしは現在開発中です")
    }
    
    func transcribeBatch(audioURLs: [URL], options: APITranscriptionOptions) async throws -> [TranscriptionResult] {
        throw ApplicationError.featureNotAvailable("API文字起こしは現在開発中です")
    }
    
    func getSupportedLanguages() async throws -> [String] {
        return ["ja", "en", "zh", "ko", "es", "fr", "de"]
    }
    
    func getAvailableModels() async throws -> [String] {
        return ["whisper-1", "whisper-large-v2", "whisper-large-v3"]
    }
    
    func getUsageStats() async throws -> APIUsageStats {
        return APIUsageStats(
            totalRequests: 0,
            totalDuration: 0,
            remainingQuota: nil,
            resetDate: nil,
            costThisMonth: 0.0
        )
    }
}

class MockSubscriptionService: SubscriptionServiceProtocol {
    // MARK: - Properties
    var currentSubscription: SubscriptionStatus {
        get async {
            return SubscriptionStatus(
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
        get async {
            return .free
        }
    }
    
    var isSubscriptionActive: Bool {
        get async {
            return false
        }
    }
    
    // MARK: - Purchase & Restore
    func purchaseSubscription(_ plan: SubscriptionPlan) async throws -> SubscriptionStatus {
        throw SubscriptionError.purchaseFailed("Mock service - purchase not available")
    }
    
    func restorePurchases() async throws -> SubscriptionStatus {
        return await currentSubscription
    }
    
    // MARK: - Entitlements & Limits
    func hasEntitlement(_ entitlement: String) async -> Bool {
        return false // Free tier has no entitlements
    }
    
    func canUseFeature(_ feature: String) async -> Bool {
        // Only basic features are available in free tier
        let freeFeatures = ["basic_recording", "basic_transcription", "basic_projects"]
        return freeFeatures.contains(feature)
    }
    
    func checkUsageLimits() async throws -> UsageStats {
        return UsageStats(
            currentPeriodStart: Calendar.current.startOfDay(for: Date()),
            currentPeriodEnd: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            projectsUsed: 0,
            recordingMinutesUsed: 0,
            apiCallsUsed: 0
        )
    }
    
    func getCurrentLimits() async -> SubscriptionLimits {
        return SubscriptionPlan.free.limits
    }
    
    // MARK: - Usage Tracking
    func recordProjectCreation() async throws {
        // Mock implementation - no tracking in free tier
    }
    
    func recordRecordingMinutes(_ minutes: Int) async throws {
        // Mock implementation - no tracking in free tier
    }
    
    func recordAPICall() async throws {
        // Mock implementation - no tracking in free tier
    }
    
    // MARK: - UI Support
    func getAvailableProducts() async throws -> [SubscriptionPlan] {
        return [.free, .premium]
    }
    
    func getPriceString(for plan: SubscriptionPlan) async -> String? {
        switch plan {
        case .free:
            return "無料"
        case .premium:
            return "¥980/月"
        }
    }
    
    // MARK: - Configuration
    func configure(apiKey: String, appUserID: String?) async throws {
        // Mock implementation - no configuration needed
    }
    
    func setUserAttributes(_ attributes: [String: String]) async throws {
        // Mock implementation - no attributes to set
    }
    
    // MARK: - Observers
    func startListening(onUpdate: @escaping (SubscriptionStatus) -> Void) {
        // Mock implementation - no updates to listen for
    }
    
    func stopListening() {
        // Mock implementation - nothing to stop
    }
}

// MARK: - Mock SyncDataManager for Testing

class MockSyncDataManager {
    private let mockProjectCount: Int
    private let mockRecordingCount: Int
    
    init(projectCount: Int = 5, recordingCount: Int = 10) {
        self.mockProjectCount = projectCount
        self.mockRecordingCount = recordingCount
    }
    
    func getProjectCount() async -> Int {
        return mockProjectCount
    }
    
    func getRecordingCount() async -> Int {
        return mockRecordingCount
    }
    
    func getAllProjectMetadata() async -> [ProjectSyncMetadata] {
        return (0..<mockProjectCount).map { index in
            ProjectSyncMetadata(
                id: UUID(),
                title: "Mock Project \(index + 1)",
                createdAt: Date(),
                modifiedAt: Date(),
                recordingCount: 2
            )
        }
    }
    
    func getAllRecordingMetadata() async -> [RecordingSyncMetadata] {
        return (0..<mockRecordingCount).map { index in
            RecordingSyncMetadata(
                id: UUID(),
                projectId: UUID(),
                filename: "mock_recording_\(index + 1).m4a",
                duration: 120.0,
                createdAt: Date(),
                transcriptionStatus: "completed",
                fileSize: 1024 * 1024,
                checksum: "mock_checksum_\(index)",
                fullTranscription: "This is a mock transcription for recording \(index + 1)"
            )
        }
    }
    
    func getAllRecordingSummaries() async -> [RecordingSummary] {
        return []
    }
    
    func getAllRecordingData() async -> [RecordingSyncMetadata] {
        return await getAllRecordingMetadata()
    }
}

// MARK: - Mock LLMProvider for APIUsageRepository

struct MockLLMProvider {
    let identifier: String
    
    var keychainIdentifier: String { identifier }
    var displayName: String { identifier }
    var baseURL: String { "" }
    var defaultModel: String { "" }
    var supportedModels: [String] { [] }
    
    func estimateCost(tokens: Int32, operation: APIOperationType) -> Double {
        return 0.0
    }
}