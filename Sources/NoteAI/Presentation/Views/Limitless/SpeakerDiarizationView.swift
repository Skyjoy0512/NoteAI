import SwiftUI

// MARK: - Missing Types for Speaker Diarization

// MARK: - View Speaker Types
struct ViewSpeaker: Identifiable {
    let id: String
    let name: String?
    let averageConfidence: Double
    let totalSpeakingTime: TimeInterval
    let segmentCount: Int
    let characteristics: ViewSpeakerCharacteristics?
    
    init(
        id: String,
        name: String? = nil,
        averageConfidence: Double,
        totalSpeakingTime: TimeInterval,
        segmentCount: Int,
        characteristics: ViewSpeakerCharacteristics? = nil
    ) {
        self.id = id
        self.name = name
        self.averageConfidence = averageConfidence
        self.totalSpeakingTime = totalSpeakingTime
        self.segmentCount = segmentCount
        self.characteristics = characteristics
    }
}

struct ViewSpeakerCharacteristics {
    let estimatedGender: EstimatedGender?
    let estimatedAge: EstimatedAge?
    let speakingRate: Double // words per minute
    let emotionalTone: ViewEmotionalTone?
    
    init(
        estimatedGender: EstimatedGender? = nil,
        estimatedAge: EstimatedAge? = nil,
        speakingRate: Double = 150,
        emotionalTone: ViewEmotionalTone? = nil
    ) {
        self.estimatedGender = estimatedGender
        self.estimatedAge = estimatedAge
        self.speakingRate = speakingRate
        self.emotionalTone = emotionalTone
    }
}

enum EstimatedGender: String, CaseIterable {
    case male = "male"
    case female = "female"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .male: return "男性"
        case .female: return "女性"
        case .unknown: return "不明"
        }
    }
}

enum EstimatedAge: String, CaseIterable {
    case child = "child"
    case young = "young"
    case adult = "adult"
    case senior = "senior"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .child: return "子供"
        case .young: return "若年層"
        case .adult: return "成人"
        case .senior: return "高齢者"
        case .unknown: return "不明"
        }
    }
}

enum ViewEmotionalTone: String, CaseIterable {
    case neutral = "neutral"
    case happy = "happy"
    case sad = "sad"
    case angry = "angry"
    case excited = "excited"
    case calm = "calm"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .neutral: return "中立"
        case .happy: return "嬉しい"
        case .sad: return "悲しい"
        case .angry: return "怒り"
        case .excited: return "興奮"
        case .calm: return "落ち着いた"
        case .unknown: return "不明"
        }
    }
}

struct ViewDiarizationResult {
    let audioFile: URL
    let totalDuration: TimeInterval
    let speakerCount: Int
    let speakers: [ViewSpeaker]
    var segments: [ViewSpeakerSegment]
    let confidence: Double
    let processingTime: TimeInterval
    
    init(
        audioFile: URL,
        totalDuration: TimeInterval,
        speakerCount: Int,
        speakers: [ViewSpeaker],
        segments: [ViewSpeakerSegment],
        confidence: Double,
        processingTime: TimeInterval
    ) {
        self.audioFile = audioFile
        self.totalDuration = totalDuration
        self.speakerCount = speakerCount
        self.speakers = speakers
        self.segments = segments
        self.confidence = confidence
        self.processingTime = processingTime
    }
}

struct ViewSpeakerSegment: Identifiable {
    let id: UUID
    let speakerId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    let audioLevel: Float
    
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    init(
        id: UUID = UUID(),
        speakerId: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double,
        audioLevel: Float = 0.5
    ) {
        self.id = id
        self.speakerId = speakerId
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.audioLevel = audioLevel
    }
}

// DiarizationOptions is available from Infrastructure layer imports

struct ViewSpeakerProfile: Identifiable {
    let id: UUID
    let name: String
    let sampleCount: Int
    let totalDuration: TimeInterval
    let lastUpdated: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        sampleCount: Int,
        totalDuration: TimeInterval,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sampleCount = sampleCount
        self.totalDuration = totalDuration
        self.lastUpdated = lastUpdated
    }
}

// InsightType is available from Core layer imports

