import SwiftUI

// MARK: - クラウドストレージ設定画面

struct CloudStorageSettingsView: View {
    
    @StateObject private var syncManager = SelectiveCloudSyncManager.shared
    @StateObject private var storageMonitor = StorageMonitor.shared
    @State private var showingCleanupSheet = false
    @State private var showingSyncDataEstimate = false
    @State private var syncDataEstimate: SyncDataEstimate?
    
    var body: some View {
        NavigationView {
            Form {
                // データ同期設定セクション
                dataSyncSection
                
                // ストレージ使用量セクション
                storageUsageSection
                
                // クリーンアップセクション
                cleanupSection
                
                // プライバシー情報セクション
                privacySection
                
                // 詳細設定セクション
                advancedSection
            }
            .navigationTitle("ストレージ設定")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                storageMonitor.startMonitoring()
                Task {
                    syncDataEstimate = await syncManager.estimateSyncDataSize()
                }
            }
            .onDisappear {
                storageMonitor.stopMonitoring()
            }
            .sheet(isPresented: $showingCleanupSheet) {
                CleanupSuggestionsView()
            }
            .sheet(isPresented: $showingSyncDataEstimate) {
                SyncDataEstimateView(estimate: syncDataEstimate)
            }
        }
    }
    
    // MARK: - Data Sync Section
    
    private var dataSyncSection: some View {
        Section {
            // メイン同期トグル
            Toggle("クラウド同期", isOn: $syncManager.syncEnabled)
                .tint(.blue)
            
            if syncManager.syncEnabled {
                // 同期範囲選択
                syncScopePickerRow
                
                // 自動同期設定
                Toggle("自動同期", isOn: $syncManager.autoSyncEnabled)
                    .disabled(!syncManager.syncEnabled)
                
                // WiFi限定同期
                Toggle("WiFi接続時のみ", isOn: $syncManager.wifiOnlySync)
                    .disabled(!syncManager.syncEnabled)
                
                // 手動同期ボタン
                manualSyncButton
                
                // 同期ステータス
                syncStatusRow
            }
        } header: {
            Text("データ同期")
        } footer: {
            if syncManager.syncEnabled {
                syncScopeDescription
            } else {
                Text("同期を有効にすると、デバイス間でプロジェクト情報を共有できます")
            }
        }
    }
    
    private var syncScopePickerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("同期範囲")
                    .foregroundColor(.primary)
                Spacer()
                Button(syncManager.syncScope.displayName) {
                    // Picker表示はActionSheetで実装
                }
                .foregroundColor(.blue)
            }
            
            if let estimate = syncDataEstimate {
                HStack {
                    Text("推定データ量: \(estimate.formattedSize)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("詳細") {
                        showingSyncDataEstimate = true
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var manualSyncButton: some View {
        Button(action: {
            Task {
                await syncManager.triggerManualSync()
            }
        }) {
            HStack {
                if syncManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                
                Text(syncManager.isSyncing ? "同期中..." : "今すぐ同期")
            }
        }
        .disabled(syncManager.isSyncing || !syncManager.syncEnabled)
    }
    
    private var syncStatusRow: some View {
        HStack {
            Text("同期状況")
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(syncManager.syncStatus.color)
                    .frame(width: 8, height: 8)
                
                Text(syncManager.syncStatus.displayName)
                    .font(.caption)
                    .foregroundColor(syncManager.syncStatus.color)
            }
        }
    }
    
    private var syncScopeDescription: some View {
        Group {
            switch syncManager.syncScope {
            case .disabled:
                Text("クラウド同期は無効です")
            case .metadataOnly:
                Text("プロジェクト名、ファイル名、作成日時などの基本情報のみ同期されます。音声ファイルや文字起こし内容は同期されません。")
            case .summarySync:
                Text("基本情報に加えて、文字起こしの要約も同期されます。詳細な内容は端末内に保存されます。")
            case .fullSync:
                Text("全ての文字起こし結果が同期されます。有料プランが必要です。")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    // MARK: - Storage Usage Section
    
    private var storageUsageSection: some View {
        Section("ストレージ使用量") {
            StorageUsageView(metrics: storageMonitor.currentMetrics)
            
            if storageMonitor.currentMetrics.isWarningSpace {
                storageWarningView
            }
            
            NavigationLink("詳細分析") {
                DetailedStorageAnalysisView()
            }
        }
    }
    
    private var storageWarningView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ストレージ容量が少なくなっています")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("クリーンアップをお勧めします")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Cleanup Section
    
    private var cleanupSection: some View {
        Section("ストレージクリーンアップ") {
            Button("クリーンアップ提案を表示") {
                showingCleanupSheet = true
            }
            .foregroundColor(.blue)
            
            if !storageMonitor.cleanupSuggestions.isEmpty {
                HStack {
                    Text("提案件数")
                    Spacer()
                    Text("\(storageMonitor.cleanupSuggestions.count)件")
                        .foregroundColor(.secondary)
                }
                
                let totalSavings = storageMonitor.cleanupSuggestions.reduce(0) { $0 + $1.potentialSavings }
                HStack {
                    Text("削減可能容量")
                    Spacer()
                    Text(ByteCountFormatter().string(fromByteCount: totalSavings))
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section("プライバシー保護") {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("音声データは端末内保存")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("プライバシーを最優先に設計されています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("APIキーの安全な保存")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("キーチェーンによる暗号化保存")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "network.slash")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("オフライン完全対応")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("ネットワークなしでも全機能利用可能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section("詳細設定") {
            Button("同期設定をリセット") {
                syncManager.resetSyncSettings()
            }
            .foregroundColor(.red)
            
            if let lastSyncInfo = syncManager.getLastSyncInfo() {
                HStack {
                    Text("最後の同期")
                    Spacer()
                    Text(lastSyncInfo.timeAgo)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink("高度なストレージ設定") {
                AdvancedStorageSettingsView()
            }
        }
    }
}

// MARK: - Storage Usage View

struct StorageUsageView: View {
    let metrics: StorageMetrics
    
    var body: some View {
        VStack(spacing: 12) {
            // 全体使用量
            overallUsageView
            
            // 詳細内訳
            detailedBreakdown
        }
    }
    
    private var overallUsageView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("使用量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(metrics.formattedSize(metrics.totalUsed)) / \(metrics.formattedSize(metrics.totalSpace))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: metrics.usagePercentage)
                .tint(progressColor)
                .background(Color.gray.opacity(0.2))
            
            HStack {
                Text("\(Int(metrics.usagePercentage * 100))% 使用中")
                    .font(.caption)
                    .foregroundColor(progressColor)
                
                Spacer()
                
                Text("空き容量: \(metrics.formattedSize(metrics.availableSpace))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var detailedBreakdown: some View {
        VStack(spacing: 4) {
            storageRow("音声ファイル", size: metrics.audioFiles, color: .blue)
            storageRow("ベクトルデータ", size: metrics.vectorData, color: .green)
            storageRow("キャッシュ", size: metrics.cacheData, color: .orange)
            storageRow("一時ファイル", size: metrics.temporaryFiles, color: .red)
            storageRow("アプリデータ", size: metrics.coreDataSize, color: .purple)
        }
    }
    
    private func storageRow(_ title: String, size: Int64, color: Color) -> some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption)
            }
            
            Spacer()
            
            Text(metrics.formattedSize(size))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var progressColor: Color {
        if metrics.isLowSpace {
            return .red
        } else if metrics.isWarningSpace {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Cleanup Suggestions View

struct CleanupSuggestionsView: View {
    @StateObject private var storageMonitor = StorageMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSuggestions: Set<String> = []
    @State private var isPerformingCleanup = false
    @State private var cleanupResult: CleanupResult?
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("クリーンアップ不要")
                .font(.headline)
            
            Text("現在、削除可能な不要ファイルはありません")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var cleanupSuggestionsList: some View {
        List {
            ForEach(storageMonitor.cleanupSuggestions, id: \.title) { suggestion in
                CleanupSuggestionRow(
                    suggestion: suggestion,
                    isSelected: selectedSuggestions.contains(suggestion.title)
                ) { isSelected in
                    if isSelected {
                        selectedSuggestions.insert(suggestion.title)
                    } else {
                        selectedSuggestions.remove(suggestion.title)
                    }
                }
            }
            
            if !selectedSuggestions.isEmpty {
                totalSavingsRow
            }
        }
    }
    
    private var totalSavingsRow: some View {
        HStack {
            Text("合計削減容量")
                .fontWeight(.medium)
            
            Spacer()
            
            let totalSavings = storageMonitor.cleanupSuggestions
                .filter { selectedSuggestions.contains($0.title) }
                .reduce(0) { $0 + $1.potentialSavings }
            
            Text(ByteCountFormatter().string(fromByteCount: totalSavings))
                .fontWeight(.semibold)
                .foregroundColor(.green)
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private func performCleanup() {
        isPerformingCleanup = true
        
        let suggestionsToExecute = storageMonitor.cleanupSuggestions
            .filter { selectedSuggestions.contains($0.title) }
        
        Task {
            // Mock implementation - replace with actual StorageMonitor method
            let result = CleanupResult(
                cleanedSize: suggestionsToExecute.reduce(0) { $0 + $1.potentialSavings },
                cleanedItems: suggestionsToExecute.count,
                errors: []
            )
            
            await MainActor.run {
                self.cleanupResult = result
                self.isPerformingCleanup = false
                self.selectedSuggestions.removeAll()
            }
            
            if result.isSuccessful {
                // 3秒後に自動で閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    dismiss()
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if storageMonitor.cleanupSuggestions.isEmpty {
                    emptyStateView
                } else {
                    cleanupSuggestionsList
                }
            }
            .navigationTitle("クリーンアップ提案")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                #endif
                
                if !storageMonitor.cleanupSuggestions.isEmpty {
                    #if canImport(UIKit)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("実行") {
                            performCleanup()
                        }
                        .disabled(selectedSuggestions.isEmpty || isPerformingCleanup)
                    }
                    #else
                    ToolbarItem(placement: .confirmationAction) {
                        Button("実行") {
                            performCleanup()
                        }
                        .disabled(selectedSuggestions.isEmpty || isPerformingCleanup)
                    }
                    #endif
                }
            }
        }
    }
}

struct CleanupSuggestionRow: View {
    let suggestion: CleanupSuggestion
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.title)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(ByteCountFormatter().string(fromByteCount: suggestion.potentialSavings))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Missing View Placeholders

struct SyncDataEstimateView: View {
    let estimate: SyncDataEstimate?
    
    var body: some View {
        Text("Placeholder for SyncDataEstimateView")
    }
}

struct DetailedStorageAnalysisView: View {
    var body: some View {
        Text("Placeholder for DetailedStorageAnalysisView")
    }
}

struct AdvancedStorageSettingsView: View {
    var body: some View {
        Text("Placeholder for AdvancedStorageSettingsView")
    }
}

#Preview {
    CloudStorageSettingsView()
}
