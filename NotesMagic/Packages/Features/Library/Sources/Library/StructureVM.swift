import Foundation
import SwiftUI
import Domain
import NaturalLanguage

@MainActor
final class StructureVM: ObservableObject {
    struct Topic: Identifiable, Hashable { 
        var id: String { name }
        let name: String
        let count: Int
        let lastUsed: Date
        let score: Double
    }
    
    struct Group: Identifiable { 
        let id: String
        let title: String
        let emoji: String
        let topics: [Topic]
    }
    
    @Published var groups: [Group] = []
    private var cacheKey: Int = 0
    private let topicIndex: TopicIndex
    private let notesProvider: () -> [Note]
    
    init(topicIndex: TopicIndex, notesProvider: @escaping () -> [Note]) {
        self.topicIndex = topicIndex
        self.notesProvider = notesProvider
        
        // Listen for notes changes to refresh automatically
        NotificationCenter.default.addObserver(
            forName: .notesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func refresh() {
        let notes = notesProvider()
        let key = notes.reduce(0) { $0 ^ $1.hashValue }
        guard key != cacheKey else { return }
        cacheKey = key
        
        groups = buildGroups(from: notes)
    }
    
    private func buildGroups(from notes: [Note]) -> [Group] {
        let topicCounts = Dictionary(uniqueKeysWithValues: topicIndex.topicsWithScores().map { ($0.name, $0.count) })
        let topicLastUsed = Dictionary(uniqueKeysWithValues: topicIndex.topicsWithScores().map { ($0.name, $0.lastUsed) })
        
        var groups: [Group] = []
        
        // People (named entities)
        let people = extractEntities(from: notes, kind: .nameType)
            .filter { Heuristics.acceptTag($0, countAcrossNotes: topicCounts[$0] ?? 0, isEntity: true) }
            .map { Topic(name: $0, count: topicCounts[$0] ?? 0, lastUsed: topicLastUsed[$0] ?? Date()) }
            .sorted { calculateScore(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) > calculateScore(name: $1.name, count: $1.count, lastUsed: $1.lastUsed) }
        
        if !people.isEmpty {
            groups.append(Group(emoji: "👥", title: "People", topics: people))
        }
        
        // Work (organizations)
        let work = extractEntities(from: notes, kind: .nameType)
            .filter { Heuristics.acceptTag($0, countAcrossNotes: topicCounts[$0] ?? 0, isEntity: true) }
            .map { Topic(name: $0, count: topicCounts[$0] ?? 0, lastUsed: topicLastUsed[$0] ?? Date()) }
            .sorted { calculateScore(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) > calculateScore(name: $1.name, count: $1.count, lastUsed: $1.lastUsed) }
        
        if !work.isEmpty {
            groups.append(Group(emoji: "💼", title: "Work", topics: work))
        }
        
        // Ideas (frequent keywords)
        let ideas = topicIndex.topicsWithScores()
            .filter { Heuristics.acceptTag($0.name, countAcrossNotes: $0.count, isEntity: false) }
            .filter { $0.count >= 2 } // Only stable ideas
            .sorted { calculateScore(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) > calculateScore(name: $1.name, count: $1.count, lastUsed: $1.lastUsed) }
            .prefix(12)
            .map { Topic(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) }
        
        if !ideas.isEmpty {
            groups.append(Group(emoji: "💡", title: "Ideas", topics: Array(ideas)))
        }
        
        // Places (geographic entities)
        let places = extractEntities(from: notes, kind: .nameType)
            .filter { Heuristics.acceptTag($0, countAcrossNotes: topicCounts[$0] ?? 0, isEntity: true) }
            .map { Topic(name: $0, count: topicCounts[$0] ?? 0, lastUsed: topicLastUsed[$0] ?? Date()) }
            .sorted { calculateScore(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) > calculateScore(name: $1.name, count: $1.count, lastUsed: $1.lastUsed) }
        
        if !places.isEmpty {
            groups.append(Group(emoji: "📍", title: "Places", topics: places))
        }
        
        // Other Topics (remaining explicit tags)
        let other = topicIndex.topicsWithScores()
            .filter { Heuristics.acceptTag($0.name, countAcrossNotes: $0.count, isEntity: false) }
            .filter { !ideas.contains { $0.name == $0.name } } // Exclude ideas already shown
            .sorted { calculateScore(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) > calculateScore(name: $1.name, count: $1.count, lastUsed: $1.lastUsed) }
            .prefix(8)
            .map { Topic(name: $0.name, count: $0.count, lastUsed: $0.lastUsed) }
        
        if !other.isEmpty {
            groups.append(Group(emoji: "🏷️", title: "Other Topics", topics: Array(other)))
        }
        
        // Order groups by total activity (sum of topic scores)
        return groups.sorted { group1, group2 in
            let score1 = group1.topics.reduce(0.0) { sum, topic in
                sum + calculateScore(name: topic.name, count: topic.count, lastUsed: topic.lastUsed)
            }
            let score2 = group2.topics.reduce(0.0) { sum, topic in
                sum + calculateScore(name: topic.name, count: topic.count, lastUsed: topic.lastUsed)
            }
            return score1 > score2
        }
    }
    
    private func calculateScore(name: String, count: Int, lastUsed: Date) -> Double {
        let frequency = Double(count)
        let recencyScore = max(0.0, 30.0 - Date().timeIntervalSince(lastUsed) / (24.0 * 60.0 * 60.0)) / 30.0
        
        // Weighted scoring: 70% recency, 30% frequency (log scale)
        return 0.7 * recencyScore + 0.3 * log1p(frequency)
    }
    
    private func extractEntities(from notes: [Note], kind: NLTagScheme) -> [String] {
        let tagger = NLTagger(tagSchemes: [kind])
        var entities: Set<String> = []
        
        for note in notes {
            tagger.string = note.body
            tagger.enumerateTags(
                in: note.body.startIndex..<note.body.endIndex, 
                unit: .word, 
                scheme: kind, 
                options: [.omitPunctuation,.omitWhitespace,.joinNames]
            ) { _, range in
                let entity = String(note.body[range])
                if entity.count > 2 && !entity.contains(" ") {
                    entities.insert(entity)
                }
                return true
            }
        }
        return Array(entities)
    }
}

// MARK: - Extensions

private extension Array where Element == StructureVM.Topic {
    func first(name: String) -> StructureVM.Topic? { 
        first { $0.name == name } 
    }
}

private extension String {
    func containsAny(of needles: [String]) -> Bool { 
        let l = lowercased()
        return needles.contains { l.contains($0) } 
    }
}
