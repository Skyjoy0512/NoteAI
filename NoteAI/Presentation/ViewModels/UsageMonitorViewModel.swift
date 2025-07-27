import SwiftUI
import Foundation
import Combine

struct ChartDataPoint {
    let date: Date
    let value: Double
}

@MainActor
class UsageMonitorViewModel: ViewModelCapable {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Summary Data
    @Published var totalAPICalls = 0
    @Published var totalTokens = 0
    @Published var totalCost = 0.0
    @Published var averageResponseTime = 0.0
    
    // Trends (percentage change from previous period)
    @Published var apiCallsTrend: Double? = nil
    @Published var tokensTrend: Double? = nil
    @Published var costTrend: Double? = nil
    @Published var responseTimeTrend: Double? = nil
    
    // Chart Data
    @Published var selectedMetric: UsageMetric = .apiCalls
    @Published var chartData: [ChartDataPoint] = []
    
    // Cost Breakdown
    @Published var costBreakdown: [LLMProvider: Double] = [:]
    @Published var providerStats: [ProviderUsageStats] = []
    
    // Alerts & Limits
    @Published var activeAlerts: [UsageAlert] = []
    @Published var limitStatuses: [LimitStatus] = []
    
    // Optimization
    @Published var savingsSuggestions: [SavingSuggestion] = []
    
    // MARK: - Dependencies
    private let usageTracker: APIUsageTrackerProtocol
    
