import Foundation
import Alamofire

// MARK: - 基底APIクライアント

class BaseAPIClient: ProviderAPIClientProtocol {
    let provider: LLMProvider
    let baseURL: String
    private let session: Session
    private let keyManager: APIKeyManagerProtocol
    
    init(
        provider: LLMProvider,
        keyManager: APIKeyManagerProtocol,
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.provider = provider
        self.baseURL = provider.baseURL
        self.keyManager = keyManager
        
        // タイムアウト設定
        sessionConfiguration.timeoutIntervalForRequest = 30.0
        sessionConfiguration.timeoutIntervalForResource = 60.0
        
        self.session = Session(configuration: sessionConfiguration)
    }
    
    // MARK: - プロトコル実装
    
    func makeRequest<T: Codable>(
        _ request: APIRequest,
        responseType: T.Type
    ) async throws -> T {
        
        guard let apiKey = try await keyManager.getAPIKey(for: provider) else {
            throw APIClientError.noAPIKey
        }
        
        let url = baseURL + request.endpoint
        
        var headers = HTTPHeaders(request.headers)
        headers = try addAuthenticationHeaders(headers, apiKey: apiKey)
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: HTTPMethod(rawValue: request.method.rawValue) ?? .get,
                headers: headers
            )
            .validate(statusCode: 200..<300)
            .responseData { response in
                self.handleResponse(response, responseType: responseType, continuation: continuation)
            }
        }
    }
    
    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        // サブクラスでオーバーライド
        return false
    }
    
    func getAvailableModels() async throws -> [String] {
        // サブクラスでオーバーライド
        return []
    }
    
    func getUsageInfo() async throws -> ProviderUsageInfo? {
        // サブクラスでオーバーライド
        return nil
    }
    
    func getRateLimitInfo() async throws -> ProviderRateLimitInfo {
        // デフォルト実装
        return ProviderRateLimitInfo(
            requestsPerMinute: provider.defaultRateLimits.perMinute,
            requestsPerHour: provider.defaultRateLimits.perHour,
            requestsPerDay: provider.defaultRateLimits.perDay,
            currentUsage: RateLimitUsage(perMinute: 0, perHour: 0, perDay: 0),
            resetTimes: RateLimitResetTimes(
                nextMinuteReset: Date().addingTimeInterval(60),
                nextHourReset: Date().addingTimeInterval(3600),
                nextDayReset: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            )
        )
    }
    
    // MARK: - 内部メソッド
    
    private func addAuthenticationHeaders(
        _ headers: HTTPHeaders,
        apiKey: String
    ) throws -> HTTPHeaders {
        var modifiedHeaders = headers
        
        switch provider {
        case .openai:
            modifiedHeaders["Authorization"] = "Bearer \(apiKey)"
            modifiedHeaders["Content-Type"] = "application/json"
            
        case .anthropic:
            modifiedHeaders["x-api-key"] = apiKey
            modifiedHeaders["Content-Type"] = "application/json"
            modifiedHeaders["anthropic-version"] = "2023-06-01"
            
        case .gemini:
            // Geminiはクエリパラメータで認証
            modifiedHeaders["Content-Type"] = "application/json"
        }
        
        return modifiedHeaders
    }
    
    private func handleResponse<T: Codable>(
        _ response: DataResponse<Data, AFError>,
        responseType: T.Type,
        continuation: CheckedContinuation<T, Error>
    ) {
        switch response.result {
        case .success(let data):
            do {
                let decodedResponse = try JSONDecoder().decode(responseType, from: data)
                continuation.resume(returning: decodedResponse)
            } catch {
                continuation.resume(throwing: APIClientError.decodingError(error))
            }
            
        case .failure(let error):
            let apiError = convertAlamofireError(error, response: response.response, data: response.data)
            continuation.resume(throwing: apiError)
        }
    }
    
    private func convertAlamofireError(
        _ error: AFError,
        response: HTTPURLResponse?,
        data: Data?
    ) -> APIClientError {
        
        if let statusCode = response?.statusCode {
            switch statusCode {
            case 401:
                return .invalidAPIKey
            case 429:
                let retryAfter = parseRetryAfter(from: response)
                return .rateLimitExceeded(retryAfter: retryAfter)
            case 402, 403:
                return .quotaExceeded
            default:
                return .httpError(statusCode: statusCode, data: data)
            }
        }
        
        if error.isTimeout {
            return .timeout
        }
        
        return .networkError(error)
    }
    
    private func parseRetryAfter(from response: HTTPURLResponse?) -> TimeInterval? {
        guard let retryAfterHeader = response?.value(forHTTPHeaderField: "Retry-After"),
              let retryAfter = TimeInterval(retryAfterHeader) else {
            return nil
        }
        return retryAfter
    }
}

// MARK: - プロバイダー別実装

class OpenAIAPIClient: BaseAPIClient, OpenAIClientProtocol {
    
    override init(keyManager: APIKeyManagerProtocol) {
        super.init(provider: .openai, keyManager: keyManager)
    }
    
    func createChatCompletion(request: OpenAIChatRequest) async throws -> OpenAIChatResponse {
        let apiRequest = APIRequest(
            endpoint: "/chat/completions",
            method: .POST,
            body: try JSONEncoder().encode(request)
        )
        
        return try await makeRequest(apiRequest, responseType: OpenAIChatResponse.self)
    }
    
