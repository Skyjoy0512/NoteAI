import Foundation
import SwiftUI

// MARK: - ストレージ使用量監視システム

@MainActor
class StorageMonitor: ObservableObject {
    
    static let shared = StorageMonitor()
    
    // MARK: - Published Properties
    
    @Published var currentMetrics: StorageMetrics
    @Published var isMonitoring: Bool = false
    @Published var cleanupSuggestions: [CleanupSuggestion] = []
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let documentsURL: URL
    private let cacheURL: URL
    private let audioDirectory: URL
    private let vectorDBPath: URL
    
    // MARK: - Configuration
    
    private struct Config {
        static let updateInterval: TimeInterval = 30 // 30秒間隔
        static let criticalThreshold: Double = 0.9 // 90%使用量で警告
        static let warningThreshold: Double = 0.8 // 80%使用量で注意
        static let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
        static let oldFileThreshold: TimeInterval = 7 * 24 * 3600 // 7日
    }
    
    // MARK: - Initialization
    
    private init() {
        self.documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.audioDirectory = documentsURL.appendingPathComponent("Audio")
        self.vectorDBPath = documentsURL.appendingPathComponent("vectorstore.db")
        
        // 初期メトリクス取得
        self.currentMetrics = StorageMetrics()
        
        Task {
            await updateMetrics()
        }
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        Task {
            while isMonitoring {
                await updateMetrics()
                await generateCleanupSuggestions()
                
                try? await Task.sleep(nanoseconds: UInt64(Config.updateInterval * 1_000_000_000))
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    func updateMetrics() async {
        let metrics = await calculateStorageMetrics()
        
        await MainActor.run {
            self.currentMetrics = metrics
        }
    }
    
    func performCleanup(suggestions: [CleanupSuggestion]) async throws -> CleanupResult {
        var cleanedSize: Int64 = 0
        var cleanedItems: Int = 0
        var errors: [Error] = []
        
        for suggestion in suggestions {
            do {
                let result = try await executeCleanupSuggestion(suggestion)
                cleanedSize += result.size
                cleanedItems += result.itemCount
            } catch {
                errors.append(error)
            }
        }
        
        // メトリクス更新
        await updateMetrics()
        await generateCleanupSuggestions()
        
        return CleanupResult(
            cleanedSize: cleanedSize,
            cleanedItems: cleanedItems,
            errors: errors
        )
    }
    
    func getDetailedBreakdown() async -> DetailedStorageBreakdown {
        return await DetailedStorageBreakdown(
            audioFiles: calculateAudioFilesBreakdown(),
            vectorData: calculateVectorDataBreakdown(),
            cacheData: calculateCacheBreakdown(),
            temporaryFiles: calculateTemporaryFilesBreakdown(),
            coreData: calculateCoreDataBreakdown()
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateStorageMetrics() async -> StorageMetrics {
        let audioSize = await calculateDirectorySize(audioDirectory)
        let vectorSize = await calculateFileSize(vectorDBPath)
        let cacheSize = await calculateDirectorySize(cacheURL)
        let tempSize = await calculateTemporaryFilesSize()
        let coreDataSize = await calculateCoreDataSize()
        
        let totalUsed = audioSize + vectorSize + cacheSize + tempSize + coreDataSize
        let availableSpace = await getAvailableSpace()
        let totalSpace = await getTotalSpace()
        
        return StorageMetrics(
            totalUsed: totalUsed,
            audioFiles: audioSize,
            vectorData: vectorSize,
            cacheData: cacheSize,
            temporaryFiles: tempSize,
            coreDataSize: coreDataSize,
            availableSpace: availableSpace,
            totalSpace: totalSpace,
            usagePercentage: totalSpace > 0 ? Double(totalUsed) / Double(totalSpace) : 0.0,
            lastUpdated: Date()
        )
    }
    
    private func calculateDirectorySize(_ url: URL) async -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        
        var totalSize: Int64 = 0
        
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            let fileEnumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = fileEnumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }
        } catch {
            print("Error calculating directory size: \(error)")
        }
        
        return totalSize
    }
    
    private func calculateFileSize(_ url: URL) async -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func calculateTemporaryFilesSize() async -> Int64 {
        let tempURL = fileManager.temporaryDirectory
        return await calculateDirectorySize(tempURL)
    }
    
    private func calculateCoreDataSize() async -> Int64 {
        // CoreDataの推定サイズ計算
        let coreDataURL = documentsURL.appendingPathComponent("DataModel.sqlite")
        return await calculateFileSize(coreDataURL)
    }
    
    private func getAvailableSpace() async -> Int64 {
        do {
            let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(resourceValues.volumeAvailableCapacity ?? 0)
        } catch {
            return 0
        }
    }
    
    private func getTotalSpace() async -> Int64 {
        do {
            let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
            return Int64(resourceValues.volumeTotalCapacity ?? 0)
        } catch {
            return 0
        }
    }
    
    private func generateCleanupSuggestions() async {
        var suggestions: [CleanupSuggestion] = []
        
        // 古いキャッシュファイル
        if currentMetrics.cacheData > Config.maxCacheSize {
            suggestions.append(.clearOldCache(
                size: currentMetrics.cacheData - Config.maxCacheSize,
                description: "古いキャッシュファイルを削除"
            ))
        }
        
        // 一時ファイル
        if currentMetrics.temporaryFiles > 0 {
            suggestions.append(.clearTemporaryFiles(
                size: currentMetrics.temporaryFiles,
                description: "一時ファイルをクリア"
            ))
        }
        
        // 古い音声ファイル
        let oldAudioFiles = await findOldAudioFiles()
        if !oldAudioFiles.isEmpty {
            let totalSize = oldAudioFiles.reduce(0) { $0 + $1.size }
            suggestions.append(.archiveOldAudioFiles(
                files: oldAudioFiles,
                size: totalSize,
                description: "\(oldAudioFiles.count)個の古い音声ファイル"
            ))
        }
        
        // 重複ベクトルデータ
        let duplicateVectors = await findDuplicateVectorData()
        if !duplicateVectors.isEmpty {
            suggestions.append(.removeDuplicateVectors(
                count: duplicateVectors.count,
                size: duplicateVectors.reduce(0) { $0 + $1.estimatedSize },
                description: "\(duplicateVectors.count)個の重複ベクトル"
            ))
        }
        
        await MainActor.run {
            self.cleanupSuggestions = suggestions
        }
    }
    
    private func findOldAudioFiles() async -> [OldFileInfo] {
        var oldFiles: [OldFileInfo] = []
        
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
            let fileEnumerator = fileManager.enumerator(
                at: audioDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            let cutoffDate = Date().addingTimeInterval(-Config.oldFileThreshold)
            
            while let fileURL = fileEnumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < cutoffDate {
                    oldFiles.append(OldFileInfo(
                        url: fileURL,
                        size: Int64(resourceValues.fileSize ?? 0),
                        lastModified: modificationDate
                    ))
                }
            }
        } catch {
            print("Error finding old audio files: \(error)")
        }
        
        return oldFiles
    }
    
    private func findDuplicateVectorData() async -> [DuplicateVectorInfo] {
        // 簡略化された重複検出
        // 実際の実装では、ベクトルデータベースをクエリして重複を検出
        return []
    }
    
    private func executeCleanupSuggestion(_ suggestion: CleanupSuggestion) async throws -> CleanupSuggestionResult {
        switch suggestion {
        case .clearOldCache(let size, _):
            return try await clearOldCacheFiles(targetSize: size)
            
        case .clearTemporaryFiles(_, _):
            return try await clearTemporaryFiles()
            
        case .archiveOldAudioFiles(let files, _, _):
            return try await archiveAudioFiles(files)
            
        case .removeDuplicateVectors(let count, let size, _):
            return try await removeDuplicateVectors(count: count, estimatedSize: size)
        }
    }
    
    private func clearOldCacheFiles(targetSize: Int64) async throws -> CleanupSuggestionResult {
        var clearedSize: Int64 = 0
        var clearedCount = 0
        
        // キャッシュディレクトリのファイルを日付順でソート
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let fileEnumerator = fileManager.enumerator(
            at: cacheURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
        
        var files: [(URL, Date, Int64)] = []
        
        while let fileURL = fileEnumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            if let modificationDate = resourceValues.contentModificationDate {
                files.append((
                    fileURL,
                    modificationDate,
                    Int64(resourceValues.fileSize ?? 0)
                ))
            }
        }
        
        // 古いファイルから削除
        files.sort { $0.1 < $1.1 }
        
        for (url, _, size) in files {
            if clearedSize >= targetSize { break }
            
            try fileManager.removeItem(at: url)
            clearedSize += size
            clearedCount += 1
        }
        
        return CleanupSuggestionResult(size: clearedSize, itemCount: clearedCount)
    }
    
    private func clearTemporaryFiles() async throws -> CleanupSuggestionResult {
        let tempURL = fileManager.temporaryDirectory
        let tempSize = await calculateDirectorySize(tempURL)
        
        try fileManager.removeItem(at: tempURL)
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
        
        return CleanupSuggestionResult(size: tempSize, itemCount: 1)
    }
    
    private func archiveAudioFiles(_ files: [OldFileInfo]) async throws -> CleanupSuggestionResult {
        // アーカイブは実装しない（ユーザーによる手動操作推奨）
        return CleanupSuggestionResult(size: 0, itemCount: 0)
    }
    
    private func removeDuplicateVectors(count: Int, estimatedSize: Int64) async throws -> CleanupSuggestionResult {
        // 重複ベクトル削除は実装しない（データ整合性のため）
        return CleanupSuggestionResult(size: 0, itemCount: 0)
    }
    
    // MARK: - Detailed Breakdown Calculations
    
    private func calculateAudioFilesBreakdown() async -> AudioFilesBreakdown {
        var totalFiles = 0
        var totalSize: Int64 = 0
        var filesByFormat: [String: Int] = [:]
        var sizeByFormat: [String: Int64] = [:]
        
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey]
            let fileEnumerator = fileManager.enumerator(
                at: audioDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = fileEnumerator?.nextObject() as? URL {
                let format = fileURL.pathExtension.lowercased()
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                
                totalFiles += 1
                totalSize += fileSize
                
                filesByFormat[format, default: 0] += 1
                sizeByFormat[format, default: 0] += fileSize
            }
        } catch {
            print("Error calculating audio files breakdown: \(error)")
        }
        
        return AudioFilesBreakdown(
            totalFiles: totalFiles,
            totalSize: totalSize,
            filesByFormat: filesByFormat,
            sizeByFormat: sizeByFormat
        )
    }
    
