import Foundation
import Domain
import Data

@MainActor
public final class StructureViewModel: ObservableObject {
    @Published public var sections: [Section] = []
    
    public struct Section: Identifiable {
        public let id = UUID()
        public let group: TopicGroup
        public let chips: [String]   // topics
        public let totalCount: Int
        
        public init(group: TopicGroup, chips: [String], totalCount: Int) {
            self.group = group
            self.chips = chips
            self.totalCount = totalCount
        }
    }
    
    public let index: TopicIndex
    public init(index: TopicIndex) { self.index = index }
    
    public func rebuild(limitPerGroup: Int = 10) {
        var buckets: [TopicGroup: [(String, Double)]] = [:]
        
        for (topic, _) in (index as? TopicIndexImpl)?.stats ?? [:] {
            if (index as? TopicIndexImpl)?.isNoise(topic) == true { continue }
            let g = index.group(for: topic)
            buckets[g, default: []].append((topic, index.topicScore(topic)))
        }
        
        var secs: [Section] = []
        for g in TopicGroup.allCases {
            guard var arr = buckets[g], !arr.isEmpty else { continue }
            arr.sort { $0.1 > $1.1 }
            let topics = arr.map { $0.0 }
            let chips = Array(topics.prefix(limitPerGroup))
            let total = topics.count
            secs.append(Section(group: g, chips: chips, totalCount: total))
        }
        
        // sort groups by summed score
        secs.sort {
            let a = buckets[$0.group]?.map { $0.1 }.reduce(0, +) ?? 0
            let b = buckets[$1.group]?.map { $0.1 }.reduce(0, +) ?? 0
            return a > b
        }
        sections = secs
    }
}

// MARK: - Section Extensions

private extension StructureViewModel.Section {
    var groupTitle: String {
        switch group {
            case .people: return "People"
            case .orgs: return "Organizations"
            case .places: return "Places"
            case .projects: return "Projects"
            case .work: return "Work"
            case .ideas: return "Ideas"
            case .other: return "Other"
        }
    }
}

