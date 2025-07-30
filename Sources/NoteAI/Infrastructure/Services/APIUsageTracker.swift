import Foundation
#if !MINIMAL_BUILD && !NO_COREDATA
import GRDB
#endif

class APIUsageTracker: APIUsageTrackerProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    #if !MINIMAL_BUILD && !NO_COREDATA
    private var database: DatabaseQueue?
    #else
    private var memoryStorage: [String: [APIUsageRecord]] = [:]
    #endif
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
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let dbQueue = database as? DatabaseQueue else {
            throw APIUsageTrackerError.configurationError
        }
        
        self.database = dbQueue
        try await createTables()
        #else
        // MINIMAL_BUILD: メモリ内初期化のみ
        memoryStorage = [:]
        #endif
    }
    
    func setRetentionPeriod(_ days: Int) async throws {
        retentionDays = days
    }
    
    func enableRealTimeTracking(_ enabled: Bool) async throws {
        isRealTimeTrackingEnabled = enabled
    }
    
    // MARK: - Core Usage Recording
    
    func recordAPICall(provider: LLMProvider, model: String, tokensUsed: Int, cost: Double) async throws {
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
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        try await database.write { db in
            try record.insert(db)
        }
        #else
        // MINIMAL_BUILD: メモリに保存
        let key = provider.rawValue
        if memoryStorage[key] == nil {
            memoryStorage[key] = []
        }
        memoryStorage[key]?.append(record)
        #endif
        
        // Rate limit tracking
        await updateRateLimitCounters(for: provider)
        
        // Real-time alerts
        if isRealTimeTrackingEnabled {
            await checkForAlerts(provider: provider, cost: cost)
        }
    }
    
    func recordFailedAPICall(provider: LLMProvider, model: String, error: String) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        #else
        // MINIMAL_BUILD: メモリ内での失敗記録
        let key = provider.rawValue + "_failed"
        if memoryStorage[key] == nil {
            memoryStorage[key] = []
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
        memoryStorage[key]?.append(record)
        return
        #endif
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        try await database.write { db in
            try record.insert(db)
        }
        #endif
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
        return rateLimitQueue.sync {
            guard let counter = rateLimitCounters[provider.rawValue] else { return true }
            return counter.canMakeRequest()
        }
    }
    
    func getRateLimitStatus(for provider: LLMProvider) async throws -> RateLimitStatus {
        return rateLimitQueue.sync {
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
        rateLimitQueue.async(flags: .barrier) {
            var counter = self.rateLimitCounters[provider.rawValue] ?? RateLimitCounter(provider: provider)
            counter.maxRequestsPerMinute = limits.maxRequestsPerMinute
            counter.maxRequestsPerHour = limits.maxRequestsPerHour
            counter.maxRequestsPerDay = limits.maxRequestsPerDay
            self.rateLimitCounters[provider.rawValue] = counter
        }
    }
    
    // MARK: - Usage Queries
    
    func getMonthlyUsage(for month: Date? = nil) async throws -> MonthlyUsage {
        let targetMonth = month ?? Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: targetMonth)?.start ?? targetMonth
        let endOfMonth = calendar.dateInterval(of: .month, for: targetMonth)?.end ?? targetMonth
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        // GRDB版の実装
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(APIUsageRecord.Columns.timestamp >= startOfMonth && APIUsageRecord.Columns.timestamp < endOfMonth)
                .filter(APIUsageRecord.Columns.success == true)
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
                provider: nil,
                totalTokens: totalTokens,
                totalCost: totalCost,
                requestCount: totalAPICalls,
                audioMinutes: 0,
                period: DateInterval(start: startOfMonth, end: endOfMonth),
                month: startOfMonth,
                totalAPICalls: totalAPICalls,
                providerBreakdown: providerBreakdown
            )
        }
        #else
        // MINIMAL_BUILD: メモリから統計を計算
        var allRecords: [APIUsageRecord] = []
        for records in memoryStorage.values {
            allRecords.append(contentsOf: records)
        }
        
        let filteredRecords = allRecords.filter { record in
            record.timestamp >= startOfMonth && record.timestamp < endOfMonth && record.success
        }
        
        let totalAPICalls = filteredRecords.count
        let totalTokens = filteredRecords.reduce(0) { $0 + $1.tokensUsed }
        let totalCost = filteredRecords.reduce(0.0) { $0 + $1.cost }
        
        return MonthlyUsage(
            provider: nil,
            totalTokens: totalTokens,
            totalCost: totalCost,
            requestCount: totalAPICalls,
            audioMinutes: 0,
            period: DateInterval(start: startOfMonth, end: endOfMonth),
            month: startOfMonth,
            totalAPICalls: totalAPICalls,
            providerBreakdown: [:]
        )
        #endif
    }
    
    func getDailyUsage(for date: Date) async throws -> [DailyUsage] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        #else
        // MINIMAL_BUILD: メモリから日次統計を計算
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        var allRecords: [APIUsageRecord] = []
        for records in memoryStorage.values {
            allRecords.append(contentsOf: records)
        }
        
        let filteredRecords = allRecords.filter { record in
            record.timestamp >= startOfDay && record.timestamp < endOfDay && record.success
        }
        
        let groupedByProvider = Dictionary(grouping: filteredRecords) { $0.provider }
        
        return groupedByProvider.map { provider, providerRecords in
            DailyUsage(
                date: startOfDay,
                provider: provider,
                apiCalls: providerRecords.count,
                tokensUsed: providerRecords.reduce(0) { $0 + $1.tokensUsed },
                totalCost: providerRecords.reduce(0.0) { $0 + $1.cost },
                averageResponseTime: 0.0
            )
        }
        #endif
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(APIUsageRecord.Columns.timestamp >= startOfDay && APIUsageRecord.Columns.timestamp < endOfDay)
                .filter(APIUsageRecord.Columns.success == true)
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
        #endif
    }
    
    func getProviderUsage(_ provider: LLMProvider, period: DateInterval? = nil) async throws -> ProviderUsageStats {
        let interval = period ?? DateInterval(start: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(), end: Date())
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        // GRDB版の実装
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(APIUsageRecord.Columns.provider == provider.rawValue)
                .filter(APIUsageRecord.Columns.timestamp >= interval.start && APIUsageRecord.Columns.timestamp <= interval.end)
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
        #else
        // MINIMAL_BUILD: メモリから統計を計算
        var allRecords: [APIUsageRecord] = []
        for records in memoryStorage.values {
            allRecords.append(contentsOf: records.filter { $0.provider == provider })
        }
        
        let filteredRecords = allRecords.filter { record in
            record.timestamp >= interval.start && record.timestamp <= interval.end
        }
        
        let successfulRecords = filteredRecords.filter { $0.success }
        let totalRecords = filteredRecords.count
        let successRate = totalRecords > 0 ? Double(successfulRecords.count) / Double(totalRecords) : 0.0
        
        let modelCounts = Dictionary(grouping: successfulRecords) { $0.model }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return ProviderUsageStats(
            provider: provider,
            apiCalls: successfulRecords.count,
            tokens: successfulRecords.reduce(0) { $0 + $1.tokensUsed },
            cost: successfulRecords.reduce(0.0) { $0 + $1.cost },
            lastUsed: filteredRecords.max(by: { $0.timestamp < $1.timestamp })?.timestamp,
            averageResponseTime: 0.0,
            successRate: successRate,
            topModels: Array(modelCounts.prefix(5).map { $0.key })
        )
        #endif
    }
    
    func getUsageHistory(provider: LLMProvider?, limit: Int) async throws -> [APIUsageRecord] {
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        return try await database.read { db in
            var query = APIUsageRecord.order(APIUsageRecord.Columns.timestamp.desc)
            
            if let provider = provider {
                query = query.filter(APIUsageRecord.Columns.provider == provider.rawValue)
            }
            
            return try query.limit(limit).fetchAll(db)
        }
        #else
        // MINIMAL_BUILD: メモリから取得
        var allRecords: [APIUsageRecord] = []
        for records in memoryStorage.values {
            if let provider = provider {
                allRecords.append(contentsOf: records.filter { $0.provider == provider })
            } else {
                allRecords.append(contentsOf: records)
            }
        }
        
        return Array(allRecords.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
        #endif
    }
    
    // MARK: - Analytics & Trends
    
    func getUsageTrend(period: String, days: Int) async throws -> UsageTrend {
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        #else
        // MINIMAL_BUILD: メモリから統計を計算
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        var allRecords: [APIUsageRecord] = []
        for records in memoryStorage.values {
            allRecords.append(contentsOf: records)
        }
        
        let filteredRecords = allRecords.filter { record in
            record.timestamp >= startDate && record.timestamp <= endDate && record.success
        }
        
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: filteredRecords) { record in
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
        #endif
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(APIUsageRecord.Columns.timestamp >= startDate && APIUsageRecord.Columns.timestamp <= endDate)
                .filter(APIUsageRecord.Columns.success == true)
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
        #endif
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
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        return try await database.read { db in
            let records = try APIUsageRecord
                .filter(APIUsageRecord.Columns.timestamp >= startOfMonth)
                .filter(APIUsageRecord.Columns.success == true)
                .fetchAll(db)
            
            let modelCounts = Dictionary(grouping: records) { $0.model }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            return Array(modelCounts.prefix(limit))
        }
        #else
        // MINIMAL_BUILD: メモリから統計を計算
        var allRecords: [APIUsageRecord] = []
        for records in memoryStorage.values {
            allRecords.append(contentsOf: records)
        }
        
        let filteredRecords = allRecords.filter { record in
            record.timestamp >= startOfMonth && record.success
        }
        
        let modelCounts = Dictionary(grouping: filteredRecords) { $0.model }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(modelCounts.prefix(limit)).map { (model: $0.key, usage: $0.value) }
        #endif
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
            let _ = try await getProviderUsage(provider)
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
            if usage.totalCost > 20.0 && !isOpenAI(provider) {
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
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        return try await database.read { db in
            try APIUsageRecord
                .filter(APIUsageRecord.Columns.timestamp >= startOfMonth)
                .filter(APIUsageRecord.Columns.success == true)
                .order(APIUsageRecord.Columns.cost.desc)
                .limit(limit)
                .fetchAll(db)
        }
        #else
        // MINIMAL_BUILD: メモリから高コスト操作を取得
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        let allRecords = memoryStorage.values.flatMap { $0 }
        return Array(allRecords
            .filter { $0.timestamp >= startOfMonth && $0.success }
            .sorted { $0.cost > $1.cost }
            .prefix(limit))
        #endif
    }
    
    // MARK: - Usage Stats (APIUsageTrackerProtocol requirement)
    
    func getUsageStats() async throws -> LLMUsageStats {
        let monthlyUsage = try await getMonthlyUsage()
        
        var providerBreakdown: [LLMProvider: ProviderUsage] = [:]
        for (provider, usage) in monthlyUsage.providerBreakdown {
            providerBreakdown[provider] = ProviderUsage(
                apiCalls: usage.apiCalls,
                tokens: usage.tokensUsed,
                cost: usage.totalCost,
                lastUsed: nil // TODO: 実際の最終使用日時を取得
            )
        }
        
        return LLMUsageStats(
            totalAPICallsThisMonth: monthlyUsage.totalAPICalls,
            totalTokensThisMonth: monthlyUsage.totalTokens,
            totalCostThisMonth: monthlyUsage.totalCost,
            remainingAPICallsThisMonth: max(0, 10000 - monthlyUsage.totalAPICalls), // デフォルト制限
            providerBreakdown: providerBreakdown
        )
    }
    
    // MARK: - UsageRecordingProtocol methods
    
    func recordBatchUsage(_ records: [UsageRecord]) async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        try await database.write { db in
            for record in records {
                let apiRecord = APIUsageRecord(
                    id: UUID(),
                    provider: record.provider,
                    model: record.model,
                    tokensUsed: record.tokensUsed,
                    cost: record.cost,
                    timestamp: record.timestamp,
                    responseTime: record.responseTime,
                    success: record.success,
                    errorMessage: record.errorMessage
                )
                try apiRecord.save(db)
            }
        }
        #else
        // MINIMAL_BUILD: メモリにバッチレコードを保存
        for record in records {
            let apiRecord = APIUsageRecord(
                id: UUID(),
                provider: record.provider,
                model: record.model,
                tokensUsed: record.tokensUsed,
                cost: record.cost,
                timestamp: record.timestamp,
                responseTime: record.responseTime,
                success: record.success,
                errorMessage: record.errorMessage
            )
            
            let key = record.provider.rawValue
            if memoryStorage[key] == nil {
                memoryStorage[key] = []
            }
            memoryStorage[key]?.append(apiRecord)
        }
        #endif
    }
    
    func getNextAvailableTime(for provider: LLMProvider) async -> Date? {
        return rateLimitQueue.sync {
            guard let counter = rateLimitCounters[provider.rawValue] else { return nil }
            return counter.nextAvailableTime()
        }
    }
    
    // MARK: - UsageLimitsProtocol methods
    
    func updateAlertSettings(_ settings: AlertSettings) async throws {
        // AlertSettingsをUserDefaultsに保存
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: "usage_alert_settings")
        }
    }
    
    // MARK: - UsageOptimizationProtocol methods
    
    func analyzeUsagePatterns() async throws -> UsagePatternAnalysis {
        let monthlyUsage = try await getMonthlyUsage()
        
        // 簡単な分析ロジック
        let mostUsedProviders = monthlyUsage.providerBreakdown.sorted { $0.value.apiCalls > $1.value.apiCalls }.map { $0.key }
        let averageCostPerRequest = monthlyUsage.totalAPICalls > 0 ? monthlyUsage.totalCost / Double(monthlyUsage.totalAPICalls) : 0.0
        
        return UsagePatternAnalysis(
            peakUsageHours: [9, 10, 11, 14, 15, 16], // デフォルト値
            mostUsedProviders: Array(mostUsedProviders.prefix(3)),
            averageCostPerRequest: averageCostPerRequest,
            usageGrowthRate: 0.0, // TODO: 実際の成長率計算
            seasonalPatterns: [:], // TODO: 季節パターン分析
            recommendedOptimizations: await generateSavingsOpportunities()
        )
    }
    
    // MARK: - UsageDataManagementProtocol methods
    
    func optimizeDatabase() async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        try await database.write { db in
            try db.execute(sql: "VACUUM")
            try db.execute(sql: "ANALYZE")
        }
        #else
        // MINIMAL_BUILD: メモリ内ストレージは最適化不要
        #endif
    }
    
    func backupData() async throws -> Data {
        // 使用量データのバックアップ作成
        let records = try await getUsageHistory(provider: nil, limit: Int.max)
        return try JSONEncoder().encode(records)
    }
    
    func restoreData(from data: Data) async throws {
        let records = try JSONDecoder().decode([APIUsageRecord].self, from: data)
        let usageRecords = records.map { record in
            UsageRecord(
                provider: record.provider,
                model: record.model,
                tokensUsed: record.tokensUsed,
                cost: record.cost,
                timestamp: record.timestamp,
                success: record.success,
                responseTime: record.responseTime,
                errorMessage: record.errorMessage
            )
        }
        try await recordBatchUsage(usageRecords)
    }
    
    // MARK: - UsageConfigurationProtocol methods
    
    func getConfiguration() async throws -> UsageConfiguration {
        let decoder = JSONDecoder()
        let alertSettingsData = UserDefaults.standard.data(forKey: "usage_alert_settings") ?? Data()
        let alertSettings = (try? decoder.decode(AlertSettings.self, from: alertSettingsData)) ?? AlertSettings(
            costThreshold: nil,
            usageThreshold: nil,
            dailyLimitWarning: true,
            monthlyLimitWarning: true,
            enableNotifications: true
        )
        
        return UsageConfiguration(
            retentionDays: retentionDays,
            enableRealTimeTracking: isRealTimeTrackingEnabled,
            enableAnalytics: true,
            exportFormats: [.json, .csv],
            alertSettings: alertSettings
        )
    }
    
    func updateConfiguration(_ config: UsageConfiguration) async throws {
        retentionDays = config.retentionDays
        isRealTimeTrackingEnabled = config.enableRealTimeTracking
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(config.alertSettings) {
            UserDefaults.standard.set(data, forKey: "usage_alert_settings")
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
        #if !MINIMAL_BUILD && !NO_COREDATA
        guard let database = database else {
            throw APIUsageTrackerError.configurationError
        }
        
        try await database.write { db in
            try APIUsageRecord
                .filter(APIUsageRecord.Columns.timestamp < olderThan)
                .deleteAll(db)
        }
        #else
        // MINIMAL_BUILD: メモリ内データのクリーンアップ
        for key in memoryStorage.keys {
            memoryStorage[key] = memoryStorage[key]?.filter { $0.timestamp >= olderThan }
        }
        #endif
    }
    
    func resetMonthlyUsage() async throws {
        // 月次リセットロジック（必要に応じて実装）
        let key = "last_monthly_reset"
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    // MARK: - Private Methods
    
    private func createTables() async throws {
        #if !MINIMAL_BUILD && !NO_COREDATA
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
        #else
        // MINIMAL_BUILD: テーブル作成不要
        #endif
    }
    
    private func setupDefaultRateLimits() {
        for provider in LLMProvider.allCases {
            rateLimitCounters[provider.rawValue] = RateLimitCounter(provider: provider)
        }
    }
    
    private func updateRateLimitCounters(for provider: LLMProvider) async {
        rateLimitQueue.async(flags: .barrier) {
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
        case .openAI(_): return (60, 3600, 10000)
        case .anthropic(_): return (50, 1000, 5000)
        case .gemini(_): return (60, 1500, 15000)
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
    
    private func isOpenAI(_ provider: LLMProvider) -> Bool {
        switch provider {
        case .openAI(_):
            return true
        default:
            return false
        }
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
        let (perMinute, perHour, perDay) = RateLimitCounter.getDefaultLimits(for: provider)
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
    
    private static func getDefaultLimits(for provider: LLMProvider) -> (Int, Int, Int) {
        switch provider {
        case .openAI(_): return (60, 3600, 10000)
        case .anthropic(_): return (50, 1000, 5000)
        case .gemini(_): return (60, 1500, 15000)
        }
    }
}

// MARK: - GRDB Extensions

#if !MINIMAL_BUILD && !NO_COREDATA
extension APIUsageRecord: FetchableRecord, PersistableRecord {
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
        provider = LLMProvider(rawValue: row["provider"]) ?? .openAI(.gpt4)
        model = row["model"]
        tokensUsed = row["tokens_used"]
        cost = row["cost"]
        timestamp = row["timestamp"]
        responseTime = row["response_time"]
        success = row["success"]
        errorMessage = row["error_message"]
    }
}
#endif