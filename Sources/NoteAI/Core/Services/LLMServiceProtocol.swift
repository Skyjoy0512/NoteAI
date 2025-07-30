import Foundation

enum LLMServiceError: Error, LocalizedError {
    case apiKeyNotFound
    case invalidAPIKey
    case networkError(String)
    case quotaExceeded
    case modelNotFound
    case invalidRequest(String)
    case responseParsingError
    case rateLimitExceeded
    case subscriptionRequired
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotFound:
            return "APIキーが設定されていません"
        case .invalidAPIKey:
            return "無効なAPIキーです"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .quotaExceeded:
            return "APIの使用制限に達しました"
        case .modelNotFound:
            return "指定されたモデルが見つかりません"
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        case .responseParsingError:
            return "レスポンスの解析に失敗しました"
        case .rateLimitExceeded:
            return "レート制限に達しました。しばらく待ってから再試行してください"
        case .subscriptionRequired:
            return "この機能を使用するにはプレミアムサブスクリプションが必要です"
        case .unknownError(let message):
            return "不明なエラー: \(message)"
        }
    }
    
    var userMessage: String {
        return errorDescription ?? "LLMサービスエラーが発生しました"
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
        case .unknownError: return "UNKNOWN_ERROR"
        }
    }
    
    var debugInfo: String? {
        return "LLM Service Error: \(errorCode)"
    }
}

enum LLMModel: String, CaseIterable {
    // OpenAI Models
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt35Turbo = "gpt-3.5-turbo"
    
    // Anthropic Models
    case claude3Opus = "claude-3-opus-20240229"
    case claude3Sonnet = "claude-3-sonnet-20240229"
    case claude3Haiku = "claude-3-haiku-20240307"
    
    // Google Models
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"
    case geminiPro = "gemini-pro"
    
    var provider: LLMProvider {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4Turbo, .gpt35Turbo:
            return .openAI(.gpt4)
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return .anthropic(.claude3Sonnet)
        case .gemini15Pro, .gemini15Flash, .geminiPro:
            return .gemini(.geminipro)
        }
    }
    
    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        case .claude3Opus: return "Claude 3 Opus"
        case .claude3Sonnet: return "Claude 3 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        case .gemini15Pro: return "Gemini 1.5 Pro"
        case .gemini15Flash: return "Gemini 1.5 Flash"
        case .geminiPro: return "Gemini Pro"
        }
    }
    
    var costPer1kTokens: (input: Double, output: Double) {
        switch self {
        case .gpt4o: return (5.0, 15.0)
        case .gpt4oMini: return (0.15, 0.6)
        case .gpt4Turbo: return (10.0, 30.0)
        case .gpt35Turbo: return (0.5, 1.5)
        case .claude3Opus: return (15.0, 75.0)
        case .claude3Sonnet: return (3.0, 15.0)
        case .claude3Haiku: return (0.25, 1.25)
        case .gemini15Pro: return (7.0, 21.0)
        case .gemini15Flash: return (0.35, 1.05)
        case .geminiPro: return (0.5, 1.5)
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .gpt4o, .gpt4oMini: return 128000
        case .gpt4Turbo, .gpt35Turbo: return 16000
        case .claude3Opus, .claude3Sonnet, .claude3Haiku: return 200000
        case .gemini15Pro, .gemini15Flash: return 1000000
        case .geminiPro: return 32000
        }
    }
}

struct LLMMessage {
    let role: String // "system", "user", "assistant"
    let content: String
}

struct LLMRequest {
    let model: LLMModel
    let messages: [LLMMessage]
    let maxTokens: Int?
    let temperature: Double?
    let systemPrompt: String?
}

struct LLMResponse {
    let content: String
    let model: LLMModel
    let tokensUsed: LLMTokenUsage
    let cost: Double
    let responseTime: TimeInterval
    let finishReason: String?
}

struct LLMTokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    
    var inputCost: Double {
        return 0.0 // モデル固有の計算は別途実装
    }
    
    var outputCost: Double {
        return 0.0 // モデル固有の計算は別途実装
    }
    
    var totalCost: Double {
        return inputCost + outputCost
    }
}

struct LLMUsageStats {
    let totalAPICallsThisMonth: Int
    let totalTokensThisMonth: Int
    let totalCostThisMonth: Double
    let remainingAPICallsThisMonth: Int
    let providerBreakdown: [LLMProvider: ProviderUsage]
}

struct ProviderUsage {
    let apiCalls: Int
    let tokens: Int
    let cost: Double
    let lastUsed: Date?
}

protocol LLMServiceProtocol {
    // Core LLM Functions
    func sendMessage(request: LLMRequest) async throws -> LLMResponse
    func summarizeText(_ text: String, model: LLMModel) async throws -> String
    func extractKeywords(_ text: String, model: LLMModel) async throws -> [String]
    func answerQuestion(_ question: String, context: String, model: LLMModel) async throws -> String
    
    // Provider-specific calls
    func callOpenAI(request: LLMRequest) async throws -> LLMResponse
    func callAnthropic(request: LLMRequest) async throws -> LLMResponse
    func callGemini(request: LLMRequest) async throws -> LLMResponse
    
    // Model & Provider Management
    func getAvailableModels(for provider: LLMProvider) async throws -> [LLMModel]
    func isModelAvailable(_ model: LLMModel) async -> Bool
    func getDefaultModel(for provider: LLMProvider) -> LLMModel
    func estimateCost(for request: LLMRequest) async -> Double
    
    // Usage & Analytics
    func getUsageStats() async throws -> LLMUsageStats
    func recordUsage(_ response: LLMResponse) async throws
    func checkRateLimit(for provider: LLMProvider) async throws -> Bool
    
    // Configuration
    func configure(apiKeyManager: APIKeyManagerProtocol, usageTracker: APIUsageTrackerProtocol?) async throws
    func setDefaultModel(_ model: LLMModel, for provider: LLMProvider) async
    func getPreferredModel(for task: String) async -> LLMModel
}