    private func calculateVectorDataBreakdown() async -> VectorDataBreakdown {
        let vectorSize = await calculateFileSize(vectorDBPath)
        
        // ベクトルデータベースの詳細分析（簡略化）
        return VectorDataBreakdown(
            databaseSize: vectorSize,
            estimatedVectorCount: vectorSize > 0 ? Int(vectorSize / 6144) : 0, // 1536 * 4 bytes per vector
            indexSize: vectorSize / 10, // 推定値
            metadataSize: vectorSize / 20 // 推定値
        )
    }
    
    private func calculateCacheBreakdown() async -> CacheBreakdown {
        var apiCacheSize: Int64 = 0
        var imageCacheSize: Int64 = 0
        var tempCacheSize: Int64 = 0
        
        // APIキャッシュ
        let apiCacheURL = cacheURL.appendingPathComponent("APICache")
        apiCacheSize = await calculateDirectorySize(apiCacheURL)
        
        // イメージキャッシュ
        let imageCacheURL = cacheURL.appendingPathComponent("ImageCache")
        imageCacheSize = await calculateDirectorySize(imageCacheURL)
        
        // その他のキャッシュ
        let totalCacheSize = await calculateDirectorySize(cacheURL)
        tempCacheSize = totalCacheSize - apiCacheSize - imageCacheSize
        
        return CacheBreakdown(
            apiCache: apiCacheSize,
            imageCache: imageCacheSize,
            temporaryCache: tempCacheSize,
            totalCache: totalCacheSize
        )
    }
    
