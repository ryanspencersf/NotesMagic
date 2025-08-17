import Foundation

// MARK: - Topic Model
public struct Topic: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let count: Int
    public let lastUsedAt: Date
    public let score: Double
    
    public init(name: String, count: Int, lastUsedAt: Date, score: Double) {
        self.name = name
        self.count = count
        self.lastUsedAt = lastUsedAt
        self.score = score
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - TopicIndex Protocol
public protocol TopicIndex {
    func rebuild(from notes: [Note])
    func noteDidChange(_ note: Note)
    func topTopics(limit: Int, windowDays: Int) -> [Topic]
    func notes(for topicName: String) -> [Note]
    func search(_ query: String) -> (topics: [Topic], notes: [Note])
    func addTag(_ tag: String, to noteID: UUID)
    func topicsWithScores() -> [(name: String, count: Int, lastUsedAt: Date, score: Double)]
    func relatedTopics(for topic: String, limit: Int) -> [String]
}
