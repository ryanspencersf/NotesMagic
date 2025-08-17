import Foundation
import Domain
import NaturalLanguage

public class TopicIndexImpl: TopicIndex, ObservableObject {
    public static let shared = TopicIndexImpl()
    
    @Published public private(set) var stats: [String: TopicStats] = [:]
    @Published public private(set) var overrides: [String: TopicGroup] = [:]  // manual
    
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
    
    // MARK: - New Dynamic Methods
    
    public func setManualGroup(topic: String, group: TopicGroup?) {
        overrides[topic] = group
        objectWillChange.send()
    }
    
    public func index(note id: UUID, text: String, date: Date = Date()) {
        let rawTopics = extractTopics(text)
        let topics = Set(rawTopics.map(canonicalize))
        for t in topics {
            var s = stats[t, default: TopicStats()]
            s.count += 1
            s.lastSeen = max(s.lastSeen, date)
            s.isEntity = s.isEntity || isNamedEntity(t, in: text)
            s.cooccurs.formUnion(topics.subtracting([t]))
            stats[t] = s
        }
    }
    
    public func group(for topic: String) -> TopicGroup {
        if let o = overrides[topic] { return o }
        let s = stats[topic] ?? TopicStats()
        if s.isEntity { return .people } // simple default for entities; refine to orgs/places if you want
        if s.count >= 3 { return .projects }
        if s.count >= 2 { return .work }
        return .ideas
    }
    
    public func topicScore(_ topic: String, now: Date = Date()) -> Double {
        guard let s = stats[topic] else { return 0 }
        // recency: clamp 0–30d → 0–1
        let days = max(0, min(30, now.timeIntervalSince(s.lastSeen) / 86_400))
        let recency = (30 - days) / 30
        let freq = log(1 + Double(s.count))
        let centrality = min(1.0, Double(s.cooccurs.count) / 8.0)
        return 0.6 * recency + 0.3 * freq + 0.1 * centrality
    }
    
    public func isNoise(_ topic: String) -> Bool {
        let s = stats[topic] ?? TopicStats()
        if topic.count < 3 { return true }
        if topic.firstIndex(where: { "aeiou".contains($0) }) == nil { return true }
        if s.count < 2 && !s.isEntity { return true }
        return false
    }
    
    // MARK: - Helper Methods
    
    private func canonicalize(_ s: String) -> String {
        let lowered = s.lowercased()
        let removed = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.union(.whitespaces).contains($0) }
        let collapsed = String(removed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "-")
    }
    
    private func extractTopics(_ text: String) -> [String] {
        // 1) explicit hashtags
        let regex = try! NSRegularExpression(pattern: "#([a-zA-Z0-9\\-]+)")
        let ns = text as NSString
        let tags = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
        
        // 2) simple keyword picks (can upgrade later)
        return tags
    }
    
    private func isNamedEntity(_ topic: String, in text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found = false
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if let t = tag, t == .personalName || t == .placeName || t == .organizationName {
                if canonicalize(String(text[range])) == canonicalize(topic) { found = true; return false }
            }
            return true
        }
        return found
    }
    
    // MARK: - Legacy Protocol Methods
    
    public func rebuild(from notes: [Note]) {
        posting.removeAll()
        when.removeAll()
        inferredPosting.removeAll()
        inferredWhen.removeAll()
        scoreCache.removeAll()
        lastUsed.removeAll()
        notesByID.removeAll()
        stats.removeAll()
        overrides.removeAll()
        
        for n in notes { 
            index(note: n.id, text: n.body, date: n.updatedAt)
            indexLegacy(n) 
        }
    }
    
    public func noteDidChange(_ note: Note) {
        if let old = notesByID[note.id] {
            for t in Self.explicit(from: old.body) { posting[t]?.remove(old.id) }
            for t in Self.infer(from: old.body) { inferredPosting[t]?.remove(old.id) }
        }
        index(note: note.id, text: note.body, date: note.updatedAt)
        indexLegacy(note)
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
        stats.removeAll()
        overrides.removeAll()
    }
    
    // MARK: - Legacy Private Methods
    
    private func indexLegacy(_ note: Note) {
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
