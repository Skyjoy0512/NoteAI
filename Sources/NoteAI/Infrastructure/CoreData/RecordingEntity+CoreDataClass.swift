import Foundation
import CoreData

@objc(RecordingEntity)
@MainActor
public class RecordingEntity: NSManagedObject {
    
    // Custom business logic methods
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var segmentCount: Int {
        return segments?.count ?? 0
    }
    
    public var hasTranscription: Bool {
        return transcription != nil && !transcription!.isEmpty
    }
    
    // Convenience initializer
    public convenience init(context: NSManagedObjectContext, title: String, audioFileURL: String) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.audioFileURL = audioFileURL
        self.createdAt = Date()
        self.updatedAt = Date()
        self.duration = 0.0
        self.language = "ja"
        self.transcriptionMethod = "whisper"
        self.isFromLimitless = false
        self.audioQuality = "standard"
    }
    
    public override func willSave() {
        super.willSave()
        if !isDeleted {
            updatedAt = Date()
        }
    }
}