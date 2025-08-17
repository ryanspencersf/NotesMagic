import Foundation

public struct Note: Identifiable, Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var body: String
    public var format: NoteFormat
    public var deletedAt: Date?
    
    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        body: String,
        format: NoteFormat = .plainText,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.body = body
        self.format = format
        self.deletedAt = deletedAt
    }
    
    public var isDeleted: Bool {
        deletedAt != nil
    }
    
    public mutating func markAsDeleted() {
        deletedAt = Date()
        updatedAt = Date()
    }
    
    public mutating func restore() {
        deletedAt = nil
        updatedAt = Date()
    }
}

public enum NoteFormat: String, Codable, CaseIterable {
    case plainText = "plain"
    case markdown = "markdown"
    
    public var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .markdown: return "Markdown"
        }
    }
}
