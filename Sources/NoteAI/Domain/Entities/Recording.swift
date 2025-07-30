import Foundation

struct Recording: Identifiable {
    let id: UUID
    var title: String
    let audioFileURL: URL
    var transcription: String?
    var transcriptionMethod: TranscriptionMethod
    var whisperModel: WhisperModel?
    let language: String
    let duration: TimeInterval
    let audioQuality: AudioQuality
    let isFromLimitless: Bool
    let createdAt: Date
    var updatedAt: Date
    var metadata: RecordingMetadata
    var segments: [RecordingSegment] = []
    var projectId: UUID?
    
    init(
        id: UUID = UUID(),
        title: String,
        audioFileURL: URL,
        transcription: String? = nil,
        transcriptionMethod: TranscriptionMethod = .local(.base),
        whisperModel: WhisperModel? = nil,
        language: String = "ja",
        duration: TimeInterval = 0,
        audioQuality: AudioQuality = .standard,
        isFromLimitless: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: RecordingMetadata = RecordingMetadata(),
        projectId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.audioFileURL = audioFileURL
        self.transcription = transcription
        self.transcriptionMethod = transcriptionMethod
        self.whisperModel = whisperModel
        self.language = language
        self.duration = duration
        self.audioQuality = audioQuality
        self.isFromLimitless = isFromLimitless
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.projectId = projectId
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    var hasTranscription: Bool {
        transcription?.isEmpty == false
    }
}

struct RecordingMetadata: Codable, Equatable {
    var location: String?
    var participantCount: Int = 0
    var notes: String?
    var customFields: [String: String] = [:]
    
    init() {}
}

struct RecordingSegment: Identifiable, Equatable, Codable {
    let id: UUID
    let recordingId: UUID
    var text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    var speaker: String?
    var confidence: Double?
    
    init(
        id: UUID = UUID(),
        recordingId: UUID,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        speaker: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.recordingId = recordingId
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speaker = speaker
        self.confidence = confidence
    }
}