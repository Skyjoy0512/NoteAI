import Foundation

// MARK: - Date Formatting Service

/// 統一された日付フォーマットサービス
class DateFormattingService {
    static let shared = DateFormattingService()
    
    // MARK: - Formatters
    
    private let shortTimeFormatter: DateFormatter
    private let mediumDateFormatter: DateFormatter
    private let fullDateTimeFormatter: DateFormatter
    private let relativeFormatter: RelativeDateTimeFormatter
    private let iso8601Formatter: ISO8601DateFormatter
    private let customFormatter: DateFormatter
    
    // MARK: - Initialization
    
    private init() {
        // Short time formatter (HH:mm)
        shortTimeFormatter = DateFormatter()
        shortTimeFormatter.timeStyle = .short
        shortTimeFormatter.locale = Locale(identifier: "ja_JP")
        
        // Medium date formatter (yyyy年MM月dd日)
        mediumDateFormatter = DateFormatter()
        mediumDateFormatter.dateStyle = .medium
        mediumDateFormatter.locale = Locale(identifier: "ja_JP")
        
        // Full date-time formatter
        fullDateTimeFormatter = DateFormatter()
        fullDateTimeFormatter.dateStyle = .medium
        fullDateTimeFormatter.timeStyle = .short
        fullDateTimeFormatter.locale = Locale(identifier: "ja_JP")
        
        // Relative formatter (1時間前, 昨日など)
        relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        relativeFormatter.locale = Locale(identifier: "ja_JP")
        
        // ISO8601 formatter for API communication
        iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Custom formatter for specific use cases
        customFormatter = DateFormatter()
        customFormatter.locale = Locale(identifier: "ja_JP")
    }
    
    // MARK: - Public Formatting Methods
    
    /// 作成日時をフォーマット (今日 15:30、昨日 15:30、2024年1月15日)
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
    
    /// 期間をフォーマット (1時間30分, 45秒)
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: duration) ?? "0秒"
    }
    
    /// 日本語の期間フォーマット (1時間30分)
    func formatDurationJapanese(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)時間\(minutes)分"
            } else {
                return "\(hours)時間"
            }
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "\(seconds)秒"
        }
    }
    
    /// 相対日時をフォーマット (1時間前, 3日前)
    func formatRelativeDate(_ date: Date, relativeTo referenceDate: Date = Date()) -> String {
        return relativeFormatter.localizedString(for: date, relativeTo: referenceDate)
    }
    
    /// 完全な日時をフォーマット (2024年1月15日 15:30)
    func formatFullDateTime(_ date: Date) -> String {
        return fullDateTimeFormatter.string(from: date)
    }
    
    /// 日付のみをフォーマット (2024年1月15日)
    func formatDateOnly(_ date: Date) -> String {
        return mediumDateFormatter.string(from: date)
    }
    
    /// 時刻のみをフォーマット (15:30)
    func formatTimeOnly(_ date: Date) -> String {
        return shortTimeFormatter.string(from: date)
    }
    
    /// ISO8601フォーマット (API通信用)
    func formatISO8601(_ date: Date) -> String {
        return iso8601Formatter.string(from: date)
    }
    
    /// ISO8601文字列から日付を解析
    func parseISO8601(_ string: String) -> Date? {
        return iso8601Formatter.date(from: string)
    }
    
    /// カスタムフォーマットで日付をフォーマット
    func formatCustom(_ date: Date, format: String) -> String {
        customFormatter.dateFormat = format
        return customFormatter.string(from: date)
    }
    
    /// カスタムフォーマットで文字列を日付に変換
    func parseCustom(_ string: String, format: String) -> Date? {
        customFormatter.dateFormat = format
        return customFormatter.date(from: string)
    }
    
    // MARK: - Specialized Formatters
    
    /// ファイル名用の日時フォーマット (20240115_153045)
    func formatForFileName(_ date: Date = Date()) -> String {
        return formatCustom(date, format: "yyyyMMdd_HHmmss")
    }
    
    /// ログ用の日時フォーマット (2024-01-15 15:30:45.123)
    func formatForLog(_ date: Date = Date()) -> String {
        return formatCustom(date, format: "yyyy-MM-dd HH:mm:ss.SSS")
    }
    
    /// UI表示用の短縮フォーマット (1/15, 15:30)
    func formatCompact(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return formatTimeOnly(date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return formatCustom(date, format: "M/d")
        } else {
            return formatCustom(date, format: "yyyy/M/d")
        }
    }
    
    /// 週次レポート用の日付範囲フォーマット (1月8日 - 1月14日)
    func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDate(startDate, equalTo: endDate, toGranularity: .year) {
            if calendar.isDate(startDate, equalTo: endDate, toGranularity: .month) {
                // 同じ月内
                let startDay = formatCustom(startDate, format: "d日")
                let endFull = formatCustom(endDate, format: "M月d日")
                return "\(startDay) - \(endFull)"
            } else {
                // 同じ年内の異なる月
                let startMonth = formatCustom(startDate, format: "M月d日")
                let endMonth = formatCustom(endDate, format: "M月d日")
                return "\(startMonth) - \(endMonth)"
            }
        } else {
            // 異なる年
            let startYear = formatCustom(startDate, format: "yyyy年M月d日")
            let endYear = formatCustom(endDate, format: "yyyy年M月d日")
            return "\(startYear) - \(endYear)"
        }
    }
    
    /// 録音セッション用の時間フォーマット (開始: 15:30, 継続時間: 1時間30分)
    func formatRecordingSession(startTime: Date, duration: TimeInterval) -> String {
        let startFormatted = formatTimeOnly(startTime)
        let durationFormatted = formatDurationJapanese(duration)
        return "開始: \(startFormatted), 継続時間: \(durationFormatted)"
    }
    
    /// 年月のみのフォーマット (2024年1月)
    func formatYearMonth(_ date: Date) -> String {
        return formatCustom(date, format: "yyyy年M月")
    }
    
    /// 曜日付きの日付フォーマット (2024年1月15日(月))
    func formatDateWithWeekday(_ date: Date) -> String {
        return formatCustom(date, format: "yyyy年M月d日(E)")
    }
    
    // MARK: - Time Zone Support
    
    /// 特定のタイムゾーンでフォーマット
    func formatInTimeZone(_ date: Date, timeZone: TimeZone, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    /// UTC時刻でフォーマット
    func formatUTC(_ date: Date, format: String = "yyyy-MM-dd'T'HH:mm:ss'Z'") -> String {
        return formatInTimeZone(date, timeZone: TimeZone(abbreviation: "UTC")!, format: format)
    }
    
    // MARK: - Validation and Parsing
    
    /// 日付文字列の妥当性チェック
    func isValidDateString(_ string: String, format: String) -> Bool {
        return parseCustom(string, format: format) != nil
    }
    
    /// 複数フォーマットで解析を試行
    func parseMultipleFormats(_ string: String, formats: [String]) -> Date? {
        for format in formats {
            if let date = parseCustom(string, format: format) {
                return date
            }
        }
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// 現在の日付が指定した日付と同じ日かチェック
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    /// 現在の日付が今週内かチェック
    func isThisWeek(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 現在の日付が今月内かチェック
    func isThisMonth(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    /// 現在の日付が今年内かチェック
    func isThisYear(_ date: Date) -> Bool {
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
    }
}