// MARK: - Extensions
// Note: SpeakerAwareTranscriptionSegment.audioLevel is now available from Infrastructure layer

// MARK: - Type Conversion Extensions

extension Speaker {
    func toViewSpeaker() -> ViewSpeaker {
        return ViewSpeaker(
            id: self.id,
            name: self.name,
            averageConfidence: self.averageConfidence,
            totalSpeakingTime: self.totalSpeakingTime,
            segmentCount: self.segmentCount,
            characteristics: self.characteristics?.toViewSpeakerCharacteristics()
        )
    }
}

extension SpeakerCharacteristics {
    func toViewSpeakerCharacteristics() -> ViewSpeakerCharacteristics {
        return ViewSpeakerCharacteristics(
            estimatedGender: self.estimatedGender?.toViewEstimatedGender(),
            estimatedAge: self.estimatedAge?.toViewEstimatedAge(),
            speakingRate: Double(self.speakingRate),
            emotionalTone: self.emotionalTone?.toViewEmotionalTone()
        )
    }
}

extension Gender {
    func toViewEstimatedGender() -> EstimatedGender {
        switch self {
        case .male: return .male
        case .female: return .female
        case .unknown: return .unknown
        }
    }
}

extension AgeRange {
    func toViewEstimatedAge() -> EstimatedAge {
        switch self {
        case .child: return .child
        case .teenager: return .young
        case .youngAdult: return .young
        case .middleAged: return .adult
        case .senior: return .senior
        case .unknown: return .unknown
        }
    }
}

extension EmotionalTone {
    func toViewEmotionalTone() -> ViewEmotionalTone {
        switch self {
        case .neutral: return .neutral
        case .happy: return .happy
        case .sad: return .sad
        case .angry: return .angry
        case .excited: return .excited
        case .calm: return .calm
        case .stressed: return .unknown  // Map stressed to unknown since ViewEmotionalTone doesn't have stressed
        }
    }
}

// MARK: - 話者分離表示画面

struct SpeakerDiarizationView: View {
    let audioFile: AudioFileInfo
    @StateObject private var viewModel = SpeakerDiarizationViewModel()
    @State private var showingSpeakerSettings = false
    @State private var showingSpeakerProfiles = false
    @State private var selectedSpeaker: ViewSpeaker?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let result = viewModel.diarizationResult {
                    diarizationContent(result)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("話者分離")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: { showingSpeakerProfiles = true }) {
                        Image(systemName: "person.3")
                    }
                    
