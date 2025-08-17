import SwiftUI
import Domain
import UIKit

public struct StructurePanelView: View {
    @ObservedObject var vm: StructureVM
    let onPick: (String) -> Void
    let onClose: () -> Void
    @State private var showSettings = false
    
    public init(vm: StructureVM, onPick: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.vm = vm
        self.onPick = onPick
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Structure")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.groups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            // Group header with count badge
                            HStack {
                                Text(group.emoji)
                                    .font(.title3)
                                Text(group.title)
                                    .font(.headline)
                                Spacer()
                                CountBadge(n: group.topics.count)
                            }
                            .padding(.top, 4)
                            
                            // Topics with limit and "View all" chip
                            let displayTopics = group.topics.prefix(10)
                            let hasOverflow = group.topics.count > 10
                            
                            WrapChips(
                                items: displayTopics.map { "#\($0.name)" },
                                onTap: { topicString in
                                    let topic = String(topicString.dropFirst()) // Remove #
                                    // Haptic feedback on chip tap
                                    let impact = UIImpactFeedbackGenerator(style: .soft)
                                    impact.impactOccurred()
                                    onPick(topic)
                                }
                            )
                            
                            // Overflow indicator
                            if hasOverflow {
                                Button {
                                    // TODO: Show full group view
                                } label: {
                                    HStack {
                                        Text("View all \(group.topics.count) →")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Haptic feedback on appear
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Supporting Views

struct GroupHeader: View {
    let emoji: String
    let title: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 10) {
            Text(emoji).font(.title3)
            Text(title).font(.headline)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
}

struct TopicChip: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("#\(name)").pill()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Pin/Unpin") { /* TODO: Implement */ }
            Button("Merge…") { /* TODO: Implement */ }
            Button("Assign to Group…") { /* TODO: Implement */ }
        }
        .accessibilityLabel("#\(name) topic")
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

struct CountBadge: View {
    let n: Int
    
    var body: some View {
        Text("\(n)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(.secondary)
    }
}

#Preview {
    StructurePanelView(
        vm: StructureVM(topicIndex: nil, notesProvider: { [] }),
        onPick: { _ in },
        onClose: {}
    )
}
