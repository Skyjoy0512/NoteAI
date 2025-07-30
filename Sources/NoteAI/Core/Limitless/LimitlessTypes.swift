import Foundation

// MARK: - Limitless連携関連の型定義

// MARK: - 表示モード
enum DisplayMode: String, CaseIterable {
    case audioFiles = "audio_files"       // ファイル形式表示
    case lifelog = "lifelog"              // ライフログ形式表示
    
    var displayName: String {
        switch self {
        case .audioFiles:
            return "音声ファイル"
        case .lifelog:
            return "ライフログ"
        }
    }
    
    var icon: String {
        switch self {
        case .audioFiles:
            return "waveform"
        case .lifelog:
            return "calendar"
        }
    }
}

// MARK: - 音声ファイル情報
struct AudioFileInfo: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let filePath: URL
    let duration: TimeInterval
    let fileSize: Int64
    let createdAt: Date
    let modifiedAt: Date
    let sampleRate: Double
    let channels: Int
    let bitRate: Int?
    let format: AudioFormat
    let transcriptionStatus: TranscriptionStatus
    let metadata: AudioMetadata
    
    // iCloud関連プロパティ
    let iCloudURL: URL?
    let cloudRecordID: String? // CKRecord.IDをStringで保存
    let isImportant: Bool
    let isSyncedToiCloud: Bool
    let cloudSyncDate: Date?
    
    init(
        id: UUID = UUID(),
        fileName: String,
        filePath: URL,
        duration: TimeInterval,
        fileSize: Int64,
        createdAt: Date,
        modifiedAt: Date = Date(),
        sampleRate: Double,
        channels: Int,
        bitRate: Int? = nil,
        format: AudioFormat,
        transcriptionStatus: TranscriptionStatus = .pending,
        metadata: AudioMetadata = AudioMetadata(),
        iCloudURL: URL? = nil,
        cloudRecordID: String? = nil,
        isImportant: Bool = false,
        isSyncedToiCloud: Bool = false,
        cloudSyncDate: Date? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.duration = duration
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitRate = bitRate
        self.format = format
        self.transcriptionStatus = transcriptionStatus
        self.metadata = metadata
        self.iCloudURL = iCloudURL
        self.cloudRecordID = cloudRecordID
        self.isImportant = isImportant
        self.isSyncedToiCloud = isSyncedToiCloud
        self.cloudSyncDate = cloudSyncDate
    }
}

// MARK: - 音声フォーマット
enum AudioFormat: String, CaseIterable, Codable {
    case wav = "wav"
    case mp3 = "mp3"
    case m4a = "m4a"
    case aac = "aac"
    case flac = "flac"
    
    var displayName: String {
        switch self {
        case .m4a: return "M4A (標準)"
        case .wav: return "WAV (高音質)"
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .flac: return "FLAC (ロスレス)"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
    
    var mimeType: String {
        switch self {
        case .wav: return "audio/wav"
        case .mp3: return "audio/mpeg"
        case .m4a: return "audio/m4a"
        case .aac: return "audio/aac"
        case .flac: return "audio/flac"
        }
    }
}

// MARK: - 文字起こし状態
enum TranscriptionStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
    
    var displayName: String {
        switch self {
        case .pending:
            return "待機中"
        case .processing:
            return "処理中"
        case .completed:
            return "完了"
        case .failed:
            return "失敗"
        case .skipped:
            return "スキップ"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .processing:
            return "blue"
        case .completed:
            return "green"
        case .failed:
            return "red"
        case .skipped:
            return "gray"
        }
    }
}

// MARK: - 音声メタデータ
struct AudioMetadata: Codable {
    let deviceInfo: DeviceInfo?
    let location: LocationInfo?
    let environment: EnvironmentInfo?
    let tags: [String]
    let notes: String?
    
    init(
        deviceInfo: DeviceInfo? = nil,
        location: LocationInfo? = nil,
        environment: EnvironmentInfo? = nil,
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.deviceInfo = deviceInfo
        self.location = location
        self.environment = environment
        self.tags = tags
        self.notes = notes
    }
}

// MARK: - デバイス情報
struct DeviceInfo: Codable {
    let deviceId: String
    let deviceName: String
    let firmwareVersion: String?
    let batteryLevel: Double?
    let signalStrength: Double?
    
