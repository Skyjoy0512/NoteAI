import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Application Constants

/// Static application constants that don't change during runtime
struct AppConstants {
    
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
    
    // MARK: - Limitless Constants
    struct Limitless {
        static let defaultConnectionTimeout: TimeInterval = 10.0
        static let defaultHeartbeatInterval: TimeInterval = 5.0
        static let defaultMaxRetryAttempts = 3
        static let defaultMaxSessionDuration: TimeInterval = 3600.0
        static let defaultBufferSize = 4096
        static let defaultTranscriptionBatchSize = 10
        static let defaultConfidenceThreshold: Double = 0.8
        static let defaultAnimationDuration: TimeInterval = 0.3
        static let defaultMaxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
        static let defaultCacheExpirationTime: TimeInterval = 24 * 3600 // 24 hours
        
        // Validation ranges
        static let connectionTimeoutRange: ClosedRange<TimeInterval> = 1.0...60.0
        static let heartbeatIntervalRange: ClosedRange<TimeInterval> = 1.0...30.0
        static let maxRetryAttemptsRange: ClosedRange<Int> = 1...10
        static let maxSessionDurationRange: ClosedRange<TimeInterval> = 60.0...86400.0
        static let bufferSizeRange: ClosedRange<Int> = 1024...65536
        static let transcriptionBatchSizeRange: ClosedRange<Int> = 1...50
        static let confidenceThresholdRange: ClosedRange<Double> = 0.0...1.0
        static let animationDurationRange: ClosedRange<TimeInterval> = 0.1...2.0
        static let maxCacheSizeRange: ClosedRange<Int64> = (10 * 1024 * 1024)...(1024 * 1024 * 1024)
        static let cacheExpirationTimeRange: ClosedRange<TimeInterval> = 3600...(7 * 24 * 3600)
    }
}

// MARK: - App Theme
enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .auto: return "自動"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

// MARK: - App Language
enum AppLanguage: String, CaseIterable, Codable {
    case japanese = "ja"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }
}

// MARK: - Backup Frequency
enum BackupFrequency: String, CaseIterable, Codable {
    case manual = "manual"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .manual: return "手動"
        case .daily: return "毎日"
        case .weekly: return "毎週"
        case .monthly: return "毎月"
        }
    }
}

// MARK: - Transcription Method
// TranscriptionMethod is defined in Domain/Entities/Enums.swift
// Use the canonical complex enum with associated values from the Domain layer