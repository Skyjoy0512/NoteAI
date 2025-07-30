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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
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
                #else
                ToolbarItem(placement: .primaryAction) {
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
                
                ToolbarItem(placement: .primaryAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                #endif
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
            // UsageMonitorのエクスポート用ビュー（暫定実装）
            NavigationView {
                VStack {
                    Text("使用量データのエクスポート")
                        .font(.headline)
                        .padding()
                    
                    Text("エクスポート機能の実装予定")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .navigationTitle("データエクスポート")
                #if canImport(UIKit)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: toolbarPlacement) {
                        Button("閉じる") {
                            showingExportOptions = false
                        }
                    }
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var toolbarPlacement: ToolbarItemPlacement {
        #if canImport(UIKit)
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        Text("Period Selector - 最小実装")
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        Text("Summary Cards - 最小実装")
    }
    
    // MARK: - Usage Chart
    
    private var usageChart: some View {
        Text("Usage Chart - 最小実装")
    }
    
    // MARK: - Cost Breakdown
    
    private var costBreakdown: some View {
        Text("Cost Breakdown - 最小実装")
    }
    
    // MARK: - Provider Stats
    
    private var providerStats: some View {
        Text("Provider Stats - 最小実装")
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        Text("Alerts Section - 最小実装")
    }
    
    // MARK: - Optimization Suggestions
    
    private var optimizationSuggestions: some View {
        Text("Optimization Suggestions - 最小実装")
    }
}

#Preview {
    UsageMonitorView(
        viewModel: UsageMonitorViewModel(
            usageTracker: MockAPIUsageTrackerForPreview()
        )
    )
}