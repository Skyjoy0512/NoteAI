import Foundation

// MARK: - 型安全なキー定義

struct TypeSafeKey<T> {
    let rawValue: String
    
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - UserDefaults型安全ラッパー

extension UserDefaults {
    
    func get<T>(_ key: TypeSafeKey<T>) -> T? {
        return object(forKey: key.rawValue) as? T
    }
    
    func set<T>(_ value: T, forKey key: TypeSafeKey<T>) {
        set(value, forKey: key.rawValue)
    }
    
    func remove<T>(_ key: TypeSafeKey<T>) {
        removeObject(forKey: key.rawValue)
    }
    
    // Optional型対応
    func get<T>(_ key: TypeSafeKey<T?>) -> T? {
        return object(forKey: key.rawValue) as? T
    }
    
    func set<T>(_ value: T?, forKey key: TypeSafeKey<T?>) {
        if let value = value {
            set(value, forKey: key.rawValue)
        } else {
            removeObject(forKey: key.rawValue)
        }
    }
    
    // RawRepresentable対応（Enum等）
    func get<T: RawRepresentable>(_ key: TypeSafeKey<T>) -> T? where T.RawValue == String {
        guard let rawValue = string(forKey: key.rawValue) else { return nil }
        return T(rawValue: rawValue)
    }
    
    func set<T: RawRepresentable>(_ value: T, forKey key: TypeSafeKey<T>) where T.RawValue == String {
        set(value.rawValue, forKey: key.rawValue)
    }
    
    // Codable対応
    func getCodable<T: Codable>(_ key: TypeSafeKey<T>) -> T? {
        guard let data = data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    func setCodable<T: Codable>(_ value: T, forKey key: TypeSafeKey<T>) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key.rawValue)
    }
}

// MARK: - 型安全なUserDefaultsキー定義

struct UserDefaultsKeys {
    
    // MARK: - 録音設定
    static let recordingQuality = TypeSafeKey<RecordingQuality>("recording_quality")
    static let audioFormat = TypeSafeKey<AudioFormat>("audio_format")
    static let allowBackgroundRecording = TypeSafeKey<Bool>("allow_background_recording")
    static let autoStopRecording = TypeSafeKey<Bool>("auto_stop_recording")
    static let autoStopDuration = TypeSafeKey<Int>("auto_stop_duration")
    
    // MARK: - AI・文字起こし設定
    static let defaultLanguage = TypeSafeKey<SupportedLanguage>("default_language")
    static let transcriptionMethod = TypeSafeKey<TranscriptionMethod>("transcription_method")
    static let preferredAIProvider = TypeSafeKey<LLMProvider>("preferred_ai_provider")
    static let autoSummarize = TypeSafeKey<Bool>("auto_summarize")
    static let autoExtractKeywords = TypeSafeKey<Bool>("auto_extract_keywords")
    
    // MARK: - アプリ設定
    static let appTheme = TypeSafeKey<AppTheme>("app_theme")
    static let appLanguage = TypeSafeKey<AppLanguage>("app_language")
    static let hapticFeedback = TypeSafeKey<Bool>("haptic_feedback")
    static let autoBackup = TypeSafeKey<Bool>("auto_backup")
    static let backupFrequency = TypeSafeKey<BackupFrequency>("backup_frequency")
    
    // MARK: - 使用量関連
    static func usageCount(for type: UsageType, month: String) -> TypeSafeKey<Int> {
        return TypeSafeKey<Int>("usage_\(type.rawValue)_\(month)")
    }
    
    static func usageLimit(for provider: LLMProvider, period: String) -> TypeSafeKey<Int> {
        return TypeSafeKey<Int>("usage_limit_\(provider.rawValue)_\(period)")
    }
    
    static func responseTime(for provider: LLMProvider) -> TypeSafeKey<[Double]> {
        return TypeSafeKey<[Double]>("response_time_\(provider.rawValue)")
    }
    
    // MARK: - メタデータ
    static func keyMetadata(for provider: LLMProvider) -> TypeSafeKey<Data?> {
        return TypeSafeKey<Data?>("metadata_\(provider.rawValue)")
    }
    
    static let lastMonthlyReset = TypeSafeKey<Date?>("last_monthly_reset")
    static let firstLaunchDate = TypeSafeKey<Date?>("first_launch_date")
    static let lastVersionString = TypeSafeKey<String?>("last_version_string")
}

// MARK: - 使用量タイプの型安全定義

enum UsageType: String, CaseIterable {
    case projects = "projects"
    case recording = "recording"
    case api = "api"
    case transcription = "transcription"
    case summary = "summary"
    case keywords = "keywords"
    
