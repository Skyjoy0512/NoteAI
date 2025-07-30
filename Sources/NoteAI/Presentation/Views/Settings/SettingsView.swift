import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var showingAPIKeySettings = false
    @State private var showingSubscriptionView = false
    @State private var showingUsageView = false
    
    init(viewModel: SettingsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            List {
                // プレミアム機能セクション
                premiumSection
                
                // 録音設定セクション
                recordingSection
                
                // AI・文字起こし設定セクション
                aiTranscriptionSection
                
                // APIキー管理セクション
                apiKeySection
                
                // 使用量・コスト管理セクション
                usageSection
                
                // アプリ設定セクション
                appSection
                
                // サポート・情報セクション
                supportSection
            }
            .navigationTitle("設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await viewModel.refreshSettings()
            }
        }
        /*
        .sheet(isPresented: $showingAPIKeySettings) {
            APIKeySettingsView(
                viewModel: viewModel.apiKeySettingsViewModel
            )
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView(
                viewModel: viewModel.subscriptionViewModel
            )
        }
        */
        .sheet(isPresented: $showingUsageView) {
            UsageMonitorView(
                viewModel: viewModel.usageMonitorViewModel
            )
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Premium Section
    
    private var premiumSection: some View {
        Section {
            if viewModel.isSubscriptionActive {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                    Text("プレミアムプラン")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("有効")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button {
                    showingSubscriptionView = true
                } label: {
                    HStack {
                        Text("サブスクリプション管理")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Button {
                    showingSubscriptionView = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("プレミアムにアップグレード")
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("AI機能、無制限録音、API統合")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("プレミアム機能")
        }
    }
    
    // MARK: - Recording Section
    
    private var recordingSection: some View {
        Section {
            HStack {
                Text("録音品質")
                Spacer()
                Picker("録音品質", selection: $viewModel.recordingQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("ファイル形式")
                Spacer()
                Picker("ファイル形式", selection: $viewModel.audioFormat) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Toggle("バックグラウンド録音", isOn: $viewModel.allowBackgroundRecording)
            
            Toggle("自動停止", isOn: $viewModel.autoStopRecording)
            
            if viewModel.autoStopRecording {
                HStack {
                    Text("自動停止時間")
                    Spacer()
                    Picker("自動停止時間", selection: $viewModel.autoStopDuration) {
                        ForEach([30, 60, 120, 300], id: \.self) { minutes in
                            Text("\(minutes)分").tag(minutes)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        } header: {
            Text("録音設定")
        }
    }
    
    // MARK: - AI Transcription Section
    
    private var aiTranscriptionSection: some View {
        Section {
            HStack {
                Text("デフォルト言語")
                Spacer()
                Picker("言語", selection: $viewModel.defaultLanguage) {
                    ForEach(SupportedLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("文字起こし方法")
                Spacer()
                Picker("方法", selection: $viewModel.transcriptionMethod) {
                    Text("ローカル (Base)").tag(TranscriptionMethod.local(.base))
                    Text("ローカル (Small)").tag(TranscriptionMethod.local(.small))
                    if viewModel.isSubscriptionActive {
                        Text("API (OpenAI)").tag(TranscriptionMethod.api(.openAI(.gpt35turbo)))
                        Text("API (Gemini)").tag(TranscriptionMethod.api(.gemini(.geminipro)))
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            if case .api = viewModel.transcriptionMethod {
                if viewModel.isSubscriptionActive {
                    HStack {
                        Text("優先AIプロバイダー")
                        Spacer()
                        Picker("プロバイダー", selection: $viewModel.preferredAIProvider) {
                            ForEach(LLMProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                } else {
                    HStack {
                        Text("API機能")
                        Spacer()
                        Text("プレミアム限定")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Toggle("自動要約", isOn: $viewModel.autoSummarize)
            
            Toggle("キーワード抽出", isOn: $viewModel.autoExtractKeywords)
            
            if !viewModel.isSubscriptionActive && (viewModel.autoSummarize || viewModel.autoExtractKeywords) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("AI機能はプレミアムプランで利用可能です")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("AI・文字起こし設定")
        }
    }
    
    // MARK: - API Key Section
    
    private var apiKeySection: some View {
        Section {
            Button {
                showingAPIKeySettings = true
            } label: {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                    Text("APIキー管理")
                    Spacer()
                    if viewModel.hasAPIKeys {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.hasAPIKeys {
                HStack {
                    Text("設定済みプロバイダー")
                    Spacer()
                    Text("\(viewModel.configuredProviders.count)個")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("APIキー設定")
        } footer: {
            if !viewModel.isSubscriptionActive {
                Text("AI機能を利用するにはプレミアムプランとAPIキーの設定が必要です。")
            }
        }
    }
    
    // MARK: - Usage Section
    
    private var usageSection: some View {
        Section {
            Button {
                showingUsageView = true
            } label: {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.green)
                    Text("使用量・コスト管理")
                    Spacer()
                    if viewModel.hasUsageData {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("今月: \(viewModel.monthlyUsageText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("コスト: \(viewModel.monthlyCostText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.isSubscriptionActive {
                HStack {
                    Text("使用状況")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("API呼び出し: \(viewModel.monthlyAPICalls)/月")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("録音時間: \(viewModel.monthlyRecordingMinutes)分/月")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("使用量・コスト")
        }
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        Section {
            HStack {
                Text("アプリテーマ")
                Spacer()
                Picker("テーマ", selection: $viewModel.appTheme) {
                    Text("自動").tag(AppTheme.auto)
                    Text("ライト").tag(AppTheme.light)
                    Text("ダーク").tag(AppTheme.dark)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Text("言語")
                Spacer()
                Picker("言語", selection: $viewModel.appLanguage) {
                    Text("日本語").tag(AppLanguage.japanese)
                    Text("English").tag(AppLanguage.english)
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedback)
            
            Toggle("自動バックアップ", isOn: $viewModel.autoBackup)
            
            if viewModel.autoBackup {
                HStack {
                    Text("バックアップ頻度")
                    Spacer()
                    Picker("頻度", selection: $viewModel.backupFrequency) {
                        Text("毎日").tag(BackupFrequency.daily)
                        Text("毎週").tag(BackupFrequency.weekly)
                        Text("毎月").tag(BackupFrequency.monthly)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        } header: {
            Text("アプリ設定")
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section {
            Button {
                viewModel.openPrivacyPolicy()
            } label: {
                HStack {
                    Text("プライバシーポリシー")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                viewModel.openTermsOfService()
            } label: {
                HStack {
                    Text("利用規約")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button {
                viewModel.sendFeedback()
            } label: {
                HStack {
                    Text("フィードバック送信")
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("バージョン")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("サポート・情報")
        }
    }
}

// MARK: - Supporting Enums

// RecordingQuality is now defined in Core/Limitless/ContinuousRecordingManager.swift

// AudioFormat enum は Core/Limitless/LimitlessTypes.swift で定義されています

// SupportedLanguage enum は Core/Common/RAGTypes.swift で定義されています

// TranscriptionMethod is defined in Domain/Entities/Enums.swift
// Use the canonical complex enum with associated values from the Domain layer

// AppTheme, AppLanguage, and BackupFrequency are now defined in AppConstants.swift

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            subscriptionService: MockSubscriptionServiceForPreview(),
            apiKeyManager: MockAPIKeyManagerForPreview(),
            usageTracker: MockAPIUsageTrackerForPreview()
        )
    )
}