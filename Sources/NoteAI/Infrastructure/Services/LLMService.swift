import Foundation
import Alamofire

@MainActor
class LLMService: @preconcurrency LLMServiceProtocol {
    
    // MARK: - Dependencies
    private var apiKeyManager: APIKeyManagerProtocol?
    private var usageTracker: APIUsageTrackerProtocol?
    
    // MARK: - Configuration
    private var defaultModels: [LLMProvider: LLMModel] = [
        .openAI(.gpt4): .gpt4oMini,
        .anthropic(.claude3Haiku): .claude3Haiku,
        .gemini(.geminipro): .geminiPro
    ]
    
    private var preferredModelsByTask: [String: LLMModel] = [
        "summarize": .gpt4oMini,
        "keywords": .claude3Haiku,
        "question_answer": .gpt4o,
        "analysis": .claude3Sonnet
    ]
    
    // MARK: - Configuration
    
    func configure(apiKeyManager: APIKeyManagerProtocol, usageTracker: APIUsageTrackerProtocol?) async throws {
        self.apiKeyManager = apiKeyManager
        self.usageTracker = usageTracker
    }
    
    func setDefaultModel(_ model: LLMModel, for provider: LLMProvider) async {
        defaultModels[provider] = model
    }
    
    func getPreferredModel(for task: String) async -> LLMModel {
        return preferredModelsByTask[task] ?? .gpt4oMini
    }
    
    // MARK: - Core LLM Functions
    
    func sendMessage(request: LLMRequest) async throws -> LLMResponse {
        // レート制限チェック
        let canProceed = try await checkRateLimit(for: request.model.provider)
        guard canProceed else {
            throw LLMServiceError.rateLimitExceeded
        }
        
        let response: LLMResponse
        
        switch request.model.provider {
        case .openAI(_):
            response = try await callOpenAI(request: request)
        case .anthropic(_):
            response = try await callAnthropic(request: request)
        case .gemini(_):
            response = try await callGemini(request: request)
        }
        
        // 使用量を記録
        try await recordUsage(response)
        
        return response
    }
    
    func summarizeText(_ text: String, model: LLMModel) async throws -> String {
        let systemPrompt = """
        あなたは優秀な要約アシスタントです。与えられたテキストの重要なポイントを簡潔にまとめてください。
        要約は以下の点を含めてください：
        - 主要なトピック
        - 重要な決定事項
        - アクションアイテム
        - キーポイント
        
        簡潔で分かりやすい日本語で要約してください。
        """
        
        let messages = [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: "以下のテキストを要約してください:\n\n\(text)")
        ]
        
        let request = LLMRequest(
            model: model,
            messages: messages,
            maxTokens: 1000,
            temperature: 0.3,
            systemPrompt: systemPrompt
        )
        