    init(
        deviceId: String,
        deviceName: String,
        firmwareVersion: String? = nil,
        batteryLevel: Double? = nil,
        signalStrength: Double? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.firmwareVersion = firmwareVersion
        self.batteryLevel = batteryLevel
        self.signalStrength = signalStrength
    }
}

// MARK: - 位置情報
struct LocationInfo: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let accuracy: Double
    let timestamp: Date
    let placeName: String?
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        accuracy: Double,
        timestamp: Date,
        placeName: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.placeName = placeName
    }
}

// MARK: - 環境情報
struct EnvironmentInfo: Codable {
    let noiseLevel: Double?
    let temperature: Double?
    let humidity: Double?
    let lightLevel: Double?
    let activityType: ActivityType?
    
    init(
        noiseLevel: Double? = nil,
        temperature: Double? = nil,
        humidity: Double? = nil,
        lightLevel: Double? = nil,
        activityType: ActivityType? = nil
    ) {
        self.noiseLevel = noiseLevel
        self.temperature = temperature
        self.humidity = humidity
        self.lightLevel = lightLevel
        self.activityType = activityType
    }
}

// MARK: - 活動タイプ
enum ActivityType: String, CaseIterable, Codable {
    case meeting = "meeting"
    case conversation = "conversation"
    case lecture = "lecture"
    case personal = "personal"
    case travel = "travel"
    case exercise = "exercise"
    case work = "work"
    case leisure = "leisure"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .meeting:
            return "会議"
        case .conversation:
            return "会話"
        case .lecture:
            return "講義"
        case .personal:
            return "個人"
        case .travel:
            return "移動"
        case .exercise:
            return "運動"
        case .work:
            return "仕事"
        case .leisure:
            return "娯楽"
        case .unknown:
            return "不明"
        }
    }
    
    var icon: String {
        switch self {
        case .meeting:
            return "person.3"
        case .conversation:
            return "message"
        case .lecture:
            return "book"
        case .personal:
            return "person"
        case .travel:
            return "car"
        case .exercise:
            return "figure.run"
        case .work:
            return "briefcase"
        case .leisure:
            return "gamecontroller"
        case .unknown:
            return "questionmark"
        }
    }
}

// MARK: - ライフログエントリ
struct LifelogEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let audioFiles: [AudioFileInfo]
    let totalDuration: TimeInterval
    let transcriptSummary: String?
    let activities: [ActivitySummary]
    let locations: [LocationSummary]
    let keyMoments: [KeyMoment]
    let insights: [String]
    let mood: MoodInfo?
    
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    init(
        id: UUID = UUID(),
        date: Date,
        audioFiles: [AudioFileInfo] = [],
        totalDuration: TimeInterval = 0,
        transcriptSummary: String? = nil,
        activities: [ActivitySummary] = [],
        locations: [LocationSummary] = [],
        keyMoments: [KeyMoment] = [],
        insights: [String] = [],
        mood: MoodInfo? = nil
    ) {
        self.id = id
        self.date = date
        self.audioFiles = audioFiles
        self.totalDuration = totalDuration
        self.transcriptSummary = transcriptSummary
        self.activities = activities
        self.locations = locations
        self.keyMoments = keyMoments
        self.insights = insights
        self.mood = mood
    }
}

// MARK: - 活動サマリー
struct ActivitySummary: Identifiable, Codable {
    let id: UUID
    let activityType: ActivityType
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let description: String?
    let confidence: Double
    
    init(
        id: UUID = UUID(),
        activityType: ActivityType,
        duration: TimeInterval,
        startTime: Date,
        endTime: Date,
        description: String? = nil,
        confidence: Double
    ) {
        self.id = id
        self.activityType = activityType
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.description = description
        self.confidence = confidence
    }
}

// MARK: - 位置サマリー
struct LocationSummary: Identifiable, Codable {
    let id: UUID
    let placeName: String
    let duration: TimeInterval
    let arrivalTime: Date
    let departureTime: Date?
    let latitude: Double
    let longitude: Double
    let category: LocationCategory
    
