import Foundation

public protocol NotesStore {
    func create(_ body: String) -> Note
    func update(_ note: Note)
    func trash(_ id: Note.ID) throws
    func restore(_ id: Note.ID) throws
    func purge(olderThan days: Int) throws
    func activeNotes() -> [Note]
    func trashedNotes() -> [Note]
    func note(withId id: Note.ID) -> Note?
    func search(query: String) -> [Note]
}

public protocol AnnotationsStore {
    func save(_ annotation: Annotation)
    func annotations(for noteId: Note.ID) -> [Annotation]
    func accept(_ annotationId: Annotation.ID)
    func dismiss(_ annotationId: Annotation.ID)
    func clearDismissed(for noteId: Note.ID)
}

public protocol RelationsStore {
    func save(_ relation: Relation)
    func relations(for noteId: Note.ID) -> [Relation]
    func relatedNotes(for noteId: Note.ID, limit: Int) -> [Note]
}

public protocol TopicViewsStore {
    func save(_ view: TopicView)
    func pinnedViews() -> [TopicView]
    func views(for type: ViewType) -> [TopicView]
    func togglePin(_ viewId: TopicView.ID)
}
