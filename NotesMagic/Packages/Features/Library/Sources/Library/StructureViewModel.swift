import Foundation
import NaturalLanguage
import Domain

@MainActor
public class StructureViewModel: ObservableObject {
    @Published public private(set) var categories: [TagCategory] = []
    @Published public private(set) var categorizedTopics: [String: [TopicChip]] = [:]
    @Published public var searchQuery: String = ""
    @Published public var searchResults: (topics: [TopicChip], notes: [Note]) = ([], [])
    
    public let topicIndex: TopicIndex
    private let notesProvider: () -> [Note]
    private var manualOverrides: [String: String] = [:] // topic name -> category ID
    
    public init(topicIndex: TopicIndex, notesProvider: @escaping () -> [Note]) {
        self.topicIndex = topicIndex
        self.notesProvider = notesProvider
        loadDefaultCategories()
        categorizeTopics()
    }
    
    // MARK: - Public API
    
    public func search(_ query: String) {
        searchQuery = query
        guard !query.isEmpty else {
            searchResults = ([], [])
            return
        }
        
        let results = topicIndex.search(query)
        let topicChips = results.topics.map { topic in
            TopicChip(
                name: topic.name,
                count: topic.count,
                category: getCategory(for: topic.name),
                isPinned: false
            )
        }
        
        searchResults = (topicChips, results.notes)
    }
    
    public func togglePin(for topicName: String) {
        // Implementation for pinning would go here
        // For now, just recategorize to refresh the view
        categorizeTopics()
    }
    
    public func assignTopic(_ topicName: String, to categoryID: String?) {
        if let categoryID = categoryID {
            manualOverrides[topicName] = categoryID
        } else {
            manualOverrides.removeValue(forKey: topicName)
        }
        saveManualOverrides()
        categorizeTopics()
    }
    
    public func reorderCategories(_ categories: [TagCategory]) {
        self.categories = categories
        saveCategories()
        categorizeTopics()
    }
    
    // MARK: - Private Methods
    
    private func loadDefaultCategories() {
        let defaults = [
            TagCategory(id: "people", name: "People", emoji: "👤", rules: [.entity(.personalName)], pinned: true, order: 0),
            TagCategory(id: "family", name: "Family", emoji: "👪", rules: [.contains(["wife", "husband", "mom", "dad", "son", "daughter"])], pinned: true, order: 1),
            TagCategory(id: "friends", name: "Friends", emoji: "👫", rules: [.contains(["friend", "friends"])], pinned: true, order: 2),
            TagCategory(id: "projects", name: "Projects", emoji: "🚀", rules: [.contains(["project", "plan", "launch", "spec", "roadmap"]), .minNotes(3)], pinned: true, order: 3),
            TagCategory(id: "work", name: "Work", emoji: "💼", rules: [.entity(.organizationName), .contains(["meeting", "standup", "okr", "prd"])], pinned: true, order: 4),
            TagCategory(id: "places", name: "Places", emoji: "📍", rules: [.entity(.placeName)], pinned: true, order: 5),
            TagCategory(id: "reading", name: "Reading", emoji: "📚", rules: [.contains(["read", "watch", "article", "paper"])], pinned: true, order: 6),
            TagCategory(id: "ideas", name: "Ideas", emoji: "💡", rules: [.contains(["idea", "what if"])], pinned: true, order: 7),
            TagCategory(id: "meetings", name: "Meetings", emoji: "🗓️", rules: [.contains(["meeting", "standup", "retro"])], pinned: true, order: 8)
        ]
        
        categories = loadCategories() ?? defaults
        saveCategories()
    }
    
    private func categorizeTopics() {
        let topics = topicIndex.topicsWithScores()
        let notes = notesProvider()
        
        var categorized: [String: [TopicChip]] = [:]
        
        for topic in topics {
            let categoryID = categorize(topic.name, notes: notes)
            let chip = TopicChip(
                name: topic.name,
                count: topic.count,
                category: categoryID,
                isPinned: false
            )
            
            if let categoryID = categoryID {
                categorized[categoryID, default: []].append(chip)
            } else {
                categorized["ungrouped", default: []].append(chip)
            }
        }
        
        // Sort topics within each category by score
        for categoryID in categorized.keys {
            categorized[categoryID]?.sort { $0.score > $1.score }
        }
        
        categorizedTopics = categorized
    }
    
    private func categorize(_ topicName: String, notes: [Note]) -> String? {
        // Check manual override first
        if let override = manualOverrides[topicName] {
            return override
        }
        
        let lowerName = topicName.lowercased()
        
        // Use NaturalLanguage for entity recognition
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = topicName
        
        // Check entity types
        if let (tag, _) = tagger.tag(at: topicName.startIndex, unit: .word, scheme: .nameType) {
            switch tag {
            case .personalName:
                return "people"
            case .placeName:
                return "places"
            case .organizationName:
                return "work"
            default:
                break
            }
        }
        
        // Check keyword rules
        for category in categories {
            for rule in category.rules {
                if matchesRule(topicName, rule: rule, notes: notes) {
                    return category.id
                }
            }
        }
        
        return nil
    }
    
    private func matchesRule(_ topicName: String, rule: Rule, notes: [Note]) -> Bool {
        let lowerName = topicName.lowercased()
        
        switch rule {
        case .entity(let entityType):
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = topicName
            if let (tag, _) = tagger.tag(at: topicName.startIndex, unit: .word, scheme: .nameType) {
                return tag == entityType
            }
            return false
            
        case .contains(let keywords):
            return keywords.contains { lowerName.contains($0) }
            
        case .regex(let pattern):
            return topicName.range(of: pattern, options: .regularExpression) != nil
            
        case .minNotes(let minCount):
            return topicIndex.notes(for: topicName).count >= minCount
        }
    }
    
    private func getCategory(for topicName: String) -> String? {
        return manualOverrides[topicName] ?? categorize(topicName, notes: notesProvider())
    }
    
    // MARK: - Persistence
    
    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: "StructureCategories")
        }
    }
    
    private func loadCategories() -> [TagCategory]? {
        guard let data = UserDefaults.standard.data(forKey: "StructureCategories") else { return nil }
        return try? JSONDecoder().decode([TagCategory].self, from: data)
    }
    
    private func saveManualOverrides() {
        if let data = try? JSONEncoder().encode(manualOverrides) {
            UserDefaults.standard.set(data, forKey: "StructureManualOverrides")
        }
    }
    
    private func loadManualOverrides() {
        guard let data = UserDefaults.standard.data(forKey: "StructureManualOverrides") else { return }
        manualOverrides = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}

// MARK: - Models

public struct TagCategory: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var emoji: String
    public var rules: [Rule]
    public var pinned: Bool
    public var order: Int
    
    public init(id: String, name: String, emoji: String, rules: [Rule], pinned: Bool, order: Int) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.rules = rules
        self.pinned = pinned
        self.order = order
    }
}

public enum Rule: Codable, Equatable {
    case entity(NLTagKind)
    case contains([String])
    case regex(String)
    case minNotes(Int)
}

public struct TopicChip: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let count: Int
    public let category: String?
    public let isPinned: Bool
    
    // Computed property for score-based sorting
    public var score: Double {
        // Simple scoring: count + recency bonus
        return Double(count)
    }
    
    public init(name: String, count: Int, category: String?, isPinned: Bool) {
        self.name = name
        self.count = count
        self.category = category
        self.isPinned = isPinned
    }
}

