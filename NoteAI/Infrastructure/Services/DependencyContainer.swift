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
    
    // MARK: - Future Services (Phase 4+)
    // These services will be implemented in later phases:
    // - apiKeyManager: APIKeyManagerProtocol
    // - apiUsageTracker: APIUsageTrackerProtocol  
    // - llmService: LLMServiceProtocol
    // - subscriptionService: SubscriptionServiceProtocol
    // - searchService: SearchServiceProtocol
    
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
    
    // MARK: - Future UseCases (Phase 3+)
    // These use cases will be implemented in later phases:
    // - makeProjectUseCase() -> ProjectUseCaseProtocol
    // - makeProjectAIUseCase() -> ProjectAIUseCaseProtocol  
    // - makeSubscriptionUseCase() -> SubscriptionUseCaseProtocol
    
    // MARK: - ViewModel Factories
    func makeRecordingViewModel() -> RecordingViewModel {
        return RecordingViewModel(
            recordingUseCase: makeRecordingUseCase(),
            transcriptionUseCase: makeTranscriptionUseCase(),
            projectRepository: projectRepository
        )
    }
    
    // MARK: - Future ViewModels (Phase 3+)
    // These view models will be implemented in later phases:
    // - makeProjectListViewModel() -> ProjectListViewModel
    // - makeProjectDetailViewModel(project:) -> ProjectDetailViewModel
    // - makeSettingsViewModel() -> SettingsViewModel
    
    // MARK: - Additional Services (Lazy Initialization)
    private lazy var audioFileManager: AudioFileManagerProtocol = {
        AudioFileManager()
    }()
    
    // TODO: These services will be implemented in Phase 4
    private lazy var apiTranscriptionService: APITranscriptionServiceProtocol = {
        // Temporary mock implementation
        return MockAPITranscriptionService()
    }()
    
    private lazy var subscriptionService: SubscriptionServiceProtocol = {
        // Temporary mock implementation  
        return MockSubscriptionService()
    }()
}

    // MARK: - Future Implementation Notes
    // The following components will be implemented in subsequent phases:
    // 
    // Phase 3:
    // - ProjectUseCase: Project management business logic
    // - ProjectListViewModel, ProjectDetailViewModel: Project UI components
    // 
    // Phase 4:
    // - APIKeyManager: API key secure storage and management
    // - LLMService: External AI service integration
    // - SubscriptionService: Premium feature management
    // - SettingsViewModel: App configuration UI
    // 
    // Phase 5:
    // - RAGService: Advanced search and AI analysis
    // - ProjectAIUseCase: AI-powered project insights