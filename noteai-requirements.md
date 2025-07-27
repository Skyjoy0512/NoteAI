# NoteAI 開発要件定義書（Claude Code版）

## 1. プロジェクト概要

### 1.1 基本情報
- **プロジェクト名**: NoteAI
- **プラットフォーム**: iOS (iPhone専用、将来的にiPad対応)
- **開発言語**: Swift 5.9+
- **最小対応OS**: iOS 16.0
- **開発ツール**: Xcode 15.0+, Claude Code
- **アーキテクチャ**: MVVM + Clean Architecture

### 1.2 プロジェクト構造
```
NoteAI/
├── NoteAI.xcodeproj
├── NoteAI/
│   ├── App/
│   │   ├── NoteAIApp.swift
│   │   └── Info.plist
│   ├── Presentation/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── Domain/
│   │   ├── Entities/
│   │   ├── UseCases/
│   │   └── Repositories/
│   ├── Data/
│   │   ├── Repositories/
│   │   ├── DataSources/
│   │   └── Models/
│   ├── Infrastructure/
│   │   ├── Services/
│   │   ├── Extensions/
│   │   └── Utilities/
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── LaunchScreen.storyboard
├── NoteAITests/
├── NoteAIUITests/
└── README.md
```

## 2. 開発環境セットアップ

### 2.1 必要なツール
```bash
# Xcodeプロジェクト作成
xcodegen generate

# SwiftLint設定
brew install swiftlint

# Swift Package Manager dependencies
```

### 2.2 Package.swift
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteAI",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        // AI/ML
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.5.0"),
        
        // ネットワーク
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        
        // データベース
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        
        // UI
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "2.2.0"),
        
        // 課金
        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "4.0.0"),
        
        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        
        // Markdown
        .package(url: "https://github.com/johnxnguyen/Down", from: "0.11.0")
    ]
)
```

## 3. 機能要件

### 3.1 録音機能
- **基本録音機能**
  - バックグラウンド録音対応
  - 録音の一時停止・再開
  - 録音時間の表示
  - 音声レベルインジケーター
  - 音質設定（高/中/低）
  - ファイル形式選択（m4a/wav）

- **ウィジェット対応**
  - ホーム画面ウィジェットからワンタップで録音開始
  - 録音状態の表示（録音中/停止中）
  - 直近の録音へのクイックアクセス

### 3.2 文字起こし機能
- **ローカル処理（無料）**
  - WhisperKitによるオンデバイス文字起こし
  - モデルサイズ選択（tiny/base/small）
  - 多言語対応（日本語、英語を含む）
  - オフライン対応

- **外部API利用（有料版のみ）**
  - Whisper API（OpenAI）
  - より高精度な文字起こし
  - 大容量ファイル対応

### 3.3 AI機能
- **ローカルLLM（無料版）**
  - iOS向け軽量モデル
  - 基本的な要約機能のみ
  - オフライン動作
  - テンプレート要約（箇条書き、短文要約）

- **外部LLM API（有料版のみ - 月額500円）**
  - ユーザー自身のAPIキー設定必須
  - 対応プロバイダー：
    - OpenAI (GPT-4, GPT-3.5)
    - Google Gemini API
    - Anthropic Claude API
  - 高度な要約・分析機能
  - カスタムプロンプト
  - AskAI機能（対話型質問応答）

### 3.4 RAG（Retrieval-Augmented Generation）
- **基本機能（無料版）**
  - 録音データの検索
  - キーワード検索

- **高度な機能（有料版）**
  - ベクトル検索
  - ドキュメントインポート
    - PDF、Word、テキストファイル
    - Webページの取り込み
  - 統合検索（録音＋ドキュメント）
  - AIによる関連性分析

### 3.5 外部連携
- **Limitless API統合（有料版）**
  - Pendantデバイスとの連携
  - 録音データの自動同期
  - メタデータの統合

### 3.6 プロジェクト管理機能
- **プロジェクトフォルダ**
  - 複数の録音を1つのプロジェクトにまとめる
  - プロジェクト単位でのタグ付け・管理
  - プロジェクトカバー画像・アイコン設定
  - プロジェクトの説明・メモ機能

- **プロジェクト単位のAskAI（有料版）**
  - プロジェクト内の全録音を統合したコンテキスト
  - 横断的な質問応答
  - プロジェクト全体の要約・分析
  - 時系列での進捗追跡

### 3.7 データ管理
- **ローカルストレージ**
  - Core Dataによるデータ管理
  - 効率的なファイル管理
  - 自動バックアップ

- **クラウド同期（有料版）**
  - iCloud同期
  - エクスポート機能強化

## 4. 料金プラン

### 4.1 無料プラン（Free）
```
【提供機能】
- 録音機能（無制限）
- ローカル文字起こし（WhisperKit使用）
- 基本的な要約（ローカルLLMのみ）
- キーワード検索
- テキストエクスポート
- 広告表示あり

