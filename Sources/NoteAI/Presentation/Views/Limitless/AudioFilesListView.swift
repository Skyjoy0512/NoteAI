import SwiftUI
import AVFoundation

struct AudioFilesListView: View {
    @StateObject private var viewModel = AudioFilesViewModel()
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingFilterSheet = false
    @State private var showingPlayer = false
    @State private var selectedAudioFile: AudioFileInfo?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date and Filter Controls
                dateFilterControls
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.audioFiles.isEmpty {
                    emptyStateView
                } else {
                    audioFilesList
                }
            }
            .navigationTitle("音声ファイル")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Menu {
                        Button(action: { showingFilterSheet = true }) {
                            Label("フィルター", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: viewModel.startBatchTranscription) {
                            Label("一括文字起こし", systemImage: "text.bubble")
                        }
                        .disabled(viewModel.audioFiles.filter { $0.transcriptionStatus == .pending }.isEmpty)
                        
                        Button(action: viewModel.exportAudioFiles) {
                            Label("エクスポート", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { viewModel.loadAudioFiles(for: selectedDate) }) {
                            Label("更新", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showingFilterSheet) {
                filterSheet
            }
            .sheet(isPresented: $showingPlayer) {
                if let audioFile = selectedAudioFile {
                    AudioPlayerView(audioFile: audioFile)
                }
            }
            .onAppear {
                viewModel.loadAudioFiles(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newDate in
                viewModel.loadAudioFiles(for: newDate)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var toolbarPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }
    
    // MARK: - Date and Filter Controls
    
    private var dateFilterControls: some View {
        VStack(spacing: 12) {
            // Date Selector
            HStack {
                Button(action: previousDay) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: { showingDatePicker = true }) {
                    VStack(spacing: 2) {
                        Text(selectedDate.formatted(.dateTime.year().month().day()))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: nextDay) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .disabled(Calendar.current.isDate(selectedDate, inSameDayAs: Date()))
            }
            
            // Summary Stats
            if !viewModel.audioFiles.isEmpty {
                HStack(spacing: 20) {
                    statItem(
                        title: "ファイル数",
                        value: "\(viewModel.audioFiles.count)",
                        icon: "waveform"
                    )
                    
                    statItem(
                        title: "総時間",
                        value: formatTotalDuration(viewModel.audioFiles),
                        icon: "clock"
                    )
                    
                    statItem(
                        title: "総サイズ",
                        value: formatTotalSize(viewModel.audioFiles),
                        icon: "externaldrive"
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
    
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Audio Files List
    
    private var audioFilesList: some View {
        List {
            ForEach(viewModel.groupedAudioFiles.keys.sorted(), id: \.self) { timeGroup in
                Section(header: timeGroupHeader(timeGroup)) {
                    ForEach(viewModel.groupedAudioFiles[timeGroup] ?? []) { audioFile in
                        audioFileRow(audioFile)
                            .onTapGesture {
                                selectedAudioFile = audioFile
                                showingPlayer = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                deleteButton(audioFile)
                                shareButton(audioFile)
                                transcribeButton(audioFile)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.loadAudioFiles(for: selectedDate)
        }
    }
    
    private func timeGroupHeader(_ timeGroup: String) -> some View {
        Text(timeGroup)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.primary)
    }
    
    private func audioFileRow(_ audioFile: AudioFileInfo) -> some View {
        HStack(spacing: 12) {
            // File Icon and Status
            VStack(spacing: 4) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(audioFile.transcriptionStatus == .completed ? .green : .blue)
                    .font(.title2)
                
                Text(audioFile.format.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // File Information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(audioFile.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(audioFile.createdAt.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(formatDuration(audioFile.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(audioFile.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let deviceInfo = audioFile.metadata.deviceInfo {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(deviceInfo.deviceName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                // Transcription Status
                HStack {
                    transcriptionStatusBadge(audioFile.transcriptionStatus)
                    
                    if let location = audioFile.metadata.location {
                        locationBadge(location.placeName ?? "位置情報")
                    }
                    
                    if let activityType = audioFile.metadata.environment?.activityType {
                        activityBadge(activityType)
                    }
                    
                    Spacer()
                }
            }
            
            // Play Button
            Button(action: {
                selectedAudioFile = audioFile
                showingPlayer = true
            }) {
                Image(systemName: "play.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func transcriptionStatusBadge(_ status: TranscriptionStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(status.color).opacity(0.1))
            .foregroundColor(Color(status.color))
            .cornerRadius(4)
    }
    
    private func locationBadge(_ location: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "location.fill")
                .font(.caption2)
            Text(location)
                .lineLimit(1)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red.opacity(0.1))
        .foregroundColor(.red)
        .cornerRadius(4)
    }
    
    private func activityBadge(_ activity: ActivityType) -> some View {
        HStack(spacing: 2) {
            Image(systemName: activity.icon)
                .font(.caption2)
            Text(activity.displayName)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.1))
        .foregroundColor(.green)
        .cornerRadius(4)
    }
    
    // MARK: - Swipe Actions
    
    private func transcribeButton(_ audioFile: AudioFileInfo) -> some View {
        Button {
            viewModel.transcribeAudioFile(audioFile)
        } label: {
            Label("文字起こし", systemImage: "text.bubble")
        }
        .tint(.blue)
        .disabled(audioFile.transcriptionStatus == .completed || audioFile.transcriptionStatus == .processing)
    }
    
    private func shareButton(_ audioFile: AudioFileInfo) -> some View {
        Button {
            viewModel.shareAudioFile(audioFile)
        } label: {
            Label("共有", systemImage: "square.and.arrow.up")
        }
        .tint(.green)
    }
    
    private func deleteButton(_ audioFile: AudioFileInfo) -> some View {
        Button {
            viewModel.deleteAudioFile(audioFile)
        } label: {
            Label("削除", systemImage: "trash")
        }
        .tint(.red)
    }
    
    // MARK: - Empty State & Loading
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("音声ファイルがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("この日の録音データが見つかりません")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("録音を開始") {
                // Navigate to recording view or start recording
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("音声ファイルを読み込み中...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sheets
    
    private var datePickerSheet: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "日付を選択",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("日付選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        showingDatePicker = false
                    }
                }
            }
        }
    }
    
    private var filterSheet: some View {
        NavigationView {
            AudioFilesFilterView(filter: $viewModel.currentFilter) {
                viewModel.applyFilter()
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        showingFilterSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func nextDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if tomorrow <= Date() {
            selectedDate = tomorrow
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func formatTotalDuration(_ audioFiles: [AudioFileInfo]) -> String {
        let totalDuration = audioFiles.reduce(0) { $0 + $1.duration }
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTotalSize(_ audioFiles: [AudioFileInfo]) -> String {
        let totalSize = audioFiles.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Audio Files Filter View

struct AudioFilesFilterView: View {
    @Binding var filter: AudioFileFilter
    let onApply: () -> Void
    
    var body: some View {
        Form {
            Section("文字起こし状態") {
                ForEach(TranscriptionStatus.allCases, id: \.self) { status in
                    Toggle(status.displayName, isOn: Binding(
                        get: { filter.transcriptionStatuses.contains(status) },
                        set: { isOn in
                            if isOn {
                                filter.transcriptionStatuses.insert(status)
                            } else {
                                filter.transcriptionStatuses.remove(status)
                            }
                        }
                    ))
                }
            }
            
            Section("音声フォーマット") {
                ForEach(AudioFormat.allCases, id: \.self) { format in
                    Toggle(format.displayName, isOn: Binding(
                        get: { filter.audioFormats.contains(format) },
                        set: { isOn in
                            if isOn {
                                filter.audioFormats.insert(format)
                            } else {
                                filter.audioFormats.remove(format)
                            }
                        }
                    ))
                }
            }
            
            Section("録音時間") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最小時間: \(Int(filter.minDuration / 60))分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: $filter.minDuration,
                        in: 0...3600,
                        step: 60
                    ) {
                        Text("最小時間")
                    }
                    
                    Text("最大時間: \(filter.maxDuration == 7200 ? "制限なし" : "\(Int(filter.maxDuration / 60))分")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: $filter.maxDuration,
                        in: 60...7200,
                        step: 60
                    ) {
                        Text("最大時間")
                    }
                }
            }
            
            Section("活動タイプ") {
                ForEach(ActivityType.allCases, id: \.self) { activity in
                    Toggle(activity.displayName, isOn: Binding(
                        get: { filter.activityTypes.contains(activity) },
                        set: { isOn in
                            if isOn {
                                filter.activityTypes.insert(activity)
                            } else {
                                filter.activityTypes.remove(activity)
                            }
                        }
                    ))
                }
            }
            
            Section {
                Button("フィルターをリセット") {
                    filter = AudioFileFilter()
                    onApply()
                }
                .foregroundColor(.red)
                
                Button("フィルターを適用") {
                    onApply()
                }
                .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
    let audioFile: AudioFileInfo
    @StateObject private var player = AudioPlayerManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // File Info
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(audioFile.fileName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Text(formatDuration(audioFile.duration))
                        Text("•")
                        Text(audioFile.format.displayName)
                        Text("•")
                        Text(formatFileSize(audioFile.fileSize))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Progress Bar
                VStack(spacing: 8) {
                    Slider(
                        value: $player.currentTime,
                        in: 0...audioFile.duration,
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(to: player.currentTime)
                            }
                        }
                    )
                    
                    HStack {
                        Text(formatDuration(player.currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatDuration(audioFile.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Playback Controls
                HStack(spacing: 32) {
                    Button(action: { player.skipBackward() }) {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                    }
                    
                    Button(action: { player.togglePlayPause() }) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    
                    Button(action: { player.skipForward() }) {
                        Image(systemName: "goforward.15")
                            .font(.title)
                    }
                }
                .foregroundColor(.blue)
                
                // Playback Speed
                HStack {
                    Text("再生速度:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Speed", selection: $player.playbackSpeed) {
                        Text("0.5x").tag(0.5)
                        Text("0.75x").tag(0.75)
                        Text("1.0x").tag(1.0)
                        Text("1.25x").tag(1.25)
                        Text("1.5x").tag(1.5)
                        Text("2.0x").tag(2.0)
                    }
                    .pickerStyle(.segmented)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("音声再生")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("共有", action: {})
                        Button("エクスポート", action: {})
                        if audioFile.transcriptionStatus == .pending {
                            Button("文字起こし", action: {})
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            player.loadAudio(from: audioFile.filePath)
        }
        .onDisappear {
            player.stop()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

#Preview {
    AudioFilesListView()
}