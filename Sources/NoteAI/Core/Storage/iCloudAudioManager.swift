import Foundation
import CloudKit

// MARK: - iCloud音声ファイル管理システム

@MainActor
class iCloudAudioManager: ObservableObject {
    
    static let shared = iCloudAudioManager()
    
    // MARK: - Published Properties
    
    @Published var isEnabled: Bool {
        didSet { saveSettings() }
    }
    
    @Published var syncStrategy: SyncStrategy {
        didSet { saveSettings() }
    }
    
    @Published var isAvailable: Bool = false
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var syncStatus: SyncStatus = .idle
    @Published var uploadProgress: [String: Double] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    
    // MARK: - Configuration
    
    enum SyncStrategy: String, CaseIterable {
        case manual = "manual"
        case auto = "auto"
        case wifiOnly = "wifiOnly"
        case important = "important"
        
        var displayName: String {
            switch self {
            case .manual:
                return "手動同期"
            case .auto:
                return "自動同期"
            case .wifiOnly:
                return "WiFi時のみ"
            case .important:
                return "重要なもののみ"
            }
        }
        
        var description: String {
            switch self {
            case .manual:
                return "ユーザーが手動で選択したファイルのみ同期"
            case .auto:
                return "全ての新しい音声ファイルを自動で同期"
            case .wifiOnly:
                return "WiFi接続時のみ自動同期"
            case .important:
                return "お気に入りやピン留めしたファイルのみ同期"
            }
        }
    }
    
