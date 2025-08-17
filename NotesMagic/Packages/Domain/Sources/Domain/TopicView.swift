import Foundation

public struct TopicView: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: ViewType
    public let queryDSL: [String: String]
    public var pinned: Bool
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        type: ViewType,
        queryDSL: [String: String],
        pinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.queryDSL = queryDSL
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ViewType: String, Codable, CaseIterable {
    case tag = "tag"
    case search = "search"
    case date = "date"
    case relation = "relation"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .tag: return "Tag View"
        case .search: return "Search View"
        case .date: return "Date View"
        case .relation: return "Relation View"
        case .custom: return "Custom View"
        }
    }
}
