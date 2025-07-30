import Foundation
import CoreData

extension TagEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TagEntity> {
        return NSFetchRequest<TagEntity>(entityName: "TagEntity")
    }

    @NSManaged public var color: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var projects: NSSet?

}

// MARK: Generated accessors for projects
extension TagEntity {

    @objc(addProjectsObject:)
    @NSManaged public func addToProjects(_ value: ProjectEntity)

    @objc(removeProjectsObject:)
    @NSManaged public func removeFromProjects(_ value: ProjectEntity)

    @objc(addProjects:)
    @NSManaged public func addToProjects(_ values: NSSet)

    @objc(removeProjects:)
    @NSManaged public func removeFromProjects(_ values: NSSet)

}

extension TagEntity : @preconcurrency Identifiable {

}