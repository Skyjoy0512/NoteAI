import SwiftUI

struct ProjectListView: View {
    @StateObject private var viewModel = DependencyContainer.shared.makeProjectListViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("プロジェクト管理")
                    .font(.title)
                
                // TODO: プロジェクト一覧UI実装
                Button("新規プロジェクト") {
                    // TODO: プロジェクト作成処理
                }
                .buttonStyle(.borderedProminent)
                
                Text("Phase 3で詳細実装予定")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("プロジェクト")
        }
    }
}

#Preview {
    ProjectListView()
}