【制限事項】
- 外部API利用不可
- 高度なAI機能利用不可
- ドキュメントインポート不可
- 話者分離機能なし
```

### 4.2 有料プラン（Premium - 月額500円）
```
【提供機能】
- 無料版の全機能
- 広告非表示
- ユーザー自身のAPIキー設定・利用
  - OpenAI API（GPT-4/GPT-3.5/Whisper）
  - Google Gemini API
  - Anthropic Claude API
- 高度なAI機能
  - カスタムプロンプト
  - AskAI（対話型質問応答）
  - 詳細な要約・分析
- RAG機能フル活用
  - ドキュメントインポート（無制限）
  - ベクトル検索
  - 統合検索
- 話者分離機能
- Limitless連携
- 全形式でのエクスポート（PDF、Markdown等）

【注意事項】
- APIキーはユーザー自身で取得・管理
- API利用料金はユーザー負担
- 使用量モニタリング機能付き
```

## 5. 技術仕様

### 5.1 プロジェクト管理システム

#### プロジェクトサービス
```swift
// Infrastructure/Services/ProjectService.swift
import Foundation
import Combine

protocol ProjectServiceProtocol {
    func createProject(name: String, description: String?) async throws -> Project
    func addRecording(_ recording: Recording, to project: Project) async throws
    func removeRecording(_ recordingId: UUID, from project: Project) async throws
    func getAllProjects() async throws -> [Project]
    func getProjectContext(_ project: Project) async throws -> ProjectContext
}

class ProjectService: ProjectServiceProtocol {
    private let repository: ProjectRepositoryProtocol
    private let ragService: RAGServiceProtocol
    
    func createProject(name: String, description: String?) async throws -> Project {
        let project = Project(
            id: UUID(),
            name: name,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            recordingIds: [],
            coverImageData: nil
        )
        
        try await repository.save(project)
        return project
    }
    
    func getProjectContext(_ project: Project) async throws -> ProjectContext {
        // プロジェクト内の全録音を取得
        let recordings = try await repository.getRecordings(for: project)
        
        // 統合されたコンテキストを作成
        let transcriptions = recordings.compactMap { $0.transcription }
        let combinedText = transcriptions.joined(separator: "\n\n---\n\n")
        
        // メタデータ収集
        let totalDuration = recordings.reduce(0) { $0 + $1.duration }
        let dateRange = (
            start: recordings.map { $0.date }.min() ?? Date(),
            end: recordings.map { $0.date }.max() ?? Date()
        )
        
        return ProjectContext(
            projectId: project.id,
            recordings: recordings,
            combinedTranscription: combinedText,
            totalDuration: totalDuration,
            dateRange: dateRange,
            recordingCount: recordings.count
        )
    }
}
```

#### プロジェクトベースのAskAI
```swift
// Domain/UseCases/ProjectAskAIUseCase.swift
protocol ProjectAskAIUseCaseProtocol {
    func askAboutProject(_ question: String, project: Project) async throws -> ProjectAIResponse
    func generateProjectSummary(_ project: Project, type: SummaryType) async throws -> String
    func analyzeProjectProgress(_ project: Project) async throws -> ProjectAnalysis
}

