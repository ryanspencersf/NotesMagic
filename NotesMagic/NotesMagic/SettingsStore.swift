import SwiftUI

final class SettingsStore: ObservableObject {
  static let shared = SettingsStore()

  enum Theme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
      switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
  }

  @Published var theme: Theme = .system { didSet { persist() } }
  @Published var autoApplyTags: Bool = true { didSet { persist() } }

  private init() { load() }

  private func persist() {
    let d = UserDefaults.standard
    d.set(theme.rawValue, forKey: "settings.theme")
    d.set(autoApplyTags, forKey: "settings.autoApplyTags")
  }

  private func load() {
    let d = UserDefaults.standard
    if let raw = d.string(forKey: "settings.theme"), let t = Theme(rawValue: raw) { theme = t }
    autoApplyTags = d.object(forKey: "settings.autoApplyTags") as? Bool ?? true
  }
}
