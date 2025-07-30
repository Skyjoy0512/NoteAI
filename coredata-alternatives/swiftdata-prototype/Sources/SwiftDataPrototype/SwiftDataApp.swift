import SwiftUI
import SwiftData

@main
public struct SwiftDataPrototypeApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Project.self, Recording.self, RecordingSegment.self, Tag.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    
    var body: some View {
        NavigationView {
            VStack {
                Text("SwiftData Prototype")
                    .font(.title)
                    .padding()
                
                List(projects) { project in
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        if let description = project.projectDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button("Add Sample Project") {
                    let project = Project(name: "Sample Project", projectDescription: "SwiftData test project")
                    modelContext.insert(project)
                    
                    try? modelContext.save()
                }
                .padding()
            }
        }
    }
}
