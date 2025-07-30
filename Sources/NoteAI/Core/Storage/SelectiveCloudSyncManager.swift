import Foundation
import SwiftUI
import Combine

// MARK: - 選択的クラウド同期管理システム

@MainActor
class SelectiveCloudSyncManager: ObservableObject {
    
    static let shared = SelectiveCloudSyncManager()
    
    // MARK: - Published Properties
    
    @Published var syncEnabled: Bool {
        didSet { saveSyncSettings() }
    }
    
    @Published var syncScope: SyncScope {
        didSet { saveSyncSettings() }
    }
    
    @Published var autoSyncEnabled: Bool {
        didSet { saveSyncSettings() }
    }
    
    @Published var wifiOnlySync: Bool {
        didSet { saveSyncSettings() }
    }
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var syncProgress: Double = 0.0
    
    // MARK: - Sync Configuration
    
    enum SyncScope: String, CaseIterable {
        case disabled = "disabled"
        case metadataOnly = "metadataOnly"
        case summarySync = "summarySync"
        case fullSync = "fullSync"
        
        var displayName: String {
            switch self {
            case .disabled:
                return "同期無効"
            case .metadataOnly:
                return "メタデータのみ"
            case .summarySync:
                return "要約データ"
            case .fullSync:
                return "完全同期"
            }
        }
        
        var description: String {
            switch self {
            case .disabled:
                return "クラウド同期を行いません"
            case .metadataOnly:
                return "プロジェクト情報とファイル名のみ同期"
            case .summarySync:
                return "メタデータ + 文字起こし要約を同期"
            case .fullSync:
                return "全ての文字起こし結果を同期（有料プランのみ）"
            }
        }
        
        var maxDataSize: Int64 {
            switch self {
            case .disabled:
                return 0
            case .metadataOnly:
                return 1024 // 1KB
            case .summarySync:
                return 10 * 1024 // 10KB
            case .fullSync:
                return 1024 * 1024 // 1MB
            }
        }
        
