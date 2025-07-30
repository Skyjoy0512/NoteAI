import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            RecordingView(viewModel: DependencyContainer.shared.recordingViewModel)
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("録音")
                }
            
            ProjectListView(viewModel: DependencyContainer.shared.makeProjectListViewModel())
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("プロジェクト")
                }
            
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("検索")
                }
            
            SettingsView(viewModel: DependencyContainer.shared.makeSettingsViewModel())
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
        }
    }
}

#Preview {
    ContentView()
}