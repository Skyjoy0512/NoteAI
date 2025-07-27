import SwiftUI
import Combine
import Foundation

@MainActor
class ProjectListViewModel: ViewModelCapable {
    // MARK: - Published Properties
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var showingCreateProject = false
    @Published var showingDeleteConfirmation = false
    @Published var selectedProject: Project?
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - View State
    @Published var sortOption: ProjectSortOption = .newestFirst
    @Published var viewMode: ProjectViewMode = .grid
    
    // MARK: - Dependencies
    private let projectUseCase: ProjectUseCaseProtocol
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init(projectUseCase: ProjectUseCaseProtocol) {
        self.projectUseCase = projectUseCase
        setupSearchBinding()
        loadProjects()
    }
    
    // MARK: - Public Methods
    
    func loadProjects() {
        Task {
            await refreshProjects()
        }
    }
    
    func refreshProjects() async {
        await withLoadingNoReturn {
            let fetchedProjects: [Project]
            
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fetchedProjects = try await projectUseCase.getAllProjects()
            } else {
                fetchedProjects = try await projectUseCase.searchProjects(query: searchText)
            }
            
            projects = sortProjects(fetchedProjects)
        }
    }
    
    func createProject(name: String, description: String?, coverImageData: Data?) async {
        do {
            let newProject = try await projectUseCase.createProject(
                name: name,
                description: description,
                coverImageData: coverImageData
            )
            
            // プロジェクト一覧を再読み込み
            await refreshProjects()
            
            showingCreateProject = false
            
        } catch {
            await handleError(error)
        }
    }
    
    func deleteProject(_ project: Project) async {
        do {
            try await projectUseCase.deleteProject(project.id)
            
            // プロジェクト一覧から削除
            projects.removeAll { $0.id == project.id }
            
            showingDeleteConfirmation = false
            selectedProject = nil
            
        } catch {
            await handleError(error)
        }
    }
    
    func duplicateProject(_ project: Project, newName: String) async {
        do {
            let duplicatedProject = try await projectUseCase.duplicateProject(
                project.id,
                newName: newName
            )
            
            // プロジェクト一覧を再読み込み
            await refreshProjects()
            
        } catch {
            await handleError(error)
        }
    }
    
    func selectProjectForDeletion(_ project: Project) {
        selectedProject = project
        showingDeleteConfirmation = true
    }
    
    func setSortOption(_ option: ProjectSortOption) {
        sortOption = option
        projects = sortProjects(projects)
    }
    
    func setViewMode(_ mode: ProjectViewMode) {
        viewMode = mode
    }
    
    // MARK: - Private Methods
    
    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(Int(AppConfiguration.UI.searchDebounceDelay * 1000)), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshProjects()
                }
            }
            .store(in: &cancellables)
    }
    
    private func sortProjects(_ projects: [Project]) -> [Project] {
        switch sortOption {
        case .newestFirst:
            return projects.sorted { $0.updatedAt > $1.updatedAt }
        case .oldestFirst:
            return projects.sorted { $0.updatedAt < $1.updatedAt }
        case .nameAscending:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }
    
    // handleError\u306f\u30d7\u30ed\u30c8\u30b3\u30eb\u3067\u5b9f\u88c5\u6e08\u307f
    
    // MARK: - Computed Properties
    
    var filteredProjects: [Project] {
        return projects
    }
    
    var hasProjects: Bool {
        !projects.isEmpty
    }
    
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var searchResultsCount: Int {
        projects.count
    }
    
    var sortOptionDisplayName: String {
        switch sortOption {
        case .newestFirst: return "新しい順"
        case .oldestFirst: return "古い順"
        case .nameAscending: return "名前順"
        case .nameDescending: return "名前逆順"
        }
    }
}

// MARK: - Supporting Types

enum ProjectSortOption: String, CaseIterable {
    case newestFirst = "newest"
    case oldestFirst = "oldest"
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    
    var displayName: String {
        switch self {
        case .newestFirst: return "新しい順"
        case .oldestFirst: return "古い順"
        case .nameAscending: return "名前順"
        case .nameDescending: return "名前逆順"
        }
    }
    
    var iconName: String {
        switch self {
        case .newestFirst: return "arrow.down"
        case .oldestFirst: return "arrow.up"
        case .nameAscending: return "textformat.abc"
        case .nameDescending: return "textformat.abc"
        }
    }
}

enum ProjectViewMode: String, CaseIterable {
    case grid = "grid"
    case list = "list"
    
    var displayName: String {
        switch self {
        case .grid: return "グリッド"
        case .list: return "リスト"
        }
    }
    
    var iconName: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}