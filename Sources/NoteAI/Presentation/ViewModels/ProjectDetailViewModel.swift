import SwiftUI
import Combine
import Foundation

@MainActor
class ProjectDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var project: Project
    @Published var recordings: [Recording] = []
    @Published var statistics: ProjectStatistics?
    @Published var isLoading = false
    @Published var isLoadingRecordings = false
    @Published var showingEditProject = false
    @Published var showingDeleteConfirmation = false
    @Published var selectedRecording: Recording?
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Edit State
    @Published var editName: String
    @Published var editDescription: String
    @Published var editCoverImageData: Data?
    
    // MARK: - View State
    @Published var recordingSortOption: RecordingSortOption = .newestFirst
    @Published var recordingFilterOption: RecordingFilterOption = .all
    
    // MARK: - Dependencies
    private let projectUseCase: ProjectUseCaseProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(
        project: Project,
        projectUseCase: ProjectUseCaseProtocol,
        recordingRepository: RecordingRepositoryProtocol
    ) {
        self.project = project
        self.projectUseCase = projectUseCase
        self.recordingRepository = recordingRepository
        
        // 編集用プロパティ初期化
        self.editName = project.name
        self.editDescription = project.description ?? ""
        self.editCoverImageData = project.coverImageData
        
        loadProjectData()
    }
    
    // MARK: - Public Methods
    
    func loadProjectData() {
        Task {
            await loadStatistics()
            await loadRecordings()
        }
    }
    
    func refreshProject() async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            // プロジェクト情報を再取得
            if let updatedProject = try await projectUseCase.getProjectById(project.id) {
                project = updatedProject
                editName = project.name
                editDescription = project.description ?? ""
                editCoverImageData = project.coverImageData
            }
            
            await loadStatistics()
            await loadRecordings()
            
        } catch {
            await handleError(error)
        }
        
        isLoading = false
    }
    
    func updateProject() async {
        do {
            let updatedProject = Project(
                id: project.id,
                name: editName,
                description: editDescription.isEmpty ? nil : editDescription,
                coverImageData: editCoverImageData,
                createdAt: project.createdAt,
                updatedAt: Date(),
                metadata: project.metadata
            )
            
            let result = try await projectUseCase.updateProject(updatedProject)
            project = result
            showingEditProject = false
            
            // 統計を再読み込み
            await loadStatistics()
            
        } catch {
            await handleError(error)
        }
    }
    
    func deleteRecording(_ recording: Recording) async {
        do {
            // TODO: RecordingUseCaseを使用して削除処理
            try await recordingRepository.delete(recording.id)
            
            // リストから削除
            recordings.removeAll { $0.id == recording.id }
            
            // 統計を再読み込み
            await loadStatistics()
            
        } catch {
            await handleError(error)
        }
    }
    
    func setSortOption(_ option: RecordingSortOption) {
        recordingSortOption = option
        recordings = sortRecordings(recordings)
    }
    
    func setFilterOption(_ option: RecordingFilterOption) {
        recordingFilterOption = option
        recordings = filterAndSortRecordings(recordings)
    }
    
    func selectRecording(_ recording: Recording) {
        selectedRecording = recording
    }
    
    func resetEditState() {
        editName = project.name
        editDescription = project.description ?? ""
        editCoverImageData = project.coverImageData
    }
    
    func updateCoverImage(_ imageData: Data?) {
        editCoverImageData = imageData
    }
    
    // MARK: - Private Methods
    
    private func loadStatistics() async {
        do {
            let stats = try await projectUseCase.getProjectStatistics(project.id)
            await MainActor.run {
                statistics = stats
            }
        } catch {
            await handleError(error)
        }
    }
    
    private func loadRecordings() async {
        isLoadingRecordings = true
        
        do {
            let fetchedRecordings = try await projectUseCase.getRecordingsForProject(project.id)
            let processedRecordings = filterAndSortRecordings(fetchedRecordings)
            
            await MainActor.run {
                recordings = processedRecordings
            }
            
        } catch {
            await handleError(error)
        }
        
        isLoadingRecordings = false
    }
    
    private func filterAndSortRecordings(_ recordings: [Recording]) -> [Recording] {
        let filteredRecordings = filterRecordings(recordings)
        return sortRecordings(filteredRecordings)
    }
    
    private func filterRecordings(_ recordings: [Recording]) -> [Recording] {
        switch recordingFilterOption {
        case .all:
            return recordings
        case .transcribed:
            return recordings.filter { $0.transcription != nil }
        case .notTranscribed:
            return recordings.filter { $0.transcription == nil }
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            return recordings.filter { $0.createdAt >= today && $0.createdAt < tomorrow }
        case .thisWeek:
            let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            return recordings.filter { $0.createdAt >= weekStart }
        case .thisMonth:
            let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
            return recordings.filter { $0.createdAt >= monthStart }
        }
    }
    
    private func sortRecordings(_ recordings: [Recording]) -> [Recording] {
        switch recordingSortOption {
        case .newestFirst:
            return recordings.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return recordings.sorted { $0.createdAt < $1.createdAt }
        case .longestFirst:
            return recordings.sorted { $0.duration > $1.duration }
        case .shortestFirst:
            return recordings.sorted { $0.duration < $1.duration }
        case .nameAscending:
            return recordings.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .nameDescending:
            return recordings.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            if let noteAIError = error as? NoteAIError {
                errorMessage = noteAIError.userMessage
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
    }
    
    // MARK: - Computed Properties
    
    var hasRecordings: Bool {
        !recordings.isEmpty
    }
    
    var recordingsCount: Int {
        recordings.count
    }
    
    var canSaveChanges: Bool {
        !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (editName != project.name ||
         editDescription != (project.description ?? "") ||
         editCoverImageData != project.coverImageData)
    }
    
    var totalDurationFormatted: String {
        guard let stats = statistics else { return "0s" }
        return stats.formattedTotalDuration
    }
    
    var averageDurationFormatted: String {
        guard let stats = statistics else { return "0s" }
        return stats.formattedAverageDuration
    }
    
    var transcriptionPercentage: String {
        guard let stats = statistics else { return "0%" }
        return stats.transcriptionPercentage
    }
    
    var activityPeriod: String {
        guard let stats = statistics else { return "未記録" }
        return stats.activityPeriod ?? "未記録"
    }
    
    var projectAge: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: project.createdAt, to: Date())
        
        if let days = components.day {
            if days == 0 {
                return "今日作成"
            } else if days == 1 {
                return "1日前に作成"
            } else {
                return "\(days)日前に作成"
            }
        }
        
        return "作成日不明"
    }
}

