import SwiftUI

public final class SettingsStore: ObservableObject {
  public static let shared = SettingsStore()

  public enum Theme: String, CaseIterable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
    public var colorScheme: ColorScheme? {
      switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
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
    if let raw = d.string(forKey: "settings.theme"), let t = Theme(rawValue: raw) { theme = t }
    autoApplyTags = d.object(forKey: "settings.autoApplyTags") as? Bool ?? true
  }
}
