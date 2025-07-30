import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                SearchBar(text: $searchText)
                
                Text("検索機能")
                    .font(.title)
                
                Text("Phase 3で詳細実装予定")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("検索")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("録音内容を検索...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

#Preview {
    SearchView()
}