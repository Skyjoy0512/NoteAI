import Foundation

// MARK: - Audio Quality
enum AudioQuality: String, CaseIterable, Codable {
    case high = "high"
    case standard = "standard"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "高音質"
        case .standard: return "標準"
        case .low: return "省容量"
        }
    }
    
    var sampleRate: Double {
        switch self {
        case .high: return 44100.0
        case .standard: return 22050.0
        case .low: return 16000.0
        }
    }
    
    var bitRate: Int {
        switch self {
        case .high: return 128000
        case .standard: return 64000
        case .low: return 32000
        }
    }
}

// MARK: - Transcription Method
enum TranscriptionMethod: Codable, Equatable {
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
enum LLMProvider: Codable, Equatable {
    case openAI(OpenAIModel)
    case gemini(GeminiModel)
    case anthropic(ClaudeModel)
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
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
}

// MARK: - OpenAI Models
enum OpenAIModel: String, CaseIterable, Codable {
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
enum GeminiModel: String, CaseIterable, Codable {
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
enum ClaudeModel: String, CaseIterable, Codable {
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

enum AudioFormat: String, CaseIterable {
    case m4a = "m4a"
    case wav = "wav"
    
    var displayName: String {
        switch self {
        case .m4a: return "M4A (標準)"
        case .wav: return "WAV (高音質)"
        }
    }
}

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