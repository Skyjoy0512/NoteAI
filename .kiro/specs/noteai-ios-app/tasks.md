# NoteAI iOS App - 実装タスク

## 開発フェーズ概要

### Phase 1: プロジェクトセットアップ・基盤構築 (2週間)
### Phase 2: 基本録音・文字起こし機能 (2週間)  
### Phase 3: プロジェクト管理・UI実装 (2週間)
### Phase 4: 有料機能・API統合 (3週間)
### Phase 5: 高度なAI・RAG機能 (2週間)
### Phase 6: 最適化・リリース準備 (1週間)

---

## Phase 1: プロジェクトセットアップ・基盤構築 (2週間)

### 1.1 プロジェクト初期化
- [ ] Xcodeプロジェクト作成（iOS 16.0+対応）
- [ ] Package.swift設定・依存関係追加
  - [ ] WhisperKit (0.5.0+)
  - [ ] Alamofire (5.8.0+)
  - [ ] GRDB.swift (6.0.0+)
  - [ ] RevenueCat (4.0.0+)
  - [ ] Firebase iOS SDK (10.0.0+)
  - [ ] Down (0.11.0+)
- [ ] プロジェクト構造作成（Clean Architecture準拠）
  - [ ] App/ フォルダ
  - [ ] Presentation/ フォルダ
  - [ ] Domain/ フォルダ
  - [ ] Infrastructure/ フォルダ
  - [ ] Resources/ フォルダ

### 1.2 Core Data セットアップ
- [ ] NoteAI.xcdatamodeld作成
- [ ] ProjectEntity実装
  - [ ] id: UUID
  - [ ] name: String
  - [ ] description: String?
  - [ ] coverImageData: Data?
  - [ ] createdAt, updatedAt: Date
  - [ ] metadata: Data? (JSON)
- [ ] RecordingEntity実装
  - [ ] id: UUID
  - [ ] title: String
  - [ ] audioFileURL: String
  - [ ] transcription: String?
  - [ ] transcriptionMethod: String
  - [ ] duration: Double
  - [ ] language: String
  - [ ] createdAt, updatedAt: Date
- [ ] SubscriptionEntity実装
- [ ] APIUsageEntity実装
- [ ] RecordingSegmentEntity実装
- [ ] CoreDataStack実装

### 1.3 GRDB セットアップ
- [ ] AnalyticsDatabase実装
- [ ] 全文検索インデックス作成
- [ ] 検索機能の基盤実装

### 1.4 DI Container 実装
- [ ] DependencyContainer基本構造
- [ ] Repository factories
- [ ] Service factories
- [ ] UseCase factories
- [ ] ViewModel factories

### 1.5 基本ドメインモデル
- [ ] Project struct実装
- [ ] Recording struct実装
- [ ] TranscriptionResult struct実装
- [ ] AudioQuality enum実装
- [ ] TranscriptionMethod enum実装
- [ ] LLMProvider enum実装

---

## Phase 2: 基本録音・文字起こし機能 (2週間)

### 2.1 音声録音サービス実装
- [ ] AudioServiceProtocol定義
- [ ] AudioService実装
  - [ ] AVAudioSession設定
  - [ ] AVAudioRecorder統合
  - [ ] バックグラウンド録音対応
  - [ ] 音声レベル監視
  - [ ] 録音品質設定（高/標準/低）
- [ ] AudioFileManager実装
  - [ ] ファイル保存・管理
  - [ ] セキュアファイル保存
  - [ ] ファイル暗号化

### 2.2 WhisperKit 統合
- [ ] WhisperKitServiceProtocol定義
- [ ] WhisperKitService実装
  - [ ] モデル初期化・管理
  - [ ] 音声データ変換（Float配列）
  - [ ] 文字起こし実行
  - [ ] 多言語対応（日本語、英語）
  - [ ] モデルサイズ選択（tiny/base/small）
- [ ] WhisperKitModelManager実装
  - [ ] モデルキャッシュ管理
  - [ ] メモリ最適化

### 2.3 録音ユースケース実装
- [ ] RecordingUseCaseProtocol定義
- [ ] RecordingUseCase実装
  - [ ] 録音開始・停止・一時停止
  - [ ] 録音ファイル管理
  - [ ] メタデータ保存
  - [ ] プロジェクト関連付け

### 2.4 文字起こしユースケース実装
- [ ] TranscriptionUseCaseProtocol定義
- [ ] TranscriptionUseCase実装
  - [ ] ローカル文字起こし実行
  - [ ] 結果保存・更新
  - [ ] エラーハンドリング

### 2.5 Repository実装
- [ ] ProjectRepositoryProtocol定義
- [ ] ProjectRepository実装
- [ ] RecordingRepositoryProtocol定義  
- [ ] RecordingRepository実装
- [ ] Core Data CRUD操作
- [ ] 非同期データアクセス

### 2.6 基本UI実装
- [ ] RecordingView基本構造
- [ ] 録音ボタン・制御UI
- [ ] 録音時間表示
- [ ] 音声レベルインジケーター
- [ ] RecordingViewModel実装

---

