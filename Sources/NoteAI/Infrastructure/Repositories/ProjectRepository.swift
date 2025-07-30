import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import CoreData
#endif

class ProjectRepository: ProjectRepositoryProtocol {
    #if !MINIMAL_BUILD && !NO_COREDATA
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    #else
    // MINIMAL_BUILD: メモリ内実装
    private var memoryStorage: [UUID: Project] = [:]
    
    init(coreDataStack: Any? = nil) {
        // Minimal build does not use Core Data
    }
    #endif
    
    func save(_ project: Project) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: project, in: context)
            self.updateEntity(entity, with: project)
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリ内保存
        memoryStorage[project.id] = project
        #endif
    }
    
    func findById(_ id: UUID) async throws -> Project? {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
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
    
    func findAll() async throws -> [Project] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内全取得
        return Array(memoryStorage.values.sorted { $0.updatedAt > $1.updatedAt })
        #endif
    }
    
    func findByIds(_ ids: [UUID]) async throws -> [Project] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内ID検索
        return ids.compactMap { memoryStorage[$0] }.sorted { $0.updatedAt > $1.updatedAt }
        #endif
    }
    
    func search(query: String) async throws -> [Project] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name CONTAINS[c] %@", query)
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内検索
        return memoryStorage.values.filter { project in
            project.name.localizedCaseInsensitiveContains(query)
        }.sorted { $0.updatedAt > $1.updatedAt }
        #endif
    }
    
    func findByName(_ name: String) async throws -> [Project] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name CONTAINS[c] %@", name)
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内検索
        return memoryStorage.values.filter { project in
            project.name.localizedCaseInsensitiveContains(name)
        }.sorted { $0.updatedAt > $1.updatedAt }
        #endif
    }
    
    func findRecentProjects(limit: Int) async throws -> [Project] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            request.fetchLimit = limit
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内制限取得
        return Array(memoryStorage.values.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
        #endif
    }
    
    func findByTag(_ tag: String) async throws -> [Project] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "ANY tags.name == %@", tag)
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内タグ検索（簡略化）
        return memoryStorage.values.filter { project in
            // 簡単な実装：メタデータにタグ情報があると仮定
            return false // タグ機能は最小実装では無効
        }.sorted { $0.updatedAt > $1.updatedAt }
        #endif
    }
    
    func delete(_ id: UUID) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
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
    
    private func findOrCreateEntity(for project: Project, in context: NSManagedObjectContext) throws -> ProjectEntity {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)
        request.fetchLimit = 1
        
        if let existingEntity = try context.fetch(request).first {
            return existingEntity
        } else {
            return ProjectEntity(context: context)
        }
    }
    
    private func updateEntity(_ entity: ProjectEntity, with project: Project) {
        entity.id = project.id
        entity.name = project.name
        entity.projectDescription = project.description
        entity.coverImageData = project.coverImageData
        entity.createdAt = project.createdAt
        entity.updatedAt = project.updatedAt
        
        // Metadata encoding
        if let metadata = try? JSONEncoder().encode(project.metadata) {
            entity.metadata = metadata
        }
    }
    #endif
}

#if !MINIMAL_BUILD && !NO_COREDATA
extension ProjectRepository: CoreDataRepository {}
#endif