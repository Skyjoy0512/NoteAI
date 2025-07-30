import Foundation
import CoreData

extension ProjectEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectEntity> {
        return NSFetchRequest<ProjectEntity>(entityName: "ProjectEntity")
    }

    @NSManaged public var coverImageData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var metadata: Data?
    @NSManaged public var name: String
    @NSManaged public var projectDescription: String?
    @NSManaged public var updatedAt: Date
    @NSManaged public var recordings: NSSet?
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for recordings
extension ProjectEntity {

    @objc(addRecordingsObject:)
    @NSManaged public func addToRecordings(_ value: RecordingEntity)

    @objc(removeRecordingsObject:)
    @NSManaged public func removeFromRecordings(_ value: RecordingEntity)

    @objc(addRecordings:)
    @NSManaged public func addToRecordings(_ values: NSSet)

    @objc(removeRecordings:)
    @NSManaged public func removeFromRecordings(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension ProjectEntity {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: TagEntity)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: TagEntity)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

extension ProjectEntity : @preconcurrency Identifiable {

}