                    Menu {
                        Button("話者設定", action: { showingSpeakerSettings = true })
                        Button("再分析", action: { viewModel.reanalyzeSpeakers() })
                        Button("エクスポート", action: { viewModel.exportResults() })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSpeakerSettings) {
                SpeakerSettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSpeakerProfiles) {
                SpeakerProfilesView()
            }
            .sheet(item: $selectedSpeaker) { speaker in
                SpeakerDetailView(speaker: speaker, segments: viewModel.getSegments(for: speaker))
            }
            .onAppear {
                Task {
                    viewModel.performDiarization(for: audioFile)
                }
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private func diarizationContent(_ result: DiarizedTranscriptionResult) -> some View {
        VStack(spacing: 0) {
            // Summary Header
            summaryHeader(result)
            
            Divider()
            
            // Content Tabs
            TabView {
                // Timeline View
                timelineView(result)
                    .tabItem {
                        Label("タイムライン", systemImage: "timeline.selection")
                    }
                
                // Speaker View
                speakerView(result)
                    .tabItem {
                        Label("話者", systemImage: "person.2")
                    }
                
                // Transcript View
                transcriptView(result)
                    .tabItem {
                        Label("全文", systemImage: "text.alignleft")
                    }
            }
        }
    }
    
    private func summaryHeader(_ result: DiarizedTranscriptionResult) -> some View {
        VStack(spacing: 12) {
            // Audio File Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioFile.fileName)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("\(FormatUtils.formatDuration(result.totalDuration)) • \(result.speakerCount)人の話者")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { /* Play audio */ }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            
            // Speaker Overview
            HStack(spacing: 16) {
                ForEach(result.diarizationResult.speakers.prefix(4).map { $0.toViewSpeaker() }) { speaker in
                    speakerChip(speaker, isCompact: true)
                        .onTapGesture {
                            selectedSpeaker = speaker
                        }
                }
                
                if result.diarizationResult.speakers.count > 4 {
                    Text("+\(result.diarizationResult.speakers.count - 4)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        #if canImport(UIKit)
                        .background(Color(UIColor.systemGray5))
                        #else
                        .background(Color.gray.opacity(0.2))
                        #endif
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color.primary.colorInvert())
        #endif
    }
    
    private func timelineView(_ result: DiarizedTranscriptionResult) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(result.speakerSegments) { segment in
                    timelineSegmentView(segment, speakers: result.diarizationResult.speakers.map { $0.toViewSpeaker() })
                }
            }
            .padding()
        }
    }
    
    private func timelineSegmentView(_ segment: SpeakerAwareTranscriptionSegment, speakers: [ViewSpeaker]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 4) {
                Text(FormatUtils.formatTime(Date(timeIntervalSince1970: segment.startTime)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(speakerColor(segment.speakerId))
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    #if canImport(UIKit)
                    .fill(Color(UIColor.systemGray4))
                    #else
                    .fill(Color.gray.opacity(0.4))
                    #endif
                    .frame(width: 1, height: 20)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Speaker info
                HStack {
                    if let speaker = speakers.first(where: { $0.id == segment.speakerId }) {
                        speakerChip(speaker, isCompact: true)
                    }
                    
                    Spacer()
                    
                    // Duration and confidence
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FormatUtils.formatDuration(segment.duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        confidenceBadge(segment.confidence)
                    }
                }
                
                // Transcript text
                if let text = segment.text, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        #if canImport(UIKit)
                        .background(Color(UIColor.systemGray6))
                        #else
                        .background(Color.gray.opacity(0.1))
                        #endif
                        .cornerRadius(8)
                }
                
                // Audio level indicator
                audioLevelIndicator(segment.audioLevel)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func speakerView(_ result: DiarizedTranscriptionResult) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(result.diarizationResult.speakers.map { $0.toViewSpeaker() }) { speaker in
                    speakerCard(speaker, segments: result.speakerSegments.filter { $0.speakerId == speaker.id })
                        .onTapGesture {
                            selectedSpeaker = speaker
                        }
                }
            }
            .padding()
        }
    }
    
