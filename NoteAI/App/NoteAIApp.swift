import SwiftUI
import CoreData

@main
struct NoteAIApp: App {
    let dependencyContainer = DependencyContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dependencyContainer.coreDataStack.context)
        }
    }
}