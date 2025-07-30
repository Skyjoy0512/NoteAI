import Foundation

protocol APIUsageRepositoryProtocol {
    func save(_ usage: APIUsage) async throws
    func findById(_ id: UUID) async throws -> APIUsage?
    func findUsageForMonth(year: Int, month: Int) async throws -> [APIUsage]
    func getTotalUsageForMonth(year: Int, month: Int, provider: LLMProvider) async throws -> APIUsageSummary
    func getTotalUsageForProvider(_ provider: LLMProvider) async throws -> APIUsageSummary
    func getRecentUsage(limit: Int) async throws -> [APIUsage]
    func deleteOldUsage(olderThan date: Date) async throws
    func delete(_ id: UUID) async throws
}