## Phase 3: プロジェクト管理・UI実装 (2週間)

### 3.1 プロジェクト管理機能
- [ ] ProjectServiceProtocol定義
- [ ] ProjectService実装
  - [ ] プロジェクト作成・編集・削除
  - [ ] 録音のプロジェクト割り当て
  - [ ] プロジェクト統計生成
  - [ ] プロジェクトコンテキスト構築

### 3.2 プロジェクト関連UI
- [ ] ProjectListView実装
  - [ ] プロジェクト一覧表示
  - [ ] グリッドレイアウト
  - [ ] 新規プロジェクト作成ボタン
- [ ] ProjectCard実装
  - [ ] カバー画像表示
  - [ ] プロジェクト統計表示
- [ ] CreateProjectView実装
  - [ ] プロジェクト名・説明入力
  - [ ] カバー画像設定
- [ ] ProjectDetailView実装
  - [ ] プロジェクト情報表示
  - [ ] 録音一覧表示
  - [ ] プロジェクト編集機能

### 3.3 録音一覧・管理UI
- [ ] RecordingListView実装
- [ ] RecordingRow実装
  - [ ] 録音情報表示
  - [ ] 再生ボタン
  - [ ] 文字起こし状況表示
- [ ] RecordingDetailView実装
  - [ ] 音声再生機能
  - [ ] 文字起こし結果表示・編集
  - [ ] メタデータ表示

### 3.4 検索機能実装
- [ ] SearchServiceProtocol定義
- [ ] SearchService実装（GRDB使用）
- [ ] SearchView実装
- [ ] 全文検索機能
- [ ] フィルタ機能（日付、プロジェクト）

### 3.5 ナビゲーション・TabView
- [ ] MainTabView実装
- [ ] タブ構成（録音、プロジェクト、検索、設定）
- [ ] ナビゲーション構造

### 3.6 基本設定画面
- [ ] SettingsView実装
- [ ] アプリ設定（録音品質、言語）
- [ ] プライバシー設定

---

## Phase 4: 有料機能・API統合 (3週間)

### 4.1 課金システム実装
- [ ] RevenueCat統合
- [ ] SubscriptionServiceProtocol定義
- [ ] SubscriptionService実装
  - [ ] 課金状態管理
  - [ ] レシート検証
  - [ ] 課金復元機能
- [ ] SubscriptionView実装
  - [ ] 料金プラン表示
  - [ ] 購入フロー
  - [ ] 利用規約・プライバシーポリシー

### 4.2 APIキー管理システム
- [ ] APIKeyManagerProtocol定義
- [ ] APIKeyManager実装
  - [ ] Keychain統合
  - [ ] 生体認証連携
  - [ ] APIキー検証
- [ ] APIKeySettingsView実装
  - [ ] プロバイダー別設定
  - [ ] APIキー入力・保存
  - [ ] 使用量表示
- [ ] APIKeyGuideView実装
  - [ ] プロバイダー別取得ガイド
  - [ ] 設定手順説明

### 4.3 LLM API サービス実装
- [ ] LLMServiceProtocol定義
- [ ] LLMService実装
  - [ ] OpenAI API統合
  - [ ] Google Gemini API統合
  - [ ] Anthropic Claude API統合
  - [ ] プロバイダー切り替え
  - [ ] エラーハンドリング
- [ ] API別実装
  - [ ] callOpenAI実装
  - [ ] callGemini実装
  - [ ] callClaude実装

### 4.4 使用量トラッキング
- [ ] APIUsageTrackerProtocol定義
- [ ] APIUsageTracker実装
  - [ ] リアルタイム使用量記録
  - [ ] コスト計算
  - [ ] 月次集計
  - [ ] 使用量制限チェック
- [ ] UsageMonitorView実装
  - [ ] 使用量グラフ表示
  - [ ] コスト予測
  - [ ] アラート設定

### 4.5 API文字起こし機能
- [ ] APITranscriptionServiceProtocol定義
- [ ] APITranscriptionService実装
- [ ] Whisper API統合
- [ ] 高精度文字起こし
- [ ] 話者分離（API経由）

### 4.6 基本AI機能
- [ ] AIServiceProtocol定義
- [ ] AIService実装
- [ ] 要約機能実装
- [ ] キーワード抽出
- [ ] 基本的な分析機能

---

## Phase 5: 高度なAI・RAG機能 (2週間)

### 5.1 プロジェクトAI機能
- [ ] ProjectAIUseCaseProtocol定義
- [ ] ProjectAIUseCase実装
  - [ ] プロジェクト横断分析
  - [ ] 統合コンテキスト構築
  - [ ] 質問応答システム
  - [ ] 時系列分析
- [ ] ProjectAskAIView実装
  - [ ] チャット形式UI
  - [ ] 質問入力・回答表示
  - [ ] ソース表示
  - [ ] クイックアクション

### 5.2 RAG機能実装
- [ ] RAGServiceProtocol定義
- [ ] RAGService実装
  - [ ] ベクトル検索
  - [ ] セマンティック検索
  - [ ] 関連性スコアリング
