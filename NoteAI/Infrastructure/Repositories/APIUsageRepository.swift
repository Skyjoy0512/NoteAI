import Foundation
import CoreData

class APIUsageRepository: APIUsageRepositoryProtocol, CoreDataRepository {
    let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func save(_ usage: APIUsage) async throws {
        try await withContext { context in
            let entity = try self.findOrCreateEntity(for: usage, in: context)
            self.updateEntity(entity, with: usage)
            try context.save()
        }
    }
    
    func findById(_ id: UUID) async throws -> APIUsage? {
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }
    
    func findUsageForMonth(year: Int, month: Int) async throws -> [APIUsage] {
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
    }
    
    func getTotalUsageForMonth(year: Int, month: Int, provider: LLMProvider) async throws -> APIUsageSummary {
        let monthlyUsage = try await findUsageForMonth(year: year, month: month)
        let providerUsage = monthlyUsage.filter { $0.provider.keychainIdentifier == provider.keychainIdentifier }
        
        var totalTokens: Int32 = 0
        var totalCost: Double = 0.0
        var totalRequests: Int32 = 0
        
        for usage in providerUsage {
            totalTokens += usage.tokensUsed
            totalCost += usage.estimatedCost
            totalRequests += 1
        }
        
        return APIUsageSummary(
            provider: provider,
            year: year,
            month: month,
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            totalCost: totalCost,
            usageDetails: providerUsage
        )
    }
    
    func getTotalUsageForProvider(_ provider: LLMProvider) async throws -> APIUsageSummary {
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "providerType == %@", provider.keychainIdentifier)
            
            let entities = try context.fetch(request)
            let usage = entities.compactMap { $0.toDomain() }
            
            var totalTokens: Int32 = 0
            var totalCost: Double = 0.0
            let totalRequests = Int32(usage.count)
            
            for item in usage {
                totalTokens += item.tokensUsed
                totalCost += item.estimatedCost
            }
            
            return APIUsageSummary(
                provider: provider,
                year: Calendar.current.component(.year, from: Date()),
                month: Calendar.current.component(.month, from: Date()),
                totalRequests: totalRequests,
                totalTokens: totalTokens,
                totalCost: totalCost,
                usageDetails: usage
            )
        }
    }
    
    func getRecentUsage(limit: Int) async throws -> [APIUsage] {
        return try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "usedAt", ascending: false)
            ]
            request.fetchLimit = limit
            
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }
    
    func deleteOldUsage(olderThan date: Date) async throws {
        try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "usedAt < %@", date as NSDate)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
    }
    
    func delete(_ id: UUID) async throws {
        try await withContext { context in
            let request: NSFetchRequest<APIUsageEntity> = APIUsageEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Private Methods
    
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
        entity.tokensUsed = usage.tokensUsed
        entity.estimatedCost = usage.estimatedCost
        entity.responseTime = usage.responseTime
        entity.usedAt = usage.usedAt
        
        // Request/Response metadata (JSONエンコード)
        if let requestMetadata = try? JSONEncoder().encode(usage.requestMetadata) {
            entity.requestMetadata = requestMetadata
        }
        
        if let responseMetadata = try? JSONEncoder().encode(usage.responseMetadata) {
            entity.responseMetadata = responseMetadata
        }
    }
}

// MARK: - APIUsageEntity Extensions

extension APIUsageEntity {
    func toDomain() -> APIUsage? {
        guard let id = self.id,
              let providerTypeString = self.providerType,
              let operationTypeString = self.operationType,
              let operationType = APIOperationType(rawValue: operationTypeString),
              let usedAt = self.usedAt else {
            return nil
        }
        
        // Providerのデコード (TODO: 実際のLLMProvider定義に合わせて調整)
        let provider = decodeLLMProvider(from: providerTypeString)
        
        // Metadataのデコード
        var requestMetadata: [String: AnyCodable] = [:]
        var responseMetadata: [String: AnyCodable] = [:]
        
        if let requestData = self.requestMetadata {
            requestMetadata = (try? JSONDecoder().decode([String: AnyCodable].self, from: requestData)) ?? [:]
        }
        
        if let responseData = self.responseMetadata {
            responseMetadata = (try? JSONDecoder().decode([String: AnyCodable].self, from: responseData)) ?? [:]
        }
        
        return APIUsage(
            id: id,
            provider: provider,
            operationType: operationType,
            tokensUsed: self.tokensUsed,
            estimatedCost: self.estimatedCost,
            responseTime: self.responseTime,
            requestMetadata: requestMetadata,
            responseMetadata: responseMetadata,
            usedAt: usedAt
        )
    }
    
    private func decodeLLMProvider(from string: String) -> LLMProvider {
        // TODO: 実際LLMProvider定義で置き換え
        // 一時的なmock providerを返す
        return MockLLMProvider(identifier: string)
    }
}

// MARK: - Supporting Types

struct APIUsageSummary {
    let provider: LLMProvider
    let year: Int
    let month: Int
    let totalRequests: Int32
    let totalTokens: Int32
    let totalCost: Double
    let usageDetails: [APIUsage]
    
    var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalCost)) ?? "$0.00"
    }
    
    var averageResponseTime: TimeInterval {
        guard !usageDetails.isEmpty else { return 0 }
        let total = usageDetails.reduce(0) { $0 + $1.responseTime }
        return total / Double(usageDetails.count)
    }
    
    var formattedAverageResponseTime: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: averageResponseTime)) ?? "0")s"
    }
}

// Note: MockLLMProvider moved to MockServices.swift