import Foundation
import CoreGraphics

// MARK: - App Configuration

struct AppConfiguration {
    // MARK: - Project Settings
    struct Project {
        static let maxNameLength = 100
        static let maxDescriptionLength = 500
        static let defaultCoverImageColors = [
            "blue", "purple", "green", "orange", "pink", "indigo"
        ]
    }
    
    // MARK: - Recording Settings
    struct Recording {
        static let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
        static let minDuration: TimeInterval = 1.0 // 1秒
        static let maxDuration: TimeInterval = 4 * 60 * 60 // 4時間
        static let defaultQuality = "high"
        static let supportedFormats = ["m4a", "wav", "mp3", "aac"]
    }
    
    // MARK: - Image Settings
    struct Image {
        static let maxFileSize: Int64 = 5 * 1024 * 1024 // 5MB
        static let maxDimensions = CGSize(width: 800, height: 600)
        static let compressionQuality: CGFloat = 0.8
        static let thumbnailSize = CGSize(width: 200, height: 200)
        static let cardImageHeight: CGFloat = 80
        static let rowImageSize = CGSize(width: 60, height: 60)
    }
    
    // MARK: - UI Settings
    struct UI {
        static let searchDebounceDelay: TimeInterval = 0.3
        static let animationDuration: TimeInterval = 0.2
        static let cardCornerRadius: CGFloat = 12
        static let buttonCornerRadius: CGFloat = 8
        static let listItemHeight: CGFloat = 80
        static let gridSpacing: CGFloat = 16
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
    }
    
    // MARK: - Performance Settings
    struct Performance {
        static let backgroundContextTimeout: TimeInterval = 30.0
        static let imageLoadTimeout: TimeInterval = 10.0
        static let networkTimeout: TimeInterval = 30.0
        static let maxConcurrentOperations = 3
    }
    
    // MARK: - Storage Settings
    struct Storage {
        static let audioDirectoryName = "Audio"
        static let backupDirectoryName = "Backups"
        static let tempDirectoryName = "Temp"
        static let cacheDirectoryName = "Cache"
        static let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
        static let autoCleanupDays = 30
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let projectNamePattern = "^[\\s\\S]{1,100}$"
        static let emailPattern = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        static let phonePattern = "^[0-9+\\-\\s()]{10,15}$"
    }
    
    // MARK: - Feature Flags
    struct Features {
        static let enableCloudSync = false
        static let enableAdvancedSearch = true
        static let enableProjectSharing = false
        static let enableAdvancedAnalytics = false
        static let enableOfflineMode = true
    }
    
    // MARK: - Development Settings
    struct Development {
        static let enableDebugLogging = true
        static let enablePerformanceMetrics = false
        static let mockDataEnabled = false
    }
}

// MARK: - Configuration Manager

class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()
    
    @Published var currentTheme: AppTheme = .system
    @Published var preferredLanguage: String = "ja"
    @Published var enableHapticFeedback: Bool = true
    @Published var enableSoundEffects: Bool = true
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        // UserDefaultsから設定を読み込み
        currentTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "app_theme") ?? "system") ?? .system
        preferredLanguage = UserDefaults.standard.string(forKey: "preferred_language") ?? "ja"
        enableHapticFeedback = UserDefaults.standard.bool(forKey: "enable_haptic_feedback")
        enableSoundEffects = UserDefaults.standard.bool(forKey: "enable_sound_effects")
    }
    
    func saveConfiguration() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(preferredLanguage, forKey: "preferred_language")
        UserDefaults.standard.set(enableHapticFeedback, forKey: "enable_haptic_feedback")
        UserDefaults.standard.set(enableSoundEffects, forKey: "enable_sound_effects")
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .system: return "システム設定"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Validation Helper

struct ValidationHelper {
    static func validateProjectName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= AppConfiguration.Project.maxNameLength
    }
    
    static func validateProjectDescription(_ description: String) -> Bool {
        return description.count <= AppConfiguration.Project.maxDescriptionLength
    }
    
    static func validateImageSize(_ data: Data) -> Bool {
        return data.count <= AppConfiguration.Image.maxFileSize
    }
    
    static func validateRecordingDuration(_ duration: TimeInterval) -> Bool {
        return duration >= AppConfiguration.Recording.minDuration &&
               duration <= AppConfiguration.Recording.maxDuration
    }
}

// MARK: - Date Formatting Service

class DateFormattingService {
    static let shared = DateFormattingService()
    
    private let shortTimeFormatter: DateFormatter
    private let mediumDateFormatter: DateFormatter
    private let fullDateTimeFormatter: DateFormatter
    private let relativeFormatter: RelativeDateTimeFormatter
    
    private init() {
        shortTimeFormatter = DateFormatter()
        shortTimeFormatter.timeStyle = .short
        
        mediumDateFormatter = DateFormatter()
        mediumDateFormatter.dateStyle = .medium
        
        fullDateTimeFormatter = DateFormatter()
        fullDateTimeFormatter.dateStyle = .medium
        fullDateTimeFormatter.timeStyle = .short
        
        relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
    }
    
    func formatCreatedAt(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "今日 \(shortTimeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "昨日 \(shortTimeFormatter.string(from: date))"
        } else {
            return mediumDateFormatter.string(from: date)
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    func formatRelativeDate(_ date: Date) -> String {
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}