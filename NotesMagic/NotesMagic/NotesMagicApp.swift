//
//  NotesMagicApp.swift
//  NotesMagic
//
//  Created by Ryan Spencer on 8/16/25.
//

import SwiftUI
import NaturalLanguage

// MARK: - Settings Store
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    public enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark
        public var id: String { rawValue }
        public var colorScheme: ColorScheme? {
            switch self { 
                case .system: return nil; 
                case .light: return .light; 
                case .dark: return .dark 
            }
        }
    }
    
    @Published public var theme: Theme = .system { didSet { persist() } }
    @Published public var autoApplyTags: Bool = true { didSet { persist() } }
    
    private init() { load() }
    
    private func persist() {
        let d = UserDefaults.standard
        d.set(theme.rawValue, forKey: "settings.theme")
        d.set(autoApplyTags, forKey: "settings.autoApplyTags")
    }
    
    private func load() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: "settings.theme"), let t = Theme(rawValue: raw) { 
            theme = t 
        }
        autoApplyTags = d.object(forKey: "settings.autoApplyTags") as? Bool ?? true
    }
}

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

// MARK: - Main App Content
struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        LibraryView()
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
}

// MARK: - Library View
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
                            searchTopics = r.topics.sorted { $0.count > $1.count }
                            searchNotes = r.notes
                        }
                    
                    // Topics strip – fluid organization signal
                    TopicsStrip(topics: query.isEmpty ? vm.trendingTopics : searchTopics) { topic in
                        path.append(.topic(topic.name))
                    }
                    
                    // List: either search results or recent notes
                    if query.isEmpty {
                        list
                    } else {
                        searchResults
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                
                // Glass FAB lives only on Library
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
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        try? vm.trash(note.id)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
            .onDelete { indexSet in
                for i in indexSet { try? vm.trash(vm.items[i].id) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
    
    private var searchResults: some View {
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

// MARK: - Editor View
struct EditorView: View {
    public let noteID: UUID
    private let getText: () -> String
    private let setText: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text: String
    
    init(noteID: UUID, getText: @escaping () -> String, setText: @escaping (String) -> Void) {
        self.noteID = noteID
        self.getText = getText
        self.setText = setText
        self._text = State(initialValue: getText())
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            TextEditor(text: $text)
                .font(.body)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 52)
                .background(Color(.systemBackground))
                .focused($focused)
                .onAppear { focused = true }
                .onChange(of: text) { oldValue, newValue in
                    setText(newValue)
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { 
                    focused = false
                    dismiss() 
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Glass FAB
struct GlassFAB: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10))
        )
        .buttonStyle(.plain)
    }
}

// MARK: - Topics Strip
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
        }
    }
}

// MARK: - Pill Style
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

// MARK: - Models
struct Note: Identifiable, Equatable {
    let id: UUID
    var body: String
    let createdAt: Date
    var updatedAt: Date
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

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

// MARK: - View Models
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
    
    func notes(for topic: Topic) -> [Note] { 
        topics.notes(for: topic.name) 
    }
    
    func search(_ q: String) -> (topics: [Topic], notes: [Note]) { 
        topics.search(q) 
    }
    