    private func speakerCard(_ speaker: ViewSpeaker, segments: [SpeakerAwareTranscriptionSegment]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Speaker header
            HStack {
                speakerChip(speaker, isCompact: false)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(segments.count)セグメント")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(FormatUtils.formatDuration(speaker.totalSpeakingTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Speaker characteristics
            if let characteristics = speaker.characteristics {
                speakerCharacteristicsView(characteristics)
            }
            
            // Recent segments preview
            VStack(alignment: .leading, spacing: 4) {
                Text("最近の発言")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(Array(segments.prefix(3))) { segment in
                    if let text = segment.text, !text.isEmpty {
                        Text(text)
                            .font(.caption)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            #if canImport(UIKit)
                        .background(Color(UIColor.systemGray6))
                        #else
                        .background(Color.gray.opacity(0.1))
                        #endif
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color.primary.colorInvert())
        #endif
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    private func transcriptView(_ result: DiarizedTranscriptionResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(result.speakerSegments) { segment in
                    transcriptSegmentView(segment, speakers: result.diarizationResult.speakers.map { $0.toViewSpeaker() })
                }
            }
            .padding()
        }
    }
    
    private func transcriptSegmentView(_ segment: SpeakerAwareTranscriptionSegment, speakers: [ViewSpeaker]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Speaker and time
            HStack {
                if let speaker = speakers.first(where: { $0.id == segment.speakerId }) {
                    Text(speaker.name ?? "話者\(segment.speakerId)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(speakerColor(segment.speakerId))
                }
                
                Spacer()
                
                Text(FormatUtils.formatTime(Date(timeIntervalSince1970: segment.startTime)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Transcript text
            if let text = segment.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Views
    
    private func speakerChip(_ speaker: ViewSpeaker, isCompact: Bool) -> some View {
        HStack(spacing: isCompact ? 4 : 8) {
            Circle()
                .fill(speakerColor(speaker.id))
                .frame(width: isCompact ? 12 : 16, height: isCompact ? 12 : 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name ?? "話者\(speaker.id)")
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.medium)
                
                if !isCompact {
                    Text("\(Int(speaker.averageConfidence * 100))% 信頼度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 4 : 6)
        .background(speakerColor(speaker.id).opacity(0.1))
        .cornerRadius(isCompact ? 8 : 10)
    }
    
    private func speakerCharacteristicsView(_ characteristics: ViewSpeakerCharacteristics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("話者特徴")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                if let gender = characteristics.estimatedGender {
                    characteristicBadge(gender.displayName, icon: "person")
                }
                
                if let age = characteristics.estimatedAge {
                    characteristicBadge(age.displayName, icon: "calendar")
                }
                
                if let tone = characteristics.emotionalTone {
                    characteristicBadge(tone.displayName, icon: "heart")
                }
            }
        }
    }
    
    private func characteristicBadge(_ text: String, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        #if canImport(UIKit)
        .background(Color(UIColor.systemGray5))
        #else
        .background(Color.gray.opacity(0.2))
        #endif
        .cornerRadius(4)
    }
    
    private func confidenceBadge(_ confidence: Double) -> some View {
        let confidencePercent = Int(confidence * 100)
        let color: Color = confidencePercent >= 80 ? .green : confidencePercent >= 60 ? .orange : .red
        
        return Text("\(confidencePercent)%")
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(3)
    }
    
    private func audioLevelIndicator(_ level: Float) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<10, id: \.self) { index in
                Rectangle()
                    .frame(width: 2, height: CGFloat(index + 1) * 2)
                    .foregroundColor(Float(index) / 10.0 <= level ? .blue : .gray.opacity(0.3))
            }
        }
    }
    
    private func speakerColor(_ speakerId: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .cyan, .mint]
        let hash = speakerId.hashValue
        return colors[abs(hash) % colors.count]
    }
    
    // MARK: - State Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("話者を分析中...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("話者分離ができませんでした")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("音声ファイルに複数の話者が含まれていない可能性があります")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("再試行") {
                viewModel.performDiarization(for: audioFile)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Speaker Settings View

struct SpeakerSettingsView: View {
    @ObservedObject var viewModel: SpeakerDiarizationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("分析設定") {
                    Picker("期待話者数", selection: $viewModel.expectedSpeakerCount) {
                        Text("自動検出").tag(0)
                        ForEach(1...10, id: \.self) { count in
                            Text("\(count)人").tag(count)
                        }
                    }
                    
                    HStack {
                        Text("最小発言時間")
                        Spacer()
                        Text("\(Int(viewModel.minSpeakerDuration))秒")
                    }
                    
                    Slider(
                        value: $viewModel.minSpeakerDuration,
                        in: 0.5...5.0,
                        step: 0.5
                    )
                }
                
                Section("高度な設定") {
                    Toggle("話者特徴分析", isOn: $viewModel.enableCharacteristics)
                    Toggle("感情分析", isOn: $viewModel.enableEmotionAnalysis)
                    Toggle("既知話者との照合", isOn: $viewModel.enableSpeakerIdentification)
                }
            }
            .navigationTitle("話者分離設定")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    Spacer()
                    Button("適用") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Speaker Profiles View

struct SpeakerProfilesView: View {
    @StateObject private var profilesManager = SpeakerProfilesManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(profilesManager.profiles) { profile in
                    SpeakerProfileRow(profile: profile)
                }
                .onDelete(perform: profilesManager.deleteProfiles)
            }
            .navigationTitle("話者プロファイル")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("閉じる") {
                        dismiss()
                    }
                    Spacer()
                    Button("追加") {
                        // Add new profile
                    }
                }
            }
        }
    }
}