    init(
        id: UUID = UUID(),
        placeName: String,
        duration: TimeInterval,
        arrivalTime: Date,
        departureTime: Date? = nil,
        latitude: Double,
        longitude: Double,
        category: LocationCategory
    ) {
        self.id = id
        self.placeName = placeName
        self.duration = duration
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
    }
}

// MARK: - 位置カテゴリ
enum LocationCategory: String, CaseIterable, Codable {
    case home = "home"
    case office = "office"
    case restaurant = "restaurant"
    case shop = "shop"
    case transport = "transport"
    case outdoor = "outdoor"
    case entertainment = "entertainment"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .home:
            return "自宅"
        case .office:
            return "オフィス"
        case .restaurant:
            return "レストラン"
        case .shop:
            return "ショップ"
        case .transport:
            return "交通機関"
        case .outdoor:
            return "屋外"
        case .entertainment:
            return "娯楽施設"
        case .unknown:
            return "不明"
        }
    }
    
    var icon: String {
        switch self {
        case .home:
            return "house"
        case .office:
            return "building.2"
        case .restaurant:
            return "fork.knife"
        case .shop:
            return "bag"
        case .transport:
            return "tram"
        case .outdoor:
            return "tree"
        case .entertainment:
            return "theatermasks"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - キーモーメント
struct KeyMoment: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let title: String
    let description: String
    let category: KeyMomentCategory
    let importance: ImportanceLevel
    let relatedAudioFile: UUID?
    let audioTimestamp: TimeInterval?
    
    init(
        id: UUID = UUID(),
        timestamp: Date,
        title: String,
        description: String,
        category: KeyMomentCategory,
        importance: ImportanceLevel,
        relatedAudioFile: UUID? = nil,
        audioTimestamp: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.description = description
        self.category = category
        self.importance = importance
        self.relatedAudioFile = relatedAudioFile
        self.audioTimestamp = audioTimestamp
    }
}

// MARK: - キーモーメントカテゴリ
enum KeyMomentCategory: String, CaseIterable, Codable {
    case decision = "decision"
    case insight = "insight"
    case meeting = "meeting"
    case idea = "idea"
    case problem = "problem"
    case achievement = "achievement"
    case emotion = "emotion"
    case learning = "learning"
    
    var displayName: String {
        switch self {
        case .decision:
            return "決定"
        case .insight:
            return "洞察"
        case .meeting:
            return "会議"
        case .idea:
            return "アイデア"
        case .problem:
            return "問題"
        case .achievement:
            return "達成"
        case .emotion:
            return "感情"
        case .learning:
            return "学習"
        }
    }
    
    var icon: String {
        switch self {
        case .decision:
            return "checkmark.circle"
        case .insight:
            return "lightbulb"
        case .meeting:
            return "person.3"
        case .idea:
            return "brain.head.profile"
        case .problem:
            return "exclamationmark.triangle"
        case .achievement:
            return "star.circle"
        case .emotion:
            return "heart"
        case .learning:
            return "book.circle"
        }
    }
}

// MARK: - 重要度レベル
enum ImportanceLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        case .critical:
            return "重要"
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "gray"
        case .medium:
            return "blue"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

// MARK: - ムード情報
struct MoodInfo: Codable {
    let overall: MoodLevel
    let energy: EnergyLevel
    let stress: StressLevel
    let confidence: Double
    let notes: String?
    
    init(
        overall: MoodLevel,
        energy: EnergyLevel,
        stress: StressLevel,
        confidence: Double,
        notes: String? = nil
    ) {
        self.overall = overall
        self.energy = energy
        self.stress = stress
        self.confidence = confidence
        self.notes = notes
    }
}

// MARK: - ムードレベル
enum MoodLevel: String, CaseIterable, Codable {
    case veryPositive = "very_positive"
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case veryNegative = "very_negative"
    
    var displayName: String {
        switch self {
        case .veryPositive:
            return "とても良い"
        case .positive:
            return "良い"
        case .neutral:
            return "普通"
        case .negative:
            return "悪い"
        case .veryNegative:
            return "とても悪い"
        }
    }
    
    var emoji: String {
        switch self {
        case .veryPositive:
            return "😄"
        case .positive:
            return "😊"
        case .neutral:
            return "😐"
        case .negative:
            return "😟"
        case .veryNegative:
            return "😢"
        }
    }
}

// MARK: - エネルギーレベル
enum EnergyLevel: String, CaseIterable, Codable {
    case veryHigh = "very_high"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case veryLow = "very_low"
    
    var displayName: String {
        switch self {
        case .veryHigh:
            return "とても高い"
        case .high:
            return "高い"
        case .medium:
            return "普通"
        case .low:
            return "低い"
        case .veryLow:
            return "とても低い"
        }
    }
    
    var color: String {
        switch self {
        case .veryHigh:
            return "green"
        case .high:
            return "mint"
        case .medium:
            return "yellow"
        case .low:
            return "orange"
        case .veryLow:
            return "red"
        }
    }
}

// MARK: - ストレスレベル
enum StressLevel: String, CaseIterable, Codable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow:
            return "とても低い"
        case .low:
            return "低い"
        case .medium:
            return "普通"
        case .high:
            return "高い"
        case .veryHigh:
            return "とても高い"
        }
    }
    
    var color: String {
        switch self {
        case .veryLow:
            return "green"
        case .low:
            return "mint"
        case .medium:
            return "yellow"
        case .high:
            return "orange"
        case .veryHigh:
            return "red"
        }
    }
}

