import SwiftUI
import Combine

/// App settings with simple UserDefaults persistence.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    enum AppTheme: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var name: String { switch self {
            case .system: "System"
            case .light:  "Light"
            case .dark:   "Dark"
        }}
        var colorScheme: ColorScheme? {
            switch self { case .system: nil; case .light: .light; case .dark: .dark }
        }
    }

    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var autoApplyTags: Bool {
        didSet { UserDefaults.standard.set(autoApplyTags, forKey: Keys.autoApplyTags) }
    }
    @Published var searchAnswerCard: Bool {
        didSet { UserDefaults.standard.set(searchAnswerCard, forKey: Keys.searchAnswerCard) }
    }

    private init() {
        let ud = UserDefaults.standard
        theme = AppTheme(rawValue: ud.string(forKey: Keys.theme) ?? "") ?? .system
        autoApplyTags = (ud.object(forKey: Keys.autoApplyTags) as? Bool) ?? true
        searchAnswerCard = (ud.object(forKey: Keys.searchAnswerCard) as? Bool) ?? false
    }

    private enum Keys {
        static let theme = "settings.theme"
        static let autoApplyTags = "settings.autoApplyTags"
        static let searchAnswerCard = "settings.searchAnswerCard"
    }
}
