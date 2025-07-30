import Foundation

// MARK: - Audio Quality
enum AudioQuality: String, CaseIterable, Codable {
    case high = "high"
    case standard = "standard"
    case low = "low"
    case lossless = "lossless"
    
    var displayName: String {
        switch self {
        case .high: return "高音質"
        case .standard: return "標準"
        case .low: return "省容量"
        case .lossless: return "ロスレス"
        }
    }
    
    var sampleRate: Double {
        switch self {
        case .high: return 44100.0
        case .standard: return 22050.0
        case .low: return 16000.0
        case .lossless: return 48000.0
        }
    }
    
    var bitRate: Int {
        switch self {
        case .high: return 128000
        case .standard: return 64000
        case .low: return 32000
        case .lossless: return 1411000 // CD quality
        }
    }
}

// MARK: - Transcription Method
enum TranscriptionMethod: Codable, Equatable, Hashable {
    case local(WhisperModel)
    case api(LLMProvider)
    
    var displayName: String {
        switch self {
        case .local(let model):
            return "ローカル (\(model.displayName))"
        case .api(let provider):
            return "API (\(provider.displayName))"
        }
    }
}

// MARK: - Whisper Model
enum WhisperModel: String, CaseIterable, Codable {
    case tiny = "tiny"
    case base = "base" 
    case small = "small"
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (軽量)"
        case .base: return "Base (標準)"
        case .small: return "Small (高精度)"
        }
    }
    
    var modelName: String {
        return rawValue
    }
    
    var approximateSize: String {
        switch self {
        case .tiny: return "~40MB"
        case .base: return "~140MB"
        case .small: return "~470MB"
        }
    }
}

// MARK: - LLM Provider
enum LLMProvider: Codable, Equatable, Hashable {
    case openAI(OpenAIModel)
    case gemini(GeminiModel)
    case anthropic(ClaudeModel)
    
    // Explicit Codable implementation
    enum CodingKeys: String, CodingKey {
        case type, model
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "openAI":
            let model = try container.decode(OpenAIModel.self, forKey: .model)
            self = .openAI(model)
        case "gemini":
            let model = try container.decode(GeminiModel.self, forKey: .model)
            self = .gemini(model)
        case "anthropic":
            let model = try container.decode(ClaudeModel.self, forKey: .model)
            self = .anthropic(model)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown LLMProvider type: \(type)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .openAI(let model):
            try container.encode("openAI", forKey: .type)
            try container.encode(model, forKey: .model)
        case .gemini(let model):
            try container.encode("gemini", forKey: .type)
            try container.encode(model, forKey: .model)
        case .anthropic(let model):
            try container.encode("anthropic", forKey: .type)
            try container.encode(model, forKey: .model)
        }
    }
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        }
    }
    
    var rawValue: String {
        switch self {
        case .openAI: return "openAI"
        case .gemini: return "gemini"
        case .anthropic: return "anthropic"
        }
    }
    
    var keyPrefix: String {
        switch self {
        case .openAI: return "openai"
        case .gemini: return "gemini"
        case .anthropic: return "claude"
        }
    }
    
    var keychainIdentifier: String {
        switch self {
        case .openAI: return "openai_api_key"
        case .gemini: return "gemini_api_key"
        case .anthropic: return "claude_api_key"
        }
    }
    
    var setupURL: URL {
        switch self {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini:
            return URL(string: "https://makersuite.google.com/app/apikey")!
        case .anthropic:
            return URL(string: "https://console.anthropic.com/api")!
        }
    }
    
    // Static allCases equivalent for enum with associated values
    static var allCases: [LLMProvider] {
        return [
            .openAI(.gpt4),
            .openAI(.gpt35turbo),
            .gemini(.geminipro),
            .gemini(.geminiproVision),
            .anthropic(.claude3Sonnet),
            .anthropic(.claude3Haiku)
        ]
    }
    
    // Convenience constructors for backward compatibility
    static var openai: LLMProvider { .openAI(.gpt4) }
    static func openaiProvider(_ model: OpenAIModel = .gpt4) -> LLMProvider { .openAI(model) }
    static func anthropicProvider(_ model: ClaudeModel = .claude3Sonnet) -> LLMProvider { .anthropic(model) }
    static func geminiProvider(_ model: GeminiModel = .geminipro) -> LLMProvider { .gemini(model) }
    
    // String conversion utilities
    static func from(string: String) -> LLMProvider? {
        switch string.lowercased() {
        case "openai", "openai_api_key":
            return .openAI(.gpt4)
        case "gemini", "gemini_api_key":
            return .gemini(.geminipro)
        case "anthropic", "claude", "claude_api_key":
            return .anthropic(.claude3Sonnet)
        default:
            return nil
        }
    }
    
    // RawValue-based initializer for backward compatibility
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "openai":
            self = .openAI(.gpt4)
        case "gemini":
            self = .gemini(.geminipro)
        case "anthropic":
            self = .anthropic(.claude3Sonnet)
        default:
            return nil
        }
    }
    
    var baseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openAI(let model):
            return model.rawValue
        case .gemini(let model):
            return model.rawValue
        case .anthropic(let model):
            return model.rawValue
        }
    }
    
    var supportedModels: [String] {
        switch self {
        case .openAI:
            return OpenAIModel.allCases.map { $0.rawValue }
        case .gemini:
            return GeminiModel.allCases.map { $0.rawValue }
        case .anthropic:
            return ClaudeModel.allCases.map { $0.rawValue }
        }
    }
    
    func estimateCost(tokens: Int32, operation: APIOperationType) -> Double {
        // Simplified cost estimation
        let baseRate = 0.002 // $0.002 per 1K tokens as baseline
        return Double(tokens) / 1000.0 * baseRate
    }
}

