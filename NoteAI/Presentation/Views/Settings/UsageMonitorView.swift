import SwiftUI
import Charts

struct UsageMonitorView: View {
    @StateObject private var viewModel: UsageMonitorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: UsagePeriod = .thisMonth
    @State private var selectedProvider: LLMProvider? = nil
    @State private var showingExportOptions = false
    
    init(viewModel: UsageMonitorViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 期間選択
                    periodSelector
                    
                    // サマリーカード
                    summaryCards
                    
                    // 使用量チャート
                    usageChart
                    
                    // コスト内訳
                    costBreakdown
                    
                    // プロバイダー別統計
                    providerStats
                    
                    // アラート・制限
                    alertsSection
                    
                    // 最適化提案
                    optimizationSuggestions
                }
                .padding()
            }
            .navigationTitle("使用量・コスト管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("データをエクスポート") {
                            showingExportOptions = true
                        }
                        
                        Button("使用量をリセット") {
                            Task {
                                await viewModel.resetUsage()
                            }
                        }
                        
                        Button("設定") {
                            viewModel.showSettings()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("期間")
                    .font(.headline)
                Spacer()
            }
            
            Picker("期間", selection: $selectedPeriod) {
                ForEach(UsagePeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedPeriod) { newPeriod in
                Task {
                    await viewModel.changePeriod(newPeriod)
                }
            }
        }
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            SummaryCard(
                title: "API呼び出し",
                value: "\(viewModel.totalAPICalls)",
                subtitle: "回",
                color: .blue,
                trend: viewModel.apiCallsTrend
            )
            
            SummaryCard(
                title: "トークン使用量",
                value: formatNumber(viewModel.totalTokens),
                subtitle: "tokens",
                color: .green,
                trend: viewModel.tokensTrend
            )
            
            SummaryCard(
                title: "総コスト",
                value: String(format: "$%.2f", viewModel.totalCost),
                subtitle: "",
                color: .orange,
                trend: viewModel.costTrend
            )
            
            SummaryCard(
                title: "平均応答時間",
                value: String(format: "%.1fs", viewModel.averageResponseTime),
                subtitle: "",
                color: .purple,
                trend: viewModel.responseTimeTrend
            )
        }
    }
    
    // MARK: - Usage Chart
    
    private var usageChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("使用量推移")
                    .font(.headline)
                Spacer()
                
                Picker("メトリック", selection: $viewModel.selectedMetric) {
                    Text("API呼び出し").tag(UsageMetric.apiCalls)
                    Text("トークン").tag(UsageMetric.tokens)
                    Text("コスト").tag(UsageMetric.cost)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            if viewModel.chartData.isEmpty {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("データがありません")
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Cost Breakdown
    
    private var costBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プロバイダー別コスト")
                .font(.headline)
            
            if viewModel.costBreakdown.isEmpty {
                Text("データがありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.costBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { provider, cost in
                    HStack {
                        Circle()
                            .fill(colorForProvider(provider))
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(viewModel.getAPICallsForProvider(provider))回の呼び出し")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "$%.2f", cost))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(String(format: "%.1f%%", (cost / viewModel.totalCost) * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Provider Stats
    
    private var providerStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プロバイダー統計")
                .font(.headline)
            
            if viewModel.providerStats.isEmpty {
                Text("データがありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.providerStats, id: \.provider) { stats in
                    ProviderStatsRow(stats: stats)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("アラート・制限")
                .font(.headline)
            
            if viewModel.activeAlerts.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("すべて正常です")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.activeAlerts, id: \.id) { alert in
                    AlertRow(alert: alert)
                }
            }
            
            // 制限状況
            if !viewModel.limitStatuses.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.limitStatuses, id: \.provider) { status in
                        LimitStatusRow(status: status)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Optimization Suggestions
    
    private var optimizationSuggestions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最適化提案")
                .font(.headline)
            
            if viewModel.savingsSuggestions.isEmpty {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("現在、提案はありません")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.savingsSuggestions, id: \.id) { suggestion in
                    SuggestionRow(suggestion: suggestion)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Methods
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func colorForProvider(_ provider: LLMProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        }
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let trend: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                        Text(String(format: "%.1f%%", abs(trend)))
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                    }
                }
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ProviderStatsRow: View {
    let stats: ProviderUsageStats
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(stats.provider.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f%%", stats.successRate * 100))
                    .font(.caption)
                    .foregroundColor(stats.successRate >= 0.95 ? .green : .orange)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("API呼び出し")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(stats.apiCalls)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("平均応答時間")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1fs", stats.averageResponseTime))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("コスト")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.2f", stats.cost))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AlertRow: View {
    let alert: UsageAlert
    
    var body: some View {
        HStack {
            Image(systemName: iconForAlertType(alert.type))
                .foregroundColor(colorForAlertType(alert.type))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.subheadline)
                
                if let provider = alert.provider {
                    Text(provider.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(String(format: "%.0f/%.0f", alert.currentValue, alert.threshold))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(colorForAlertType(alert.type).opacity(0.1))
        .cornerRadius(8)
    }
    
    private func iconForAlertType(_ type: AlertType) -> String {
        switch type {
        case .costThreshold: return "dollarsign.circle.fill"
        case .usageThreshold: return "exclamationmark.triangle.fill"
        case .rateLimitApproaching: return "clock.fill"
        case .dailyLimitReached: return "hand.raised.fill"
        case .monthlyLimitReached: return "stop.circle.fill"
        case .unusualActivity: return "questionmark.circle.fill"
        }
    }
    
    private func colorForAlertType(_ type: AlertType) -> Color {
        switch type {
        case .costThreshold: return .orange
        case .usageThreshold: return .yellow
        case .rateLimitApproaching: return .blue
        case .dailyLimitReached, .monthlyLimitReached: return .red
        case .unusualActivity: return .purple
        }
    }
}

struct LimitStatusRow: View {
    let status: LimitStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(status.provider.displayName) - \(status.limitType)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(status.currentUsage)/\(status.limit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(status.isExceeded ? .red : .primary)
            }
            
            ProgressView(value: min(status.percentage / 100, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: status.isExceeded ? .red : .blue))
                .scaleEffect(x: 1, y: 0.7)
        }
    }
}

struct SuggestionRow: View {
    let suggestion: SavingSuggestion
    
    var body: some View {
        HStack {
            Image(systemName: iconForSuggestionType(suggestion.type))
                .foregroundColor(colorForPriority(suggestion.priority))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.description)
                    .font(.subheadline)
                
                Text(suggestion.actionRequired)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.2f", suggestion.potentialSavings))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Text("節約可能")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(colorForPriority(suggestion.priority).opacity(0.1))
        .cornerRadius(8)
    }
    
    private func iconForSuggestionType(_ type: SuggestionType) -> String {
        switch type {
        case .modelDowngrade: return "arrow.down.circle"
        case .providerSwitch: return "arrow.triangle.2.circlepath"
        case .batchRequests: return "square.stack"
        case .cacheResponses: return "memorychip"
        case .optimizePrompts: return "text.word.spacing"
        case .removeUnusedProviders: return "trash"
        }
    }
    
    private func colorForPriority(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

// MARK: - Supporting Types

enum UsagePeriod: String, CaseIterable {
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case last3Months = "last_3_months"
    
    var displayName: String {
        switch self {
        case .today: return "今日"
        case .thisWeek: return "今週"
        case .thisMonth: return "今月"
        case .lastMonth: return "先月"
        case .last3Months: return "過去3ヶ月"
        }
    }
}

enum UsageMetric: String, CaseIterable {
    case apiCalls = "api_calls"
    case tokens = "tokens"
    case cost = "cost"
    
    var displayName: String {
        switch self {
        case .apiCalls: return "API呼び出し"
        case .tokens: return "トークン"
        case .cost: return "コスト"
        }
    }
}

#Preview {
    UsageMonitorView(
        viewModel: UsageMonitorViewModel(
            usageTracker: MockAPIUsageTracker()
        )
    )
}