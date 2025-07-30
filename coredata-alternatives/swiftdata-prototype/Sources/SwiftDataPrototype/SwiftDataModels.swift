import SwiftData
import Foundation

@Model
public class Project {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var projectDescription: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var coverImageData: Data?
    public var metadata: Data?
    
    @Relationship(deleteRule: .cascade, inverse: \Recording.project)
    public var recordings: [Recording] = []
    
    @Relationship(deleteRule: .nullify)
    public var tags: [Tag] = []
    
    public init(name: String, projectDescription: String? = nil) {
        self.id = UUID()
        self.name = name
        self.projectDescription = projectDescription
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
public class Recording {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var audioFileURL: String
    public var duration: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var transcription: String?
    public var language: String
    public var audioQuality: String
    public var transcriptionMethod: String
    public var whisperModel: String?
    public var isFromLimitless: Bool
    public var metadata: Data?
    
    public var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \RecordingSegment.recording)
    public var segments: [RecordingSegment] = []
    
    public init(title: String, audioFileURL: String, project: Project? = nil) {
        self.id = UUID()
        self.title = title
        self.audioFileURL = audioFileURL
        self.duration = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.language = "ja"
        self.audioQuality = "standard"
        self.transcriptionMethod = "whisper"
        self.isFromLimitless = false
        self.project = project
    }
}

@Model  
public class RecordingSegment {
    @Attribute(.unique) public var id: UUID
    public var text: String
    public var startTime: Double
    public var endTime: Double
    public var speaker: String?
    public var confidence: Double?
    
    public var recording: Recording?
    
    public init(text: String, startTime: Double, endTime: Double, recording: Recording? = nil) {
        self.id = UUID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.recording = recording
    }
}

@Model
public class Tag {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var color: String
    
    public var projects: [Project] = []
    
    public init(name: String, color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
    }
}
