import Foundation
import CoreGraphics

// MARK: - Validation Helper

/// 共通のバリデーション機能を提供するヘルパークラス
struct ValidationHelper {
    
    // MARK: - Project Validation
    
    static func validateProjectName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= AppConstants.Project.maxNameLength
    }
    
    static func validateProjectDescription(_ description: String) -> Bool {
        return description.count <= AppConstants.Project.maxDescriptionLength
    }
    
    // MARK: - Image Validation
    
    static func validateImageSize(_ data: Data) -> Bool {
        return data.count <= AppConstants.Image.maxFileSize
    }
    
    static func validateImageDimensions(_ size: CGSize) -> Bool {
        let maxDimensions = AppConstants.Image.maxDimensions
        return size.width <= maxDimensions.width && size.height <= maxDimensions.height
    }
    
    // MARK: - Recording Validation
    
    static func validateRecordingDuration(_ duration: TimeInterval) -> Bool {
        return duration >= AppConstants.Recording.minDuration &&
               duration <= AppConstants.Recording.maxDuration
    }
    
    static func validateRecordingFileSize(_ size: Int64) -> Bool {
        return size <= AppConstants.Recording.maxFileSize
    }
    
    static func validateAudioFormat(_ format: String) -> Bool {
        return AppConstants.Recording.supportedFormats.contains(format.lowercased())
    }
    
    // MARK: - Email and Contact Validation
    
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = AppConstants.Validation.emailPattern
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func validatePhone(_ phone: String) -> Bool {
        let phoneRegex = AppConstants.Validation.phonePattern
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    // MARK: - Limitless Validation
    
    static func validateLimitlessConnectionTimeout(_ timeout: TimeInterval) -> Bool {
        return AppConstants.Limitless.connectionTimeoutRange.contains(timeout)
    }
    
    static func validateLimitlessHeartbeatInterval(_ interval: TimeInterval) -> Bool {
        return AppConstants.Limitless.heartbeatIntervalRange.contains(interval)
    }
    
    static func validateLimitlessRetryAttempts(_ attempts: Int) -> Bool {
        return AppConstants.Limitless.maxRetryAttemptsRange.contains(attempts)
    }
    
    static func validateLimitlessSessionDuration(_ duration: TimeInterval) -> Bool {
        return AppConstants.Limitless.maxSessionDurationRange.contains(duration)
    }
    
    static func validateLimitlessBufferSize(_ size: Int) -> Bool {
        return AppConstants.Limitless.bufferSizeRange.contains(size)
    }
    
    static func validateLimitlessTranscriptionBatchSize(_ size: Int) -> Bool {
        return AppConstants.Limitless.transcriptionBatchSizeRange.contains(size)
    }
    
    static func validateLimitlessConfidenceThreshold(_ threshold: Double) -> Bool {
        return AppConstants.Limitless.confidenceThresholdRange.contains(threshold)
    }
    
    static func validateLimitlessAnimationDuration(_ duration: TimeInterval) -> Bool {
        return AppConstants.Limitless.animationDurationRange.contains(duration)
    }
    
    static func validateLimitlessMaxCacheSize(_ size: Int64) -> Bool {
        return AppConstants.Limitless.maxCacheSizeRange.contains(size)
    }
    
    static func validateLimitlessCacheExpirationTime(_ time: TimeInterval) -> Bool {
        return AppConstants.Limitless.cacheExpirationTimeRange.contains(time)
    }
    
    // MARK: - General Validation
    
    static func validateStringLength(_ string: String, minLength: Int = 0, maxLength: Int) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= minLength && trimmed.count <= maxLength
    }
    
    static func validateNumericRange<T: Comparable>(_ value: T, range: ClosedRange<T>) -> Bool {
        return range.contains(value)
    }
    
    static func validateFileSize(_ size: Int64, maxSize: Int64) -> Bool {
        return size > 0 && size <= maxSize
    }
    
    // MARK: - URL Validation
    
    static func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        // クロスプラットフォーム対応: 基本的なURL検証のみ実行
        return url.scheme != nil && url.host != nil
    }
    
    static func validateWebURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    // MARK: - File Path Validation
    
    static func validateFilePath(_ path: String, allowedExtensions: [String] = []) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else { return false }
        
        // Check file extension if specified
        if !allowedExtensions.isEmpty {
            let fileExtension = url.pathExtension.lowercased()
            return allowedExtensions.contains(fileExtension)
        }
        
        return true
    }
    
    // MARK: - Advanced Validation with Error Messages
    
    enum ValidationError: Error, LocalizedError {
        case projectNameTooLong(Int)
        case projectNameEmpty
        case projectDescriptionTooLong(Int)
        case imageSizeTooLarge(Int64, Int64)
        case imageDimensionsTooLarge(CGSize, CGSize)
        case recordingDurationOutOfRange(TimeInterval, ClosedRange<TimeInterval>)
        case recordingFileSizeTooLarge(Int64, Int64)
        case audioFormatUnsupported(String, [String])
        case emailInvalid(String)
        case phoneInvalid(String)
        case urlInvalid(String)
        case filePathInvalid(String)
        case numericValueOutOfRange(String, String)
        case stringLengthInvalid(String, Int, Int)
        
        var errorDescription: String? {
            switch self {
            case .projectNameTooLong(let maxLength):
                return "プロジェクト名は\(maxLength)文字以内で入力してください"
            case .projectNameEmpty:
                return "プロジェクト名を入力してください"
            case .projectDescriptionTooLong(let maxLength):
                return "プロジェクト説明は\(maxLength)文字以内で入力してください"
            case .imageSizeTooLarge(let size, let maxSize):
                return "画像サイズが大きすぎます: \(formatFileSize(size)) (最大: \(formatFileSize(maxSize)))"
            case .imageDimensionsTooLarge(let size, let maxSize):
                return "画像の解像度が大きすぎます: \(Int(size.width))x\(Int(size.height)) (最大: \(Int(maxSize.width))x\(Int(maxSize.height)))"
            case .recordingDurationOutOfRange(let duration, let range):
                return "録音時間が範囲外です: \(formatDuration(duration)) (範囲: \(formatDuration(range.lowerBound)) - \(formatDuration(range.upperBound)))"
            case .recordingFileSizeTooLarge(let size, let maxSize):
                return "録音ファイルサイズが大きすぎます: \(formatFileSize(size)) (最大: \(formatFileSize(maxSize)))"
            case .audioFormatUnsupported(let format, let supportedFormats):
                return "サポートされていない音声フォーマットです: \(format) (サポート: \(supportedFormats.joined(separator: ", ")))"
            case .emailInvalid(let email):
                return "無効なメールアドレスです: \(email)"
            case .phoneInvalid(let phone):
                return "無効な電話番号です: \(phone)"
            case .urlInvalid(let url):
                return "無効なURLです: \(url)"
            case .filePathInvalid(let path):
                return "無効なファイルパスです: \(path)"
            case .numericValueOutOfRange(let field, let range):
                return "\(field)が範囲外です: \(range)"
            case .stringLengthInvalid(let field, let minLength, let maxLength):
                return "\(field)の長さが無効です: \(minLength) - \(maxLength)文字で入力してください"
            }
        }
        
        private func formatFileSize(_ bytes: Int64) -> String {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        
        private func formatDuration(_ duration: TimeInterval) -> String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            return formatter.string(from: duration) ?? "\(Int(duration))秒"
        }
    }
    
    static func validateProjectNameWithError(_ name: String) -> ValidationError? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .projectNameEmpty
        }
        
        if trimmed.count > AppConstants.Project.maxNameLength {
            return .projectNameTooLong(AppConstants.Project.maxNameLength)
        }
        
        return nil
    }
    
    static func validateProjectDescriptionWithError(_ description: String) -> ValidationError? {
        if description.count > AppConstants.Project.maxDescriptionLength {
            return .projectDescriptionTooLong(AppConstants.Project.maxDescriptionLength)
        }
        return nil
    }
    
    static func validateImageSizeWithError(_ data: Data) -> ValidationError? {
        let maxSize = AppConstants.Image.maxFileSize
        if data.count > maxSize {
            return .imageSizeTooLarge(Int64(data.count), maxSize)
        }
        return nil
    }
    
    static func validateRecordingDurationWithError(_ duration: TimeInterval) -> ValidationError? {
        let range = AppConstants.Recording.minDuration...AppConstants.Recording.maxDuration
        if !range.contains(duration) {
            return .recordingDurationOutOfRange(duration, range)
        }
        return nil
    }
    
    static func validateEmailWithError(_ email: String) -> ValidationError? {
        if !validateEmail(email) {
            return .emailInvalid(email)
        }
        return nil
    }
    
    static func validatePhoneWithError(_ phone: String) -> ValidationError? {
        if !validatePhone(phone) {
            return .phoneInvalid(phone)
        }
        return nil
    }
}