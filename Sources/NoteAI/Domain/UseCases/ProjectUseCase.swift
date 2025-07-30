import Foundation

protocol ProjectUseCaseProtocol {
    func createProject(name: String, description: String?, coverImageData: Data?) async throws -> Project
    func updateProject(_ project: Project) async throws -> Project
    func deleteProject(_ projectId: UUID) async throws
    func getAllProjects() async throws -> [Project]
    func getProjectById(_ id: UUID) async throws -> Project?
    func searchProjects(query: String) async throws -> [Project]
    func getProjectStatistics(_ projectId: UUID) async throws -> ProjectStatistics
    func getRecordingsForProject(_ projectId: UUID) async throws -> [Recording]
    func duplicateProject(_ projectId: UUID, newName: String) async throws -> Project
}

class ProjectUseCase: ProjectUseCaseProtocol {
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    
    init(
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol
    ) {
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
    }
    
    func createProject(name: String, description: String?, coverImageData: Data?) async throws -> Project {
        // バリデーション
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectUseCaseError.invalidProjectName("プロジェクト名を入力してください")
        }
        
        guard name.count <= 100 else {
            throw ProjectUseCaseError.invalidProjectName("プロジェクト名は100文字以内で入力してください")
        }
        
        if let description = description, description.count > 500 {
            throw ProjectUseCaseError.invalidDescription("説明は500文字以内で入力してください")
        }
        
        // プロジェクト作成
        let project = Project(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageData: coverImageData,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: ProjectMetadata()
        )
        
        try await projectRepository.save(project)
        return project
    }
    
    func updateProject(_ project: Project) async throws -> Project {
        // バリデーション
        guard !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectUseCaseError.invalidProjectName("プロジェクト名を入力してください")
        }
        
        guard project.name.count <= 100 else {
            throw ProjectUseCaseError.invalidProjectName("プロジェクト名は100文字以内で入力してください")
        }
        
        if let description = project.description, description.count > 500 {
            throw ProjectUseCaseError.invalidDescription("説明は500文字以内で入力してください")
        }
        
        // 既存プロジェクトの確認
        guard try await projectRepository.findById(project.id) != nil else {
            throw ProjectUseCaseError.projectNotFound(project.id)
        }
        
        // 更新日時を設定
        let updatedProject = Project(
            id: project.id,
            name: project.name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: project.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageData: project.coverImageData,
            createdAt: project.createdAt,
            updatedAt: Date(),
            metadata: project.metadata
        )
        
        try await projectRepository.save(updatedProject)
        return updatedProject
    }
    
    func deleteProject(_ projectId: UUID) async throws {
        // プロジェクトの存在確認
        guard try await projectRepository.findById(projectId) != nil else {
            throw ProjectUseCaseError.projectNotFound(projectId)
        }
        
        // 関連する録音データの確認
        let recordings = try await recordingRepository.findByProjectId(projectId)
        
        if !recordings.isEmpty {
            // 録音データがある場合の警告
            throw ProjectUseCaseError.projectHasRecordings(projectId, recordings.count)
        }
        
        try await projectRepository.delete(projectId)
    }
    
    func getAllProjects() async throws -> [Project] {
        return try await projectRepository.findAll()
    }
    
    func getProjectById(_ id: UUID) async throws -> Project? {
        return try await projectRepository.findById(id)
    }
    
    func searchProjects(query: String) async throws -> [Project] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try await getAllProjects()
        }
        
        return try await projectRepository.search(query: query)
    }
    
    func getProjectStatistics(_ projectId: UUID) async throws -> ProjectStatistics {
        // プロジェクトの存在確認
        guard let project = try await projectRepository.findById(projectId) else {
            throw ProjectUseCaseError.projectNotFound(projectId)
        }
        
        // 録音データ取得
        let recordings = try await recordingRepository.findByProjectId(projectId)
        
        // 統計計算
        let totalRecordings = recordings.count
        let totalDuration = recordings.reduce(0) { $0 + $1.duration }
        let transcribedCount = recordings.filter { $0.transcription != nil }.count
        let averageDuration = totalRecordings > 0 ? totalDuration / Double(totalRecordings) : 0
        
        // 最新・最古の録音日時
        let recordingDates = recordings.map { $0.createdAt }
        let oldestRecording = recordingDates.min()
        let newestRecording = recordingDates.max()
        
        // 言語別統計
        let languageStats = Dictionary(grouping: recordings, by: { $0.language })
            .mapValues { $0.count }
        
        // 文字起こし方法別統計
        let methodStats = Dictionary(grouping: recordings, by: { $0.transcriptionMethod })
            .mapValues { $0.count }
        
        return ProjectStatistics(
            project: project,
            totalRecordings: totalRecordings,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            transcribedCount: transcribedCount,
            transcriptionRate: totalRecordings > 0 ? Double(transcribedCount) / Double(totalRecordings) : 0,
            oldestRecording: oldestRecording,
            newestRecording: newestRecording,
            languageStatistics: languageStats,
            methodStatistics: methodStats,
            createdAt: Date()
        )
    }
    
    func getRecordingsForProject(_ projectId: UUID) async throws -> [Recording] {
        // プロジェクトの存在確認
        guard try await projectRepository.findById(projectId) != nil else {
            throw ProjectUseCaseError.projectNotFound(projectId)
        }
        
        return try await recordingRepository.findByProjectId(projectId)
    }
    
    func duplicateProject(_ projectId: UUID, newName: String) async throws -> Project {
        // 元プロジェクトの取得
        guard let originalProject = try await projectRepository.findById(projectId) else {
            throw ProjectUseCaseError.projectNotFound(projectId)
        }
        
        // 名前のバリデーション
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectUseCaseError.invalidProjectName("プロジェクト名を入力してください")
        }
        
        // 複製プロジェクト作成
        let duplicatedProject = Project(
            id: UUID(),
            name: newName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: originalProject.description.map { "\($0) (複製)" },
            coverImageData: originalProject.coverImageData,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: originalProject.metadata
        )
        
        try await projectRepository.save(duplicatedProject)
        return duplicatedProject
    }
}

