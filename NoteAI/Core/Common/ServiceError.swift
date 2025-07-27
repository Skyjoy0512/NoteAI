import Foundation

// MARK: - 統一サービスエラー

enum NoteAIServiceError: NoteAIError {
    case apiKey(APIKeyServiceError)
    case usage(UsageTrackingError)
    case llm(LLMServiceError)
    case subscription(SubscriptionError)
    case configuration(ConfigurationError)
    case network(NetworkError)
    
    var userMessage: String {
        switch self {
        case .apiKey(let error):
            return error.userMessage
        case .usage(let error):
            return error.userMessage
        case .llm(let error):
            return error.userMessage
        case .subscription(let error):
            return error.userMessage
        case .configuration(let error):
            return error.userMessage
        case .network(let error):
            return error.userMessage
        }
    }
    
    var errorCode: String {
        switch self {
        case .apiKey(let error):
            return "API_KEY_\(error.errorCode)"
        case .usage(let error):
            return "USAGE_\(error.errorCode)"
        case .llm(let error):
            return "LLM_\(error.errorCode)"
        case .subscription(let error):
            return "SUBSCRIPTION_\(error.errorCode)"
        case .configuration(let error):
            return "CONFIG_\(error.errorCode)"
        case .network(let error):
            return "NETWORK_\(error.errorCode)"
        }
    }
}

// MARK: - APIキーサービスエラー

enum APIKeyServiceError: Error, LocalizedError {
    case keychainWriteFailed
    case keychainReadFailed
    case keychainDeleteFailed
    case invalidAPIKey(provider: String)
    case biometricAuthenticationFailed
    case keyNotFound(provider: String)
    case validationFailed(provider: String, reason: String)
    
    var userMessage: String {
        switch self {
        case .keychainWriteFailed:
            return "APIキーの保存に失敗しました"
        case .keychainReadFailed:
            return "APIキーの取得に失敗しました"
        case .keychainDeleteFailed:
            return "APIキーの削除に失敗しました"
        case .invalidAPIKey(let provider):
            return "\(provider)の無効なAPIキーです"
        case .biometricAuthenticationFailed:
            return "生体認証に失敗しました"
        case .keyNotFound(let provider):
            return "\(provider)のAPIキーが見つかりません"
        case .validationFailed(let provider, let reason):
            return "\(provider)のAPIキー検証に失敗しました: \(reason)"
        }
    }
    
    var errorCode: String {
        switch self {
        case .keychainWriteFailed: return "KEYCHAIN_WRITE_FAILED"
        case .keychainReadFailed: return "KEYCHAIN_READ_FAILED"
        case .keychainDeleteFailed: return "KEYCHAIN_DELETE_FAILED"
        case .invalidAPIKey: return "INVALID_API_KEY"
        case .biometricAuthenticationFailed: return "BIOMETRIC_AUTH_FAILED"
        case .keyNotFound: return "KEY_NOT_FOUND"
        case .validationFailed: return "VALIDATION_FAILED"
        }
    }
}

// MARK: - 使用量追跡エラー

enum UsageTrackingError: Error, LocalizedError {
    case databaseError(message: String)
    case rateLimitExceeded(provider: String)
    case usageLimitExceeded(type: String, limit: Int)
    case invalidProvider(provider: String)
    case configurationError(message: String)
    case dataExportFailed(format: String)
    case analyticsCalculationFailed
    
    var userMessage: String {
        switch self {
        case .databaseError(let message):
            return "データベースエラー: \(message)"
        case .rateLimitExceeded(let provider):
            return "\(provider)のレート制限に達しました"
        case .usageLimitExceeded(let type, let limit):
            return "\(type)の使用制限(\(limit))に達しました"
        case .invalidProvider(let provider):
            return "無効なプロバイダー: \(provider)"
        case .configurationError(let message):
            return "設定エラー: \(message)"
        case .dataExportFailed(let format):
            return "\(format)形式でのデータエクスポートに失敗しました"
        case .analyticsCalculationFailed:
            return "使用量分析の計算に失敗しました"
        }
    }
    
    var errorCode: String {
        switch self {
        case .databaseError: return "DATABASE_ERROR"
        case .rateLimitExceeded: return "RATE_LIMIT_EXCEEDED"
        case .usageLimitExceeded: return "USAGE_LIMIT_EXCEEDED"
        case .invalidProvider: return "INVALID_PROVIDER"
        case .configurationError: return "CONFIGURATION_ERROR"
        case .dataExportFailed: return "DATA_EXPORT_FAILED"
        case .analyticsCalculationFailed: return "ANALYTICS_CALCULATION_FAILED"
        }
    }
}

