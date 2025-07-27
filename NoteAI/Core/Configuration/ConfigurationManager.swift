import Foundation
import Security

// MARK: - 設定管理プロトコル

protocol ConfigurationManagerProtocol {
    func get<T>(_ key: ConfigurationKey<T>) async throws -> T
    func set<T>(_ key: ConfigurationKey<T>, value: T) async throws
    func remove<T>(_ key: ConfigurationKey<T>) async throws
    func exists<T>(_ key: ConfigurationKey<T>) async -> Bool
    func migrate(from oldVersion: String, to newVersion: String) async throws
    func export() async throws -> Data
    func import(from data: Data) async throws
}

// MARK: - 設定キー

struct ConfigurationKey<T> {
    let name: String
    let storage: StorageType
    let defaultValue: T
    let validator: ((T) -> Bool)?
    let migrationKey: String?
    
    init(
        name: String,
        storage: StorageType,
        defaultValue: T,
        validator: ((T) -> Bool)? = nil,
        migrationKey: String? = nil
    ) {
        self.name = name
        self.storage = storage
        self.defaultValue = defaultValue
        self.validator = validator
        self.migrationKey = migrationKey
    }
}

// MARK: - ストレージタイプ

enum StorageType {
    case userDefaults
    case keychain(accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly)
    case database
    case memory
    
    enum KeychainAccessibility {
        case whenUnlockedThisDeviceOnly
        case whenUnlocked
        case afterFirstUnlockThisDeviceOnly
        case afterFirstUnlock
        case whenPasscodeSetThisDeviceOnly
        
        var secAccessibility: CFString {
            switch self {
            case .whenUnlockedThisDeviceOnly:
                return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .whenUnlocked:
                return kSecAttrAccessibleWhenUnlocked
            case .afterFirstUnlockThisDeviceOnly:
                return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .afterFirstUnlock:
                return kSecAttrAccessibleAfterFirstUnlock
            case .whenPasscodeSetThisDeviceOnly:
                return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            }
        }
    }
}

// MARK: - 設定管理実装

@MainActor
class ConfigurationManager: ConfigurationManagerProtocol {
    
    // MARK: - シングルトン
    static let shared = ConfigurationManager()
    
    // MARK: - ストレージ
    private let userDefaults = UserDefaults.standard
    private let keychainService = "com.noteai.config"
    private var memoryStorage: [String: Any] = [:]
    private var databaseStorage: [String: Any] = [:] // TODO: Core Data連携
    
    // MARK: - 初期化
    private init() {}
    
    // MARK: - プロトコル実装
    
    func get<T>(_ key: ConfigurationKey<T>) async throws -> T {
        if await exists(key) {
            return try await getValue(key)
        } else {
            return key.defaultValue
        }
    }
    
    func set<T>(_ key: ConfigurationKey<T>, value: T) async throws {
        // バリデーション
        if let validator = key.validator, !validator(value) {
            throw ConfigurationError.validationFailed(
                key: key.name,
                reason: "Value validation failed"
            )
        }
        
        try await setValue(key, value: value)
    }
    
    func remove<T>(_ key: ConfigurationKey<T>) async throws {
        switch key.storage {
        case .userDefaults:
            userDefaults.removeObject(forKey: key.name)
            
        case .keychain:
            try removeFromKeychain(key: key.name)
            
        case .database:
            databaseStorage.removeValue(forKey: key.name)
            
        case .memory:
            memoryStorage.removeValue(forKey: key.name)
        }
    }
    
    func exists<T>(_ key: ConfigurationKey<T>) async -> Bool {
        switch key.storage {
        case .userDefaults:
            return userDefaults.object(forKey: key.name) != nil
            
        case .keychain:
            return keychainItemExists(key: key.name)
            
        case .database:
            return databaseStorage[key.name] != nil
            
        case .memory:
            return memoryStorage[key.name] != nil
        }
    }
    
    func migrate(from oldVersion: String, to newVersion: String) async throws {
        let migrations = getMigrations(from: oldVersion, to: newVersion)
        
        for migration in migrations {
            try await migration.execute()
        }
        
        // バージョン情報を更新
        try await set(ConfigurationKeys.appVersion, value: newVersion)
    }
    
