import Foundation
import CoreData

extension RecordingEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordingEntity> {
        return NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
    }

    @NSManaged public var audioFileURL: String
    @NSManaged public var audioQuality: String
    @NSManaged public var createdAt: Date
    @NSManaged public var duration: Double
    @NSManaged public var id: UUID
    @NSManaged public var isFromLimitless: Bool
    @NSManaged public var language: String
    @NSManaged public var metadata: Data?
    @NSManaged public var title: String
    @NSManaged public var transcription: String?
    @NSManaged public var transcriptionMethod: String
    @NSManaged public var updatedAt: Date
    @NSManaged public var whisperModel: String?
    @NSManaged public var project: ProjectEntity?
    @NSManaged public var segments: NSSet?

}

// MARK: Generated accessors for segments
extension RecordingEntity {

    @objc(addSegmentsObject:)
    @NSManaged public func addToSegments(_ value: RecordingSegmentEntity)

    @objc(removeSegmentsObject:)
    @NSManaged public func removeFromSegments(_ value: RecordingSegmentEntity)

    @objc(addSegments:)
    @NSManaged public func addToSegments(_ values: NSSet)

    @objc(removeSegments:)
    @NSManaged public func removeFromSegments(_ values: NSSet)

}

extension RecordingEntity : @preconcurrency Identifiable {

}