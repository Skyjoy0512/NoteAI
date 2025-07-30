import Foundation

// MARK: - Entity Imports from Domain Layer

// Clean Architecture: All entities should be imported from Domain layer
// These type aliases provide backward compatibility for existing code

// Import the canonical Project and Recording entities from Domain layer
// Note: The actual entities are defined in:
// - Domain/Entities/Project.swift
// - Domain/Entities/Recording.swift

// Type aliases for backward compatibility (remove after migration)
// typealias LightweightProject = Project
// typealias LightweightRecording = Recording

// MARK: - Helper Extensions for Domain Entities

// Add any lightweight utility extensions here if needed
// These should be minimal and not duplicate domain logic