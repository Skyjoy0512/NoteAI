import Foundation
import CoreData

@MainActor
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
    
    // MARK: - Phase 4 Services
    lazy var apiKeyManager: APIKeyManagerProtocol = {
        APIKeyManager()
    }()
    
    lazy var apiUsageTracker: APIUsageTrackerProtocol = {
        APIUsageTracker()
    }()
    
    lazy var llmService: LLMServiceProtocol = {
        LLMService()
    }()
    
    lazy var apiTranscriptionService: APITranscriptionServiceProtocol = {
        // TODO: Implement proper APITranscriptionService
        // For now, use MockAPITranscriptionService
        MockAPITranscriptionService()
    }()
    
    lazy var subscriptionService: SubscriptionServiceProtocol = {
        SubscriptionService()
    }()
    
    // MARK: - Phase 5 Services
    lazy var embeddingService: EmbeddingServiceProtocol = {
        EmbeddingService(
            llmService: llmService,
            apiKeyManager: apiKeyManager
        )
    }()
    
    lazy var vectorStore: VectorStoreProtocol = {
        #if !MINIMAL_BUILD && !NO_COREDATA
        // TODO: Replace with proper GRDB DatabaseWriter when implemented
        VectorStore(database: nil)
        #else
        VectorStore(database: nil)
        #endif
    }()
    
    lazy var ragService: RAGServiceProtocol = {
        RAGService(
            llmService: llmService,
            database: nil,
            embeddingService: embeddingService,
            vectorStore: vectorStore,
            chunkingService: TextChunkingService()
        )
    }()
    
    // MARK: - Future Services (Phase 5+)
    // These services will be implemented in later phases:
    // - searchService: SearchServiceProtocol (enhanced semantic search)
    // - exportService: ExportServiceProtocol
    
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
    
    // MARK: - Phase 4 UseCases (temporarily disabled)
    /*
    func makeSubscriptionUseCase() -> SubscriptionUseCaseProtocol {
        return SubscriptionUseCase(
            subscriptionService: subscriptionService,
            apiUsageTracker: apiUsageTracker
        )
    }
    */
    
    // MARK: - Phase 5 UseCases
    func makeProjectAIUseCase() -> ProjectAIUseCaseProtocol {
        return ProjectAIUseCase(
            ragService: ragService,
            llmService: llmService,
            projectRepository: projectRepository,
            recordingRepository: recordingRepository
        )
    }
    
    // MARK: - Future UseCases (Phase 5+)
    // These use cases will be implemented in later phases:
    // - makeExportUseCase() -> ExportUseCaseProtocol
    
    // MARK: - ViewModel Factories
    lazy var recordingViewModel: RecordingViewModel = {
        return RecordingViewModel(
            recordingUseCase: makeRecordingUseCase(),
            transcriptionUseCase: makeTranscriptionUseCase(),
            projectRepository: projectRepository
        )
    }()
    
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
            projectUseCase: makeProjectUseCase(),
            recordingRepository: recordingRepository
        )
    }
    
    // MARK: - Phase 4 ViewModels
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            subscriptionService: subscriptionService,
            apiKeyManager: apiKeyManager,
            usageTracker: apiUsageTracker
        )
    }
    
    // Temporarily disabled ViewModels
    /*
    func makeAPIKeySettingsViewModel() -> APIKeySettingsViewModel {
        return APIKeySettingsViewModel(
            apiKeyManager: apiKeyManager
        )
    }
    
    func makeSubscriptionViewModel() -> SubscriptionViewModel {
        return SubscriptionViewModel(
            subscriptionService: subscriptionService
        )
    }
    */
    
    func makeUsageMonitorViewModel() -> UsageMonitorViewModel {
        return UsageMonitorViewModel(
            usageTracker: apiUsageTracker
        )
    }
    
    // MARK: - Phase 5 ViewModels
    func makeProjectAIViewModel(project: Project) -> ProjectAIViewModel {
        return ProjectAIViewModel(
            project: project,
            projectAIUseCase: makeProjectAIUseCase()
        )
    }
    
    // MARK: - Future ViewModels (Phase 5+)
    // These view models will be implemented in later phases:
    // - makeExportViewModel() -> ExportViewModel
    
    // MARK: - Additional Services (Lazy Initialization)
    private lazy var audioFileManager: AudioFileManagerProtocol = {
        AudioFileManager()
    }()
    
    // MARK: - Configuration and Initialization
    func configure() async throws {
        // Configure API Usage Tracker with database
        try await apiUsageTracker.configure(database: nil) // TODO: Set up GRDB database
        
        // Configure LLM Service
        try await llmService.configure(
            apiKeyManager: apiKeyManager,
            usageTracker: apiUsageTracker
        )
        
        // Configure Subscription Service
        try await subscriptionService.configure(
            apiKey: "your_revenuecat_key", // TODO: Add actual RevenueCat key
            appUserID: nil
        )
        
        // Configure Phase 5 Services
        try await configureRAGServices()
    }
    
    private func configureRAGServices() async throws {
        // Configure Embedding Service
        let embeddingConfig = EmbeddingConfiguration(
            model: .openaiTextEmbedding3Small,
            maxTokens: 8192,
            batchSize: 10,
            timeout: 30.0,
            retryCount: 3,
            enableCaching: true,
            cacheExpiration: 3600,
            preprocessingOptions: PreprocessingOptions(
                normalizeWhitespace: true,
                removeSpecialCharacters: false,
                lowercaseText: false,
                removeStopWords: false,
                stemming: false,
                maxLength: 8192,
                minLength: 1
            )
        )
        
        try await embeddingService.updateConfiguration(embeddingConfig)
        
        // Initialize default embedding model
        try await embeddingService.loadModel(model: .openaiTextEmbedding3Small)
    }
    
    // MARK: - Helper Methods
    // Temporarily disabled GRDB
    /*
    private func createMockDatabaseWriter() -> DatabaseWriter {
        // TODO: Replace with proper GRDB DatabaseWriter implementation
        fatalError("GRDB DatabaseWriter not implemented yet")
    }
    */
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