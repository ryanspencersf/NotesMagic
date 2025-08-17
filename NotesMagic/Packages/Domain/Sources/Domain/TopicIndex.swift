import Foundation
import NaturalLanguage

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

// MARK: - Topic Groups
public enum TopicGroup: String, CaseIterable { 
    case people, orgs, places, projects, work, ideas, other 
}

// MARK: - Topic Statistics
public struct TopicStats {
    public var count: Int = 0
    public var lastSeen: Date = .distantPast
    public var cooccurs: Set<String> = []
    public var isEntity: Bool = false
    public var manualGroup: TopicGroup? = nil
    
    public init() {}
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
    func reset()
    
    // New dynamic methods
    func setManualGroup(topic: String, group: TopicGroup?)
    func index(note id: UUID, text: String, date: Date)
    func group(for topic: String) -> TopicGroup
    func topicScore(_ topic: String, now: Date) -> Double
    func isNoise(_ topic: String) -> Bool
}
