import Foundation

protocol ProjectRepositoryProtocol {
    func save(_ project: Project) async throws
    func findById(_ id: UUID) async throws -> Project?
    func findAll() async throws -> [Project]
    func delete(_ id: UUID) async throws
    func findByIds(_ ids: [UUID]) async throws -> [Project]
    func search(query: String) async throws -> [Project]
}