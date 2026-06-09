import SwiftUI

struct DeckConfigView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings: Settings = .default
    @State private var editingDeck: String? = nil
    @State private var isAddingDeck = false
    @State private var newDeckName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(settings.deckMappings.keys.sorted(), id: \.self) { deck in
                        Button {
                            editingDeck = deck
                        } label: {
                            HStack {
                                Text(deck)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        let keys = settings.deckMappings.keys.sorted()
                        for index in indexSet {
                            settings.deckMappings.removeValue(forKey: keys[index])
                        }
                    }
                } header: {
                    Text("Configured Decks")
                } footer: {
                    Text("Swipe to delete. Tap to edit field mappings.")
                }

                Section {
                    Button {
                        isAddingDeck = true
                    } label: {
                        Label("Add Deck", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Deck Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateSettings(settings)
                        dismiss()
                    }
                }
            }
            .onAppear {
                settings = viewModel.getSettings()
            }
            .sheet(item: $editingDeck) { deck in
                DeckMappingEditView(deckName: deck, mapping: settings.deckMappings[deck] ?? .default) { updated in
                    settings.deckMappings[deck] = updated
                }
            }
            .alert("Add Deck", isPresented: $isAddingDeck) {
                TextField("Deck Name", text: $newDeckName)
                Button("Cancel", role: .cancel) {
                    newDeckName = ""
                }
                Button("Add") {
                    if !newDeckName.isEmpty && settings.deckMappings[newDeckName] == nil {
                        settings.deckMappings[newDeckName] = DeckFieldMapping.default
                    }
                    newDeckName = ""
                }
            } message: {
                Text("Enter the Anki deck name exactly as it appears.")
            }
        }
    }
}

struct DeckMappingEditView: View {
    let deckName: String
    @State var mapping: DeckFieldMapping
    let onSave: (DeckFieldMapping) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(deckName), footer: Text("Enter the exact field names from your Anki cards. Case-sensitive.")) {
                    TextField("Japanese Field", text: $mapping.japanese)
                        .autocapitalization(.none)

                    TextField("Reading Field", text: $mapping.reading)
                        .autocapitalization(.none)

                    TextField("English Field", text: $mapping.english)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(mapping)
                        dismiss()
                    }
                }
            }
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

#Preview {
    DeckConfigView(viewModel: ContentViewModel())
}