- [ ] ドキュメント統合機能
  - [ ] PDF読み込み
  - [ ] Word文書読み込み
  - [ ] Webページ取り込み
- [ ] 知識ベース管理
  - [ ] プロジェクト固有知識蓄積
  - [ ] 統合検索機能

### 5.3 高度な分析機能
- [ ] ProjectAnalysisService実装
- [ ] 進捗追跡機能
- [ ] アクションアイテム抽出
- [ ] 決定事項分析
- [ ] 感情分析

### 5.4 エクスポート機能
- [ ] ExportServiceProtocol定義
- [ ] ExportService実装
  - [ ] PDF出力
  - [ ] Markdown出力
  - [ ] 音声ファイル書き出し
  - [ ] レポート生成

### 5.5 Limitless連携
- [ ] LimitlessAPIService実装
- [ ] Pendantデバイス連携
- [ ] 自動録音開始
- [ ] メタデータ統合

---

## Phase 6: 最適化・リリース準備 (1週間)

### 6.1 パフォーマンス最適化
- [ ] メモリ使用量最適化
- [ ] バッテリー消費最適化
- [ ] データベースクエリ最適化
- [ ] 画像キャッシュ最適化
- [ ] バックグラウンド処理最適化

### 6.2 UIポリッシュ
- [ ] アニメーション実装
- [ ] ダークモード対応
- [ ] アクセシビリティ対応
- [ ] Dynamic Type対応
- [ ] 多言語対応（日本語・英語）

### 6.3 エラーハンドリング・ログ
- [ ] エラー画面実装
- [ ] ログシステム実装
- [ ] クラッシュレポート統合
- [ ] ユーザーフィードバック機能

### 6.4 テスト実装
- [ ] 単体テスト
  - [ ] UseCaseテスト
  - [ ] Serviceテスト
  - [ ] ViewModelテスト
- [ ] 統合テスト
  - [ ] API統合テスト
  - [ ] データフローテスト
- [ ] UIテスト
  - [ ] 録音フローテスト
  - [ ] プロジェクト作成テスト
  - [ ] AI機能テスト

### 6.5 セキュリティ監査
- [ ] APIキー保存セキュリティチェック
- [ ] ファイル暗号化検証
- [ ] 通信セキュリティ確認
- [ ] プライバシー保護検証

### 6.6 App Store準備
- [ ] App Store Connectセットアップ
- [ ] アプリアイコン作成
- [ ] スクリーンショット作成
- [ ] App Store説明文作成
- [ ] プライバシー情報設定
- [ ] TestFlight配信
- [ ] App Store申請

---

## 追加・継続的タスク

### セキュリティ・プライバシー
- [ ] データ匿名化機能実装
- [ ] プライバシー設定詳細化
- [ ] GDPR準拠確認
- [ ] セキュリティ監査実施

### ユーザーエクスペリエンス向上
- [ ] オンボーディング実装
- [ ] チュートリアル作成
- [ ] ヘルプ・FAQ実装
- [ ] ユーザーフィードバック収集

### 監視・分析
- [ ] Firebase Analytics統合
- [ ] パフォーマンス監視
- [ ] クラッシュ率監視
- [ ] ユーザー行動分析

### 将来的な拡張
- [ ] iPad対応準備
- [ ] Apple Watch連携検討
- [ ] Siri Shortcuts対応
- [ ] ウィジェット機能拡張

---

## 開発マイルストーン

### マイルストーン 1 (2週間後)
- [ ] プロジェクトセットアップ完了
- [ ] 基本データモデル実装完了
- [ ] DI Container動作確認

### マイルストーン 2 (4週間後)  
- [ ] 基本録音機能動作
- [ ] ローカル文字起こし動作
- [ ] 基本UI実装完了

### マイルストーン 3 (6週間後)
- [ ] プロジェクト管理機能完了
- [ ] 検索機能実装完了
- [ ] 無料版機能完成

### マイルストーン 4 (9週間後)
- [ ] 課金システム統合完了
- [ ] API統合完了
- [ ] 有料版機能実装完了

### マイルストーン 5 (11週間後)
- [ ] 高度なAI機能完了
- [ ] RAG機能実装完了
- [ ] 全機能統合完了

### マイルストーン 6 (12週間後)
- [ ] 最適化・テスト完了
- [ ] App Store申請準備完了
- [ ] リリース可能状態

---

## 優先度・依存関係

### High Priority (必須機能)
1. 基本録音機能
2. ローカル文字起こし
3. プロジェクト管理
4. 課金システム
5. APIキー管理

### Medium Priority (重要機能)
1. API統合
2. プロジェクトAI
3. 検索機能
4. エクスポート機能

### Low Priority (拡張機能)
1. RAG機能
2. Limitless連携
3. 高度な分析
4. 多言語対応

### 技術的依存関係
- Core Data → Repository → UseCase → ViewModel
- AudioService → RecordingUseCase → RecordingView
- APIKeyManager → LLMService → ProjectAI
- SubscriptionService → 有料機能全般

この実装タスクにより、段階的かつ効率的にNoteAI iOS アプリを開発し、高品質なプロダクトをリリースできます。