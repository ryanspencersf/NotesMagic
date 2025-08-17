//
//  NotesMagicApp.swift
//  NotesMagic
//
//  Created by Ryan Spencer on 8/16/25.
//

import SwiftUI
import NaturalLanguage
import Data

@main
struct NotesMagicApp: App {
    @StateObject var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.theme.colorScheme)
        }
    }
}

// MARK: - Temporary Implementation (will move to packages once linked)
struct ContentView: View {
    var body: some View {
        LibraryView()
    }
}

// MARK: - LibraryView (temporary copy)
struct LibraryView: View {
    @StateObject var vm: LibraryViewModel
    @State private var path: [Route] = []
    @State private var query: String = ""
    @State private var searchTopics: [Topic] = []
    @State private var searchNotes: [Note] = []
    @State private var showStructure = false
    @State private var activeTopic: String? = nil
    
    enum Route: Hashable { 
        case note(UUID), topic(String) 
    }
    
    init(viewModel: LibraryViewModel = LibraryViewModel()) { 
        self._vm = StateObject(wrappedValue: viewModel) 
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Filter token (when a topic is active)
                    if let topic = activeTopic {
                        HStack(spacing: 8) {
                            Text("#\(topic)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemGray5))
                                )
                            
                            Button { 
                                activeTopic = nil 
                            } label: { 
                                Image(systemName: "xmark.circle.fill") 
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }
                    
                    // Search field (unified)
                    TextField("Search notes and topics…", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .onChange(of: query) { oldValue, newValue in
                            let r = vm.search(newValue)
                            searchTopics = r.topics.sorted { $0.count > $1.count } // Sort by count
                            searchNotes = r.notes
                        }
                    
                    // Topics strip – fluid organization signal
                    TopicsStrip(topics: query.isEmpty ? vm.trendingTopics : searchTopics) { topic in
                        path.append(.topic(topic.name))
                    }
                    
                    // List: either search results or recent notes
                    if query.isEmpty {
                        list // your existing recent notes list
                    } else {
                        List {
                            if !searchTopics.isEmpty {
                                Section("Topics") {
                                    ForEach(searchTopics) { t in
                                        NavigationLink(value: Route.topic(t.name)) {
                                            Label("#\(t.name)", systemImage: "number")
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Section("Notes") {
                                ForEach(searchNotes) { note in
                                    NavigationLink(value: Route.note(note.id)) {
                                        Text(note.body).lineLimit(2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemBackground))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                
                // FAB lives only on Library, so it disappears when we navigate
                GlassFAB { openNew() }
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { 
                        showStructure = true 
                    } label: { 
                        Image(systemName: "sidebar.left") 
                    }
                    .accessibilityLabel("Structure")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .note(let id):
                    EditorView(
                        noteID: id,
                        getText: { vm.text(for: id) },
                        setText: { vm.update(noteID: id, body: $0) }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                case .topic(let name):
                    TopicView(topicName: name, notes: vm.notes(for: Topic(name: name, count: 0, lastUsedAt: Date(), score: 0)))
                }
            }
            // Edge swipe to open structure panel
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.22)) {
                            showStructure = true
                        }
                    }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay(alignment: .leading) {
            SidePanel(isOpen: $showStructure) {
                StructurePanelView(
                    vm: StructureVM(
                        topicIndex: vm.topicIndex,
                        notesProvider: { vm.items }
                    ),
                    onPick: { topic in
                        // Navigate to topic hub
                        path.append(.topic(topic))
                        showStructure = false
                    },
                    onClose: { showStructure = false }
                )
            }
        }
    }
    
    private var list: some View {
        List {
            ForEach(filteredNotes) { note in
                NavigationLink(value: Route.note(note.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.body.isEmpty ? "New note…" : note.body)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("Just now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                }
                .swipeActions(edge: .trailing) {              // swipe to delete
                    Button(role: .destructive) {
                        try? vm.trash(note.id)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            .onDelete { indexSet in                          // list delete (optional)
                for i in indexSet { try? vm.trash(vm.items[i].id) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
    
    private var filteredNotes: [Note] {
        guard let topic = activeTopic else { return vm.items }
        return vm.items.filter { note in
            note.body.lowercased().contains("#\(topic)") || note.body.lowercased().contains(topic)
        }
    }
    
    private func openNew() {
        let n = vm.newNote()
        path = [.note(n.id)]
    }
}

// MARK: - EditorView (temporary copy)
struct EditorView: View {
    public let noteID: UUID
    private let getText: () -> String
    private let setText: (String) -> Void
    private let libraryVM: LibraryViewModel? // Add this property
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text: String
    // Tag management
    @State private var suggestions: [Suggestion] = []
    @State private var acceptedTags: Set<String> = []
    @State private var pendingTags: Set<String> = [] // New: tags collected during editing
    @State private var suggestionWorkItem: DispatchWorkItem?
    @State private var lastAnalyzedText: String = ""
    
    // Auto-tag preview
    @State private var autoTagPreview: [String] = []
    
    @AppStorage("orgMode") private var orgModeRaw: String = OrganizationMode.auto.rawValue
    private var orgMode: OrganizationMode { OrganizationMode(rawValue: orgModeRaw) ?? .auto }
    
    init(noteID: UUID,
         getText: @escaping () -> String,
         setText: @escaping (String) -> Void,
         libraryVM: LibraryViewModel? = nil) {
        self.noteID = noteID
        self.getText = getText
        self.setText = setText
        self.libraryVM = libraryVM
        self._text = State(initialValue: getText())
        
        // Load previously accepted tags for this note
        self._acceptedTags = State(initialValue: loadAcceptedTags(for: noteID))
        
        // Load pending tags for this note (tags collected during current editing session)
        self._pendingTags = State(initialValue: loadPendingTags(for: noteID))
    }
    
    // MARK: - Tag Persistence
    
    private func loadAcceptedTags(for noteID: UUID) -> Set<String> {
        let key = "acceptedTags_\(noteID.uuidString)"
        if let tags = UserDefaults.standard.stringArray(forKey: key) {
            return Set(tags)
        }
        return []
    }
    
    private func saveAcceptedTags(_ tags: Set<String>, for noteID: UUID) {
        let key = "acceptedTags_\(noteID.uuidString)"
        UserDefaults.standard.set(Array(tags), forKey: key)
    }
    
    private func loadPendingTags(for noteID: UUID) -> Set<String> {
        let key = "pendingTags_\(noteID.uuidString)"
        if let tags = UserDefaults.standard.stringArray(forKey: key) {
            return Set(tags)
        }
        return []
    }
    
    private func savePendingTags(_ tags: Set<String>, for noteID: UUID) {
        let key = "pendingTags_\(noteID.uuidString)"
        UserDefaults.standard.set(Array(tags), forKey: key)
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Canvas
            TextEditor(text: $text)
                .font(.body)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.horizontal, 16)        // tighter horizontal gutters
                .padding(.top, 6)                // ← raise content up
                .padding(.bottom, 52)            // leave space for pills
                .background(Color(.systemBackground))
                .focused($focused)
                .onAppear { focused = true }
                .onChange(of: text) { oldValue, newValue in
                    setText(newValue)
                    scheduleSuggestions(for: newValue)   // pills update while typing
                    scheduleAutoTagPreview(for: newValue) // auto-tag preview update while typing
                }
            
            // Context bar or auto-tag preview
            if orgMode != .auto {
                ContextBar(suggestions: suggestions, onAccept: { accept($0) })
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else if !autoTagPreview.isEmpty {
                // Show pending tags with visual distinction
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Auto-detected tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Show pending tags
                    if !pendingTags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(pendingTags.prefix(6)), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Show accepted tags if any
                    if !acceptedTags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(acceptedTags.prefix(4)), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.regularMaterial)
                                    )
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !pendingTags.isEmpty {
                    HStack(spacing: 6) {
                        Text("\(pendingTags.count)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.orange)
                            )
                            .foregroundStyle(.white)
                        Text("pending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("Clear pending tags") {
                            clearPendingTags()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {      // single Done
                Button("Done") { 
                    commitPendingTags()
                    focused = false
                    dismiss() 
                }
                .disabled(pendingTags.isEmpty) // Disable if no pending tags
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Tag Management
    
    private func scheduleSuggestions(for text: String) {
        // Cancel previous debounce
        suggestionWorkItem?.cancel()
        
        // Only analyze if text actually changed meaningfully
        guard text != lastAnalyzedText else { return }
        
        // Debounce with longer delay to reduce flickering
        let workItem = DispatchWorkItem {
            self.analyzeAndUpdateSuggestions(for: text)
        }
        suggestionWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem) // increased from 0.5s
    }
    
    private func scheduleAutoTagPreview(for text: String) {
        // Separate debounce for auto-tag preview to make it more stable
        guard orgMode == .auto else { return }
        
        let workItem = DispatchWorkItem {
            self.updateAutoTagPreview(for: text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
    
    private func updateAutoTagPreview(for text: String) {
        guard !text.isEmpty else { return }
        
        let keywords = Heuristics.topKeywords(from: text)
        let newPreview = keywords.map { "#\($0)" }
        
        // Only update if preview actually changed and we have meaningful content
        if autoTagPreview != newPreview && !newPreview.isEmpty {
            withAnimation(.easeOut(duration: 0.3)) {
                autoTagPreview = newPreview
            }
        }
    }
    
    private func analyzeAndUpdateSuggestions(for text: String) {
        guard !text.isEmpty else {
            // Only clear if we had suggestions before
            if !suggestions.isEmpty {
                withAnimation(.easeOut(duration: 0.2)) {
                    suggestions = []
                }
            }
            // Clear auto-tag preview
            if !autoTagPreview.isEmpty {
                withAnimation(.easeOut(duration: 0.2)) {
                    autoTagPreview = []
                }
            }
            return
        }
        
        // Always collect tags in pendingTags while editing
        let allTags = Heuristics.extract(text)
        let newPendingTags = Set(allTags.explicit + allTags.inferred)
        
        // Update pending tags if they changed
        if pendingTags != newPendingTags {
            pendingTags = newPendingTags
            savePendingTags(pendingTags, for: noteID)
        }
        
        // Only show suggestions for tags that aren't already accepted or pending
        let availableSuggestions = Heuristics.infer(from: text).filter { suggestion in
            switch suggestion.kind {
            case .tag(let tag):
                return !acceptedTags.contains(tag) && !pendingTags.contains(tag)
            case .title:
                return true
            }
        }
        
        // Only update if suggestions actually changed
        if suggestions != availableSuggestions {
            withAnimation(.easeOut(duration: 0.2)) {
                suggestions = availableSuggestions
            }
        }
        
        // Update auto-tag preview for auto mode (show pending tags)
        if orgMode == .auto {
            // Show preview if we have any tags (pending or accepted)
            let hasTags = !pendingTags.isEmpty || !acceptedTags.isEmpty
            
            if hasTags != !autoTagPreview.isEmpty {
                withAnimation(.easeOut(duration: 0.2)) {
                    autoTagPreview = hasTags ? ["show"] : [] // Just use as a boolean flag
                }
            }
        }
        
        lastAnalyzedText = text
    }
    
    private func accept(_ suggestion: Suggestion) {
        switch suggestion.kind {
        case .tag(let tag):
            // Add to pending tags (will be committed when Done is pressed)
            if !pendingTags.contains(tag) {
                pendingTags.insert(tag)
                savePendingTags(pendingTags, for: noteID)
                
                // Update text with hashtag if not already present
                if !text.contains("#\(tag)") {
                    let insertPoint = text.endIndex
                    text.insert(contentsOf: " #\(tag)", at: insertPoint)
                }
            }
        case .title(let title):
            // Handle title suggestion
            break
        }
        
        // Remove from suggestions after accepting
        withAnimation(.easeOut(duration: 0.15)) {
            suggestions.removeAll { $0 == suggestion }
        }
    }
    
    private func commitPendingTags() {
        // Merge pending tags with accepted tags
        let newAcceptedTags = acceptedTags.union(pendingTags)
        
        // Save to master library
        saveAcceptedTags(newAcceptedTags, for: noteID)
        
        // Update local state
        acceptedTags = newAcceptedTags
        pendingTags = []
        savePendingTags([], for: noteID) // Clear pending tags after committing
        
        // Update the note text with any new tags that weren't already in the text
        var updatedText = text
        for tag in newAcceptedTags {
            if !updatedText.contains("#\(tag)") {
                updatedText += " #\(tag)"
            }
        }
        
        // Only update if text actually changed
        if updatedText != text {
            text = updatedText
            setText(updatedText)
        }
        
        // Notify library view model about the new tags
        if let libraryVM = libraryVM {
            libraryVM.commitTagsToMasterLibrary(newAcceptedTags, for: noteID)
        }
    }
    
    private func clearPendingTags() {
        withAnimation(.easeOut(duration: 0.2)) {
            pendingTags = []
        }
        savePendingTags([], for: noteID)
        
        // Remove any pending tags from the text that were added during this session
        var updatedText = text
        for tag in pendingTags {
            updatedText = updatedText.replacingOccurrences(of: " #\(tag)", with: "")
        }
        
        if updatedText != text {
            text = updatedText
            setText(updatedText)
        }
    }
}

// MARK: - GlassFAB (temporary copy)
struct GlassFAB: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)                 // white "+"
                .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)                       // solid black
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10)) // faint edge so it reads on light bg
        )
        .shadow(color: .clear, radius: 0)                // no shadow
        .buttonStyle(.plain)
    }
}

// MARK: - LibraryViewModel (temporary copy)
class LibraryViewModel: ObservableObject {
    @Published var items: [Note] = []
    @Published var trendingTopics: [Topic] = []
    
    private let topics: TopicIndex = TopicIndexInMemory()
    
    init() {
        #if DEBUG
        items = [
            Note(id: UUID(), body: "Welcome to NotesMagic! This is your first note.", createdAt: Date(), updatedAt: Date()),
            Note(id: UUID(), body: "Meeting notes from today's standup #work #meeting", createdAt: Date(), updatedAt: Date()),
            Note(id: UUID(), body: "Ideas for weekend #personal #ideas", createdAt: Date(), updatedAt: Date()),
            Note(id: UUID(), body: "Project planning for the new app launch. Need to coordinate with design team and set up development timeline.", createdAt: Date(), updatedAt: Date())
        ]
        #endif
        
        topics.rebuild(from: items)
        refreshTopics()
    }
    
    @discardableResult
    func newNote() -> Note {
        let n = Note(id: UUID(), body: "", createdAt: Date(), updatedAt: Date())
        items.insert(n, at: 0)
        topics.noteDidChange(n)
        refreshTopics()
        return n
    }
    
    // Binding helpers for EditorView
    func text(for id: UUID) -> String {
        items.first(where: { $0.id == id })?.body ?? ""
    }
    
    func update(noteID: UUID, body: String) {
        guard let i = items.firstIndex(where: { $0.id == noteID }) else { return }
        items[i].body = body
        items[i].updatedAt = Date()
        topics.noteDidChange(items[i])
        refreshTopics()
    }
    
    // Helper for better tag integration
    func noteDidChange(_ id: UUID, inferred: [String]) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        // store/update note text as you already do...
        topics.noteDidChange(items[i])   // TopicIndex handles inferred tags automatically
        refreshTopics()
    }
    
    func notes(for topic: Topic) -> [Note] { 
        topics.notes(for: topic.name) 
    }
    
    func search(_ q: String) -> (topics: [Topic], notes: [Note]) { 
        topics.search(q) 
    }
    
    func addTag(_ tag: String, to noteID: UUID) {
        topics.addTag(tag, to: noteID)
    }
    
    private func refreshTopics() {
        trendingTopics = topics.topTopics(limit: 12, windowDays: 14)
            .sorted { $0.count > $1.count } // Sort by count, highest first
    }
    
    func loadNotes() {
        // In a real app, this would load from the store
        // For now, keep the debug data
    }
    
    func create(_ body: String) -> Note {
        let note = Note(id: UUID(), body: body, createdAt: Date(), updatedAt: Date())
        items.insert(note, at: 0)
        return note
    }
    
    func update(_ note: Note) {
        guard let i = items.firstIndex(where: { $0.id == note.id }) else { return }
        items[i] = note
    }
    
    func trash(_ id: UUID) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let note = items[index]
        items.remove(at: index)
        topics.noteDidChange(note) // Pass the note before removal
        refreshTopics()
    }
    
    func commitTagsToMasterLibrary(_ tags: Set<String>, for noteID: UUID) {
        // In a real app, this would save to the store
        // For now, just print
        print("Committing tags \(tags) to master library for note \(noteID)")
    }
    
    // Expose topics for Structure Drawer
    var topicIndex: TopicIndex {
        return topics
    }
}

// MARK: - Note Model (temporary copy)
struct Note: Identifiable, Equatable {
    let id: UUID
    var body: String
    let createdAt: Date
    var updatedAt: Date
    var format: NoteFormat = .plainText
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

enum NoteFormat: String, CaseIterable {
    case plainText = "plain"
    case markdown = "md"
    case richText = "rtf"
}

// MARK: - Suggestion Types and Heuristics
public struct Suggestion: Identifiable, Equatable {
    public enum Kind: Equatable { 
        case title(String), tag(String) 
    }
    public let id = UUID()
    public let kind: Kind
    public var label: String {
        switch kind { 
            case .title(let t): return t
            case .tag(let t): return "#\(t)" 
        }
    }
}

public enum Heuristics {
    public struct Extracted {
        public var explicit: [String] = []    // #hashtags in text
        public var inferred: [String] = []    // entities + nouns
    }
    
    // Public API used by the ContextBar
    public static func infer(from text: String) -> [Suggestion] {
        let ex = extract(text)
        var out: [Suggestion] = []
        
        if let t = inferTitle(text) { out.append(.init(kind: .title(t))) }
        
        // More aggressive tagging - return more suggestions
        let allTags = (ex.explicit + ex.inferred).uniqued()
        
        // Prioritize explicit hashtags first
        let explicitTags = allTags.filter { ex.explicit.contains($0) }
        for tag in explicitTags.prefix(3) { 
            out.append(.init(kind: .tag(tag))) 
        }
        
        // Then add inferred tags (more aggressive)
        let inferredTags = allTags.filter { !ex.explicit.contains($0) }
        for tag in inferredTags.prefix(5) { // increased from 2 to 5
            out.append(.init(kind: .tag(tag))) 
        }
        
        return out
    }
    
    // MARK: - Core extraction
    
    public static func extract(_ text: String) -> Extracted {
        var result = Extracted()
        result.explicit = explicitHashtags(in: text)
        
        // NLTagger: entities + noun/proper-noun keywords
        var counts: [String:Int] = [:]
        
        if !text.isEmpty {
            let range = text.startIndex..<text.endIndex
            let tagger = NLTagger(tagSchemes: [NLTagScheme.nameType, NLTagScheme.lexicalClass, NLTagScheme.script, NLTagScheme.language])
            tagger.string = text
            
            // Named entities (strongest weight - people, places, organizations)
            tagger.enumerateTags(in: range, unit: NLTokenUnit.word, scheme: NLTagScheme.nameType,
                                 options: [NLTagger.Options.omitPunctuation, NLTagger.Options.omitWhitespace]) { tag, r in
                guard let tag else { return true }
                // Count all named entities with high weight
                let token = normalize(String(text[r]))
                if token.count > 1 { counts[token, default: 0] += 5 } // boost entities significantly
                return true
            }
            
            // Lexical analysis - nouns, verbs, adjectives, proper nouns
            tagger.enumerateTags(in: range, unit: NLTokenUnit.word, scheme: NLTagScheme.lexicalClass,
                                 options: [NLTagger.Options.omitPunctuation, NLTagger.Options.omitWhitespace]) { tag, r in
                guard let tag else { return true }
                let token = normalize(String(text[r]))
                
                // Simplified approach to avoid NLTag enum issues
                if token.count > 2 && !stopwords.contains(token) {
                    counts[token, default: 0] += 2 // all lexical tags get moderate weight
                }
                return true
            }
            
            // Extract compound phrases and technical terms
            let compoundPhrases = extractCompoundPhrases(from: text)
            for phrase in compoundPhrases {
                counts[phrase, default: 0] += 4 // compound phrases get high weight
            }
            
            // Extract technical terms and jargon
            let technicalTerms = extractTechnicalTerms(from: text)
            for term in technicalTerms {
                counts[term, default: 0] += 3
            }
            
            // Extract time-based concepts
            let timeConcepts = extractTimeConcepts(from: text)
            for concept in timeConcepts {
                counts[concept, default: 0] += 2
            }
            
            // Extract location references
            let locations = extractLocationReferences(from: text)
            for location in locations {
                counts[location, default: 0] += 3
            }
            
            // Extract emotional/sentiment indicators
            let emotions = extractEmotionalIndicators(from: text)
            for emotion in emotions {
                counts[emotion, default: 0] += 2
            }
        }
        
        // Fallback if NLTagger yields nothing (rare / short text)
        if counts.isEmpty {
            let words = text.lowercased().split { !"abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }
            for w in words {
                let t = normalize(String(w))
                if t.count > 2 && !stopwords.contains(t) { counts[t, default: 0] += 1 }
            }
        }
        
        // Rank, de-dupe explicit, and cap
        let ranked = counts.sorted { $0.value > $1.value }.map(\.key)
        result.inferred = ranked.filter { !result.explicit.contains($0) }.prefix(3).map { String($0) }
        return result
    }
    
    // Simple first-sentence title if it looks meaningful
    private static func inferTitle(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return nil }
        if let i = trimmed.firstIndex(where: { ".!?".contains($0) }) {
            let first = trimmed[..<i].trimmingCharacters(in: .whitespaces)
            return (8...60).contains(first.count) ? first : nil
        }
        return nil
    }
    
    // MARK: - Utilities
    
    private static func explicitHashtags(in text: String) -> [String] {
        let rx = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
        let ns = text as NSString
        return rx.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)).lowercased() }
    }
    
    // MARK: - Advanced Extraction Methods
    
    private static func extractCompoundPhrases(from text: String) -> [String] {
        var phrases: [String] = []
        let words = text.lowercased().split { !"abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }.map(String.init)
        
        // Look for 2-3 word combinations that might be meaningful
        for i in 0..<words.count-1 {
            let phrase = "\(words[i])-\(words[i+1])"
            if words[i].count > 2 && words[i+1].count > 2 && !stopwords.contains(words[i]) && !stopwords.contains(words[i+1]) {
                phrases.append(phrase)
            }
            
            // 3-word phrases
            if i < words.count-2 {
                let phrase3 = "\(words[i])-\(words[i+1])-\(words[i+2])"
                if words[i].count > 2 && words[i+1].count > 2 && words[i+2].count > 2 &&
                   !stopwords.contains(words[i]) && !stopwords.contains(words[i+1]) && !stopwords.contains(words[i+2]) {
                    phrases.append(phrase3)
                }
            }
        }
        return phrases
    }
    
    private static func extractTechnicalTerms(from text: String) -> [String] {
        var terms: [String] = []
        let technicalPatterns = [
            "\\b[A-Z][a-z]+(?:[A-Z][a-z]+)*\\b", // CamelCase terms
            "\\b[A-Z]{2,}\\b", // Acronyms
            "\\b\\w+\\d+\\w*\\b", // Words with numbers
            "\\b\\w+[-_]\\w+\\b" // Words with hyphens/underscores
        ]
        
        for pattern in technicalPatterns {
            if let rx = try? NSRegularExpression(pattern: pattern) {
                let ns = text as NSString
                let matches = rx.matches(in: text, range: NSRange(location: 0, length: ns.length))
                for match in matches {
                    let term = ns.substring(with: match.range).lowercased()
                    if term.count > 2 && !stopwords.contains(term) {
                        terms.append(term)
                    }
                }
            }
        }
        return terms
    }
    
    private static func extractTimeConcepts(from text: String) -> [String] {
        var concepts: [String] = []
        let timeWords = Set([
            "today", "yesterday", "tomorrow", "morning", "afternoon", "evening", "night",
            "week", "month", "year", "decade", "century", "season", "spring", "summer", "fall", "winter",
            "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "hour", "minute", "second", "moment", "instant", "period", "era", "age"
        ])
        
        let words = text.lowercased().split { !"abcdefghijklmnopqrstuvwxyz".contains($0) }.map(String.init)
        for word in words {
            if timeWords.contains(word) {
                concepts.append(word)
            }
        }
        return concepts
    }
    
    private static func extractLocationReferences(from text: String) -> [String] {
        var locations: [String] = []
        let locationWords = Set([
            "home", "office", "work", "school", "university", "college", "hospital", "store", "shop", "market",
            "park", "garden", "beach", "mountain", "forest", "city", "town", "village", "country", "state",
            "street", "avenue", "road", "highway", "airport", "station", "terminal", "building", "house", "apartment"
        ])
        
        let words = text.lowercased().split { !"abcdefghijklmnopqrstuvwxyz".contains($0) }.map(String.init)
        for word in words {
            if locationWords.contains(word) {
                locations.append(word)
            }
        }
        return locations
    }
    
    private static func extractEmotionalIndicators(from text: String) -> [String] {
        var emotions: [String] = []
        let emotionalWords = Set([
            "happy", "sad", "angry", "excited", "worried", "anxious", "calm", "stressed", "relaxed", "frustrated",
            "satisfied", "disappointed", "surprised", "confused", "confident", "nervous", "proud", "ashamed", "grateful", "jealous",
            "love", "hate", "like", "dislike", "enjoy", "enjoyed", "enjoying", "hate", "hated", "hating"
        ])
        
        let words = text.lowercased().split { !"abcdefghijklmnopqrstuvwxyz".contains($0) }.map(String.init)
        for word in words {
            if emotionalWords.contains(word) {
                emotions.append(word)
            }
        }
        return emotions
    }
    
    private static func normalize(_ s: String) -> String {
        var t = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        t = t.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        return t.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    private static let stopwords: Set<String> = [
        "the","a","an","and","or","to","for","of","in","on","is","are","this","that","with","from",
        "just","note","notes","today","here","about","into","over","more","less","very","really","first",
        "my","our","your","their","am","im","i'm","ive","i've","lets","let's","she","he","they","them"
    ]
    
    // Legacy method for backward compatibility
    public static func topKeywords(from text: String) -> [String] {
        let extracted = extract(text)
        return Array(extracted.inferred.prefix(2))
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - ContextBar for AI Suggestions
public struct ContextBar: View {
    let suggestions: [Suggestion]
    let onAccept: (Suggestion) -> Void
    
    public init(suggestions: [Suggestion], onAccept: @escaping (Suggestion) -> Void) {
        self.suggestions = suggestions
        self.onAccept = onAccept
    }
    
    public var body: some View {
        if suggestions.isEmpty { 
            EmptyView() 
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { s in
                        Button {
                            onAccept(s)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: icon(for: s))
                                    .font(.system(size: 12, weight: .semibold))
                                Text(s.label)
                                    .font(.caption)
                            }
                            .pillStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeOut(duration: 0.12), value: suggestions.count)
        }
    }
    
    private func icon(for s: Suggestion) -> String {
        switch s.kind { 
            case .title: return "textformat"
            case .tag: return "number" 
        }
    }
}

// MARK: - Pill Style Modifier
extension View {
    func pillStyle() -> some View {
        self
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            )
    }
}

// MARK: - Organization Mode
enum OrganizationMode: String, CaseIterable {
    case keepRaw, suggest, auto
}

// MARK: - Topic Model and Index Protocol
struct Topic: Identifiable, Hashable {
    var id: String { name.lowercased() }
    let name: String
    var count: Int
    var lastUsedAt: Date
    var score: Double
    
    init(name: String, count: Int, lastUsedAt: Date, score: Double) {
        self.name = name
        self.count = count
        self.lastUsedAt = lastUsedAt
        self.score = score
    }
}

protocol TopicIndex {
    func rebuild(from notes: [Note])
    func noteDidChange(_ note: Note)
    func topTopics(limit: Int, windowDays: Int) -> [Topic]
    func notes(for topicName: String) -> [Note]
    func search(_ query: String) -> (topics: [Topic], notes: [Note])
    func addTag(_ tag: String, to noteID: UUID)
    func topicsWithScores() -> [(name: String, count: Int, lastUsedAt: Date, score: Double)]
    func relatedTopics(for topic: String, limit: Int) -> [String]
}

// MARK: - TopicIndexInMemory Implementation
final class TopicIndexInMemory: TopicIndex {
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
    
    init() {}
    
    func rebuild(from notes: [Note]) {
        posting.removeAll()
        when.removeAll()
        inferredPosting.removeAll()
        inferredWhen.removeAll()
        scoreCache.removeAll()
        lastUsed.removeAll()
        notesByID.removeAll()
        for n in notes { index(n) }
    }
    
    func noteDidChange(_ note: Note) {
        if let old = notesByID[note.id] {
            for t in Self.explicit(from: old.body) { posting[t]?.remove(old.id) }
            for t in Self.infer(from: old.body) { inferredPosting[t]?.remove(old.id) }
        }
        index(note)
    }
    
    func topTopics(limit: Int, windowDays: Int) -> [Topic] {
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
    
    func notes(for topicName: String) -> [Note] {
        let key = topicName.lowercased()
        let ids = (posting[key] ?? []).union(inferredPosting[key] ?? [])
        return ids.compactMap { notesByID[$0] }.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    func search(_ q: String) -> (topics: [Topic], notes: [Note]) {
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
    
    func addTag(_ tag: String, to noteID: UUID) {
        let lowerTag = tag.lowercased()
        posting[lowerTag, default: []].insert(noteID)
        when[lowerTag, default: []].append(Date())
        lastUsed[lowerTag] = Date()
        scoreCache.removeAll()
    }
    
    func topicsWithScores() -> [(name: String, count: Int, lastUsedAt: Date, score: Double)] {
        let now = Date()
        let all = Set(posting.keys).union(inferredPosting.keys)
        return all.map { topicName in
            let count = (posting[topicName]?.count ?? 0) + (inferredPosting[topicName]?.count ?? 0)
            let lastUsedAt = lastUsed[topicName] ?? .distantPast
            let score = score(for: topicName, now: now)
            return (name: topicName, count: count, lastUsedAt: lastUsedAt, score: score)
        }.sorted { $0.score > $1.score }
    }
    
    func relatedTopics(for topic: String, limit: Int) -> [String] {
        let lowerTopic = topic.lowercased()
        let now = Date()
        let window = now.addingTimeInterval(-86_400 * 7) // 7 days
        
        let notesInTopic = notes(for: topic).filter { $0.updatedAt >= window }
        
        var coOccurrenceCounts: [String: Int] = [:]
        
        for note in notesInTopic {
            let noteTags = Self.explicit(from: note.body)
            for tag in noteTags {
                if tag.lowercased() != lowerTopic {
                    coOccurrenceCounts[tag.lowercased(), default: 0] += 1
                }
            }
        }
        
        // Also check for inferred tags
        for note in notesInTopic {
            let noteTags = Self.infer(from: note.body)
            for tag in noteTags {
                if tag.lowercased() != lowerTopic {
                    coOccurrenceCounts[tag.lowercased(), default: 0] += 1
                }
            }
        }
        
        let sortedTags = coOccurrenceCounts.sorted { $0.value > $1.value }.prefix(limit).map(\.key)
        return sortedTags
    }
    
    // MARK: - Internals
    
    private func index(_ note: Note) {
        notesByID[note.id] = note
        let now = Date()
        
        // explicit hashtags in the text
        for raw in Self.explicit(from: note.body) {
            let t = raw.lowercased()
            posting[t, default: []].insert(note.id)
            when[t, default: []].append(now)
            lastUsed[t] = max(lastUsed[t] ?? .distantPast, note.updatedAt)
        }
        // inferred tags from keywords (auto-applied; keep out of the body)
        for raw in Self.infer(from: note.body) {
            let t = raw.lowercased()
            inferredPosting[t, default: []].insert(note.id)
            inferredWhen[t, default: []].append(now)
            lastUsed[t] = max(lastUsed[t] ?? .distantPast, note.updatedAt)
        }
        scoreCache.removeAll()
    }
    
    private func score(for tag: String, now: Date) -> Double {
        if let s = scoreCache[tag] { return s }
        let halfLife = 7.0
        let exp = (when[tag] ?? []).reduce(0.0) { acc, d in
            acc + pow(0.5, now.timeIntervalSince(d) / 86_400.0 / halfLife)
        }
        let inf = (inferredWhen[tag] ?? []).reduce(0.0) { acc, d in
            acc + 0.7 * pow(0.5, now.timeIntervalSince(d) / 86_400.0 / halfLife) // lighter weight
        }
        let unique = Double((posting[tag]?.count ?? 0)) * 0.3 + Double((inferredPosting[tag]?.count ?? 0)) * 0.2
        let s = exp + inf + unique
        scoreCache[tag] = s
        return s
    }
    
    // Explicit hashtags
    private static func explicit(from text: String) -> [String] {
        let ns = text as NSString
        return tagRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)) }
    }
    
    // Inferred tags: top 2 keywords (simple, local)
    private static func infer(from text: String) -> [String] {
        let lowers = text.lowercased()
        let keep = lowers.split { !"abcdefghijklmnopqrstuvwxyz0123456789#-_".contains($0) }.map(String.init)
            .filter { !$0.hasPrefix("#") && $0.count > 3 && !stopwords.contains($0) }
        var counts: [String:Int] = [:]
        keep.forEach { counts[$0, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(2).map(\.key)
    }
    
    private static let stopwords: Set<String> = [
        "the","a","an","and","or","to","for","of","in","on","is","are","this","that","with","from",
        "just","note","notes","today","here","about","into","over","more","less","very","really"
    ]
}

// MARK: - TopicsStrip Component
struct TopicsStrip: View {
    let topics: [Topic]
    let onTap: (Topic) -> Void
    
    var body: some View {
        if topics.isEmpty { 
            EmptyView() 
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topics) { t in
                        Button { onTap(t) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "number")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(t.name)
                                    .font(.caption)
                                Text("\(t.count)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(.systemGray6))
                                    )
                            }
                            .pillStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .accessibilityLabel("Trending topics")
        }
    }
}

// MARK: - TopicView Component
struct TopicView: View {
    let topicName: String
    let notes: [Note]
    
    var body: some View {
        List {
            Section("#\(topicName)") {
                ForEach(notes) { n in
                    Text(n.body.isEmpty ? "Untitled" : n.body)
                        .lineLimit(2)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("#\(topicName)")
    }
}

// MARK: - StructureViewModel (temporary copy)
class StructureViewModel: ObservableObject {
    @Published var categories: [TagCategory] = []
    @Published var categorizedTopics: [String: [TopicChip]] = [:]
    @Published var searchQuery: String = ""
    @Published var searchResults: (topics: [TopicChip], notes: [Note]) = ([], [])
    
    private let topicIndex: TopicIndex
    private let notesProvider: () -> [Note]
    private var manualOverrides: [String: String] = [:]
    
    init(topicIndex: TopicIndex, notesProvider: @escaping () -> [Note]) {
        self.topicIndex = topicIndex
        self.notesProvider = notesProvider
        loadDefaultCategories()
        loadManualOverrides()
        categorizeTopics()
    }
    
    func search(_ query: String) {
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
    
    func assignTopic(_ topicName: String, to categoryID: String?) {
        if let categoryID = categoryID {
            manualOverrides[topicName] = categoryID
        } else {
            manualOverrides.removeValue(forKey: topicName)
        }
        saveManualOverrides()
        categorizeTopics()
    }
    
    private func loadDefaultCategories() {
        let defaults = [
            TagCategory(id: "people", name: "People", emoji: "👤", rules: [], pinned: true, order: 0),
            TagCategory(id: "family", name: "Family", emoji: "👪", rules: [], pinned: true, order: 1),
            TagCategory(id: "friends", name: "Friends", emoji: "👫", rules: [], pinned: true, order: 2),
            TagCategory(id: "projects", name: "Projects", emoji: "🚀", rules: [], pinned: true, order: 3),
            TagCategory(id: "work", name: "Work", emoji: "💼", rules: [], pinned: true, order: 4),
            TagCategory(id: "places", name: "Places", emoji: "📍", rules: [], pinned: true, order: 5),
            TagCategory(id: "reading", name: "Reading", emoji: "📚", rules: [], pinned: true, order: 6),
            TagCategory(id: "ideas", name: "Ideas", emoji: "💡", rules: [], pinned: true, order: 7),
            TagCategory(id: "meetings", name: "Meetings", emoji: "🗓️", rules: [], pinned: true, order: 8)
        ]
        
        categories = loadCategories() ?? defaults
        saveCategories()
    }
    
    private func loadManualOverrides() {
        if let data = UserDefaults.standard.data(forKey: "StructureManualOverrides") {
            if let overrides = try? JSONDecoder().decode([String: String].self, from: data) {
                manualOverrides = overrides
            }
        }
    }
    
    private func saveManualOverrides() {
        if let data = try? JSONEncoder().encode(manualOverrides) {
            UserDefaults.standard.set(data, forKey: "StructureManualOverrides")
        }
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
        
        // Simple keyword-based categorization for now
        if lowerName.contains("meeting") || lowerName.contains("standup") || lowerName.contains("retro") {
            return "meetings"
        }
        if lowerName.contains("project") || lowerName.contains("plan") || lowerName.contains("launch") {
            return "projects"
        }
        if lowerName.contains("work") || lowerName.contains("okr") || lowerName.contains("prd") {
            return "work"
        }
        if lowerName.contains("read") || lowerName.contains("watch") || lowerName.contains("article") {
            return "reading"
        }
        if lowerName.contains("idea") || lowerName.contains("what if") {
            return "ideas"
        }
        
        return nil
    }
    
    private func getCategory(for topicName: String) -> String? {
        return manualOverrides[topicName] ?? categorize(topicName, notes: notesProvider())
    }
    
    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: "StructureCategories")
        }
    }
    
    private func loadCategories() -> [TagCategory]? {
        guard let data = UserDefaults.standard.data(forKey: "StructureCategories") else { return nil }
        return try? JSONDecoder().decode([TagCategory].self, from: data)
    }
}

// MARK: - StructureDrawerView (temporary copy)
struct StructureDrawerView: View {
    @StateObject private var viewModel: StructureViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var selectedTopic: TopicChip?
    
    let applyFilter: (String) -> Void
    
    init(viewModel: StructureViewModel, applyFilter: @escaping (String) -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.applyFilter = applyFilter
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if viewModel.searchQuery.isEmpty {
                    categoriesList
                } else {
                    searchResults
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 20) // Add bottom padding to prevent content cutoff
            .navigationTitle("Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAssignSheet) {
            if let topic = selectedTopic {
                AssignToGroupSheet(
                    topic: topic,
                    categories: viewModel.categories,
                    onAssign: { categoryID in
                        viewModel.assignTopic(topic.name, to: categoryID)
                        showingAssignSheet = false
                    }
                )
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search topics and notes...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .onChange(of: viewModel.searchQuery) { _, newValue in
                    viewModel.search(newValue)
                }
            
            if !viewModel.searchQuery.isEmpty {
                Button("Clear") {
                    viewModel.searchQuery = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var categoriesList: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(viewModel.categories.sorted(by: { $0.order < $1.order })) { category in
                    CategorySection(
                        category: category,
                        topics: viewModel.categorizedTopics[category.id] ?? [],
                        onTopicTap: { topic in
                            applyFilter(topic.name)
                            dismiss()
                        },
                        onTopicLongPress: { topic in
                            selectedTopic = topic
                            showingAssignSheet = true
                        }
                    )
                }
                
                // Ungrouped section
                if let ungrouped = viewModel.categorizedTopics["ungrouped"], !ungrouped.isEmpty {
                    CategorySection(
                        category: TagCategory(id: "ungrouped", name: "Ungrouped", emoji: "📁", rules: [], pinned: false, order: 999),
                        topics: ungrouped,
                        onTopicTap: { topic in
                            applyFilter(topic.name)
                            dismiss()
                        },
                        onTopicLongPress: { topic in
                            selectedTopic = topic
                            showingAssignSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var searchResults: some View {
        List {
            if !viewModel.searchResults.topics.isEmpty {
                Section("Topics") {
                    ForEach(viewModel.searchResults.topics) { topic in
                        TopicChipView(
                            topic: topic,
                            onTap: {
                                applyFilter(topic.name)
                                dismiss()
                            },
                            onLongPress: {
                                selectedTopic = topic
                                showingAssignSheet = true
                            }
                        )
                    }
                }
            }
            
            if !viewModel.searchResults.notes.isEmpty {
                Section("Notes") {
                    ForEach(viewModel.searchResults.notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.body.prefix(100))
                                .lineLimit(2)
                            Text(note.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Supporting Views

private struct CategorySection: View {
    let category: TagCategory
    let topics: [TopicChip]
    let onTopicTap: (TopicChip) -> Void
    let onTopicLongPress: (TopicChip) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                Text(category.emoji)
                    .font(.title2)
                
                Text(category.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(topics.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
            }
            
            // Topic chips
            if topics.isEmpty {
                Text("No topics yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
                ], spacing: 8) {
                    ForEach(topics) { topic in
                        TopicChipView(
                            topic: topic,
                            onTap: { onTopicTap(topic) },
                            onLongPress: { onTopicLongPress(topic) }
                        )
                    }
                }
            }
        }
    }
}

private struct TopicChipView: View {
    let topic: TopicChip
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(topic.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text("\(topic.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            onLongPress()
        }
    }
}

private struct AssignToGroupSheet: View {
    let topic: TopicChip
    let categories: [TagCategory]
    let onAssign: (String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Assign '\(topic.name)' to group:") {
                    Button("Ungrouped") {
                        onAssign(nil)
                    }
                    .foregroundColor(.primary)
                    
                    ForEach(categories.sorted(by: { $0.order < $1.order })) { category in
                        Button("\(category.emoji) \(category.name)") {
                            onAssign(category.id)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Assign to Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Models

struct TagCategory: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var emoji: String
    var rules: [String] // Simplified for now
    var pinned: Bool
    var order: Int
}

struct TopicChip: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let count: Int
    let category: String?
    let isPinned: Bool
    
    var score: Double {
        return Double(count)
    }
}

// MARK: - SidePanel (temporary copy)
struct SidePanel<Content: View>: View {
    @Binding var isOpen: Bool
    var widthRatio: CGFloat = 0.86
    var edge: Edge = .leading
    @ViewBuilder let content: () -> Content
    
    init(isOpen: Binding<Bool>, widthRatio: CGFloat = 0.86, edge: Edge = .leading, @ViewBuilder content: @escaping () -> Content) {
        _isOpen = isOpen
        self.widthRatio = widthRatio
        self.edge = edge
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let panelW = geo.size.width * widthRatio
            ZStack(alignment: edge == .leading ? .leading : .trailing) {
                // Scrim
                Color.black.opacity(isOpen ? 0.22 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { 
                        withAnimation(.easeOut(duration: 0.18)) { 
                            isOpen = false 
                        } 
                    }
                    .allowsHitTesting(isOpen)
                
                // Panel
                content()
                    .frame(width: panelW)
                    .background(.ultraThinMaterial)
                    .overlay(Divider().opacity(0.08), alignment: edge == .leading ? .trailing : .leading)
                    .offset(x: offset(panelW))
                    .transition(.move(edge: edge))
                    .gesture(drag(panelW))
            }
            .animation(.easeOut(duration: 0.22), value: isOpen)
        }
    }
    
    private func offset(_ w: CGFloat) -> CGFloat {
        if isOpen { return 0 }
        return edge == .leading ? -w : w
    }
    
    private func drag(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onEnded { v in
                let close = edge == .leading ? v.translation.width < -30 : v.translation.width > 30
                if close { isOpen = false }
            }
    }
}

// MARK: - StructureVM (temporary copy)
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
    
    private let notesProvider: () -> [Note]
    private let topicIndex: TopicIndex?
    
    @Published var groups: [Group] = []
    
    init(topicIndex: TopicIndex?, notesProvider: @escaping () -> [Note]) {
        self.topicIndex = topicIndex
        self.notesProvider = notesProvider
        refresh()
    }
    
    func refresh() {
        let notes = notesProvider()
        let topics = topicsWithScores(notes: notes)
        var out: [Group] = []
        
        let people = entity(namesIn: notes, kind: .personalName)
            .compactMap { name in topics.first { $0.name == name } }
        if !people.isEmpty { 
            out.append(.init(id: "people", title: "People", emoji: "👤", topics: people)) 
        }
        
        let places = entity(namesIn: notes, kind: .placeName)
            .compactMap { topics.first(name: $0) }
        if !places.isEmpty { 
            out.append(.init(id: "places", title: "Places", emoji: "📍", topics: places)) 
        }
        
        let projects = topics.filter { 
            $0.count >= 3 || $0.name.containsAny(of: ["project","launch","roadmap","spec","plan"]) 
        }
        if !projects.isEmpty { 
            out.append(.init(id: "projects", title: "Projects", emoji: "🚀", topics: projects)) 
        }
        
        let work = topics.filter { 
            $0.name.containsAny(of: ["work","meeting","standup","okr","brief","client"]) 
        }
        if !work.isEmpty { 
            out.append(.init(id: "work", title: "Work", emoji: "💼", topics: work)) 
        }
        
        let ideas = topics.filter { 
            $0.name.containsAny(of: ["idea","ideas"]) 
        }
        if !ideas.isEmpty { 
            out.append(.init(id: "ideas", title: "Ideas", emoji: "💡", topics: ideas)) 
        }
        
        // Only non-empty groups, sorted by total score
        groups = out
            .map { g in 
                Group(
                    id: g.id, 
                    title: g.title, 
                    emoji: g.emoji, 
                    topics: g.topics.sorted { $0.score > $1.score }.prefix(12).map{$0}
                ) 
            }
            .sorted { 
                $0.topics.reduce(0){$0+$1.score} > $1.topics.reduce(0){$0+$1.score} 
            }
    }
    
    // MARK: topic building
    
    private func topicsWithScores(notes: [Note]) -> [Topic] {
        if let idx = topicIndex {
            let exposed = idx.topicsWithScores()
            return exposed.map {
                Topic(name: $0.name, count: $0.count, lastUsed: $0.lastUsedAt, score: $0.score)
            }
        }
        
        var counts: [String:(c:Int, last:Date)] = [:]
        let now = Date()
        for n in notes {
            let tags = explicitTags(in: n.body) + keywords(from: n.body)
            for t in Set(tags) {
                counts[t, default: (0, .distantPast)].c += 1
                counts[t]!.last = max(counts[t]!.last, n.updatedAt)
            }
        }
        return counts.map { (name, val) in
            let age = now.timeIntervalSince(val.last)
            let recency = exp(-age / (14 * 86_400))           // 14d half-life-ish
            return Topic(name: name, count: val.c, lastUsed: val.last, score: Double(val.c) * (0.6 + 0.4*recency))
        }
    }
    
    private func explicitTags(in text: String) -> [String] {
        let rx = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
        let ns = text as NSString
        return rx.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)).lowercased() }
    }
    
    private func keywords(from text: String) -> [String] {
        text.lowercased()
            .split { !"abcdefghijklmnopqrstuvwxyz0123456789-".contains($0) }
            .map(String.init)
            .filter { $0.count > 3 && !$0.hasPrefix("#") }
    }
    
    private func entity(namesIn notes: [Note], kind: NLTag) -> [String] {
        var set = Set<String>()
        let tagger = NLTagger(tagSchemes: [.nameType])
        for n in notes {
            tagger.string = n.body
            tagger.enumerateTags(
                in: n.body.startIndex..<n.body.endIndex, 
                unit: .word, 
                scheme: .nameType, 
                options: [.omitPunctuation,.omitWhitespace,.joinNames]
            ) { tag, range in
                if tag == kind {
                    set.insert(String(n.body[range]))
                }
                return true
            }
        }
        return Array(set)
    }
}

// MARK: - StructurePanelView (temporary copy)
struct StructurePanelView: View {
    @ObservedObject var vm: StructureVM
    var onPick: (String) -> Void
    var onClose: () -> Void
    
    init(vm: StructureVM, onPick: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.vm = vm
        self.onPick = onPick
        self.onClose = onClose
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.groups) { group in
                        Section {
                            WrapChips(items: group.topics.map { "#\($0.name)" }, onTap: { topicString in
                                let topicName = topicString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                                onPick(topicName)
                            })
                        } header: {
                            HStack(spacing: 10) {
                                Text(group.emoji).font(.title3)
                                Text(group.title).font(.headline)
                                Spacer()
                                Text("\(group.topics.count)").font(.footnote).foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 20) // Add bottom padding to prevent content cutoff
            .navigationTitle("Structure")
            .toolbar { 
                ToolbarItem(placement: .topBarTrailing) { 
                    Button("Done", action: onClose) 
                } 
            }
            .onAppear { vm.refresh() }
        }
    }
}

// MARK: - Supporting Views

private struct WrapChips: View {
    let items: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        FlexibleHStack(items: items, onTap: onTap)
    }
}

private struct FlexibleHStack: View {
    let items: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .alignmentGuide(.leading, computeValue: { d in
                    if abs(width - d.width) > geometry.size.width {
                        width = 0
                        height -= d.height
                    }
                    let result = width
                    if item == items.last {
                        width = 0
                    } else {
                        width -= d.width
                    }
                    return result
                })
                .alignmentGuide(.top, computeValue: { d in
                    let result = height
                    if item == items.last {
                        height = 0
                    }
                    return result
                })
            }
        }
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

#Preview {
    ContentView()
}

// MARK: - IdentifiableString Helper
struct IdentifiableString: Identifiable {
    let id = UUID()
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
}

// MARK: - TopicHubView (temporary copy)
struct TopicHubView: View {
    let topic: String
    @StateObject private var viewModel: TopicHubViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingActionSheet = false
    @State private var selectedAction: TopicAction?
    
    init(topic: String, index: TopicIndex) {
        self.topic = topic
        self._viewModel = StateObject(wrappedValue: TopicHubViewModel(topic: topic, index: index))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                
                if !viewModel.summary.isEmpty {
                    section("Summary", viewModel.summary.map { IdentifiableString($0) }) { Text("• " + $0.text) }
                }
                
                if !viewModel.people.isEmpty {
                    chips("People", viewModel.people)
                }
                
                if !viewModel.openLoops.isEmpty {
                    section("Open Loops", viewModel.openLoops) { Text($0.title) }
                }
                
                if !viewModel.highlights.isEmpty {
                    section("Highlights", viewModel.highlights) { HighlightRow(highlight: $0) }
                }
                
                if !viewModel.timeline.isEmpty {
                    timelineSection
                }
                
                if !viewModel.related.isEmpty {
                    chips("Related", viewModel.related.map { "#\($0)" })
                }
            }
            .padding(16)
        }
        .navigationTitle("#\(topic)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                hubMenu
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📝")
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(topic)")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        Label("\(viewModel.notes.count) notes", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !viewModel.people.isEmpty {
                            Label("\(viewModel.people.count) people", systemImage: "person.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastUpdated = viewModel.lastUpdated {
                            Label(lastUpdated, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Quick stats
            HStack(spacing: 12) {
                StatCard(title: "Notes", value: "\(viewModel.notes.count)")
                StatCard(title: "People", value: "\(viewModel.people.count)")
                StatCard(title: "Open Loops", value: "\(viewModel.openLoops.count)")
            }
        }
        .padding(.bottom, 8)
    }
    
    private func section<T: Identifiable>(_ title: String, _ items: [T], @ViewBuilder content: @escaping (T) -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    content(item)
                        .font(.body)
                        .lineLimit(3)
                }
            }
            .padding(.leading, 8)
        }
    }
    
    private func chips(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
            ], spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray5))
                        )
                }
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.timeline, id: \.0) { date, notes in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(date, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(notes) { note in
                            HStack {
                                Text(note.body.prefix(80))
                                    .font(.caption)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Button("Open") {
                                    // Navigate to note
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
    
    private var hubMenu: some View {
        Menu {
            Button("Pin Topic") {
                selectedAction = .pin
            }
            
            Button("Rename Topic") {
                selectedAction = .rename
            }
            
            Button("Merge with...") {
                selectedAction = .merge
            }
            
            Divider()
            
            Button("Refresh") {
                viewModel.refresh()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

// MARK: - Supporting Views for TopicHubView

private struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

private struct HighlightRow: View {
    let highlight: Highlight
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("💡")
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.text)
                    .font(.body)
                    .lineLimit(3)
                
                HStack {
                    Text("from note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Open") {
                        // Navigate to note at specific range
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - TopicHubViewModel (temporary copy)
class TopicHubViewModel: ObservableObject {
    let topic: String
    private let index: TopicIndex
    
    @Published var notes: [Note] = []
    @Published var summary: [String] = []
    @Published var people: [String] = []
    @Published var openLoops: [LoopItem] = []
    @Published var highlights: [Highlight] = []
    @Published var timeline: [(Date, [Note])] = []
    @Published var related: [String] = []
    @Published var lastUpdated: String?
    
    init(topic: String, index: TopicIndex) {
        self.topic = topic
        self.index = index
    }
    
    func refresh() {
        notes = index.notes(for: topic)
        people = Entities.people(in: notes)
        openLoops = Extractors.openLoops(in: notes)
        highlights = Extractors.highlights(in: notes, topic: topic)
        summary = Summarize.sentences(from: notes, topic: topic, limit: 5)
        timeline = Grouping.timeline(notes, days: 30)
        related = index.relatedTopics(for: topic, limit: 10)
        
        // Calculate last updated
        if let mostRecent = notes.max(by: { $0.updatedAt < $1.updatedAt }) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lastUpdated = formatter.localizedString(for: mostRecent.updatedAt, relativeTo: Date())
        }
    }
}

// MARK: - Supporting Models for TopicHubView

struct LoopItem: Identifiable {
    let id = UUID()
    let title: String
    let noteID: UUID
    let range: Range<String.Index>
    
    init(title: String, noteID: UUID, range: Range<String.Index>) {
        self.title = title
        self.noteID = noteID
        self.range = range
    }
}

struct Highlight: Identifiable {
    let id = UUID()
    let text: String
    let noteID: UUID
    let range: Range<String.Index>
    
    init(text: String, noteID: UUID, range: Range<String.Index>) {
        self.text = text
        self.noteID = noteID
        self.range = range
    }
}

enum TopicAction: Identifiable {
    case pin, rename, merge
    
    var id: String {
        switch self {
        case .pin: return "pin"
        case .rename: return "rename"
        case .merge: return "merge"
        }
    }
}

// MARK: - Helper Classes for TopicHubView

private enum Entities {
    static func people(in notes: [Note]) -> [String] {
        var people: Set<String> = []
        
        for note in notes {
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = note.body
            
            tagger.enumerateTags(in: note.body.startIndex..<note.body.endIndex, 
                                unit: .word, 
                                scheme: .nameType) { tag, range in
                if tag == .personalName {
                    let name = String(note.body[range])
                    if name.count > 2 && !name.contains(" ") {
                        people.insert(name)
                    }
                }
                return true
            }
        }
        
        return Array(people).sorted()
    }
}

private enum Extractors {
    static func openLoops(in notes: [Note]) -> [LoopItem] {
        var loops: [LoopItem] = []
        
        for note in notes {
            let body = note.body
            
            // TODO patterns
            let todoPattern = try! NSRegularExpression(pattern: "TODO:\\s*(.+)", options: .caseInsensitive)
            let matches = todoPattern.matches(in: body, range: NSRange(location: 0, length: body.count))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: body) {
                    let title = String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        loops.append(LoopItem(title: title, noteID: note.id, range: range))
                    }
                }
            }
            
            // Question patterns
            let questionPattern = try! NSRegularExpression(pattern: "([^.!?]+\\?)", options: .caseInsensitive)
            let questionMatches = questionPattern.matches(in: body, range: NSRange(location: 0, length: body.count))
            
            for match in questionMatches {
                if let range = Range(match.range(at: 1), in: body) {
                    let title = String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty && title.count < 100 {
                        loops.append(LoopItem(title: title, noteID: note.id, range: range))
                    }
                }
            }
        }
        
        return loops
    }
    
    static func highlights(in notes: [Note], topic: String) -> [Highlight] {
        var highlights: [Highlight] = []
        
        for note in notes {
            let sentences = note.body.components(separatedBy: .init(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            for sentence in sentences {
                let lowerSentence = sentence.lowercased()
                let lowerTopic = topic.lowercased()
                
                // Check if sentence contains the topic or entities
                if lowerSentence.contains(lowerTopic) || 
                   lowerSentence.contains("meeting") || 
                   lowerSentence.contains("project") ||
                   lowerSentence.contains("idea") {
                    
                    let length = sentence.count
                    if length >= 80 && length <= 180 {
                        let startIndex = note.body.firstIndex(of: sentence.first!) ?? note.body.startIndex
                        let endIndex = note.body.index(startIndex, offsetBy: sentence.count)
                        let range = startIndex..<endIndex
                        
                        highlights.append(Highlight(text: sentence, noteID: note.id, range: range))
                        
                        if highlights.count >= 3 {
                            break
                        }
                    }
                }
            }
        }
        
        return highlights
    }
}

private enum Summarize {
    static func sentences(from notes: [Note], topic: String, limit: Int) -> [String] {
        var scoredSentences: [(sentence: String, score: Double)] = []
        
        for note in notes {
            let sentences = note.body.components(separatedBy: .init(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.count > 20 }
            
            for sentence in sentences {
                let lowerSentence = sentence.lowercased()
                let lowerTopic = topic.lowercased()
                
                // Score based on topic frequency and recency
                var score = 0.0
                
                // Topic frequency
                let topicCount = lowerSentence.components(separatedBy: lowerTopic).count - 1
                score += Double(topicCount) * 10.0
                
                // Recency boost
                let daysSinceUpdate = Date().timeIntervalSince(note.updatedAt) / (24.0 * 60.0 * 60.0)
                let maxDays = Swift.max(0.0, 30.0 - daysSinceUpdate)
                let recencyBoost = maxDays / 30.0
                score += recencyBoost * 5.0
                
                // Length bonus (prefer medium-length sentences)
                let length = sentence.count
                if length >= 50 && length <= 150 {
                    score += 2.0
                }
                
                scoredSentences.append((sentence: sentence, score: score))
            }
        }
        
        // Sort by score and take top sentences
        return scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.sentence }
    }
}

private enum Grouping {
    static func timeline(_ notes: [Note], days: Int) -> [(Date, [Note])] {
        let calendar = Calendar.current
        let now = Date()
        let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        
        // Filter notes within the time window
        let recentNotes = notes.filter { $0.updatedAt >= cutoff }
        
        // Group by week
        var weeklyGroups: [Date: [Note]] = [:]
        
        for note in recentNotes {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: note.updatedAt)?.start ?? note.updatedAt
            weeklyGroups[weekStart, default: []].append(note)
        }
        
        // Sort by date and return
        return weeklyGroups
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
    }
}

#Preview {
    ContentView()
}
