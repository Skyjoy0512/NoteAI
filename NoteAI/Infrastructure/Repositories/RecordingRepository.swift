import Foundation
import CoreData

class RecordingRepository: RecordingRepositoryProtocol {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func save(_ recording: Recording) async throws {
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: recording, in: context)
            self.updateEntity(entity, with: recording)
            try context.save()
        }
    }
    
    func findById(_ id: UUID) async throws -> Recording? {
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }
    
    func findByProjectId(_ projectId: UUID) async throws -> [Recording] {
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "project.id == %@", projectId as CVarArg)
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func findAll() async throws -> [Recording] {
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func delete(_ id: UUID) async throws {
        try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
    }
    
    func search(query: String) async throws -> [Recording] {
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "title CONTAINS[cd] %@ OR transcription CONTAINS[cd] %@",
                query, query
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func findRecent(limit: Int) async throws -> [Recording] {
        return try await withContext { context in
            let request: NSFetchRequest<RecordingEntity> = RecordingEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            request.fetchLimit = limit
            
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
        
        // Enums を文字列として保存
        entity.transcriptionMethod = encodeTranscriptionMethod(recording.transcriptionMethod)
        entity.audioQuality = recording.audioQuality.rawValue
        entity.whisperModel = recording.whisperModel?.rawValue
        
        // メタデータをJSONエンコードして保存
        if let metadataData = try? JSONEncoder().encode(recording.metadata) {
            entity.metadata = metadataData
        }
        
        // プロジェクト関連付け
        if let projectId = recording.projectId {
            let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projectRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
            projectRequest.fetchLimit = 1
            
            if let projectEntity = try? entity.managedObjectContext?.fetch(projectRequest).first {
                entity.project = projectEntity
            }
        }
    }
    
    private func encodeTranscriptionMethod(_ method: TranscriptionMethod) -> String {
        switch method {
        case .local(let model):
            return "local:\(model.rawValue)"
        case .api(let provider):
            return "api:\(provider.keychainIdentifier)"
        }
    }
    
    private func decodeTranscriptionMethod(_ methodString: String) -> TranscriptionMethod {
        let components = methodString.components(separatedBy: ":")
        guard components.count == 2 else {
            return .local(.base) // デフォルト
        }
        
        switch components[0] {
        case "local":
            let model = WhisperModel(rawValue: components[1]) ?? .base
            return .local(model)
        case "api":
            // TODO: LLMProvider のデコード実装
            return .local(.base) // 暫定
        default:
            return .local(.base)
        }
    }
}

// MARK: - RecordingEntity Extensions

extension RecordingEntity {
    func toDomain() -> Recording? {
        guard let id = self.id,
              let title = self.title,
              let audioFileURLString = self.audioFileURL,
              let audioFileURL = URL(string: audioFileURLString),
              let createdAt = self.createdAt,
              let updatedAt = self.updatedAt else {
            return nil
        }
        
        // メタデータデコード
        var metadata = RecordingMetadata()
        if let metadataData = self.metadata {
            metadata = (try? JSONDecoder().decode(RecordingMetadata.self, from: metadataData)) ?? RecordingMetadata()
        }
        
        // Enumsデコード
        let audioQuality = AudioQuality(rawValue: self.audioQuality ?? "standard") ?? .standard
        let whisperModel = self.whisperModel.flatMap { WhisperModel(rawValue: $0) }
        let transcriptionMethod = decodeTranscriptionMethod(self.transcriptionMethod ?? "local:base")
        
        return Recording(
            id: id,
            title: title,
            audioFileURL: audioFileURL,
            transcription: self.transcription,
            transcriptionMethod: transcriptionMethod,
            whisperModel: whisperModel,
            language: self.language ?? "ja",
            duration: self.duration,
            audioQuality: audioQuality,
            isFromLimitless: self.isFromLimitless,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            projectId: self.project?.id
        )
    }
    
    private func decodeTranscriptionMethod(_ methodString: String) -> TranscriptionMethod {
        let components = methodString.components(separatedBy: ":")
        guard components.count == 2 else {
            return .local(.base)
        }
        
        switch components[0] {
        case "local":
            let model = WhisperModel(rawValue: components[1]) ?? .base
            return .local(model)
        case "api":
            // TODO: LLMProvider のデコード実装
            return .local(.base) // 暫定
        default:
            return .local(.base)
        }
    }
}