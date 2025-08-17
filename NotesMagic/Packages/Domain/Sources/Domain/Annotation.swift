import Foundation

public struct Annotation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let noteId: UUID
    public let range: Range<Int>
    public let type: AnnotationType
    public let payload: [String: String]
    public let provenance: Provenance
    public let confidence: Double
    public var isAccepted: Bool
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        noteId: UUID,
        range: Range<Int>,
        type: AnnotationType,
        payload: [String: String],
        provenance: Provenance,
        confidence: Double,
        isAccepted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.noteId = noteId
        self.range = range
        self.type = type
        self.payload = payload
        self.provenance = provenance
        self.confidence = confidence
        self.isAccepted = isAccepted
        self.createdAt = createdAt
    }
}

public enum AnnotationType: String, Codable, CaseIterable {
    case title = "title"
    case tag = "tag"
    case task = "task"
    case link = "link"
    case summary = "summary"
    
    public var displayName: String {
        switch self {
        case .title: return "Title"
        case .tag: return "Tag"
        case .task: return "Task"
        case .link: return "Link"
        case .summary: return "Summary"
        }
    }
}

public struct Provenance: Codable, Equatable {
    public let model: String
    public let version: String
    public let timestamp: Date
    public let source: ProvenanceSource
    
    public init(
        model: String,
        version: String,
        timestamp: Date = Date(),
        source: ProvenanceSource
    ) {
        self.model = model
        self.version = version
        self.timestamp = timestamp
        self.source = source
    }
}

public enum ProvenanceSource: String, Codable, CaseIterable {
    case local = "local"
    case cloud = "cloud"
    case user = "user"
    
    public var displayName: String {
        switch self {
        case .local: return "Local Model"
        case .cloud: return "Cloud Model"
        case .user: return "User"
        }
    }
}
