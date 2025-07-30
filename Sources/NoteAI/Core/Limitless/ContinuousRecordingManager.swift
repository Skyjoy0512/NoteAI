import Foundation
import Combine

// MARK: - 常時録音データ管理サービス

@MainActor
protocol ContinuousRecordingManagerProtocol {
    var isRecording: Bool { get }
    var currentSession: RecordingSession? { get }
    var todaysSessions: [RecordingSession] { get }
    var storageUsage: StorageUsage { get }
    
    func startContinuousRecording() async throws
    func stopContinuousRecording() async throws
    func pauseRecording() async throws
    func resumeRecording() async throws
    
    func getRecordingSessions(for date: Date) async throws -> [RecordingSession]
    func getRecordingSessions(from startDate: Date, to endDate: Date) async throws -> [RecordingSession]
    func deleteRecordingSession(_ sessionId: UUID) async throws
    func processUnprocessedRecordings() async throws
    
    func setRecordingQuality(_ quality: RecordingQuality) async throws
    func setAutoProcessing(_ enabled: Bool) async throws
    func setBatteryOptimization(_ enabled: Bool) async throws
}

@MainActor
class ContinuousRecordingManager: ObservableObject, ContinuousRecordingManagerProtocol {
    
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var currentSession: RecordingSession?
    @Published var todaysSessions: [RecordingSession] = []
    @Published var storageUsage: StorageUsage = StorageUsage()
    
    // MARK: - Private Properties
    private let deviceService: any LimitlessDeviceServiceProtocol
    private let whisperService: FasterWhisperServiceProtocol
    private let fileManager = FileManager.default
    private let logger = RAGLogger.shared
    private let performanceMonitor = RAGPerformanceMonitor.shared
    
    private var recordingTimer: Timer?
    private var processingQueue = DispatchQueue(label: "recording.processing", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private struct Config {
        static let sessionInterval: TimeInterval = 3600 // 1 hour per session
        static let maxStorageSize: Int64 = 50 * 1024 * 1024 * 1024 // 50GB
        static let autoCleanupThreshold: Double = 0.9 // 90% storage usage
        static let processingBatchSize = 10
        static let retentionDays = 30
    }
    
    // MARK: - Settings
    private var recordingQuality: RecordingQuality = .high
    private var autoProcessingEnabled: Bool = true
    private var batteryOptimizationEnabled: Bool = true
    
    init(
        deviceService: any LimitlessDeviceServiceProtocol,
        whisperService: FasterWhisperServiceProtocol
    ) {
        self.deviceService = deviceService
        self.whisperService = whisperService
        
        setupObservers()
        loadTodaysSessions()
        updateStorageUsage()
    }
    
    // MARK: - Recording Control
    
    func startContinuousRecording() async throws {
        guard !isRecording else {
            logger.log(level: .warning, message: "Recording already in progress")
            return
        }
        
        logger.log(level: .info, message: "Starting continuous recording")
        
        // Check device connection
        guard deviceService.connectionStatus == .connected else {
            throw RecordingError.deviceNotConnected
        }
        
        // Check storage space
        try checkStorageSpace()
        
        // Start device recording
        try await deviceService.startContinuousRecording()
        
        // Create new recording session
        let session = RecordingSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            quality: recordingQuality,
            deviceId: deviceService.connectedDevice?.id.uuidString ?? "unknown",
            status: .recording,
            audioFiles: [],
            totalDuration: 0,
            estimatedSize: 0
        )
        
        currentSession = session
        isRecording = true
        
        // Start session timer
        startSessionTimer()
        
        logger.log(level: .info, message: "Continuous recording started", context: [
            "sessionId": session.id.uuidString,
            "quality": recordingQuality.rawValue
        ])
    }
    
