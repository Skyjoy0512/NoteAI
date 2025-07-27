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
            subscriptionService: subscriptionService
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

// MARK: - Protocol Definitions (Placeholders)
protocol AudioServiceProtocol {}
protocol WhisperKitServiceProtocol {}
protocol APIKeyManagerProtocol {}
protocol APIUsageTrackerProtocol {}
protocol LLMServiceProtocol {}
protocol SubscriptionServiceProtocol {}
protocol SearchServiceProtocol {}
protocol AudioFileManagerProtocol {}
protocol APITranscriptionServiceProtocol {}
protocol RAGServiceProtocol {}

// MARK: - UseCase Protocol Definitions (Placeholders)
protocol RecordingUseCaseProtocol {}
protocol TranscriptionUseCaseProtocol {}
protocol ProjectUseCaseProtocol {}
protocol ProjectAIUseCaseProtocol {}
protocol SubscriptionUseCaseProtocol {}

// MARK: - Service Implementations (Placeholders)
class AudioService: AudioServiceProtocol {}
class WhisperKitService: WhisperKitServiceProtocol {}
class APIKeyManager: APIKeyManagerProtocol {}
class APIUsageTracker: APIUsageTrackerProtocol {
    init(repository: APIUsageRepositoryProtocol, notificationCenter: NotificationCenter) {}
}
class LLMService: LLMServiceProtocol {
    init(apiKeyManager: APIKeyManagerProtocol, usageTracker: APIUsageTrackerProtocol) {}
}
class SubscriptionService: SubscriptionServiceProtocol {
    init(repository: SubscriptionRepositoryProtocol) {}
}
class SearchService: SearchServiceProtocol {}
class AudioFileManager: AudioFileManagerProtocol {}
class APITranscriptionService: APITranscriptionServiceProtocol {
    init(apiKeyManager: APIKeyManagerProtocol, usageTracker: APIUsageTrackerProtocol) {}
}
class RAGService: RAGServiceProtocol {
    init(searchService: SearchServiceProtocol) {}
}

// MARK: - UseCase Implementations (Placeholders)
class RecordingUseCase: RecordingUseCaseProtocol {
    init(audioService: AudioServiceProtocol, recordingRepository: RecordingRepositoryProtocol, fileManager: AudioFileManagerProtocol) {}
}
class TranscriptionUseCase: TranscriptionUseCaseProtocol {
    init(whisperKitService: WhisperKitServiceProtocol, apiTranscriptionService: APITranscriptionServiceProtocol, subscriptionService: SubscriptionServiceProtocol) {}
}
class ProjectUseCase: ProjectUseCaseProtocol {
    init(projectRepository: ProjectRepositoryProtocol, recordingRepository: RecordingRepositoryProtocol) {}
}
class ProjectAIUseCase: ProjectAIUseCaseProtocol {
    init(projectRepository: ProjectRepositoryProtocol, llmService: LLMServiceProtocol, ragService: RAGServiceProtocol, subscriptionService: SubscriptionServiceProtocol) {}
}
class SubscriptionUseCase: SubscriptionUseCaseProtocol {
    init(subscriptionService: SubscriptionServiceProtocol, subscriptionRepository: SubscriptionRepositoryProtocol) {}
}

// MARK: - Repository Implementations (Placeholders)
class ProjectRepository: ProjectRepositoryProtocol {
    init(coreDataStack: CoreDataStack) {}
    func save(_ project: Project) async throws {}
    func findById(_ id: UUID) async throws -> Project? { return nil }
    func findAll() async throws -> [Project] { return [] }
    func delete(_ id: UUID) async throws {}
    func findByIds(_ ids: [UUID]) async throws -> [Project] { return [] }
    func search(query: String) async throws -> [Project] { return [] }
}

class RecordingRepository: RecordingRepositoryProtocol {
    init(coreDataStack: CoreDataStack) {}
    func save(_ recording: Recording) async throws {}
    func findById(_ id: UUID) async throws -> Recording? { return nil }
    func findByProjectId(_ projectId: UUID) async throws -> [Recording] { return [] }
    func findAll() async throws -> [Recording] { return [] }
    func delete(_ id: UUID) async throws {}
    func search(query: String) async throws -> [Recording] { return [] }
    func findRecent(limit: Int) async throws -> [Recording] { return [] }
}

class SubscriptionRepository: SubscriptionRepositoryProtocol {
    init(coreDataStack: CoreDataStack) {}
    func save(_ subscription: Subscription) async throws {}
    func findCurrent() async throws -> Subscription? { return nil }
    func findAll() async throws -> [Subscription] { return [] }
}

class APIUsageRepository: APIUsageRepositoryProtocol {
    init(coreDataStack: CoreDataStack) {}
    func save(_ usage: APIUsage) async throws {}
    func findUsages(provider: LLMProvider, from: Date, to: Date) async throws -> [APIUsage] { return [] }
    func getMonthlyUsage(provider: LLMProvider, month: String) async throws -> [APIUsage] { return [] }
    func getTotalMonthlyCost(month: String) async throws -> Double { return 0 }
}

// MARK: - ViewModel Implementations (Placeholders)
class RecordingViewModel: ObservableObject {
    init(recordingUseCase: RecordingUseCaseProtocol, transcriptionUseCase: TranscriptionUseCaseProtocol, projectRepository: ProjectRepositoryProtocol) {}
}

class ProjectListViewModel: ObservableObject {
    init(projectUseCase: ProjectUseCaseProtocol) {}
}

class ProjectDetailViewModel: ObservableObject {
    init(project: Project, projectRepository: ProjectRepositoryProtocol, recordingRepository: RecordingRepositoryProtocol, projectAIUseCase: ProjectAIUseCaseProtocol) {}
}

class SettingsViewModel: ObservableObject {
    init(subscriptionUseCase: SubscriptionUseCaseProtocol, apiKeyManager: APIKeyManagerProtocol, apiUsageTracker: APIUsageTrackerProtocol) {}
}