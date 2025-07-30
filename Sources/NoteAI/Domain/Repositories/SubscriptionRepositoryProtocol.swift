import Foundation

protocol SubscriptionRepositoryProtocol {
    func save(_ subscription: Subscription) async throws
    func findById(_ id: UUID) async throws -> Subscription?
    func findActiveSubscription() async throws -> Subscription?
    func findSubscriptionHistory() async throws -> [Subscription]
    func updateSubscriptionStatus(_ id: UUID, isActive: Bool) async throws
    func hasActiveSubscription() async throws -> Bool
    func delete(_ id: UUID) async throws
}