    private func calculateTemporaryFilesBreakdown() async -> TemporaryFilesBreakdown {
        let tempSize = await calculateTemporaryFilesSize()
        
        return TemporaryFilesBreakdown(
            systemTemp: tempSize,
            appTemp: 0, // 現在使用していない
            exportTemp: 0, // エクスポート時の一時ファイル
            totalTemp: tempSize
        )
    }
    
    private func calculateCoreDataBreakdown() async -> CoreDataBreakdown {
        let coreDataSize = await calculateCoreDataSize()
        
        return CoreDataBreakdown(
            storeSize: coreDataSize,
            walSize: 0, // Write-Ahead Logのサイズ
            shmSize: 0, // Shared Memoryのサイズ
            totalSize: coreDataSize
        )
    }
}

// MARK: - Data Types

struct StorageMetrics {
    let totalUsed: Int64
    let audioFiles: Int64
    let vectorData: Int64
    let cacheData: Int64
    let temporaryFiles: Int64
    let coreDataSize: Int64
    let availableSpace: Int64
    let totalSpace: Int64
    let usagePercentage: Double
    let lastUpdated: Date
    
    init(
        totalUsed: Int64 = 0,
        audioFiles: Int64 = 0,
        vectorData: Int64 = 0,
        cacheData: Int64 = 0,
        temporaryFiles: Int64 = 0,
        coreDataSize: Int64 = 0,
        availableSpace: Int64 = 0,
        totalSpace: Int64 = 0,
        usagePercentage: Double = 0.0,
        lastUpdated: Date = Date()
    ) {
        self.totalUsed = totalUsed
        self.audioFiles = audioFiles
        self.vectorData = vectorData
        self.cacheData = cacheData
        self.temporaryFiles = temporaryFiles
        self.coreDataSize = coreDataSize
        self.availableSpace = availableSpace
        self.totalSpace = totalSpace
        self.usagePercentage = usagePercentage
        self.lastUpdated = lastUpdated
    }
    
