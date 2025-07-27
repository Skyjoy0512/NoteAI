import Foundation

struct Project: Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var coverImageData: Data?
    let createdAt: Date
    var updatedAt: Date
    var metadata: ProjectMetadata
    var recordings: [Recording] = []
    var tags: [Tag] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        coverImageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: ProjectMetadata = ProjectMetadata()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverImageData = coverImageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
    
    var recordingCount: Int {
        recordings.count
    }
    
    var totalDuration: TimeInterval {
        recordings.reduce(0) { $0 + $1.duration }
    }
    
    var dateRange: (start: Date, end: Date)? {
        guard !recordings.isEmpty else { return nil }
        let dates = recordings.map { $0.createdAt }
        return (dates.min()!, dates.max()!)
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalDuration) ?? ""
    }
}

struct ProjectMetadata: Codable, Equatable {
    var participantNames: [String] = []
    var location: String?
    var purpose: String?
    var customFields: [String: String] = [:]
    
    init() {}
}

struct Tag: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var color: String
    
    init(id: UUID = UUID(), name: String, color: String = "blue") {
        self.id = id
        self.name = name
        self.color = color
    }
}