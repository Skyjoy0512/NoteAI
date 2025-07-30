import Foundation
import CoreData

extension SubscriptionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscriptionEntity> {
        return NSFetchRequest<SubscriptionEntity>(entityName: "SubscriptionEntity")
    }

    @NSManaged public var expirationDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isActive: Bool
    @NSManaged public var lastValidated: Date?
    @NSManaged public var receiptData: Data?
    @NSManaged public var startDate: Date?
    @NSManaged public var subscriptionType: String?
    @NSManaged public var planType: String?
    @NSManaged public var endDate: Date?
    @NSManaged public var autoRenew: Bool
    @NSManaged public var transactionId: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?

}

extension SubscriptionEntity : @preconcurrency Identifiable {

}