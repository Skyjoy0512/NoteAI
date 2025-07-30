import SwiftUI
import CloudKit

// MARK: - 音声ファイル行表示（iCloud対応版）

struct AudioFileRowView: View {
    
    let audioFile: AudioFileInfo
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onToggleImportant: () -> Void
    let onSyncToiCloud: () -> Void
    
    @StateObject private var iCloudManager = iCloudAudioManager.shared
    @State private var isUploadingToiCloud = false
    @State private var uploadProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // ファイル情報
                fileInfoSection
                
                Spacer()
                
                // 操作ボタン
                actionButtonsSection
            }
            .padding(.vertical, 8)
            
            // iCloud同期インジケーター
            if audioFile.isSyncedToiCloud || isUploadingToiCloud {
                iCloudSyncIndicator
            }
        }
        #if canImport(UIKit)
        .background(Color(.systemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .onReceive(iCloudManager.$uploadProgress) { progress in
            if let fileProgress = progress[audioFile.id.uuidString] {
                uploadProgress = fileProgress
                isUploadingToiCloud = fileProgress < 1.0
            }
        }
    }
    
    // MARK: - File Info Section
    
    private var fileInfoSection: some View {
        HStack(spacing: 12) {
            // ファイル形式アイコン
            formatIcon
            
            VStack(alignment: .leading, spacing: 4) {
                // ファイル名と重要マーク
                HStack(spacing: 6) {
                    Text(audioFile.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if audioFile.isImportant {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    if audioFile.isSyncedToiCloud {
                        Image(systemName: "icloud.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // ファイル詳細情報
                HStack(spacing: 8) {
                    Text(FormatUtils.formatDuration(audioFile.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(FormatUtils.formatFileSize(audioFile.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(audioFile.format.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 文字起こし状態と日時
                HStack(spacing: 8) {
                    transcriptionStatusBadge
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(FormatUtils.formatRelativeDate(audioFile.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var formatIcon: some View {
        ZStack {
            Circle()
                .fill(formatColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: formatIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(formatColor)
        }
    }
    
    private var formatColor: Color {
        switch audioFile.format {
        case .wav:
            return .blue
        case .mp3:
            return .green
        case .m4a:
            return .purple
        case .aac:
            return .orange
        case .flac:
            return .red
        }
    }
    
    private var formatIconName: String {
        switch audioFile.format {
        case .wav, .flac:
            return "waveform"
        case .mp3, .aac:
            return "music.note"
        case .m4a:
            return "speaker.wave.2"
        }
    }
    
    private var transcriptionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(transcriptionStatusColor)
                .frame(width: 6, height: 6)
            
            Text(audioFile.transcriptionStatus.displayName)
                .font(.caption2)
                .foregroundColor(transcriptionStatusColor)
        }
    }
    
    private var transcriptionStatusColor: Color {
        switch audioFile.transcriptionStatus {
        case .pending:
            return .orange
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .skipped:
            return .gray
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        HStack(spacing: 8) {
            // 重要マークトグル
            Button(action: onToggleImportant) {
                Image(systemName: audioFile.isImportant ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundColor(audioFile.isImportant ? .yellow : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            // iCloud同期ボタン
            if iCloudManager.isEnabled && iCloudManager.isAvailable {
                iCloudSyncButton
            }
            
            // 再生ボタン
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            // メニューボタン
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var iCloudSyncButton: some View {
        Button(action: {
            if audioFile.isSyncedToiCloud {
                // 既に同期済みの場合は何もしない（または詳細表示）
            } else {
                onSyncToiCloud()
            }
        }) {
            if isUploadingToiCloud {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: audioFile.isSyncedToiCloud ? "icloud.fill" : "icloud")
                    .font(.system(size: 16))
                    .foregroundColor(audioFile.isSyncedToiCloud ? .blue : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUploadingToiCloud)
    }
    
    private var menuItems: some View {
        Group {
            Button(action: {
                // ファイル詳細表示
            }) {
                Label("詳細を表示", systemImage: "info.circle")
            }
            
            Button(action: {
                // ファイル名変更
            }) {
                Label("名前を変更", systemImage: "pencil")
            }
            
            if audioFile.isSyncedToiCloud {
                Button(action: {
                    // iCloudから削除
                }) {
                    Label("iCloudから削除", systemImage: "icloud.slash")
                }
            }
            
            Button(action: {
                // エクスポート
            }) {
                Label("エクスポート", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(action: onDelete) {
                Label("削除", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - iCloud Sync Indicator
    
    private var iCloudSyncIndicator: some View {
        VStack(spacing: 4) {
            if isUploadingToiCloud {
                HStack {
                    Text("iCloudに同期中...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(Int(uploadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: uploadProgress)
                    .tint(.blue)
                    .scaleEffect(y: 0.5)
                
            } else if audioFile.isSyncedToiCloud {
                HStack {
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("iCloudと同期済み")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    if let syncDate = audioFile.cloudSyncDate {
                        Text("• \(FormatUtils.formatRelativeDate(syncDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - AudioFileRowView with Enhanced iCloud Features

struct EnhancedAudioFileRowView: View {
    
    let audioFile: AudioFileInfo
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onToggleImportant: () -> Void
    let onSyncToiCloud: () -> Void
    let onDownloadFromiCloud: () -> Void
    
    @StateObject private var iCloudManager = iCloudAudioManager.shared
    @State private var showingCloudMenu = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // メインコンテンツ
            mainContent
            
            // iCloud詳細インジケーター
            if shouldShowCloudIndicator {
                cloudDetailIndicator
            }
        }
        #if canImport(UIKit)
        .background(Color(.systemBackground))
        #else
        .background(Color(NSColor.controlBackgroundColor))
        #endif
        .contextMenu {
            contextMenuItems
        }
    }
    
    private var mainContent: some View {
        HStack(spacing: 12) {
            // ファイル情報（詳細版）
            enhancedFileInfo
            
            Spacer()
            
            // 操作ボタン（拡張版）
            enhancedActionButtons
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
    
    private var enhancedFileInfo: some View {
        HStack(spacing: 12) {
            // 複合アイコン（フォーマット + 状態）
            ZStack {
                Circle()
                    .fill(formatColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: formatIconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(formatColor)
                
                // iCloud状態のオーバーレイ
                if audioFile.isSyncedToiCloud {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .background(
                                    Circle()
                                        #if canImport(UIKit)
                                        .fill(Color(.systemBackground))
                                        #else
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        #endif
                                        .frame(width: 14, height: 14)
                                )
                        }
                    }
                    .frame(width: 44, height: 44)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // ファイル名行
                HStack(spacing: 6) {
                    Text(audioFile.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if audioFile.isImportant {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                // 詳細情報行
                HStack(spacing: 8) {
                    Text(FormatUtils.formatDuration(audioFile.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(FormatUtils.formatFileSize(audioFile.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(audioFile.sampleRate/1000))kHz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if audioFile.channels > 1 {
                        Text("• ステレオ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 状態と日時行
                HStack(spacing: 8) {
                    transcriptionStatusBadge
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(FormatUtils.formatRelativeDate(audioFile.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let syncDate = audioFile.cloudSyncDate {
                        Text("• iCloud: \(FormatUtils.formatRelativeDate(syncDate))")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var enhancedActionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 重要マーク
                Button(action: onToggleImportant) {
                    Image(systemName: audioFile.isImportant ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(audioFile.isImportant ? .yellow : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                // iCloud操作ボタン
                if iCloudManager.isEnabled && iCloudManager.isAvailable {
                    cloudActionButton
                }
                
                // 再生ボタン
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // ファイルサイズインジケーター
            if audioFile.fileSize > 10 * 1024 * 1024 { // 10MB以上
                Text("大きなファイル")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
    
    private var cloudActionButton: some View {
        Button(action: {
            if audioFile.isSyncedToiCloud {
                showingCloudMenu = true
            } else {
                onSyncToiCloud()
            }
        }) {
            if isDownloading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: cloudButtonIcon)
                    .font(.system(size: 18))
                    .foregroundColor(cloudButtonColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog("iCloudオプション", isPresented: $showingCloudMenu) {
            cloudMenuOptions
        }
    }
    
    private var cloudButtonIcon: String {
        if audioFile.isSyncedToiCloud {
            return "icloud.fill"
        } else {
            return "icloud"
        }
    }
    
    private var cloudButtonColor: Color {
        if audioFile.isSyncedToiCloud {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var cloudMenuOptions: some View {
        Group {
            Button("詳細を表示") {
                // iCloud詳細表示
            }
            
            if !isLocalFileAvailable {
                Button("ダウンロード") {
                    onDownloadFromiCloud()
                }
            }
            
            Button("再同期") {
                onSyncToiCloud()
            }
            
            Button("iCloudから削除", role: .destructive) {
                // iCloudから削除
            }
        }
    }
    
    private var shouldShowCloudIndicator: Bool {
        return audioFile.isSyncedToiCloud || isDownloading || !isLocalFileAvailable
    }
    
    private var isLocalFileAvailable: Bool {
        return FileManager.default.fileExists(atPath: audioFile.filePath.path)
    }
    
    private var cloudDetailIndicator: some View {
        VStack(spacing: 6) {
            if isDownloading {
                downloadProgressView
            } else if audioFile.isSyncedToiCloud && !isLocalFileAvailable {
                cloudOnlyIndicator
            } else if audioFile.isSyncedToiCloud {
                syncedIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var downloadProgressView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("iCloudからダウンロード中...")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(Int(downloadProgress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: downloadProgress)
                .tint(.blue)
                .scaleEffect(y: 0.6)
        }
    }
    
    private var cloudOnlyIndicator: some View {
        HStack {
            Image(systemName: "icloud.and.arrow.down")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text("iCloudに保存済み（ローカルなし）")
                .font(.caption2)
                .foregroundColor(.blue)
            
            Spacer()
            
            Button("ダウンロード") {
                onDownloadFromiCloud()
            }
            .font(.caption2)
            .foregroundColor(.blue)
        }
    }
    
    private var syncedIndicator: some View {
        HStack {
            Image(systemName: "checkmark.icloud.fill")
                .font(.caption)
                .foregroundColor(.green)
            
            Text("iCloudと同期済み")
                .font(.caption2)
                .foregroundColor(.green)
            
            if let syncDate = audioFile.cloudSyncDate {
                Text("• \(FormatUtils.formatRelativeDate(syncDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(action: onPlay) {
                Label("再生", systemImage: "play.fill")
            }
            
            Button(action: onToggleImportant) {
                Label(
                    audioFile.isImportant ? "重要マークを外す" : "重要マーク",
                    systemImage: audioFile.isImportant ? "star.slash" : "star"
                )
            }
            
            if iCloudManager.isEnabled && iCloudManager.isAvailable {
                if audioFile.isSyncedToiCloud {
                    Button(action: onDownloadFromiCloud) {
                        Label("再ダウンロード", systemImage: "icloud.and.arrow.down")
                    }
                } else {
                    Button(action: onSyncToiCloud) {
                        Label("iCloudに同期", systemImage: "icloud.and.arrow.up")
                    }
                }
            }
            
            Divider()
            
            Button(action: onDelete) {
                Label("削除", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    // 共通プロパティ（上記のコードから継承）
    private var formatColor: Color {
        switch audioFile.format {
        case .wav: return .blue
        case .mp3: return .green
        case .m4a: return .purple
        case .aac: return .orange
        case .flac: return .red
        }
    }
    
    private var formatIconName: String {
        switch audioFile.format {
        case .wav, .flac: return "waveform"
        case .mp3, .aac: return "music.note"
        case .m4a: return "speaker.wave.2"
        }
    }
    
    private var transcriptionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(transcriptionStatusColor)
                .frame(width: 6, height: 6)
            
            Text(audioFile.transcriptionStatus.displayName)
                .font(.caption2)
                .foregroundColor(transcriptionStatusColor)
        }
    }
    
    private var transcriptionStatusColor: Color {
        switch audioFile.transcriptionStatus {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

// MARK: - Format Utils Extension

extension FormatUtils {
    static func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack {
        AudioFileRowView(
            audioFile: AudioFileInfo(
                fileName: "テスト録音.m4a",
                filePath: URL(fileURLWithPath: "/tmp/test.m4a"),
                duration: 125.5,
                fileSize: 2_450_000,
                createdAt: Date().addingTimeInterval(-3600),
                sampleRate: 44100,
                channels: 2,
                format: .m4a,
                transcriptionStatus: .completed,
                isImportant: true,
                isSyncedToiCloud: true,
                cloudSyncDate: Date().addingTimeInterval(-1800)
            ),
            onPlay: { },
            onDelete: { },
            onToggleImportant: { },
            onSyncToiCloud: { }
        )
        
        Divider()
        
        EnhancedAudioFileRowView(
            audioFile: AudioFileInfo(
                fileName: "長い会議録音ファイル名例.wav",
                filePath: URL(fileURLWithPath: "/tmp/meeting.wav"),
                duration: 3725.8,
                fileSize: 45_300_000,
                createdAt: Date().addingTimeInterval(-86400),
                sampleRate: 48000,
                channels: 1,
                format: .wav,
                transcriptionStatus: .processing,
                isImportant: false,
                isSyncedToiCloud: false
            ),
            onPlay: { },
            onDelete: { },
            onToggleImportant: { },
            onSyncToiCloud: { },
            onDownloadFromiCloud: { }
        )
    }
    .padding()
}