// MARK: - Supporting Types

enum RecordingSortOption: String, CaseIterable {
    case newestFirst = "newest"
    case oldestFirst = "oldest"
    case longestFirst = "longest"
    case shortestFirst = "shortest"
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    
    var displayName: String {
        switch self {
        case .newestFirst: return "新しい順"
        case .oldestFirst: return "古い順"
        case .longestFirst: return "長い順"
        case .shortestFirst: return "短い順"
        case .nameAscending: return "名前順"
        case .nameDescending: return "名前逆順"
        }
    }
    
    var iconName: String {
        switch self {
        case .newestFirst: return "arrow.down"
        case .oldestFirst: return "arrow.up"
        case .longestFirst: return "arrow.down.right"
        case .shortestFirst: return "arrow.up.right"
        case .nameAscending: return "textformat.abc"
        case .nameDescending: return "textformat.abc"
        }
    }
}

enum RecordingFilterOption: String, CaseIterable {
    case all = "all"
    case transcribed = "transcribed"
    case notTranscribed = "not_transcribed"
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    
    var displayName: String {
        switch self {
        case .all: return "すべて"
        case .transcribed: return "文字起こし済み"
        case .notTranscribed: return "未文字起こし"
        case .today: return "今日"
        case .thisWeek: return "今週"
        case .thisMonth: return "今月"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .transcribed: return "text.badge.checkmark"
        case .notTranscribed: return "text.badge.xmark"
        case .today: return "calendar"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar.badge.exclamationmark"
        }
    }
}