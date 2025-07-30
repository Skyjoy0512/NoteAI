import Foundation
import SwiftUI
import Combine

// MARK: - Base ViewModel for Limitless Views

@MainActor
class LimitlessBaseViewModel: ObservableObject {
    
    // MARK: - Common Properties
    @Published var isLoading = false
    @Published var currentError: LimitlessError?
    @Published var selectedDate = Date()
    
    // MARK: - Dependencies
    internal let deviceService: any LimitlessDeviceServiceProtocol
    internal let recordingManager: ContinuousRecordingManagerProtocol
    internal let whisperService: FasterWhisperServiceProtocol
    internal let settings = LimitlessSettings.shared
    internal let logger = RAGLogger.shared
    internal let performanceMonitor = RAGPerformanceMonitor.shared
    
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        deviceService: any LimitlessDeviceServiceProtocol,
        recordingManager: ContinuousRecordingManagerProtocol,
        whisperService: FasterWhisperServiceProtocol
    ) {
        self.deviceService = deviceService
        self.recordingManager = recordingManager
        self.whisperService = whisperService
        
        setupCommonObservers()
    }
    
    // For SwiftUI Preview and testing
    convenience init() {
        self.init(
            deviceService: MockLimitlessDeviceService(),
            recordingManager: MockContinuousRecordingManager(),
            whisperService: MockFasterWhisperService()
        )
    }
    
    // MARK: - Common Methods
    
    func handleError(_ error: Error) {
        let limitlessError: LimitlessError
        
        switch error {
        case let deviceError as DeviceError:
            limitlessError = .deviceError(deviceError)
        case let recordingError as RecordingError:
            limitlessError = .recordingError(recordingError)
        case let whisperError as WhisperError:
            limitlessError = .transcriptionError(whisperError)
        case let validationError as ValidationError:
            limitlessError = .validationError(validationError)
        default:
            limitlessError = .unknownError(error.localizedDescription)
        }
        
        currentError = limitlessError
        logger.log(level: .error, message: "Error in \(type(of: self))", context: [
            "error": error.localizedDescription
        ])
    }
    
    func clearError() {
        currentError = nil
    }
    
    func performWithLoading<T>(_ operation: @escaping () async throws -> T) async -> T? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            return try await operation()
        } catch {
            handleError(error)
            return nil
        }
    }
    
    func retryOperation<T>(_ operation: @escaping () async throws -> T, maxAttempts: Int = 3) async -> T? {
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                if attempt == maxAttempts {
                    handleError(error)
                    return nil
                }
                
                // Exponential backoff
                let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        return nil
    }
    
    // MARK: - Date Navigation
    
    func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    func nextDay() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if tomorrow <= Date() {
            selectedDate = tomorrow
        }
    }
    
    func selectToday() {
        selectedDate = Date()
    }
    
    // MARK: - Setup Methods
    
    private func setupCommonObservers() {
        // Device service error handling
        if let deviceService = deviceService as? LimitlessDeviceService {
            deviceService.$lastError
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] error in
                    self?.currentError = error
                }
                .store(in: &cancellables)
        }
        
        // Settings changes
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }
    
    internal func handleSettingsChange() {
        // Override in subclasses
    }
}

// MARK: - Enhanced LifelogViewModel

@MainActor
class LifelogViewModelRefactored: LimitlessBaseViewModel {
    
    // MARK: - Published Properties
    @Published var currentLifelogEntry: LifelogEntry?
    @Published var displayFilter = DisplayFilter()
    @Published var insights: [LifelogInsight] = []
    @Published var moodTrend: MoodTrend?
    
    // MARK: - Private Properties
    private let ragService: RAGServiceProtocol
    private let analyticsEngine = LifelogAnalyticsEngine()
    
    // MARK: - Initialization
    