class ProjectAskAIUseCase: ProjectAskAIUseCaseProtocol {
    private let projectService: ProjectServiceProtocol
    private let ragService: RAGServiceProtocol
    private let llmService: LLMServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    
    func askAboutProject(_ question: String, project: Project) async throws -> ProjectAIResponse {
        // サブスクリプション確認
        guard await subscriptionService.hasActiveSubscription() else {
            throw ProjectAIError.subscriptionRequired
        }
        
        // プロジェクトコンテキスト取得
        let context = try await projectService.getProjectContext(project)
        
        // RAG検索（プロジェクト内のみ）
        let searchResults = try await ragService.searchInProject(
            query: question,
            projectId: project.id,
            limit: 10
        )
        
        // プロンプト構築
        let systemPrompt = """
        あなたは「\(project.name)」プロジェクトの録音データを分析するアシスタントです。
        このプロジェクトには\(context.recordingCount)件の録音（合計\(formatDuration(context.totalDuration))）が含まれています。
        期間: \(formatDateRange(context.dateRange))
        
        以下のコンテキストに基づいて質問に答えてください：
        """
        
        let prompt = buildPromptWithContext(
            question: question,
            context: context,
            searchResults: searchResults
        )
        
        // LLM呼び出し
        let response = try await llmService.generateResponse(
            prompt: prompt,
            context: systemPrompt,
            provider: getUserPreferredProvider()
        )
        
        return ProjectAIResponse(
            answer: response.text,
            sources: searchResults.map { 
                ProjectSource(
                    recordingId: $0.recordingId,
                    recordingTitle: $0.recordingTitle,
                    timestamp: $0.timestamp,
                    relevantText: $0.text
                )
            },
            projectStats: ProjectStats(
                totalRecordings: context.recordingCount,
                totalDuration: context.totalDuration,
                dateRange: context.dateRange
            )
        )
    }
    
    func generateProjectSummary(_ project: Project, type: SummaryType) async throws -> String {
        let context = try await projectService.getProjectContext(project)
        
        let prompt: String
        switch type {
        case .overview:
            prompt = "このプロジェクトの全体的な概要を作成してください。主要なトピック、決定事項、進捗を含めてください。"
        case .timeline:
            prompt = "このプロジェクトの時系列での進展を整理してください。各録音での主要な出来事や決定を時系列で。"
        case .actionItems:
            prompt = "このプロジェクト全体を通じてのアクションアイテムとその状況を整理してください。"
        case .keyInsights:
            prompt = "このプロジェクトから得られた重要な洞察や学びをまとめてください。"
        }
        
        return try await askAboutProject(prompt, project: project).answer
    }
}
```

### 5.2 APIキー管理システム（有料版コア機能）

#### セキュアなAPIキー管理
```swift
// Infrastructure/Services/APIKeyManager.swift
import Security
import Combine

class APIKeyManager: ObservableObject {
    @Published var hasValidAPIKeys: Bool = false
    @Published var apiUsageWarnings: [APIUsageWarning] = []
    
    enum APIProvider: String, CaseIterable {
        case openAI = "openai_api_key"
        case googleGemini = "gemini_api_key"
        case anthropic = "claude_api_key"
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .googleGemini: return "Google Gemini"
            case .anthropic: return "Anthropic Claude"
            }
        }
        
        var setupGuideURL: URL {
            switch self {
            case .openAI:
                return URL(string: "https://platform.openai.com/api-keys")!
            case .googleGemini:
                return URL(string: "https://makersuite.google.com/app/apikey")!
            case .anthropic:
                return URL(string: "https://console.anthropic.com/api")!
            }
        }
    }
    
    // Keychainへの暗号化保存
    func saveAPIKey(_ key: String, for provider: APIProvider) throws {
        // 検証
        guard isValidAPIKey(key, for: provider) else {
            throw APIKeyError.invalidFormat
        }
        
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.rawValue,
            kSecAttrService as String: "com.noteai.apikeys",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw APIKeyError.saveFailed
        }
        
        updateHasValidAPIKeys()
    }
    
    // APIキーの検証
    private func isValidAPIKey(_ key: String, for provider: APIProvider) -> Bool {
        switch provider {
        case .openAI:
            return key.hasPrefix("sk-") && key.count > 20
        case .googleGemini:
            return key.count == 39 // Gemini APIキーは39文字
        case .anthropic:
            return key.hasPrefix("sk-ant-") && key.count > 30
        }
    }
}
```

#### API使用量トラッキング
```swift
// Infrastructure/Services/APIUsageTracker.swift
import Foundation

