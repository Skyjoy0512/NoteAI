import SwiftUI

struct LifelogView: View {
    @StateObject private var viewModel = LifelogViewModel()
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    @State private var showingFilterSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date Selector
                dateSelector
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if let lifelogEntry = viewModel.currentLifelogEntry {
                    lifelogContentView(lifelogEntry)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("ライフログ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingFilterSheet = true }) {
                            Label("フィルター", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: viewModel.exportLifelog) {
                            Label("エクスポート", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: viewModel.refreshData) {
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
            .onAppear {
                viewModel.loadLifelogEntry(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newDate in
                viewModel.loadLifelogEntry(for: newDate)
            }
        }
    }
    
    // MARK: - Date Selector
    
    private var dateSelector: some View {
        HStack {
            Button(action: previousDay) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(action: { showingDatePicker = true }) {
                VStack(spacing: 4) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(selectedDate.formatted(.dateTime.year().month().day()))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Button(action: nextDay) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
            .disabled(Calendar.current.isDate(selectedDate, inSameDayAs: Date()))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
    
    // MARK: - Lifelog Content
    
    private func lifelogContentView(_ entry: LifelogEntry) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Daily Summary Card
                dailySummaryCard(entry)
                
                // Activities Timeline
                activitiesTimelineCard(entry)
                
                // Locations Visited
                locationsCard(entry)
                
                // Key Moments
                keyMomentsCard(entry)
                
                // Mood & Insights
                moodInsightsCard(entry)
                
                // Audio Recordings Summary
                audioSummaryCard(entry)
            }
            .padding()
        }
    }
    
    private func dailySummaryCard(_ entry: LifelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("1日のサマリー")
                    .font(.headline)
                Spacer()
            }
            
            if let summary = entry.transcriptSummary {
                Text(summary)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                summaryMetric(
                    title: "録音時間",
                    value: formatDuration(entry.totalDuration),
                    icon: "waveform"
                )
                
                summaryMetric(
                    title: "活動数",
                    value: "\(entry.activities.count)",
                    icon: "figure.walk"
                )
                
                summaryMetric(
                    title: "訪問場所",
                    value: "\(entry.locations.count)",
                    icon: "location"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    private func summaryMetric(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func activitiesTimelineCard(_ entry: LifelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.green)
                Text("活動タイムライン")
                    .font(.headline)
                Spacer()
            }
            
            if entry.activities.isEmpty {
                Text("活動データがありません")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entry.activities) { activity in
                        activityTimelineItem(activity)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    private func activityTimelineItem(_ activity: ActivitySummary) -> some View {
        HStack(spacing: 12) {
            // Activity Icon
            Image(systemName: activity.activityType.icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.activityType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formatDuration(activity.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(activity.startTime.formatted(.dateTime.hour().minute())) - \(activity.endTime.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = activity.description {
                    Text(description)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Confidence indicator
            Circle()
                .fill(confidenceColor(activity.confidence))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private func locationsCard(_ entry: LifelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.red)
                Text("訪問場所")
                    .font(.headline)
                Spacer()
            }
            
            if entry.locations.isEmpty {
                Text("位置情報がありません")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entry.locations) { location in
                        locationItem(location)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    private func locationItem(_ location: LocationSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: location.category.icon)
                .foregroundColor(.red)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.placeName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(location.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("滞在時間: \(formatDuration(location.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(location.arrivalTime.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let departureTime = location.departureTime {
                        Text("- \(departureTime.formatted(.dateTime.hour().minute()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func keyMomentsCard(_ entry: LifelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle")
                    .foregroundColor(.orange)
                Text("キーモーメント")
                    .font(.headline)
                Spacer()
            }
            
            if entry.keyMoments.isEmpty {
                Text("キーモーメントがありません")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entry.keyMoments) { moment in
                        keyMomentItem(moment)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    private func keyMomentItem(_ moment: KeyMoment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: moment.category.icon)
                    .foregroundColor(Color(moment.importance.color))
                    .frame(width: 20, height: 20)
                
                Text(moment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(moment.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(moment.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text(moment.category.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                
                Text(moment.importance.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(moment.importance.color).opacity(0.1))
                    .foregroundColor(Color(moment.importance.color))
                    .cornerRadius(4)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func moodInsightsCard(_ entry: LifelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("ムード & インサイト")
                    .font(.headline)
                Spacer()
            }
            
            if let mood = entry.mood {
                moodSection(mood)
            }
            
            if !entry.insights.isEmpty {
                insightsSection(entry.insights)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    private func moodSection(_ mood: MoodInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日のムード")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(mood.overall.emoji)
                        .font(.title2)
                    Text("全体")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(mood.overall.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(mood.energy.color))
                        .frame(width: 20, height: 20)
                    Text("エネルギー")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(mood.energy.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(mood.stress.color))
                        .frame(width: 20, height: 20)
                    Text("ストレス")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(mood.stress.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let notes = mood.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }
    
    private func insightsSection(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日のインサイト")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .padding(.top, 2)
                        
                        Text(insight)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func audioSummaryCard(_ entry: LifelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                Text("音声録音サマリー")
                    .font(.headline)
                Spacer()
                
                NavigationLink(destination: AudioFilesView(audioFiles: entry.audioFiles)) {
                    Text("詳細")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.audioFiles.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("録音ファイル")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDuration(entry.totalDuration))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("総録音時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !entry.audioFiles.isEmpty {
                let completedFiles = entry.audioFiles.filter { $0.transcriptionStatus == .completed }
                let processingFiles = entry.audioFiles.filter { $0.transcriptionStatus == .processing }
                
                HStack {
                    Text("文字起こし進捗:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(completedFiles.count)/\(entry.audioFiles.count) 完了")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if !processingFiles.isEmpty {
                        Text("(\(processingFiles.count) 処理中)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    // MARK: - Empty State & Loading
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("この日のデータがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("録音データがないか、まだ処理されていません")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("データを確認") {
                viewModel.checkForData()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("ライフログを読み込み中...")
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
            Form {
                Section("表示設定") {
                    // Filter options would go here
                    Text("フィルター設定（実装予定）")
                        .foregroundColor(.secondary)
                }
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
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Supporting Views

struct AudioFilesView: View {
    let audioFiles: [AudioFileInfo]
    
    var body: some View {
        List(audioFiles) { audioFile in
            VStack(alignment: .leading, spacing: 4) {
                Text(audioFile.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(formatDuration(audioFile.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(audioFile.transcriptionStatus.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(audioFile.transcriptionStatus.color).opacity(0.1))
                        .foregroundColor(Color(audioFile.transcriptionStatus.color))
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("音声ファイル")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    LifelogView()
}