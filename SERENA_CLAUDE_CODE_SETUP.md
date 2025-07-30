# Serena + Claude Code セットアップガイド

SerenaをClaude Codeで使用してNoteAIプロジェクトの開発効率を向上させる方法。

## 概要

Serena MCPサーバーを使用すると、Claude Codeに以下の高度な機能が追加されます：
- セマンティックコード分析（LSPベース）
- シンボルレベルでの正確なコード編集
- プロジェクト固有の記憶システム
- 効率的なコードナビゲーション

## セットアップ手順

### 1. 前提条件
- Python 3.11以上がインストールされていること
- uvパッケージマネージャーがインストールされていること
- Claude Codeがインストールされていること

### 2. Serenaのインストール

```bash
# uvのインストール（未インストールの場合）
curl -LsSf https://astral.sh/uv/install.sh | sh

# パスを通す
export PATH="$HOME/.local/bin:$PATH"
```

### 3. Claude CodeでSerenaを追加

NoteAIプロジェクトディレクトリで以下を実行：

```bash
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant --project $(pwd)
```

### 4. 使用開始

Claude Codeで新しい会話を開始し、以下のコマンドを実行：

```
/mcp__serena__initial_instructions
```

これによりSerenaの使い方がClaude Codeに読み込まれます。

## 主な機能

### プロジェクトの有効化
```
Activate the project NoteAI
```

### シンボル検索
```
Find all Swift classes that implement AudioProcessing
```

### 正確なコード編集
```
Replace the body of processAudio function with optimized implementation
```

### プロジェクト記憶
```
Write a memory about the audio processing architecture
```

### コード分析
```
Get symbols overview for Sources/NoteAI/Infrastructure/Services/
```

## NoteAI開発での活用例

### 1. 音声処理機能の改善
- WhisperKitServiceの最適化
- 話者分離アルゴリズムの実装
- リアルタイム処理の追加

### 2. SwiftUIビューの生成
- 新しいビューコンポーネントの作成
- 既存ビューのリファクタリング
- パフォーマンス最適化

### 3. テストの自動生成
- ユニットテストの作成
- 統合テストの実装
- テストカバレッジの向上

### 4. アーキテクチャの改善
- Clean Architectureパターンの適用
- 依存性注入の実装
- モジュール分割の最適化

## ベストプラクティス

1. **プロジェクトのインデックス作成**
   ```bash
   uvx --from git+https://github.com/oraios/serena index-project
   ```

2. **定期的な記憶の更新**
   - 重要な設計決定を記憶として保存
   - アーキテクチャの変更を記録

3. **効率的なコンテキスト管理**
   - 長いタスクは新しい会話で継続
   - `prepare_for_new_conversation`ツールを使用

4. **セマンティック操作の活用**
   - テキストベースではなくシンボルベースの編集
   - リファクタリング時の正確性向上

## トラブルシューティング

### Python バージョンエラー
macOSの場合、Homebrewで最新のPythonをインストール：
```bash
brew install python@3.11
```

### MCP サーバーが起動しない
Claude Codeを完全に終了して再起動（システムトレイも確認）

### ツールが表示されない
`/mcp__serena__initial_instructions`を再実行

## 参考リンク

- [Serena GitHub](https://github.com/oraios/serena)
- [Claude Code Documentation](https://claude.ai/code)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## まとめ

SerenaをClaude Codeと組み合わせることで、NoteAIプロジェクトの開発効率を大幅に向上させることができます。特に大規模なコードベースでの作業や、複雑なリファクタリングタスクで威力を発揮します。