class APIUsageTracker: ObservableObject {
    @Published var monthlyUsage: [APIProvider: APIUsage] = [:]
    @Published var estimatedCost: [APIProvider: Double] = [:]
    
    struct APIUsage {
        var tokens: Int = 0
        var requests: Int = 0
        var audioMinutes: Double = 0
        
        var estimatedCost: Double {
            // プロバイダーごとの料金計算
            return 0 // 実装省略
        }
    }
    
    func trackUsage(provider: APIProvider, tokens: Int? = nil, audioMinutes: Double? = nil) {
        var usage = monthlyUsage[provider] ?? APIUsage()
        
        if let tokens = tokens {
            usage.tokens += tokens
        }
        if let audioMinutes = audioMinutes {
            usage.audioMinutes += audioMinutes
        }
        usage.requests += 1
        
        monthlyUsage[provider] = usage
        estimatedCost[provider] = usage.estimatedCost
        
        // 使用量警告
        checkUsageLimit(for: provider)
    }
    
    private func checkUsageLimit(for provider: APIProvider) {
        guard let usage = monthlyUsage[provider] else { return }
        
        // ユーザー設定の上限と比較
        if usage.estimatedCost > getUserLimit(for: provider) * 0.8 {
            sendUsageWarning(provider: provider, percentage: 80)
        }
    }
}
```

### 5.2 LLMサービス実装

#### 統合LLMサービス
```swift
// Infrastructure/Services/LLMService.swift
protocol LLMServiceProtocol {
    func generateResponse(prompt: String, context: String?, provider: APIProvider) async throws -> LLMResponse
    func validateAPIKey(_ key: String, provider: APIProvider) async throws -> Bool
}

class LLMService: LLMServiceProtocol {
    private let apiKeyManager: APIKeyManager
    private let usageTracker: APIUsageTracker
    private let subscriptionService: SubscriptionService
    
    func generateResponse(prompt: String, context: String?, provider: APIProvider) async throws -> LLMResponse {
        // サブスクリプション確認
        guard await subscriptionService.hasActiveSubscription() else {
            throw LLMError.subscriptionRequired
        }
        
        // APIキー取得
        guard let apiKey = try? apiKeyManager.getAPIKey(for: provider) else {
            throw LLMError.apiKeyNotSet
        }
        
        // プロバイダーごとの実装
        switch provider {
        case .openAI:
            return try await callOpenAI(prompt: prompt, context: context, apiKey: apiKey)
        case .googleGemini:
            return try await callGemini(prompt: prompt, context: context, apiKey: apiKey)
        case .anthropic:
            return try await callClaude(prompt: prompt, context: context, apiKey: apiKey)
        }
    }
    
    private func callOpenAI(prompt: String, context: String?, apiKey: String) async throws -> LLMResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": "You are a helpful assistant for meeting transcription analysis."],
            ["role": "user", "content": context ?? ""],
            ["role": "user", "content": prompt]
        ]
        
        let body = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "temperature": 0.7
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // レスポンス処理とトークン計算
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        // 使用量トラッキング
        usageTracker.trackUsage(provider: .openAI, tokens: response.usage.totalTokens)
        
        return LLMResponse(
            text: response.choices.first?.message.content ?? "",
            tokens: response.usage.totalTokens,
            provider: .openAI
        )
    }
}
```

### 5.3 UI実装 - APIキー設定画面

```swift
// Presentation/Views/Settings/APIKeySettingsView.swift
import SwiftUI

struct APIKeySettingsView: View {
    @StateObject private var viewModel = APIKeySettingsViewModel()
    @State private var selectedProvider: APIKeyManager.APIProvider = .openAI
    @State private var apiKeyInput = ""
    @State private var showingGuide = false
    
