import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.cardsByDeck.isEmpty {
                    ProgressView("Loading...")
                } else if viewModel.cardsByDeck.isEmpty {
                    VStack(spacing: 20) {
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                        Button {
                            Task { await viewModel.syncAndLoad() }
                        } label: {
                            Label("Sync Cards", systemImage: "arrow.triangle.2.circlepath")
                                .font(.headline)
                        }
                        Text("Tap to sync with your Mac")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24, pinnedViews: .sectionHeaders) {
                            ForEach(viewModel.deckNames, id: \.self) { deck in
                                Section {
                                    ForEach(viewModel.cardsByDeck[deck] ?? []) { card in
                                        CardView(card: card)
                                    }
                                } header: {
                                    DeckHeaderView(
                                        deckName: deck,
                                        onRefresh: {
                                            viewModel.reshuffleDeck(deck)
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.syncAndLoad()
                    }
                }
            }
            .navigationTitle("Kurikaesu")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await viewModel.syncAndLoad() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
        .task {
            viewModel.loadLocalData()
        }
    }
}

struct DeckHeaderView: View {
    let deckName: String
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            Text(deckName)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
    }
}

@MainActor
class ContentViewModel: ObservableObject {
    @Published var cardsByDeck: [String: [Card]] = [:]
    @Published var deckNames: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = DatabaseService.shared

    func loadLocalData() {
        let decks = db.getDeckNames()
        deckNames = decks.sorted()

        cardsByDeck = [:]
        for deck in decks {
            let cards = db.generateDailySelection(forDeck: deck)
            if !cards.isEmpty {
                cardsByDeck[deck] = cards
            }
        }
    }

    func syncAndLoad() async {
        isLoading = true
        errorMessage = nil

        do {
            let cards = try await APIService.shared.fetchCards()
            db.upsertCards(cards)
            loadLocalData()
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func reshuffleDeck(_ deck: String) {
        let cards = db.reshuffleDeck(deck)
        cardsByDeck[deck] = cards
    }

    func getSettings() -> Settings {
        db.getSettings()
    }

    func updateSettings(_ settings: Settings) {
        db.saveSettings(settings)
        loadLocalData()
    }
}

#Preview {
    ContentView()
}