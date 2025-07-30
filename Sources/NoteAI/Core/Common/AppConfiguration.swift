import Foundation
import CoreGraphics

// MARK: - App Configuration (Legacy Support)

/// レガシーサポート用のアプリケーション設定
/// 新しいコードでは AppConstants を使用してください
@available(*, deprecated, message: "Use AppConstants instead")
struct AppConfiguration {
    // MARK: - Project Settings
    struct Project {
        static let maxNameLength = AppConstants.Project.maxNameLength
        static let maxDescriptionLength = AppConstants.Project.maxDescriptionLength
        static let defaultCoverImageColors = AppConstants.Project.defaultCoverImageColors
    }
    
    // MARK: - Recording Settings
    struct Recording {
        static let maxFileSize = AppConstants.Recording.maxFileSize
        static let minDuration = AppConstants.Recording.minDuration
        static let maxDuration = AppConstants.Recording.maxDuration
        static let defaultQuality = AppConstants.Recording.defaultQuality
        static let supportedFormats = AppConstants.Recording.supportedFormats
    }
    
    // MARK: - Image Settings
    struct Image {
        static let maxFileSize = AppConstants.Image.maxFileSize
        static let maxDimensions = AppConstants.Image.maxDimensions
        static let compressionQuality = AppConstants.Image.compressionQuality
        static let thumbnailSize = AppConstants.Image.thumbnailSize
        static let cardImageHeight = AppConstants.Image.cardImageHeight
        static let rowImageSize = AppConstants.Image.rowImageSize
    }
    
    // MARK: - UI Settings
    struct UI {
        static let searchDebounceDelay = AppConstants.UI.searchDebounceDelay
        static let animationDuration = AppConstants.UI.animationDuration
        static let cardCornerRadius = AppConstants.UI.cardCornerRadius
        static let buttonCornerRadius = AppConstants.UI.buttonCornerRadius
        static let listItemHeight = AppConstants.UI.listItemHeight
        static let gridSpacing = AppConstants.UI.gridSpacing
        static let standardPadding = AppConstants.UI.standardPadding
        static let smallPadding = AppConstants.UI.smallPadding
    }
    
    // MARK: - Performance Settings
    struct Performance {
        static let backgroundContextTimeout = AppConstants.Performance.backgroundContextTimeout
        static let imageLoadTimeout = AppConstants.Performance.imageLoadTimeout
        static let networkTimeout = AppConstants.Performance.networkTimeout
        static let maxConcurrentOperations = AppConstants.Performance.maxConcurrentOperations
    }
    
    // MARK: - Storage Settings
    struct Storage {
        static let audioDirectoryName = AppConstants.Storage.audioDirectoryName
        static let backupDirectoryName = AppConstants.Storage.backupDirectoryName
        static let tempDirectoryName = AppConstants.Storage.tempDirectoryName
        static let cacheDirectoryName = AppConstants.Storage.cacheDirectoryName
        static let maxCacheSize = AppConstants.Storage.maxCacheSize
        static let autoCleanupDays = AppConstants.Storage.autoCleanupDays
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let projectNamePattern = AppConstants.Validation.projectNamePattern
        static let emailPattern = AppConstants.Validation.emailPattern
        static let phonePattern = AppConstants.Validation.phonePattern
    }
    
    // MARK: - Feature Flags
    struct Features {
        static let enableCloudSync = AppConstants.Features.enableCloudSync
        static let enableAdvancedSearch = AppConstants.Features.enableAdvancedSearch
        static let enableProjectSharing = AppConstants.Features.enableProjectSharing
        static let enableAdvancedAnalytics = AppConstants.Features.enableAdvancedAnalytics
        static let enableOfflineMode = AppConstants.Features.enableOfflineMode
    }
    
    // MARK: - Development Settings
    struct Development {
        static let enableDebugLogging = AppConstants.Development.enableDebugLogging
        static let enablePerformanceMetrics = AppConstants.Development.enablePerformanceMetrics
        static let mockDataEnabled = AppConstants.Development.mockDataEnabled
    }
}

// MARK: - Configuration Manager (Legacy)

/// レガシーサポート用の設定管理
/// 新しいコードでは ConfigurationManager.shared を使用してください
@available(*, deprecated, message: "Use ConfigurationManager.shared instead")
@MainActor
class LegacyConfigurationManager: ObservableObject {
    static let shared = LegacyConfigurationManager()
    
    @Published var currentTheme: AppTheme = .auto
    @Published var preferredLanguage: String = "ja"
    @Published var enableHapticFeedback: Bool = true
    @Published var enableSoundEffects: Bool = true
    
    private var configManager: ConfigurationManager!
    
    private init() {
        Task { @MainActor in
            configManager = ConfigurationManager.shared
            await loadConfiguration()
        }
    }
    
    @MainActor
    private func loadConfiguration() async {
        do {
            currentTheme = try await configManager.get(ConfigurationKeys.appTheme)
            preferredLanguage = (try await configManager.get(ConfigurationKeys.appLanguage)).rawValue
            enableHapticFeedback = try await configManager.get(ConfigurationKeys.enableHapticFeedback)
            enableSoundEffects = try await configManager.get(ConfigurationKeys.enableSoundEffects)
        } catch {
            // Fallback to UserDefaults for backward compatibility
            loadFromUserDefaults()
        }
    }
    
    @MainActor
    private func loadFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        currentTheme = AppTheme(rawValue: userDefaults.string(forKey: "app_theme") ?? "auto") ?? .auto
        preferredLanguage = userDefaults.string(forKey: "preferred_language") ?? "ja"
        enableHapticFeedback = userDefaults.bool(forKey: "enable_haptic_feedback")
        enableSoundEffects = userDefaults.bool(forKey: "enable_sound_effects")
    }
    
    @MainActor
    func saveConfiguration() {
        Task {
            do {
                try await configManager.set(ConfigurationKeys.appTheme, value: currentTheme)
                try await configManager.set(ConfigurationKeys.appLanguage, value: AppLanguage(rawValue: preferredLanguage) ?? .japanese)
                try await configManager.set(ConfigurationKeys.enableHapticFeedback, value: enableHapticFeedback)
                try await configManager.set(ConfigurationKeys.enableSoundEffects, value: enableSoundEffects)
            } catch {
                // Fallback to UserDefaults
                saveToUserDefaults()
            }
        }
    }
    
    @MainActor
    private func saveToUserDefaults() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(currentTheme.rawValue, forKey: "app_theme")
        userDefaults.set(preferredLanguage, forKey: "preferred_language")
        userDefaults.set(enableHapticFeedback, forKey: "enable_haptic_feedback")
        userDefaults.set(enableSoundEffects, forKey: "enable_sound_effects")
    }
}

// MARK: - Migration Support

/// 設定の移行をサポートするヘルパー
struct ConfigurationMigrationHelper {
    
    /// レガシー設定から新しい設定システムに移行
    static func migrateIfNeeded() async {
        let configManager = await ConfigurationManager.shared
        
        // アプリバージョンチェック
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lastVersion = try? await configManager.get(ConfigurationKeys.appVersion)
        
        if lastVersion != currentVersion {
            await performMigration(from: lastVersion, to: currentVersion)
        }
    }
    
    private static func performMigration(from oldVersion: String?, to newVersion: String) async {
        let configManager = await ConfigurationManager.shared
        
        // バージョン情報を更新
        try? await configManager.set(ConfigurationKeys.appVersion, value: newVersion)
        
        // 必要に応じて特定のバージョン間のマイグレーション処理を実行
        if let oldVersion = oldVersion {
            try? await configManager.migrate(from: oldVersion, to: newVersion)
        }
    }
}