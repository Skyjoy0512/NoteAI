# NoteAI iOS App - 技術設計書

## 1. アーキテクチャ概要

### 1.1 全体アーキテクチャ
```
┌─────────────────────────────────────────────────────────────┐
│                        NoteAI iOS App                        │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer (SwiftUI + MVVM)                       │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │   Recording │  Transcript │   Project   │   Settings  │  │
│  │    Views    │    Views    │    Views    │    Views    │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Domain Layer (Business Logic)                             │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │  Recording  │Transcription│   Project   │     AI      │  │
│  │  UseCases   │  UseCases   │  UseCases   │  UseCases   │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer (Data & External Services)           │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │  Audio      │  WhisperKit │   Core      │    API      │  │
│  │  Services   │   Service   │    Data     │  Services   │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Clean Architecture + MVVM パターン
- **Presentation Layer**: SwiftUI Views + ViewModels
- **Domain Layer**: UseCases + Entities + Repository Protocols
- **Infrastructure Layer**: Repository Implementations + External Services

### 1.3 技術スタック
```swift
// 開発環境
Platform: iOS 16.0+
Language: Swift 5.9+
UI Framework: SwiftUI
Architecture: MVVM + Clean Architecture
Database: Core Data + GRDB.swift
Dependency Injection: Manual DI Container
```

## 2. データ層設計

### 2.1 Core Data モデル設計

#### 2.1.1 Project エンティティ
```swift
@Entity
class ProjectEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var projectDescription: String?
    @NSManaged var coverImageData: Data?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var metadata: Data? // JSON encoded ProjectMetadata
    
    // Relationships
    @NSManaged var recordings: NSSet? // To-many RecordingEntity
    @NSManaged var tags: NSSet? // To-many TagEntity
    @NSManaged var summaries: NSSet? // To-many ProjectSummaryEntity
}

// Domain Model
struct Project: Identifiable {
    let id: UUID
    var name: String
    var description: String?
    var coverImageData: Data?
    let createdAt: Date
    var updatedAt: Date
    var metadata: ProjectMetadata
    var recordings: [Recording] = []
    var tags: [Tag] = []
}
```

#### 2.1.2 Recording エンティティ
```swift
@Entity
class RecordingEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var audioFileURL: String
    @NSManaged var transcription: String?
    @NSManaged var transcriptionMethod: String // "local" | "api"
    @NSManaged var whisperModel: String?
    @NSManaged var language: String
    @NSManaged var duration: Double
    @NSManaged var audioQuality: String // "high" | "standard" | "low"
    @NSManaged var isFromLimitless: Bool
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var metadata: Data? // JSON encoded RecordingMetadata
    
    // Relationships
    @NSManaged var project: ProjectEntity?
    @NSManaged var segments: NSSet? // To-many RecordingSegmentEntity
}

// Domain Model
struct Recording: Identifiable {
    let id: UUID
    var title: String
    let audioFileURL: URL
    var transcription: String?
    let transcriptionMethod: TranscriptionMethod
    var whisperModel: WhisperModel?
    let language: String
    let duration: TimeInterval
    let audioQuality: AudioQuality
    let isFromLimitless: Bool
    let createdAt: Date
    var updatedAt: Date
    var metadata: RecordingMetadata
    var segments: [RecordingSegment] = []
}
```

#### 2.1.3 APIキー・課金エンティティ
```swift
@Entity
class SubscriptionEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var subscriptionType: String // "free" | "premium"
    @NSManaged var isActive: Bool
    @NSManaged var startDate: Date
    @NSManaged var expirationDate: Date?
    @NSManaged var receiptData: Data?
    @NSManaged var lastValidated: Date?
}

@Entity 
class APIUsageEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var provider: String // "openai" | "gemini" | "anthropic"
    @NSManaged var date: Date
    @NSManaged var tokens: Int32
    @NSManaged var requests: Int32
    @NSManaged var audioMinutes: Double
    @NSManaged var estimatedCost: Double
    @NSManaged var month: String // "2025-01" format for monthly aggregation
}
```

### 2.2 GRDB.swift 使用箇所
```swift
// 高速検索・分析用途でGRDBを併用
class AnalyticsDatabase {
    private let dbQueue: DatabaseQueue
    
