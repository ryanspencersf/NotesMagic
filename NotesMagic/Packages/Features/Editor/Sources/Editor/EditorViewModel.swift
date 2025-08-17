import SwiftUI
import Combine
import Foundation
import Domain

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var inferredTags: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var lastLen = 0
    private var analyzeTask: Task<Void, Never>?
    
    init() {
        $text
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] t in
                guard let self = self else { return }
                let newLen = t.count
                let delta = newLen - self.lastLen
                self.lastLen = newLen
                // Heuristic: big jump == paste
                if delta >= 500 { 
                    self.scheduleFullAnalysis(immediate: true) 
                }
            })
            .debounce(for: .milliseconds(180), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in 
                self?.scheduleFullAnalysis(immediate: false) 
            }
            .store(in: &cancellables)
    }
    
    func scheduleFullAnalysis(immediate: Bool) {
        analyzeTask?.cancel()
        let current = text
        analyzeTask = Task.detached(priority: immediate ? .userInitiated : .utility) {
            let result = Heuristics.inferTags(from: current) // full pass
            
            await MainActor.run { [weak self] in 
                self?.inferredTags = result
                
                // Persist inferred tags and trigger UI updates
                if let topicIndex = TopicIndex.shared {
                    // Store inferred tags with confidence, but only if they pass acceptance
                    for tag in result {
                        // Check if tag should be accepted before persisting
                        if Heuristics.acceptTag(tag, countAcrossNotes: 1, isEntity: false) {
                            topicIndex.addInferredTag(tag, confidence: 0.7)
                        }
                    }
                    
                    // Trigger refresh of Library and Structure views
                    NotificationCenter.default.post(name: .notesDidChange, object: nil)
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let notesDidChange = Notification.Name("notesDidChange")
}