    var body: some View {
        NavigationStack {
            Form {
                // サブスクリプション状態
                Section {
                    if viewModel.hasActiveSubscription {
                        Label("Premium会員", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API機能を利用するにはPremiumプランへの登録が必要です")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Premiumプランに登録（月額500円）") {
                                viewModel.showingSubscription = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if viewModel.hasActiveSubscription {
                    // APIプロバイダー選択
                    Section("APIプロバイダー") {
                        ForEach(APIKeyManager.APIProvider.allCases, id: \.self) { provider in
                            HStack {
                                Label(provider.displayName, systemImage: viewModel.hasAPIKey(for: provider) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(viewModel.hasAPIKey(for: provider) ? .green : .secondary)
                                
                                Spacer()
                                
                                Button("設定") {
                                    selectedProvider = provider
                                    apiKeyInput = ""
                                    showingGuide = true
                                }
                                .font(.caption)
                            }
                        }
                    }
                    
                    // 使用量モニター
                    Section("今月の使用量") {
                        ForEach(viewModel.monthlyUsage.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { provider in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(provider.displayName)
                                    Spacer()
                                    Text("推定 ¥\(viewModel.estimatedCost[provider] ?? 0, specifier: "%.0f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let usage = viewModel.monthlyUsage[provider] {
                                    HStack {
                                        Text("\(usage.requests)回")
                                        Text("•")
                                        Text("\(usage.tokens)トークン")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // 使用量アラート設定
                    Section("使用量アラート") {
                        ForEach(APIKeyManager.APIProvider.allCases, id: \.self) { provider in
                            HStack {
                                Text(provider.displayName)
                                Spacer()
                                TextField("上限金額", value: $viewModel.usageLimits[provider], format: .currency(code: "JPY"))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    
                    // ヘルプ
                    Section {
                        Link("APIキーの取得方法", destination: URL(string: "https://noteai.app/api-guide")!)
                        Link("料金計算ツール", destination: URL(string: "https://noteai.app/pricing-calculator")!)
                    }
                }
            }
            .navigationTitle("API設定")
            .sheet(isPresented: $showingGuide) {
                APIKeyGuideView(provider: selectedProvider, apiKeyInput: $apiKeyInput) {
                    Task {
                        try await viewModel.saveAPIKey(apiKeyInput, for: selectedProvider)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingSubscription) {
                SubscriptionView()
            }
        }
    }
}

// APIキー取得ガイド
struct APIKeyGuideView: View {
    let provider: APIKeyManager.APIProvider
    @Binding var apiKeyInput: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(provider.displayName) APIキーの設定")
                        .font(.title2)
                        .bold()
                    
                    // プロバイダーごとのガイド
                    switch provider {
                    case .openAI:
                        OpenAIGuideView()
                    case .googleGemini:
                        GeminiGuideView()
                    case .anthropic:
                        ClaudeGuideView()
                    }
                    
                    // APIキー入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APIキー")
                            .font(.headline)
                        
                        SecureField("APIキーを入力", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("APIキーは暗号化されて安全に保存されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 料金目安
                    PricingEstimateView(provider: provider)
                    
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(apiKeyInput.isEmpty)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### 5.4 録音・文字起こしサービス

```swift
// Infrastructure/Services/TranscriptionService.swift
import WhisperKit

class TranscriptionService: TranscriptionServiceProtocol {
    private let subscriptionService: SubscriptionService
    private let apiKeyManager: APIKeyManager
    private let usageTracker: APIUsageTracker
    
    func transcribe(audioURL: URL, options: TranscriptionOptions) async throws -> TranscriptionResult {
        if options.useAPI && await subscriptionService.hasActiveSubscription() {
            // 有料版: Whisper API使用
            return try await transcribeWithAPI(audioURL: audioURL)
        } else {
            // 無料版: ローカルWhisperKit使用
            return try await transcribeLocally(audioURL: audioURL, model: options.localModel)
        }
    }
    
    private func transcribeWithAPI(audioURL: URL) async throws -> TranscriptionResult {
        guard let apiKey = try? apiKeyManager.getAPIKey(for: .openAI) else {
            throw TranscriptionError.apiKeyNotSet
        }
        
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // マルチパートフォームデータ作成
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioURL)
        let body = createMultipartBody(
            audioData: audioData,
            fileName: audioURL.lastPathComponent,
            boundary: boundary
        )
        
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(WhisperAPIResponse.self, from: data)
        
        // 使用量トラッキング（音声の長さから計算）
        let duration = getAudioDuration(from: audioURL)
        usageTracker.trackUsage(provider: .openAI, audioMinutes: duration / 60)
        
        return TranscriptionResult(
            text: response.text,
            language: response.language ?? "ja",
            duration: duration,
            segments: []
        )
    }
}
```

## 6. データモデル

### 6.1 Core Dataエンティティ
```swift
// Project Entity (新規追加)
entity Project {
    id: UUID
    name: String
    description: String?
    coverImageData: Data?
    createdAt: Date
    updatedAt: Date
    
    // Relationships
    recordings: [Recording] // 1対多
    tags: [Tag]
    summaries: [ProjectSummary]
}

// Recording Entity (更新)
entity Recording {
    id: UUID
    title: String
    date: Date
    duration: Double
    audioFileURL: String
    transcription: String?
    transcriptionMethod: String // "local" or "api"
    whisperModel: String?
    language: String
    isFromLimitless: Bool
    createdAt: Date
    updatedAt: Date
    
    // Relationships
    project: Project? // 所属プロジェクト
    segments: [RecordingSegment] // タイムスタンプ付きセグメント
}

// ProjectSummary Entity (新規)
entity ProjectSummary {
    id: UUID
    projectId: UUID
    type: String // "overview", "timeline", "actionItems", "keyInsights"
    content: String
    generatedAt: Date
    llmProvider: String
}

// RecordingSegment Entity (新規)
entity RecordingSegment {
    id: UUID
    recordingId: UUID
    text: String
    startTime: Double
    endTime: Double
    speaker: String?
}

// Subscription Entity (重要)
entity Subscription {
    id: UUID
    type: String // "free" or "premium"
    startDate: Date
    expirationDate: Date?
    isActive: Bool
    receiptData: Data?
}

// APIKeyUsage Entity
entity APIKeyUsage {
    id: UUID
    provider: String
    date: Date
    tokens: Int32
    requests: Int32
    audioMinutes: Double
    estimatedCost: Double
}
```

### 6.2 ビジネスモデル
```swift
// Domain/Entities/Project.swift
struct Project: Identifiable {
    let id: UUID
    var name: String
    var description: String?
    var coverImageData: Data?
    let createdAt: Date
    var updatedAt: Date
    var recordings: [Recording] = []
    
    var recordingCount: Int {
        recordings.count
    }
    
    var totalDuration: TimeInterval {
        recordings.reduce(0) { $0 + $1.duration }
    }
    
    var dateRange: (start: Date, end: Date)? {
        guard !recordings.isEmpty else { return nil }
        let dates = recordings.map { $0.date }
        return (dates.min()!, dates.max()!)
    }
}

// Domain/Entities/ProjectContext.swift
struct ProjectContext {
    let projectId: UUID
    let recordings: [Recording]
    let combinedTranscription: String
    let totalDuration: TimeInterval
    let dateRange: (start: Date, end: Date)
    let recordingCount: Int
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalDuration) ?? ""
    }
}

// Domain/Entities/ProjectAIResponse.swift
struct ProjectAIResponse {
    let answer: String
    let sources: [ProjectSource]
    let projectStats: ProjectStats
}

struct ProjectSource {
    let recordingId: UUID
    let recordingTitle: String
    let timestamp: TimeInterval?
    let relevantText: String
}
```

## 7. UI実装仕様

### 7.1 プロジェクト関連画面

#### プロジェクト一覧画面
```swift
// Presentation/Views/Projects/ProjectListView.swift
import SwiftUI

struct ProjectListView: View {
    @StateObject private var viewModel = ProjectListViewModel()
    @State private var showingCreateProject = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                    // 新規プロジェクト作成カード
                    Button(action: { showingCreateProject = true }) {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                            Text("新規プロジェクト")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // プロジェクトカード
                    ForEach(viewModel.projects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            ProjectCard(project: project)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("プロジェクト")
            .sheet(isPresented: $showingCreateProject) {
                CreateProjectView()
            }
        }
    }
}

// プロジェクトカード
struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // カバー画像またはアイコン
            if let imageData = project.coverImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 80)
                    .clipped()
            } else {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 80)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Label("\(project.recordingCount)", systemImage: "waveform")
                    Spacer()
                    Text(project.formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

#### プロジェクト詳細画面
```swift
// Presentation/Views/Projects/ProjectDetailView.swift
struct ProjectDetailView: View {
    @StateObject private var viewModel: ProjectDetailViewModel
    let project: Project
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: ProjectDetailViewModel(project: project))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // プロジェクト情報
                ProjectHeaderView(project: project)
                
                // AskAIセクション（有料版のみ）
                if viewModel.hasActiveSubscription {
                    ProjectAskAISection(project: project)
                        .padding(.horizontal)
                }
                
                // 録音一覧
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("録音 (\(project.recordingCount))")
                            .font(.headline)
                        
                        Spacer()
                        
                        Menu {
                            Button("録音を追加", systemImage: "plus") {
                                viewModel.showingAddRecording = true
                            }
                            Button("新規録音", systemImage: "mic") {
                                viewModel.startNewRecording()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .padding(.horizontal)
                    
                    ForEach(viewModel.recordings) { recording in
                        RecordingRow(recording: recording, showProject: false)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.showingAddRecording) {
            AddRecordingToProjectView(project: project)
        }
    }
}

// プロジェクトAskAIセクション
struct ProjectAskAISection: View {
    let project: Project
    @State private var question = ""
    @State private var showingAskAI = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                Text("プロジェクトAI")
                    .font(.headline)
            }
            
            HStack {
                TextField("このプロジェクトについて質問...", text: $question)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("質問", action: { showingAskAI = true })
                    .buttonStyle(.borderedProminent)
                    .disabled(question.isEmpty)
            }
            
            // クイックアクション
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuickActionChip(title: "全体要約", icon: "doc.text") {
                        question = "このプロジェクトの全体的な要約を作成してください"
                        showingAskAI = true
                    }
                    
                    QuickActionChip(title: "進捗確認", icon: "chart.line.uptrend.xyaxis") {
                        question = "プロジェクトの進捗状況を時系列でまとめてください"
                        showingAskAI = true
                    }
                    
                    QuickActionChip(title: "TODO抽出", icon: "checklist") {
                        question = "すべてのアクションアイテムとTODOをリストアップしてください"
                        showingAskAI = true
                    }
                    
                    QuickActionChip(title: "重要な決定", icon: "star") {
                        question = "プロジェクトで行われた重要な決定事項をまとめてください"
                        showingAskAI = true
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingAskAI) {
            ProjectAskAIView(project: project, initialQuestion: question)
        }
    }
}
```

#### プロジェクトAskAI画面
```swift
// Presentation/Views/Projects/ProjectAskAIView.swift
struct ProjectAskAIView: View {
    @StateObject private var viewModel: ProjectAskAIViewModel
    let project: Project
    
    init(project: Project, initialQuestion: String = "") {
        self.project = project
        self._viewModel = StateObject(wrappedValue: ProjectAskAIViewModel(
            project: project,
            initialQuestion: initialQuestion
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // プロジェクト情報バー
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        Text("\(project.recordingCount)件の録音 • \(project.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                
                // チャット履歴
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                    Text("考え中...")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // 入力エリア
                VStack(spacing: 8) {
                    // ソース表示
                    if !viewModel.currentSources.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.currentSources, id: \.recordingId) { source in
                                    SourceChip(source: source)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        TextField("質問を入力...", text: $viewModel.inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: viewModel.sendMessage) {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.1))
            }
            .navigationTitle("プロジェクトAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        // Dismiss
                    }
                }
            }
        }
    }
}
```

### 7.2 メイン画面の更新

### 7.1 無料版の価値提供
- 高品質なローカル文字起こし（WhisperKit）
- 基本的な要約機能
- プライバシー重視（完全ローカル処理）
- 制限なしの録音機能

### 7.2 有料版（月額500円）の価値提供
- **最大の価値**: ユーザー自身のAPIキーで無制限利用
- API利用による高精度文字起こし
- 高度なAI機能（GPT-4、Claude、Gemini）
- カスタムプロンプト
- 使用量モニタリング・コスト管理
- 広告非表示

### 7.3 収益シミュレーション
```
【想定コスト（月額）】
- Apple Developer Program: 1,250円（年額15,000円÷12）
- Firebase（最小構成）: 0円（無料枠内）
- 合計: 1,250円

【損益分岐点】
- 必要有料ユーザー数: 3人（1,250円 ÷ 500円）

【収益予測】
- 100人の有料ユーザー: 50,000円/月（利益: 48,750円）
- 1,000人の有料ユーザー: 500,000円/月（利益: 498,750円）
```

## 8. マーケティング戦略

### 8.1 ターゲットユーザー
1. **プライバシー重視層**（無料版）
   - ローカル処理を求めるユーザー
   - オフライン利用が必要なユーザー

2. **パワーユーザー層**（有料版）
   - すでにChatGPT Plus等を利用している
   - APIの存在を知っている技術リテラシー層
   - コスト管理しながら高機能を使いたい層

### 8.2 差別化ポイント
- 「自分のAPIキーが使える唯一の議事録アプリ」
- 「API利用料金の見える化」
- 「無料でも高品質な文字起こし」

## 10. 開発フェーズ

### Phase 1: MVP開発（2週間）
- [ ] プロジェクトセットアップ
- [ ] 基本的な録音機能
- [ ] WhisperKitによるローカル文字起こし
- [ ] プロジェクト管理機能（基本）
- [ ] Core Dataスキーマ（Project対応）
- [ ] 基本的なUI実装

### Phase 2: 有料機能実装（2週間）
- [ ] RevenueCat統合（課金システム）
- [ ] APIキー管理システム
- [ ] LLMサービス実装（OpenAI、Gemini、Claude）
- [ ] プロジェクト単位のAskAI機能
- [ ] 使用量トラッキング
- [ ] API設定画面

### Phase 3: 高度な機能（2週間）
- [ ] RAGシステム実装（プロジェクト対応）
- [ ] プロジェクト横断検索
- [ ] ドキュメントインポート（プロジェクトへの追加）
- [ ] Limitless API連携
- [ ] 話者分離機能
- [ ] プロジェクト分析機能

### Phase 4: リリース準備（1週間）
- [ ] パフォーマンス最適化
- [ ] UIポリッシュ
- [ ] App Store申請準備
- [ ] ドキュメント作成

## 10. 技術的な注意点

### 10.1 APIキーのセキュリティ
- Keychainに暗号化保存
- デバイス固有の暗号化
- APIキーのバリデーション
- 誤って露出しないUI設計

### 10.2 使用量管理
- リアルタイムトラッキング
- 月次リセット
- 警告通知システム
- コスト予測機能

### 10.3 エラーハンドリング
- APIエラーの適切な処理
- フォールバック（API→ローカル）
- ユーザーへの分かりやすいエラー表示

## 11. 今後の拡張計画

### 11.1 短期（3ヶ月）
- iPad対応
- より多くのLLMプロバイダー対応
- チーム共有機能（別料金）

### 11.2 中期（6ヶ月）
- Mac版開発
- ブラウザ拡張機能
- API利用統計ダッシュボード

### 11.3 長期（12ヶ月）
- 独自API提供（高額プラン）
- エンタープライズ版
- プラグインシステム

---

この要件定義書は、個人開発でNoteAIを効率的に開発し、持続可能なビジネスモデルを構築するために作成されています。ユーザー自身のAPIキーを使用する仕組みにより、運用コストを最小限に抑えながら、高機能を提供できる設計となっています。