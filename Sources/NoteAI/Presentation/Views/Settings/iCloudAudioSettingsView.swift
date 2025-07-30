import SwiftUI
import CloudKit
#if os(iOS)
import UIKit
#endif

// MARK: - iCloud音声ファイル設定画面

struct iCloudAudioSettingsView: View {
    
    @StateObject private var iCloudManager = iCloudAudioManager.shared
    @State private var showingCloudFilesList = false
    @State private var showingStorageDetails = false
    @State private var cloudStorageUsage: CloudStorageUsage?
    @State private var isLoadingUsage = false
    @State private var showingEnableAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // iCloud状態セクション
                iCloudStatusSection
                
                // 同期設定セクション
                if iCloudManager.isEnabled {
                    syncSettingsSection
                }
                
                // ストレージ使用量セクション
                storageUsageSection
                
                // ファイル管理セクション
                if iCloudManager.isEnabled {
                    fileManagementSection
                }
                
                // 詳細設定セクション
                if iCloudManager.isEnabled {
                    advancedSettingsSection
                }
                
                // ヘルプセクション
                helpSection
            }
            .navigationTitle("iCloud音声同期")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                loadStorageUsage()
            }
            .alert("iCloud同期を有効にしますか？", isPresented: $showingEnableAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("有効にする") {
                    enableiCloudSync()
                }
            } message: {
                Text("音声ファイルがiCloud Driveに同期され、すべてのデバイスからアクセスできるようになります。")
            }
            .alert("エラー", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingCloudFilesList) {
                iCloudFilesListView()
            }
            .sheet(isPresented: $showingStorageDetails) {
                iCloudStorageDetailsView(usage: cloudStorageUsage)
            }
        }
    }
    
    // MARK: - iCloud Status Section
    
    private var iCloudStatusSection: some View {
        Section {
            HStack {
                iCloudStatusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud状態")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(iCloudStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if iCloudManager.isAvailable {
                    Toggle("", isOn: $iCloudManager.isEnabled)
                        .labelsHidden()
                        .onChange(of: iCloudManager.isEnabled) { oldValue, newValue in
                            if newValue && !iCloudManager.isEnabled {
                                showingEnableAlert = true
                            } else if !newValue && iCloudManager.isEnabled {
                                disableiCloudSync()
                            }
                        }
                } else {
                    Button("設定") {
                        openSystemSettings()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if iCloudManager.syncStatus != .idle {
                syncProgressView
            }
        } header: {
            Text("iCloud Drive連携")
        } footer: {
            if !iCloudManager.isAvailable {
                Text("iCloudを使用するには、デバイスの設定でiCloud Driveを有効にしてください。")
            } else if iCloudManager.isEnabled {
                Text("音声ファイルがiCloud Driveの「NoteAI」フォルダに保存され、すべてのデバイスから利用できます。")
            }
        }
    }
    
    private var iCloudStatusIcon: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.title2)
    }
    
    private var iconName: String {
        switch iCloudManager.accountStatus {
        case .available:
            return iCloudManager.isEnabled ? "icloud.fill" : "icloud"
        case .noAccount:
            return "person.crop.circle.badge.xmark"
        case .restricted:
            return "exclamationmark.icloud"
        case .couldNotDetermine, .temporarilyUnavailable:
            return "icloud.slash"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch iCloudManager.accountStatus {
        case .available:
            return iCloudManager.isEnabled ? .blue : .gray
        case .noAccount, .restricted:
            return .orange
        case .couldNotDetermine, .temporarilyUnavailable:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    private var iCloudStatusDescription: String {
        if let usage = cloudStorageUsage {
            return usage.statusDescription
        }
        
        switch iCloudManager.accountStatus {
        case .available:
            return iCloudManager.isEnabled ? "同期中" : "利用可能"
        case .noAccount:
            return "iCloudアカウントが設定されていません"
        case .restricted:
            return "iCloudの使用が制限されています"
        case .couldNotDetermine:
            return "iCloudの状態を確認できません"
        case .temporarilyUnavailable:
            return "iCloudが一時的に利用できません"
        @unknown default:
            return "状態不明"
        }
    }
    
    private var syncProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text(iCloudManager.syncStatus.displayName)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
            }
            
            if !iCloudManager.uploadProgress.isEmpty || !iCloudManager.downloadProgress.isEmpty {
                ProgressView(value: calculateOverallProgress())
                    .tint(.blue)
            }
        }
    }
    
    // MARK: - Sync Settings Section
    
    private var syncSettingsSection: some View {
        Section("同期設定") {
            Picker("同期方法", selection: $iCloudManager.syncStrategy) {
                ForEach(iCloudAudioManager.SyncStrategy.allCases, id: \.self) { strategy in
                    VStack(alignment: .leading) {
                        Text(strategy.displayName)
                        Text(strategy.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(strategy)
                }
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #else
            .pickerStyle(.menu)
            #endif
            
            Button("今すぐ同期") {
                performManualSync()
            }
            .disabled(iCloudManager.syncStatus != .idle)
        }
    }
    
    // MARK: - Storage Usage Section
    
    private var storageUsageSection: some View {
        Section("ストレージ使用量") {
            if isLoadingUsage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("計算中...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let usage = cloudStorageUsage {
                storageUsageView(usage)
            } else {
                Button("使用量を確認") {
                    loadStorageUsage()
                }
            }
        }
    }
    
    private func storageUsageView(_ usage: CloudStorageUsage) -> some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud使用量")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(usage.fileCount)ファイル")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(usage.formattedSize)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button("詳細") {
                        showingStorageDetails = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Button("使用量を更新") {
                loadStorageUsage()
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - File Management Section
    
    private var fileManagementSection: some View {
        Section("ファイル管理") {
            NavigationLink("iCloudファイル一覧") {
                iCloudFilesListView()
            }
            
            Button("ローカルファイルをアップロード") {
                uploadLocalFiles()
            }
            .foregroundColor(.blue)
            
            Button("iCloudから再ダウンロード") {
                redownloadAllFiles()
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Advanced Settings Section
    
    private var advancedSettingsSection: some View {
        Section("詳細設定") {
            NavigationLink("同期の詳細設定") {
                AdvancediCloudSyncSettingsView()
            }
            
            Button("すべてのiCloudファイルを削除") {
                // 確認ダイアログを表示
            }
            .foregroundColor(.red)
            
            Button("同期設定をリセット") {
                resetSyncSettings()
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        Section("ヘルプ") {
            NavigationLink("iCloud同期について") {
                iCloudHelpView()
            }
            
            NavigationLink("トラブルシューティング") {
                iCloudTroubleshootingView()
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("データの安全性")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("音声ファイルはAppleのiCloudに暗号化されて保存されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStorageUsage() {
        guard iCloudManager.isEnabled && iCloudManager.isAvailable else { return }
        
        isLoadingUsage = true
        
        Task {
            do {
                let usage = try await iCloudManager.getCloudStorageUsage()
                
                await MainActor.run {
                    self.cloudStorageUsage = usage
                    self.isLoadingUsage = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingUsage = false
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func enableiCloudSync() {
        Task {
            do {
                try await iCloudManager.enable()
                loadStorageUsage()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                    self.iCloudManager.isEnabled = false
                }
            }
        }
    }
    
    private func disableiCloudSync() {
        Task {
            await iCloudManager.disable()
        }
    }
    
    private func performManualSync() {
        Task {
            do {
                try await iCloudManager.syncAllFiles()
                loadStorageUsage()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func uploadLocalFiles() {
        // 実装: ローカルファイル選択UI
    }
    
    private func redownloadAllFiles() {
        // 実装: 全ファイル再ダウンロード
    }
    
    private func resetSyncSettings() {
        // 実装: 設定リセット
    }
    
    private func openSystemSettings() {
        #if os(iOS)
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
        #endif
    }
    
    private func calculateOverallProgress() -> Double {
        let uploadProgress = Array(iCloudManager.uploadProgress.values)
        let downloadProgress = Array(iCloudManager.downloadProgress.values)
        let allProgress = uploadProgress + downloadProgress
        guard !allProgress.isEmpty else { return 0.0 }
        
        return allProgress.reduce(0, +) / Double(allProgress.count)
    }
}

// MARK: - iCloud Files List View

struct iCloudFilesListView: View {
    @StateObject private var iCloudManager = iCloudAudioManager.shared
    @State private var iCloudFiles: [iCloudAudioFile] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("ファイル一覧を読み込み中...")
                } else if iCloudFiles.isEmpty {
                    emptyStateView
                } else {
                    filesListView
                }
            }
            .navigationTitle("iCloudファイル")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("更新") {
                        loadFiles()
                    }
                }
            }
            .onAppear {
                loadFiles()
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("iCloudファイルなし")
                .font(.headline)
            
            Text("まだiCloudに音声ファイルが同期されていません")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("ローカルファイルを同期") {
                syncLocalFiles()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var filesListView: some View {
        List {
            ForEach(iCloudFiles, id: \.fileName) { file in
                iCloudFileRow(file: file)
            }
        }
    }
    
    private func iCloudFileRow(file: iCloudAudioFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    downloadStatusBadge(file)
                    
                    Text(relativeDateString(file.modificationDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !file.isDownloaded {
                Button("ダウンロード") {
                    downloadFile(file)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func downloadStatusBadge(_ file: iCloudAudioFile) -> some View {
        Text(file.downloadStatusDescription)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor(file).opacity(0.2))
            .foregroundColor(badgeColor(file))
            .cornerRadius(4)
    }
    
    private func badgeColor(_ file: iCloudAudioFile) -> Color {
        if file.isDownloaded {
            return .green
        } else {
            return .orange
        }
    }
    
    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadFiles() {
        isLoading = true
        
        Task {
            do {
                let files = try await iCloudManager.getiCloudFileList()
                
                await MainActor.run {
                    self.iCloudFiles = files
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func downloadFile(_ file: iCloudAudioFile) {
        Task {
            do {
                try await iCloudManager.downloadFromiCloudIfNeeded(file)
                loadFiles() // リストを更新
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func syncLocalFiles() {
        Task {
            do {
                try await iCloudManager.syncAllFiles()
                loadFiles()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct iCloudStorageDetailsView: View {
    let usage: CloudStorageUsage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if let usage = usage {
                    storageDetailsContent(usage)
                } else {
                    Text("ストレージ情報なし")
                }
            }
            .navigationTitle("ストレージ詳細")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func storageDetailsContent(_ usage: CloudStorageUsage) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(usage.formattedSize)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("iCloud使用量")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(title: "ファイル数", value: "\(usage.fileCount)個")
                DetailRow(title: "平均ファイルサイズ", value: usage.fileCount > 0 ? ByteCountFormatter().string(fromByteCount: usage.totalSize / Int64(usage.fileCount)) : "0 bytes")
                DetailRow(title: "アカウント状態", value: usage.statusDescription)
                DetailRow(title: "同期状態", value: usage.isEnabled ? "有効" : "無効")
            }
            .padding()
            #if os(iOS)
            .background(Color(.systemGray6))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}

struct AdvancediCloudSyncSettingsView: View {
    var body: some View {
        Form {
            Section("同期オプション") {
                Toggle("バックグラウンド同期", isOn: .constant(true))
                Toggle("低電力モード時は同期停止", isOn: .constant(true))
                Toggle("モバイルデータ使用を制限", isOn: .constant(false))
            }
            
            Section("競合解決") {
                Picker("ファイル競合時の処理", selection: .constant(0)) {
                    Text("新しいファイルを優先").tag(0)
                    Text("ローカルファイルを優先").tag(1)
                    Text("手動で選択").tag(2)
                }
            }
        }
        .navigationTitle("詳細設定")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct iCloudHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                helpSection(
                    title: "iCloud同期とは",
                    content: "iCloud同期を有効にすると、音声ファイルがAppleのiCloud Driveに自動で保存され、iPhone、iPad、Macなど、すべてのデバイスからアクセスできるようになります。"
                )
                
                helpSection(
                    title: "プライバシーとセキュリティ",
                    content: "音声ファイルはAppleのiCloudに暗号化されて保存されます。Appleのプライバシーポリシーに従って管理され、開発者がファイルにアクセスすることはありません。"
                )
                
                helpSection(
                    title: "ストレージ容量",
                    content: "iCloud同期を使用すると、Appleから提供されているiCloudストレージ容量を消費します。無料プランでは5GBまで、有料プランではより多くの容量を利用できます。"
                )
                
                helpSection(
                    title: "同期方法",
                    content: "手動同期、自動同期、WiFi時のみ、重要なファイルのみなど、様々な同期方法から選択できます。用途に応じて最適な方法を選んでください。"
                )
            }
            .padding()
        }
        .navigationTitle("iCloud同期について")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(8)
    }
}

struct iCloudTroubleshootingView: View {
    var body: some View {
        List {
            troubleshootingItem(
                problem: "iCloudが利用できない",
                solution: "設定 > [ユーザー名] > iCloud > iCloud Drive を有効にしてください。"
            )
            
            troubleshootingItem(
                problem: "同期が遅い",
                solution: "WiFi接続を確認し、デバイスの再起動を試してください。"
            )
            
            troubleshootingItem(
                problem: "ファイルがダウンロードされない",
                solution: "iCloudストレージに十分な空き容量があることを確認してください。"
            )
            
            troubleshootingItem(
                problem: "同期エラーが発生する",
                solution: "アプリを再起動し、iCloudからサインアウト・サインインを試してください。"
            )
        }
        .navigationTitle("トラブルシューティング")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func troubleshootingItem(problem: String, solution: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(problem)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(solution)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    iCloudAudioSettingsView()
}