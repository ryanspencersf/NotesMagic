import SwiftUI
import Data

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showEraseConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(SettingsStore.Theme.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                }

                Section("Features") {
                    Toggle("Auto-apply tags", isOn: $settings.autoApplyTags)
                    Toggle("Search answer card", isOn: $settings.searchAnswerCard)
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        Text("Erase all local data")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Erase all local data?", isPresented: $showEraseConfirm, titleVisibility: .visible) {
                Button("Erase Everything", role: .destructive) {
                    NotesStoreImpl.shared.eraseAll()
                    TopicIndexImpl.shared.reset()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}
