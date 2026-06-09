import Foundation

struct AnkiDeckResponse: Codable {
    let result: [String]?
    let error: String?
}

struct AnkiFindResponse: Codable {
    let result: [Int]?
    let error: String?
}

struct AnkiCardInfo: Codable {
    let cards: [AnkiCard]?
    let error: String?
}

struct AnkiCard: Codable {
    let cardId: Int
    let fields: [String: AnkiField]

    enum CodingKeys: String, CodingKey {
        case cardId = "cardId"
        case fields
    }
}

struct AnkiField: Codable {
    let value: String
    let order: Int?
}