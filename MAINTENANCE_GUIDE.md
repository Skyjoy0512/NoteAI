# NoteAI開発環境メンテナンスガイド

## 定期実行推奨スクリプト

### 1. Core Dataバックアップ（毎日推奨）
```bash
./scripts/backup-coredata.sh
```
- Core Dataモデルファイルの自動バックアップ
- エンティティファイルも含めて保存
- 30日以上前の古いバックアップを自動削除

### 2. Xcode環境健康状態チェック（週1回推奨）
```bash
./scripts/monitor-xcode-health.sh
```
- 現在のXcode設定確認
- Core Dataモデルファイル整合性検証
- クラッシュログ監視
- プロジェクトビルド可能性チェック

### 3. 開発環境切り替え（必要に応じて）
```bash
# 安定版に切り替え（推奨）
./scripts/xcode-switch.sh stable

# ベータ版でテスト（注意）
./scripts/xcode-switch.sh beta

# 環境クリーンアップ
./scripts/xcode-switch.sh clean
```

## 自動化設定（推奨）

### crontabでの自動実行
```bash
# crontabを編集
crontab -e

# 以下を追加:
# 毎日午前2時にCore Dataバックアップ
0 2 * * * /Users/hashimotokenichi/Desktop/NoteAI/scripts/backup-coredata.sh

# 毎週月曜日午前3時に健康状態チェック  
0 3 * * 1 /Users/hashimotokenichi/Desktop/NoteAI/scripts/monitor-xcode-health.sh
```

## クラッシュ発生時の対応手順

### 即座実行
1. **安全な環境に切り替え**
   ```bash
   ./scripts/xcode-switch.sh stable
   ```

2. **環境クリーンアップ**
   ```bash
   ./scripts/xcode-switch.sh clean
   ```

3. **Core Dataバックアップ確認**
   ```bash
   ls -la ~/Desktop/NoteAI-Backups/CoreData/
   ```

### トラブルシューティング
1. **Core Dataモデル復旧**
   ```bash
   # 最新のバックアップから復旧
   cp -R ~/Desktop/NoteAI-Backups/CoreData/NoteAI.xcdatamodeld_YYYYMMDD_HHMMSS/* \
         Sources/NoteAI/Resources/NoteAI.xcdatamodeld/
   ```

2. **完全環境リセット**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   swift package clean
   rm -rf .build .swiftpm
   swift package resolve
   ```

## 監視指標

### 正常状態の基準
- ✅ Core DataモデルXMLが有効
- ✅ エンティティ数: 6個
- ✅ 過去7日間のXcodeクラッシュ: 0件
- ✅ Swift Package依存関係解決成功

### 警告レベル
- ⚠️ 過去7日間のXcodeクラッシュ: 1-2件
- ⚠️ DerivedDataサイズ > 10GB

### 危険レベル
- ❌ Core DataモデルXMLエラー
- ❌ エンティティ数異常
- ❌ 過去7日間のXcodeクラッシュ: 3件以上
- ❌ Swift Packageビルド失敗

## 緊急連絡先
- **Apple Developer Support**: https://developer.apple.com/support/
- **Feedback Assistant**: Xcodeクラッシュレポート提出用
- **プロジェクトバックアップ**: ~/Desktop/NoteAI-Backups/

## ファイル構成
```
NoteAI/
├── scripts/
│   ├── backup-coredata.sh       # Core Dataバックアップ
│   ├── monitor-xcode-health.sh  # 健康状態監視
│   └── xcode-switch.sh          # Xcode環境切り替え
├── XCODE_USAGE_GUIDE.md         # Xcode使い分けガイド
├── CRASH_REPORT_SUMMARY.md      # クラッシュレポート概要
└── MAINTENANCE_GUIDE.md         # このファイル
```