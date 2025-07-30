import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import CoreData
#endif

class APIUsageRepository: APIUsageRepositoryProtocol {
    #if !MINIMAL_BUILD && !NO_COREDATA
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    #else
    // MINIMAL_BUILD: メモリ内実装
    private var memoryStorage: [UUID: APIUsage] = [:]
    
    init(coreDataStack: Any? = nil) {
        // Minimal build does not use Core Data
    }
    #endif
    
    func save(_ usage: APIUsage) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: usage, in: context)
            self.updateEntity(entity, with: usage)
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリ内保存
        memoryStorage[usage.id] = usage
        #endif
    }
    
    func findById(_ id: UUID) async throws -> APIUsage? {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
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
    
    func findUsageForMonth(year: Int, month: Int) async throws -> [APIUsage] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return []
        }
        
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "usedAt >= %@ AND usedAt < %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "usedAt", ascending: false)
            ]
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内フィルタ
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return []
        }
        
        return memoryStorage.values.filter { usage in
            usage.usedAt >= startDate && usage.usedAt < endDate
        }.sorted { $0.usedAt > $1.usedAt }
        #endif
    }
    
    func getTotalUsageForMonth(year: Int, month: Int, provider: LLMProvider) async throws -> APIUsageSummary {
        let monthlyUsage = try await findUsageForMonth(year: year, month: month)
        let providerUsage = monthlyUsage.filter { $0.provider.keychainIdentifier == provider.keychainIdentifier }
        
        var totalTokens: Int = 0
        var totalCost: Double = 0.0
        var totalRequests: Int = 0
        
        for usage in providerUsage {
            totalTokens += usage.tokensUsed
            totalCost += usage.estimatedCost
            totalRequests += 1
        }
        
        return APIUsageSummary(
            provider: provider,
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            totalCost: totalCost,
            averageResponseTime: 0.0,
            operationBreakdown: [:],
            period: nil
        )
    }
    
    func getTotalUsageForProvider(_ provider: LLMProvider) async throws -> APIUsageSummary {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "providerType == %@", provider.keychainIdentifier)
            
            let entities = try context.fetch(request)
            let usage = entities.compactMap { $0.toDomain() }
            
            var totalTokens: Int = 0
            var totalCost: Double = 0.0
            let totalRequests = usage.count
            
            for item in usage {
                totalTokens += item.tokensUsed
                totalCost += item.estimatedCost
            }
            
            return APIUsageSummary(
                provider: provider,
                totalRequests: totalRequests,
                totalTokens: totalTokens,
                totalCost: totalCost,
                averageResponseTime: 0.0,
                operationBreakdown: [:],
                period: nil
            )
        }
        #else
        // MINIMAL_BUILD: メモリ内集計
        let usage = memoryStorage.values.filter { $0.provider.keychainIdentifier == provider.keychainIdentifier }
        
        var totalTokens: Int = 0
        var totalCost: Double = 0.0
        let totalRequests = usage.count
        
        for item in usage {
            totalTokens += item.tokensUsed
            totalCost += item.estimatedCost
        }
        
        return APIUsageSummary(
            provider: provider,
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            totalCost: totalCost,
            averageResponseTime: 0.0,
            operationBreakdown: [:],
            period: nil
        )
        #endif
    }
    
    func getRecentUsage(limit: Int) async throws -> [APIUsage] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "usedAt", ascending: false)
            ]
            request.fetchLimit = limit
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
        #else
        // MINIMAL_BUILD: メモリ内ソートと制限
        return Array(memoryStorage.values.sorted { $0.usedAt > $1.usedAt }.prefix(limit))
        #endif
    }
    
    func deleteOldUsage(olderThan date: Date) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "usedAt < %@", date as NSDate)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
        #else
        // MINIMAL_BUILD: メモリから削除
        memoryStorage = memoryStorage.filter { $0.value.usedAt >= date }
        #endif
    }
    
    func delete(_ id: UUID) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
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
    
    private func findOrCreateEntity(for usage: APIUsage, in context: NSManagedObjectContext) throws -> APIUsageEntity {
        let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", usage.id as CVarArg)
        request.fetchLimit = 1
        
        if let existingEntity = try context.fetch(request).first {
            return existingEntity
        } else {
            return APIUsageEntity(context: context)
        }
    }
    
    private func updateEntity(_ entity: APIUsageEntity, with usage: APIUsage) {
        entity.id = usage.id
        entity.providerType = usage.provider.keychainIdentifier
        entity.operationType = usage.operationType.rawValue
        entity.tokensUsed = Int32(usage.tokensUsed)
        entity.estimatedCost = usage.estimatedCost
        entity.responseTime = usage.responseTime
        entity.usedAt = usage.usedAt
        
        // Legacy fields for backward compatibility
        entity.provider = usage.provider.keychainIdentifier
        entity.tokens = Int32(usage.tokensUsed)
        entity.date = usage.usedAt
        
        // Request/Response metadata (JSONエンコード)
        if let requestMetadata = try? JSONEncoder().encode(usage.requestMetadata) {
            entity.requestMetadata = requestMetadata
        }
        
        if let responseMetadata = try? JSONEncoder().encode(usage.responseMetadata) {
            entity.responseMetadata = responseMetadata
        }
    }
    #endif
}

#if !MINIMAL_BUILD && !NO_COREDATA
extension APIUsageRepository: CoreDataRepository {}
#endif