    func stopContinuousRecording() async throws {
        guard isRecording else {
            logger.log(level: .warning, message: "No recording in progress")
            return
        }
        
        logger.log(level: .info, message: "Stopping continuous recording")
        
        // Stop device recording
        try await deviceService.stopContinuousRecording()
        
        // Finalize current session
        if var session = currentSession {
            session.endTime = Date()
            session.status = .completed
            session.totalDuration = session.endTime!.timeIntervalSince(session.startTime)
            
            currentSession = nil
            todaysSessions.append(session)
            
            // Sync and process final audio files
            await syncSessionAudioFiles(session)
        }
        
        isRecording = false
        stopSessionTimer()
        
        // Process new recordings if auto-processing is enabled
        if autoProcessingEnabled {
            Task {
                try await processUnprocessedRecordings()
            }
        }
        
        logger.log(level: .info, message: "Continuous recording stopped")
    }
    
    func pauseRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        logger.log(level: .info, message: "Pausing recording")
        
        // Implementation depends on device capabilities
        // For now, we'll stop and create a new session when resumed
        try await stopContinuousRecording()
        
        currentSession?.status = .paused
    }
    
    func resumeRecording() async throws {
        logger.log(level: .info, message: "Resuming recording")
        
        try await startContinuousRecording()
    }
    
    // MARK: - Data Retrieval
    
    func getRecordingSessions(for date: Date) async throws -> [RecordingSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try await getRecordingSessions(from: startOfDay, to: endOfDay)
    }
    
    func getRecordingSessions(from startDate: Date, to endDate: Date) async throws -> [RecordingSession] {
        // In a real implementation, this would query the database
        // For now, return mock data
        
        let mockSessions = generateMockSessions(from: startDate, to: endDate)
        
        logger.log(level: .debug, message: "Retrieved recording sessions", context: [
            "count": mockSessions.count,
            "startDate": startDate.description,
            "endDate": endDate.description
        ])
        
        return mockSessions
    }
    
    func deleteRecordingSession(_ sessionId: UUID) async throws {
        logger.log(level: .info, message: "Deleting recording session", context: [
            "sessionId": sessionId.uuidString
        ])
        
        // Remove from today's sessions
        todaysSessions.removeAll { $0.id == sessionId }
        
        // Delete audio files
        // In a real implementation, this would delete from storage
        
        updateStorageUsage()
        
        logger.log(level: .info, message: "Recording session deleted")
    }
    
    // MARK: - Processing
    
    func processUnprocessedRecordings() async throws {
        logger.log(level: .info, message: "Processing unprocessed recordings")
        
        let measurement = performanceMonitor.startMeasurement()
        
        // Get unprocessed audio files
        let unprocessedFiles = await getUnprocessedAudioFiles()
        
        guard !unprocessedFiles.isEmpty else {
            logger.log(level: .debug, message: "No unprocessed recordings found")
            return
        }
        
        logger.log(level: .info, message: "Found unprocessed recordings", context: [
            "count": unprocessedFiles.count
        ])
        
        // Process files in batches
        let batches: [[AudioFileInfo]] = Array(unprocessedFiles).chunked(into: Config.processingBatchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            logger.log(level: .debug, message: "Processing batch", context: [
                "batch": batchIndex + 1,
                "totalBatches": batches.count,
                "filesInBatch": batch.count
            ])
            
            await processBatch(batch)
        }
        
        performanceMonitor.recordMetric(
            operation: "processUnprocessedRecordings",
            measurement: measurement,
            success: true,
            metadata: [
                "fileCount": unprocessedFiles.count,
                "batchCount": batches.count
            ]
        )
        
        logger.log(level: .info, message: "Processing completed", context: [
            "processedFiles": unprocessedFiles.count
        ])
    }
    
    // MARK: - Settings
    
    func setRecordingQuality(_ quality: RecordingQuality) async throws {
        logger.log(level: .info, message: "Setting recording quality", context: [
            "quality": quality.rawValue
        ])
        
        recordingQuality = quality
        
        // Update device settings if connected
        if deviceService.connectionStatus == .connected {
            let command = DeviceCommand(
                type: .setRecordingQuality,
                parameters: [
                    "quality": quality.rawValue,
                    "sampleRate": quality.sampleRate,
                    "bitRate": quality.bitRate
                ]
            )
            
            let _ = try await deviceService.sendCommand(command)
        }
    }
    
    func setAutoProcessing(_ enabled: Bool) async throws {
        logger.log(level: .info, message: "Setting auto-processing", context: [
            "enabled": enabled
        ])
        
        autoProcessingEnabled = enabled
    }
    
    func setBatteryOptimization(_ enabled: Bool) async throws {
        logger.log(level: .info, message: "Setting battery optimization", context: [
            "enabled": enabled
        ])
        
        batteryOptimizationEnabled = enabled
        
        // Update device settings
        if deviceService.connectionStatus == .connected {
            let command = DeviceCommand(
                type: .setBatteryOptimization,
                parameters: ["enabled": enabled]
            )
            
            let _ = try await deviceService.sendCommand(command)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe device connection status changes
        // Note: Using a simple timer-based approach due to objectWillChange compatibility issues
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleDeviceStatusChange()
            }
        }
    }
    
    private func handleDeviceStatusChange() {
        if deviceService.connectionStatus == .disconnected && isRecording {
            Task {
                try? await stopContinuousRecording()
            }
        }
    }
    
    private func startSessionTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: Config.sessionInterval, repeats: true) { _ in
            Task { await self.rotateSession() }
        }
    }
    
    private func stopSessionTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func rotateSession() async {
        guard isRecording, let currentSession = currentSession else { return }
        
        logger.log(level: .info, message: "Rotating recording session", context: [
            "currentSessionId": currentSession.id.uuidString
        ])
        
        // Finalize current session
        var finishedSession = currentSession
        finishedSession.endTime = Date()
        finishedSession.status = .completed
        finishedSession.totalDuration = finishedSession.endTime!.timeIntervalSince(finishedSession.startTime)
        
        // Sync audio files for the finished session
        await syncSessionAudioFiles(finishedSession)
        
        todaysSessions.append(finishedSession)
        
        // Start new session
        let newSession = RecordingSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            quality: recordingQuality,
            deviceId: deviceService.connectedDevice?.id.uuidString ?? "unknown",
            status: .recording,
            audioFiles: [],
            totalDuration: 0,
            estimatedSize: 0
        )
        
        self.currentSession = newSession
        
        logger.log(level: .info, message: "Session rotated", context: [
            "newSessionId": newSession.id.uuidString
        ])
    }
    
    private func syncSessionAudioFiles(_ session: RecordingSession) async {
        do {
            let audioFiles = try await deviceService.syncAudioFiles()
            
            // Update session with synced files
            var updatedSession = session
            updatedSession.audioFiles = audioFiles
            updatedSession.estimatedSize = audioFiles.reduce(0) { $0 + $1.fileSize }
            
            // Update in todaysSessions if it exists there
            if let index = todaysSessions.firstIndex(where: { $0.id == session.id }) {
                todaysSessions[index] = updatedSession
            }
            
            updateStorageUsage()
            
        } catch {
            logger.log(level: .error, message: "Failed to sync audio files", context: [
                "sessionId": session.id.uuidString,
                "error": error.localizedDescription
            ])
        }
    }
    
    private func loadTodaysSessions() {
        // In a real implementation, load from database
        let today = Date()
        
        Task {
            do {
                let sessions = try await getRecordingSessions(for: today)
                await MainActor.run {
                    self.todaysSessions = sessions
                }
            } catch {
                logger.log(level: .error, message: "Failed to load today's sessions", context: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    private func updateStorageUsage() {
        Task {
            let totalSize = calculateTotalStorageUsage()
            let availableSpace = getAvailableStorageSpace()
            
            await MainActor.run {
                self.storageUsage = StorageUsage(
                    totalUsed: totalSize,
                    totalAvailable: availableSpace,
                    audioFiles: totalSize,
                    transcripts: 0,
                    cache: 0
                )
            }
        }
    }
    
    private func calculateTotalStorageUsage() -> Int64 {
        let totalSessionSize = todaysSessions.reduce(0) { $0 + $1.estimatedSize }
        return totalSessionSize
    }
    
    private func getAvailableStorageSpace() -> Int64 {
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber
            return freeSpace?.int64Value ?? 0
        } catch {
            return 0
        }
    }
    
    private func checkStorageSpace() throws {
        let availableSpace = getAvailableStorageSpace()
        let usedSpace = calculateTotalStorageUsage()
        let usageRatio = Double(usedSpace) / Double(availableSpace + usedSpace)
        
        if usageRatio > Config.autoCleanupThreshold {
            logger.log(level: .warning, message: "Storage usage high", context: [
                "usageRatio": usageRatio,
                "threshold": Config.autoCleanupThreshold
            ])
            
            // Trigger cleanup
            Task {
                await performAutoCleanup()
            }
        }
        
        if availableSpace < 1024 * 1024 * 1024 { // Less than 1GB
            throw RecordingError.insufficientStorage(availableSpace)
        }
    }
    
    private func performAutoCleanup() async {
        logger.log(level: .info, message: "Performing auto cleanup")
        
        // Delete old recordings beyond retention period
        let cutoffDate = Date().addingTimeInterval(-Double(Config.retentionDays) * 24 * 3600)
        
        do {
            let oldSessions = try await getRecordingSessions(from: Date.distantPast, to: cutoffDate)
            
            for session in oldSessions {
                try await deleteRecordingSession(session.id)
            }
            
            logger.log(level: .info, message: "Auto cleanup completed", context: [
                "deletedSessions": oldSessions.count
            ])
            
        } catch {
            logger.log(level: .error, message: "Auto cleanup failed", context: [
                "error": error.localizedDescription
            ])
        }
    }
    
    private func getUnprocessedAudioFiles() async -> [AudioFileInfo] {
        // Get all audio files that haven't been transcribed yet
        let allFiles = todaysSessions.flatMap { $0.audioFiles }
        return allFiles.filter { $0.transcriptionStatus == .pending }
    }
    
    private func processBatch(_ audioFiles: [AudioFileInfo]) async {
        await withTaskGroup(of: Void.self) { group in
            for audioFile in audioFiles {
                group.addTask {
                    await self.processAudioFile(audioFile)
                }
            }
        }
    }
    
    private func processAudioFile(_ audioFile: AudioFileInfo) async {
        do {
            logger.log(level: .debug, message: "Processing audio file", context: [
                "fileName": audioFile.fileName
            ])
            
            let options = TranscriptionOptions(
                language: "ja", // Default to Japanese
                wordTimestamps: true,
                vadFilter: true
            )
            
            let result = try await whisperService.transcribe(audioFile: audioFile.filePath, options: options)
            
            logger.log(level: .debug, message: "Audio file processed", context: [
                "fileName": audioFile.fileName,
                "confidence": result.averageConfidence,
                "duration": result.audioDuration
            ])
            
            // Update file status
            // In a real implementation, update in database
            
        } catch {
            logger.log(level: .error, message: "Failed to process audio file", context: [
                "fileName": audioFile.fileName,
                "error": error.localizedDescription
            ])
        }
    }
    
    private func generateMockSessions(from startDate: Date, to endDate: Date) -> [RecordingSession] {
        var sessions: [RecordingSession] = []
        let calendar = Calendar.current
        
        var currentDate = startDate
        while currentDate < endDate {
            let sessionStart = currentDate
            let sessionEnd = calendar.date(byAdding: .hour, value: 1, to: sessionStart)!
            
            if sessionEnd <= endDate {
                let session = RecordingSession(
                    id: UUID(),
                    startTime: sessionStart,
                    endTime: sessionEnd,
                    quality: .high,
                    deviceId: "mock-device",
                    status: .completed,
                    audioFiles: [],
                    totalDuration: 3600,
                    estimatedSize: 126_000_000
                )
                
                sessions.append(session)
            }
            
            currentDate = calendar.date(byAdding: .hour, value: 2, to: currentDate)!
        }
        
        return sessions
    }
}

// MARK: - Supporting Types

struct RecordingSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let quality: RecordingQuality
    let deviceId: String
    var status: RecordingStatus
    var audioFiles: [AudioFileInfo]
    var totalDuration: TimeInterval
    var estimatedSize: Int64
    
    var isActive: Bool {
        return status == .recording || status == .paused
    }
    
    var actualDuration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }
}

