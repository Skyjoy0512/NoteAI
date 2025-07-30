import SwiftUI
import CoreData
import Network

@main
struct NoteAIApp: App {
    let dependencyContainer = DependencyContainer.shared
    
    init() {
        // iOS 26 ベータ版のTLS 1.2対応によるクラッシュ修正
        // URLSession関連のEXC_BREAKPOINTクラッシュを回避
        _ = nw_tls_create_options()
        
        // コマンドライン実行時の動作確認テスト
        #if DEBUG
        if ProcessInfo.processInfo.environment["NOTEAI_CLI_TEST"] == "1" {
            let testPassed = NoteAIAppTest.performBasicTest()
            exit(testPassed ? 0 : 1)
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dependencyContainer.coreDataStack.context)
        }
    }
}