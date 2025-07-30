import Foundation
import SwiftUI
import Combine

@MainActor
class LifelogViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentLifelogEntry: LifelogEntry?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var displayFilter = DisplayFilter()
    
    // MARK: - Private Properties
    private let recordingManager: ContinuousRecordingManagerProtocol
    private let deviceService: any LimitlessDeviceServiceProtocol
    private let whisperService: FasterWhisperServiceProtocol
    private let ragService: RAGServiceProtocol
    
    private let logger = RAGLogger.shared
    private let performanceMonitor = RAGPerformanceMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        recordingManager: ContinuousRecordingManagerProtocol,
        deviceService: any LimitlessDeviceServiceProtocol,
        whisperService: FasterWhisperServiceProtocol,
        ragService: RAGServiceProtocol
    ) {
        self.recordingManager = recordingManager
        self.deviceService = deviceService
        self.whisperService = whisperService
        self.ragService = ragService
        
        setupObservers()
    }
    
    // For SwiftUI Preview
    init() {
        self.recordingManager = MockContinuousRecordingManager()
        self.deviceService = MockLimitlessDeviceService()
        self.whisperService = MockFasterWhisperService()
        self.ragService = MockRAGService()
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func loadLifelogEntry(for date: Date) {
        Task {
            await loadLifelogEntryAsync(for: date)
        }
    }
    
    func refreshData() {
        guard let currentDate = currentLifelogEntry?.date else { return }
        loadLifelogEntry(for: currentDate)
    }
    
    func exportLifelog() {
        guard let entry = currentLifelogEntry else { return }
        
        Task {
            await exportLifelogEntry(entry)
        }
    }
    
    func checkForData() {
        Task {
            await checkForDataAsync()
        }
    }
    
    func updateFilter(_ filter: DisplayFilter) {
        displayFilter = filter
        refreshData()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Use timer-based monitoring since protocol types don't have objectWillChange
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRecordingManagerUpdate()
            }
            .store(in: &cancellables)
    }
    
    private func handleRecordingManagerUpdate() {
        // Refresh current lifelog entry when new recordings are available
        if let currentDate = currentLifelogEntry?.date {
            loadLifelogEntry(for: currentDate)
        }
    }
    
    private func loadLifelogEntryAsync(for date: Date) async {
        let measurement = performanceMonitor.startMeasurement()
        
        isLoading = true
        errorMessage = nil
        
        logger.log(level: .info, message: "Loading lifelog entry", context: [
            "date": date.description
        ])
        
        do {
            // Get recording sessions for the date
            let sessions = try await recordingManager.getRecordingSessions(for: date)
            
            // Aggregate audio files from all sessions
            let audioFiles = sessions.flatMap { $0.audioFiles }
            
            // Calculate total duration
            let totalDuration = audioFiles.reduce(0) { $0 + $1.duration }
            
            // Generate lifelog entry
            let entry = try await generateLifelogEntry(
                date: date,
                audioFiles: audioFiles,
                totalDuration: totalDuration
            )
            
            currentLifelogEntry = entry
            
            performanceMonitor.recordMetric(
                operation: "loadLifelogEntry",
                measurement: measurement,
                success: true,
                metadata: [
                    "audioFileCount": audioFiles.count,
                    "totalDuration": totalDuration
                ]
            )
            
            logger.log(level: .info, message: "Lifelog entry loaded", context: [
                "audioFiles": audioFiles.count,
                "activities": entry.activities.count,
                "locations": entry.locations.count,
                "keyMoments": entry.keyMoments.count
            ])
            
        } catch {
            errorMessage = error.localizedDescription
            
            performanceMonitor.recordMetric(
                operation: "loadLifelogEntry",
                measurement: measurement,
                success: false
            )
            
            logger.log(level: .error, message: "Failed to load lifelog entry", context: [
                "error": error.localizedDescription
            ])
        }
        
        isLoading = false
    }
    
    private func generateLifelogEntry(
        date: Date,
        audioFiles: [AudioFileInfo],
        totalDuration: TimeInterval
    ) async throws -> LifelogEntry {
        
        // Generate transcript summary
        let transcriptSummary = try await generateTranscriptSummary(audioFiles: audioFiles)
        
        // Analyze activities
        let activities = try await analyzeActivities(audioFiles: audioFiles)
        
        // Analyze locations
        let locations = try await analyzeLocations(audioFiles: audioFiles)
        
        // Extract key moments
        let keyMoments = try await extractKeyMoments(audioFiles: audioFiles)
        
        // Generate insights
        let insights = try await generateInsights(
            audioFiles: audioFiles,
            activities: activities,
            locations: locations,
            keyMoments: keyMoments
        )
        
        // Analyze mood (if available)
        let mood = try await analyzeMood(audioFiles: audioFiles)
        
        return LifelogEntry(
            date: date,
            audioFiles: audioFiles,
            totalDuration: totalDuration,
            transcriptSummary: transcriptSummary,
            activities: activities,
            locations: locations,
            keyMoments: keyMoments,
            insights: insights,
            mood: mood
        )
    }
    
    private func generateTranscriptSummary(audioFiles: [AudioFileInfo]) async throws -> String? {
        let transcribedFiles = audioFiles.filter { $0.transcriptionStatus == .completed }
        
        guard !transcribedFiles.isEmpty else { return nil }
        
        // In a real implementation, this would combine all transcripts and summarize
        // For now, return a mock summary
        
        let totalDuration = transcribedFiles.reduce(0) { $0 + $1.duration }
        let hours = Int(totalDuration) / 3600
        let minutes = Int(totalDuration) % 3600 / 60
        
        if hours > 0 {
            return "今日は\(hours)時間\(minutes)分の録音データから、会議、電話、日常会話などの様々な活動が記録されました。重要な決定事項や新しいアイデアが複数含まれており、生産的な一日だったことが伺えます。"
        } else {
            return "今日は\(minutes)分の録音データが記録されました。短時間ながら重要な内容が含まれているようです。"
        }
    }
    
    private func analyzeActivities(audioFiles: [AudioFileInfo]) async throws -> [ActivitySummary] {
        // Mock activity analysis
        // In a real implementation, this would use AI to analyze audio content and metadata
        
        var activities: [ActivitySummary] = []
        let calendar = Calendar.current
        
        // Generate mock activities based on time of day and audio files
        for (_, audioFile) in audioFiles.enumerated() {
            let hour = calendar.component(.hour, from: audioFile.createdAt)
            let activityType: ActivityType
            
            switch hour {
            case 6...8:
                activityType = .personal
            case 9...12:
                activityType = .meeting
            case 12...13:
                activityType = .leisure
            case 13...17:
                activityType = .work
            case 17...19:
                activityType = .travel
            case 19...22:
                activityType = .leisure
            default:
                activityType = .personal
            }
            
            let activity = ActivitySummary(
                activityType: activityType,
                duration: audioFile.duration,
                startTime: audioFile.createdAt,
                endTime: audioFile.createdAt.addingTimeInterval(audioFile.duration),
                description: generateActivityDescription(activityType, duration: audioFile.duration),
                confidence: Double.random(in: 0.7...0.95)
            )
            
            activities.append(activity)
        }
        
        return activities.sorted { $0.startTime < $1.startTime }
    }
    
    private func analyzeLocations(audioFiles: [AudioFileInfo]) async throws -> [LocationSummary] {
        // Mock location analysis
        var locations: [LocationSummary] = []
        
        // Group audio files by location based on metadata
        let locationGroups = Dictionary(grouping: audioFiles) { audioFile in
            audioFile.metadata.location?.placeName ?? "不明な場所"
        }
        
        for (placeName, files) in locationGroups {
            guard let firstFile = files.first,
                  let location = firstFile.metadata.location else { continue }
            
            let totalDuration = files.reduce(0) { $0 + $1.duration }
            let startTime = files.map { $0.createdAt }.min() ?? Date()
            let endTime = files.map { $0.createdAt.addingTimeInterval($0.duration) }.max() ?? Date()
            
            let category = determineLocationCategory(placeName: placeName)
            
            let locationSummary = LocationSummary(
                placeName: placeName,
                duration: totalDuration,
                arrivalTime: startTime,
                departureTime: endTime,
                latitude: location.latitude,
                longitude: location.longitude,
                category: category
            )
            
            locations.append(locationSummary)
        }
        
        return locations.sorted { $0.arrivalTime < $1.arrivalTime }
    }
    
    private func extractKeyMoments(audioFiles: [AudioFileInfo]) async throws -> [KeyMoment] {
        // Mock key moment extraction
        var keyMoments: [KeyMoment] = []
        
        // Simulate AI-based key moment detection
        for audioFile in audioFiles {
            if Bool.random() { // 50% chance of having a key moment
                let categories: [KeyMomentCategory] = [.decision, .insight, .idea, .achievement]
                let category = categories.randomElement()!
                let importance: ImportanceLevel = [.medium, .high, .critical].randomElement()!
                
                let moment = KeyMoment(
                    timestamp: audioFile.createdAt.addingTimeInterval(Double.random(in: 0...audioFile.duration)),
                    title: generateKeyMomentTitle(category: category),
                    description: generateKeyMomentDescription(category: category),
                    category: category,
                    importance: importance,
                    relatedAudioFile: audioFile.id,
                    audioTimestamp: Double.random(in: 0...audioFile.duration)
                )
                
                keyMoments.append(moment)
            }
        }
        
        return keyMoments.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func generateInsights(
        audioFiles: [AudioFileInfo],
        activities: [ActivitySummary],
        locations: [LocationSummary],
        keyMoments: [KeyMoment]
    ) async throws -> [String] {
        
        var insights: [String] = []
        
        // Productivity insights
        let workActivities = activities.filter { $0.activityType == .work || $0.activityType == .meeting }
        let workDuration = workActivities.reduce(0) { $0 + $1.duration }
        
        if workDuration > 0 {
            let hours = Int(workDuration) / 3600
            insights.append("今日は\(hours)時間の仕事関連の活動がありました。")
        }
        
        // Meeting insights
        let meetings = activities.filter { $0.activityType == .meeting }
        if meetings.count > 3 {
            insights.append("今日は\(meetings.count)回の会議があり、非常に忙しい一日でした。")
        }
        
        // Location insights
        if locations.count > 5 {
            insights.append("今日は\(locations.count)か所を訪れ、活動的な一日でした。")
        }
        
        // Key moment insights
        let criticalMoments = keyMoments.filter { $0.importance == .critical }
        if !criticalMoments.isEmpty {
            insights.append("今日は\(criticalMoments.count)つの重要な瞬間がありました。")
        }
        
        return insights
    }
    
    private func analyzeMood(audioFiles: [AudioFileInfo]) async throws -> MoodInfo? {
        // Mock mood analysis
        // In a real implementation, this would analyze voice patterns, speech content, etc.
        
        guard !audioFiles.isEmpty else { return nil }
        
        let overallMoods: [MoodLevel] = [.positive, .neutral, .positive, .veryPositive]
        let energyLevels: [EnergyLevel] = [.medium, .high, .medium, .high]
        let stressLevels: [StressLevel] = [.low, .medium, .low, .low]
        
        return MoodInfo(
            overall: overallMoods.randomElement()!,
            energy: energyLevels.randomElement()!,
            stress: stressLevels.randomElement()!,
            confidence: Double.random(in: 0.7...0.9),
            notes: "音声分析に基づく推定値です。今日は全体的にポジティブな傾向が見られました。"
        )
    }
    
    private func exportLifelogEntry(_ entry: LifelogEntry) async {
        logger.log(level: .info, message: "Exporting lifelog entry", context: [
            "date": entry.date.description
        ])
        
        // Implementation would integrate with export system
        // For now, just log the action
        logger.log(level: .info, message: "Lifelog export completed")
    }
    
    private func checkForDataAsync() async {
        // Check if there's any data available for processing
        logger.log(level: .info, message: "Checking for available data")
        
        do {
            try await recordingManager.processUnprocessedRecordings()
            refreshData()
        } catch {
            errorMessage = "データ処理中にエラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateActivityDescription(_ activityType: ActivityType, duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        
        switch activityType {
        case .meeting:
            return "\(minutes)分間の会議または打ち合わせ"
        case .conversation:
            return "\(minutes)分間の会話"
        case .work:
            return "\(minutes)分間の作業時間"
        case .travel:
            return "\(minutes)分間の移動"
        case .personal:
            return "\(minutes)分間の個人的な時間"
        default:
            return "\(minutes)分間の\(activityType.displayName)"
        }
    }
    
    private func determineLocationCategory(placeName: String) -> LocationCategory {
        let name = placeName.lowercased()
        
        if name.contains("オフィス") || name.contains("会社") {
            return .office
        } else if name.contains("レストラン") || name.contains("カフェ") {
            return .restaurant
        } else if name.contains("駅") || name.contains("電車") {
            return .transport
        } else if name.contains("公園") || name.contains("屋外") {
            return .outdoor
        } else {
            return .unknown
        }
    }
    
    private func generateKeyMomentTitle(category: KeyMomentCategory) -> String {
        switch category {
        case .decision:
            return "重要な決定"
        case .insight:
            return "新しい洞察"
        case .idea:
            return "アイデアの発見"
        case .achievement:
            return "目標達成"
        case .meeting:
            return "重要な会議"
        case .problem:
            return "課題の特定"
        case .emotion:
            return "感情的な瞬間"
        case .learning:
            return "学習の機会"
        }
    }
    
    private func generateKeyMomentDescription(category: KeyMomentCategory) -> String {
        switch category {
        case .decision:
            return "プロジェクトの方向性について重要な決定が行われました。"
        case .insight:
            return "データ分析により新しい洞察が得られました。"
        case .idea:
            return "問題解決のための創造的なアイデアが生まれました。"
        case .achievement:
            return "設定していた目標を達成することができました。"
        case .meeting:
            return "ステークホルダーとの重要な協議が行われました。"
        case .problem:
            return "解決すべき課題が明確になりました。"
        case .emotion:
            return "感情的に重要な瞬間がありました。"
        case .learning:
            return "新しい知識やスキルを習得する機会がありました。"
        }
    }
}

// MARK: - Mock Services for Preview

class MockContinuousRecordingManager: ContinuousRecordingManagerProtocol {
    @Published var isRecording: Bool = false
    @Published var currentSession: RecordingSession?
    @Published var todaysSessions: [RecordingSession] = []
    @Published var storageUsage: StorageUsage = StorageUsage()
    
    func startContinuousRecording() async throws {}
    func stopContinuousRecording() async throws {}
    func pauseRecording() async throws {}
    func resumeRecording() async throws {}
    
    func getRecordingSessions(for date: Date) async throws -> [RecordingSession] {
        return generateMockSessions()
    }
    
    func getRecordingSessions(from startDate: Date, to endDate: Date) async throws -> [RecordingSession] {
        return generateMockSessions()
    }
    
    func deleteRecordingSession(_ sessionId: UUID) async throws {}
    func processUnprocessedRecordings() async throws {}
    func setRecordingQuality(_ quality: RecordingQuality) async throws {}
    func setAutoProcessing(_ enabled: Bool) async throws {}
    func setBatteryOptimization(_ enabled: Bool) async throws {}
    
    private func generateMockSessions() -> [RecordingSession] {
        let mockAudioFile = AudioFileInfo(
            fileName: "recording_001.wav",
            filePath: URL(fileURLWithPath: "/tmp/recording.wav"),
            duration: 1800,
            fileSize: 126_000_000,
            createdAt: Date(),
            sampleRate: 44100,
            channels: 1,
            format: .wav,
            transcriptionStatus: .completed
        )
        
        return [
            RecordingSession(
                id: UUID(),
                startTime: Date().addingTimeInterval(-7200),
                endTime: Date().addingTimeInterval(-5400),
                quality: .high,
                deviceId: "mock-device",
                status: .completed,
                audioFiles: [mockAudioFile],
                totalDuration: 1800,
                estimatedSize: 126_000_000
            )
        ]
    }
}

@MainActor
class MockLimitlessDeviceService: LimitlessDeviceServiceProtocol {
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var connectedDevice: LimitlessDevice?
    
    var isConnected: Bool {
        return connectionStatus == .connected
    }
    
    var currentDevice: LimitlessDevice? {
        return connectedDevice
    }
    @Published var discoveredDevices: [LimitlessDevice] = []
    @Published var isScanning: Bool = false
    
    func connectToDevice() async throws {}
    func disconnectFromDevice() async throws {}
    func getDeviceStatus() async throws -> DeviceStatus {
        return DeviceStatus(batteryLevel: 85, signalStrength: 4, isRecording: false, storageAvailable: 1024*1024*1024)
    }
    func sendCommand(_ command: DeviceCommand) async throws -> DeviceResponse {
        return DeviceResponse(success: true, data: [:], error: nil)
    }
    func startContinuousRecording() async throws {}
    func stopContinuousRecording() async throws {}
    func syncAudioFiles() async throws -> [AudioFileInfo] { return [] }
}

class MockFasterWhisperService: FasterWhisperServiceProtocol {
    func transcribe(audioFile: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        return TranscriptionResult(
            text: "Mock transcription",
            segments: [],
            detectedLanguage: "ja",
            languageConfidence: 0.95,
            audioDuration: 60,
            processingDuration: 5,
            modelUsed: "faster-whisper-turbo",
            averageConfidence: 0.9,
            alternativeLanguages: []
        )
    }
    
    func transcribeStream(audioStream: AsyncStream<Data>, options: TranscriptionOptions) async throws -> AsyncStream<TranscriptionSegment> {
        return AsyncStream { _ in }
    }
    
    func transcribeBatch(audioFiles: [URL], options: TranscriptionOptions) async throws -> [TranscriptionResult] {
        return []
    }
    
    func transcribeWithSpeakerDiarization(audioFile: URL, options: TranscriptionOptions, diarizationOptions: DiarizationOptions) async throws -> DiarizedTranscriptionResult {
        return DiarizedTranscriptionResult(
            transcriptionResult: TranscriptionResult(
                text: "Mock diarized transcription",
                segments: [],
                detectedLanguage: "ja",
                languageConfidence: 0.95,
                audioDuration: 60,
                processingDuration: 1.0,
                modelUsed: "mock",
                averageConfidence: 0.95,
                alternativeLanguages: nil
            ),
            diarizationResult: DiarizationResult(
                audioFile: audioFile,
                totalDuration: 60,
                speakerCount: 1,
                speakers: [],
                segments: [],
                confidence: 0.95,
                processingTime: 1.0
            ),
            speakerSegments: [],
            speakerCount: 1,
            totalDuration: 60,
            processingTime: 1.0
        )
    }
    
    func detectLanguage(audioFile: URL) async throws -> LanguageDetectionResult {
        return LanguageDetectionResult(detectedLanguage: "ja", confidence: 0.95, alternativeLanguages: [])
    }
    
    func getSupportedLanguages() -> [TranscriptionLanguage] { return [] }
    func getModelInfo() -> ModelInfo {
        return ModelInfo(name: "Mock", version: "1.0", size: "1MB", languages: 1, features: [], maxAudioLength: 3600, supportedFormats: [])
    }
}