// MARK: - LLMサービスエラー

enum LLMServiceError: Error, LocalizedError {
    case apiKeyNotFound(provider: String)
    case invalidAPIKey(provider: String)
    case networkError(provider: String, message: String)
    case quotaExceeded(provider: String)
    case modelNotFound(model: String)
    case invalidRequest(message: String)
    case responseParsingError(provider: String)
    case rateLimitExceeded(provider: String, retryAfter: TimeInterval?)
    case subscriptionRequired(feature: String)
    case providerUnavailable(provider: String)
    
    var userMessage: String {
        switch self {
        case .apiKeyNotFound(let provider):
            return "\(provider)のAPIキーが設定されていません"
        case .invalidAPIKey(let provider):
            return "\(provider)の無効なAPIキーです"
        case .networkError(let provider, let message):
            return "\(provider): ネットワークエラー - \(message)"
        case .quotaExceeded(let provider):
            return "\(provider)のAPIクォータを超過しました"
        case .modelNotFound(let model):
            return "モデル '\(model)' が見つかりません"
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        case .responseParsingError(let provider):
            return "\(provider)のレスポンス解析に失敗しました"
        case .rateLimitExceeded(let provider, let retryAfter):
            if let retryAfter = retryAfter {
                return "\(provider)のレート制限に達しました。\(Int(retryAfter))秒後に再試行してください"
            } else {
                return "\(provider)のレート制限に達しました"
            }
        case .subscriptionRequired(let feature):
            return "\(feature)を使用するにはプレミアムサブスクリプションが必要です"
        case .providerUnavailable(let provider):
            return "\(provider)は現在利用できません"
        }
    }
    
    var errorCode: String {
        switch self {
        case .apiKeyNotFound: return "API_KEY_NOT_FOUND"
        case .invalidAPIKey: return "INVALID_API_KEY"
        case .networkError: return "NETWORK_ERROR"
        case .quotaExceeded: return "QUOTA_EXCEEDED"
        case .modelNotFound: return "MODEL_NOT_FOUND"
        case .invalidRequest: return "INVALID_REQUEST"
        case .responseParsingError: return "RESPONSE_PARSING_ERROR"
        case .rateLimitExceeded: return "RATE_LIMIT_EXCEEDED"
        case .subscriptionRequired: return "SUBSCRIPTION_REQUIRED"
        case .providerUnavailable: return "PROVIDER_UNAVAILABLE"
        }
    }
}

// MARK: - サブスクリプションエラー

enum SubscriptionError: Error, LocalizedError {
    case revenueCatNotConfigured
    case purchaseFailed(reason: String)
    case restoreFailed(reason: String)
    case subscriptionNotFound(plan: String)
    case networkError(message: String)
    case userCancelled
    case paymentDeclined
    case limitReached(type: String, current: Int, limit: Int)
    case entitlementNotFound(entitlement: String)
    
    var userMessage: String {
        switch self {
        case .revenueCatNotConfigured:
            return "課金システムが設定されていません"
        case .purchaseFailed(let reason):
            return "購入に失敗しました: \(reason)"
        case .restoreFailed(let reason):
            return "復元に失敗しました: \(reason)"
        case .subscriptionNotFound(let plan):
            return "サブスクリプション '\(plan)' が見つかりません"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .userCancelled:
            return "ユーザーによってキャンセルされました"
        case .paymentDeclined:
            return "支払いが拒否されました"
        case .limitReached(let type, let current, let limit):
            return "\(type)の制限(\(limit))に達しました。現在の使用量: \(current)"
        case .entitlementNotFound(let entitlement):
            return "エンタイトルメント '\(entitlement)' が見つかりません"
        }
    }
    
    var errorCode: String {
        switch self {
        case .revenueCatNotConfigured: return "REVENUE_CAT_NOT_CONFIGURED"
        case .purchaseFailed: return "PURCHASE_FAILED"
        case .restoreFailed: return "RESTORE_FAILED"
        case .subscriptionNotFound: return "SUBSCRIPTION_NOT_FOUND"
        case .networkError: return "NETWORK_ERROR"
        case .userCancelled: return "USER_CANCELLED"
        case .paymentDeclined: return "PAYMENT_DECLINED"
        case .limitReached: return "LIMIT_REACHED"
        case .entitlementNotFound: return "ENTITLEMENT_NOT_FOUND"
        }
    }
}

// MARK: - 設定エラー

enum ConfigurationError: Error, LocalizedError {
    case invalidValue(key: String, value: Any)
    case keyNotFound(key: String)
    case storageError(message: String)
    case validationFailed(key: String, reason: String)
    case migrationFailed(from: String, to: String)
    case corruptedData(key: String)
    
