import SwiftUI
import Domain
import UIComponents
import Data

public struct StructureDrawerView: View {
    @StateObject private var viewModel: StructureViewModel
    @Environment(\.dismiss) private var dismiss
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
                // Content
                sectionsList
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
                    TopicHubView(topic: name, index: viewModel.index)
                }
            }
        }
        .onAppear {
            viewModel.rebuild()
        }
    }
    
    private var sectionsList: some View {
        List {
            ForEach(viewModel.sections) { section in
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(section.chips, id: \.self) { t in
                            Button { 
                                path.append(.topic(t))
                            } label: { 
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
