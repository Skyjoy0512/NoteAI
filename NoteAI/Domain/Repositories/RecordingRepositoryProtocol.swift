import Foundation

protocol RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws
    func findById(_ id: UUID) async throws -> Recording?
    func findByProjectId(_ projectId: UUID) async throws -> [Recording]
    func findAll() async throws -> [Recording]
    func delete(_ id: UUID) async throws
    func search(query: String) async throws -> [Recording]
    func findRecent(limit: Int) async throws -> [Recording]
}