// MARK: - Supporting Types

struct ProjectStatistics {
    let project: Project
    let totalRecordings: Int
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let transcribedCount: Int
    let transcriptionRate: Double // 0.0 - 1.0
    let oldestRecording: Date?
    let newestRecording: Date?
    let languageStatistics: [String: Int]
    let methodStatistics: [TranscriptionMethod: Int]
    let createdAt: Date
    
    var formattedTotalDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalDuration) ?? "0s"
    }
    
    var formattedAverageDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: averageDuration) ?? "0s"
    }
    
    var transcriptionPercentage: String {
        let percentage = Int(transcriptionRate * 100)
        return "\(percentage)%"
    }
    
    var activityPeriod: String? {
        guard let oldest = oldestRecording,
              let newest = newestRecording else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if Calendar.current.isDate(oldest, inSameDayAs: newest) {
            return formatter.string(from: oldest)
        } else {
            return "\(formatter.string(from: oldest)) 〜 \(formatter.string(from: newest))"
        }
    }
}

enum ProjectUseCaseError: NoteAIError {
    case invalidProjectName(String)
    case invalidDescription(String)
    case projectNotFound(UUID)
    case projectHasRecordings(UUID, Int)
    case duplicateProjectName(String)
    case operationFailed(Error)
    
    var errorCode: String {
        switch self {
        case .invalidProjectName: return "PROJECT_INVALID_NAME"
        case .invalidDescription: return "PROJECT_INVALID_DESC"
        case .projectNotFound: return "PROJECT_NOT_FOUND"
        case .projectHasRecordings: return "PROJECT_HAS_RECORDINGS"
        case .duplicateProjectName: return "PROJECT_DUPLICATE_NAME"
        case .operationFailed: return "PROJECT_OPERATION_FAILED"
        }
    }
    
    var userMessage: String {
        switch self {
        case .invalidProjectName(let message):
            return message
        case .invalidDescription(let message):
            return message
        case .projectNotFound:
            return "プロジェクトが見つかりません"
        case .projectHasRecordings(_, let count):
            return "このプロジェクトには\(count)件の録音があります。削除するには先に録音を削除してください。"
        case .duplicateProjectName(let name):
            return "プロジェクト名'\(name)'は既に使用されています"
        case .operationFailed:
            return "操作に失敗しました"
        }
    }
    
    var debugInfo: String? {
        switch self {
        case .invalidProjectName(let message),
             .invalidDescription(let message),
             .duplicateProjectName(let message):
            return message
        case .projectNotFound(let id):
            return "Project ID: \(id)"
        case .projectHasRecordings(let id, let count):
            return "Project ID: \(id), Recording count: \(count)"
        case .operationFailed(let error):
            return error.localizedDescription
        }
    }
}