    func export() async throws -> Data {
        var exportData: [String: Any] = [:]
        
        // UserDefaults からエクスポート
        let userDefaultsKeys = getAllUserDefaultsKeys()
        for key in userDefaultsKeys {
            exportData[key] = userDefaults.object(forKey: key)
        }
        
        // メモリストレージからエクスポート
        for (key, value) in memoryStorage {
            exportData[key] = value
        }
        
        // Keychainは機密性のためエクスポートしない
        
        return try JSONSerialization.data(withJSONObject: exportData)
    }
    
    func import(from data: Data) async throws {
        guard let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigurationError.corruptedData(key: "import")
        }
        
        for (key, value) in importData {
            userDefaults.set(value, forKey: key)
        }
    }
    
    // MARK: - 内部メソッド
    
    private func getValue<T>(_ key: ConfigurationKey<T>) async throws -> T {
        switch key.storage {
        case .userDefaults:
            return try getUserDefaultsValue(key)
            
        case .keychain:
            return try getKeychainValue(key)
            
        case .database:
            return try getDatabaseValue(key)
            
        case .memory:
            return try getMemoryValue(key)
        }
    }
    
    private func setValue<T>(_ key: ConfigurationKey<T>, value: T) async throws {
        switch key.storage {
        case .userDefaults:
            try setUserDefaultsValue(key, value: value)
            
        case .keychain(let accessibility):
            try setKeychainValue(key, value: value, accessibility: accessibility)
            
        case .database:
            try setDatabaseValue(key, value: value)
            
        case .memory:
            setMemoryValue(key, value: value)
        }
    }
    
    // MARK: - UserDefaults操作
    
    private func getUserDefaultsValue<T>(_ key: ConfigurationKey<T>) throws -> T {
        let value = userDefaults.object(forKey: key.name)
        
        guard let typedValue = value as? T else {
            throw ConfigurationError.invalidValue(key: key.name, value: value ?? "nil")
        }
        
        return typedValue
    }
    
    private func setUserDefaultsValue<T>(_ key: ConfigurationKey<T>, value: T) throws {
        userDefaults.set(value, forKey: key.name)
    }
    
    // MARK: - Keychain操作
    
    private func getKeychainValue<T>(_ key: ConfigurationKey<T>) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key.name,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw ConfigurationError.keyNotFound(key: key.name)
        }
        
        guard let data = result as? Data,
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            throw ConfigurationError.corruptedData(key: key.name)
        }
        
        return value
    }
    
    private func setKeychainValue<T>(
        _ key: ConfigurationKey<T>,
        value: T,
        accessibility: StorageType.KeychainAccessibility
    ) throws {
        let data = try JSONEncoder().encode(value)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key.name,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.secAccessibility
        ]
        
        // 既存のアイテムを削除
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key.name
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 新しいアイテムを追加
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw ConfigurationError.storageError(message: "Keychain write failed: \(status)")
        }
    }
    
    private func removeFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ConfigurationError.storageError(message: "Keychain delete failed: \(status)")
        }
    }
    
    private func keychainItemExists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    
    // MARK: - Database操作
    
    private func getDatabaseValue<T>(_ key: ConfigurationKey<T>) throws -> T {
        guard let value = databaseStorage[key.name] as? T else {
            throw ConfigurationError.keyNotFound(key: key.name)
        }
        return value
    }
    
    private func setDatabaseValue<T>(_ key: ConfigurationKey<T>, value: T) throws {
        databaseStorage[key.name] = value
        // TODO: Core Dataに永続化
    }
    
    // MARK: - Memory操作
    
    private func getMemoryValue<T>(_ key: ConfigurationKey<T>) throws -> T {
        guard let value = memoryStorage[key.name] as? T else {
            throw ConfigurationError.keyNotFound(key: key.name)
        }
        return value
    }
    
    private func setMemoryValue<T>(_ key: ConfigurationKey<T>, value: T) {
        memoryStorage[key.name] = value
    }
    
    // MARK: - ヘルパーメソッド
    
    private func getAllUserDefaultsKeys() -> [String] {
        return Array(userDefaults.dictionaryRepresentation().keys)
    }
    
    private func getMigrations(from oldVersion: String, to newVersion: String) -> [ConfigurationMigration] {
        var migrations: [ConfigurationMigration] = []
        
        // バージョン固有のマイグレーション
        if oldVersion < "1.1.0" && to >= "1.1.0" {
            migrations.append(Migration_1_0_to_1_1())
        }
        
        if oldVersion < "1.2.0" && to >= "1.2.0" {
            migrations.append(Migration_1_1_to_1_2())
        }
        
        return migrations
    }
}

// MARK: - 設定マイグレーション