// MARK: - OpenAI Models
enum OpenAIModel: String, CaseIterable, Codable, Hashable {
    case gpt4 = "gpt-4"
    case gpt35turbo = "gpt-3.5-turbo"
    
    var displayName: String {
        switch self {
        case .gpt4: return "GPT-4"
        case .gpt35turbo: return "GPT-3.5 Turbo"
        }
    }
}

// MARK: - Gemini Models
enum GeminiModel: String, CaseIterable, Codable, Hashable {
    case geminipro = "gemini-pro"
    case geminiproVision = "gemini-pro-vision"
    
    var displayName: String {
        switch self {
        case .geminipro: return "Gemini Pro"
        case .geminiproVision: return "Gemini Pro Vision"
        }
    }
}

// MARK: - Claude Models
enum ClaudeModel: String, CaseIterable, Codable, Hashable {
    case claude3Sonnet = "claude-3-sonnet-20240229"
    case claude3Haiku = "claude-3-haiku-20240307"
    
    var displayName: String {
        switch self {
        case .claude3Sonnet: return "Claude 3 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        }
    }
}

// MARK: - Recording Settings
struct RecordingSettings {
    let quality: AudioQuality
    let language: String
    let format: AudioFormat
    
    init(quality: AudioQuality = .standard, language: String = "ja", format: AudioFormat = .m4a) {
        self.quality = quality
        self.language = language
        self.format = format
    }
}

// AudioFormat enum は Core/Limitless/LimitlessTypes.swift で定義されています

// MARK: - Summary Types
enum SummaryType: String, CaseIterable {
    case overview = "overview"
    case timeline = "timeline"
    case actionItems = "actionItems"
    case keyInsights = "keyInsights"
    
    var displayName: String {
        switch self {
        case .overview: return "全体要約"
        case .timeline: return "時系列"
        case .actionItems: return "アクションアイテム"
        case .keyInsights: return "重要な洞察"
        }
    }
}

// MARK: - Subscription Type
enum SubscriptionType: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "無料"
        case .premium: return "Premium"
        }
    }
}