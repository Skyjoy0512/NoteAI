# Serena Integration for NoteAI

SerenaをNoteAIプロジェクトの開発支援ツールとして統合します。

## セットアップ

1. **初期設定**
```bash
cd .serena
./setup.sh
```

2. **Serena環境の有効化**
```bash
source .venv/bin/activate
serena activate --project ..
```

## 使用方法

### コード生成
```bash
# 新しいSwiftUIビューを生成
serena generate view AudioPlayerView

# Core Dataエンティティを生成
serena generate entity Recording
```

### リファクタリング
```bash
# コードの最適化
serena refactor optimize Sources/NoteAI/Infrastructure/Services/AudioService.swift

# アーキテクチャパターンの適用
serena refactor pattern mvvm Sources/NoteAI/Presentation/
```

### テスト生成
```bash
# ユニットテストの自動生成
serena test generate Sources/NoteAI/Domain/UseCases/TranscriptionUseCase.swift

# UIテストの作成
serena test ui Sources/NoteAI/Presentation/Views/RecordingView.swift
```

### AI支援開発
```bash
# コードレビュー
serena review Sources/NoteAI/

# ドキュメント生成
serena docs generate

# バグ検出
serena analyze bugs
```

## プロジェクト固有の機能

### 音声処理の最適化
```bash
# WhisperKit統合の改善
serena optimize audio-processing

# 話者分離アルゴリズムの最適化
serena optimize speaker-diarization
```

### SwiftUI最適化
```bash
# パフォーマンス分析
serena analyze performance Sources/NoteAI/Presentation/Views/

# ビューの最適化提案
serena suggest optimizations
```

## ベストプラクティス

1. **定期的なコード分析**
   - 毎日の開発開始時に`serena analyze`を実行

2. **AIペアプログラミング**
   - 複雑な機能実装時は`serena assist`モードを使用

3. **継続的な改善**
   - `serena learn`でプロジェクト固有のパターンを学習

## トラブルシューティング

- **LSPエラー**: `sourcekit-lsp`が正しくインストールされているか確認
- **インデックスエラー**: `serena index rebuild`でインデックスを再構築
- **AI接続エラー**: APIキーが正しく設定されているか確認