import SwiftUI
import Domain
import UIKit
import UIComponents

public struct LibraryView: View {
    @Environment(\.undoManager) private var undo
    @StateObject private var viewModel: LibraryViewModel
    @State private var showStructure = false
    @State private var activeTopic: String? = nil
    @State private var path: [Route] = []
    
    public enum Route: Hashable {
        case note(UUID)
        case topic(String)
    }
    
    public init(viewModel: LibraryViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
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
        .overlay(alignment: .leading) {
            // Edge swipe area
            Color.clear
                .frame(width: 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    showStructure = true
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesDidChange)) { _ in
            // Refresh when notes change (e.g., after paste analysis)
            vm.refresh()
        }
    }
    
    private var header: some View {
        VStack(spacing: 10) { // Reduced from default spacing
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
        }
    }
    
    private var filteredNotes: [Note] {
        guard let topic = activeTopic else { return viewModel.activeNotes }
        return viewModel.activeNotes.filter { note in
            note.body.lowercased().contains("#\(topic)") || note.body.lowercased().contains(topic)
        }
    }
    
    private func delete(_ note: Note) {
        withAnimation {
            try? viewModel.trash(note.id)
        }
        undo?.registerUndo(withTarget: viewModel) { target in
            try? target.restore(note.id)
        }
    }
    
    private func pasteAsNewNote() {
        #if os(iOS)
        if let string = UIPasteboard.general.string {
            viewModel.createFromPaste(string)
        }
        #elseif os(macOS)
        if let string = NSPasteboard.general.string(forType: .string) {
            viewModel.createFromPaste(string)
        }
        #endif
    }
}

struct LibraryRow: View {
    let note: Note
    
    var body: some View {
        NavigationLink(value: Route.note(note.id)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.body.isEmpty ? "New note…" : note.body)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("Just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Limited hashtags (max 2-3)
                    let hashtags = extractHashtags(from: note.body)
                    ForEach(Array(hashtags.prefix(3)), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                            .foregroundStyle(.secondary)
                    }
                    
                    if hashtags.count > 3 {
                        Text("+\(hashtags.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                impactFeedback.impactOccurred()
                // Delete action will be handled by parent
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func extractHashtags(from text: String) -> [String] {
        let pattern = "#([A-Za-z0-9_\\-]+)"
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        return results.map { nsString.substring(with: $0.range(at: 1)) }
    }
}