    init(
        deviceService: any LimitlessDeviceServiceProtocol,
        recordingManager: ContinuousRecordingManagerProtocol,
        whisperService: FasterWhisperServiceProtocol,
        ragService: RAGServiceProtocol
    ) {
        self.ragService = ragService
        super.init(
            deviceService: deviceService,
            recordingManager: recordingManager,
            whisperService: whisperService
        )
        
        setupLifelogObservers()
    }
    
    convenience init() {
        self.init(
            deviceService: MockLimitlessDeviceService(),
            recordingManager: MockContinuousRecordingManager(),
            whisperService: MockFasterWhisperService(),
            ragService: MockRAGService()
        )
    }
    
    // MARK: - Public Methods
    
    func loadLifelogEntry(for date: Date) {
        Task {
            await performWithLoading {
                try await self.loadLifelogEntryAsync(for: date)
            }
        }
    }
    
    func refreshData() {
        guard let currentDate = currentLifelogEntry?.date else { return }
        loadLifelogEntry(for: currentDate)
    }
    
    func exportLifelog() async {
        guard let entry = currentLifelogEntry else { return }
        
        await performWithLoading {
            try await self.exportLifelogEntry(entry)
        }
    }
    
    func generateInsights() async {
        guard let entry = currentLifelogEntry else { return }
        
        await performWithLoading {
            try await self.generateLifelogInsights(entry)
        }
    }
    
    func updateFilter(_ filter: DisplayFilter) {
        displayFilter = filter
        applyFilter()
    }
    
    // MARK: - Private Methods
    
    private func setupLifelogObservers() {
        // Recording manager state changes
        // Note: objectWillChange not available for protocol types in minimal build
        // Using alternative approach for minimal build compatibility
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRecordingUpdate()
            }
            .store(in: &cancellables)
        
        // Selected date changes
        $selectedDate
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] date in
                self?.loadLifelogEntry(for: date)
            }
            .store(in: &cancellables)
    }
    
    private func handleRecordingUpdate() {
        // Refresh lifelog when new recordings are available
        refreshData()
    }
    
    private func loadLifelogEntryAsync(for date: Date) async throws {
        let measurement = PerformanceMeasurement(startTime: Date())
        defer { _ = measurement.duration }
        
        logger.log(level: .info, message: "Loading lifelog entry", context: [
            "date": FormatUtils.formatDate(date)
        ])
        
        // Get recording sessions for the date
        let sessions = try await recordingManager.getRecordingSessions(for: date)
        
        // Aggregate audio files from all sessions
        let audioFiles = sessions.flatMap { $0.audioFiles }
        
        // Calculate total duration
        let totalDuration = audioFiles.reduce(0) { $0 + $1.duration }
        
        // Generate lifelog entry using analytics engine
        let entry = try await analyticsEngine.generateLifelogEntry(
            date: date,
            audioFiles: audioFiles,
            totalDuration: totalDuration,
            whisperService: whisperService,
            ragService: ragService
        )
        
        currentLifelogEntry = entry
        
        // Generate additional insights
        try await generateLifelogInsights(entry)
        
        logger.log(level: .info, message: "Lifelog entry loaded", context: [
            "audioFiles": audioFiles.count,
            "activities": entry.activities.count,
            "locations": entry.locations.count,
            "keyMoments": entry.keyMoments.count
        ])
    }
    
    private func generateLifelogInsights(_ entry: LifelogEntry) async throws {
        let generatedInsights = try await analyticsEngine.generateInsights(
            entry: entry,
            historicalData: await getHistoricalData(),
            ragService: ragService
        )
        
        insights = generatedInsights
        
        // Generate mood trend
        moodTrend = try await analyticsEngine.generateMoodTrend(
            currentEntry: entry,
            historicalData: await getHistoricalData()
        )
    }
    
    private func exportLifelogEntry(_ entry: LifelogEntry) async throws {
        logger.log(level: .info, message: "Exporting lifelog entry", context: [
            "date": FormatUtils.formatDate(entry.date)
        ])
        
        // Implementation would integrate with export system
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate export
        
        logger.log(level: .info, message: "Lifelog export completed")
    }
    
    private func applyFilter() {
        // Apply filter to current entry
        guard currentLifelogEntry != nil else { return }
        
        // Filter activities, locations, key moments based on displayFilter
        // Implementation depends on filter criteria
    }
    
    private func getHistoricalData() async -> [LifelogEntry] {
        // Get historical lifelog entries for trend analysis
        // Mock implementation
        return []
    }
    
    override func handleSettingsChange() {
        // Respond to settings changes
        refreshData()
    }
}

