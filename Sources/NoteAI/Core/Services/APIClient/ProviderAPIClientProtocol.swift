import Foundation

// MARK: - API共通プロトコル

protocol ProviderAPIClientProtocol {
    var provider: LLMProvider { get }
    var baseURL: String { get }
    
    /// APIリクエストを実行
    func makeRequest<T: Codable>(
        _ request: APIRequest,
        responseType: T.Type
    ) async throws -> T
    
    /// APIキーを検証
    func validateAPIKey(_ apiKey: String) async throws -> Bool
    
    /// モデル一覧を取得
    func getAvailableModels() async throws -> [String]
    
    /// 使用量情報を取得
    func getUsageInfo() async throws -> ProviderUsageInfo?
    
    /// レート制限情報を取得
    func getRateLimitInfo() async throws -> ProviderRateLimitInfo
}

// MARK: - APIリクエスト構造

struct APIRequest {
    let endpoint: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    
    init(
        endpoint: String,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30.0
    ) {
        self.endpoint = endpoint
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - プロバイダー情報構造

struct ProviderUsageInfo {
    let totalRequests: Int
    let remainingQuota: Int?
    let billingCycle: String
    let currentCost: Double
    let lastResetDate: Date?
}

struct ProviderRateLimitInfo {
    let requestsPerMinute: Int
    let requestsPerHour: Int
    let requestsPerDay: Int
    let currentUsage: RateLimitUsage
    let resetTimes: RateLimitResetTimes
}

struct RateLimitUsage {
    let perMinute: Int
    let perHour: Int
    let perDay: Int
}

struct RateLimitResetTimes {
    let nextMinuteReset: Date
    let nextHourReset: Date
    let nextDayReset: Date
}

// MARK: - プロバイダー別実装

protocol OpenAIClientProtocol: ProviderAPIClientProtocol {
    func createChatCompletion(request: OpenAIChatRequest) async throws -> OpenAIChatResponse
    func listModels() async throws -> OpenAIModelsResponse
    func getUsage(date: Date) async throws -> OpenAIUsageResponse
}

protocol AnthropicClientProtocol: ProviderAPIClientProtocol {
    func createMessage(request: AnthropicMessageRequest) async throws -> AnthropicMessageResponse
    func getModels() async throws -> [String]
}

protocol GeminiClientProtocol: ProviderAPIClientProtocol {
    func generateContent(request: GeminiRequest) async throws -> GeminiResponse
    func listModels() async throws -> GeminiModelsResponse
}

// MARK: - OpenAI型定義

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int?
    let temperature: Double?
    let topP: Double?
    let stop: [String]?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case stop
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct OpenAIModelsResponse: Codable {
    let object: String
    let data: [OpenAIModelInfo]
}

struct OpenAIModelInfo: Codable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

struct OpenAIUsageResponse: Codable {
    let object: String
    let data: [OpenAIDayUsage]
}

struct OpenAIDayUsage: Codable {
    let aggregationTimestamp: Int
    let nRequests: Int
    let operation: String
    let snapshotId: String
    
    enum CodingKeys: String, CodingKey {
        case aggregationTimestamp = "aggregation_timestamp"
        case nRequests = "n_requests"
        case operation
        case snapshotId = "snapshot_id"
    }
}

// MARK: - Anthropic型定義

struct AnthropicMessageRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]
    let system: String?
    let temperature: Double?
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
    }
}

struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

struct AnthropicMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: AnthropicUsage
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

struct AnthropicContent: Codable {
    let type: String
    let text: String
}

struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Gemini型定義

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
    let systemInstruction: GeminiContent?
    
    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig = "generationConfig"
        case systemInstruction = "systemInstruction"
    }
}

struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Codable {
    let maxOutputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    
    enum CodingKeys: String, CodingKey {
        case maxOutputTokens = "maxOutputTokens"
        case temperature
        case topP = "topP"
        case topK = "topK"
    }
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
    let usageMetadata: GeminiUsageMetadata?
    
    enum CodingKeys: String, CodingKey {
        case candidates
        case usageMetadata = "usageMetadata"
    }
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    let index: Int
    
    enum CodingKeys: String, CodingKey {
        case content
        case finishReason = "finishReason"
        case index
    }
}

struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int
    let candidatesTokenCount: Int
    let totalTokenCount: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokenCount = "promptTokenCount"
        case candidatesTokenCount = "candidatesTokenCount"
        case totalTokenCount = "totalTokenCount"
    }
}

struct GeminiModelsResponse: Codable {
    let models: [GeminiModelInfo]
}

struct GeminiModelInfo: Codable {
    let name: String
    let displayName: String
    let description: String
    let inputTokenLimit: Int
    let outputTokenLimit: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "displayName"
        case description
        case inputTokenLimit = "inputTokenLimit"
        case outputTokenLimit = "outputTokenLimit"
    }
}

// MARK: - エラー型

enum APIClientError: Error, LocalizedError {
    case invalidURL(String)
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case encodingError(Error)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case quotaExceeded
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noAPIKey:
            return "No API key provided"
        case .invalidAPIKey:
            return "Invalid API key"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(retryAfter) seconds"
            } else {
                return "Rate limit exceeded"
            }
        case .quotaExceeded:
            return "Quota exceeded"
        case .timeout:
            return "Request timeout"
        }
    }
}