    // MARK: - State
    private var currentPeriod: UsagePeriod = .thisMonth
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(usageTracker: APIUsageTrackerProtocol) {
        self.usageTracker = usageTracker
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() async {
        await withLoadingNoReturn {
            await loadSummaryData()
            await loadChartData()
            await loadCostBreakdown()
            await loadProviderStats()
            await loadAlertsAndLimits()
            await loadOptimizationSuggestions()
        }
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func changePeriod(_ period: UsagePeriod) async {
        currentPeriod = period
        await loadInitialData()
    }
    
    func resetUsage() async {
        do {
            try await usageTracker.resetMonthlyUsage()
            await refreshData()
        } catch {
            await handleError(error)
        }
    }
    
    func showSettings() {
        // SettingsViewへの遷移（親ViewControllerで処理）
    }
    
    func getAPICallsForProvider(_ provider: LLMProvider) -> Int {
        guard let stats = providerStats.first(where: { $0.provider == provider }) else {
            return 0
        }
        return stats.apiCalls
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // メトリック変更時にチャートデータを更新
        $selectedMetric
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadChartData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSummaryData() async {
        do {
            let dateInterval = getDateInterval(for: currentPeriod)
            let previousInterval = getPreviousDateInterval(for: currentPeriod)
            
            // 現在の期間の統計
            let monthlyUsage = try await usageTracker.getMonthlyUsage(for: dateInterval.start)
            totalAPICalls = monthlyUsage.totalAPICalls
            totalTokens = monthlyUsage.totalTokens
            totalCost = monthlyUsage.totalCost
            
            // 平均応答時間の計算
            averageResponseTime = calculateAverageResponseTime(from: monthlyUsage.providerBreakdown)
            
            // 前期間との比較でトレンドを計算
            let previousUsage = try await usageTracker.getMonthlyUsage(for: previousInterval.start)
            
            apiCallsTrend = calculateTrend(current: totalAPICalls, previous: previousUsage.totalAPICalls)
            tokensTrend = calculateTrend(current: totalTokens, previous: previousUsage.totalTokens)
            costTrend = calculateTrend(current: totalCost, previous: previousUsage.totalCost)
            
            let previousAvgResponseTime = calculateAverageResponseTime(from: previousUsage.providerBreakdown)
            responseTimeTrend = calculateTrend(current: averageResponseTime, previous: previousAvgResponseTime)
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadChartData() async {
        do {
            let dateInterval = getDateInterval(for: currentPeriod)
            let days = Int(dateInterval.duration / 86400) // seconds to days
            
            let trend = try await usageTracker.getUsageTrend(
                period: currentPeriod.rawValue,
                days: min(days, 30)
            )
            
            chartData = trend.data.map { dataPoint in
                let value: Double
                switch selectedMetric {
                case .apiCalls:
                    value = Double(dataPoint.apiCalls)
                case .tokens:
                    value = Double(dataPoint.tokens)
                case .cost:
                    value = dataPoint.cost
                }
                
                return ChartDataPoint(date: dataPoint.date, value: value)
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadCostBreakdown() async {
        do {
            let dateInterval = getDateInterval(for: currentPeriod)
            costBreakdown = try await usageTracker.getCostBreakdown(for: dateInterval.start)
        } catch {
            await handleError(error)
        }
    }
    
    private func loadProviderStats() async {
        do {
            let dateInterval = getDateInterval(for: currentPeriod)
            var stats: [ProviderUsageStats] = []
            
            for provider in LLMProvider.allCases {
                let providerStats = try await usageTracker.getProviderUsage(provider, period: dateInterval)
                if providerStats.apiCalls > 0 {
                    stats.append(providerStats)
                }
            }
            
            providerStats = stats.sorted { $0.cost > $1.cost }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadAlertsAndLimits() async {
        do {
            activeAlerts = try await usageTracker.getUsageAlerts()
            limitStatuses = try await usageTracker.checkUsageLimits()
        } catch {
            await handleError(error)
        }
    }
    
    private func loadOptimizationSuggestions() async {
        do {
            savingsSuggestions = try await usageTracker.getSavingsSuggestions()
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDateInterval(for period: UsagePeriod) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return DateInterval(start: startOfDay, end: endOfDay)
            
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
            return DateInterval(start: startOfWeek, end: endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
            return DateInterval(start: startOfMonth, end: endOfMonth)
            
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? lastMonth
            let endOfLastMonth = calendar.date(byAdding: .month, value: 1, to: startOfLastMonth) ?? lastMonth
            return DateInterval(start: startOfLastMonth, end: endOfLastMonth)
            
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            let startOf3MonthsAgo = calendar.dateInterval(of: .month, for: threeMonthsAgo)?.start ?? threeMonthsAgo
            return DateInterval(start: startOf3MonthsAgo, end: now)
        }
    }
    
    private func getPreviousDateInterval(for period: UsagePeriod) -> DateInterval {
        let calendar = Calendar.current
        let currentInterval = getDateInterval(for: period)
        let duration = currentInterval.duration
        
        let previousStart = currentInterval.start.addingTimeInterval(-duration)
        let previousEnd = currentInterval.start
        
        return DateInterval(start: previousStart, end: previousEnd)
    }
    
    private func calculateTrend(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
    
    private func calculateTrend(current: Int, previous: Int) -> Double? {
        guard previous > 0 else { return nil }
        return ((Double(current) - Double(previous)) / Double(previous)) * 100
    }
    
    private func calculateAverageResponseTime(from breakdown: [LLMProvider: DailyUsage]) -> Double {
        guard !breakdown.isEmpty else { return 0.0 }
        
        let totalResponseTime = breakdown.values.reduce(0.0) { total, usage in
            total + usage.averageResponseTime
        }
        
        return totalResponseTime / Double(breakdown.count)
    }
    
    // handleError はプロトコルで実装済み
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    let viewModel: UsageMonitorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .csv
    @State private var selectedPeriod: UsagePeriod = .thisMonth
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("エクスポート形式") {
                    Picker("形式", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("期間") {
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(UsagePeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Button("エクスポート") {
                        Task {
                            await exportData()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("データエクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportData() async {
        isExporting = true
        
        // エクスポート処理の実装
        // 実際の実装では、usageTracker.exportUsageData を呼び出して
        // ファイルをシェアまたは保存する
        
        await MainActor.run {
            isExporting = false
            dismiss()
        }
    }
}

extension ExportFormat {
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .pdf: return "PDF"
        case .xlsx: return "Excel"
        }
    }
}