// MARK: - Enhanced AudioFilesViewModel

@MainActor
class AudioFilesViewModelRefactored: LimitlessBaseViewModel {
    
    // MARK: - Published Properties
    @Published var audioFiles: [AudioFileInfo] = []
    @Published var filteredAudioFiles: [AudioFileInfo] = []
    @Published var currentFilter = AudioFileFilter()
    @Published var searchText = ""
    @Published var selectedTimeRange: TimeRange = .today
    @Published var groupedAudioFiles: [String: [AudioFileInfo]] = [:]
    
    // MARK: - Private Properties
    private let audioFileManager: AudioFileManagerProtocol
    private let transcriptionService: TranscriptionServiceProtocol?
    private let filterEngine = AudioFileFilterEngine()
    
    // MARK: - Initialization
    
    init(
        deviceService: any LimitlessDeviceServiceProtocol,
        recordingManager: ContinuousRecordingManagerProtocol,
        whisperService: FasterWhisperServiceProtocol,
        audioFileManager: AudioFileManagerProtocol,
        transcriptionService: TranscriptionServiceProtocol? = nil
    ) {
        self.audioFileManager = audioFileManager
        self.transcriptionService = transcriptionService
        
        super.init(
            deviceService: deviceService,
            recordingManager: recordingManager,
            whisperService: whisperService
        )
        
        setupAudioFilesObservers()
    }
    
    convenience init() {
        self.init(
            deviceService: MockLimitlessDeviceService(),
            recordingManager: MockContinuousRecordingManager(),
            whisperService: MockFasterWhisperService(),
            audioFileManager: MockAudioFileManager()
        )
    }
    
    // MARK: - Public Methods
    
    func loadAudioFiles(for date: Date) {
        Task {
            await performWithLoading {
                try await self.loadAudioFilesAsync(for: date)
            }
        }
    }
    
    func applyFilter() {
        Task {
            await self.applyFilterAsync()
        }
    }
    
    func transcribeAudioFile(_ audioFile: AudioFileInfo) {
        Task {
            await performWithLoading {
                try await self.transcribeAudioFileAsync(audioFile)
            }
        }
    }
    
    func startBatchTranscription() {
        Task {
            let pendingFiles = self.audioFiles.filter { $0.transcriptionStatus == .pending }
            await performWithLoading {
                try await self.batchTranscribe(pendingFiles)
            }
        }
    }
    
    func deleteAudioFile(_ audioFile: AudioFileInfo) {
        Task {
            await performWithLoading {
                try await self.deleteAudioFileAsync(audioFile)
            }
        }
    }
    
    func shareAudioFile(_ audioFile: AudioFileInfo) {
        // Implementation for sharing
        logger.log(level: .info, message: "Sharing audio file", context: [
            "fileName": audioFile.fileName
        ])
    }
    
