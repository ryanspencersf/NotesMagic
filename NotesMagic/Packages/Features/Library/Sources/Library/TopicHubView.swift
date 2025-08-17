import SwiftUI
import Domain

struct TopicHubView: View {
    @StateObject var vm: TopicHubViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(topic: String) {
        self._vm = StateObject(wrappedValue: TopicHubViewModel(topic: topic))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("#\(vm.topic)")
                        .font(.largeTitle.bold())
                    Spacer()
                    Text("\(vm.notes.count) notes")
                        .foregroundStyle(.secondary)
                }
                
                // TL;DR
                if !vm.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TL;DR")
                            .font(.headline)
                        ForEach(Array(vm.bullets.enumerated()), id: \.offset) { _, bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(bullet.text)
                                Spacer()
                                // Citation badge
                                Button {
                                    // TODO: Open note at specific location
                                } label: {
                                    Image(systemName: "text.quote")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Entities
                if !vm.entities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("People & Places")
                            .font(.headline)
                        FlowLayout(vm.entities.prefix(10)) { entity in
                            Text(entity).pill()
                        }
                    }
                }
                
                // Open loops
                if !vm.openLoops.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Open loops")
                            .font(.headline)
                        ForEach(vm.openLoops.prefix(6), id: \.self) { loop in
                            Text("• \(loop)")
                        }
                    }
                }
                
                // Notes list (fallback)
                if !vm.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        ForEach(vm.notes) { note in
                            LibraryRow(note: note)
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear { vm.load() }
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

// FlowLayout for wrapping entities
struct FlowLayout: Layout {
    let items: [String]
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        let positions: [CGPoint]
        let size: CGSize
        
        init(in maxWidth: CGFloat, subviews: Subviews) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth = maxWidth
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight
                    lineHeight = 0
                }
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + 8
                lineHeight = max(lineHeight, size.height)
            }
            
            self.positions = positions
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