        var isPremiumFeature: Bool {
            return self == .fullSync
        }
    }
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case completed
        case failed(Error)
        case paused
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.syncing, .syncing),
                 (.completed, .completed),
                 (.paused, .paused):
                return true
            case (.failed, .failed):
                return true // 簡略化
            default:
                return false
            }
        }
        
        var displayName: String {
            switch self {
            case .idle:
                return "待機中"
            case .syncing:
                return "同期中"
            case .completed:
                return "完了"
            case .failed:
                return "エラー"
            case .paused:
                return "一時停止"
            }
        }
        
        var color: Color {
            switch self {
            case .idle:
                return .secondary
            case .syncing:
                return .blue
            case .completed:
                return .green
            case .failed:
                return .red
            case .paused:
                return .orange
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let networkMonitor = NetworkMonitor()
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration Keys
    
    private struct UserDefaultsKeys {
        static let syncEnabled = "SelectiveCloudSync.enabled"
        static let syncScope = "SelectiveCloudSync.scope"
        static let autoSyncEnabled = "SelectiveCloudSync.autoSync"
        static let wifiOnlySync = "SelectiveCloudSync.wifiOnly"
        static let lastSyncDate = "SelectiveCloudSync.lastSync"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved settings
        self.syncEnabled = userDefaults.bool(forKey: UserDefaultsKeys.syncEnabled)
        self.autoSyncEnabled = userDefaults.bool(forKey: UserDefaultsKeys.autoSyncEnabled)
        self.wifiOnlySync = userDefaults.bool(forKey: UserDefaultsKeys.wifiOnlySync)
        
        if let scopeRawValue = userDefaults.string(forKey: UserDefaultsKeys.syncScope),
           let scope = SyncScope(rawValue: scopeRawValue) {
            self.syncScope = scope
        } else {
            self.syncScope = .metadataOnly
        }
        
        if let lastSyncTimestamp = userDefaults.object(forKey: UserDefaultsKeys.lastSyncDate) as? Date {
            self.lastSyncDate = lastSyncTimestamp
        }
        
        setupAutoSync()
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func triggerManualSync() async {
        guard syncEnabled && syncScope != .disabled else { return }
        guard !isSyncing else { return }
        
        await performSync()
    }
    
    func pauseSync() {
        isSyncing = false
        syncStatus = .paused
        syncTimer?.invalidate()
    }
    
    func resumeSync() {
        guard syncEnabled else { return }
        
        if syncStatus == .paused {
            syncStatus = .idle
            setupAutoSync()
        }
    }
    
    func resetSyncSettings() {
        syncEnabled = false
        syncScope = .metadataOnly
        autoSyncEnabled = false
        wifiOnlySync = true
        lastSyncDate = nil
        
        pauseSync()
        saveSyncSettings()
    }
    
    func estimateSyncDataSize() async -> SyncDataEstimate {
        let dependencyContainer = DependencyContainer.shared
        let syncDataManager = SyncDataManager(
            projectRepository: dependencyContainer.projectRepository,
            recordingRepository: dependencyContainer.recordingRepository
        )
        let projectCount = await syncDataManager.getProjectCount()
        let recordingCount = await syncDataManager.getRecordingCount()
        
        var estimatedSize: Int64 = 0
        var itemCount = 0
        
        switch syncScope {
        case .disabled:
            break
            
        case .metadataOnly:
            // プロジェクトメタデータ + レコーディングメタデータ
            estimatedSize = Int64(projectCount * 200 + recordingCount * 100) // 平均サイズ
            itemCount = projectCount + recordingCount
            
        case .summarySync:
            // メタデータ + 要約テキスト
            estimatedSize = Int64(projectCount * 500 + recordingCount * 2000) // 要約込み
            itemCount = projectCount + recordingCount
            
        case .fullSync:
            // 全文字起こしデータ
            estimatedSize = Int64(recordingCount * 10000) // 平均10KB/録音
            itemCount = recordingCount
        }
        
        return SyncDataEstimate(
            estimatedSize: estimatedSize,
            itemCount: itemCount,
            syncScope: syncScope
        )
    }
    
    func getLastSyncInfo() -> LastSyncInfo? {
        guard let lastSyncDate = lastSyncDate else { return nil }
        
        return LastSyncInfo(
            date: lastSyncDate,
            scope: syncScope,
            status: syncStatus
        )
    }
    
    // MARK: - Private Methods
    
    private func saveSyncSettings() {
        userDefaults.set(syncEnabled, forKey: UserDefaultsKeys.syncEnabled)
        userDefaults.set(syncScope.rawValue, forKey: UserDefaultsKeys.syncScope)
        userDefaults.set(autoSyncEnabled, forKey: UserDefaultsKeys.autoSyncEnabled)
        userDefaults.set(wifiOnlySync, forKey: UserDefaultsKeys.wifiOnlySync)
    }
    
    private func setupAutoSync() {
        syncTimer?.invalidate()
        
        guard syncEnabled && autoSyncEnabled else { return }
        
        // 30分間隔での自動同期
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            Task { @MainActor in
                await self.performAutoSync()
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected && self?.syncEnabled == true {
                    Task { @MainActor in
                        await self?.performAutoSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performAutoSync() async {
        guard shouldPerformAutoSync() else { return }
        await performSync()
    }
    
    private func shouldPerformAutoSync() -> Bool {
        guard syncEnabled && autoSyncEnabled && !isSyncing else { return false }
        guard syncScope != .disabled else { return false }
        
        // WiFi限定チェック
        if wifiOnlySync && !networkMonitor.isWiFiConnected {
            return false
        }
        
        // 最後の同期から一定時間経過チェック
        if let lastSync = lastSyncDate {
            let minimumInterval: TimeInterval = 15 * 60 // 15分
            if Date().timeIntervalSince(lastSync) < minimumInterval {
                return false
            }
        }
        
        return true
    }
    
    private func performSync() async {
        isSyncing = true
        syncStatus = .syncing
        syncProgress = 0.0
        
        do {
            // 同期データの準備
            let syncData = await prepareSyncData()
            syncProgress = 0.3
            
            // クラウドへのアップロード（Mock実装）
            try await uploadSyncData(syncData)
            syncProgress = 0.8
            
            // 同期完了処理
            await finalizSync()
            syncProgress = 1.0
            
            syncStatus = .completed
            lastSyncDate = Date()
            userDefaults.set(lastSyncDate, forKey: UserDefaultsKeys.lastSyncDate)
            
        } catch {
            syncStatus = .failed(error)
            print("Sync failed: \(error)")
        }
        
        isSyncing = false
        
        // 3秒後にステータスをリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.syncStatus == .completed {
                self.syncStatus = .idle
            }
        }
    }
    
    private func prepareSyncData() async -> SyncData {
        let dependencyContainer = DependencyContainer.shared
        let syncDataManager = SyncDataManager(
            projectRepository: dependencyContainer.projectRepository,
            recordingRepository: dependencyContainer.recordingRepository
        )
        
        switch syncScope {
        case .disabled:
            return SyncData(projects: [], recordings: [], summaries: [])
            
        case .metadataOnly:
            let projects = await syncDataManager.getAllProjectMetadata()
            let recordings = await syncDataManager.getAllRecordingMetadata()
            return SyncData(projects: projects, recordings: recordings, summaries: [])
            
        case .summarySync:
            let projects = await syncDataManager.getAllProjectMetadata()
            let recordings = await syncDataManager.getAllRecordingMetadata()
            let summaries = await syncDataManager.getAllRecordingSummaries()
            return SyncData(projects: projects, recordings: recordings, summaries: summaries)
            
        case .fullSync:
            let projects = await syncDataManager.getAllProjectMetadata()
            let recordings = await syncDataManager.getAllRecordingData()
            return SyncData(projects: projects, recordings: recordings, summaries: [])
        }
    }
    
    private func uploadSyncData(_ syncData: SyncData) async throws {
        // Mock実装 - 実際のFirebase Firestoreアップロード
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒のシミュレーション
        
        // 実際の実装では以下のような処理になる：
        // 1. Firestore Collectionへのデータアップロード
        // 2. バッチ書き込みでの効率的な同期
        // 3. エラーハンドリングとリトライロジック
        // 4. データサイズ制限のチェック
    }
    
    private func finalizSync() async {
        // 同期後のクリーンアップ処理
        // 不要なローカルキャッシュの削除など
    }
}

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var isWiFiConnected = true
    
    // 簡略化された実装
    // 実際にはNetwork frameworkを使用してネットワーク状態を監視
}

// MARK: - Sync Data Manager

class SyncDataManager {
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    
    init(
        projectRepository: ProjectRepositoryProtocol,
        recordingRepository: RecordingRepositoryProtocol
    ) {
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
    }
    
    func getProjectCount() async -> Int {
        do {
            let projects = try await projectRepository.findAll()
            return projects.count
        } catch {
            return 0
        }
    }
    
    func getRecordingCount() async -> Int {
        do {
            let recordings = try await recordingRepository.findAll()
            return recordings.count
        } catch {
            return 0
        }
    }
    
    func getAllProjectMetadata() async -> [ProjectSyncMetadata] {
        do {
            let projects = try await projectRepository.findAll()
            return projects.map { project in
                ProjectSyncMetadata(
                    id: project.id,
                    title: project.name,
                    createdAt: project.createdAt,
                    modifiedAt: project.updatedAt,
                    recordingCount: 0 // TODO: Count recordings per project
                )
            }
        } catch {
            return []
        }
    }
    
    func getAllRecordingMetadata() async -> [RecordingSyncMetadata] {
        do {
            let recordings = try await recordingRepository.findAll()
            return recordings.compactMap { recording in
                RecordingSyncMetadata(
                    id: recording.id,
                    projectId: recording.projectId ?? UUID(),
                    filename: recording.audioFileURL.lastPathComponent,
                    duration: recording.duration,
                    createdAt: recording.createdAt,
                    transcriptionStatus: recording.hasTranscription ? "completed" : "pending",
                    fileSize: 0, // TODO: Calculate from file
                    checksum: "", // TODO: Calculate checksum
                    fullTranscription: recording.transcription
                )
            }
        } catch {
            return []
        }
    }
    
    func getAllRecordingSummaries() async -> [RecordingSummary] {
        // Mock implementation - would need summary repository
        return []
    }
    
    func getAllRecordingData() async -> [RecordingSyncMetadata] {
        // Same as getAllRecordingMetadata but with full transcription data
        return await getAllRecordingMetadata()
    }
}

// MARK: - Data Types

struct SyncData {
    let projects: [ProjectSyncMetadata]
    let recordings: [RecordingSyncMetadata] 
    let summaries: [RecordingSummary]
    
    var totalSize: Int64 {
        // 推定データサイズ計算
        let projectSize = Int64(projects.count * 200)
        let recordingSize = Int64(recordings.count * 1000)
        let summarySize = Int64(summaries.count * 500)
        return projectSize + recordingSize + summarySize
    }
}

struct ProjectSyncMetadata: Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let modifiedAt: Date
    let recordingCount: Int
}

struct RecordingSyncMetadata: Codable {
    let id: UUID
    let projectId: UUID
    let filename: String
    let duration: TimeInterval
    let createdAt: Date
    let transcriptionStatus: String
    let fileSize: Int64
    let checksum: String
    
    // フル同期時のみ
    let fullTranscription: String?
}

struct RecordingSummary: Codable {
    let recordingId: UUID
    let summary: String
    let keywords: [String]
    let sentimentScore: Double?
    let language: String
}

struct SyncDataEstimate {
    let estimatedSize: Int64
    let itemCount: Int
    let syncScope: SelectiveCloudSyncManager.SyncScope
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSize)
    }
}

struct LastSyncInfo {
    let date: Date
    let scope: SelectiveCloudSyncManager.SyncScope
    let status: SelectiveCloudSyncManager.SyncStatus
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}