import Foundation
import SwiftUI
import Combine

// MARK: - Limitless設定の統一管理

/// Limitless機能の設定を統一管理するクラス
/// ConfigurationManagerを基盤として使用し、型安全性と検証機能を提供
@MainActor
final class LimitlessSettings: ObservableObject {
    
    static let shared = LimitlessSettings()
    
    private var configManager: ConfigurationManager!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Core Settings
    
    @Published var isEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessEnabled, value: isEnabled) } }
    }
    
    @Published var debugMode: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessDebugMode, value: debugMode) } }
    }
    
    @Published var performanceMetricsEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessPerformanceMetrics, value: performanceMetricsEnabled) } }
    }
    
    // MARK: - Device Settings
    
    @Published var deviceConnectionTimeout: TimeInterval = AppConstants.Limitless.defaultConnectionTimeout {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessDeviceConnectionTimeout, value: deviceConnectionTimeout) } }
    }
    
    @Published var heartbeatInterval: TimeInterval = AppConstants.Limitless.defaultHeartbeatInterval {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessHeartbeatInterval, value: heartbeatInterval) } }
    }
    
    @Published var maxRetryAttempts: Int = AppConstants.Limitless.defaultMaxRetryAttempts {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessMaxRetryAttempts, value: maxRetryAttempts) } }
    }
    
    @Published var autoReconnectEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessAutoReconnect, value: autoReconnectEnabled) } }
    }
    
    // MARK: - Recording Settings
    
    @Published var maxSessionDuration: TimeInterval = AppConstants.Limitless.defaultMaxSessionDuration {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessMaxSessionDuration, value: maxSessionDuration) } }
    }
    
    @Published var bufferSize: Int = AppConstants.Limitless.defaultBufferSize {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessBufferSize, value: bufferSize) } }
    }
    
    @Published var compressionEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessCompressionEnabled, value: compressionEnabled) } }
    }
    
    // MARK: - AI Processing Settings
    
    @Published var transcriptionBatchSize: Int = AppConstants.Limitless.defaultTranscriptionBatchSize {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessTranscriptionBatchSize, value: transcriptionBatchSize) } }
    }
    
    @Published var aiAnalysisEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessAIAnalysisEnabled, value: aiAnalysisEnabled) } }
    }
    
    @Published var confidenceThreshold: Double = AppConstants.Limitless.defaultConfidenceThreshold {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessConfidenceThreshold, value: confidenceThreshold) } }
    }
    
    // MARK: - UI Settings
    
    @Published var animationDuration: TimeInterval = AppConstants.Limitless.defaultAnimationDuration {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessAnimationDuration, value: animationDuration) } }
    }
    
    @Published var hapticFeedbackEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessHapticFeedback, value: hapticFeedbackEnabled) } }
    }
    
    @Published var accessibilityMode: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessAccessibilityMode, value: accessibilityMode) } }
    }
    
    // MARK: - Cache Settings
    
    @Published var cacheEnabled: Bool = false {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessCacheEnabled, value: cacheEnabled) } }
    }
    
    @Published var maxCacheSize: Int64 = AppConstants.Limitless.defaultMaxCacheSize {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessMaxCacheSize, value: maxCacheSize) } }
    }
    
    @Published var cacheExpirationTime: TimeInterval = AppConstants.Limitless.defaultCacheExpirationTime {
        didSet { Task { try? await configManager.set(ConfigurationKeys.limitlessCacheExpirationTime, value: cacheExpirationTime) } }
    }
    
    // MARK: - 共通設定 (録音品質など)
    
    @Published var recordingQuality: RecordingQuality = .high {
        didSet { Task { try? await configManager.set(ConfigurationKeys.recordingQuality, value: recordingQuality) } }
    }
    
    @Published var autoProcessingEnabled: Bool = true {
        didSet { saveConfiguration() }
    }
    
    @Published var batteryOptimizationEnabled: Bool = true {
        didSet { saveConfiguration() }
    }
    
    @Published var autoCleanupEnabled: Bool = true {
        didSet { saveConfiguration() }
    }
    
    @Published var retentionDays: Int = 30 {
        didSet { saveConfiguration() }
    }
    
    @Published var defaultDisplayMode: DisplayMode = .lifelog {
        didSet { saveConfiguration() }
    }
    
    // MARK: - 初期化
    
    private init() {
        Task { @MainActor in
            configManager = ConfigurationManager.shared
            await loadConfiguration()
        }
    }
    
    // MARK: - Configuration Management
    
    private func loadConfiguration() async {
        // Core Settings
        isEnabled = try! await configManager.get(ConfigurationKeys.limitlessEnabled)
        debugMode = try! await configManager.get(ConfigurationKeys.limitlessDebugMode)
        performanceMetricsEnabled = try! await configManager.get(ConfigurationKeys.limitlessPerformanceMetrics)
        
        // Device Settings
        deviceConnectionTimeout = try! await configManager.get(ConfigurationKeys.limitlessDeviceConnectionTimeout)
        heartbeatInterval = try! await configManager.get(ConfigurationKeys.limitlessHeartbeatInterval)
        maxRetryAttempts = try! await configManager.get(ConfigurationKeys.limitlessMaxRetryAttempts)
        autoReconnectEnabled = try! await configManager.get(ConfigurationKeys.limitlessAutoReconnect)
        
        // Recording Settings
        maxSessionDuration = try! await configManager.get(ConfigurationKeys.limitlessMaxSessionDuration)
        bufferSize = try! await configManager.get(ConfigurationKeys.limitlessBufferSize)
        compressionEnabled = try! await configManager.get(ConfigurationKeys.limitlessCompressionEnabled)
        
        // AI Processing Settings
        transcriptionBatchSize = try! await configManager.get(ConfigurationKeys.limitlessTranscriptionBatchSize)
        aiAnalysisEnabled = try! await configManager.get(ConfigurationKeys.limitlessAIAnalysisEnabled)
        confidenceThreshold = try! await configManager.get(ConfigurationKeys.limitlessConfidenceThreshold)
        
        // UI Settings
        animationDuration = try! await configManager.get(ConfigurationKeys.limitlessAnimationDuration)
        hapticFeedbackEnabled = try! await configManager.get(ConfigurationKeys.limitlessHapticFeedback)
        accessibilityMode = try! await configManager.get(ConfigurationKeys.limitlessAccessibilityMode)
        
        // Cache Settings
        cacheEnabled = try! await configManager.get(ConfigurationKeys.limitlessCacheEnabled)
        maxCacheSize = try! await configManager.get(ConfigurationKeys.limitlessMaxCacheSize)
        cacheExpirationTime = try! await configManager.get(ConfigurationKeys.limitlessCacheExpirationTime)
        
        // 共通設定
        recordingQuality = try! await configManager.get(ConfigurationKeys.recordingQuality)
        
        // UserDefaults から追加設定を読み込み (移行期間)
        loadLegacySettings()
    }
    
    private func loadLegacySettings() {
        let userDefaults = UserDefaults.standard
        autoProcessingEnabled = userDefaults.bool(forKey: "autoProcessingEnabled")
        batteryOptimizationEnabled = userDefaults.bool(forKey: "batteryOptimizationEnabled")
        autoCleanupEnabled = userDefaults.bool(forKey: "autoCleanupEnabled")
        retentionDays = userDefaults.integer(forKey: "retentionDays") == 0 ? 30 : userDefaults.integer(forKey: "retentionDays")
        defaultDisplayMode = DisplayMode(rawValue: userDefaults.string(forKey: "defaultDisplayMode") ?? "") ?? .lifelog
    }
    
    private func saveConfiguration() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(autoProcessingEnabled, forKey: "autoProcessingEnabled")
        userDefaults.set(batteryOptimizationEnabled, forKey: "batteryOptimizationEnabled")
        userDefaults.set(autoCleanupEnabled, forKey: "autoCleanupEnabled")
        userDefaults.set(retentionDays, forKey: "retentionDays")
        userDefaults.set(defaultDisplayMode.rawValue, forKey: "defaultDisplayMode")
    }
    
    // MARK: - Public Methods
    
    func resetToDefaults() async {
        isEnabled = false
        debugMode = false
        performanceMetricsEnabled = false
        deviceConnectionTimeout = AppConstants.Limitless.defaultConnectionTimeout
        heartbeatInterval = AppConstants.Limitless.defaultHeartbeatInterval
        maxRetryAttempts = AppConstants.Limitless.defaultMaxRetryAttempts
        autoReconnectEnabled = false
        maxSessionDuration = AppConstants.Limitless.defaultMaxSessionDuration
        bufferSize = AppConstants.Limitless.defaultBufferSize
        compressionEnabled = false
        transcriptionBatchSize = AppConstants.Limitless.defaultTranscriptionBatchSize
        aiAnalysisEnabled = false
        confidenceThreshold = AppConstants.Limitless.defaultConfidenceThreshold
        animationDuration = AppConstants.Limitless.defaultAnimationDuration
        hapticFeedbackEnabled = false
        accessibilityMode = false
        cacheEnabled = false
        maxCacheSize = AppConstants.Limitless.defaultMaxCacheSize
        cacheExpirationTime = AppConstants.Limitless.defaultCacheExpirationTime
        recordingQuality = .high
        autoProcessingEnabled = true
        batteryOptimizationEnabled = true
        autoCleanupEnabled = true
        retentionDays = 30
        defaultDisplayMode = .lifelog
    }
    
    func exportConfiguration() async throws -> [String: Any] {
        var config: [String: Any] = [:]
        
        // Core Settings
        config["isEnabled"] = isEnabled
        config["debugMode"] = debugMode
        config["performanceMetricsEnabled"] = performanceMetricsEnabled
        
        // Device Settings
        config["deviceConnectionTimeout"] = deviceConnectionTimeout
        config["heartbeatInterval"] = heartbeatInterval
        config["maxRetryAttempts"] = maxRetryAttempts
        config["autoReconnectEnabled"] = autoReconnectEnabled
        
        // Recording Settings
        config["maxSessionDuration"] = maxSessionDuration
        config["bufferSize"] = bufferSize
        config["compressionEnabled"] = compressionEnabled
        
        // AI Processing Settings
        config["transcriptionBatchSize"] = transcriptionBatchSize
        config["aiAnalysisEnabled"] = aiAnalysisEnabled
        config["confidenceThreshold"] = confidenceThreshold
        
        // UI Settings
        config["animationDuration"] = animationDuration
        config["hapticFeedbackEnabled"] = hapticFeedbackEnabled
        config["accessibilityMode"] = accessibilityMode
        
        // Cache Settings
        config["cacheEnabled"] = cacheEnabled
        config["maxCacheSize"] = maxCacheSize
        config["cacheExpirationTime"] = cacheExpirationTime
        
        // 共通設定
        config["recordingQuality"] = recordingQuality.rawValue
        config["autoProcessingEnabled"] = autoProcessingEnabled
        config["batteryOptimizationEnabled"] = batteryOptimizationEnabled
        config["autoCleanupEnabled"] = autoCleanupEnabled
        config["retentionDays"] = retentionDays
        config["defaultDisplayMode"] = defaultDisplayMode.rawValue
        
        return config
    }
    
    func importConfiguration(_ config: [String: Any]) async throws {
        // Core Settings
        if let value = config["isEnabled"] as? Bool {
            isEnabled = value
        }
        if let value = config["debugMode"] as? Bool {
            debugMode = value
        }
        if let value = config["performanceMetricsEnabled"] as? Bool {
            performanceMetricsEnabled = value
        }
        
        // Device Settings
        if let value = config["deviceConnectionTimeout"] as? TimeInterval {
            deviceConnectionTimeout = value
        }
        if let value = config["heartbeatInterval"] as? TimeInterval {
            heartbeatInterval = value
        }
        if let value = config["maxRetryAttempts"] as? Int {
            maxRetryAttempts = value
        }
        if let value = config["autoReconnectEnabled"] as? Bool {
            autoReconnectEnabled = value
        }
        
        // Recording Settings
        if let value = config["maxSessionDuration"] as? TimeInterval {
            maxSessionDuration = value
        }
        if let value = config["bufferSize"] as? Int {
            bufferSize = value
        }
        if let value = config["compressionEnabled"] as? Bool {
            compressionEnabled = value
        }
        
        // AI Processing Settings
        if let value = config["transcriptionBatchSize"] as? Int {
            transcriptionBatchSize = value
        }
        if let value = config["aiAnalysisEnabled"] as? Bool {
            aiAnalysisEnabled = value
        }
        if let value = config["confidenceThreshold"] as? Double {
            confidenceThreshold = value
        }
        
        // UI Settings
        if let value = config["animationDuration"] as? TimeInterval {
            animationDuration = value
        }
        if let value = config["hapticFeedbackEnabled"] as? Bool {
            hapticFeedbackEnabled = value
        }
        if let value = config["accessibilityMode"] as? Bool {
            accessibilityMode = value
        }
        
        // Cache Settings
        if let value = config["cacheEnabled"] as? Bool {
            cacheEnabled = value
        }
        if let value = config["maxCacheSize"] as? Int64 {
            maxCacheSize = value
        }
        if let value = config["cacheExpirationTime"] as? TimeInterval {
            cacheExpirationTime = value
        }
        
        // 共通設定
        if let value = config["recordingQuality"] as? String {
            recordingQuality = RecordingQuality(rawValue: value) ?? .high
        }
        if let value = config["autoProcessingEnabled"] as? Bool {
            autoProcessingEnabled = value
        }
        if let value = config["batteryOptimizationEnabled"] as? Bool {
            batteryOptimizationEnabled = value
        }
        if let value = config["autoCleanupEnabled"] as? Bool {
            autoCleanupEnabled = value
        }
        if let value = config["retentionDays"] as? Int {
            retentionDays = value
        }
        if let value = config["defaultDisplayMode"] as? String {
            defaultDisplayMode = DisplayMode(rawValue: value) ?? .lifelog
        }
    }
    
    // MARK: - Validation
    
    func validateConfiguration() -> [LimitlessError] {
        var errors: [LimitlessError] = []
        
        if !AppConstants.Limitless.connectionTimeoutRange.contains(deviceConnectionTimeout) {
            errors.append(.configurationError("デバイス接続タイムアウトが範囲外です"))
        }
        
        if !AppConstants.Limitless.heartbeatIntervalRange.contains(heartbeatInterval) {
            errors.append(.configurationError("ハートビート間隔が範囲外です"))
        }
        
        if !AppConstants.Limitless.maxRetryAttemptsRange.contains(maxRetryAttempts) {
            errors.append(.configurationError("最大リトライ回数が範囲外です"))
        }
        
        if !AppConstants.Limitless.maxSessionDurationRange.contains(maxSessionDuration) {
            errors.append(.configurationError("最大セッション時間が範囲外です"))
        }
        
        if !AppConstants.Limitless.bufferSizeRange.contains(bufferSize) {
            errors.append(.configurationError("バッファサイズが範囲外です"))
        }
        
        if !AppConstants.Limitless.transcriptionBatchSizeRange.contains(transcriptionBatchSize) {
            errors.append(.configurationError("文字起こしバッチサイズが範囲外です"))
        }
        
        if !AppConstants.Limitless.confidenceThresholdRange.contains(confidenceThreshold) {
            errors.append(.configurationError("信頼度閾値が範囲外です"))
        }
        
        if !AppConstants.Limitless.animationDurationRange.contains(animationDuration) {
            errors.append(.configurationError("アニメーション時間が範囲外です"))
        }
        
        if !AppConstants.Limitless.maxCacheSizeRange.contains(maxCacheSize) {
            errors.append(.configurationError("最大キャッシュサイズが範囲外です"))
        }
        
        if !AppConstants.Limitless.cacheExpirationTimeRange.contains(cacheExpirationTime) {
            errors.append(.configurationError("キャッシュ有効期限が範囲外です"))
        }
        
        return errors
    }
    
    // MARK: - Optimization Suggestions
    
    func getOptimizationSuggestions() -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []
        
        // バッテリー最適化の提案
        if heartbeatInterval < 10 && !performanceMetricsEnabled {
            suggestions.append(.batterySaving("ハートビート間隔を10秒に増やすことでバッテリー寿命を延ばせます"))
        }
        
        // パフォーマンス最適化の提案
        if transcriptionBatchSize < 5 {
            suggestions.append(.performance("文字起こしバッチサイズを5以上にすることで処理効率が向上します"))
        }
        
        // ストレージ最適化の提案
        if !cacheEnabled && maxCacheSize > 50 * 1024 * 1024 {
            suggestions.append(.storage("キャッシュを有効にすることで応答性が向上します"))
        }
        
        // アクセシビリティの提案
        if !accessibilityMode && animationDuration > 0.5 {
            suggestions.append(.accessibility("アクセシビリティモードを有効にすることで使いやすさが向上します"))
        }
        
        return suggestions
    }
}

// MARK: - Supporting Types

enum OptimizationSuggestion {
    case batterySaving(String)
    case performance(String)
    case storage(String)
    case accessibility(String)
    
    var title: String {
        switch self {
        case .batterySaving:
            return "バッテリー最適化"
        case .performance:
            return "パフォーマンス向上"
        case .storage:
            return "ストレージ最適化"
        case .accessibility:
            return "アクセシビリティ向上"
        }
    }
    
    var message: String {
        switch self {
        case .batterySaving(let message),
             .performance(let message),
             .storage(let message),
             .accessibility(let message):
            return message
        }
    }
    
    var icon: String {
        switch self {
        case .batterySaving:
            return "battery.100"
        case .performance:
            return "speedometer"
        case .storage:
            return "internaldrive"
        case .accessibility:
            return "accessibility"
        }
    }
}