struct SpeakerProfileRow: View {
    let profile: ViewSpeakerProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("\(profile.sampleCount)サンプル")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(FormatUtils.formatDuration(profile.totalDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(FormatUtils.formatDate(profile.lastUpdated))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Speaker Detail View

struct SpeakerDetailView: View {
    let speaker: ViewSpeaker
    let segments: [SpeakerAwareTranscriptionSegment]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Speaker overview
                    speakerOverview
                    
                    // Characteristics
                    if let characteristics = speaker.characteristics {
                        characteristicsSection(characteristics)
                    }
                    
                    // All segments
                    segmentsSection
                }
                .padding()
            }
            .navigationTitle(speaker.name ?? "話者詳細")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var speakerOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("概要")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("総発言時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(FormatUtils.formatDuration(speaker.totalSpeakingTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("発言回数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(speaker.segmentCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("平均信頼度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(speaker.averageConfidence * 100))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
        }
        .limitlessCardStyle()
    }
    
    private func characteristicsSection(_ characteristics: ViewSpeakerCharacteristics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("話者特徴")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let gender = characteristics.estimatedGender {
                    characteristicRow("性別", value: gender.displayName)
                }
                
                if let age = characteristics.estimatedAge {
                    characteristicRow("年齢層", value: age.displayName)
                }
                
                characteristicRow("発話速度", value: "\(Int(characteristics.speakingRate))語/分")
                
                if let tone = characteristics.emotionalTone {
                    characteristicRow("感情的トーン", value: tone.displayName)
                }
            }
        }
        .limitlessCardStyle()
    }
    
    private var segmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全発言(\(segments.count))")
                .font(.headline)
            
            ForEach(segments) { segment in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(FormatUtils.formatTime(Date(timeIntervalSince1970: segment.startTime)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(FormatUtils.formatDuration(segment.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let text = segment.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                    }
                }
                .padding()
                #if canImport(UIKit)
                .background(Color(UIColor.systemGray6))
                #else
                .background(Color.gray.opacity(0.1))
                #endif
                .cornerRadius(8)
            }
        }
    }
    
    private func characteristicRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Supporting Classes

@MainActor
class SpeakerDiarizationViewModel: ObservableObject {
    @Published var diarizationResult: DiarizedTranscriptionResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Settings
    @Published var expectedSpeakerCount = 0
    @Published var minSpeakerDuration: Double = 1.0
    @Published var enableCharacteristics = true
    @Published var enableEmotionAnalysis = false
    @Published var enableSpeakerIdentification = false
    
    private let whisperService = FasterWhisperService()
    
    func performDiarization(for audioFile: AudioFileInfo) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let transcriptionOptions = TranscriptionOptions(
                    language: "ja",
                    wordTimestamps: true,
                    vadFilter: true
                )
                
                let diarizationOptions = DiarizationOptions(
                    expectedSpeakerCount: expectedSpeakerCount > 0 ? expectedSpeakerCount : nil,
                    minSpeakerDuration: minSpeakerDuration,
                    enableSpeakerIdentification: enableSpeakerIdentification
                )
                
                let result = try await whisperService.transcribeWithSpeakerDiarization(
                    audioFile: audioFile.filePath,
                    options: transcriptionOptions,
                    diarizationOptions: diarizationOptions
                )
                
                diarizationResult = result
                
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    func reanalyzeSpeakers() {
        // Re-run diarization with current settings
    }
    
    func exportResults() {
        // Export diarization results
    }
    
    func getSegments(for speaker: ViewSpeaker) -> [SpeakerAwareTranscriptionSegment] {
        return diarizationResult?.speakerSegments.filter { $0.speakerId == speaker.id } ?? []
    }
}

@MainActor
class SpeakerProfilesManager: ObservableObject {
    @Published var profiles: [ViewSpeakerProfile] = []
    
    init() {
        loadProfiles()
    }
    
    private func loadProfiles() {
        // Load saved speaker profiles
        // Mock data for now
        profiles = []
    }
    
    func deleteProfiles(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
    }
}

#Preview {
    SpeakerDiarizationView(audioFile: AudioFileInfo(
        fileName: "test.wav",
        filePath: URL(fileURLWithPath: "/tmp/test.wav"),
        duration: 120,
        fileSize: 1024,
        createdAt: Date(),
        sampleRate: 44100,
        channels: 2,
        format: .wav,
        transcriptionStatus: .completed
    ))
}