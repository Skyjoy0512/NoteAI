import Foundation
import CoreData

// MARK: - APIUsageEntity Extensions

extension APIUsageEntity {
    func toDomain() -> APIUsage? {
        guard
              let providerString = self.providerType,
              let operationString = self.operationType,
              let usedAt = self.usedAt else {
            return nil
        }
        
        // Decode request metadata - Safe unwrapping
        let requestMetadata: APIRequestMetadata?
        if let requestMetadataData = self.requestMetadata {
            do {
                requestMetadata = try JSONDecoder().decode(APIRequestMetadata.self, from: requestMetadataData)
            } catch {
                print("Failed to decode request metadata: \(error)")
                requestMetadata = nil
            }
        } else {
            requestMetadata = nil
        }
        
        // Decode response metadata - Safe unwrapping
        let responseMetadata: APIResponseMetadata?
        if let responseMetadataData = self.responseMetadata {
            do {
                responseMetadata = try JSONDecoder().decode(APIResponseMetadata.self, from: responseMetadataData)
            } catch {
                print("Failed to decode response metadata: \(error)")
                responseMetadata = nil
            }
        } else {
            responseMetadata = nil
        }
        
        // Decode provider
        guard let provider = LLMProvider.from(string: providerString) else {
            return nil
        }
        
        // Decode operation type
        guard let operationType = APIOperationType(rawValue: operationString) else {
            return nil
        }
        
        return APIUsage(
            id: self.id,
            provider: provider,
            operationType: operationType,
            tokensUsed: Int(self.tokensUsed),
            estimatedCost: self.estimatedCost,
            responseTime: self.responseTime,
            usedAt: usedAt,
            requestMetadata: requestMetadata,
            responseMetadata: responseMetadata
        )
    }
}

// MARK: - SubscriptionEntity Extensions

extension SubscriptionEntity {
    func toDomain() -> Subscription? {
        guard let id = self.id,
              let subscriptionTypeString = self.subscriptionType,
              let subscriptionType = SubscriptionType(rawValue: subscriptionTypeString),
              let startDate = self.startDate else {
            return nil
        }
        
        // Handle planType - use subscriptionType as fallback
        let planType: SubscriptionPlan
        if let planTypeString = self.planType,
           let parsedPlanType = SubscriptionPlan(rawValue: planTypeString) {
            planType = parsedPlanType
        } else {
            // Fallback: convert subscriptionType to planType
            planType = subscriptionType == .premium ? .premium : .free
        }
        
        return Subscription(
            id: id,
            subscriptionType: subscriptionType,
            planType: planType,
            isActive: self.isActive,
            startDate: startDate,
            expirationDate: self.expirationDate,
            endDate: self.endDate,
            receiptData: self.receiptData,
            lastValidated: self.lastValidated,
            autoRenew: self.autoRenew,
            transactionId: self.transactionId,
            createdAt: self.createdAt ?? startDate,
            updatedAt: self.updatedAt ?? startDate
        )
    }
}