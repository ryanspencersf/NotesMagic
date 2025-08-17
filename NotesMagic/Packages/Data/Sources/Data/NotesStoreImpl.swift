import Foundation
import Domain

public class NotesStoreImpl: NotesStore {
    public static let shared = NotesStoreImpl()
    
    private var notes: [Note] = []
    
    private init() {
        // Add some sample notes for development
        _ = create("Welcome to NotesMagic! This is your first note. Start typing to capture your thoughts.")
        _ = create("Meeting notes from today's standup: Discussed new feature requirements, Set timeline for next sprint, Assigned tasks to team members")
        _ = create("Ideas for weekend: Try that new restaurant downtown, Work on side project, Call mom")
    }
    
    public func create(_ body: String) -> Note {
        let note = Note(body: body)
        notes.append(note)
        return note
    }
    
    public func update(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        }
    }
    
    public func trash(_ id: Note.ID) throws {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].markAsDeleted()
        }
    }
    
    public func restore(_ id: Note.ID) throws {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].restore()
        }
    }
    
    public func purge(olderThan days: Int) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        notes.removeAll { note in
            note.isDeleted && note.deletedAt! < cutoffDate
        }
    }
    
    public func activeNotes() -> [Note] {
        notes.filter { !$0.isDeleted }
    }
    
    public func trashedNotes() -> [Note] {
        notes.filter { $0.isDeleted }
    }
    
    public func note(withId id: Note.ID) -> Note? {
        notes.first { $0.id == id }
    }
    
    public func search(query: String) -> [Note] {
        let active = activeNotes()
        if query.isEmpty { return active }
        
        return active.filter { note in
            note.body.localizedCaseInsensitiveContains(query)
        }
    }
    
    public func eraseAll() {
        notes.removeAll()
    }
}
