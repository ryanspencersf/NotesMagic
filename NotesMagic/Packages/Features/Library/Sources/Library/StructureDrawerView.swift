import SwiftUI
import Domain
import UIComponents

public struct StructureDrawerView: View {
    @StateObject private var viewModel: StructureViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var selectedTopic: TopicChip?
    @State private var path: [Route] = []
    
    public enum Route: Hashable {
        case topic(String)
    }
    
    let applyFilter: (String) -> Void
    
    public init(viewModel: StructureViewModel, applyFilter: @escaping (String) -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.applyFilter = applyFilter
    }
    
    public var body: some View {
        NavigationStack(path: $path) {
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
            .navigationTitle("Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topic(let name):
                    TopicHubView(topic: name, index: viewModel.topicIndex)
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
                            // Navigate to topic hub
                            path.append(.topic(topic.name))
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
                            // Navigate to topic hub
                            path.append(.topic(topic.name))
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
                                // Navigate to topic hub
                                path.append(.topic(topic.name))
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

// MARK: - Category Section

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

// MARK: - Topic Chip View

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
                    .fill(DS.ColorToken.pillFill)
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Assign to Group Sheet

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

#Preview {
    StructureDrawerView(
        viewModel: StructureViewModel(
            topicIndex: MockTopicIndex(),
            notesProvider: { [] }
        ),
        applyFilter: { _ in }
    )
}

// MARK: - Mock TopicIndex for Preview

private class MockTopicIndex: TopicIndex {
    func rebuild(from notes: [Note]) {}
    func noteDidChange(_ note: Note) {}
    func topTopics(limit: Int, windowDays: Int) -> [Topic] { [] }
    func notes(for topicName: String) -> [Note] { [] }
    func search(_ query: String) -> (topics: [Topic], notes: [Note]) { ([], []) }
    func addTag(_ tag: String, to noteID: UUID) {}
    func topicsWithScores() -> [(name: String, count: Int, lastUsedAt: Date, score: Double)] { [] }
    func relatedTopics(for topic: String, limit: Int) -> [String] { [] }
    func reset() {}
}
