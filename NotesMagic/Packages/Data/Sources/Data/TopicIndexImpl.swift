import Foundation
import Domain

public class TopicIndexImpl: TopicIndex {
    public static let shared = TopicIndexImpl()
    
    // explicit hashtags
    private var posting: [String: Set<UUID>] = [:]
    private var when: [String: [Date]] = [:]
    // inferred tags (auto-applied, lighter weight)
    private var inferredPosting: [String: Set<UUID>] = [:]
    private var inferredWhen: [String: [Date]] = [:]
    
    private var scoreCache: [String: Double] = [:]
    private var lastUsed: [String: Date] = [:]
    private var notesByID: [UUID: Note] = [:]
    
    private static let tagRegex = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
    
    private init() {}
    
    public func rebuild(from notes: [Note]) {
        posting.removeAll()
        when.removeAll()
        inferredPosting.removeAll()
        inferredWhen.removeAll()
        scoreCache.removeAll()
        lastUsed.removeAll()
        notesByID.removeAll()
        for n in notes { index(n) }
    }
    
    public func noteDidChange(_ note: Note) {
        if let old = notesByID[note.id] {
            for t in Self.explicit(from: old.body) { posting[t]?.remove(old.id) }
            for t in Self.infer(from: old.body) { inferredPosting[t]?.remove(old.id) }
        }
        index(note)
    }
    
    public func topTopics(limit: Int, windowDays: Int) -> [Topic] {
        let now = Date()
        let window = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let all = Set(posting.keys).union(inferredPosting.keys)
        let topics: [Topic] = all.map { t in
            let expUses = (when[t] ?? []).filter { $0 >= window }.count
            let infUses = (inferredWhen[t] ?? []).filter { $0 >= window }.count
            let s = score(for: t, now: now)
            let last = lastUsed[t] ?? .distantPast
            return Topic(name: t,
                        count: (posting[t]?.count ?? 0) + (inferredPosting[t]?.count ?? 0),
                        lastUsedAt: last,
                        score: s + Double(expUses) + 0.7 * Double(infUses))   // recency bump
        }
        return topics.sorted {
            $0.score == $1.score ? $0.lastUsedAt > $1.lastUsedAt : $0.score > $1.score
        }.prefix(limit).map { $0 }
    }
    
    public func notes(for topicName: String) -> [Note] {
        let key = topicName.lowercased()
        let ids = (posting[key] ?? []).union(inferredPosting[key] ?? [])
        return ids.compactMap { notesByID[$0] }.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    public func search(_ q: String) -> (topics: [Topic], notes: [Note]) {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ([], []) }
        let now = Date()
        let all = Set(posting.keys).union(inferredPosting.keys)
        let t = all.filter { $0.contains(query) }.map { name in
            Topic(name: name,
                  count: (posting[name]?.count ?? 0) + (inferredPosting[name]?.count ?? 0),
                  lastUsedAt: lastUsed[name] ?? .distantPast,
                  score: score(for: name, now: now))
        }.sorted { $0.score > $1.score }
        let n = notesByID.values.filter { $0.body.lowercased().contains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
        return (Array(t.prefix(6)), Array(n.prefix(20)))
    }
    
    public func addTag(_ tag: String, to noteID: UUID) {
        let lowerTag = tag.lowercased()
        posting[lowerTag, default: []].insert(noteID)
        when[lowerTag, default: []].append(Date())
        lastUsed[lowerTag] = Date()
        scoreCache.removeAll()
    }
    
    public func topicsWithScores() -> [(name: String, count: Int, lastUsedAt: Date, score: Double)] {
        let now = Date()
        let all = Set(posting.keys).union(inferredPosting.keys)
        return all.map { topicName in
            let count = (posting[topicName]?.count ?? 0) + (inferredPosting[topicName]?.count ?? 0)
            let lastUsedAt = lastUsed[topicName] ?? .distantPast
            let score = score(for: topicName, now: now)
            return (name: topicName, count: count, lastUsedAt: lastUsedAt, score: score)
        }
    }
    
    public func relatedTopics(for topic: String, limit: Int) -> [String] {
        let topicNotes = notes(for: topic)
        var topicCounts: [String: Int] = [:]
        
        for note in topicNotes {
            for tag in Self.explicit(from: note.body) {
                if tag != topic.lowercased() {
                    topicCounts[tag, default: 0] += 1
                }
            }
        }
        
        return topicCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    public func reset() {
        posting.removeAll()
        when.removeAll()
        inferredPosting.removeAll()
        inferredWhen.removeAll()
        scoreCache.removeAll()
        lastUsed.removeAll()
        notesByID.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func index(_ note: Note) {
        notesByID[note.id] = note
        for tag in Self.explicit(from: note.body) {
            posting[tag, default: []].insert(note.id)
            when[tag, default: []].append(Date())
            lastUsed[tag] = Date()
        }
        for tag in Self.infer(from: note.body) {
            inferredPosting[tag, default: []].insert(note.id)
            inferredWhen[tag, default: []].append(Date())
            lastUsed[tag] = Date()
        }
        scoreCache.removeAll()
    }
    
    private func score(for topic: String, now: Date) -> Double {
        if let cached = scoreCache[topic] { return cached }
        let last = lastUsed[topic] ?? .distantPast
        let daysSince = now.timeIntervalSince(last) / 86_400
        let score = max(0, 100 - daysSince) // decay over time
        scoreCache[topic] = score
        return score
    }
    
    private static func explicit(from text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = tagRegex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range]).lowercased()
        }
    }
    
    private static func infer(from text: String) -> [String] {
        // Simple heuristic: extract potential topics from text
        // This is a placeholder - would be replaced with proper NLP
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { word in
            word.count > 3 && 
            word.first?.isUppercase == true &&
            !word.contains(where: { !$0.isLetter })
        }.map { $0.lowercased() }
    }
}