    enum SyncStatus: Equatable {
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.uploading, .uploading),
                 (.downloading, .downloading),
                 (.syncing, .syncing):
                return true
            case (.error, .error):
                return true // Simplified comparison for errors
            default:
                return false
            }
        }
        case idle
        case uploading
        case downloading
        case syncing
        case error(Error)
        
        var displayName: String {
            switch self {
            case .idle: return "待機中"
            case .uploading: return "アップロード中"
            case .downloading: return "ダウンロード中"
            case .syncing: return "同期中"
            case .error: return "エラー"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let container: CKContainer
    private let database: CKDatabase
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let localAudioManager = AudioFileManager.shared
    
    // iCloud Documents Directory
    private lazy var iCloudDocumentsURL: URL? = {
        return fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Audio")
    }()
    
    // Local Documents Directory (fallback)
    private lazy var localDocumentsURL: URL = {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Audio")
    }()
    
    // MARK: - Configuration Keys
    
    private struct UserDefaultsKeys {
        static let isEnabled = "iCloudAudio.enabled"
        static let syncStrategy = "iCloudAudio.syncStrategy"
    }
    
    // MARK: - Initialization
    
    private init() {
        self.container = CKContainer.default()
        self.database = container.privateCloudDatabase
        
        // Load saved settings
        self.isEnabled = userDefaults.bool(forKey: UserDefaultsKeys.isEnabled)
        
        if let strategyRawValue = userDefaults.string(forKey: UserDefaultsKeys.syncStrategy),
           let strategy = SyncStrategy(rawValue: strategyRawValue) {
            self.syncStrategy = strategy
        } else {
            self.syncStrategy = .manual
        }
        
        Task {
            await checkiCloudAvailability()
            await setupiCloudDirectory()
        }
    }
    
    // MARK: - Public Methods
    
    func enable() async throws {
        guard isAvailable else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        isEnabled = true
        await setupiCloudDirectory()
        await performInitialSync()
    }
    
    func disable() async {
        isEnabled = false
        // iCloudファイルは削除しない（ユーザーの選択に委ねる）
    }
    
    func uploadAudioFile(_ audioFile: AudioFileInfo, priority: UploadPriority = .normal) async throws {
        guard isEnabled && isAvailable else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        syncStatus = .uploading
        
        do {
            let iCloudURL = try await copyToiCloud(audioFile: audioFile)
            try await createCloudKitRecord(audioFile: audioFile, iCloudURL: iCloudURL)
            
            // メタデータ更新
            try await updateAudioFileMetadata(audioFile, iCloudURL: iCloudURL)
            
        } catch {
            syncStatus = .error(error)
            throw error
        }
        
        syncStatus = .idle
    }
    
    func downloadAudioFile(_ recordID: CKRecord.ID) async throws -> AudioFileInfo {
        guard isEnabled && isAvailable else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        syncStatus = .downloading
        
        do {
            let record = try await database.record(for: recordID)
            let audioFile = try await downloadFromiCloud(record: record)
            
            syncStatus = .idle
            return audioFile
            
        } catch {
            syncStatus = .error(error)
            throw error
        }
    }
    
    func syncAllFiles() async throws {
        guard isEnabled && isAvailable else { return }
        
        syncStatus = .syncing
        
        do {
            // ローカルファイルをiCloudに同期
            let localFiles = try localAudioManager.getAllAudioFiles()
            let audioFileInfos = try convertURLsToAudioFileInfo(localFiles)
            let filesToSync = filterFilesForSync(audioFileInfos)
            
            for audioFile in filesToSync {
                try await uploadAudioFile(audioFile, priority: .normal)
            }
            
            // iCloudからローカルに同期
            try await downloadMissingFiles()
            
            syncStatus = .idle
            
        } catch {
            syncStatus = .error(error)
            throw error
        }
    }
    
    func deleteFromiCloud(_ audioFile: AudioFileInfo) async throws {
        guard let cloudRecordIDString = audioFile.cloudRecordID else {
            throw iCloudAudioError.fileNotFoundInCloud
        }
        
        let cloudRecordID = CKRecord.ID(recordName: cloudRecordIDString)
        
        // CloudKitレコード削除
        try await database.deleteRecord(withID: cloudRecordID)
        
        // iCloudファイル削除
        if let iCloudURL = audioFile.iCloudURL {
            try fileManager.removeItem(at: iCloudURL)
        }
        
        // メタデータ更新
        try await updateAudioFileMetadata(audioFile, iCloudURL: nil, cloudRecordID: nil)
    }
    
    func getCloudStorageUsage() async throws -> CloudStorageUsage {
        guard isAvailable else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        // iCloudディレクトリのサイズ計算
        var totalSize: Int64 = 0
        var fileCount = 0
        
        if let iCloudURL = iCloudDocumentsURL,
           fileManager.fileExists(atPath: iCloudURL.path) {
            
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: iCloudURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                    fileCount += 1
                }
            }
        }
        
        return CloudStorageUsage(
            totalSize: totalSize,
            fileCount: fileCount,
            isEnabled: isEnabled,
            accountStatus: accountStatus
        )
    }
    
    func getiCloudFileList() async throws -> [iCloudAudioFile] {
        guard isAvailable else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        var iCloudFiles: [iCloudAudioFile] = []
        
        if let iCloudURL = iCloudDocumentsURL,
           fileManager.fileExists(atPath: iCloudURL.path) {
            
            let resourceKeys: [URLResourceKey] = [
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey,
                .ubiquitousItemDownloadingStatusKey
            ]
            
            let enumerator = fileManager.enumerator(
                at: iCloudURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus ?? .notDownloaded
                    let isDownloaded = (downloadStatus == .current || downloadStatus == .downloaded)
                    
                    let iCloudFile = iCloudAudioFile(
                        url: fileURL,
                        fileName: fileURL.lastPathComponent,
                        fileSize: Int64(resourceValues.fileSize ?? 0),
                        modificationDate: resourceValues.contentModificationDate ?? Date(),
                        downloadStatus: downloadStatus,
                        isDownloaded: isDownloaded
                    )
                    
                    iCloudFiles.append(iCloudFile)
                }
            }
        }
        
        return iCloudFiles.sorted { $0.modificationDate > $1.modificationDate }
    }
    
    func downloadFromiCloudIfNeeded(_ iCloudFile: iCloudAudioFile) async throws {
        guard !iCloudFile.isDownloaded else { return }
        
        do {
            try fileManager.startDownloadingUbiquitousItem(at: iCloudFile.url)
            
            // ダウンロード完了を待機
            var attempts = 0
            let maxAttempts = 30 // 30秒待機
            
            while attempts < maxAttempts {
                let resourceValues = try iCloudFile.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus ?? .notDownloaded
                if downloadStatus == .current || downloadStatus == .downloaded {
                    break
                }
                
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機
                attempts += 1
            }
            
            if attempts >= maxAttempts {
                throw iCloudAudioError.downloadTimeout
            }
            
        } catch {
            throw iCloudAudioError.downloadFailed(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        userDefaults.set(isEnabled, forKey: UserDefaultsKeys.isEnabled)
        userDefaults.set(syncStrategy.rawValue, forKey: UserDefaultsKeys.syncStrategy)
    }
    
    private func checkiCloudAvailability() async {
        do {
            let status = try await container.accountStatus()
            
            await MainActor.run {
                self.accountStatus = status
                self.isAvailable = (status == .available)
            }
            
        } catch {
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
                self.isAvailable = false
            }
        }
    }
    
    private func setupiCloudDirectory() async {
        guard let iCloudURL = iCloudDocumentsURL else { return }
        
        do {
            if !fileManager.fileExists(atPath: iCloudURL.path) {
                try fileManager.createDirectory(
                    at: iCloudURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        } catch {
            print("Failed to create iCloud directory: \(error)")
        }
    }
    
    private func copyToiCloud(audioFile: AudioFileInfo) async throws -> URL {
        guard let iCloudURL = iCloudDocumentsURL else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        let destinationURL = iCloudURL.appendingPathComponent(audioFile.fileName)
        
        // ファイルが既に存在する場合は上書き
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: audioFile.filePath, to: destinationURL)
        
        return destinationURL
    }
    
    private func createCloudKitRecord(audioFile: AudioFileInfo, iCloudURL: URL) async throws {
        let record = CKRecord(recordType: "AudioFile", recordID: CKRecord.ID(recordName: audioFile.id.uuidString))
        
        record["fileName"] = audioFile.fileName as CKRecordValue
        record["duration"] = audioFile.duration as CKRecordValue
        record["fileSize"] = audioFile.fileSize as CKRecordValue
        record["createdAt"] = audioFile.createdAt as CKRecordValue
        record["sampleRate"] = audioFile.sampleRate as CKRecordValue
        record["channels"] = audioFile.channels as CKRecordValue
        record["format"] = audioFile.format.rawValue as CKRecordValue
        record["checksum"] = calculateChecksum(audioFile.filePath) as CKRecordValue
        
        try await database.save(record)
    }
    
    private func downloadFromiCloud(record: CKRecord) async throws -> AudioFileInfo {
        guard let fileName = record["fileName"] as? String,
              let duration = record["duration"] as? TimeInterval,
              let fileSize = record["fileSize"] as? Int64,
              let createdAt = record["createdAt"] as? Date,
              let sampleRate = record["sampleRate"] as? Double,
              let channels = record["channels"] as? Int,
              let formatString = record["format"] as? String,
              let format = AudioFormat(rawValue: formatString) else {
            throw iCloudAudioError.invalidCloudRecord
        }
        
        // iCloudからローカルにコピー
        guard let iCloudURL = iCloudDocumentsURL?.appendingPathComponent(fileName) else {
            throw iCloudAudioError.iCloudNotAvailable
        }
        
        let localURL = localDocumentsURL.appendingPathComponent(fileName)
        
        // ローカルディレクトリ作成
        try fileManager.createDirectory(
            at: localDocumentsURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // ファイルが既に存在する場合は上書き
        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
        }
        
        try fileManager.copyItem(at: iCloudURL, to: localURL)
        
        return AudioFileInfo(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            fileName: fileName,
            filePath: localURL,
            duration: duration,
            fileSize: fileSize,
            createdAt: createdAt,
            sampleRate: sampleRate,
            channels: channels,
            format: format,
            transcriptionStatus: .pending,
            iCloudURL: iCloudURL,
            cloudRecordID: record.recordID.recordName
        )
    }
    
    // URLをAudioFileInfoに変換するヘルパーメソッド
    private func convertURLsToAudioFileInfo(_ urls: [URL]) throws -> [AudioFileInfo] {
        return try urls.compactMap { url -> AudioFileInfo? in
            guard url.pathExtension.lowercased() == "m4a" || 
                  url.pathExtension.lowercased() == "wav" ||
                  url.pathExtension.lowercased() == "mp3" else {
                return nil
            }
            
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .creationDateKey,
                .contentModificationDateKey
            ])
            
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let createdAt = resourceValues.creationDate ?? Date()
            let format: AudioFormat = url.pathExtension.lowercased() == "wav" ? .wav : .m4a
            
            return AudioFileInfo(
                fileName: url.lastPathComponent,
                filePath: url,
                duration: 0, // Duration will be calculated later if needed
                fileSize: fileSize,
                createdAt: createdAt,
                sampleRate: 44100, // Default value
                channels: 1, // Default value
                format: format,
                transcriptionStatus: .pending
            )
        }
    }
    
    private func filterFilesForSync(_ files: [AudioFileInfo]) -> [AudioFileInfo] {
        switch syncStrategy {
        case .manual:
            return [] // 手動同期なので自動では何もしない
            
        case .auto:
            return files.filter { $0.iCloudURL == nil } // まだiCloudに同期されていないファイル
            
        case .wifiOnly:
            // WiFi接続チェック（簡略化）
            return files.filter { $0.iCloudURL == nil }
            
        case .important:
            return files.filter { $0.isImportant && $0.iCloudURL == nil } // 重要フラグがあるファイル
        }
    }
    
    private func downloadMissingFiles() async throws {
        // CloudKitから全レコードを取得
        let query = CKQuery(recordType: "AudioFile", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let fileName = record["fileName"] as? String {
                    let localURL = localDocumentsURL.appendingPathComponent(fileName)
                    
                    // ローカルに存在しない場合はダウンロード
                    if !fileManager.fileExists(atPath: localURL.path) {
                        _ = try await downloadFromiCloud(record: record)
                    }
                }
                
            case .failure(let error):
                print("Failed to process CloudKit record: \(error)")
            }
        }
    }
    
    private func updateAudioFileMetadata(_ audioFile: AudioFileInfo, iCloudURL: URL?, cloudRecordID: String? = nil) async throws {
        // CoreDataの更新（実装が必要）
        // 実際の実装では、CoreDataManagerを使ってメタデータを更新
    }
    
    private func performInitialSync() async {
        guard syncStrategy == .auto else { return }
        
        do {
            try await syncAllFiles()
        } catch {
            print("Initial sync failed: \(error)")
        }
    }
    
    private func calculateChecksum(_ fileURL: URL) -> String {
        // ファイルのSHA256チェックサムを計算
        // 実装簡略化のため、ファイルサイズを使用
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return String(fileSize)
        } catch {
            return "unknown"
        }
    }
}