        let response = try await sendMessage(request: request)
        return response.content
    }
    
    func extractKeywords(_ text: String, model: LLMModel) async throws -> [String] {
        let systemPrompt = """
        与えられたテキストから重要なキーワードを抽出してください。
        キーワードは以下の形式で返してください：
        - 1行に1つのキーワード
        - 重要度順に並べる
        - 最大10個まで
        - 日本語のキーワードを優先
        """
        
        let messages = [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: "以下のテキストからキーワードを抽出してください:\n\n\(text)")
        ]
        
        let request = LLMRequest(
            model: model,
            messages: messages,
            maxTokens: 300,
            temperature: 0.1,
            systemPrompt: systemPrompt
        )
        
        let response = try await sendMessage(request: request)
        
        // レスポンスを行ごとに分割してキーワードリストに変換
        let keywords = response.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("-") }
            .map { $0.replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression) }
            .prefix(10)
        
        return Array(keywords)
    }
    
    func answerQuestion(_ question: String, context: String, model: LLMModel) async throws -> String {
        let systemPrompt = """
        あなたは与えられたコンテキストに基づいて質問に答えるアシスタントです。
        以下のルールに従ってください：
        - コンテキストの情報のみを使用して回答する
        - コンテキストに答えがない場合は「提供された情報では回答できません」と答える
        - 正確で簡潔な回答を心がける
        - 日本語で回答する
        """
        
        let messages = [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: "コンテキスト:\n\(context)\n\n質問: \(question)")
        ]
        
        let request = LLMRequest(
            model: model,
            messages: messages,
            maxTokens: 800,
            temperature: 0.2,
            systemPrompt: systemPrompt
        )
        
        let response = try await sendMessage(request: request)
        return response.content
    }
    
    // MARK: - Provider-specific calls
    
    func callOpenAI(request: LLMRequest) async throws -> LLMResponse {
        guard let apiKeyManager = apiKeyManager else {
            throw LLMServiceError.apiKeyNotFound
        }
        
        guard let apiKey = try await apiKeyManager.getAPIKey(for: .openAI(.gpt4)) else {
            throw LLMServiceError.apiKeyNotFound
        }
        
        let url = "https://api.openai.com/v1/chat/completions"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        var messages: [[String: String]] = []
        
        // システムプロンプトがある場合は最初に追加
        if let systemPrompt = request.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        
        // リクエストメッセージを追加
        for message in request.messages {
            messages.append(["role": message.role, "content": message.content])
        }
        
        let parameters: [String: Any] = [
            "model": request.model.rawValue,
            "messages": messages,
            "max_tokens": request.maxTokens ?? 1000,
            "temperature": request.temperature ?? 0.7
        ]
        
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseData { response in
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    switch response.result {
                    case .success(let data):
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            let choices = json?["choices"] as? [[String: Any]]
                            let message = choices?.first?["message"] as? [String: Any]
                            let content = message?["content"] as? String ?? ""
                            let finishReason = choices?.first?["finish_reason"] as? String
                            
                            let usage = json?["usage"] as? [String: Any]
                            let inputTokens = usage?["prompt_tokens"] as? Int ?? 0
                            let outputTokens = usage?["completion_tokens"] as? Int ?? 0
                            let totalTokens = usage?["total_tokens"] as? Int ?? (inputTokens + outputTokens)
                            
                            let tokenUsage = LLMTokenUsage(
                                inputTokens: inputTokens,
                                outputTokens: outputTokens,
                                totalTokens: totalTokens
                            )
                            
                            let cost = self.calculateCost(for: request.model, tokens: tokenUsage)
                            
                            let llmResponse = LLMResponse(
                                content: content,
                                model: request.model,
                                tokensUsed: tokenUsage,
                                cost: cost,
                                responseTime: responseTime,
                                finishReason: finishReason
                            )
                            
                            continuation.resume(returning: llmResponse)
                        } catch {
                            continuation.resume(throwing: LLMServiceError.responseParsingError)
                        }
                        
                    case .failure(let error):
                        if let statusCode = response.response?.statusCode {
                            switch statusCode {
                            case 401:
                                continuation.resume(throwing: LLMServiceError.invalidAPIKey)
                            case 429:
                                continuation.resume(throwing: LLMServiceError.rateLimitExceeded)
                            case 402:
                                continuation.resume(throwing: LLMServiceError.quotaExceeded)
                            default:
                                continuation.resume(throwing: LLMServiceError.networkError(error.localizedDescription))
                            }
                        } else {
                            continuation.resume(throwing: LLMServiceError.networkError(error.localizedDescription))
                        }
                    }
                }
        }
    }
    
    func callAnthropic(request: LLMRequest) async throws -> LLMResponse {
        guard let apiKeyManager = apiKeyManager else {
            throw LLMServiceError.apiKeyNotFound
        }
        
        guard let apiKey = try await apiKeyManager.getAPIKey(for: .anthropic(.claude3Sonnet)) else {
            throw LLMServiceError.apiKeyNotFound
        }
        
        let url = "https://api.anthropic.com/v1/messages"
        let headers: HTTPHeaders = [
            "x-api-key": apiKey,
            "Content-Type": "application/json",
            "anthropic-version": "2023-06-01"
        ]
        
        var messages: [[String: String]] = []
        var systemPrompt: String?
        
        for message in request.messages {
            if message.role == "system" {
                systemPrompt = message.content
            } else {
                messages.append(["role": message.role, "content": message.content])
            }
        }
        
        // リクエストのシステムプロンプトがある場合はそれを優先
        if let requestSystemPrompt = request.systemPrompt {
            systemPrompt = requestSystemPrompt
        }
        
        var parameters: [String: Any] = [
            "model": request.model.rawValue,
            "messages": messages,
            "max_tokens": request.maxTokens ?? 1000
        ]
        
        if let system = systemPrompt {
            parameters["system"] = system
        }
        
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseData { response in
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    switch response.result {
                    case .success(let data):
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            let content = json?["content"] as? [[String: Any]]
                            let text = content?.first?["text"] as? String ?? ""
                            let stopReason = json?["stop_reason"] as? String
                            
                            let usage = json?["usage"] as? [String: Any]
                            let inputTokens = usage?["input_tokens"] as? Int ?? 0
                            let outputTokens = usage?["output_tokens"] as? Int ?? 0
                            
                            let tokenUsage = LLMTokenUsage(
                                inputTokens: inputTokens,
                                outputTokens: outputTokens,
                                totalTokens: inputTokens + outputTokens
                            )
                            
                            let cost = self.calculateCost(for: request.model, tokens: tokenUsage)
                            
                            let llmResponse = LLMResponse(
                                content: text,
                                model: request.model,
                                tokensUsed: tokenUsage,
                                cost: cost,
                                responseTime: responseTime,
                                finishReason: stopReason
                            )
                            
                            continuation.resume(returning: llmResponse)
                        } catch {
                            continuation.resume(throwing: LLMServiceError.responseParsingError)
                        }
                        
                    case .failure(let error):
                        if let statusCode = response.response?.statusCode {
                            switch statusCode {
                            case 401:
                                continuation.resume(throwing: LLMServiceError.invalidAPIKey)
                            case 429:
                                continuation.resume(throwing: LLMServiceError.rateLimitExceeded)
                            case 402:
                                continuation.resume(throwing: LLMServiceError.quotaExceeded)
                            default:
                                continuation.resume(throwing: LLMServiceError.networkError(error.localizedDescription))
                            }
                        } else {
                            continuation.resume(throwing: LLMServiceError.networkError(error.localizedDescription))
                        }
                    }
                }
        }
    }
    
    func callGemini(request: LLMRequest) async throws -> LLMResponse {
        guard let apiKeyManager = apiKeyManager else {
            throw LLMServiceError.apiKeyNotFound
        }
        
        guard let apiKey = try await apiKeyManager.getAPIKey(for: .gemini(.geminipro)) else {
            throw LLMServiceError.apiKeyNotFound
        }
        
        let url = "https://generativelanguage.googleapis.com/v1beta/models/\(request.model.rawValue):generateContent?key=\(apiKey)"
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        var contents: [[String: Any]] = []
        
        for message in request.messages {
            let role = message.role == "assistant" ? "model" : message.role
            contents.append([
                "role": role,
                "parts": [["text": message.content]]
            ])
        }
        
        var parameters: [String: Any] = [
            "contents": contents
        ]
        
        if let systemPrompt = request.systemPrompt {
            parameters["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
        }
        
        if let maxTokens = request.maxTokens {
            parameters["generationConfig"] = [
                "maxOutputTokens": maxTokens,
                "temperature": request.temperature ?? 0.7
            ]
        }
        
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseData { response in
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    switch response.result {
                    case .success(let data):
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            let candidates = json?["candidates"] as? [[String: Any]]
                            let content = candidates?.first?["content"] as? [String: Any]
                            let parts = content?["parts"] as? [[String: Any]]
                            let text = parts?.first?["text"] as? String ?? ""
                            let finishReason = candidates?.first?["finishReason"] as? String
                            
                            let usageMetadata = json?["usageMetadata"] as? [String: Any]
                            let inputTokens = usageMetadata?["promptTokenCount"] as? Int ?? 0
                            let outputTokens = usageMetadata?["candidatesTokenCount"] as? Int ?? 0
                            let totalTokens = usageMetadata?["totalTokenCount"] as? Int ?? (inputTokens + outputTokens)
                            
                            let tokenUsage = LLMTokenUsage(
                                inputTokens: inputTokens,
                                outputTokens: outputTokens,
                                totalTokens: totalTokens
                            )
                            
                            let cost = self.calculateCost(for: request.model, tokens: tokenUsage)
                            
                            let llmResponse = LLMResponse(
                                content: text,
                                model: request.model,
                                tokensUsed: tokenUsage,
                                cost: cost,
                                responseTime: responseTime,
                                finishReason: finishReason
                            )
                            
                            continuation.resume(returning: llmResponse)
                        } catch {
                            continuation.resume(throwing: LLMServiceError.responseParsingError)
                        }
                        
                    case .failure(let error):
                        if let statusCode = response.response?.statusCode {
                            switch statusCode {
                            case 401, 403:
                                continuation.resume(throwing: LLMServiceError.invalidAPIKey)
                            case 429:
                                continuation.resume(throwing: LLMServiceError.rateLimitExceeded)
                            case 402:
                                continuation.resume(throwing: LLMServiceError.quotaExceeded)
                            default:
                                continuation.resume(throwing: LLMServiceError.networkError(error.localizedDescription))
                            }
                        } else {
                            continuation.resume(throwing: LLMServiceError.networkError(error.localizedDescription))
                        }
                    }
                }
        }
    }
    
    // MARK: - Model & Provider Management
    
    func getAvailableModels(for provider: LLMProvider) async throws -> [LLMModel] {
        return LLMModel.allCases.filter { $0.provider == provider }
    }
    
    func isModelAvailable(_ model: LLMModel) async -> Bool {
        guard let apiKeyManager = apiKeyManager else { return false }
        return await apiKeyManager.hasValidAPIKey(for: model.provider)
    }
    
    func getDefaultModel(for provider: LLMProvider) -> LLMModel {
        return defaultModels[provider] ?? .gpt4oMini
    }
    
    func estimateCost(for request: LLMRequest) async -> Double {
        // 概算計算（実際のトークン数は不明なので、文字数ベースで概算）
        let estimatedInputTokens = request.messages.reduce(0) { total, message in
            total + (message.content.count / 4) // 大まかな文字数→トークン数変換
        }
        
        let estimatedOutputTokens = request.maxTokens ?? 500
        
        let tokenUsage = LLMTokenUsage(
            inputTokens: estimatedInputTokens,
            outputTokens: estimatedOutputTokens,
            totalTokens: estimatedInputTokens + estimatedOutputTokens
        )
        
        return calculateCost(for: request.model, tokens: tokenUsage)
    }
    
    // MARK: - Usage & Analytics
    
    func getUsageStats() async throws -> LLMUsageStats {
        guard let usageTracker = usageTracker else {
            return LLMUsageStats(
                totalAPICallsThisMonth: 0,
                totalTokensThisMonth: 0,
                totalCostThisMonth: 0.0,
                remainingAPICallsThisMonth: 0,
                providerBreakdown: [:]
            )
        }
        
        // Usage trackerから統計を取得
        let stats = try await usageTracker.getMonthlyUsage(for: Date())
        
        var providerBreakdown: [LLMProvider: ProviderUsage] = [:]
        for provider in LLMProvider.allCases {
            let usage = try await usageTracker.getProviderUsage(provider, period: nil)
            providerBreakdown[provider] = ProviderUsage(
                apiCalls: usage.apiCalls,
                tokens: usage.tokens,
                cost: usage.cost,
                lastUsed: usage.lastUsed
            )
        }
        
        return LLMUsageStats(
            totalAPICallsThisMonth: stats.totalAPICalls,
            totalTokensThisMonth: stats.totalTokens,
            totalCostThisMonth: stats.totalCost,
            remainingAPICallsThisMonth: max(0, 10000 - stats.totalAPICalls), // 月間制限から計算
            providerBreakdown: providerBreakdown
        )
    }
    
    func recordUsage(_ response: LLMResponse) async throws {
        guard let usageTracker = usageTracker else { return }
        
        try await usageTracker.recordAPICall(
            provider: response.model.provider,
            model: response.model.rawValue,
            tokensUsed: response.tokensUsed.totalTokens,
            cost: response.cost
        )
    }
    
    func checkRateLimit(for provider: LLMProvider) async throws -> Bool {
        guard let usageTracker = usageTracker else { return true }
        return try await usageTracker.checkRateLimit(for: provider)
    }
    
    // MARK: - Private Methods
    
    nonisolated private func calculateCost(for model: LLMModel, tokens: LLMTokenUsage) -> Double {
        let rates = model.costPer1kTokens
        let inputCost = (Double(tokens.inputTokens) / 1000.0) * rates.input
        let outputCost = (Double(tokens.outputTokens) / 1000.0) * rates.output
        return (inputCost + outputCost) / 100.0 // USD cents to USD dollars
    }
}