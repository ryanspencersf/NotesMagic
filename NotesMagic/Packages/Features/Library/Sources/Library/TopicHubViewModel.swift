import Foundation
import Domain
import NaturalLanguage

@MainActor
final class TopicHubViewModel: ObservableObject {
    @Published var bullets: [(text: String, noteID: UUID)] = []
    @Published var entities: [String] = []
    @Published var openLoops: [String] = []
    @Published var notes: [Note] = []
    let topic: String
    
    init(topic: String) { 
        self.topic = topic 
    }
    
    func load() {
        // TODO: Get notes from TopicIndex when available
        // notes = TopicIndex.shared.notes(for: topic)
        
        // For now, use mock data
        notes = []
        bullets = []
        entities = []
        openLoops = []
        
        // TODO: Implement when Summarize.sentences is available
        // bullets = Summarize.sentences(from: notes, topic: topic, limit: 5)
        //     .map { ($0.text, $0.noteID) }
        
        // TODO: Implement when Heuristics.entities is available
        // entities = Heuristics.entities(in: notes.map(\.body).joined(separator: "\n"))
        
        // TODO: Implement when Heuristics.openLoops is available
        // openLoops = Heuristics.openLoops(in: notes)
    }
}