    func trash(_ id: UUID) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let note = items[index]
        items.remove(at: index)
        topics.noteDidChange(note)
        refreshTopics()
    }
    
    var topicIndex: TopicIndex {
        return topics
    }
    
    private func refreshTopics() {
        trendingTopics = topics.topTopics(limit: 12, windowDays: 14)
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Topic Index Protocol
protocol TopicIndex {
    func rebuild(from notes: [Note])
    func noteDidChange(_ note: Note)
    func topTopics(limit: Int, windowDays: Int) -> [Topic]
    func notes(for topicName: String) -> [Note]
    func search(_ query: String) -> (topics: [Topic], notes: [Note])
}

// MARK: - Topic Index Implementation
final class TopicIndexInMemory: TopicIndex {
    private var posting: [String: Set<UUID>] = [:]
    private var when: [String: [Date]] = [:]
    private var lastUsed: [String: Date] = [:]
    private var notesByID: [UUID: Note] = [:]
    
    private static let tagRegex = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
    
    func rebuild(from notes: [Note]) {
        posting.removeAll()
        when.removeAll()
        lastUsed.removeAll()
        notesByID.removeAll()
        for n in notes { index(n) }
    }
    
    func noteDidChange(_ note: Note) {
        if let old = notesByID[note.id] {
            for t in Self.explicit(from: old.body) { posting[t]?.remove(old.id) }
        }
        index(note)
    }
    
    func topTopics(limit: Int, windowDays: Int) -> [Topic] {
        let now = Date()
        let window = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let all = Set(posting.keys)
        let topics: [Topic] = all.map { t in
            let expUses = (when[t] ?? []).filter { $0 >= window }.count
            let s = score(for: t, now: now)
            let last = lastUsed[t] ?? .distantPast
            return Topic(name: t, count: posting[t]?.count ?? 0, lastUsedAt: last, score: s + Double(expUses))
        }
        return topics.sorted {
            $0.score == $1.score ? $0.lastUsedAt > $1.lastUsedAt : $0.score > $1.score
        }.prefix(limit).map { $0 }
    }
    
    func notes(for topicName: String) -> [Note] {
        let key = topicName.lowercased()
        let ids = posting[key] ?? []
        return ids.compactMap { notesByID[$0] }.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    func search(_ q: String) -> (topics: [Topic], notes: [Note]) {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ([], []) }
        let now = Date()
        let all = Set(posting.keys)
        let t = all.filter { $0.contains(query) }.map { name in
            Topic(name: name, count: posting[name]?.count ?? 0, lastUsedAt: lastUsed[name] ?? .distantPast, score: score(for: name, now: now))
        }.sorted { $0.score > $1.score }
        let n = notesByID.values.filter { $0.body.lowercased().contains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
        return (Array(t.prefix(6)), Array(n.prefix(20)))
    }
    
    private func index(_ note: Note) {
        notesByID[note.id] = note
        let now = Date()
        
        for raw in Self.explicit(from: note.body) {
            let t = raw.lowercased()
            posting[t, default: []].insert(note.id)
            when[t, default: []].append(now)
            lastUsed[t] = max(lastUsed[t] ?? .distantPast, note.updatedAt)
        }
    }
    
    private func score(for tag: String, now: Date) -> Double {
        let halfLife = 7.0
        let exp = (when[tag] ?? []).reduce(0.0) { acc, d in
            acc + pow(0.5, now.timeIntervalSince(d) / 86_400.0 / halfLife)
        }
        let unique = Double((posting[tag]?.count ?? 0)) * 0.3
        return exp + unique
    }
    
    private static func explicit(from text: String) -> [String] {
        let ns = text as NSString
        return tagRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)) }
    }
}

// MARK: - Topic View
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

// MARK: - Structure Panel View
struct StructurePanelView: View {
    @ObservedObject var vm: StructureVM
    var onPick: (String) -> Void
    var onClose: () -> Void
    
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
            .padding(.bottom, 20)
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

// MARK: - Structure VM
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
    
    private func topicsWithScores(notes: [Note]) -> [Topic] {
        if let idx = topicIndex {
            let exposed = idx.topTopics(limit: 50, windowDays: 30)
            return exposed.map {
                Topic(name: $0.name, count: $0.count, lastUsed: $0.lastUsedAt, score: $0.score)
            }
        }
        
        var counts: [String:(c:Int, last:Date)] = [:]
        let now = Date()
        for n in notes {
            let tags = explicitTags(in: n.body)
            for t in Set(tags) {
                counts[t, default: (0, .distantPast)].c += 1
                counts[t]!.last = max(counts[t]!.last, n.updatedAt)
            }
        }
        return counts.map { (name, val) in
            let age = now.timeIntervalSince(val.last)
            let recency = exp(-age / (14 * 86_400))
            return Topic(name: name, count: val.c, lastUsed: val.last, score: Double(val.c) * (0.6 + 0.4*recency))
        }
    }
    
    private func explicitTags(in text: String) -> [String] {
        let rx = try! NSRegularExpression(pattern: "#([A-Za-z0-9_\\-]+)")
        let ns = text as NSString
        return rx.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)) }
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
            ) { tag, r in
                if tag == kind {
                    set.insert(String(n.body[r]))
                }
                return true
            }
        }
        return Array(set)
    }
}

// MARK: - Wrap Chips
private struct WrapChips: View {
    let items: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        FlexibleHStack(items: items, onTap: onTap)
    }
}

// MARK: - Flexible HStack
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

// MARK: - Side Panel
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
