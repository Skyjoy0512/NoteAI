import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = DependencyContainer.shared.makeSettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("機能") {
                    NavigationLink("録音設定") {
                        Text("Phase 2で実装予定")
                    }
                    
                    NavigationLink("API設定") {
                        Text("Phase 4で実装予定")
                    }
                    
                    NavigationLink("課金管理") {
                        Text("Phase 4で実装予定")
                    }
                }
                
                Section("サポート") {
                    Link("ヘルプ", destination: URL(string: "https://noteai.app/help")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://noteai.app/privacy")!)
                }
            }
            .navigationTitle("設定")
        }
    }
}

#Preview {
    SettingsView()
}