// MARK: - フィルター設定
struct DisplayFilter: Codable {
    var dateRange: DateRange?
    var activityTypes: Set<ActivityType>
    var transcriptionStatus: Set<TranscriptionStatus>
    var minDuration: TimeInterval?
    var maxDuration: TimeInterval?
    var locations: Set<String>
    var tags: Set<String>
    var importanceLevel: ImportanceLevel?
    
    init(
        dateRange: DateRange? = nil,
        activityTypes: Set<ActivityType> = Set(ActivityType.allCases),
        transcriptionStatus: Set<TranscriptionStatus> = Set(TranscriptionStatus.allCases),
        minDuration: TimeInterval? = nil,
        maxDuration: TimeInterval? = nil,
        locations: Set<String> = [],
        tags: Set<String> = [],
        importanceLevel: ImportanceLevel? = nil
    ) {
        self.dateRange = dateRange
        self.activityTypes = activityTypes
        self.transcriptionStatus = transcriptionStatus
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.locations = locations
        self.tags = tags
        self.importanceLevel = importanceLevel
    }
}

// MARK: - 日付範囲
struct DateRange: Codable {
    let startDate: Date
    let endDate: Date
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - 音声ファイルフィルター
struct AudioFileFilter: Codable {
    var transcriptionStatuses: Set<TranscriptionStatus>
    var audioFormats: Set<AudioFormat>
    var minDuration: TimeInterval
    var maxDuration: TimeInterval
    var activityTypes: Set<ActivityType>
    var searchText: String
    var showOnlyFavorites: Bool
    
    init(
        transcriptionStatuses: Set<TranscriptionStatus> = Set(TranscriptionStatus.allCases),
        audioFormats: Set<AudioFormat> = Set(AudioFormat.allCases),
        minDuration: TimeInterval = 0,
        maxDuration: TimeInterval = 7200, // 2時間
        activityTypes: Set<ActivityType> = Set(ActivityType.allCases),
        searchText: String = "",
        showOnlyFavorites: Bool = false
    ) {
        self.transcriptionStatuses = transcriptionStatuses
        self.audioFormats = audioFormats
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.activityTypes = activityTypes
        self.searchText = searchText
        self.showOnlyFavorites = showOnlyFavorites
    }
    
    /// フィルターが適用されているかどうかを判定
    var isActive: Bool {
        return transcriptionStatuses.count != TranscriptionStatus.allCases.count ||
               audioFormats.count != AudioFormat.allCases.count ||
               minDuration > 0 ||
               maxDuration < 7200 ||
               activityTypes.count != ActivityType.allCases.count ||
               !searchText.isEmpty ||
               showOnlyFavorites
    }
    
    /// フィルターをリセット
    mutating func reset() {
        self = AudioFileFilter()
    }
}