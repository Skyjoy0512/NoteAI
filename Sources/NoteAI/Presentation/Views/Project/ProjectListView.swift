import SwiftUI

struct ProjectListView: View {
    @StateObject private var viewModel: ProjectListViewModel
    @State private var showingCreateProject = false
    @State private var showingSortOptions = false
    
    init(viewModel: ProjectListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Computed Properties
    
    private var leadingPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .navigationBarLeading
        #else
        return .secondaryAction
        #endif
    }
    
    private var trailingPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("プロジェクトを読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasProjects {
                    projectContentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("プロジェクト")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: leadingPlacement) {
                    sortButton
                }
                
                ToolbarItem(placement: trailingPlacement) {
                    HStack {
                        viewModeToggle
                        createProjectButton
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "プロジェクトを検索")
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView { name, description, coverImageData in
                Task {
                    await viewModel.createProject(
                        name: name,
                        description: description,
                        coverImageData: coverImageData
                    )
                }
            }
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .refreshable {
            await viewModel.refreshProjects()
        }
    }
    
    // MARK: - Project Content View
    
    @ViewBuilder
    private var projectContentView: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                searchResultsHeader
            }
            
            if viewModel.viewMode == .grid {
                projectGridView
            } else {
                projectListView
            }
        }
    }
    
    // MARK: - Search Results Header
    
    private var searchResultsHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            Text("\(viewModel.searchResultsCount)件のプロジェクトが見つかりました")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Grid View
    
    private var projectGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(viewModel.projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        projectContextMenu(for: project)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - List View
    
    private var projectListView: some View {
        List {
            ForEach(viewModel.projects) { project in
                NavigationLink(destination: ProjectDetailView(project: project)) {
                    ProjectRow(project: project)
                }
                .contextMenu {
                    projectContextMenu(for: project)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("プロジェクトがありません")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("録音を整理するために\n新しいプロジェクトを作成しましょう")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingCreateProject = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("新しいプロジェクト")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Items
    
    private var sortButton: some View {
        Button {
            showingSortOptions = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.sortOption.iconName)
                Text(viewModel.sortOptionDisplayName)
                    .font(.caption)
            }
        }
        .confirmationDialog("並び順", isPresented: $showingSortOptions) {
            ForEach(ProjectSortOption.allCases, id: \.self) { option in
                Button(option.displayName) {
                    viewModel.setSortOption(option)
                }
            }
        }
    }
    
    private var viewModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.setViewMode(viewModel.viewMode == .grid ? .list : .grid)
            }
        } label: {
            Image(systemName: viewModel.viewMode == .grid ? "list.bullet" : "square.grid.2x2")
        }
    }
    
    private var createProjectButton: some View {
        Button {
            showingCreateProject = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func projectContextMenu(for project: Project) -> some View {
        Button {
            // TODO: 編集機能実装
        } label: {
            Label("編集", systemImage: "pencil")
        }
        
        Button {
            Task {
                await viewModel.duplicateProject(project, newName: "\(project.name) のコピー")
            }
        } label: {
            Label("複製", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            viewModel.selectProjectForDeletion(project)
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}

// MARK: - Project Card Component

struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // カバー画像
            coverImageView
            
            // プロジェクト情報
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(project.formattedCreatedAt)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var coverImageView: some View {
        CoverImageView.cardSize(imageData: project.coverImageData)
    }
}

// MARK: - Project Row Component

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 12) {
            // カバー画像
            coverImageView
            
            // プロジェクト情報
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(project.formattedCreatedAt)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var coverImageView: some View {
        CoverImageView.rowSize(imageData: project.coverImageData)
    }
}

// MARK: - Project Detail View (Placeholder)

struct ProjectDetailView: View {
    let project: Project
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(project.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("作成日: \(project.formattedCreatedAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("更新日: \(DateFormattingService.shared.formatCreatedAt(project.updatedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Cover Image
                if project.coverImageData != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カバー画像")
                            .font(.headline)
                        
                        CoverImageView.detailSize(imageData: project.coverImageData)
                    }
                }
                
                // Project Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("アクション")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ProjectActionButton(title: "録音を開始", systemImage: "mic.fill", color: .red) {
                            // TODO: Start recording
                        }
                        
                        ProjectActionButton(title: "録音を管理", systemImage: "waveform", color: .blue) {
                            // TODO: Manage recordings
                        }
                        
                        ProjectActionButton(title: "AI分析", systemImage: "brain.head.profile", color: .purple) {
                            // TODO: AI Analysis
                        }
                        
                        ProjectActionButton(title: "エクスポート", systemImage: "square.and.arrow.up", color: .green) {
                            // TODO: Export project
                        }
                    }
                }
                
                // Project Statistics (Placeholder)
                VStack(alignment: .leading, spacing: 12) {
                    Text("統計")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        StatisticCard(title: "録音数", value: "0", systemImage: "waveform")
                        StatisticCard(title: "総時間", value: "0:00", systemImage: "clock")
                        StatisticCard(title: "AI分析", value: "0", systemImage: "brain.head.profile")
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationTitle(project.name)
        #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ProjectActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - CoverImageView Extensions

extension CoverImageView {
    static func detailSize(imageData: Data?) -> some View {
        CoverImageView(imageData: imageData, size: CGSize(width: 200, height: 200))
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
    }
}

// MARK: - Project Extension for Display

extension Project {
    var formattedCreatedAt: String {
        DateFormattingService.shared.formatCreatedAt(createdAt)
    }
}