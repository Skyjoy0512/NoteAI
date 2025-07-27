import SwiftUI

struct ProjectListView: View {
    @StateObject private var viewModel: ProjectListViewModel
    @State private var showingCreateProject = false
    @State private var showingSortOptions = false
    
    init(viewModel: ProjectListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
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
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    sortButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .background(Color(.systemGray6))
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private var coverImageView: some View {
        if let imageData = project.coverImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 80)
                .clipped()
                .cornerRadius(8)
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 80)
                .cornerRadius(8)
                .overlay {
                    Image(systemName: "folder")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
        }
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
    
    @ViewBuilder
    private var coverImageView: some View {
        if let imageData = project.coverImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(8)
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .overlay {
                    Image(systemName: "folder")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
        }
    }
}

// MARK: - Project Extension for Display

extension Project {
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(createdAt) {
            formatter.timeStyle = .short
            return "今日 \(formatter.string(from: createdAt))"
        } else if calendar.isDateInYesterday(createdAt) {
            formatter.timeStyle = .short
            return "昨日 \(formatter.string(from: createdAt))"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: createdAt)
        }
    }
}