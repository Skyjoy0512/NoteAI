import Foundation
import CoreData

extension RecordingSegmentEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordingSegmentEntity> {
        return NSFetchRequest<RecordingSegmentEntity>(entityName: "RecordingSegmentEntity")
    }

    @NSManaged public var confidence: Double
    @NSManaged public var endTime: Double
    @NSManaged public var id: UUID
    @NSManaged public var speaker: String?
    @NSManaged public var startTime: Double
    @NSManaged public var text: String
    @NSManaged public var recording: RecordingEntity?

}

extension RecordingSegmentEntity : @preconcurrency Identifiable {

}