import Foundation
import Security

enum APIKeyManagerError: Error, LocalizedError {
    case keychainWriteFailed
    case keychainReadFailed
    case keychainDeleteFailed
    case invalidAPIKey
    case biometricAuthenticationFailed
    case keyNotFound
    
    var errorDescription: String? {
        switch self {
        case .keychainWriteFailed:
            return "APIキーの保存に失敗しました"
        case .keychainReadFailed:
            return "APIキーの取得に失敗しました"
        case .keychainDeleteFailed:
            return "APIキーの削除に失敗しました"
        case .invalidAPIKey:
            return "無効なAPIキーです"
        case .biometricAuthenticationFailed:
            return "生体認証に失敗しました"
        case .keyNotFound:
            return "APIキーが見つかりません"
        }
    }
}

enum LLMProvider: String, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic Claude"
        case .gemini: return "Google Gemini"
        }
    }
    
    var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        }
    }
    
    var keyPrefix: String {
        switch self {
        case .openai: return "sk-"
        case .anthropic: return "sk-ant-"
        case .gemini: return "AIza"
        }
    }
}

struct APIKeyInfo {
    let provider: LLMProvider
    let key: String
    let isValid: Bool
    let lastValidated: Date?
    let createdAt: Date
    let updatedAt: Date
}

protocol APIKeyManagerProtocol {
    func storeAPIKey(_ key: String, for provider: LLMProvider) async throws
    func getAPIKey(for provider: LLMProvider) async throws -> String?
    func deleteAPIKey(for provider: LLMProvider) async throws
    func validateAPIKey(_ key: String, for provider: LLMProvider) async throws -> Bool
    func getAllStoredProviders() async throws -> [LLMProvider]
    func getAPIKeyInfo(for provider: LLMProvider) async throws -> APIKeyInfo?
    func clearAllAPIKeys() async throws
    func hasValidAPIKey(for provider: LLMProvider) async -> Bool
}