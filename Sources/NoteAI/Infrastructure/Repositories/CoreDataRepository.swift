import Foundation
import CoreData

// MARK: - Base Repository Protocol

protocol CoreDataRepository {
    var coreDataStack: CoreDataStack { get }
}

extension CoreDataRepository {
    func withContext<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
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
}

// MARK: - Entity Mapping Protocol

protocol DomainMappable {
    associatedtype DomainType
    func toDomain() -> DomainType?
}

protocol EntityMappable {
    associatedtype EntityType: NSManagedObject
    func toEntity(in context: NSManagedObjectContext) -> EntityType
}

// MARK: - Repository Error Types

enum RepositoryError: LocalizedError {
    case entityNotFound(String)
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let identifier):
            return "エンティティが見つかりません: \(identifier)"
        case .saveFailed(let error):
            return "保存に失敗しました: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "データの取得に失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "削除に失敗しました: \(error.localizedDescription)"
        case .invalidData(let message):
            return "無効なデータ: \(message)"
        }
    }
}