    var displayName: String {
        switch self {
        case .projects: return "プロジェクト"
        case .recording: return "録音"
        case .api: return "API"
        case .transcription: return "文字起こし"
        case .summary: return "要約"
        case .keywords: return "キーワード"
        }
    }
}

// MARK: - 時間期間の型安全定義

enum TimePeriod: String, CaseIterable {
    case minute = "minute"
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .minute: return "分"
        case .hour: return "時間"
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
        case .year: return "年"
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000 // 30日
        case .year: return 31536000 // 365日
        }
    }
}

// MARK: - 型安全な識別子

struct TypeSafeID<T>: Hashable, Codable {
    let value: UUID
    
    init() {
        self.value = UUID()
    }
    
    init(_ uuid: UUID) {
        self.value = uuid
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let uuidString = try? container.decode(String.self) {
            guard let uuid = UUID(uuidString: uuidString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid UUID string"
                )
            }
            self.value = uuid
        } else {
            self.value = try container.decode(UUID.self)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.uuidString)
    }
}

// MARK: - ドメイン固有の識別子

typealias ProjectID = TypeSafeID<Project>
typealias RecordingID = TypeSafeID<Recording>
typealias UsageRecordID = TypeSafeID<APIUsageRecord>
typealias AlertID = TypeSafeID<UsageAlert>
typealias SuggestionID = TypeSafeID<SavingSuggestion>

// MARK: - 型安全な設定値

struct TypeSafeConfiguration {
    
    // MARK: - 制約付き数値型
    struct BoundedInt {
        let value: Int
        let min: Int
        let max: Int
        
        init?(_ value: Int, min: Int, max: Int) {
            guard value >= min && value <= max else { return nil }
            self.value = value
            self.min = min
            self.max = max
        }
        
        static func autoStopDuration(_ value: Int) -> BoundedInt? {
            return BoundedInt(value, min: 1, max: 3600)
        }
        
        static func maxTokens(_ value: Int) -> BoundedInt? {
            return BoundedInt(value, min: 1, max: 128000)
        }
        
        static func retentionDays(_ value: Int) -> BoundedInt? {
            return BoundedInt(value, min: 1, max: 365)
        }
    }
    
    struct BoundedDouble {
        let value: Double
        let min: Double
        let max: Double
        
        init?(_ value: Double, min: Double, max: Double) {
            guard value >= min && value <= max else { return nil }
            self.value = value
            self.min = min
            self.max = max
        }
        
        static func temperature(_ value: Double) -> BoundedDouble? {
            return BoundedDouble(value, min: 0.0, max: 2.0)
        }
        
        static func topP(_ value: Double) -> BoundedDouble? {
            return BoundedDouble(value, min: 0.0, max: 1.0)
        }
        
        static func costThreshold(_ value: Double) -> BoundedDouble? {
            return BoundedDouble(value, min: 0.0, max: 10000.0)
        }
    }
    
    // MARK: - バリデーション付き文字列
    struct ValidatedString {
        let value: String
        let validator: (String) -> Bool
        
        init?(_ value: String, validator: @escaping (String) -> Bool) {
            guard validator(value) else { return nil }
            self.value = value
            self.validator = validator
        }
        
        static func apiKey(_ value: String, for provider: LLMProvider) -> ValidatedString? {
            let validator: (String) -> Bool = { key in
                !key.isEmpty && key.hasPrefix(provider.keyPrefix)
            }
            return ValidatedString(value, validator: validator)
        }
        
        static func projectName(_ value: String) -> ValidatedString? {
            let validator: (String) -> Bool = { name in
                !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                name.count <= AppConfiguration.Project.maxNameLength
            }
            return ValidatedString(value, validator: validator)
        }
        
        static func modelName(_ value: String) -> ValidatedString? {
            let validator: (String) -> Bool = { name in
                !name.isEmpty && name.count <= 100
            }
            return ValidatedString(value, validator: validator)
        }
    }
}

// MARK: - 型安全なビルダーパターン

struct LLMRequestBuilder {
    private var model: LLMModel?
    private var messages: [LLMMessage] = []
    private var maxTokens: TypeSafeConfiguration.BoundedInt?
    private var temperature: TypeSafeConfiguration.BoundedDouble?
    private var systemPrompt: String?
    
    func model(_ model: LLMModel) -> LLMRequestBuilder {
        var builder = self
        builder.model = model
        return builder
    }
    
    func message(role: String, content: String) -> LLMRequestBuilder {
        var builder = self
        builder.messages.append(LLMMessage(role: role, content: content))
        return builder
    }
    
