import Foundation

struct Card: Codable, Identifiable {
    let id: String
    let japanese: String
    let reading: String?
    let english: String
    let deckName: String
    let ankiInterval: Int?
    let ankiDueDate: String?
    let ankiLastReviewed: String?
    let ankiEaseFactor: Double?
    let updatedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, japanese, reading, english
        case deckName = "deck_name"
        case ankiInterval = "anki_interval"
        case ankiDueDate = "anki_due_date"
        case ankiLastReviewed = "anki_last_reviewed"
        case ankiEaseFactor = "anki_ease_factor"
        case updatedAt = "updated_at"
    }
}

struct CardsResponse: Codable {
    let cards: [Card]
}

struct DeckInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

struct DecksResponse: Codable {
    let decks: [DeckInfo]
}

struct DailySelection: Codable {
    let date: String
    let cards: [Card]
}

struct SyncResponse: Codable {
    let synced: Int?
    let error: String?
}

struct DeckFieldMapping: Codable, Equatable {
    var japanese: String
    var reading: String
    var english: String

    static let `default` = DeckFieldMapping(japanese: "", reading: "", english: "")
}

struct DeckConfig: Codable, Identifiable {
    var id: String { name }
    let name: String
    var fieldMapping: DeckFieldMapping

    static let defaultMappings: [String: DeckFieldMapping] = [
        "Kaishi 1.5k": DeckFieldMapping(
            japanese: "Word Furigana",
            reading: "Word Reading",
            english: "Word Meaning"
        ),
        "Mining": DeckFieldMapping(
            japanese: "ExpressionFurigana",
            reading: "ExpressionReading",
            english: "MainDefinition"
        )
    ]
}

struct Settings: Codable {
    var cardsPerDeck: [String: Int]
    var deckMappings: [String: DeckFieldMapping]

    static let `default` = Settings(cardsPerDeck: [:], deckMappings: DeckConfig.defaultMappings)

    mutating func setCount(_ count: Int, forDeck deck: String) {
        cardsPerDeck[deck] = count
    }

    func count(forDeck deck: String) -> Int {
        cardsPerDeck[deck] ?? 5
    }

    mutating func setMapping(_ mapping: DeckFieldMapping, forDeck deck: String) {
        deckMappings[deck] = mapping
    }

    func mapping(forDeck deck: String) -> DeckFieldMapping {
        deckMappings[deck] ?? DeckFieldMapping.default
    }
}