import Foundation

// MARK: - API Usage Types

struct APIUsage: Identifiable, Codable {
    let id: UUID
    let provider: LLMProvider
    let operationType: APIOperationType
    let tokensUsed: Int
    let estimatedCost: Double
    let responseTime: TimeInterval
    let usedAt: Date
    let requestMetadata: APIRequestMetadata?
    let responseMetadata: APIResponseMetadata?
    
    init(
        id: UUID = UUID(),
        provider: LLMProvider,
        operationType: APIOperationType,
        tokensUsed: Int,
        estimatedCost: Double,
        responseTime: TimeInterval,
        usedAt: Date = Date(),
        requestMetadata: APIRequestMetadata? = nil,
        responseMetadata: APIResponseMetadata? = nil
    ) {
        self.id = id
        self.provider = provider
        self.operationType = operationType
        self.tokensUsed = tokensUsed
        self.estimatedCost = estimatedCost
        self.responseTime = responseTime
        self.usedAt = usedAt
        self.requestMetadata = requestMetadata
        self.responseMetadata = responseMetadata
    }
}

enum APIOperationType: String, CaseIterable, Codable {
    case transcription = "transcription"
    case textGeneration = "text_generation"
    case embedding = "embedding"
    case chatCompletion = "chat_completion"
    case summarization = "summarization"
    case translation = "translation"
    
    var displayName: String {
        switch self {
        case .transcription:
            return "音声文字起こし"
        case .textGeneration:
            return "テキスト生成"
        case .embedding:
            return "埋め込み生成"
        case .chatCompletion:
            return "チャット応答"
        case .summarization:
            return "要約生成"
        case .translation:
            return "翻訳"
        }
    }
}

struct APIRequestMetadata: Codable {
    let model: String?
    let temperature: Double?
    let maxTokens: Int?
    let customParameters: [String: String]?
    
    init(
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        customParameters: [String: String]? = nil
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.customParameters = customParameters
    }
}

struct APIResponseMetadata: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let finishReason: String?
    let modelUsed: String?
    
    init(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        finishReason: String? = nil,
        modelUsed: String? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.finishReason = finishReason
        self.modelUsed = modelUsed
    }
}

struct APIUsageSummary: Codable {
    let provider: LLMProvider
    let totalRequests: Int
    let totalTokens: Int
    let totalCost: Double
    let averageResponseTime: TimeInterval
    let operationBreakdown: [APIOperationType: Int]
    let period: DateInterval?
    
    init(
        provider: LLMProvider,
        totalRequests: Int = 0,
        totalTokens: Int = 0,
        totalCost: Double = 0.0,
        averageResponseTime: TimeInterval = 0.0,
        operationBreakdown: [APIOperationType: Int] = [:],
        period: DateInterval? = nil
    ) {
        self.provider = provider
        self.totalRequests = totalRequests
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.averageResponseTime = averageResponseTime
        self.operationBreakdown = operationBreakdown
        self.period = period
    }
}

// APIUsageRecord is defined in Core/Services/APIUsageTrackerProtocol.swift