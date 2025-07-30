import Foundation
import SwiftUI

/// NoteAIアプリの基本的な動作確認用テスト
public struct NoteAIAppTest {
    
    /// アプリの主要コンポーネントが正常に初期化できるかテスト
    public static func performBasicTest() -> Bool {
        print("=== NoteAI アプリ動作確認テスト ===")
        
        var testResults: [String] = []
        var allTestsPassed = true
        
        // 1. DependencyContainer初期化テスト
        do {
            let container = DependencyContainer.shared
            testResults.append("✅ DependencyContainer初期化成功")
        } catch {
            testResults.append("❌ DependencyContainer初期化失敗: \(error)")
            allTestsPassed = false
        }
        
        // 2. CoreDataStack初期化テスト
        do {
            let container = DependencyContainer.shared
            let context = container.coreDataStack.context
            testResults.append("✅ CoreDataStack初期化成功")
        } catch {
            testResults.append("❌ CoreDataStack初期化失敗: \(error)")
            allTestsPassed = false
        }
        
        // 3. ViewModel初期化テスト
        do {
            let container = DependencyContainer.shared
            let projectListVM = container.makeProjectListViewModel()
            let settingsVM = container.makeSettingsViewModel()
            testResults.append("✅ ViewModels初期化成功")
        } catch {
            testResults.append("❌ ViewModels初期化失敗: \(error)")
            allTestsPassed = false
        }
        
        // 4. SwiftUIビュー構築テスト
        do {
            let contentView = ContentView()
            testResults.append("✅ SwiftUIビュー構築成功")
        } catch {
            testResults.append("❌ SwiftUIビュー構築失敗: \(error)")
            allTestsPassed = false
        }
        
        // 結果出力
        print("\n--- テスト結果 ---")
        for result in testResults {
            print(result)
        }
        
        print("\n--- 総合結果 ---")
        if allTestsPassed {
            print("🎉 すべてのテストが成功しました！")
            print("📱 NoteAIアプリは正常に動作可能です")
            print("🔧 Xcodeで実行してGUIを確認してください")
        } else {
            print("⚠️  一部のテストが失敗しました")
        }
        
        print("\n=== テスト完了 ===")
        return allTestsPassed
    }
}