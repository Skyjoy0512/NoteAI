import Foundation
import CoreData

@objc(RecordingSegmentEntity)
@MainActor
public class RecordingSegmentEntity: NSManagedObject {
    
    // Custom business logic methods
    public var durationText: String {
        let duration = endTime - startTime
        return String(format: "%.1fs", duration)
    }
    
    public var timeRange: String {
        return String(format: "%.1f - %.1f", startTime, endTime)
    }
    
    // Convenience initializer
    public convenience init(context: NSManagedObjectContext, text: String, startTime: Double, endTime: Double) {
        self.init(context: context)
        self.id = UUID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}