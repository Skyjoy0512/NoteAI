import SQLite
import Foundation

public class SQLiteManager {
    private var db: Connection?
    
    // Projects table
    private let projects = Table("projects")
    private let projectId = Expression<String>("id")
    private let projectName = Expression<String>("name")
    private let projectDescription = Expression<String?>("description")
    private let projectCreatedAt = Expression<Date>("created_at")
    private let projectUpdatedAt = Expression<Date>("updated_at")
    
    // Recordings table
    private let recordings = Table("recordings") 
    private let recordingId = Expression<String>("id")
    private let recordingTitle = Expression<String>("title")
    private let recordingProjectId = Expression<String?>("project_id")
    private let recordingAudioFileURL = Expression<String>("audio_file_url")
    private let recordingDuration = Expression<Double>("duration")
    private let recordingCreatedAt = Expression<Date>("created_at")
    private let recordingUpdatedAt = Expression<Date>("updated_at")
    
    public init() {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dbPath = "\(documentsPath)/noteai.sqlite3"
            db = try Connection(dbPath)
            
            createTables()
        } catch {
            print("Database initialization failed: \(error)")
        }
    }
    
    private func createTables() {
        do {
            try db?.run(projects.create(ifNotExists: true) { t in
                t.column(projectId, primaryKey: true)
                t.column(projectName)
                t.column(projectDescription)
                t.column(projectCreatedAt)
                t.column(projectUpdatedAt)
            })
            
            try db?.run(recordings.create(ifNotExists: true) { t in
                t.column(recordingId, primaryKey: true)
                t.column(recordingTitle)
                t.column(recordingProjectId)
                t.column(recordingAudioFileURL)
                t.column(recordingDuration)
                t.column(recordingCreatedAt)
                t.column(recordingUpdatedAt)
                t.foreignKey(recordingProjectId, references: projects, projectId)
            })
        } catch {
            print("Table creation failed: \(error)")
        }
    }
    
    // CRUD操作例
    public func insertProject(name: String, description: String?) -> String? {
        let id = UUID().uuidString
        let now = Date()
        
        do {
            try db?.run(projects.insert(
                projectId <- id,
                projectName <- name,
                projectDescription <- description,
                projectCreatedAt <- now,
                projectUpdatedAt <- now
            ))
            return id
        } catch {
            print("Project insertion failed: \(error)")
            return nil
        }
    }
    
    public func getAllProjects() -> [(id: String, name: String, description: String?)] {
        do {
            var result: [(id: String, name: String, description: String?)] = []
            
            for project in try db?.prepare(projects) ?? [] {
                result.append((
                    id: project[projectId],
                    name: project[projectName],
                    description: project[projectDescription]
                ))
            }
            
            return result
        } catch {
            print("Failed to fetch projects: \(error)")
            return []
        }
    }
}
