import Foundation
import CoreData

@objc(ProjectEntity)
@MainActor
public class ProjectEntity: NSManagedObject {
    
    // Custom business logic methods
    public var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    public var recordingCount: Int {
        return recordings?.count ?? 0
    }
    
    public var totalDuration: Double {
        guard let recordings = recordings as? Set<RecordingEntity> else { return 0.0 }
        return recordings.reduce(0.0) { $0 + $1.duration }
    }
    
    // Convenience initializer
    public convenience init(context: NSManagedObjectContext, name: String, description: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.projectDescription = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    public override func willSave() {
        super.willSave()
        if !isDeleted {
            updatedAt = Date()
        }
    }
}