import Foundation

protocol ProjectRepositoryProtocol {
    func save(_ project: Project) async throws
    func findById(_ id: UUID) async throws -> Project?
    func findAll() async throws -> [Project]
    func delete(_ id: UUID) async throws
    func findByIds(_ ids: [UUID]) async throws -> [Project]
    func search(query: String) async throws -> [Project]
}

protocol RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws
    func findById(_ id: UUID) async throws -> Recording?
    func findByProjectId(_ projectId: UUID) async throws -> [Recording]
    func findAll() async throws -> [Recording]
    func delete(_ id: UUID) async throws
    func search(query: String) async throws -> [Recording]
    func findRecent(limit: Int) async throws -> [Recording]
}

protocol SubscriptionRepositoryProtocol {
    func save(_ subscription: Subscription) async throws
    func findCurrent() async throws -> Subscription?
    func findAll() async throws -> [Subscription]
}

protocol APIUsageRepositoryProtocol {
    func save(_ usage: APIUsage) async throws
    func findUsages(provider: LLMProvider, from: Date, to: Date) async throws -> [APIUsage]
    func getMonthlyUsage(provider: LLMProvider, month: String) async throws -> [APIUsage]
    func getTotalMonthlyCost(month: String) async throws -> Double
}