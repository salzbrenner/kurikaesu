import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings: Settings = .default
    @State private var apiURL: String = AnkiConnectService.shared.baseURL

    var body: some View {
        NavigationStack {
            Form {
                Section("AnkiConnect") {
                    TextField("AnkiConnect URL", text: $apiURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                Section("Cards Per Deck") {
                    ForEach(viewModel.deckNames, id: \.self) { deck in
                        Stepper(value: Binding(
                            get: { settings.count(forDeck: deck) },
                            set: { settings.setCount($0, forDeck: deck) }
                        ), in: 1...20) {
                            HStack {
                                Text(deck)
                                Spacer()
                                Text("\(settings.count(forDeck: deck))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        settings = Settings(
                            cardsPerDeck: Dictionary(uniqueKeysWithValues: viewModel.deckNames.map { ($0, 5) }),
                            deckMappings: DeckConfig.defaultMappings
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        AnkiConnectService.shared.baseURL = apiURL
                        viewModel.updateSettings(settings)
                        dismiss()
                    }
                }
            }
            .onAppear {
                settings = viewModel.getSettings()
                apiURL = AnkiConnectService.shared.baseURL
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: ContentViewModel())
}