enum RecordingQuality: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    var displayName: String {
        switch self {
        case .low:
            return "低品質"
        case .medium:
            return "標準"
        case .high:
            return "高品質"
        case .lossless:
            return "ロスレス"
        }
    }
    
    var sampleRate: Int {
        switch self {
        case .low:
            return 16000
        case .medium:
            return 22050
        case .high:
            return 44100
        case .lossless:
            return 48000
        }
    }
    
    var bitRate: Int {
        switch self {
        case .low:
            return 64
        case .medium:
            return 128
        case .high:
            return 256
        case .lossless:
            return 1411
        }
    }
    
    var estimatedSizePerHour: Int64 {
        switch self {
        case .low:
            return 30 * 1024 * 1024 // 30MB
        case .medium:
            return 60 * 1024 * 1024 // 60MB
        case .high:
            return 126 * 1024 * 1024 // 126MB
        case .lossless:
            return 500 * 1024 * 1024 // 500MB
        }
    }
}

enum RecordingStatus: String, CaseIterable, Codable {
    case recording = "recording"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case processing = "processing"
    
    var displayName: String {
        switch self {
        case .recording:
            return "録音中"
        case .paused:
            return "一時停止"
        case .completed:
            return "完了"
        case .failed:
            return "失敗"
        case .processing:
            return "処理中"
        }
    }
    
