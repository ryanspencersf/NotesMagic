//
//  NotesMagicApp.swift
//  NotesMagic
//
//  Created by Ryan Spencer on 8/16/25.
//

import SwiftUI

// MARK: - Settings Store
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    public enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark
        public var id: String { rawValue }
        public var colorScheme: ColorScheme? {
            switch self { 
                case .system: return nil; 
                case .light: return .light; 
                case .dark: return .dark 
            }
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
        if let raw = d.string(forKey: "settings.theme"), let t = Theme(rawValue: raw) { 
            theme = t 
        }
        autoApplyTags = d.object(forKey: "settings.autoApplyTags") as? Bool ?? true
    }
}

@main
struct NotesMagicApp: App {
    @StateObject var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.theme.colorScheme)
        }
    }
}

// MARK: - Minimal Content View
struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("NotesMagic")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Settings working!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                // Theme picker
                Picker("Theme", selection: $settings.theme) {
                    ForEach(SettingsStore.Theme.allCases) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
                
                // Auto-apply tags toggle
                Toggle("Auto-apply tags", isOn: $settings.autoApplyTags)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding()
            .navigationTitle("NotesMagic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
}
