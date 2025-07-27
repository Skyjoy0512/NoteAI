import Foundation
import Security
import LocalAuthentication
import Alamofire

@MainActor
class APIKeyManager: APIKeyManagerProtocol {
    private let keychain = KeychainHelper()
    private let context = LAContext()
    
    private let keychainService = "com.noteai.apikeys"
    private let biometricPrompt = "APIキーにアクセスするために認証してください"
    
    func storeAPIKey(_ key: String, for provider: LLMProvider) async throws {
        // APIキーの基本的なバリデーション
        try validateKeyFormat(key, for: provider)
        
        // APIキーの有効性をチェック
        let isValid = try await validateAPIKey(key, for: provider)
        if !isValid {
            throw APIKeyManagerError.invalidAPIKey
        }
        
        // Keychainに保存
        let account = provider.rawValue
        let keyData = key.data(using: .utf8) ?? Data()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccessControl as String: try createAccessControl()
        ]
        
        // 既存のキーを削除してから新しいキーを追加
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(deleteQuery as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw APIKeyManagerError.keychainWriteFailed
        }
        
        // メタデータを保存
        try await saveKeyMetadata(for: provider, isValid: true)
    }
    
    func getAPIKey(for provider: LLMProvider) async throws -> String? {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: biometricPrompt
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let data = result as? Data,
               let key = String(data: data, encoding: .utf8) {
                return key
            }
        } else if status == errSecItemNotFound {
            return nil
        } else if status == errSecUserCancel {
            throw APIKeyManagerError.biometricAuthenticationFailed
        }
        
        throw APIKeyManagerError.keychainReadFailed
    }
    
    func deleteAPIKey(for provider: LLMProvider) async throws {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw APIKeyManagerError.keychainDeleteFailed
        }
        
        // メタデータも削除
        try await deleteKeyMetadata(for: provider)
    }
    
    func validateAPIKey(_ key: String, for provider: LLMProvider) async throws -> Bool {
        // 基本フォーマットチェック
        try validateKeyFormat(key, for: provider)
        
        // 実際のAPIコールでバリデーション
        return await performAPIValidation(key: key, provider: provider)
    }
    
    func getAllStoredProviders() async throws -> [LLMProvider] {
        var providers: [LLMProvider] = []
        
        for provider in LLMProvider.allCases {
            if await hasValidAPIKey(for: provider) {
                providers.append(provider)
            }
        }
        
        return providers
    }
    
    func getAPIKeyInfo(for provider: LLMProvider) async throws -> APIKeyInfo? {
        guard let key = try await getAPIKey(for: provider) else {
            return nil
        }
        
        let metadata = await getKeyMetadata(for: provider)
        
        return APIKeyInfo(
            provider: provider,
            key: maskAPIKey(key),
            isValid: metadata?.isValid ?? false,
            lastValidated: metadata?.lastValidated,
            createdAt: metadata?.createdAt ?? Date(),
            updatedAt: metadata?.updatedAt ?? Date()
        )
    }
    
    func clearAllAPIKeys() async throws {
        for provider in LLMProvider.allCases {
            try await deleteAPIKey(for: provider)
        }
    }
    
    func hasValidAPIKey(for provider: LLMProvider) async -> Bool {
        do {
            return try await getAPIKey(for: provider) != nil
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func validateKeyFormat(_ key: String, for provider: LLMProvider) throws {
        guard !key.isEmpty else {
            throw APIKeyManagerError.invalidAPIKey
        }
        
        // プロバイダー固有のフォーマットチェック
        switch provider {
        case .openai:
            if !key.hasPrefix(provider.keyPrefix) || key.count < 50 {
                throw APIKeyManagerError.invalidAPIKey
            }
        case .anthropic:
            if !key.hasPrefix(provider.keyPrefix) || key.count < 50 {
                throw APIKeyManagerError.invalidAPIKey
            }
        case .gemini:
            if !key.hasPrefix(provider.keyPrefix) || key.count < 30 {
                throw APIKeyManagerError.invalidAPIKey
            }
        }
    }
    
    private func performAPIValidation(key: String, provider: LLMProvider) async -> Bool {
        do {
            switch provider {
            case .openai:
                return await validateOpenAIKey(key)
            case .anthropic:
                return await validateAnthropicKey(key)
            case .gemini:
                return await validateGeminiKey(key)
            }
        } catch {
            return false
        }
    }
    
    private func validateOpenAIKey(_ key: String) async -> Bool {
        let url = "https://api.openai.com/v1/models"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(key)",
            "Content-Type": "application/json"
        ]
        
        return await withCheckedContinuation { continuation in
            AF.request(url, headers: headers)
                .validate()
                .response { response in
                    continuation.resume(returning: response.response?.statusCode == 200)
                }
        }
    }
    
    private func validateAnthropicKey(_ key: String) async -> Bool {
        let url = "https://api.anthropic.com/v1/messages"
        let headers: HTTPHeaders = [
            "x-api-key": key,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01"
        ]
        
        let parameters: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        return await withCheckedContinuation { continuation in
            AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .response { response in
                    // 401以外なら有効（実際のリクエストは不要なので400番台でもOK）
                    let statusCode = response.response?.statusCode ?? 0
                    continuation.resume(returning: statusCode != 401)
                }
        }
    }
    
    private func validateGeminiKey(_ key: String) async -> Bool {
        let url = "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)"
        
        return await withCheckedContinuation { continuation in
            AF.request(url)
                .validate()
                .response { response in
                    continuation.resume(returning: response.response?.statusCode == 200)
                }
        }
    }
    
    private func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryAny,
            &error
        ) else {
            throw APIKeyManagerError.biometricAuthenticationFailed
        }
        return accessControl
    }
    
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        let start = String(key.prefix(4))
        let end = String(key.suffix(4))
        return "\(start)...\(end)"
    }
    
    // MARK: - Metadata Management
    
    private struct KeyMetadata: Codable {
        let isValid: Bool
        let lastValidated: Date?
        let createdAt: Date
        let updatedAt: Date
    }
    
    private func saveKeyMetadata(for provider: LLMProvider, isValid: Bool) async throws {
        let metadata = KeyMetadata(
            isValid: isValid,
            lastValidated: isValid ? Date() : nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let key = "metadata_\(provider.rawValue)"
        let data = try JSONEncoder().encode(metadata)
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func getKeyMetadata(for provider: LLMProvider) async -> KeyMetadata? {
        let key = "metadata_\(provider.rawValue)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyMetadata.self, from: data)
    }
    
    private func deleteKeyMetadata(for provider: LLMProvider) async throws {
        let key = "metadata_\(provider.rawValue)"
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Keychain Helper

private class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
}