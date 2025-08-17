import Foundation
import Domain

@MainActor
public class LibraryViewModel: ObservableObject {
    @Published public private(set) var activeNotes: [Note] = []
    @Published public private(set) var trashedNotes: [Note] = []
    
    private let notesStore: NotesStore
    public let topicIndex: TopicIndex
    
    public init(notesStore: NotesStore, topicIndex: TopicIndex) {
        self.notesStore = notesStore
        self.topicIndex = topicIndex
    }
    
    public func loadNotes() {
        activeNotes = notesStore.activeNotes()
        trashedNotes = notesStore.trashedNotes()
    }
    
    public func create(_ body: String) -> Note {
        let note = notesStore.create(body)
        loadNotes()
        return note
    }
    
    public func createFromPaste(_ text: String) {
        _ = create(text)
    }
    
    public func update(_ note: Note) {
        notesStore.update(note)
        loadNotes()
    }
    
    public func trash(_ id: Note.ID) throws {
        try notesStore.trash(id)
        loadNotes()
    }
    
    public func restore(_ id: Note.ID) throws {
        try notesStore.restore(id)
        loadNotes()
    }
    
    public func purge(olderThan days: Int) throws {
        try notesStore.purge(olderThan: days)
        loadNotes()
    }
    
    public func search(query: String) -> [Note] {
        notesStore.search(query: query)
    }
    
    // MARK: - Tag Management
    
    public func commitTagsToMasterLibrary(_ tags: Set<String>, for noteID: Note.ID) {
        // Update the topic index with new tags
        for tag in tags {
            topicIndex.addTag(tag, to: noteID)
        }
        
        // Optionally refresh the topic index
        // This could trigger a refresh of trending topics, etc.
    }
}
