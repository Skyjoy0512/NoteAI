import Foundation
import CoreData

class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Core Data Stack
    lazy var coreDataStack: CoreDataStack = {
        return CoreDataStack.shared
    }()
    
    // MARK: - Repository Factories
    lazy var projectRepository: ProjectRepositoryProtocol = {
        ProjectRepository(coreDataStack: coreDataStack)
    }()
    
    lazy var recordingRepository: RecordingRepositoryProtocol = {
        RecordingRepository(coreDataStack: coreDataStack)
    }()
    
    lazy var subscriptionRepository: SubscriptionRepositoryProtocol = {
        SubscriptionRepository(coreDataStack: coreDataStack)
    }()
    
    lazy var apiUsageRepository: APIUsageRepositoryProtocol = {
        APIUsageRepository(coreDataStack: coreDataStack)
    }()
    
    // MARK: - Service Factories
    lazy var audioService: AudioServiceProtocol = {
        AudioService()
    }()
    
    lazy var whisperKitService: WhisperKitServiceProtocol = {
        WhisperKitService()
    }()
    
    lazy var apiKeyManager: APIKeyManagerProtocol = {
        APIKeyManager()
    }()
    
    lazy var apiUsageTracker: APIUsageTrackerProtocol = {
        APIUsageTracker(
            repository: apiUsageRepository,
            notificationCenter: .default
        )
    }()
    
    lazy var llmService: LLMServiceProtocol = {
        LLMService(
            apiKeyManager: apiKeyManager,
            usageTracker: apiUsageTracker
        )
    }()
    
    lazy var subscriptionService: SubscriptionServiceProtocol = {
        SubscriptionService(repository: subscriptionRepository)
    }()
    
    lazy var searchService: SearchServiceProtocol = {
        SearchService()
    }()
    
    // MARK: - UseCase Factories
    func makeRecordingUseCase() -> RecordingUseCaseProtocol {
        return RecordingUseCase(
            audioService: audioService,
            recordingRepository: recordingRepository,
            fileManager: audioFileManager
        )
    }
    
    func makeTranscriptionUseCase() -> TranscriptionUseCaseProtocol {
        return TranscriptionUseCase(
            whisperKitService: whisperKitService,
            apiTranscriptionService: apiTranscriptionService,
            subscriptionService: subscriptionService,
            recordingRepository: recordingRepository
        )
    }
    
    func makeProjectUseCase() -> ProjectUseCaseProtocol {
        return ProjectUseCase(
            projectRepository: projectRepository,
            recordingRepository: recordingRepository
        )
    }
    
    func makeProjectAIUseCase() -> ProjectAIUseCaseProtocol {
        return ProjectAIUseCase(
            projectRepository: projectRepository,
            llmService: llmService,
            ragService: ragService,
            subscriptionService: subscriptionService
        )
    }
    
    func makeSubscriptionUseCase() -> SubscriptionUseCaseProtocol {
        return SubscriptionUseCase(
            subscriptionService: subscriptionService,
            subscriptionRepository: subscriptionRepository
        )
    }
    
    // MARK: - ViewModel Factories
    func makeRecordingViewModel() -> RecordingViewModel {
        return RecordingViewModel(
            recordingUseCase: makeRecordingUseCase(),
            transcriptionUseCase: makeTranscriptionUseCase(),
            projectRepository: projectRepository
        )
    }
    
    func makeProjectListViewModel() -> ProjectListViewModel {
        return ProjectListViewModel(
            projectUseCase: makeProjectUseCase()
        )
    }
    
    func makeProjectDetailViewModel(project: Project) -> ProjectDetailViewModel {
        return ProjectDetailViewModel(
            project: project,
            projectRepository: projectRepository,
            recordingRepository: recordingRepository,
            projectAIUseCase: makeProjectAIUseCase()
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            subscriptionUseCase: makeSubscriptionUseCase(),
            apiKeyManager: apiKeyManager,
            apiUsageTracker: apiUsageTracker
        )
    }
    
    // MARK: - Additional Services (Lazy Initialization)
    private lazy var audioFileManager: AudioFileManagerProtocol = {
        AudioFileManager()
    }()
    
    private lazy var apiTranscriptionService: APITranscriptionServiceProtocol = {
        APITranscriptionService(
            apiKeyManager: apiKeyManager,
            usageTracker: apiUsageTracker
        )
    }()
    
    private lazy var ragService: RAGServiceProtocol = {
        RAGService(searchService: searchService)
    }()
}

// MARK: - Additional Service Protocols (will be implemented in Phase 4)
protocol APIKeyManagerProtocol {}
protocol APIUsageTrackerProtocol {}
protocol LLMServiceProtocol {}
protocol SearchServiceProtocol {}
protocol RAGServiceProtocol {}

// MARK: - UseCase Protocol Definitions (will be implemented in Phase 3-4)
protocol ProjectUseCaseProtocol {}
protocol ProjectAIUseCaseProtocol {}
protocol SubscriptionUseCaseProtocol {}

// MARK: - Service Implementations (Phase 4 implementation)
class APIKeyManager: APIKeyManagerProtocol {}
class APIUsageTracker: APIUsageTrackerProtocol {
    init(repository: APIUsageRepositoryProtocol, notificationCenter: NotificationCenter) {}
}
class LLMService: LLMServiceProtocol {
    init(apiKeyManager: APIKeyManagerProtocol, usageTracker: APIUsageTrackerProtocol) {}
}
class SearchService: SearchServiceProtocol {}
class RAGService: RAGServiceProtocol {
    init(searchService: SearchServiceProtocol) {}
}

// MARK: - UseCase Implementations (Phase 3-4 implementation)
class ProjectUseCase: ProjectUseCaseProtocol {
    init(projectRepository: ProjectRepositoryProtocol, recordingRepository: RecordingRepositoryProtocol) {}
}
class ProjectAIUseCase: ProjectAIUseCaseProtocol {
    init(projectRepository: ProjectRepositoryProtocol, llmService: LLMServiceProtocol, ragService: RAGServiceProtocol, subscriptionService: SubscriptionServiceProtocol) {}
}
class SubscriptionUseCase: SubscriptionUseCaseProtocol {
    init(subscriptionService: SubscriptionServiceProtocol, subscriptionRepository: SubscriptionRepositoryProtocol) {}
}

// Note: Repository implementations are in their respective files:
// - ProjectRepository in /Infrastructure/Repositories/ProjectRepository.swift
// - RecordingRepository in /Infrastructure/Repositories/RecordingRepository.swift  
// - SubscriptionRepository in /Infrastructure/Repositories/SubscriptionRepository.swift
// - APIUsageRepository in /Infrastructure/Repositories/APIUsageRepository.swift

// Note: ViewModel implementations will be in /Presentation/ViewModels/ directory
// - RecordingViewModel in Phase 2 completion
// - ProjectListViewModel, ProjectDetailViewModel in Phase 3  
// - SettingsViewModel in Phase 4