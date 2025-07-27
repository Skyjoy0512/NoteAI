import Foundation

// MARK: - Temporary Mock Services for Phase 2
// These will be replaced with actual implementations in Phase 4

class MockAPITranscriptionService: APITranscriptionServiceProtocol {
    func transcribe(audioURL: URL, provider: LLMProvider, language: String) async throws -> TranscriptionResult {
        // Mock implementation that throws subscription required error
        throw ApplicationError.featureNotAvailable("API文字起こしは現在開発中です")
    }
}

class MockSubscriptionService: SubscriptionServiceProtocol {
    func hasActiveSubscription() async -> Bool {
        // For Phase 2, always return false (free tier only)
        return false
    }
}

// MARK: - Mock LLMProvider for APIUsageRepository

struct MockLLMProvider: LLMProvider {
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