// MARK: - Supporting Types

enum UploadPriority {
    case low, normal, high
}

struct CloudStorageUsage {
    let totalSize: Int64
    let fileCount: Int
    let isEnabled: Bool
    let accountStatus: CKAccountStatus
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    var statusDescription: String {
        switch accountStatus {
        case .available:
            return isEnabled ? "利用可能" : "無効"
        case .noAccount:
            return "iCloudアカウントなし"
        case .restricted:
            return "制限あり"
        case .couldNotDetermine:
            return "状態不明"
        case .temporarilyUnavailable:
            return "一時的に利用不可"
        @unknown default:
            return "不明"
        }
    }
}

struct iCloudAudioFile {
    let url: URL
    let fileName: String
    let fileSize: Int64
    let modificationDate: Date
    let downloadStatus: URLUbiquitousItemDownloadingStatus
    let isDownloaded: Bool
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var downloadStatusDescription: String {
        switch downloadStatus {
        case .notDownloaded:
            return "未ダウンロード"
        case .downloaded:
            return "ダウンロード済み"
        case .current:
            return "最新"
        default:
            return "不明"
        }
    }
}

enum iCloudAudioError: Error, LocalizedError {
    case iCloudNotAvailable
    case fileNotFoundInCloud
    case invalidCloudRecord
    case downloadTimeout
    case downloadFailed(Error)
    case uploadFailed(Error)
    case syncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloudが利用できません。設定でiCloudを有効にしてください。"
        case .fileNotFoundInCloud:
            return "ファイルがiCloudに見つかりません。"
        case .invalidCloudRecord:
            return "iCloudのデータが破損しています。"
        case .downloadTimeout:
            return "ダウンロードがタイムアウトしました。"
        case .downloadFailed(let error):
            return "ダウンロードに失敗しました: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "アップロードに失敗しました: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "同期に失敗しました: \(error.localizedDescription)"
        }
    }
}

