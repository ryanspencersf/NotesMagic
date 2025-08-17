import SwiftUI
import Domain
import Data

public struct StructurePanelView: View {
    @ObservedObject var vm: StructureViewModel
    let onPick: (String) -> Void
    let onClose: () -> Void
    @State private var showSettings = false
    
    public init(vm: StructureViewModel, onPick: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.vm = vm
        self.onPick = onPick
        self.onClose = onClose
    }
    
    public var body: some View {
        NavigationStack {
            List {
                ForEach(vm.sections) { section in
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(section.chips, id: \.self) { t in
                                Button { onPick(t) } label: { 
                                    Text("#\(t)")
                                        .font(.footnote)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(.quinary))
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Pin") { /* TODO */ }
                                    Button("Move to…") { /* setManualGroup */ }
                                    Divider()
                                    Button("Hide", role: .destructive) { /* TODO */ }
                                }
                            }
                            if section.totalCount > section.chips.count {
                                Button("View all →") { /* push TopicHub for the group */ }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        HStack {
                            Text(section.groupTitle).font(.title3).bold()
                            Spacer()
                            Text("\(section.totalCount)").foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Structure")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: { 
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Section Extensions

private extension StructureViewModel.Section {
    var groupTitle: String {
        switch group {
            case .people: return "People"
            case .orgs: return "Organizations"
            case .places: return "Places"
            case .projects: return "Projects"
            case .work: return "Work"
            case .ideas: return "Ideas"
            case .other: return "Other"
        }
    }
}