    func maxTokens(_ tokens: Int) -> LLMRequestBuilder {
        var builder = self
        builder.maxTokens = TypeSafeConfiguration.BoundedInt.maxTokens(tokens)
        return builder
    }
    
    func temperature(_ temp: Double) -> LLMRequestBuilder {
        var builder = self
        builder.temperature = TypeSafeConfiguration.BoundedDouble.temperature(temp)
        return builder
    }
    
    func systemPrompt(_ prompt: String) -> LLMRequestBuilder {
        var builder = self
        builder.systemPrompt = prompt
        return builder
    }
    
    func build() throws -> LLMRequest {
        guard let model = model else {
            throw LLMServiceError.invalidRequest(message: "Model is required")
        }
        
        guard !messages.isEmpty else {
            throw LLMServiceError.invalidRequest(message: "At least one message is required")
        }
        
        return LLMRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens?.value,
            temperature: temperature?.value,
            systemPrompt: systemPrompt
        )
    }
}

// MARK: - 型安全なファクトリー関数

struct TypeSafeFactories {
    
    static func createUsageRecord(
        provider: LLMProvider,
        model: TypeSafeConfiguration.ValidatedString,
        tokensUsed: TypeSafeConfiguration.BoundedInt,
        cost: TypeSafeConfiguration.BoundedDouble
    ) -> UsageRecord? {
        
        guard let modelName = TypeSafeConfiguration.ValidatedString.modelName(model.value),
              let tokens = TypeSafeConfiguration.BoundedInt.maxTokens(tokensUsed.value),
              let validCost = TypeSafeConfiguration.BoundedDouble.costThreshold(cost.value) else {
            return nil
        }
        
        return UsageRecord(
            provider: provider,
            model: modelName.value,
            tokensUsed: tokens.value,
            cost: validCost.value,
            timestamp: Date(),
            success: true,
            responseTime: nil,
            errorMessage: nil
        )
    }
    
    static func createProject(
        name: String,
        description: String?
    ) -> Project? {
        
        guard let validName = TypeSafeConfiguration.ValidatedString.projectName(name) else {
            return nil
        }
        
        let validDescription: String?
        if let desc = description {
            validDescription = TypeSafeConfiguration.ValidatedString.projectName(desc)?.value
        } else {
            validDescription = nil
        }
        
        return Project(
            id: ProjectID().value,
            name: validName.value,
            description: validDescription,
            coverImageData: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: nil
        )
    }
}

// MARK: - 型安全なエラーハンドリング

enum TypeSafetyError: Error, LocalizedError {
    case validationFailed(field: String, value: Any)
    case requiredFieldMissing(field: String)
    case typeMismatch(expected: String, actual: String)
    case rangeError(field: String, min: Any, max: Any, actual: Any)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let field, let value):
            return "Validation failed for field '\(field)' with value '\(value)'"
        case .requiredFieldMissing(let field):
            return "Required field '\(field)' is missing"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected '\(expected)', got '\(actual)'"
        case .rangeError(let field, let min, let max, let actual):
            return "Value '\(actual)' for field '\(field)' is out of range [\(min), \(max)]"
        }
    }
}

// MARK: - 月フォーマットの型安全化

struct MonthIdentifier: Hashable, Codable {
    let year: Int
    let month: Int
    
    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
    
    init(date: Date = Date()) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        self.year = components.year ?? 2024
        self.month = components.month ?? 1
    }
    
    var stringValue: String {
        return String(format: "%04d-%02d", year, month)
    }
    
    var date: Date {
        let calendar = Calendar.current
        return calendar.date(from: DateComponents(year: year, month: month)) ?? Date()
    }
    
    func previous() -> MonthIdentifier {
        if month == 1 {
            return MonthIdentifier(year: year - 1, month: 12)
        } else {
            return MonthIdentifier(year: year, month: month - 1)
        }
    }
    
    func next() -> MonthIdentifier {
        if month == 12 {
            return MonthIdentifier(year: year + 1, month: 1)
        } else {
            return MonthIdentifier(year: year, month: month + 1)
        }
    }
}

// MARK: - 使用量キーの型安全化

extension UserDefaultsKeys {
    static func typeSafeUsageCount(for type: UsageType, month: MonthIdentifier) -> TypeSafeKey<Int> {
        return TypeSafeKey<Int>("usage_\(type.rawValue)_\(month.stringValue)")
    }
    
    static func typeSafeUsageLimit(for provider: LLMProvider, period: TimePeriod) -> TypeSafeKey<Int> {
        return TypeSafeKey<Int>("usage_limit_\(provider.rawValue)_\(period.rawValue)")
    }
}