//
//  NotesMagicApp.swift
//  NotesMagic
//
//  Created by Ryan Spencer on 8/16/25.
//

import SwiftUI

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
