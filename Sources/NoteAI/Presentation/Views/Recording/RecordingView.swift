import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @State private var showingSettings = false
    @State private var showingProjectSelection = false
    
    init(viewModel: RecordingViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー
                headerView
                
                // 音声レベル表示
                audioLevelView
                
                // 録音情報
                recordingInfoView
                
                // 録音コントロール
                recordingControlsView
                
                // 文字起こし情報
                transcriptionView
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("録音")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            })
        }
        .sheet(isPresented: $showingSettings) {
            RecordingSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingProjectSelection) {
            ProjectSelectionView(viewModel: viewModel)
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("プロジェクト")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button {
                    showingProjectSelection = true
                } label: {
                    HStack {
                        Text(viewModel.selectedProject?.name ?? "プロジェクトを選択")
                            .font(.headline)
                            .foregroundColor(viewModel.selectedProject != nil ? .primary : .secondary)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(viewModel.isRecording)
            }
            
            Spacer()
            
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(viewModel.isPaused ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isPaused)
                    
                    Text(viewModel.isPaused ? "一時停止中" : "録音中")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Audio Level View
    
    private var audioLevelView: some View {
        VStack(spacing: 12) {
            // メインオーディオレベル
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.audioLevelPercentage / 100))
                    .stroke(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
                
                VStack {
                    Text("音声レベル")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(viewModel.audioLevelPercentage))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            // 平均レベルバー
            HStack {
                Text("平均")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: viewModel.averageAudioLevel, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                Text("\(Int(viewModel.averageAudioLevelPercentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .opacity(viewModel.isRecording ? 1.0 : 0.3)
    }
    
    // MARK: - Recording Info View
    
    private var recordingInfoView: some View {
        VStack(spacing: 16) {
            if let progress = viewModel.recordingProgress {
                HStack {
                    VStack(alignment: .leading) {
                        Text("録音時間")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.formattedDuration)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .fontDesign(.monospaced)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("ファイルサイズ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.formattedFileSize)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                )
            }
        }
    }
    
    // MARK: - Recording Controls View
    
    private var recordingControlsView: some View {
        HStack(spacing: 32) {
            // 録音開始/停止ボタン
            Button {
                Task {
                    if viewModel.canStartRecording {
                        await viewModel.startRecording()
                    } else if viewModel.canStopRecording {
                        await viewModel.stopRecording()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
            }
            .disabled(!viewModel.canStartRecording && !viewModel.canStopRecording)
            
            // 一時停止/再開ボタン
            if viewModel.isRecording {
                Button {
                    Task {
                        if viewModel.canPauseRecording {
                            await viewModel.pauseRecording()
                        } else if viewModel.canResumeRecording {
                            await viewModel.resumeRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!viewModel.canPauseRecording && !viewModel.canResumeRecording)
            }
        }
    }
    
    // MARK: - Transcription View
    
    private var transcriptionView: some View {
        VStack(spacing: 16) {
            if let progress = viewModel.transcriptionProgress {
                VStack(spacing: 8) {
                    HStack {
                        Text("文字起こし中...")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("キャンセル") {
                            Task {
                                await viewModel.cancelTranscription()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    ProgressView(value: progress.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text(progress.status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let remaining = progress.formattedEstimatedRemainingTime {
                            Text("残り \(remaining)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBlue).opacity(0.1))
                )
            } else if let recording = viewModel.currentRecording,
                      let transcription = recording.transcription {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("文字起こし結果")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("再試行") {
                            // TODO: APIプロバイダー選択モーダル表示
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    ScrollView {
                        Text(transcription)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.systemGray6))
                            )
                    }
                    .frame(maxHeight: 150)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct RecordingSettingsView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("録音設定") {
                    Picker("音質", selection: $viewModel.audioQuality) {
                        Text("標準").tag(AudioQuality.standard)
                        Text("高音質").tag(AudioQuality.high)
                        Text("最高音質").tag(AudioQuality.lossless)
                    }
                    
                    Toggle("ノイズ除去", isOn: $viewModel.enableNoiseCancellation)
                    Toggle("自動文字起こし", isOn: $viewModel.enableAutoTranscription)
                }
                
                Section("保存設定") {
                    Toggle("自動保存", isOn: $viewModel.enableAutoSave)
                    if viewModel.enableAutoSave {
                        Stepper("自動保存間隔: \(viewModel.autoSaveInterval)秒", 
                               value: $viewModel.autoSaveInterval, 
                               in: 10...300, 
                               step: 10)
                    }
                }
            }
            .navigationTitle("録音設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProjectSelectionView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                RecordingSearchBar(text: $searchText, placeholder: "プロジェクトを検索...")
                
                List(filteredProjects) { project in
                    RecordingProjectRow(project: project) {
                        viewModel.selectedProject = project
                        dismiss()
                    }
                }
            }
            .navigationTitle("プロジェクト選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("新規作成") {
                        // Create new project action
                        dismiss()
                    }
                }
            }
        }
        .searchable(text: $searchText)
    }
    
    private var filteredProjects: [Project] {
        // Mock projects for now
        let mockProjects: [Project] = []
        
        if searchText.isEmpty {
            return mockProjects
        } else {
            return mockProjects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct RecordingProjectRow: View {
    let project: Project
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = project.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text("更新: \(project.updatedAt, formatter: DateFormatter.short)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecordingSearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("クリア") {
                    text = ""
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Types
// Note: AudioQuality is imported from Domain/Entities/Enums.swift

extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}