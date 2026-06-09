import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
}

class APIService {
    static let shared = APIService()

    // TODO: Configure via settings - default to Tailscale URL
    var baseURL: String = "http://localhost:8766"

    private init() {}

    func fetchCards() async throws -> [Card] {
        guard let url = URL(string: "\(baseURL)/cards") else {
            throw APIError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(CardsResponse.self, from: data)
            return response.cards
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchDecks() async throws -> [DeckInfo] {
        guard let url = URL(string: "\(baseURL)/decks") else {
            throw APIError.invalidURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(DecksResponse.self, from: data)
            return response.decks
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    func syncCards(_ cards: [Card]) async throws -> Int {
        guard let url = URL(string: "\(baseURL)/sync") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["cards": cards.map { card in
            [
                "id": card.id,
                "japanese": card.japanese,
                "reading": card.reading ?? "",
                "english": card.english,
                "deck_name": card.deckName,
                "anki_interval": card.ankiInterval ?? 0,
                "anki_due_date": card.ankiDueDate ?? "",
                "anki_last_reviewed": card.ankiLastReviewed ?? "",
                "anki_ease_factor": card.ankiEaseFactor ?? 0
            ] as [String: Any]
        }]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SyncResponse.self, from: data)
            if let error = response.error {
                throw APIError.serverError(error)
            }
            return response.synced ?? 0
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}