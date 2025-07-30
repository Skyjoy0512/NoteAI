import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        // Core Dataモデルを動的に作成
        let managedObjectModel = self.createManagedObjectModel()
        let container = NSPersistentContainer(name: "NoteAI", managedObjectModel: managedObjectModel)
        
        // SQLiteストアの設定
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.type = NSSQLiteStoreType
        
        // パフォーマンス向上の設定
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // 軽量マイグレーションを有効にする
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("CoreData loading error: \(error), \(error.userInfo)")
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        
        // Context設定
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Private Methods
    
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Project Entity
        let projectEntity = NSEntityDescription()
        projectEntity.name = "Project"
        projectEntity.managedObjectClassName = "Project"
        
        let projectIdAttribute = NSAttributeDescription()
        projectIdAttribute.name = "id"
        projectIdAttribute.attributeType = .UUIDAttributeType
        projectIdAttribute.isOptional = false
        
        let projectNameAttribute = NSAttributeDescription()
        projectNameAttribute.name = "name"
        projectNameAttribute.attributeType = .stringAttributeType
        projectNameAttribute.isOptional = false
        
        let projectDescriptionAttribute = NSAttributeDescription()
        projectDescriptionAttribute.name = "projectDescription"
        projectDescriptionAttribute.attributeType = .stringAttributeType
        projectDescriptionAttribute.isOptional = true
        
        let projectCreatedAtAttribute = NSAttributeDescription()
        projectCreatedAtAttribute.name = "createdAt"
        projectCreatedAtAttribute.attributeType = .dateAttributeType
        projectCreatedAtAttribute.isOptional = false
        
        let projectUpdatedAtAttribute = NSAttributeDescription()
        projectUpdatedAtAttribute.name = "updatedAt"
        projectUpdatedAtAttribute.attributeType = .dateAttributeType
        projectUpdatedAtAttribute.isOptional = false
        
        let coverImageDataAttribute = NSAttributeDescription()
        coverImageDataAttribute.name = "coverImageData"
        coverImageDataAttribute.attributeType = .binaryDataAttributeType
        coverImageDataAttribute.isOptional = true
        
        projectEntity.properties = [
            projectIdAttribute,
            projectNameAttribute,
            projectDescriptionAttribute,
            projectCreatedAtAttribute,
            projectUpdatedAtAttribute,
            coverImageDataAttribute
        ]
        
        // Recording Entity
        let recordingEntity = NSEntityDescription()
        recordingEntity.name = "Recording"
        recordingEntity.managedObjectClassName = "Recording"
        
        let recordingIdAttribute = NSAttributeDescription()
        recordingIdAttribute.name = "id"
        recordingIdAttribute.attributeType = .UUIDAttributeType
        recordingIdAttribute.isOptional = false
        
        let recordingFileNameAttribute = NSAttributeDescription()
        recordingFileNameAttribute.name = "fileName"
        recordingFileNameAttribute.attributeType = .stringAttributeType
        recordingFileNameAttribute.isOptional = false
        
        let recordingDurationAttribute = NSAttributeDescription()
        recordingDurationAttribute.name = "duration"
        recordingDurationAttribute.attributeType = .doubleAttributeType
        recordingDurationAttribute.isOptional = false
        
        let recordingCreatedAtAttribute = NSAttributeDescription()
        recordingCreatedAtAttribute.name = "createdAt"
        recordingCreatedAtAttribute.attributeType = .dateAttributeType
        recordingCreatedAtAttribute.isOptional = false
        
        recordingEntity.properties = [
            recordingIdAttribute,
            recordingFileNameAttribute,
            recordingDurationAttribute,
            recordingCreatedAtAttribute
        ]
        
        // APIUsageRecord Entity
        let apiUsageEntity = NSEntityDescription()
        apiUsageEntity.name = "APIUsageRecord"
        apiUsageEntity.managedObjectClassName = "APIUsageRecord"
        
        let apiUsageIdAttribute = NSAttributeDescription()
        apiUsageIdAttribute.name = "id"
        apiUsageIdAttribute.attributeType = .UUIDAttributeType
        apiUsageIdAttribute.isOptional = false
        
        let apiUsageTypeAttribute = NSAttributeDescription()
        apiUsageTypeAttribute.name = "apiType"
        apiUsageTypeAttribute.attributeType = .stringAttributeType
        apiUsageTypeAttribute.isOptional = false
        
        let apiUsageCountAttribute = NSAttributeDescription()
        apiUsageCountAttribute.name = "requestCount"
        apiUsageCountAttribute.attributeType = .integer32AttributeType
        apiUsageCountAttribute.isOptional = false
        
        let apiUsageDateAttribute = NSAttributeDescription()
        apiUsageDateAttribute.name = "date"
        apiUsageDateAttribute.attributeType = .dateAttributeType
        apiUsageDateAttribute.isOptional = false
        
        apiUsageEntity.properties = [
            apiUsageIdAttribute,
            apiUsageTypeAttribute,
            apiUsageCountAttribute,
            apiUsageDateAttribute
        ]
        
        // Subscription Entity
        let subscriptionEntity = NSEntityDescription()
        subscriptionEntity.name = "Subscription"
        subscriptionEntity.managedObjectClassName = "Subscription"
        
        let subscriptionIdAttribute = NSAttributeDescription()
        subscriptionIdAttribute.name = "id"
        subscriptionIdAttribute.attributeType = .UUIDAttributeType
        subscriptionIdAttribute.isOptional = false
        
        let subscriptionTypeAttribute = NSAttributeDescription()
        subscriptionTypeAttribute.name = "type"
        subscriptionTypeAttribute.attributeType = .stringAttributeType
        subscriptionTypeAttribute.isOptional = false
        
        let subscriptionIsActiveAttribute = NSAttributeDescription()
        subscriptionIsActiveAttribute.name = "isActive"
        subscriptionIsActiveAttribute.attributeType = .booleanAttributeType
        subscriptionIsActiveAttribute.isOptional = false
        
        subscriptionEntity.properties = [
            subscriptionIdAttribute,
            subscriptionTypeAttribute,
            subscriptionIsActiveAttribute
        ]
        
        model.entities = [projectEntity, recordingEntity, apiUsageEntity, subscriptionEntity]
        
        return model
    }
}