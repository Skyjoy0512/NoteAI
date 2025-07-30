import Foundation
import CoreData

extension APIUsageEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<APIUsageEntity> {
        return NSFetchRequest<APIUsageEntity>(entityName: "APIUsageEntity")
    }

    @NSManaged public var audioMinutes: Double
    @NSManaged public var date: Date
    @NSManaged public var estimatedCost: Double
    @NSManaged public var id: UUID
    @NSManaged public var month: String
    @NSManaged public var provider: String
    @NSManaged public var requests: Int32
    @NSManaged public var tokens: Int32
    @NSManaged public var providerType: String?
    @NSManaged public var operationType: String?
    @NSManaged public var tokensUsed: Int32
    @NSManaged public var responseTime: Double
    @NSManaged public var usedAt: Date?
    @NSManaged public var requestMetadata: Data?
    @NSManaged public var responseMetadata: Data?

}

extension APIUsageEntity : @preconcurrency Identifiable {

}