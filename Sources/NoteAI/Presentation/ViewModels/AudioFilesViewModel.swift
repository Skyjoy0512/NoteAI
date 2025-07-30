import Foundation
import AVFoundation
import Combine

/// 音声ファイル一覧の表示とビジネスロジックを管理するViewModel
@MainActor
class AudioFilesViewModel: ObservableObject {
    @Published var audioFiles: [AudioFileInfo] = []
    @Published var filteredAudioFiles: [AudioFileInfo] = []
    @Published var isLoading = false
    @Published var error: AudioFilesError?
    @Published var currentFilter = AudioFileFilter()
    
    // グループ化された音声ファイル（時間帯別）
    @Published var groupedAudioFiles: [String: [AudioFileInfo]] = [:]
    
    private let audioFileManager: AudioFileManagerProtocol
    private let transcriptionService: TranscriptionServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        audioFileManager: AudioFileManagerProtocol = AudioFileManager(),
        transcriptionService: TranscriptionServiceProtocol? = nil
    ) {
        self.audioFileManager = audioFileManager
        self.transcriptionService = transcriptionService
        
        setupFilterObserver()
    }
    
    // MARK: - Public Methods
    
    /// 指定日の音声ファイルを読み込み
    func loadAudioFiles(for date: Date) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let files = try await loadAudioFilesFromStorage(for: date)
                self.audioFiles = files
                applyFilter()
                updateGroupedFiles()
                isLoading = false
            } catch {
                self.error = .loadFailed(error)
                self.isLoading = false
            }
        }
    }
    
    /// フィルターを適用
    func applyFilter() {
        filteredAudioFiles = audioFiles.filter { audioFile in
            // 文字起こし状態フィルター
            guard currentFilter.transcriptionStatuses.contains(audioFile.transcriptionStatus) else {
                return false
            }
            
            // 音声フォーマットフィルター
            guard currentFilter.audioFormats.contains(audioFile.format) else {
                return false
            }
            
            // 時間長フィルター
            guard audioFile.duration >= currentFilter.minDuration &&
                  audioFile.duration <= currentFilter.maxDuration else {
                return false
            }
            
            // 活動タイプフィルター
            if let activityType = audioFile.metadata.environment?.activityType {
                guard currentFilter.activityTypes.contains(activityType) else {
                    return false
                }
            }
            
            // 検索テキストフィルター
            if !currentFilter.searchText.isEmpty {
                let searchText = currentFilter.searchText.lowercased()
                let fileName = audioFile.fileName.lowercased()
                let tags = audioFile.metadata.tags.joined(separator: " ").lowercased()
                let notes = audioFile.metadata.notes?.lowercased() ?? ""
                
                guard fileName.contains(searchText) ||
                      tags.contains(searchText) ||
                      notes.contains(searchText) else {
                    return false
                }
            }
            
            return true
        }
        
        updateGroupedFiles()
    }
    
    /// 音声ファイルの文字起こしを開始
    func transcribeAudioFile(_ audioFile: AudioFileInfo) {
        guard let transcriptionService = transcriptionService else {
            error = .transcriptionServiceUnavailable
            return
        }
        
        Task {
            do {
                // 文字起こし状態を処理中に更新
                updateTranscriptionStatus(for: audioFile.id, status: .processing)
                
                try await transcriptionService.transcribe(audioFile: audioFile)
                
                // 完了状態に更新
                updateTranscriptionStatus(for: audioFile.id, status: .completed)
                
            } catch {
                updateTranscriptionStatus(for: audioFile.id, status: .failed)
                self.error = .transcriptionFailed(error)
            }
        }
    }
    
    /// 一括文字起こしを開始
    func startBatchTranscription() {
        let pendingFiles = filteredAudioFiles.filter { $0.transcriptionStatus == .pending }
        
        guard !pendingFiles.isEmpty else { return }
        
        Task {
            for audioFile in pendingFiles {
                transcribeAudioFile(audioFile)
                // 各ファイル間に少し間隔を置く
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
        }
    }
    
    /// 音声ファイルを削除
    func deleteAudioFile(_ audioFile: AudioFileInfo) {
        Task {
            do {
                try audioFileManager.deleteAudioFile(at: audioFile.filePath)
                
                // リストから削除
                audioFiles.removeAll { $0.id == audioFile.id }
                applyFilter()
                
            } catch {
                self.error = .deleteFailed(error)
            }
        }
    }
    
    /// 音声ファイルを共有
    func shareAudioFile(_ audioFile: AudioFileInfo) {
        // 共有機能の実装
        // この実装では、共有シートの表示などは View 側で行う
        print("Sharing audio file: \(audioFile.fileName)")
    }
    
    /// 音声ファイルをエクスポート
    func exportAudioFiles() {
        let selectedFiles = filteredAudioFiles
        
        Task {
            do {
                for audioFile in selectedFiles {
                    let exportURL = getExportURL(for: audioFile)
                    try audioFileManager.exportAudioFile(
                        from: audioFile.filePath,
                        to: exportURL
                    )
                }
            } catch {
                self.error = .exportFailed(error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupFilterObserver() {
        $currentFilter
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }
    
    private func loadAudioFilesFromStorage(for date: Date) async throws -> [AudioFileInfo] {
        let allFileURLs = try audioFileManager.getAllAudioFiles()
        let calendar = Calendar.current
        
        var audioFiles: [AudioFileInfo] = []
        
        for fileURL in allFileURLs {
            let fileInfo = try await extractAudioFileInfo(from: fileURL)
            
            // 指定日のファイルのみフィルター
            if calendar.isDate(fileInfo.createdAt, inSameDayAs: date) {
                audioFiles.append(fileInfo)
            }
        }
        
        // 作成日時順でソート（新しい順）
        return audioFiles.sorted { $0.createdAt > $1.createdAt }
    }
    
    private func extractAudioFileInfo(from url: URL) async throws -> AudioFileInfo {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        
        let createdAt = attributes[.creationDate] as? Date ?? Date()
        let modifiedAt = attributes[.modificationDate] as? Date ?? Date()
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // 音声メタデータを取得
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        
        let tracks = try await asset.load(.tracks)
        var audioTrack: AVAssetTrack?
        for track in tracks {
            if track.mediaType == AVMediaType.audio {
                audioTrack = track
                break
            }
        }
        
        var sampleRate: Double = 44100
        var channels: Int = 1
        var bitRate: Int? = nil
        
        if let audioTrack = audioTrack {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                if let basicDescription = audioStreamBasicDescription {
                    sampleRate = basicDescription.pointee.mSampleRate
                    channels = Int(basicDescription.pointee.mChannelsPerFrame)
                }
            }
            
            let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
            bitRate = Int(estimatedDataRate)
        }
        
        // ファイル形式判定
        let fileExtension = url.pathExtension.lowercased()
        let format = AudioFormat(rawValue: fileExtension) ?? .m4a
        
        // メタデータの構築（実際の実装では外部サービスから取得することも）
        let metadata = buildMetadata(for: url)
        
        return AudioFileInfo(
            fileName: url.lastPathComponent,
            filePath: url,
            duration: duration,
            fileSize: fileSize,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            sampleRate: sampleRate,
            channels: channels,
            bitRate: bitRate,
            format: format,
            transcriptionStatus: .pending, // 実際の実装では保存された状態を取得
            metadata: metadata
        )
    }
    
    private func buildMetadata(for url: URL) -> AudioMetadata {
        // 実際の実装では、データベースやファイルから読み込み
        return AudioMetadata()
    }
    
    private func updateGroupedFiles() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        groupedAudioFiles = Dictionary(grouping: filteredAudioFiles) { audioFile in
            let hour = Calendar.current.component(.hour, from: audioFile.createdAt)
            
            switch hour {
            case 6..<12:
                return "午前"
            case 12..<18:
                return "午後"
            case 18..<22:
                return "夕方"
            default:
                return "夜"
            }
        }
    }
    
    private func updateTranscriptionStatus(for audioFileId: UUID, status: TranscriptionStatus) {
        if let index = audioFiles.firstIndex(where: { $0.id == audioFileId }) {
            audioFiles[index] = AudioFileInfo(
                id: audioFiles[index].id,
                fileName: audioFiles[index].fileName,
                filePath: audioFiles[index].filePath,
                duration: audioFiles[index].duration,
                fileSize: audioFiles[index].fileSize,
                createdAt: audioFiles[index].createdAt,
                modifiedAt: audioFiles[index].modifiedAt,
                sampleRate: audioFiles[index].sampleRate,
                channels: audioFiles[index].channels,
                bitRate: audioFiles[index].bitRate,
                format: audioFiles[index].format,
                transcriptionStatus: status,
                metadata: audioFiles[index].metadata
            )
        }
        
        applyFilter()
    }
    
    private func getExportURL(for audioFile: AudioFileInfo) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportDirectory = documentsPath.appendingPathComponent("Exports")
        
        // エクスポートディレクトリを作成
        try? FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        
        return exportDirectory.appendingPathComponent(audioFile.fileName)
    }
}

// MARK: - Supporting Types

/// 文字起こしサービスのプロトコル（仮）
protocol TranscriptionServiceProtocol {
    func transcribe(audioFile: AudioFileInfo) async throws
}

// MARK: - Error Types

enum AudioFilesError: LocalizedError {
    case loadFailed(Error)
    case deleteFailed(Error)
    case exportFailed(Error)
    case transcriptionFailed(Error)
    case transcriptionServiceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "音声ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "音声ファイルの削除に失敗しました: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "音声ファイルのエクスポートに失敗しました: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "文字起こしに失敗しました: \(error.localizedDescription)"
        case .transcriptionServiceUnavailable:
            return "文字起こしサービスが利用できません"
        }
    }
}