    func exportAudioFiles() {
        Task {
            await performWithLoading {
                try await self.exportSelectedFiles()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioFilesObservers() {
        // Search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.applyFilterAsync() }
            }
            .store(in: &cancellables)
        
        // Filter changes
        $currentFilter
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.applyFilterAsync() }
            }
            .store(in: &cancellables)
        
        // Selected date changes
        $selectedDate
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] date in
                self?.loadAudioFiles(for: date)
            }
            .store(in: &cancellables)
        
        // Time range changes
        $selectedTimeRange
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateDateForTimeRange()
            }
            .store(in: &cancellables)
    }
    
    private func loadAudioFilesAsync(for date: Date) async throws {
        let measurement = PerformanceMeasurement(startTime: Date())
        defer { _ = measurement.duration }
        
        logger.log(level: .info, message: "Loading audio files", context: [
            "date": FormatUtils.formatDate(date)
        ])
        
        // Get recording sessions for the date
        let sessions = try await recordingManager.getRecordingSessions(for: date)
        
        // Aggregate audio files from all sessions
        let allFiles = sessions.flatMap { $0.audioFiles }
        
        audioFiles = allFiles.sorted { $0.createdAt > $1.createdAt }
        
        await applyFilterAsync()
        
        logger.log(level: .info, message: "Audio files loaded", context: [
            "count": allFiles.count
        ])
    }
    
    private func applyFilterAsync() async {
        let filtered = await filterEngine.applyFilter(
            currentFilter,
            to: audioFiles,
            searchText: searchText
        )
        
        filteredAudioFiles = filtered
        groupedAudioFiles = AudioFileGrouper.groupByTimeOfDay(filtered)
    }
    
    private func transcribeAudioFileAsync(_ audioFile: AudioFileInfo) async throws {
        logger.log(level: .info, message: "Transcribing audio file", context: [
            "fileName": audioFile.fileName
        ])
        
        let options = TranscriptionOptions(
            language: "ja",
            wordTimestamps: true,
            vadFilter: true
        )
        
        let result = try await whisperService.transcribe(
            audioFile: audioFile.filePath,
            options: options
        )
        
        // Update transcription status
        // In real implementation, update in database
        
        logger.log(level: .info, message: "Transcription completed", context: [
            "fileName": audioFile.fileName,
            "confidence": result.averageConfidence
        ])
    }
    
    private func batchTranscribe(_ audioFiles: [AudioFileInfo]) async throws {
        logger.log(level: .info, message: "Starting batch transcription", context: [
            "fileCount": audioFiles.count
        ])
        
        let urls = audioFiles.map { $0.filePath }
        let options = TranscriptionOptions(
            language: "ja",
            wordTimestamps: true,
            vadFilter: true
        )
        
        let results = try await whisperService.transcribeBatch(
            audioFiles: urls,
            options: options
        )
        
        logger.log(level: .info, message: "Batch transcription completed", context: [
            "successCount": results.count
        ])
    }
    
    private func deleteAudioFileAsync(_ audioFile: AudioFileInfo) async throws {
        logger.log(level: .info, message: "Deleting audio file", context: [
            "fileName": audioFile.fileName
        ])
        
        // Remove from local array
        audioFiles.removeAll { $0.id == audioFile.id }
        
        // Delete from storage
        try await audioFileManager.deleteAudioFile(at: audioFile.filePath)
        
        await applyFilterAsync()
    }
    
    private func exportSelectedFiles() async throws {
        logger.log(level: .info, message: "Exporting audio files", context: [
            "count": filteredAudioFiles.count
        ])
        
        // Implementation for export
        try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate export
        
        logger.log(level: .info, message: "Export completed")
    }
    
    private func updateDateForTimeRange() {
        switch selectedTimeRange {
        case .today:
            selectedDate = Date()
        case .yesterday:
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        case .lastWeek:
            selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        case .lastMonth:
            selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .custom:
            // Custom date handled by date picker
            break
        }
    }
}

// MARK: - Supporting Types

enum TimeRange: String, CaseIterable {
    case today = "today"
    case yesterday = "yesterday"
    case lastWeek = "lastWeek"
    case lastMonth = "lastMonth"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .today: return "今日"
        case .yesterday: return "昨日"
        case .lastWeek: return "先週"
        case .lastMonth: return "先月"
        case .custom: return "カスタム"
        }
    }
}

