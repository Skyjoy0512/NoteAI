import Foundation
import SwiftUI

// MARK: - 共通ユーティリティ

/// フォーマット関連のユーティリティ
enum FormatUtils {
    
    /// 時間をフォーマット
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// 日本語の時間フォーマット
    static func formatDurationJapanese(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    /// ファイルサイズのフォーマット
    static func formatFileSize(_ size: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    /// 日付のフォーマット
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    /// 時刻のフォーマット
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - バリデーション

/// 入力値のバリデーション
enum ValidationUtils {
    
    /// 音声ファイルの有効性チェック
    static func validateAudioFile(_ url: URL) -> ValidationResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound)
        }
        
        let supportedExtensions = ["wav", "mp3", "m4a", "aac", "flac"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard supportedExtensions.contains(fileExtension) else {
            return .failure(.unsupportedFormat(fileExtension))
        }
        
        // ファイルサイズチェック (最大500MB)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let maxSize: Int64 = 500 * 1024 * 1024 // 500MB
            
            guard fileSize <= maxSize else {
                return .failure(.fileTooLarge(fileSize, maxSize))
            }
            
            return .success
            
        } catch {
            return .failure(.fileAccessError(error.localizedDescription))
        }
    }
    
    /// デバイス名の有効性チェック
    static func validateDeviceName(_ name: String) -> ValidationResult {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.emptyDeviceName)
        }
        
        guard name.count <= 50 else {
            return .failure(.deviceNameTooLong)
        }
        
        return .success
    }
}

enum ValidationResult {
    case success
    case failure(ValidationError)
}

enum ValidationError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat(String)
    case fileTooLarge(Int64, Int64)
    case fileAccessError(String)
    case emptyDeviceName
    case deviceNameTooLong
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "ファイルが見つかりません"
        case .unsupportedFormat(let format):
            return "サポートされていないフォーマットです: \(format)"
        case .fileTooLarge(let size, let maxSize):
            return "ファイルサイズが大きすぎます: \(FormatUtils.formatFileSize(size)) (最大: \(FormatUtils.formatFileSize(maxSize)))"
        case .fileAccessError(let error):
            return "ファイルアクセスエラー: \(error)"
        case .emptyDeviceName:
            return "デバイス名を入力してください"
        case .deviceNameTooLong:
            return "デバイス名が長すぎます（最大50文字）"
        }
    }
}

// MARK: - 設定管理
// LimitlessSettings は Core/Configuration/LimitlessSettings.swift で定義されています

// MARK: - データ処理ヘルパー

/// 音声ファイルのグループ化ヘルパー
enum AudioFileGrouper {
    
    /// 時間帯でグループ化
    static func groupByTimeOfDay(_ audioFiles: [AudioFileInfo]) -> [String: [AudioFileInfo]] {
        let calendar = Calendar.current
        
        return Dictionary(grouping: audioFiles) { audioFile in
            let hour = calendar.component(.hour, from: audioFile.createdAt)
            
            switch hour {
            case 6..<12:
                return "午前"
            case 12..<18:
                return "午後"
            case 18..<22:
                return "夕方"
            default:
                return "夜間"
            }
        }
    }
    
    /// 日付でグループ化
    static func groupByDate(_ audioFiles: [AudioFileInfo]) -> [String: [AudioFileInfo]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        
        return Dictionary(grouping: audioFiles) { audioFile in
            formatter.string(from: audioFile.createdAt)
        }
    }
    
    /// 活動タイプでグループ化
    static func groupByActivity(_ audioFiles: [AudioFileInfo]) -> [String: [AudioFileInfo]] {
        return Dictionary(grouping: audioFiles) { audioFile in
            audioFile.metadata.environment?.activityType?.displayName ?? "不明"
        }
    }
}

// MARK: - エラー統一

enum DeviceError: Error, LocalizedError {
    case scanningFailed(String)
    case connectionFailed(String)
    case connectionTimeout
    case notConnected
    case alreadyConnected
    case commandFailed(String)
    case invalidResponse
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .scanningFailed(let reason):
            return "デバイススキャンに失敗しました: \(reason)"
        case .connectionFailed(let reason):
            return "デバイス接続に失敗しました: \(reason)"
        case .connectionTimeout:
            return "デバイス接続がタイムアウトしました"
        case .notConnected:
            return "デバイスが接続されていません"
        case .alreadyConnected:
            return "デバイスは既に接続されています"
        case .commandFailed(let reason):
            return "コマンド実行に失敗しました: \(reason)"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .deviceNotFound:
            return "デバイスが見つかりません"
        }
    }
}

