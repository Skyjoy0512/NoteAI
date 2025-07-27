import Foundation
import CoreData

class ProjectRepository: ProjectRepositoryProtocol {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func save(_ project: Project) async throws {
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: project, in: context)
            self.updateEntity(entity, with: project)
            try context.save()
        }
    }
    
    func findById(_ id: UUID) async throws -> Project? {
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }
    
    func findAll() async throws -> [Project] {
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func delete(_ id: UUID) async throws {
        try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
    }
    
    func findByIds(_ ids: [UUID]) async throws -> [Project] {
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func search(query: String) async throws -> [Project] {
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "name CONTAINS[cd] %@ OR projectDescription CONTAINS[cd] %@",
                query, query
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    // MARK: - Private Methods
    
    private func withContext<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.newBackgroundContext()
            context.perform {
                do {
                    let result = try operation(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
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
        
        // メタデータをJSONエンコードして保存
        if let metadataData = try? JSONEncoder().encode(project.metadata) {
            entity.metadata = metadataData
        }
    }
}

// MARK: - ProjectEntity Extensions

extension ProjectEntity {
    func toDomain() -> Project? {
        guard let id = self.id,
              let name = self.name,
              let createdAt = self.createdAt,
              let updatedAt = self.updatedAt else {
            return nil
        }
        
        // メタデータデコード
        var metadata = ProjectMetadata()
        if let metadataData = self.metadata {
            metadata = (try? JSONDecoder().decode(ProjectMetadata.self, from: metadataData)) ?? ProjectMetadata()
        }
        
        return Project(
            id: id,
            name: name,
            description: self.projectDescription,
            coverImageData: self.coverImageData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata
        )
    }
}