    var isLowSpace: Bool {
        return usagePercentage > 0.9
    }
    
    var isWarningSpace: Bool {
        return usagePercentage > 0.8
    }
    
    func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum CleanupSuggestion {
    case clearOldCache(size: Int64, description: String)
    case clearTemporaryFiles(size: Int64, description: String)
    case archiveOldAudioFiles(files: [OldFileInfo], size: Int64, description: String)
    case removeDuplicateVectors(count: Int, size: Int64, description: String)
    
    var potentialSavings: Int64 {
        switch self {
        case .clearOldCache(let size, _):
            return size
        case .clearTemporaryFiles(let size, _):
            return size
        case .archiveOldAudioFiles(_, let size, _):
            return size
        case .removeDuplicateVectors(_, let size, _):
            return size
        }
    }
    
    var title: String {
        switch self {
        case .clearOldCache:
            return "古いキャッシュをクリア"
        case .clearTemporaryFiles:
            return "一時ファイルを削除"
        case .archiveOldAudioFiles:
            return "古い音声ファイルをアーカイブ"
        case .removeDuplicateVectors:
            return "重複ベクトルデータを削除"
        }
    }
    
    var description: String {
        switch self {
        case .clearOldCache(_, let desc):
            return desc
        case .clearTemporaryFiles(_, let desc):
            return desc
        case .archiveOldAudioFiles(_, _, let desc):
            return desc
        case .removeDuplicateVectors(_, _, let desc):
            return desc
        }
    }
    
    var priority: CleanupPriority {
        switch self {
        case .clearTemporaryFiles:
            return .high
        case .clearOldCache:
            return .medium
        case .archiveOldAudioFiles:
            return .low
        case .removeDuplicateVectors:
            return .low
        }
    }
}

enum CleanupPriority {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

struct CleanupResult {
    let cleanedSize: Int64
    let cleanedItems: Int
    let errors: [Error]
    
    var isSuccessful: Bool {
        return errors.isEmpty
    }
}

struct CleanupSuggestionResult {
    let size: Int64
    let itemCount: Int
}

struct OldFileInfo {
    let url: URL
    let size: Int64
    let lastModified: Date
}

struct DuplicateVectorInfo {
    let id: String
    let estimatedSize: Int64
}

struct DetailedStorageBreakdown {
    let audioFiles: AudioFilesBreakdown
    let vectorData: VectorDataBreakdown
    let cacheData: CacheBreakdown
    let temporaryFiles: TemporaryFilesBreakdown
    let coreData: CoreDataBreakdown
}

struct AudioFilesBreakdown {
    let totalFiles: Int
    let totalSize: Int64
    let filesByFormat: [String: Int]
    let sizeByFormat: [String: Int64]
}

struct VectorDataBreakdown {
    let databaseSize: Int64
    let estimatedVectorCount: Int
    let indexSize: Int64
    let metadataSize: Int64
}

struct CacheBreakdown {
    let apiCache: Int64
    let imageCache: Int64
    let temporaryCache: Int64
    let totalCache: Int64
}

struct TemporaryFilesBreakdown {
    let systemTemp: Int64
    let appTemp: Int64
    let exportTemp: Int64
    let totalTemp: Int64
}

struct CoreDataBreakdown {
    let storeSize: Int64
    let walSize: Int64
    let shmSize: Int64
    let totalSize: Int64
}