/// Limitless関連の統一エラー型
enum LimitlessError: Error, LocalizedError {
    case deviceError(DeviceError)
    case recordingError(RecordingError)
    case transcriptionError(WhisperError)
    case validationError(ValidationError)
    case networkError(String)
    case storageError(String)
    case configurationError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .deviceError(let error):
            return "デバイスエラー: \(error.localizedDescription)"
        case .recordingError(let error):
            return "録音エラー: \(error.localizedDescription)"
        case .transcriptionError(let error):
            return "文字起こしエラー: \(error.localizedDescription)"
        case .validationError(let error):
            return "入力エラー: \(error.localizedDescription)"
        case .networkError(let message):
            return "通信エラー: \(message)"
        case .storageError(let message):
            return "ストレージエラー: \(message)"
        case .configurationError(let message):
            return "設定エラー: \(message)"
        case .unknownError(let message):
            return "不明なエラー: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .deviceError:
            return "デバイスの接続を確認してください"
        case .recordingError:
            return "録音設定を確認してください"
        case .transcriptionError:
            return "音声ファイルの形式を確認してください"
        case .validationError:
            return "入力内容を確認してください"
        case .networkError:
            return "ネットワーク接続を確認してください"
        case .storageError:
            return "ストレージ容量を確認してください"
        case .configurationError:
            return "設定を確認してください"
        case .unknownError:
            return "アプリを再起動してください"
        }
    }
}

// MARK: - パフォーマンス監視

/// パフォーマンス計測ヘルパー
class LimitlessPerformanceMeasurement {
    let operation: String
    let startTime: CFTimeInterval
    
    init(_ operation: String) {
        self.operation = operation
        self.startTime = CACurrentMediaTime()
    }
    
    func finish() -> TimeInterval {
        let endTime = CACurrentMediaTime()
        let duration = endTime - startTime
        
        #if DEBUG
        print("⏱️ \(operation): \(String(format: "%.3f", duration))秒")
        #endif
        
        return duration
    }
}

// MARK: - デバッグヘルパー

#if DEBUG
enum DebugUtils {
    static func logLifelogEntry(_ entry: LifelogEntry) {
        print("📊 LifelogEntry for \(FormatUtils.formatDate(entry.date))")
        print("   - Audio files: \(entry.audioFiles.count)")
        print("   - Activities: \(entry.activities.count)")
        print("   - Locations: \(entry.locations.count)")
        print("   - Key moments: \(entry.keyMoments.count)")
        print("   - Total duration: \(FormatUtils.formatDurationJapanese(entry.totalDuration))")
    }
    
    static func logAudioFile(_ audioFile: AudioFileInfo) {
        print("🎵 AudioFile: \(audioFile.fileName)")
        print("   - Duration: \(FormatUtils.formatDuration(audioFile.duration))")
        print("   - Size: \(FormatUtils.formatFileSize(audioFile.fileSize))")
        print("   - Status: \(audioFile.transcriptionStatus.displayName)")
    }
    
    static func logDeviceStatus(_ device: LimitlessDevice?) {
        guard let device = device else {
            print("📱 No device connected")
            return
        }
        
        print("📱 Device: \(device.name)")
        print("   - Battery: \(device.batteryLevel)%")
        print("   - Signal: \(device.signalStrength)")
        print("   - Type: \(device.deviceType.rawValue)")
    }
}
#endif

// MARK: - SwiftUI ヘルパー

extension View {
    /// Limitless共通のカードスタイル
    func limitlessCardStyle() -> some View {
        self
            .padding()
            .background(Color.primary.colorInvert())
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    /// Limitless共通のボタンスタイル
    func limitlessButtonStyle(color: Color = .blue) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    /// エラー表示
    func showError(_ error: Binding<LimitlessError?>) -> some View {
        self.alert("エラー", isPresented: .constant(error.wrappedValue != nil)) {
            Button("OK") {
                error.wrappedValue = nil
            }
        } message: {
            if let errorMessage = error.wrappedValue?.errorDescription {
                Text(errorMessage)
            }
            if let recoverySuggestion = error.wrappedValue?.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
    }
}