    var color: String {
        switch self {
        case .recording:
            return "red"
        case .paused:
            return "orange"
        case .completed:
            return "green"
        case .failed:
            return "red"
        case .processing:
            return "blue"
        }
    }
}

struct StorageUsage: Codable {
    let totalUsed: Int64
    let totalAvailable: Int64
    let audioFiles: Int64
    let transcripts: Int64
    let cache: Int64
    
    init(
        totalUsed: Int64 = 0,
        totalAvailable: Int64 = 0,
        audioFiles: Int64 = 0,
        transcripts: Int64 = 0,
        cache: Int64 = 0
    ) {
        self.totalUsed = totalUsed
        self.totalAvailable = totalAvailable
        self.audioFiles = audioFiles
        self.transcripts = transcripts
        self.cache = cache
    }
    
    var usagePercentage: Double {
        guard totalAvailable > 0 else { return 0 }
        return Double(totalUsed) / Double(totalUsed + totalAvailable)
    }
    
    var formattedTotalUsed: String {
        return ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file)
    }
    
    var formattedTotalAvailable: String {
        return ByteCountFormatter.string(fromByteCount: totalAvailable, countStyle: .file)
    }
}

enum RecordingError: Error, LocalizedError {
    case deviceNotConnected
    case notRecording
    case insufficientStorage(Int64)
    case recordingInProgress
    case sessionNotFound
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotConnected:
            return "デバイスが接続されていません"
        case .notRecording:
            return "録音していません"
        case .insufficientStorage(let available):
            let formatted = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "ストレージ容量が不足しています (利用可能: \(formatted))"
        case .recordingInProgress:
            return "録音が既に進行中です"
        case .sessionNotFound:
            return "録音セッションが見つかりません"
        case .processingFailed(let reason):
            return "処理に失敗しました: \(reason)"
        }
    }
}

// MARK: - Array Extension
// chunked(into:) extension already defined elsewhere