protocol ConfigurationMigration {
    func execute() async throws
}

struct Migration_1_0_to_1_1: ConfigurationMigration {
    func execute() async throws {
        // 1.0 → 1.1 のマイグレーション処理
        print("Migrating configuration from 1.0 to 1.1")
    }
}

struct Migration_1_1_to_1_2: ConfigurationMigration {
    func execute() async throws {
        // 1.1 → 1.2 のマイグレーション処理
        print("Migrating configuration from 1.1 to 1.2")
    }
}

// MARK: - 事前定義された設定キー

struct ConfigurationKeys {
    
    // MARK: - アプリ設定
    static let appVersion = ConfigurationKey(
        name: "app_version",
        storage: .userDefaults,
        defaultValue: "1.0.0"
    )
    
    static let appTheme = ConfigurationKey(
        name: "app_theme",
        storage: .userDefaults,
        defaultValue: AppTheme.auto
    )
    
    static let appLanguage = ConfigurationKey(
        name: "app_language",
        storage: .userDefaults,
        defaultValue: AppLanguage.japanese
    )
    
    // MARK: - 録音設定
    static let recordingQuality = ConfigurationKey(
        name: "recording_quality",
        storage: .userDefaults,
        defaultValue: RecordingQuality.standard,
        validator: { RecordingQuality.allCases.contains($0) }
    )
    
    static let audioFormat = ConfigurationKey(
        name: "audio_format",
        storage: .userDefaults,
        defaultValue: AudioFormat.m4a,
        validator: { AudioFormat.allCases.contains($0) }
    )
    
    static let allowBackgroundRecording = ConfigurationKey(
        name: "allow_background_recording",
        storage: .userDefaults,
        defaultValue: true
    )
    
    static let autoStopRecording = ConfigurationKey(
        name: "auto_stop_recording",
        storage: .userDefaults,
        defaultValue: false
    )
    
    static let autoStopDuration = ConfigurationKey(
        name: "auto_stop_duration",
        storage: .userDefaults,
        defaultValue: 60,
        validator: { $0 > 0 && $0 <= 3600 }
    )
    
    // MARK: - AI設定
    static let defaultLanguage = ConfigurationKey(
        name: "default_language",
        storage: .userDefaults,
        defaultValue: SupportedLanguage.japanese
    )
    
    static let transcriptionMethod = ConfigurationKey(
        name: "transcription_method",
        storage: .userDefaults,
        defaultValue: TranscriptionMethod.local
    )
    
    static let preferredAIProvider = ConfigurationKey(
        name: "preferred_ai_provider",
        storage: .userDefaults,
        defaultValue: LLMProvider.openai
    )
    
    static let autoSummarize = ConfigurationKey(
        name: "auto_summarize",
        storage: .userDefaults,
        defaultValue: false
    )
    
    static let autoExtractKeywords = ConfigurationKey(
        name: "auto_extract_keywords",
        storage: .userDefaults,
        defaultValue: false
    )
    
    // MARK: - その他設定
    static let hapticFeedback = ConfigurationKey(
        name: "haptic_feedback",
        storage: .userDefaults,
        defaultValue: true
    )
    
    static let autoBackup = ConfigurationKey(
        name: "auto_backup",
        storage: .userDefaults,
        defaultValue: true
    )
    
    static let backupFrequency = ConfigurationKey(
        name: "backup_frequency",
        storage: .userDefaults,
        defaultValue: BackupFrequency.daily
    )
    
    // MARK: - セキュアな設定 (Keychain)
    static func apiKey(for provider: LLMProvider) -> ConfigurationKey<String?> {
        return ConfigurationKey(
            name: "api_key_\(provider.rawValue)",
            storage: .keychain(),
            defaultValue: nil
        )
    }
    
    // MARK: - 使用量設定
    static func usageCount(type: String, month: String) -> ConfigurationKey<Int> {
        return ConfigurationKey(
            name: "usage_\(type)_\(month)",
            storage: .userDefaults,
            defaultValue: 0,
            validator: { $0 >= 0 }
        )
    }
    
    static func usageLimit(provider: LLMProvider, period: String) -> ConfigurationKey<Int> {
        return ConfigurationKey(
            name: "usage_limit_\(provider.rawValue)_\(period)",
            storage: .userDefaults,
            defaultValue: -1 // -1 = unlimited
        )
    }
}

// MARK: - 設定エラー (既存のConfigurationErrorを使用)

// ConfigurationError は ServiceError.swift で定義済み