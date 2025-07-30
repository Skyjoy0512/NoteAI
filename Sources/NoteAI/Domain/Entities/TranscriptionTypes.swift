import Foundation

// MARK: - Common Transcription Types

/// 共通の文字起こし結果型
struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let detectedLanguage: String
    let languageConfidence: Double
    let audioDuration: TimeInterval
    let processingDuration: TimeInterval
    let modelUsed: String
    let averageConfidence: Double
    let alternativeLanguages: [LanguageProbability]?
    
    /// WhisperKit用の互換プロパティ
    var duration: TimeInterval { audioDuration }
    var language: String { detectedLanguage }
    
    /// WhisperKit用のプロパティ（存在する場合のみ）
    var model: WhisperModel? { 
        WhisperModel(rawValue: modelUsed) 
    }
    var processingTime: TimeInterval { processingDuration }
    
    /// 単語/分の計算
    var wordsPerMinute: Double {
        guard audioDuration > 0 else { return 0 }
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        return Double(wordCount) / (audioDuration / 60)
    }
}

/// 共通の文字起こしセグメント型
struct TranscriptionSegment: Identifiable {
    let id: Int
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    let words: [WordTimestamp]?
    let language: String?
    let noSpeechProb: Double?
    
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    /// WhisperKit互換初期化
    init(
        id: Int = 0,
        text: String, 
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double,
        words: [WordTimestamp]? = nil,
        language: String? = nil,
        noSpeechProb: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.words = words
        self.language = language
        self.noSpeechProb = noSpeechProb
    }
}

/// 単語のタイムスタンプ
struct WordTimestamp {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    
    var duration: TimeInterval {
        return endTime - startTime
    }
}

/// 言語確率情報
struct LanguageProbability {
    let language: String
    let probability: Double
    let languageCode: String
    
    init(language: String, probability: Double, languageCode: String? = nil) {
        self.language = language
        self.probability = probability
        self.languageCode = languageCode ?? language
    }
}

/// サポートされる言語（文字起こし用）
struct TranscriptionLanguage {
    let languageCode: String
    let displayName: String
    let nativeName: String
    
    init(languageCode: String, displayName: String, nativeName: String) {
        self.languageCode = languageCode
        self.displayName = displayName
        self.nativeName = nativeName
    }
}