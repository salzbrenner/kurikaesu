import Foundation

enum AnkiConnectError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case ankiError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid AnkiConnect URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .ankiError(let message):
            return "AnkiConnect error: \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error)"
        }
    }
}

class AnkiConnectService {
    static let shared = AnkiConnectService()

    var baseURL: String = "http://localhost:8766"
    var deckMappings: [String: DeckFieldMapping] = [:]

    private init() {}

    private func invoke(action: String, params: [String: Any] = [:]) async throws -> Any {
        guard let url = URL(string: "\(baseURL)/anki") else {
            throw AnkiConnectError.invalidURL
        }

        let body: [String: Any] = [
            "action": action,
            "version": 6,
            "params": params
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw AnkiConnectError.networkError(NSError(domain: "HTTP", code: httpResponse.statusCode))
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? String, !error.isEmpty {
                    throw AnkiConnectError.ankiError(error)
                }
                return json["result"] ?? []
            }

            throw AnkiConnectError.decodingError(NSError(domain: "AnkiConnect", code: -1))
        } catch let error as AnkiConnectError {
            throw error
        } catch {
            throw AnkiConnectError.networkError(error)
        }
    }

    func fetchDeckNames() async throws -> [String] {
        let result = try await invoke(action: "deckNames")
        guard let decks = result as? [String] else {
            throw AnkiConnectError.decodingError(NSError(domain: "AnkiConnect", code: -2))
        }
        return decks.filter { !$0.starts(with: "_") }
    }

    func fetchCards(forDeck deck: String) async throws -> [Card] {
        let findResult = try await invoke(action: "findCards", params: ["query": "deck:\"\(deck)\""])
        guard let cardIds = findResult as? [Int], !cardIds.isEmpty else {
            return []
        }

        let cardsResult = try await invoke(action: "cardsInfo", params: ["cards": cardIds])
        guard let cardsInfo = cardsResult as? [[String: Any]] else {
            throw AnkiConnectError.decodingError(NSError(domain: "AnkiConnect", code: -3))
        }

        let mapping = deckMappings[deck] ?? DeckFieldMapping.default

        var cards: [Card] = []
        for cardInfo in cardsInfo {
            guard let fields = cardInfo["fields"] as? [String: [String: Any]] else { continue }

            let japanese = fields[mapping.japanese]?["value"] as? String ?? ""
            let reading = fields[mapping.reading]?["value"] as? String
            let english = fields[mapping.english]?["value"] as? String ?? ""

            guard !japanese.isEmpty else { continue }

            let cardId = String(cardInfo["cardId"] as? Int ?? 0)

            cards.append(Card(
                id: "\(deck)_\(cardId)",
                japanese: japanese,
                reading: reading,
                english: english,
                deckName: deck,
                ankiInterval: cardInfo["interval"] as? Int,
                ankiDueDate: cardInfo["due"] != nil ? String(describing: cardInfo["due"]!) : nil,
                ankiLastReviewed: nil,
                ankiEaseFactor: cardInfo["ease"] as? Double,
                updatedAt: nil
            ))
        }

        return cards
    }

    func fetchAllCards() async throws -> [Card] {
        let decks = try await fetchDeckNames()
        var allCards: [Card] = []

        for deck in decks {
            let cards = try await fetchCards(forDeck: deck)
            allCards.append(contentsOf: cards)
        }

        return allCards
    }

    func loadDeckMappings(from db: DatabaseService) {
        deckMappings = db.getDeckMappings()
        if deckMappings.isEmpty {
            deckMappings = DeckConfig.defaultMappings
        }
    }
}