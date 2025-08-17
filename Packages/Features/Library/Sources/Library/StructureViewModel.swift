import Foundation
import NaturalLanguage
import Domain

public final class StructureViewModel: ObservableObject {
  // Inputs
  private let topicIndex: TopicIndex
  private let notesProvider: () -> [Note]

  // Outputs
  @Published public var trending: [Topic] = []
  @Published public var pinned: [String] = []          // topic names
  @Published public var people: [String] = []
  @Published public var projects: [Topic] = []
  @Published public var recentByTopic: [(String, [Note])] = []
  @Published public var searchTopics: [Topic] = []
  @Published public var searchNotes: [Note] = []

  public init(topicIndex: TopicIndex, notesProvider: @escaping () -> [Note]) {
    self.topicIndex = topicIndex
    self.notesProvider = notesProvider
    loadPinned()
    refreshAll()
  }

  public func refreshAll() {
    let notes = notesProvider()
    trending    = topicIndex.topTopics(limit: 24, windowDays: 14)
    people      = topNamedEntities(in: notes, kind: .personalName, limit: 16)
    projects    = inferProjects(from: notes, minNotes: 3)
    recentByTopic = groupRecentsByTopic(notes: notes, sinceDays: 7)
  }

  public func search(_ q: String) {
    let r = topicIndex.search(q)
    searchTopics = r.topics
    searchNotes  = r.notes
  }

  // Pinning
  public func togglePin(topic name: String) {
    if let i = pinned.firstIndex(of: name) { pinned.remove(at: i) } else { pinned.insert(name, at: 0) }
    savePinned()
  }

  // MARK: - Helpers

  private func groupRecentsByTopic(notes: [Note], sinceDays: Int) -> [(String, [Note])] {
    let cut = Date().addingTimeInterval(-Double(sinceDays) * 86_400)
    var buckets: [String: [Note]] = [:]
    for n in notes where n.updatedAt >= cut {
      // pick the top tag for the note (explicit or inferred) via TopicIndex.notes(for:)
      // fallback: "recent"
      let text = n.body.lowercased()
      let tag = Self.explicitTags(in: text).first
        ?? Self.keywords(from: text).first
        ?? "recent"
      buckets[tag, default: []].append(n)
    }
    return buckets
      .map { ($0.key, $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
      .sorted { $0.1.first?.updatedAt ?? .distantPast > $1.1.first?.updatedAt ?? .distantPast }
  }

  private func inferProjects(from notes: [Note], minNotes: Int) -> [Topic] {
    // Heuristic: topics that co-occur with projecty words or appear in >= minNotes
    let words = Set(["project","plan","launch","spec","brief","roadmap","milestone","ship","release"])
    var freq: [String: Int] = [:]
    for n in notes {
      let t = Self.explicitTags(in: n.body)
      let hasProj = n.body.lowercased().split{!"abcdefghijklmnopqrstuvwxyz".contains($0)}.contains { words.contains(String($0)) }
      for tag in t {
        freq[tag, default: 0] += hasProj ? 2 : 1
      }
    }
    let picks = freq.filter { $0.value >= minNotes }.map { Topic(name: $0.key, count: $0.value, lastUsedAt: Date(), score: Double($0.value)) }
    return picks.sorted { $0.score > $1.score }
  }

  private func topNamedEntities(in notes: [Note], kind: NLTag, limit: Int) -> [String] {
    var counts: [String: Int] = [:]
    for n in notes {
      let t = n.body
      let tagger = NLTagger(tagSchemes: [.nameType])
      tagger.string = t
      tagger.enumerateTags(in: t.startIndex..<t.endIndex, unit: .word, scheme: .nameType,
                           options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
        guard let tag, tag == kind else { return true }
        let s = String(t[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 1 { counts[s, default: 0] += 1 }
        return true
      }
    }
    return counts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
  }

  private static func explicitTags(in text: String) -> [String] {
    let rx = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
    let ns = text as NSString
    return rx.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)).lowercased() }
  }

  private static func keywords(from text: String) -> [String] {
    let lowers = text.lowercased()
    let keep = lowers.split { !"abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }.map(String.init)
      .filter { !$0.hasPrefix("#") && $0.count > 3 }
    var counts: [String:Int] = [:]; keep.forEach { counts[$0, default: 0] += 1 }
    return counts.sorted { $0.value > $1.value }.map(\.key)
  }

  // MARK: - Persistence (pinned)

  private func loadPinned() {
    if let s = UserDefaults.standard.stringArray(forKey: "pinnedTopics") { pinned = s }
  }
  private func savePinned() {
    UserDefaults.standard.set(pinned, forKey: "pinnedTopics")
  }
}
