import Foundation
import GRDB

@MainActor
class APIUsageTracker: APIUsageTrackerProtocol {
    
    // MARK: - Properties
    private var database: DatabaseQueue?
    private var retentionDays = 90
    private var isRealTimeTrackingEnabled = true
    
    // Rate limiting tracking
    private var rateLimitCounters: [String: RateLimitCounter] = [:]
    private let rateLimitQueue = DispatchQueue(label: "rate-limit-queue", attributes: .concurrent)
    
    // MARK: - Initialization
    
    init() {
        setupDefaultRateLimits()
    }
    
    // MARK: - Configuration
    
    func configure(database: Any?) async throws {
        guard let dbQueue = database as? DatabaseQueue else {
            throw APIUsageTrackerError.configurationError
        }
        
        self.database = dbQueue
        try await createTables()
    }
    
    func setRetentionPeriod(_ days: Int) async throws {
        retentionDays = days
    }
    
    func enableRealTimeTracking(_ enabled: Bool) async throws {
        isRealTimeTrackingEnabled = enabled
    }
    
    // MARK: - Core Usage Recording
    
    func recordAPICall(provider: LLMProvider, model: String, tokensUsed: Int, cost: Double) async throws {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let record = APIUsageRecord(
            id: UUID(),
            provider: provider,
            model: model,
            tokensUsed: tokensUsed,
            cost: cost,
            timestamp: Date(),
            responseTime: nil,
            success: true,
            errorMessage: nil
        )
        
        try await database.write { db in
            try record.insert(db)
        }
        
        // Rate limit tracking
        await updateRateLimitCounters(for: provider)
        
        // Real-time alerts
        if isRealTimeTrackingEnabled {
            await checkForAlerts(provider: provider, cost: cost)
        }
    }
    
    func recordFailedAPICall(provider: LLMProvider, model: String, error: String) async throws {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let record = APIUsageRecord(
            id: UUID(),
            provider: provider,
            model: model,
            tokensUsed: 0,
            cost: 0.0,
            timestamp: Date(),
            responseTime: nil,
            success: false,
            errorMessage: error
        )
        
        try await database.write { db in
            try record.insert(db)
        }
    }
    
    func recordResponseTime(provider: LLMProvider, responseTime: TimeInterval) async throws {
        // レスポンス時間の統計を更新
        let key = "response_time_\(provider.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        var newTimes = times
        newTimes.append(responseTime)
        
        // 最新100件のみ保持
        if newTimes.count > 100 {
            newTimes = Array(newTimes.suffix(100))
        }
        
        UserDefaults.standard.set(newTimes, forKey: key)
    }
    
    // MARK: - Rate Limiting
    
    func checkRateLimit(for provider: LLMProvider) async throws -> Bool {
        return await rateLimitQueue.sync {
            guard let counter = rateLimitCounters[provider.rawValue] else { return true }
            return counter.canMakeRequest()
        }
    }
    
    func getRateLimitStatus(for provider: LLMProvider) async throws -> RateLimitStatus {
        return await rateLimitQueue.sync {
            guard let counter = rateLimitCounters[provider.rawValue] else {
                return createDefaultRateLimitStatus(for: provider)
            }
            
            return RateLimitStatus(
                provider: provider,
                requestsInCurrentMinute: counter.requestsInCurrentMinute,
                requestsInCurrentHour: counter.requestsInCurrentHour,
                requestsInCurrentDay: counter.requestsInCurrentDay,
                maxRequestsPerMinute: counter.maxRequestsPerMinute,
                maxRequestsPerHour: counter.maxRequestsPerHour,
                maxRequestsPerDay: counter.maxRequestsPerDay,
                canMakeRequest: counter.canMakeRequest(),
                nextAvailableTime: counter.nextAvailableTime()
            )
        }
    }
    
    func updateRateLimits(for provider: LLMProvider, limits: RateLimitStatus) async throws {
        await rateLimitQueue.async(flags: .barrier) {
            var counter = self.rateLimitCounters[provider.rawValue] ?? RateLimitCounter(provider: provider)
            counter.maxRequestsPerMinute = limits.maxRequestsPerMinute
            counter.maxRequestsPerHour = limits.maxRequestsPerHour
            counter.maxRequestsPerDay = limits.maxRequestsPerDay
            self.rateLimitCounters[provider.rawValue] = counter
        }
    }
    
    // MARK: - Usage Queries
    
