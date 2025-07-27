import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = DependencyContainer.shared.makeRecordingViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("録音機能")
                    .font(.title)
                
                // TODO: 録音UI実装
                Button("録音開始") {
                    // TODO: 録音開始処理
                }
                .buttonStyle(.borderedProminent)
                
                Text("Phase 2で詳細実装予定")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("録音")
        }
    }
}

#Preview {
    RecordingView()
}