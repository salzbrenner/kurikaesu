import Foundation
import SQLite

class DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?

    // Tables
    private let cards = Table("cards")
    private let dailySelections = Table("daily_selections")
    private let settings = Table("settings")

    // Card columns
    private let id = SQLite.Expression<String>("id")
    private let japanese = SQLite.Expression<String>("japanese")
    private let reading = SQLite.Expression<String?>("reading")
    private let english = SQLite.Expression<String>("english")
    private let deckName = SQLite.Expression<String>("deck_name")
    private let ankiInterval = SQLite.Expression<Int?>("anki_interval")
    private let ankiDueDate = SQLite.Expression<String?>("anki_due_date")
    private let ankiLastReviewed = SQLite.Expression<String?>("anki_last_reviewed")
    private let ankiEaseFactor = SQLite.Expression<Double?>("anki_ease_factor")
    private let updatedAt = SQLite.Expression<Int>("updated_at")

    // Selection columns
    private let date = SQLite.Expression<String>("date")
    private let deckNameSel = SQLite.Expression<String>("deck_name")
    private let cardIds = SQLite.Expression<String>("card_ids")

    // Settings columns
    private let settingsId = SQLite.Expression<Int>("id")
    private let cardsPerDeck = SQLite.Expression<String>("cards_per_deck")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let path = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.studylist.app")!
                .appendingPathComponent("studylist.sqlite3")
                .path
            db = try Connection(path)
            createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func createTables() {
        guard let db = db else { return }

        do {
            try db.run(cards.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(japanese)
                t.column(reading)
                t.column(english)
                t.column(deckName)
                t.column(ankiInterval)
                t.column(ankiDueDate)
                t.column(ankiLastReviewed)
                t.column(ankiEaseFactor)
                t.column(updatedAt)
            })

            try db.run(dailySelections.create(ifNotExists: true) { t in
                t.column(date)
                t.column(deckNameSel)
                t.column(cardIds)
                t.primaryKey(date, deckNameSel)
            })

            try db.run(settings.create(ifNotExists: true) { t in
                t.column(settingsId, primaryKey: true)
                t.column(cardsPerDeck, defaultValue: "{}")
            })

            // Insert default settings if not exists
            let count = try db.scalar(settings.count)
            if count == 0 {
                try db.run(settings.insert(settingsId <- 1, cardsPerDeck <- "{}"))
            }
        } catch {
            print("Create tables error: \(error)")
        }
    }

    // MARK: - Card Operations

    func upsertCards(_ cardList: [Card]) {
        guard let db = db else { return }

        do {
            for card in cardList {
                try db.run(cards.insert(or: .replace,
                    id <- card.id,
                    japanese <- card.japanese,
                    reading <- card.reading,
                    english <- card.english,
                    deckName <- card.deckName,
                    ankiInterval <- card.ankiInterval,
                    ankiDueDate <- card.ankiDueDate,
                    ankiLastReviewed <- card.ankiLastReviewed,
                    ankiEaseFactor <- card.ankiEaseFactor,
                    updatedAt <- card.updatedAt ?? Int(Date().timeIntervalSince1970)
                ))
            }
            updateWidgetData()
        } catch {
            print("Upsert cards error: \(error)")
        }
    }

    func getAllCards() -> [Card] {
        guard let db = db else { return [] }

        var result: [Card] = []
        do {
            for row in try db.prepare(cards) {
                let card = Card(
                    id: row[id],
                    japanese: row[japanese],
                    reading: row[reading],
                    english: row[english],
                    deckName: row[deckName],
                    ankiInterval: row[ankiInterval],
                    ankiDueDate: row[ankiDueDate],
                    ankiLastReviewed: row[ankiLastReviewed],
                    ankiEaseFactor: row[ankiEaseFactor],
                    updatedAt: row[updatedAt]
                )
                result.append(card)
            }
        } catch {
            print("Get all cards error: \(error)")
        }
        return result
    }

    func getCards(forDeck deck: String) -> [Card] {
        guard let db = db else { return [] }

        var result: [Card] = []
        do {
            let query = cards.filter(deckName == deck)
            for row in try db.prepare(query) {
                let card = Card(
                    id: row[id],
                    japanese: row[japanese],
                    reading: row[reading],
                    english: row[english],
                    deckName: row[deckName],
                    ankiInterval: row[ankiInterval],
                    ankiDueDate: row[ankiDueDate],
                    ankiLastReviewed: row[ankiLastReviewed],
                    ankiEaseFactor: row[ankiEaseFactor],
                    updatedAt: row[updatedAt]
                )
                result.append(card)
            }
        } catch {
            print("Get cards for deck error: \(error)")
        }
        return result
    }

    func getDeckNames() -> [String] {
        guard let db = db else { return [] }

        var result: [String] = []
        do {
            for row in try db.prepare(cards.select(distinct: deckName)) {
                result.append(row[deckName])
            }
        } catch {
            print("Get deck names error: \(error)")
        }
        return result
    }

    // MARK: - Daily Selection Operations

    func saveDailySelection(forDeck deck: String, date today: String, cardIds: [String]) {
        guard let db = db else { return }

        do {
            let encoder = JSONEncoder()
            let idsJson = String(data: try encoder.encode(cardIds), encoding: .utf8) ?? "[]"
            try db.run(dailySelections.insert(or: .replace,
                date <- today,
                deckNameSel <- deck,
                self.cardIds <- idsJson
            ))
        } catch {
            print("Save daily selection error: \(error)")
        }
    }

    func getDailySelection(forDeck deck: String, date today: String) -> [String] {
        guard let db = db else { return [] }

        do {
            let query = dailySelections.filter(date == today && deckNameSel == deck)
            if let row = try db.pluck(query) {
                let json = row[cardIds]
                let decoder = JSONDecoder()
                return try decoder.decode([String].self, from: json.data(using: .utf8)!)
            }
        } catch {
            print("Get daily selection error: \(error)")
        }
        return []
    }

    // MARK: - Settings Operations

    func getSettings() -> Settings {
        guard let db = db else { return .default }

        do {
            if let row = try db.pluck(settings.filter(settingsId == 1)) {
                let json = row[cardsPerDeck]
                let decoder = JSONDecoder()
                return try decoder.decode(Settings.self, from: json.data(using: .utf8)!)
            }
        } catch {
            print("Get settings error: \(error)")
        }
        return .default
    }

    func saveSettings(_ settings: Settings) {
        guard let db = db else { return }

        do {
            let encoder = JSONEncoder()
            let json = String(data: try encoder.encode(settings), encoding: .utf8) ?? "{}"
            try db.run(self.settings.filter(settingsId == 1).update(cardsPerDeck <- json))
        } catch {
            print("Save settings error: \(error)")
        }
    }

    // MARK: - Helpers

    func generateDailySelection(forDeck deck: String) -> [Card] {
        let today = ISO8601DateFormatter().string(from: Date()).split(separator: "T")[0].description
        let existingIds = getDailySelection(forDeck: deck, date: today)

        if !existingIds.isEmpty {
            return getCards(forDeck: deck).filter { existingIds.contains($0.id) }
        }

        let allCards = getCards(forDeck: deck).shuffled()
        let settings = getSettings()
        let count = min(settings.count(forDeck: deck), allCards.count)
        let selected = Array(allCards.prefix(count))
        let ids = selected.map { $0.id }

        saveDailySelection(forDeck: deck, date: today, cardIds: ids)
        return selected
    }

    func reshuffleDeck(_ deck: String) -> [Card] {
        let today = ISO8601DateFormatter().string(from: Date()).split(separator: "T")[0].description
        let allCards = getCards(forDeck: deck).shuffled()
        let settings = getSettings()
        let count = min(settings.count(forDeck: deck), allCards.count)
        let selected = Array(allCards.prefix(count))
        let ids = selected.map { $0.id }
        saveDailySelection(forDeck: deck, date: today, cardIds: ids)
        updateWidgetData()
        return selected
    }

    private func updateWidgetData() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.studylist.app") else {
            return
        }

        let fileURL = containerURL.appendingPathComponent("widget_cards.json")

        let decks = getDeckNames()
        var widgetCards: [[String: Any]] = []

        for deck in decks {
            let selected = generateDailySelection(forDeck: deck)
            for card in selected {
                widgetCards.append([
                    "id": card.id,
                    "japanese": card.japanese,
                    "reading": card.reading ?? "",
                    "english": card.english
                ])
            }
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: widgetCards)
            try data.write(to: fileURL)
        } catch {
            print("Widget data write error: \(error)")
        }
    }
}