    func getMonthlyUsage(for month: Date? = nil) async throws -> MonthlyUsage {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let targetMonth = month ?? Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: targetMonth)?.start ?? targetMonth
        let endOfMonth = calendar.dateInterval(of: .month, for: targetMonth)?.end ?? targetMonth
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(Column("timestamp") >= startOfMonth && Column("timestamp") < endOfMonth)
                .filter(Column("success") == true)
                .fetchAll(db)
            
            let totalAPICalls = records.count
            let totalTokens = records.reduce(0) { $0 + $1.tokensUsed }
            let totalCost = records.reduce(0.0) { $0 + $1.cost }
            
            var providerBreakdown: [LLMProvider: DailyUsage] = [:]
            let groupedByProvider = Dictionary(grouping: records) { $0.provider }
            
            for (provider, providerRecords) in groupedByProvider {
                let usage = DailyUsage(
                    date: startOfMonth,
                    provider: provider,
                    apiCalls: providerRecords.count,
                    tokensUsed: providerRecords.reduce(0) { $0 + $1.tokensUsed },
                    totalCost: providerRecords.reduce(0.0) { $0 + $1.cost },
                    averageResponseTime: calculateAverageResponseTime(for: provider)
                )
                providerBreakdown[provider] = usage
            }
            
            return MonthlyUsage(
                month: startOfMonth,
                totalAPICalls: totalAPICalls,
                totalTokens: totalTokens,
                totalCost: totalCost,
                providerBreakdown: providerBreakdown
            )
        }
    }
    
    func getDailyUsage(for date: Date) async throws -> [DailyUsage] {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(Column("timestamp") >= startOfDay && Column("timestamp") < endOfDay)
                .filter(Column("success") == true)
                .fetchAll(db)
            
            let groupedByProvider = Dictionary(grouping: records) { $0.provider }
            
            return groupedByProvider.map { provider, providerRecords in
                DailyUsage(
                    date: startOfDay,
                    provider: provider,
                    apiCalls: providerRecords.count,
                    tokensUsed: providerRecords.reduce(0) { $0 + $1.tokensUsed },
                    totalCost: providerRecords.reduce(0.0) { $0 + $1.cost },
                    averageResponseTime: calculateAverageResponseTime(for: provider)
                )
            }
        }
    }
    
    func getProviderUsage(_ provider: LLMProvider, period: DateInterval?) async throws -> ProviderUsageStats {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let interval = period ?? DateInterval(start: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(), end: Date())
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(Column("provider") == provider.rawValue)
                .filter(Column("timestamp") >= interval.start && Column("timestamp") <= interval.end)
                .fetchAll(db)
            
            let successfulRecords = records.filter { $0.success }
            let totalRecords = records.count
            let successRate = totalRecords > 0 ? Double(successfulRecords.count) / Double(totalRecords) : 0.0
            
            let modelCounts = Dictionary(grouping: successfulRecords) { $0.model }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            return ProviderUsageStats(
                provider: provider,
                apiCalls: successfulRecords.count,
                tokens: successfulRecords.reduce(0) { $0 + $1.tokensUsed },
                cost: successfulRecords.reduce(0.0) { $0 + $1.cost },
                lastUsed: records.max(by: { $0.timestamp < $1.timestamp })?.timestamp,
                averageResponseTime: calculateAverageResponseTime(for: provider),
                successRate: successRate,
                topModels: Array(modelCounts.prefix(5).map { $0.key })
            )
        }
    }
    
    func getUsageHistory(provider: LLMProvider?, limit: Int) async throws -> [APIUsageRecord] {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        return try await database.read { db in
            var query = APIUsageRecord.order(Column("timestamp").desc)
            
            if let provider = provider {
                query = query.filter(Column("provider") == provider.rawValue)
            }
            
            return try query.limit(limit).fetchAll(db)
        }
    }
    
    // MARK: - Analytics & Trends
    
    func getUsageTrend(period: String, days: Int) async throws -> UsageTrend {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(Column("timestamp") >= startDate && Column("timestamp") <= endDate)
                .filter(Column("success") == true)
                .fetchAll(db)
            
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let groupedByDay = Dictionary(grouping: records) { record in
                calendar.startOfDay(for: record.timestamp)
            }
            
            let dataPoints = groupedByDay.map { date, dayRecords in
                UsageDataPoint(
                    date: date,
                    apiCalls: dayRecords.count,
                    tokens: dayRecords.reduce(0) { $0 + $1.tokensUsed },
                    cost: dayRecords.reduce(0.0) { $0 + $1.cost }
                )
            }.sorted { $0.date < $1.date }
            
            return UsageTrend(period: period, data: dataPoints)
        }
    }
    
    func getCostBreakdown(for month: Date?) async throws -> [LLMProvider: Double] {
        let usage = try await getMonthlyUsage(for: month)
        return usage.providerBreakdown.mapValues { $0.totalCost }
    }
    
    func getPredictedCosts() async throws -> CostPrediction {
        let currentMonth = try await getMonthlyUsage()
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: Date())
        
        let dailyAverage = currentMonth.totalCost / Double(dayOfMonth)
        let projectedCurrentMonth = dailyAverage * Double(daysInMonth)
        
        // 簡単な予測（前月の1.1倍）
        let nextMonthEstimated = projectedCurrentMonth * 1.1
        
        return CostPrediction(
            currentMonthProjected: projectedCurrentMonth,
            nextMonthEstimated: nextMonthEstimated,
            recommendedBudget: nextMonthEstimated * 1.2,
            savingsOpportunities: await generateSavingsOpportunities()
        )
    }
    
    func getTopModels(limit: Int) async throws -> [(model: String, usage: Int)] {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(Column("timestamp") >= startOfMonth)
                .filter(Column("success") == true)
                .fetchAll(db)
            
            let modelCounts = Dictionary(grouping: records) { $0.model }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            return Array(modelCounts.prefix(limit))
        }
    }
    
    // MARK: - Limits & Alerts
    
    func setUsageLimit(provider: LLMProvider, limit: Int, period: String) async throws {
        let key = "usage_limit_\(provider.rawValue)_\(period)"
        UserDefaults.standard.set(limit, forKey: key)
    }
    
    func getUsageAlerts() async throws -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        
        let monthlyUsage = try await getMonthlyUsage()
        
        // コスト閾値アラート
        if monthlyUsage.totalCost > 50.0 {
            alerts.append(UsageAlert(
                id: UUID(),
                type: .costThreshold,
                provider: nil,
                threshold: 50.0,
                currentValue: monthlyUsage.totalCost,
                message: "月間コストが$50を超えました",
                createdAt: Date(),
                isActive: true
            ))
        }
        
        // プロバイダー固有のアラート
        for (provider, usage) in monthlyUsage.providerBreakdown {
            if usage.apiCalls > 1000 {
                alerts.append(UsageAlert(
                    id: UUID(),
                    type: .usageThreshold,
                    provider: provider,
                    threshold: 1000,
                    currentValue: Double(usage.apiCalls),
                    message: "\(provider.displayName)のAPI呼び出しが1000回を超えました",
                    createdAt: Date(),
                    isActive: true
                ))
            }
        }
        
        return alerts
    }
    
    func checkUsageLimits() async throws -> [LimitStatus] {
        var statuses: [LimitStatus] = []
        
        for provider in LLMProvider.allCases {
            let usage = try await getProviderUsage(provider)
            let rateLimitStatus = try await getRateLimitStatus(for: provider)
            
            // 日次制限チェック
            let dailyPercentage = Double(rateLimitStatus.requestsInCurrentDay) / Double(rateLimitStatus.maxRequestsPerDay) * 100
            
            statuses.append(LimitStatus(
                provider: provider,
                limitType: "daily_requests",
                currentUsage: rateLimitStatus.requestsInCurrentDay,
                limit: rateLimitStatus.maxRequestsPerDay,
                percentage: dailyPercentage,
                timeUntilReset: calculateTimeUntilDayReset(),
                isExceeded: rateLimitStatus.requestsInCurrentDay >= rateLimitStatus.maxRequestsPerDay
            ))
        }
        
        return statuses
    }
    
    // MARK: - Optimization
    
    func getSavingsSuggestions() async throws -> [SavingSuggestion] {
        var suggestions: [SavingSuggestion] = []
        
        let monthlyUsage = try await getMonthlyUsage()
        
        // 高コストプロバイダーの使用量をチェック
        for (provider, usage) in monthlyUsage.providerBreakdown {
            if usage.totalCost > 20.0 && provider != .openai {
                suggestions.append(SavingSuggestion(
                    id: UUID(),
                    type: .providerSwitch,
                    provider: provider,
                    currentCost: usage.totalCost,
                    potentialSavings: usage.totalCost * 0.3,
                    description: "\(provider.displayName)からより安価なモデルへの切り替えを検討",
                    actionRequired: "モデル設定を確認し、より経済的なオプションを選択",
                    priority: .medium
                ))
            }
        }
        
        return suggestions
    }
    
    func getUnusedProviders(days: Int) async throws -> [LLMProvider] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var unusedProviders: [LLMProvider] = []
        
        for provider in LLMProvider.allCases {
            let usage = try await getProviderUsage(provider, period: DateInterval(start: cutoffDate, end: Date()))
            if usage.apiCalls == 0 {
                unusedProviders.append(provider)
            }
        }
        
        return unusedProviders
    }
    
    func getExpensiveOperations(limit: Int) async throws -> [APIUsageRecord] {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        return try await database.read { db in
            try APIUsageRecord
                .filter(Column("timestamp") >= startOfMonth)
                .filter(Column("success") == true)
                .order(Column("cost").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    // MARK: - Data Management
    
    func exportUsageData(format: ExportFormat, period: DateInterval) async throws -> Data {
        let records = try await getUsageHistory(provider: nil, limit: 10000)
        let filteredRecords = records.filter { period.contains($0.timestamp) }
        
        switch format {
        case .json:
            return try JSONEncoder().encode(filteredRecords)
        case .csv:
            return try generateCSV(from: filteredRecords)
        default:
            throw APIUsageTrackerError.configurationError
        }
    }
    
    func cleanupOldData(olderThan: Date) async throws {
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        try await database.write { db in
            try APIUsageRecord
                .filter(Column("timestamp") < olderThan)
                .deleteAll(db)
        }
    }
    
    func resetMonthlyUsage() async throws {
        // 月次リセットロジック（必要に応じて実装）
        let key = "last_monthly_reset"
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    // MARK: - Private Methods
    
    private func createTables() async throws {
        guard let database = database else { return }
        
        try await database.write { db in
            try db.create(table: "api_usage_records", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("provider", .text).notNull()
                t.column("model", .text).notNull()
                t.column("tokens_used", .integer).notNull()
                t.column("cost", .double).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("response_time", .double)
                t.column("success", .boolean).notNull()
                t.column("error_message", .text)
            }
            
            try db.create(index: "idx_api_usage_timestamp", on: "api_usage_records", columns: ["timestamp"], ifNotExists: true)
            try db.create(index: "idx_api_usage_provider", on: "api_usage_records", columns: ["provider"], ifNotExists: true)
        }
    }
    
    private func setupDefaultRateLimits() {
        for provider in LLMProvider.allCases {
            rateLimitCounters[provider.rawValue] = RateLimitCounter(provider: provider)
        }
    }
    
    private func updateRateLimitCounters(for provider: LLMProvider) async {
        await rateLimitQueue.async(flags: .barrier) {
            var counter = self.rateLimitCounters[provider.rawValue] ?? RateLimitCounter(provider: provider)
            counter.recordRequest()
            self.rateLimitCounters[provider.rawValue] = counter
        }
    }
    
    private func createDefaultRateLimitStatus(for provider: LLMProvider) -> RateLimitStatus {
        let (perMinute, perHour, perDay) = getDefaultRateLimits(for: provider)
        
        return RateLimitStatus(
            provider: provider,
            requestsInCurrentMinute: 0,
            requestsInCurrentHour: 0,
            requestsInCurrentDay: 0,
            maxRequestsPerMinute: perMinute,
            maxRequestsPerHour: perHour,
            maxRequestsPerDay: perDay,
            canMakeRequest: true,
            nextAvailableTime: nil
        )
    }
    
    private func getDefaultRateLimits(for provider: LLMProvider) -> (Int, Int, Int) {
        switch provider {
        case .openai: return (60, 3600, 10000)
        case .anthropic: return (50, 1000, 5000)
        case .gemini: return (60, 1500, 15000)
        }
    }
    
    private func calculateAverageResponseTime(for provider: LLMProvider) -> TimeInterval {
        let key = "response_time_\(provider.rawValue)"
        let times = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        guard !times.isEmpty else { return 0.0 }
        return times.reduce(0.0, +) / Double(times.count)
    }
    
    private func checkForAlerts(provider: LLMProvider, cost: Double) async {
        // リアルタイムアラートロジック
        if cost > 5.0 {
            print("High cost alert: $\(cost) for \(provider.displayName)")
        }
    }
    
    private func generateSavingsOpportunities() async -> [String] {
        return [
            "より安価なモデルの使用を検討",
            "プロンプトの最適化",
            "レスポンスキャッシュの活用",
            "バッチ処理の実装"
        ]
    }
    
    private func calculateTimeUntilDayReset() -> TimeInterval {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        return startOfTomorrow.timeIntervalSinceNow
    }
    
    private func generateCSV(from records: [APIUsageRecord]) throws -> Data {
        var csv = "ID,Provider,Model,TokensUsed,Cost,Timestamp,Success,ErrorMessage\n"
        
        for record in records {
            csv += "\(record.id),\(record.provider.rawValue),\(record.model),\(record.tokensUsed),\(record.cost),\(record.timestamp),\(record.success),\(record.errorMessage ?? "")\n"
        }
        
        return Data(csv.utf8)
    }
}

// MARK: - Supporting Types

private struct RateLimitCounter {
    let provider: LLMProvider
    var maxRequestsPerMinute: Int
    var maxRequestsPerHour: Int
    var maxRequestsPerDay: Int
    
    private var minuteRequests: [Date] = []
    private var hourRequests: [Date] = []
    private var dayRequests: [Date] = []
    
    init(provider: LLMProvider) {
        self.provider = provider
        let (perMinute, perHour, perDay) = getDefaultLimits(for: provider)
        self.maxRequestsPerMinute = perMinute
        self.maxRequestsPerHour = perHour
        self.maxRequestsPerDay = perDay
    }
    
    mutating func recordRequest() {
        let now = Date()
        minuteRequests.append(now)
        hourRequests.append(now)
        dayRequests.append(now)
        
        cleanupOldRequests()
    }
    
    func canMakeRequest() -> Bool {
        return requestsInCurrentMinute < maxRequestsPerMinute &&
               requestsInCurrentHour < maxRequestsPerHour &&
               requestsInCurrentDay < maxRequestsPerDay
    }
    
    var requestsInCurrentMinute: Int {
        let cutoff = Date().addingTimeInterval(-60)
        return minuteRequests.filter { $0 > cutoff }.count
    }
    
    var requestsInCurrentHour: Int {
        let cutoff = Date().addingTimeInterval(-3600)
        return hourRequests.filter { $0 > cutoff }.count
    }
    
    var requestsInCurrentDay: Int {
        let cutoff = Calendar.current.startOfDay(for: Date())
        return dayRequests.filter { $0 > cutoff }.count
    }
    
    func nextAvailableTime() -> Date? {
        if requestsInCurrentMinute >= maxRequestsPerMinute,
           let oldestInMinute = minuteRequests.first {
            return oldestInMinute.addingTimeInterval(60)
        }
        return nil
    }
    
    private mutating func cleanupOldRequests() {
        let now = Date()
        let minuteCutoff = now.addingTimeInterval(-60)
        let hourCutoff = now.addingTimeInterval(-3600)
        let dayCutoff = Calendar.current.startOfDay(for: now)
        
        minuteRequests = minuteRequests.filter { $0 > minuteCutoff }
        hourRequests = hourRequests.filter { $0 > hourCutoff }
        dayRequests = dayRequests.filter { $0 > dayCutoff }
    }
    
    private func getDefaultLimits(for provider: LLMProvider) -> (Int, Int, Int) {
        switch provider {
        case .openai: return (60, 3600, 10000)
        case .anthropic: return (50, 1000, 5000)
        case .gemini: return (60, 1500, 15000)
        }
    }
}

// MARK: - GRDB Extensions

extension APIUsageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "api_usage_records"
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["provider"] = provider.rawValue
        container["model"] = model
        container["tokens_used"] = tokensUsed
        container["cost"] = cost
        container["timestamp"] = timestamp
        container["response_time"] = responseTime
        container["success"] = success
        container["error_message"] = errorMessage
    }
    
    init(row: Row) {
        id = UUID(uuidString: row["id"]) ?? UUID()
        provider = LLMProvider(rawValue: row["provider"]) ?? .openai
        model = row["model"]
        tokensUsed = row["tokens_used"]
        cost = row["cost"]
        timestamp = row["timestamp"]
        responseTime = row["response_time"]
        success = row["success"]
        errorMessage = row["error_message"]
    }
}