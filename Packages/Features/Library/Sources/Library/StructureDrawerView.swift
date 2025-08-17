import SwiftUI
import Domain
import UIComponents

public struct StructureDrawerView: View {
  @ObservedObject var vm: StructureViewModel
  let applyFilter: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query: String = ""

  public init(viewModel: StructureViewModel, applyFilter: @escaping (String) -> Void) {
    self._vm = ObservedObject(initialValue: viewModel)
    self.applyFilter = applyFilter
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          search
          pinned
          trending
          people
          projects
          recentGroups
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
      }
      .navigationTitle("Structure")
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
      .background(DS.ColorToken.bg.ignoresSafeArea())
    }
    .onAppear { vm.refreshAll() }
  }

  // MARK: Sections

  private var search: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Search topics and notes…", text: $query)
        .textFieldStyle(.roundedBorder)
        .onChange(of: query) { _, newValue in vm.search(newValue) }
      if !query.isEmpty {
        if !vm.searchTopics.isEmpty {
          SectionHeader("Topics")
          WrapChips(vm.searchTopics.map { "#"+$0.name }) { pick($0) }
        }
        if !vm.searchNotes.isEmpty {
          SectionHeader("Notes")
          ForEach(vm.searchNotes.prefix(10)) { n in
            Button { /* open note? caller can handle if needed */ } label {
              Text(n.body).lineLimit(2)
            }.buttonStyle(.plain)
            Divider().opacity(0.08)
          }
        }
      }
    }
  }

  private var pinned: some View {
    Group {
      if !vm.pinned.isEmpty {
        SectionHeader("Pinned")
        WrapChips(vm.pinned.map { "#"+$0 }) { pick($0) }
      }
    }
  }

  private var trending: some View {
    Group {
      if !vm.trending.isEmpty {
        SectionHeader("Trending · 14d")
        WrapChips(vm.trending.map { "#"+$0.name }) { pick($0) }
      }
    }
  }

  private var people: some View {
    Group {
      if !vm.people.isEmpty {
        SectionHeader("People")
        WrapChips(vm.people) { name in pick(name) }
      }
    }
  }

  private var projects: some View {
    Group {
      if !vm.projects.isEmpty {
        SectionHeader("Projects")
        WrapChips(vm.projects.map { "#"+$0.name }) { pick($0) }
      }
    }
  }

  private var recentGroups: some View {
    Group {
      if !vm.recentByTopic.isEmpty {
        SectionHeader("Recents")
        VStack(alignment: .leading, spacing: 12) {
          ForEach(vm.recentByTopic, id: \.0) { (topic, notes) in
            VStack(alignment: .leading, spacing: 6) {
              Text("#\(topic)").font(DS.Typography.secondary()).foregroundStyle(.secondary)
              ForEach(notes.prefix(3)) { n in
                Text(n.body).lineLimit(1)
                Divider().opacity(0.06)
              }
            }
          }
        }
      }
    }
  }

  // MARK: helpers
  private func pick(_ raw: String) {
    let name = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
    applyFilter(name)
    dismiss()
  }
}

// Tiny helpers
private struct SectionHeader: View {
  let title: String
  init(_ title: String) { self.title = title }
  var body: some View {
    Text(title.uppercased())
      .font(DS.Typography.meta().weight(.semibold))
      .foregroundStyle(DS.ColorToken.textSecondary)
      .padding(.top, 4)
      .overlay(Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.08)).offset(y: 16), alignment: .bottom)
  }
}

private struct WrapChips: View {
  let items: [String]
  let onTap: (String) -> Void
  var body: some View {
    FlexibleHStack(items: items) { s in
      Button {
        onTap(s)
      } label: {
        HStack(spacing: 6) {
          if s.hasPrefix("#") { Image(systemName: "number").font(.system(size: 12, weight: .semibold)) }
          Text(s).font(DS.Typography.meta())
        }
        .pillStyle()
      }
      .contextMenu {
        Button("Pin/Unpin") { /* handled by caller if needed later */ }
      }
      .buttonStyle(.plain)
    }
  }
}

// A light flow layout for chips (no deps)
private struct FlexibleHStack<Content: View, T: Hashable>: View {
  let items: [T]
  @ViewBuilder let content: (T) -> Content
  @State private var totalHeight: CGFloat = .zero

  var body: some View {
    GeometryReader { geo in
      self.generate(in: geo)
    }
    .frame(height: totalHeight)
  }

  private func generate(in g: GeometryProxy) -> some View {
    var width: CGFloat = 0
    var height: CGFloat = 0
    return ZStack(alignment: .topLeading) {
      ForEach(items, id: \.self) { item in
        content(item)
          .padding(.trailing, 8).padding(.bottom, 8)
          .alignmentGuide(.leading) { d in
            if (abs(width - d.width) > g.size.width) {
              width = 0; height -= d.height
            }
            let result = width
            if item == items.last! { width = 0 } else { width -= d.width }
            return result
          }
          .alignmentGuide(.top) { _ in height }
      }
    }
    .background(HeightReader(height: $totalHeight))
  }
}

private struct HeightReader: View {
  @Binding var height: CGFloat
  var body: some View {
    GeometryReader { geo -> Color in
      DispatchQueue.main.async { self.height = max(self.height, geo.size.height) }
      return .clear
    }
  }
}
