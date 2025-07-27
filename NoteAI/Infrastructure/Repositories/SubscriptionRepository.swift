import Foundation
import CoreData

class SubscriptionRepository: SubscriptionRepositoryProtocol, CoreDataRepository {
    let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func save(_ subscription: Subscription) async throws {
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: subscription, in: context)
            self.updateEntity(entity, with: subscription)
            try context.save()
        }
    }
    
    func findById(_ id: UUID) async throws -> Subscription? {
        return try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }
    
    func findActiveSubscription() async throws -> Subscription? {
        return try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "isActive == YES AND endDate > %@",
                Date() as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "endDate", ascending: false)
            ]
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }
    
    func findSubscriptionHistory() async throws -> [Subscription] {
        return try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "startDate", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func updateSubscriptionStatus(_ id: UUID, isActive: Bool) async throws {
        try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if let entity = try context.fetch(request).first {
                entity.isActive = isActive
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }
    
    func hasActiveSubscription() async throws -> Bool {
        return try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "isActive == YES AND endDate > %@",
                Date() as NSDate
            )
            request.fetchLimit = 1
            
            let count = try context.count(for: request)
            return count > 0
        }
    }
    
    func delete(_ id: UUID) async throws {
        try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Private Methods
    
    private func findOrCreateEntity(for subscription: Subscription, in context: NSManagedObjectContext) throws -> SubscriptionEntity {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", subscription.id as CVarArg)
        request.fetchLimit = 1
        
        if let existingEntity = try context.fetch(request).first {
            return existingEntity
        } else {
            return SubscriptionEntity(context: context)
        }
    }
    
    private func updateEntity(_ entity: SubscriptionEntity, with subscription: Subscription) {
        entity.id = subscription.id
        entity.planType = subscription.planType.rawValue
        entity.startDate = subscription.startDate
        entity.endDate = subscription.endDate
        entity.isActive = subscription.isActive
        entity.autoRenew = subscription.autoRenew
        entity.createdAt = subscription.createdAt
        entity.updatedAt = subscription.updatedAt
        
        // Revenue Cat transaction identifier
        entity.transactionId = subscription.transactionId
        
        // Receipt data (暗号化保存)
        if let receiptData = subscription.receiptData {
            entity.receiptData = receiptData
        }
    }
}

// MARK: - SubscriptionEntity Extensions

extension SubscriptionEntity {
    func toDomain() -> Subscription? {
        guard let id = self.id,
              let planTypeString = self.planType,
              let planType = SubscriptionPlan(rawValue: planTypeString),
              let startDate = self.startDate,
              let endDate = self.endDate,
              let createdAt = self.createdAt,
              let updatedAt = self.updatedAt else {
            return nil
        }
        
        return Subscription(
            id: id,
            planType: planType,
            startDate: startDate,
            endDate: endDate,
            isActive: self.isActive,
            autoRenew: self.autoRenew,
            transactionId: self.transactionId,
            receiptData: self.receiptData,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}