    func listModels() async throws -> OpenAIModelsResponse {
        let apiRequest = APIRequest(endpoint: "/models", method: .GET)
        return try await makeRequest(apiRequest, responseType: OpenAIModelsResponse.self)
    }
    
    func getUsage(date: Date) async throws -> OpenAIUsageResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let apiRequest = APIRequest(
            endpoint: "/usage?date=\(dateString)",
            method: .GET
        )
        
        return try await makeRequest(apiRequest, responseType: OpenAIUsageResponse.self)
    }
    
    override func validateAPIKey(_ apiKey: String) async throws -> Bool {
        do {
            _ = try await listModels()
            return true
        } catch {
            return false
        }
    }
    
    override func getAvailableModels() async throws -> [String] {
        let response = try await listModels()
        return response.data.map { $0.id }
    }
    
    override func getUsageInfo() async throws -> ProviderUsageInfo? {
        do {
            let today = Date()
            let response = try await getUsage(date: today)
            
            let totalRequests = response.data.reduce(0) { $0 + $1.nRequests }
            
            return ProviderUsageInfo(
                totalRequests: totalRequests,
                remainingQuota: nil,
                billingCycle: "monthly",
                currentCost: 0.0, // OpenAIは使用量APIでコスト情報を提供しない
                lastResetDate: Calendar.current.startOfDay(for: today)
            )
        } catch {
            return nil
        }
    }
}

class AnthropicAPIClient: BaseAPIClient, AnthropicClientProtocol {
    
    override init(keyManager: APIKeyManagerProtocol) {
        super.init(provider: .anthropic, keyManager: keyManager)
    }
    
    func createMessage(request: AnthropicMessageRequest) async throws -> AnthropicMessageResponse {
        let apiRequest = APIRequest(
            endpoint: "/messages",
            method: .POST,
            body: try JSONEncoder().encode(request)
        )
        
        return try await makeRequest(apiRequest, responseType: AnthropicMessageResponse.self)
    }
    
    func getModels() async throws -> [String] {
        // Anthropicは現在モデル一覧APIを提供していない
        return ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"]
    }
    
    override func validateAPIKey(_ apiKey: String) async throws -> Bool {
        let testRequest = AnthropicMessageRequest(
            model: "claude-3-haiku-20240307",
            maxTokens: 1,
            messages: [AnthropicMessage(role: "user", content: "test")],
            system: nil,
            temperature: nil
        )
        
        do {
            _ = try await createMessage(request: testRequest)
            return true
        } catch APIClientError.httpError(let statusCode, _) where statusCode != 401 {
            // 401以外のエラーはAPIキーが有効であることを意味する
            return true
        } catch {
            return false
        }
    }
    
    override func getAvailableModels() async throws -> [String] {
        return try await getModels()
    }
}

class GeminiAPIClient: BaseAPIClient, GeminiClientProtocol {
    
    override init(keyManager: APIKeyManagerProtocol) {
        super.init(provider: .gemini, keyManager: keyManager)
    }
    
    func generateContent(request: GeminiRequest) async throws -> GeminiResponse {
        guard let apiKey = try await keyManager.getAPIKey(for: provider) else {
            throw APIClientError.noAPIKey
        }
        
        let model = "gemini-1.5-flash" // デフォルトモデル
        let endpoint = "/models/\(model):generateContent?key=\(apiKey)"
        
        let apiRequest = APIRequest(
            endpoint: endpoint,
            method: .POST,
            body: try JSONEncoder().encode(request)
        )
        
        return try await makeRequest(apiRequest, responseType: GeminiResponse.self)
    }
    
    func listModels() async throws -> GeminiModelsResponse {
        guard let apiKey = try await keyManager.getAPIKey(for: provider) else {
            throw APIClientError.noAPIKey
        }
        
        let apiRequest = APIRequest(
            endpoint: "/models?key=\(apiKey)",
            method: .GET
        )
        
        return try await makeRequest(apiRequest, responseType: GeminiModelsResponse.self)
    }
    
    override func validateAPIKey(_ apiKey: String) async throws -> Bool {
        do {
            _ = try await listModels()
            return true
        } catch {
            return false
        }
    }
    
    override func getAvailableModels() async throws -> [String] {
        let response = try await listModels()
        return response.models.map { $0.name }
    }
}

// MARK: - プロバイダー拡張

extension LLMProvider {
    var defaultRateLimits: (perMinute: Int, perHour: Int, perDay: Int) {
        switch self {
        case .openai:
            return (60, 3600, 10000)
        case .anthropic:
            return (50, 1000, 5000)
        case .gemini:
            return (60, 1500, 15000)
        }
    }
}

// MARK: - ファクトリー

class APIClientFactory {
    static func createClient(
        for provider: LLMProvider,
        keyManager: APIKeyManagerProtocol
    ) -> ProviderAPIClientProtocol {
        
        switch provider {
        case .openai:
            return OpenAIAPIClient(keyManager: keyManager)
        case .anthropic:
            return AnthropicAPIClient(keyManager: keyManager)
        case .gemini:
            return GeminiAPIClient(keyManager: keyManager)
        }
    }
}