    // 検索インデックス
    func createSearchIndex() throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS transcription_fts 
                USING fts5(recording_id, content, project_id)
            """)
        }
    }
    
    // 高速全文検索
    func searchTranscriptions(query: String) throws -> [SearchResult] {
        return try dbQueue.read { db in
            try SearchResult.fetchAll(db, sql: """
                SELECT recording_id, highlight(transcription_fts, 1, '<mark>', '</mark>') as highlighted_content
                FROM transcription_fts
                WHERE transcription_fts MATCH ?
                ORDER BY bm25(transcription_fts)
            """, arguments: [query])
        }
    }
}
```

## 3. ドメイン層設計

### 3.1 ユースケース設計

#### 3.1.1 録音ユースケース
```swift
protocol RecordingUseCaseProtocol {
    func startRecording(projectId: UUID?, settings: RecordingSettings) async throws -> Recording
    func pauseRecording() async throws
    func resumeRecording() async throws
    func stopRecording() async throws -> Recording
    func deleteRecording(_ recordingId: UUID) async throws
}

class RecordingUseCase: RecordingUseCaseProtocol {
    private let audioService: AudioServiceProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let fileManager: AudioFileManagerProtocol
    
    func startRecording(projectId: UUID?, settings: RecordingSettings) async throws -> Recording {
        // 1. 音声録音開始
        let audioSession = try await audioService.startRecording(settings: settings)
        
        // 2. Recording エンティティ作成
        let recording = Recording(
            id: UUID(),
            title: generateTitle(from: Date()),
            audioFileURL: audioSession.fileURL,
            transcriptionMethod: .local,
            language: settings.language,
            duration: 0,
            audioQuality: settings.quality,
            isFromLimitless: false,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordingMetadata()
        )
        
        // 3. プロジェクトに関連付け
        if let projectId = projectId {
            recording.projectId = projectId
        }
        
        // 4. 保存
        try await recordingRepository.save(recording)
        
        return recording
    }
}
```

#### 3.1.2 文字起こしユースケース
```swift
protocol TranscriptionUseCaseProtocol {
    func transcribeRecording(_ recording: Recording, method: TranscriptionMethod) async throws -> TranscriptionResult
    func retranscribeWithAPI(_ recording: Recording, provider: LLMProvider) async throws -> TranscriptionResult
}

class TranscriptionUseCase: TranscriptionUseCaseProtocol {
    private let whisperKitService: WhisperKitServiceProtocol
    private let apiTranscriptionService: APITranscriptionServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    
    func transcribeRecording(_ recording: Recording, method: TranscriptionMethod) async throws -> TranscriptionResult {
        switch method {
        case .local(let model):
            return try await transcribeLocally(recording, model: model)
        case .api(let provider):
            guard await subscriptionService.hasActiveSubscription() else {
                throw TranscriptionError.subscriptionRequired
            }
            return try await transcribeWithAPI(recording, provider: provider)
        }
    }
    
    private func transcribeLocally(_ recording: Recording, model: WhisperModel) async throws -> TranscriptionResult {
        return try await whisperKitService.transcribe(
            audioURL: recording.audioFileURL,
            model: model,
            language: recording.language
        )
    }
}
```

#### 3.1.3 プロジェクトAIユースケース
```swift
protocol ProjectAIUseCaseProtocol {
    func askAboutProject(_ question: String, project: Project) async throws -> ProjectAIResponse
    func generateProjectSummary(_ project: Project, type: SummaryType) async throws -> String
    func analyzeProjectProgress(_ project: Project) async throws -> ProjectAnalysis
}

class ProjectAIUseCase: ProjectAIUseCaseProtocol {
    private let projectRepository: ProjectRepositoryProtocol
    private let llmService: LLMServiceProtocol
    private let ragService: RAGServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    
    func askAboutProject(_ question: String, project: Project) async throws -> ProjectAIResponse {
        // 1. サブスクリプション確認
        guard await subscriptionService.hasActiveSubscription() else {
            throw ProjectAIError.subscriptionRequired
        }
        
        // 2. プロジェクトコンテキスト構築
        let context = try await buildProjectContext(project)
        
        // 3. RAG検索（プロジェクト内のみ）
        let searchResults = try await ragService.searchInProject(
            query: question,
            projectId: project.id,
            limit: 10
        )
        
        // 4. プロンプト構築
        let prompt = buildAIPrompt(
            question: question,
            context: context,
            searchResults: searchResults
        )
        
        // 5. LLM呼び出し
        let response = try await llmService.generateResponse(
            prompt: prompt,
            provider: getUserPreferredProvider()
        )
        
        return ProjectAIResponse(
            answer: response.text,
            sources: searchResults.map { ProjectSource(from: $0) },
            projectStats: ProjectStats(from: context)
        )
    }
}
```

### 3.2 Repository パターン
```swift
protocol ProjectRepositoryProtocol {
    func save(_ project: Project) async throws
    func findById(_ id: UUID) async throws -> Project?
    func findAll() async throws -> [Project]
    func delete(_ id: UUID) async throws
    func findByIds(_ ids: [UUID]) async throws -> [Project]
}

protocol RecordingRepositoryProtocol {
    func save(_ recording: Recording) async throws
    func findById(_ id: UUID) async throws -> Recording?
    func findByProjectId(_ projectId: UUID) async throws -> [Recording]
    func delete(_ id: UUID) async throws
    func search(query: String) async throws -> [Recording]
}
```

## 4. インフラストラクチャ層設計

### 4.1 音声録音サービス
```swift
protocol AudioServiceProtocol {
    func startRecording(settings: RecordingSettings) async throws -> AudioSession
    func pauseRecording() async throws
    func resumeRecording() async throws  
    func stopRecording() async throws -> URL
    func getCurrentLevel() -> Float
}

class AudioService: AudioServiceProtocol {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession
    
    func startRecording(settings: RecordingSettings) async throws -> AudioSession {
        // 1. オーディオセッション設定
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        // 2. 録音設定
        let recordingSettings = buildRecordingSettings(from: settings)
        
        // 3. ファイルURL生成
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        // 4. 録音開始
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: recordingSettings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        
        return AudioSession(fileURL: audioFilename, startTime: Date())
    }
    
    private func buildRecordingSettings(from settings: RecordingSettings) -> [String: Any] {
        var recordingSettings: [String: Any] = [:]
        
        recordingSettings[AVFormatIDKey] = Int(kAudioFormatMPEG4AAC)
        recordingSettings[AVEncoderAudioQualityKey] = settings.quality.avQuality
        recordingSettings[AVEncoderBitRateKey] = settings.quality.bitRate
        recordingSettings[AVNumberOfChannelsKey] = 1
        
        switch settings.quality {
        case .high:
            recordingSettings[AVSampleRateKey] = 44100.0
        case .standard:
            recordingSettings[AVSampleRateKey] = 22050.0
        case .low:
            recordingSettings[AVSampleRateKey] = 16000.0
        }
        
        return recordingSettings
    }
}
```

### 4.2 WhisperKit サービス
```swift
protocol WhisperKitServiceProtocol {
    func transcribe(audioURL: URL, model: WhisperModel, language: String) async throws -> TranscriptionResult
    func downloadModel(_ model: WhisperModel) async throws
    func getAvailableModels() -> [WhisperModel]
}

class WhisperKitService: WhisperKitServiceProtocol {
    private var whisperKit: WhisperKit?
    
    func transcribe(audioURL: URL, model: WhisperModel, language: String) async throws -> TranscriptionResult {
        // 1. モデル初期化
        if whisperKit == nil {
            whisperKit = try await WhisperKit(model: model.modelName)
        }
        
        // 2. 音声ファイル読み込み
        let audioData = try await loadAudioData(from: audioURL)
        
        // 3. 文字起こし実行
        let result = try await whisperKit?.transcribe(audioData: audioData, language: language)
        
        // 4. 結果変換
        return TranscriptionResult(
            text: result?.text ?? "",
            language: result?.language ?? language,
            segments: result?.segments.map { segment in
                TranscriptionSegment(
                    text: segment.text,
                    startTime: segment.start,
                    endTime: segment.end,
                    confidence: segment.confidence
                )
            } ?? []
        )
    }
    
    private func loadAudioData(from url: URL) async throws -> [Float] {
        // AVAudioFile を使用して音声データを Float 配列に変換
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(file.length))!
        
        try file.read(into: buffer)
        
        let floatArray = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        return floatArray
    }
}
```

### 4.3 LLM API サービス
```swift
protocol LLMServiceProtocol {
    func generateResponse(prompt: String, provider: LLMProvider) async throws -> LLMResponse
    func validateAPIKey(_ key: String, provider: LLMProvider) async throws -> Bool
}

class LLMService: LLMServiceProtocol {
    private let apiKeyManager: APIKeyManagerProtocol
    private let usageTracker: APIUsageTrackerProtocol
    
    func generateResponse(prompt: String, provider: LLMProvider) async throws -> LLMResponse {
        // 1. APIキー取得
        guard let apiKey = try await apiKeyManager.getAPIKey(for: provider) else {
            throw LLMError.apiKeyNotSet
        }
        
        // 2. プロバイダー別実装
        let response: LLMResponse
        switch provider {
        case .openAI(let model):
            response = try await callOpenAI(prompt: prompt, model: model, apiKey: apiKey)
        case .gemini(let model):
            response = try await callGemini(prompt: prompt, model: model, apiKey: apiKey)
        case .anthropic(let model):
            response = try await callClaude(prompt: prompt, model: model, apiKey: apiKey)
        }
        
        // 3. 使用量トラッキング
        await usageTracker.trackUsage(
            provider: provider,
            tokens: response.tokenUsage,
            cost: response.estimatedCost
        )
        
        return response
    }
    
    private func callOpenAI(prompt: String, model: OpenAIModel, apiKey: String) async throws -> LLMResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = OpenAIRequest(
            model: model.rawValue,
            messages: [
                OpenAIMessage(role: "user", content: prompt)
            ],
            temperature: 0.7
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        return LLMResponse(
            text: response.choices.first?.message.content ?? "",
            tokenUsage: TokenUsage(
                promptTokens: response.usage.promptTokens,
                completionTokens: response.usage.completionTokens,
                totalTokens: response.usage.totalTokens
            ),
            provider: .openAI(model),
            estimatedCost: calculateOpenAICost(usage: response.usage, model: model)
        )
    }
}
```

### 4.4 APIキー管理サービス
```swift
protocol APIKeyManagerProtocol {
    func saveAPIKey(_ key: String, for provider: LLMProvider) async throws
    func getAPIKey(for provider: LLMProvider) async throws -> String?
    func deleteAPIKey(for provider: LLMProvider) async throws
    func validateAPIKey(_ key: String, for provider: LLMProvider) async throws -> Bool
}

class APIKeyManager: APIKeyManagerProtocol {
    private let keychain = Keychain(service: "com.noteai.apikeys")
        .synchronizable(false)
        .accessibility(.whenUnlockedThisDeviceOnly)
    
    func saveAPIKey(_ key: String, for provider: LLMProvider) async throws {
        // 1. APIキー検証
        guard try await validateAPIKey(key, for: provider) else {
            throw APIKeyError.invalidKey
        }
        
        // 2. Keychain保存
        let keyIdentifier = provider.keychainIdentifier
        try keychain.set(key, key: keyIdentifier)
        
        // 3. 保存成功をUserDefaultsに記録（存在確認用）
        UserDefaults.standard.set(true, forKey: "hasAPIKey_\(keyIdentifier)")
    }
    
    func getAPIKey(for provider: LLMProvider) async throws -> String? {
        let keyIdentifier = provider.keychainIdentifier
        return try keychain.getString(keyIdentifier)
    }
    
    func validateAPIKey(_ key: String, for provider: LLMProvider) async throws -> Bool {
        switch provider {
        case .openAI:
            return try await validateOpenAIKey(key)
        case .gemini:
            return try await validateGeminiKey(key)
        case .anthropic:
            return try await validateClaudeKey(key)
        }
    }
    
    private func validateOpenAIKey(_ key: String) async throws -> Bool {
        // 簡易テストリクエストを送信してAPIキーの有効性を確認
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
```

### 4.5 使用量トラッキングサービス
```swift
protocol APIUsageTrackerProtocol {
    func trackUsage(provider: LLMProvider, tokens: TokenUsage?, cost: Double?) async
    func getMonthlyUsage(for provider: LLMProvider) async throws -> MonthlyUsage
    func getTotalMonthlyCost() async throws -> Double
    func checkUsageLimit(for provider: LLMProvider) async throws -> UsageLimitStatus
}

class APIUsageTracker: APIUsageTrackerProtocol {
    private let repository: APIUsageRepositoryProtocol
    private let notificationCenter: NotificationCenter
    
    func trackUsage(provider: LLMProvider, tokens: TokenUsage?, cost: Double?) async {
        let usage = APIUsage(
            id: UUID(),
            provider: provider,
            date: Date(),
            tokenUsage: tokens,
            estimatedCost: cost ?? 0,
            requestCount: 1
        )
        
        do {
            try await repository.save(usage)
            
            // 使用量制限チェック
            let limitStatus = try await checkUsageLimit(for: provider)
            if limitStatus.shouldAlert {
                await sendUsageAlert(provider: provider, status: limitStatus)
            }
        } catch {
            print("Failed to track usage: \(error)")
        }
    }
    
    func getMonthlyUsage(for provider: LLMProvider) async throws -> MonthlyUsage {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        let usages = try await repository.findUsages(
            provider: provider,
            from: startOfMonth,
            to: now
        )
        
        return MonthlyUsage(
            provider: provider,
            totalTokens: usages.reduce(0) { $0 + ($1.tokenUsage?.totalTokens ?? 0) },
            totalCost: usages.reduce(0) { $0 + $1.estimatedCost },
            requestCount: usages.count,
            period: DateInterval(start: startOfMonth, end: now)
        )
    }
    
    private func sendUsageAlert(provider: LLMProvider, status: UsageLimitStatus) async {
        let notification = UsageAlertNotification(
            provider: provider,
            currentUsage: status.currentUsage,
            limit: status.limit,
            percentage: status.percentage
        )
        
        await MainActor.run {
            NotificationCenter.default.post(
                name: .apiUsageAlert,
                object: notification
            )
        }
    }
}
```

## 5. プレゼンテーション層設計

### 5.1 MVVM アーキテクチャ

#### 5.1.1 RecordingViewModel
```swift
@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentRecording: Recording?
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var selectedProject: Project?
    
    private let recordingUseCase: RecordingUseCaseProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private var recordingTimer: Timer?
    private var audioLevelTimer: Timer?
    
    init(recordingUseCase: RecordingUseCaseProtocol, projectRepository: ProjectRepositoryProtocol) {
        self.recordingUseCase = recordingUseCase
        self.projectRepository = projectRepository
    }
    
    func startRecording() async {
        do {
            let settings = RecordingSettings(
                quality: .standard,
                language: "ja"
            )
            
            currentRecording = try await recordingUseCase.startRecording(
                projectId: selectedProject?.id,
                settings: settings
            )
            
            isRecording = true
            startTimers()
            
        } catch {
            // エラーハンドリング
            await showError(error)
        }
    }
    
    func stopRecording() async {
        do {
            guard let recording = try await recordingUseCase.stopRecording() else { return }
            
            isRecording = false
            isPaused = false
            stopTimers()
            
            // 自動文字起こし開始
            await startTranscription(for: recording)
            
        } catch {
            await showError(error)
        }
    }
    
    private func startTimers() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.recordingDuration += 0.1
            }
        }
        
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                // AudioService から音声レベル取得
                // self.audioLevel = await self.audioService.getCurrentLevel()
            }
        }
    }
}
```

#### 5.1.2 ProjectDetailViewModel  
```swift
@MainActor
class ProjectDetailViewModel: ObservableObject {
    @Published var project: Project
    @Published var recordings: [Recording] = []
    @Published var projectSummary: String?
    @Published var isLoadingSummary = false
    @Published var aiResponse: ProjectAIResponse?
    @Published var aiQuestion = ""
    @Published var isProcessingAI = false
    
    private let projectRepository: ProjectRepositoryProtocol
    private let recordingRepository: RecordingRepositoryProtocol
    private let projectAIUseCase: ProjectAIUseCaseProtocol
    
    init(project: Project, 
         projectRepository: ProjectRepositoryProtocol,
         recordingRepository: RecordingRepositoryProtocol,
         projectAIUseCase: ProjectAIUseCaseProtocol) {
        self.project = project
        self.projectRepository = projectRepository
        self.recordingRepository = recordingRepository
        self.projectAIUseCase = projectAIUseCase
        
        Task {
            await loadRecordings()
        }
    }
    
    func askAI() async {
        guard !aiQuestion.isEmpty else { return }
        
        isProcessingAI = true
        defer { isProcessingAI = false }
        
        do {
            aiResponse = try await projectAIUseCase.askAboutProject(aiQuestion, project: project)
            aiQuestion = ""
        } catch {
            await showError(error)
        }
    }
    
    func generateSummary(type: SummaryType) async {
        isLoadingSummary = true
        defer { isLoadingSummary = false }
        
        do {
            projectSummary = try await projectAIUseCase.generateProjectSummary(project, type: type)
        } catch {
            await showError(error)
        }
    }
    
    private func loadRecordings() async {
        do {
            recordings = try await recordingRepository.findByProjectId(project.id)
        } catch {
            await showError(error)
        }
    }
}
```

### 5.2 SwiftUI Views

#### 5.2.1 RecordingView
```swift
struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    @State private var showingProjectPicker = false
    
    var body: some View {
        VStack(spacing: 30) {
            // プロジェクト選択
            projectSelectionSection
            
            // 録音ボタン・状態表示
            recordingControlSection
            
            // 音声レベルインジケーター
            audioLevelIndicator
            
            // 録音一覧
            recordingListSection
        }
        .padding()
        .navigationTitle("録音")
        .sheet(isPresented: $showingProjectPicker) {
            ProjectPickerView(selectedProject: $viewModel.selectedProject)
        }
    }
    
    private var projectSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("録音先プロジェクト")
                .font(.headline)
            
            Button(action: { showingProjectPicker = true }) {
                HStack {
                    if let project = viewModel.selectedProject {
                        Label(project.name, systemImage: "folder.fill")
                    } else {
                        Label("プロジェクトを選択", systemImage: "folder")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var recordingControlSection: some View {
        VStack(spacing: 20) {
            // 録音時間表示
            Text(formatDuration(viewModel.recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(viewModel.isRecording ? .red : .primary)
            
            // 録音制御ボタン
            HStack(spacing: 40) {
                if viewModel.isRecording {
                    // 一時停止ボタン
                    Button(action: { Task { await viewModel.pauseRecording() } }) {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 24))
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    // 停止ボタン
                    Button(action: { Task { await viewModel.stopRecording() } }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                } else {
                    // 録音開始ボタン
                    Button(action: { Task { await viewModel.startRecording() } }) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .frame(width: 80, height: 80)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private var audioLevelIndicator: some View {
        VStack {
            Text("音声レベル")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: viewModel.audioLevel, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForAudioLevel(viewModel.audioLevel)))
                .frame(height: 8)
        }
    }
    
    private func colorForAudioLevel(_ level: Float) -> Color {
        switch level {
        case 0..<0.3: return .green
        case 0.3..<0.7: return .yellow
        default: return .red
        }
    }
}
```

#### 5.2.2 ProjectDetailView
```swift
struct ProjectDetailView: View {
    @StateObject private var viewModel: ProjectDetailViewModel
    @State private var showingAskAI = false
    
    init(project: Project) {
        self._viewModel = StateObject(wrappedValue: 
            DependencyContainer.shared.makeProjectDetailViewModel(project: project)
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // プロジェクトヘッダー
                projectHeaderSection
                
                // AI機能セクション
                aiFeatureSection
                
                // 録音一覧
                recordingsSection
            }
            .padding()
        }
        .navigationTitle(viewModel.project.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAskAI) {
            ProjectAskAIView(viewModel: viewModel)
        }
    }
    
    private var projectHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // プロジェクト統計
            HStack {
                StatCard(title: "録音数", value: "\(viewModel.recordings.count)")
                StatCard(title: "総時間", value: formatTotalDuration(viewModel.recordings))
                StatCard(title: "期間", value: formatDateRange(viewModel.recordings))
            }
            
            // プロジェクト説明
            if let description = viewModel.project.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var aiFeatureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                Text("プロジェクトAI")
                    .font(.headline)
                Spacer()
                
                Button("質問する") {
                    showingAskAI = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            // クイック要約ボタン
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    SummaryButton(title: "全体要約", icon: "doc.text") {
                        Task { await viewModel.generateSummary(type: .overview) }
                    }
                    
                    SummaryButton(title: "進捗確認", icon: "chart.line.uptrend.xyaxis") {
                        Task { await viewModel.generateSummary(type: .timeline) }
                    }
                    
                    SummaryButton(title: "TODO抽出", icon: "checklist") {
                        Task { await viewModel.generateSummary(type: .actionItems) }
                    }
                }
                .padding(.horizontal)
            }
            
            // 要約結果表示
            if let summary = viewModel.projectSummary {
                Text(summary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}
```

## 6. 依存性注入・DI Container

### 6.1 DI Container 設計
```swift
class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Repository Factories
    lazy var projectRepository: ProjectRepositoryProtocol = {
        ProjectRepository(coreDataStack: coreDataStack)
    }()
    
    lazy var recordingRepository: RecordingRepositoryProtocol = {
        RecordingRepository(coreDataStack: coreDataStack)
    }()
    
    // MARK: - Service Factories  
    lazy var audioService: AudioServiceProtocol = {
        AudioService()
    }()
    
    lazy var whisperKitService: WhisperKitServiceProtocol = {
        WhisperKitService()
    }()
    
    lazy var llmService: LLMServiceProtocol = {
        LLMService(
            apiKeyManager: apiKeyManager,
            usageTracker: apiUsageTracker
        )
    }()
    
    lazy var apiKeyManager: APIKeyManagerProtocol = {
        APIKeyManager()
    }()
    
    lazy var apiUsageTracker: APIUsageTrackerProtocol = {
        APIUsageTracker(repository: apiUsageRepository)
    }()
    
    // MARK: - UseCase Factories
    func makeRecordingUseCase() -> RecordingUseCaseProtocol {
        RecordingUseCase(
            audioService: audioService,
            recordingRepository: recordingRepository,
            fileManager: audioFileManager
        )
    }
    
    func makeTranscriptionUseCase() -> TranscriptionUseCaseProtocol {
        TranscriptionUseCase(
            whisperKitService: whisperKitService,
            apiTranscriptionService: apiTranscriptionService,
            subscriptionService: subscriptionService
        )
    }
    
    func makeProjectAIUseCase() -> ProjectAIUseCaseProtocol {
        ProjectAIUseCase(
            projectRepository: projectRepository,
            llmService: llmService,
            ragService: ragService,
            subscriptionService: subscriptionService
        )
    }
    
    // MARK: - ViewModel Factories
    func makeRecordingViewModel() -> RecordingViewModel {
        RecordingViewModel(
            recordingUseCase: makeRecordingUseCase(),
            projectRepository: projectRepository
        )
    }
    
    func makeProjectDetailViewModel(project: Project) -> ProjectDetailViewModel {
        ProjectDetailViewModel(
            project: project,
            projectRepository: projectRepository,
            recordingRepository: recordingRepository,
            projectAIUseCase: makeProjectAIUseCase()
        )
    }
    
    // MARK: - Core Data Stack
    private lazy var coreDataStack: CoreDataStack = {
        CoreDataStack(modelName: "NoteAI")
    }()
}
```

## 7. パフォーマンス・最適化

### 7.1 メモリ管理
```swift
// バックグラウンド録音時のメモリ最適化
class BackgroundAudioManager {
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    func enableBackgroundRecording() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}

// WhisperKit モデルのメモリ効率化
class WhisperKitModelManager {
    private var loadedModel: WhisperKit?
    private let modelCache = NSCache<NSString, WhisperKit>()
    
    func getModel(for type: WhisperModel) async throws -> WhisperKit {
        let cacheKey = NSString(string: type.modelName)
        
        if let cachedModel = modelCache.object(forKey: cacheKey) {
            return cachedModel
        }
        
        let model = try await WhisperKit(model: type.modelName)
        modelCache.setObject(model, forKey: cacheKey)
        
        return model
    }
}
```

### 7.2 データベース最適化
```swift
// Core Data パフォーマンス最適化
extension ProjectRepository {
    func findAllWithPrefetch() async throws -> [Project] {
        return try await withContext { context in
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            
            // 関連エンティティを事前読み込み
            request.relationshipKeyPathsForPrefetching = ["recordings", "tags"]
            
            // バッチサイズ設定
            request.fetchBatchSize = 20
            
            let entities = try context.fetch(request)
            return entities.compactMap { Project(from: $0) }
        }
    }
}

// GRDB 検索最適化
class SearchService {
    func performFastSearch(query: String, projectId: UUID?) async throws -> [SearchResult] {
        return try await dbQueue.read { db in
            var sql = """
                SELECT recording_id, 
                       highlight(transcription_fts, 1, '<mark>', '</mark>') as highlighted_content,
                       bm25(transcription_fts) as relevance_score
                FROM transcription_fts
                WHERE transcription_fts MATCH ?
            """
            
            var arguments: [DatabaseValueConvertible] = [query]
            
            if let projectId = projectId {
                sql += " AND project_id = ?"
                arguments.append(projectId.uuidString)
            }
            
            sql += " ORDER BY relevance_score LIMIT 50"
            
            return try SearchResult.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }
}
```

## 8. セキュリティ設計

### 8.1 データ保護
```swift
// ファイル暗号化
class SecureFileManager {
    private let fileManager = FileManager.default
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    func saveSecureAudioFile(_ data: Data, filename: String) throws -> URL {
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        // ファイル保護レベル設定
        try data.write(to: fileURL, options: .completeFileProtection)
        
        // ファイル属性設定
        try fileManager.setAttributes([
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ], ofItemAtPath: fileURL.path)
        
        return fileURL
    }
}

// APIキー暗号化強化
class SecureAPIKeyManager: APIKeyManagerProtocol {
    private let keychain: Keychain
    
    init() {
        self.keychain = Keychain(service: "com.noteai.apikeys")
            .synchronizable(false)
            .accessibility(.whenUnlockedThisDeviceOnly)
            .authenticationPrompt("APIキーにアクセスするため認証が必要です")
    }
    
    func saveAPIKey(_ key: String, for provider: LLMProvider) async throws {
        // 生体認証要求
        let context = LAContext()
        let reason = "APIキーを安全に保存するため認証が必要です"
        
        guard try await context.evaluatePolicy(.biometryAny, localizedReason: reason) else {
            throw APIKeyError.authenticationFailed
        }
        
        // 暗号化保存
        try keychain
            .authenticationPrompt(reason)
            .set(key, key: provider.keychainIdentifier)
    }
}
```

### 8.2 プライバシー保護
```swift
// データ匿名化
class PrivacyManager {
    func anonymizeTranscription(_ text: String) -> String {
        var anonymized = text
        
        // 個人名の匿名化
        let namePattern = #"(?:[A-Z][a-z]+\s+[A-Z][a-z]+)|(?:[ぁ-んァ-ヶ一-龯]{2,4}(?:さん|くん|ちゃん))"#
        anonymized = anonymized.replacingOccurrences(of: namePattern, with: "[NAME]", options: .regularExpression)
        
        // 電話番号の匿名化
        let phonePattern = #"\b\d{2,4}-?\d{2,4}-?\d{3,4}\b"#
        anonymized = anonymized.replacingOccurrences(of: phonePattern, with: "[PHONE]", options: .regularExpression)
        
        // メールアドレスの匿名化
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        anonymized = anonymized.replacingOccurrences(of: emailPattern, with: "[EMAIL]", options: .regularExpression)
        
        return anonymized
    }
}
```

## 9. テスト設計

### 9.1 単体テスト
```swift
// UseCase テスト例
@testable import NoteAI
import XCTest

class RecordingUseCaseTests: XCTestCase {
    var useCase: RecordingUseCase!
    var mockAudioService: MockAudioService!
    var mockRepository: MockRecordingRepository!
    
    override func setUp() {
        super.setUp()
        mockAudioService = MockAudioService()
        mockRepository = MockRecordingRepository()
        useCase = RecordingUseCase(
            audioService: mockAudioService,
            recordingRepository: mockRepository,
            fileManager: MockAudioFileManager()
        )
    }
    
    func testStartRecording_Success() async throws {
        // Given
        let projectId = UUID()
        let settings = RecordingSettings(quality: .standard, language: "ja")
        let expectedURL = URL(string: "file://test.m4a")!
        
        mockAudioService.startRecordingResult = AudioSession(fileURL: expectedURL, startTime: Date())
        
        // When
        let recording = try await useCase.startRecording(projectId: projectId, settings: settings)
        
        // Then
        XCTAssertEqual(recording.audioFileURL, expectedURL)
        XCTAssertEqual(mockRepository.savedRecordings.count, 1)
    }
    
    func testStartRecording_AudioServiceError() async {
        // Given
        let settings = RecordingSettings(quality: .standard, language: "ja")
        mockAudioService.shouldThrowError = true
        
        // When & Then
        do {
            _ = try await useCase.startRecording(projectId: nil, settings: settings)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AudioServiceError)
        }
    }
}
```

### 9.2 統合テスト
```swift
class ProjectAIIntegrationTests: XCTestCase {
    var container: DependencyContainer!
    var projectAIUseCase: ProjectAIUseCaseProtocol!
    
    override func setUp() {
        super.setUp()
        container = DependencyContainer()
        projectAIUseCase = container.makeProjectAIUseCase()
    }
    
    func testProjectAIFlow_EndToEnd() async throws {
        // Given
        let project = try await createTestProject()
        let recordings = try await createTestRecordings(for: project)
        
        // When
        let response = try await projectAIUseCase.askAboutProject(
            "このプロジェクトの主要な決定事項は何ですか？",
            project: project
        )
        
        // Then
        XCTAssertFalse(response.answer.isEmpty)
        XCTAssertFalse(response.sources.isEmpty)
    }
}
```

この技術設計書により、NoteAI iOS アプリの実装に必要な全ての技術的詳細が定義されました。Clean Architecture + MVVM パターンにより、保守性と拡張性の高いアプリケーションを構築できます。