import SwiftUI

public enum AppearanceOption: String, CaseIterable, Identifiable {
    case system, light, dark
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearanceRaw: String = AppearanceOption.system.rawValue
    
    public init() {}
    
    public var body: some View {
        Form {
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(AppearanceOption.allCases) { opt in
                    Text(opt.label).tag(opt.rawValue)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("Reduce Glass Effects", isOn: .constant(false))
                .help("Uses thinner material or solid fill for accessibility/performance.")
        }
        .padding()
    }
}