    var userMessage: String {
        switch self {
        case .invalidValue(let key, let value):
            return "設定項目 '\(key)' の値 '\(value)' が無効です"
        case .keyNotFound(let key):
            return "設定項目 '\(key)' が見つかりません"
        case .storageError(let message):
            return "設定の保存エラー: \(message)"
        case .validationFailed(let key, let reason):
            return "設定項目 '\(key)' の検証に失敗しました: \(reason)"
        case .migrationFailed(let from, let to):
            return "設定の移行に失敗しました (v\(from) → v\(to))"
        case .corruptedData(let key):
            return "設定項目 '\(key)' のデータが破損しています"
        }
    }
    
    var errorCode: String {
        switch self {
        case .invalidValue: return "INVALID_VALUE"
        case .keyNotFound: return "KEY_NOT_FOUND"
        case .storageError: return "STORAGE_ERROR"
        case .validationFailed: return "VALIDATION_FAILED"
        case .migrationFailed: return "MIGRATION_FAILED"
        case .corruptedData: return "CORRUPTED_DATA"
        }
    }
}

// MARK: - ネットワークエラー

enum NetworkError: Error, LocalizedError {
    case noInternetConnection
    case requestTimeout
    case serverError(statusCode: Int, message: String?)
    case invalidURL(url: String)
    case decodingError(type: String)
    case encodingError(message: String)
    case sslError
    case rateLimited(retryAfter: TimeInterval?)
    
    var userMessage: String {
        switch self {
        case .noInternetConnection:
            return "インターネット接続がありません"
        case .requestTimeout:
            return "リクエストがタイムアウトしました"
        case .serverError(let statusCode, let message):
            if let message = message {
                return "サーバーエラー (\(statusCode)): \(message)"
            } else {
                return "サーバーエラー (\(statusCode))"
            }
        case .invalidURL(let url):
            return "無効なURL: \(url)"
        case .decodingError(let type):
            return "データ解析エラー: \(type)"
        case .encodingError(let message):
            return "データエンコードエラー: \(message)"
        case .sslError:
            return "SSL接続エラー"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "レート制限に達しました。\(Int(retryAfter))秒後に再試行してください"
            } else {
                return "レート制限に達しました"
            }
        }
    }
    
    var errorCode: String {
        switch self {
        case .noInternetConnection: return "NO_INTERNET_CONNECTION"
        case .requestTimeout: return "REQUEST_TIMEOUT"
        case .serverError: return "SERVER_ERROR"
        case .invalidURL: return "INVALID_URL"
        case .decodingError: return "DECODING_ERROR"
        case .encodingError: return "ENCODING_ERROR"
        case .sslError: return "SSL_ERROR"
        case .rateLimited: return "RATE_LIMITED"
        }
    }
}

// MARK: - エラー変換ヘルパー

extension NoteAIServiceError {
    static func convert(_ error: Error) -> NoteAIServiceError {
        if let serviceError = error as? NoteAIServiceError {
            return serviceError
        }
        
        // 既存のエラー型を新しい統一エラー型に変換
        if let apiKeyError = error as? APIKeyManagerError {
            return .apiKey(convertAPIKeyError(apiKeyError))
        }
        
        if let usageError = error as? APIUsageTrackerError {
            return .usage(convertUsageError(usageError))
        }
        
        // デフォルトは設定エラーとして扱う
        return .configuration(.storageError(message: error.localizedDescription))
    }
    
    private static func convertAPIKeyError(_ error: APIKeyManagerError) -> APIKeyServiceError {
        switch error {
        case .keychainWriteFailed:
            return .keychainWriteFailed
        case .keychainReadFailed:
            return .keychainReadFailed
        case .keychainDeleteFailed:
            return .keychainDeleteFailed
        case .invalidAPIKey:
            return .invalidAPIKey(provider: "unknown")
        case .biometricAuthenticationFailed:
            return .biometricAuthenticationFailed
        case .keyNotFound:
            return .keyNotFound(provider: "unknown")
        }
    }
    
    private static func convertUsageError(_ error: APIUsageTrackerError) -> UsageTrackingError {
        switch error {
        case .databaseError(let message):
            return .databaseError(message: message)
        case .rateLimitExceeded:
            return .rateLimitExceeded(provider: "unknown")
        case .usageLimitExceeded:
            return .usageLimitExceeded(type: "unknown", limit: 0)
        case .invalidProvider:
            return .invalidProvider(provider: "unknown")
        case .configurationError:
            return .configurationError(message: "Configuration error")
        }
    }
}