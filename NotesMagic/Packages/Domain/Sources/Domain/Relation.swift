import Foundation

public struct Relation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let srcNoteId: UUID
    public let dstNoteId: UUID
    public let reason: String
    public let score: Double
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        srcNoteId: UUID,
        dstNoteId: UUID,
        reason: String,
        score: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.srcNoteId = srcNoteId
        self.dstNoteId = dstNoteId
        self.reason = reason
        self.score = score
        self.createdAt = createdAt
    }
}
