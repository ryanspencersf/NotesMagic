import SwiftUI
import Domain

public struct EditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @State private var showingTagEditor = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack {
                Button("Tags") {
                    showingTagEditor = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("\(viewModel.text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Main text editor
            TextView(text: $viewModel.text, onPasted: {
                // Trigger immediate analysis on paste
                viewModel.scheduleFullAnalysis(immediate: true)
            })
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Inferred tags display
            if !viewModel.inferredTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inferred Tags")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
                    ], spacing: 8) {
                        ForEach(viewModel.inferredTags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                )
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorView(tags: viewModel.inferredTags)
        }
    }
}

struct TagEditorView: View {
    let tags: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tags, id: \.self) { tag in
                    HStack {
                        Text("#\(tag)")
                        Spacer()
                        Text("Inferred")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
