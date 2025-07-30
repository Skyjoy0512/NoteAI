import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import CoreData
#endif

class RecordingRepository: RecordingRepositoryProtocol {
    #if !MINIMAL_BUILD && !NO_COREDATA
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    #else
    // MINIMAL_BUILD: メモリ内実装
    private var memoryStorage: [UUID: Recording] = [:]
    
    init(coreDataStack: Any? = nil) {
        // Minimal build does not use Core Data
    }
    #endif
    
    func save(_ recording: Recording) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: recording, in: context)
            self.updateEntity(entity, with: recording)
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリ内保存
        memoryStorage[recording.id] = recording
        #endif
    }
    
    func findById(_ id: UUID) async throws -> Recording? {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
        #else
        // MINIMAL_BUILD: メモリ内検索
        return memoryStorage[id]
        #endif
    }
    
    func findAll() async throws -> [Recording] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内全取得
        return Array(memoryStorage.values.sorted { $0.createdAt > $1.createdAt })
        #endif
    }
    
    func findByProjectId(_ projectId: UUID) async throws -> [Recording] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "project.id == %@", projectId as CVarArg)
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内プロジェクトフィルタ
        return memoryStorage.values.filter { recording in
            recording.projectId == projectId
        }.sorted { $0.createdAt > $1.createdAt }
        #endif
    }
    
    func search(query: String) async throws -> [Recording] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "title CONTAINS[c] %@", query)
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内検索
        return memoryStorage.values.filter { recording in
            recording.title.localizedCaseInsensitiveContains(query)
        }.sorted { $0.createdAt > $1.createdAt }
        #endif
    }
    
    func findByTitle(_ title: String) async throws -> [Recording] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "title CONTAINS[c] %@", title)
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内タイトル検索
        return memoryStorage.values.filter { recording in
            recording.title.localizedCaseInsensitiveContains(title)
        }.sorted { $0.createdAt > $1.createdAt }
        #endif
    }
    
    func findRecent(limit: Int) async throws -> [Recording] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            request.fetchLimit = limit
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内制限取得
        return Array(memoryStorage.values.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
        #endif
    }
    
    func findByDateRange(start: Date, end: Date) async throws -> [Recording] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "createdAt >= %@ AND createdAt <= %@",
                start as NSDate,
                end as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内日付範囲フィルタ
        return memoryStorage.values.filter { recording in
            recording.createdAt >= start && recording.createdAt <= end
        }.sorted { $0.createdAt > $1.createdAt }
        #endif
    }
    
    func delete(_ id: UUID) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリから削除
        memoryStorage.removeValue(forKey: id)
        #endif
    }
    
    #if !MINIMAL_BUILD && !NO_COREDATA
    // MARK: - Private Methods (Core Data only)
    
    private func findOrCreateEntity(for recording: Recording, in context: NSManagedObjectContext) throws -> RecordingEntity {
        let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", recording.id as CVarArg)
        request.fetchLimit = 1
        
        if let existingEntity = try context.fetch(request).first {
            return existingEntity
        } else {
            return RecordingEntity(context: context)
        }
    }
    
    private func updateEntity(_ entity: RecordingEntity, with recording: Recording) {
        entity.id = recording.id
        entity.title = recording.title
        entity.audioFileURL = recording.audioFileURL.absoluteString
        entity.transcription = recording.transcription
        entity.language = recording.language
        entity.duration = recording.duration
        entity.isFromLimitless = recording.isFromLimitless
        entity.createdAt = recording.createdAt
        entity.updatedAt = recording.updatedAt
        
        entity.transcriptionMethod = recording.transcriptionMethod.rawValue
        entity.audioQuality = recording.audioQuality.rawValue
        entity.whisperModel = recording.whisperModel?.rawValue
        
        // Metadata encoding
        if let metadata = try? JSONEncoder().encode(recording.metadata) {
            entity.metadata = metadata
        }
        
        // プロジェクト関連付け（Core Dataのみ）
        if let projectId = recording.projectId {
            let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projectRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
            projectRequest.fetchLimit = 1
            
            if let projectEntity = try? entity.managedObjectContext?.fetch(projectRequest).first {
                entity.project = projectEntity
            }
        }
    }
    #endif
}

#if !MINIMAL_BUILD && !NO_COREDATA
extension RecordingRepository: CoreDataRepository {}
#endif