struct LifelogInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let actionable: Bool
    let relatedData: [String: Any]
}

enum LimitlessInsightType {
    case productivity
    case wellness
    case social
    case learning
    case habit
}

struct MoodTrend {
    let currentMood: MoodInfo
    let trend: LimitlessTrendDirection
    let weeklyAverage: Double
    let insights: [String]
}

enum LimitlessTrendDirection {
    case improving
    case stable
    case declining
}

// MARK: - Mock Services

private class MockAudioFileManager: AudioFileManagerProtocol {
    func saveSecureAudioFile(_ data: Data, filename: String) throws -> URL {
        return URL(fileURLWithPath: "/tmp/\(filename)")
    }
    
    func loadAudioFile(from url: URL) throws -> Data {
        return Data()
    }
    
    func deleteAudioFile(at url: URL) throws {
        // Mock implementation
    }
    
    func getAudioFileSize(at url: URL) throws -> Int64 {
        return 1024
    }
    
    func getAllAudioFiles() throws -> [URL] {
        return []
    }
    
    func getAvailableStorage() throws -> Int64 {
        return 1024 * 1024 * 1024 // 1GB
    }
    
    func cleanupOldFiles(olderThan date: Date) throws {
        // Mock implementation
    }
    
    func exportAudioFile(from url: URL, to destinationURL: URL) throws {
        // Mock implementation
    }
    
    func deleteAudioFile(_ id: UUID) async throws {
        // Mock implementation for legacy interface
    }
}

// MARK: - Analytics Engine

private class LifelogAnalyticsEngine {
    func generateLifelogEntry(
        date: Date,
        audioFiles: [AudioFileInfo],
        totalDuration: TimeInterval,
        whisperService: FasterWhisperServiceProtocol,
        ragService: RAGServiceProtocol
    ) async throws -> LifelogEntry {
        // Enhanced lifelog generation with AI analysis
        // This would integrate with the RAG service for better insights
        
        // Mock implementation for now
        return LifelogEntry(
            date: date,
            audioFiles: audioFiles,
            totalDuration: totalDuration,
            transcriptSummary: "AI生成サマリー",
            activities: [],
            locations: [],
            keyMoments: [],
            insights: [],
            mood: nil
        )
    }
    
    func generateInsights(
        entry: LifelogEntry,
        historicalData: [LifelogEntry],
        ragService: RAGServiceProtocol
    ) async throws -> [LifelogInsight] {
        // Generate AI-powered insights
        return []
    }
    
    func generateMoodTrend(
        currentEntry: LifelogEntry,
        historicalData: [LifelogEntry]
    ) async throws -> MoodTrend? {
        // Generate mood trend analysis
        return nil
    }
}

private class AudioFileFilterEngine {
    func applyFilter(
        _ filter: AudioFileFilter,
        to audioFiles: [AudioFileInfo],
        searchText: String
    ) async -> [AudioFileInfo] {
        var filtered = audioFiles
        
        // Apply transcription status filter
        if !filter.transcriptionStatuses.isEmpty {
            filtered = filtered.filter { filter.transcriptionStatuses.contains($0.transcriptionStatus) }
        }
        
        // Apply format filter
        if !filter.audioFormats.isEmpty {
            filtered = filtered.filter { filter.audioFormats.contains($0.format) }
        }
        
        // Apply duration filter
        filtered = filtered.filter { audioFile in
            audioFile.duration >= filter.minDuration && audioFile.duration <= filter.maxDuration
        }
        
        // Apply activity type filter
        if !filter.activityTypes.isEmpty {
            filtered = filtered.filter { audioFile in
                guard let activityType = audioFile.metadata.environment?.activityType else { return false }
                return filter.activityTypes.contains(activityType)
            }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter { audioFile in
                audioFile.fileName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Favorites filter removed - not available in AudioFileFilter
        
        return filtered
    }
}