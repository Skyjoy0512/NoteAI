import Foundation

// MARK: - Base Error Protocol

protocol NoteAIError: LocalizedError {
    var errorCode: String { get }
    var userMessage: String { get }
    var debugInfo: String? { get }
}

extension NoteAIError {
    var errorDescription: String? {
        return userMessage
    }
    
    var recoverySuggestion: String? {
        return debugInfo
    }
}

// MARK: - Domain Errors

enum DomainError: NoteAIError {
    case invalidInput(String)
    case businessRuleViolation(String)
    case resourceNotFound(String)
    case operationNotAllowed(String)
    
    var errorCode: String {
        switch self {
        case .invalidInput: return "DOMAIN_INVALID_INPUT"
        case .businessRuleViolation: return "DOMAIN_BUSINESS_RULE"
        case .resourceNotFound: return "DOMAIN_NOT_FOUND"
        case .operationNotAllowed: return "DOMAIN_NOT_ALLOWED"
        }
    }
    
    var userMessage: String {
        switch self {
        case .invalidInput(let message):
            return "入力が無効です: \(message)"
        case .businessRuleViolation(let message):
            return "操作を実行できません: \(message)"
        case .resourceNotFound(let resource):
            return "\(resource)が見つかりません"
        case .operationNotAllowed(let operation):
            return "\(operation)は許可されていません"
        }
    }
    
    var debugInfo: String? {
        switch self {
        case .invalidInput(let message),
             .businessRuleViolation(let message),
             .resourceNotFound(let message),
             .operationNotAllowed(let message):
            return message
        }
    }
}

// MARK: - Infrastructure Errors

enum InfrastructureError: NoteAIError {
    case databaseError(Error)
    case networkError(Error)
    case fileSystemError(Error)
    case authenticationError(String)
    case configurationError(String)
    
    var errorCode: String {
        switch self {
        case .databaseError: return "INFRA_DATABASE"
        case .networkError: return "INFRA_NETWORK"
        case .fileSystemError: return "INFRA_FILESYSTEM"
        case .authenticationError: return "INFRA_AUTH"
        case .configurationError: return "INFRA_CONFIG"
        }
    }
    
    var userMessage: String {
        switch self {
        case .databaseError:
            return "データベースエラーが発生しました"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .fileSystemError:
            return "ファイル操作エラーが発生しました"
        case .authenticationError:
            return "認証エラーが発生しました"
        case .configurationError:
            return "設定エラーが発生しました"
        }
    }
    
    var debugInfo: String? {
        switch self {
        case .databaseError(let error),
             .networkError(let error),
             .fileSystemError(let error):
            return error.localizedDescription
        case .authenticationError(let message),
             .configurationError(let message):
            return message
        }
    }
}

// MARK: - Application Errors

enum ApplicationError: NoteAIError {
    case unexpectedState(String)
    case featureNotAvailable(String)
    case permissionDenied(String)
    case quotaExceeded(String)
    
    var errorCode: String {
        switch self {
        case .unexpectedState: return "APP_UNEXPECTED_STATE"
        case .featureNotAvailable: return "APP_FEATURE_UNAVAILABLE"
        case .permissionDenied: return "APP_PERMISSION_DENIED"
        case .quotaExceeded: return "APP_QUOTA_EXCEEDED"
        }
    }
    
    var userMessage: String {
        switch self {
        case .unexpectedState:
            return "予期しないエラーが発生しました"
        case .featureNotAvailable(let feature):
            return "\(feature)は現在利用できません"
        case .permissionDenied(let action):
            return "\(action)の権限がありません"
        case .quotaExceeded(let resource):
            return "\(resource)の制限を超えています"
        }
    }
    
    var debugInfo: String? {
        switch self {
        case .unexpectedState(let state),
             .featureNotAvailable(let feature),
             .permissionDenied(let action),
             .quotaExceeded(let resource):
            return "Details: \(state)\(feature)\(action)\(resource)"
        }
    }
}

// MARK: - Error Mapper

struct ErrorMapper {
    static func map(_ error: Error) -> NoteAIError {
        if let noteAIError = error as? NoteAIError {
            return noteAIError
        }
        
        // システムエラーを適切なカテゴリにマッピング
        if error is DecodingError || error is EncodingError {
            return InfrastructureError.databaseError(error)
        }
        
        // その他は予期しないエラーとして扱う
        return ApplicationError.unexpectedState(error.localizedDescription)
    }
}