import Foundation
import CryptoKit

protocol AudioFileManagerProtocol {
    func saveSecureAudioFile(_ data: Data, filename: String) throws -> URL
    func loadAudioFile(from url: URL) throws -> Data
    func deleteAudioFile(at url: URL) throws
    func getAudioFileSize(at url: URL) throws -> Int64
    func getAllAudioFiles() throws -> [URL]
    func getAvailableStorage() throws -> Int64
    func cleanupOldFiles(olderThan date: Date) throws
    func exportAudioFile(from url: URL, to destinationURL: URL) throws
}

class AudioFileManager: AudioFileManagerProtocol {
    static let shared = AudioFileManager()
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let audioDirectory: URL
    
    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioDirectory = documentsDirectory.appendingPathComponent("Audio")
        
        // オーディオディレクトリ作成
        createAudioDirectoryIfNeeded()
    }
    
    func saveSecureAudioFile(_ data: Data, filename: String) throws -> URL {
        let fileURL = audioDirectory.appendingPathComponent(filename)
        
        // ファイル保護レベル設定で暗号化保存
        try data.write(to: fileURL, options: [.completeFileProtection, .atomic])
        
        // ファイル属性設定
        try fileManager.setAttributes([
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ], ofItemAtPath: fileURL.path)
        
        return fileURL
    }
    
    func loadAudioFile(from url: URL) throws -> Data {
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioFileError.fileNotFound(url)
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            throw AudioFileError.loadFailed(url, error)
        }
    }
    
    func deleteAudioFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioFileError.fileNotFound(url)
        }
        
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw AudioFileError.deleteFailed(url, error)
        }
    }
    
    func getAudioFileSize(at url: URL) throws -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            throw AudioFileError.attributesFailed(url, error)
        }
    }
    
    func getAllAudioFiles() throws -> [URL] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: audioDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                options: .skipsHiddenFiles
            )
            
            return contents.filter { url in
                let pathExtension = url.pathExtension.lowercased()
                return ["m4a", "wav", "mp3", "aac"].contains(pathExtension)
            }.sorted { url1, url2 in
                let date1 = getCreationDate(for: url1) ?? Date.distantPast
                let date2 = getCreationDate(for: url2) ?? Date.distantPast
                return date1 > date2 // 新しい順
            }
        } catch {
            throw AudioFileError.directoryReadFailed(error)
        }
    }
    
    func cleanupOldFiles(olderThan date: Date) throws {
        let allFiles = try getAllAudioFiles()
        
        for fileURL in allFiles {
            if let creationDate = getCreationDate(for: fileURL),
               creationDate < date {
                try deleteAudioFile(at: fileURL)
            }
        }
    }
    
    func exportAudioFile(from url: URL, to destinationURL: URL) throws {
        do {
            let data = try loadAudioFile(from: url)
            try data.write(to: destinationURL)
        } catch {
            throw AudioFileError.exportFailed(url, destinationURL, error)
        }
    }
    
    // MARK: - Storage Management
    
    func getTotalStorageUsed() throws -> Int64 {
        let allFiles = try getAllAudioFiles()
        var totalSize: Int64 = 0
        
        for fileURL in allFiles {
            totalSize += try getAudioFileSize(at: fileURL)
        }
        
        return totalSize
    }
    
    func getAvailableStorage() throws -> Int64 {
        let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentsDirectory.path)
        return systemAttributes[.systemFreeSize] as? Int64 ?? 0
    }
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Backup & Restore
    
    func createBackupManifest() throws -> AudioBackupManifest {
        let allFiles = try getAllAudioFiles()
        let manifest = AudioBackupManifest(
            createdAt: Date(),
            totalFiles: allFiles.count,
            totalSize: try getTotalStorageUsed(),
            files: allFiles.map { url in
                AudioBackupFileInfo(
                    url: url,
                    size: (try? getAudioFileSize(at: url)) ?? 0,
                    createdAt: getCreationDate(for: url) ?? Date(),
                    checksum: calculateChecksum(for: url)
                )
            }
        )
        
        return manifest
    }
    
    // MARK: - Private Methods
    
    private func createAudioDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: audioDirectory,
                    withIntermediateDirectories: true,
                    attributes: [
                        .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                    ]
                )
            } catch {
                print("Failed to create audio directory: \(error)")
            }
        }
    }
    
    private func getCreationDate(for url: URL) -> Date? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
    
    private func calculateChecksum(for url: URL) -> String {
        do {
            let data = try Data(contentsOf: url)
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            return ""
        }
    }
}

// MARK: - Supporting Types

struct AudioBackupManifest: Codable {
    let createdAt: Date
    let totalFiles: Int
    let totalSize: Int64
    let files: [AudioBackupFileInfo]
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: totalSize)
    }
}

struct AudioBackupFileInfo: Codable {
    let url: URL
    let size: Int64
    let createdAt: Date
    let checksum: String
    
    var filename: String {
        url.lastPathComponent
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: size)
    }
}

enum AudioFileError: LocalizedError {
    case fileNotFound(URL)
    case loadFailed(URL, Error)
    case saveFailed(URL, Error)
    case deleteFailed(URL, Error)
    case attributesFailed(URL, Error)
    case directoryReadFailed(Error)
    case exportFailed(URL, URL, Error)
    case insufficientStorage(required: Int64, available: Int64)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "ファイルが見つかりません: \(url.lastPathComponent)"
        case .loadFailed(let url, let error):
            return "ファイルの読み込みに失敗しました: \(url.lastPathComponent) - \(error.localizedDescription)"
        case .saveFailed(let url, let error):
            return "ファイルの保存に失敗しました: \(url.lastPathComponent) - \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "ファイルの削除に失敗しました: \(url.lastPathComponent) - \(error.localizedDescription)"
        case .attributesFailed(let url, let error):
            return "ファイル属性の取得に失敗しました: \(url.lastPathComponent) - \(error.localizedDescription)"
        case .directoryReadFailed(let error):
            return "ディレクトリの読み込みに失敗しました: \(error.localizedDescription)"
        case .exportFailed(let source, let destination, let error):
            return "ファイルのエクスポートに失敗しました: \(source.lastPathComponent) -> \(destination.lastPathComponent) - \(error.localizedDescription)"
        case .insufficientStorage(let required, let available):
            let formatter = ByteCountFormatter()
            let requiredStr = formatter.string(fromByteCount: required)
            let availableStr = formatter.string(fromByteCount: available)
            return "ストレージ容量不足: 必要 \(requiredStr), 利用可能 \(availableStr)"
        }
    }
}