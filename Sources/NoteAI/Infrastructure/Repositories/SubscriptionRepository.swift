import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import CoreData
#endif

class SubscriptionRepository: SubscriptionRepositoryProtocol {
    #if !MINIMAL_BUILD && !NO_COREDATA
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    #else
    // MINIMAL_BUILD: メモリ内実装
    private var memoryStorage: [UUID: Subscription] = [:]
    
    init(coreDataStack: Any? = nil) {
        // Minimal build does not use Core Data
    }
    #endif
    
    func save(_ subscription: Subscription) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: subscription, in: context)
            self.updateEntity(entity, with: subscription)
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリ内保存
        memoryStorage[subscription.id] = subscription
        #endif
    }
    
    func findById(_ id: UUID) async throws -> Subscription? {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
        #else
        // MINIMAL_BUILD: メモリ内検索
        return memoryStorage[id]
        #endif
    }
    
    func findActiveSubscription() async throws -> Subscription? {
        #if !MINIMAL_BUILD && !NO_COREDATA
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
        #else
        // MINIMAL_BUILD: メモリ内アクティブ検索
        let now = Date()
        return memoryStorage.values.first { subscription in
            subscription.isActive && (subscription.endDate ?? Date.distantFuture) > now
        }
        #endif
    }
    
    func findSubscriptionHistory() async throws -> [Subscription] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "startDate", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内履歴取得
        return Array(memoryStorage.values.sorted { $0.startDate > $1.startDate })
        #endif
    }
    
    func updateSubscriptionStatus(_ id: UUID, isActive: Bool) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if let entity = try context.fetch(request).first {
                entity.isActive = isActive
                entity.updatedAt = Date()
                try context.save()
            }
        }
        #else
        // MINIMAL_BUILD: メモリ内ステータス更新
        if let subscription = memoryStorage[id] {
            let updatedSubscription = Subscription(
                id: subscription.id,
                subscriptionType: subscription.subscriptionType,
                planType: subscription.planType,
                isActive: isActive,
                startDate: subscription.startDate,
                expirationDate: subscription.expirationDate,
                endDate: subscription.endDate,
                receiptData: subscription.receiptData,
                lastValidated: subscription.lastValidated,
                autoRenew: subscription.autoRenew,
                transactionId: subscription.transactionId,
                createdAt: subscription.createdAt,
                updatedAt: Date()
            )
            memoryStorage[id] = updatedSubscription
        }
        #endif
    }
    
    func hasActiveSubscription() async throws -> Bool {
        #if !MINIMAL_BUILD && !NO_COREDATA
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
        #else
        // MINIMAL_BUILD: メモリ内アクティブ判定
        let now = Date()
        return memoryStorage.values.contains { subscription in
            subscription.isActive && (subscription.endDate ?? Date.distantFuture) > now
        }
        #endif
    }
    
    func delete(_ id: UUID) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリから削除
        memoryStorage.removeValue(forKey: id)
        #endif
    }
    
    #if !MINIMAL_BUILD && !NO_COREDATA
    // MARK: - Private Methods (Core Data only)
    
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
        
        // Legacy fields for backward compatibility
        entity.subscriptionType = subscription.subscriptionType.rawValue
        entity.expirationDate = subscription.expirationDate
        entity.lastValidated = subscription.lastValidated
        
        // Revenue Cat transaction identifier
        entity.transactionId = subscription.transactionId
        
        // Receipt data (暗号化保存)
        if let receiptData = subscription.receiptData {
            entity.receiptData = receiptData
        }
    }
    #endif
}

#if !MINIMAL_BUILD && !NO_COREDATA
extension SubscriptionRepository: CoreDataRepository {}
#endif

// MARK: - SubscriptionEntity Extensions

