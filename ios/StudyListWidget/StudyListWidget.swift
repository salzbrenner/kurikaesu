import WidgetKit
import SwiftUI

struct StudyEntry: TimelineEntry {
    let date: Date
    let cards: [WidgetCard]
}

struct WidgetCard: Identifiable, Codable {
    let id: String
    let japanese: String
    let reading: String?
    let english: String
}

struct StudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyEntry {
        StudyEntry(date: Date(), cards: [
            WidgetCard(id: "1", japanese: "食べる", reading: "たべる", english: "to eat"),
            WidgetCard(id: "2", japanese: "飲む", reading: "のむ", english: "to drink")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyEntry) -> Void) {
        let entry = StudyEntry(date: Date(), cards: loadCards())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyEntry>) -> Void) {
        let cards = loadCards()
        var entries: [StudyEntry] = []

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // Generate entries every 15 minutes
        for minute in stride(from: 0, to: 24 * 60, by: 15) {
            if let entryDate = calendar.date(byAdding: .minute, value: minute, to: startOfDay) {
                // Cycle through cards based on time
                let cardIndex = (minute / 15) % max(cards.count, 1)
                let displayCards = cardIndex < cards.count ? [cards[cardIndex]] : []

                if entryDate >= now {
                    let entry = StudyEntry(date: entryDate, cards: displayCards)
                    entries.append(entry)
                }
            }
        }

        // Refresh at midnight
        let refreshDate = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func loadCards() -> [WidgetCard] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.studylist.app") else {
            return []
        }

        let fileURL = containerURL.appendingPathComponent("widget_cards.json")

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([WidgetCard].self, from: data)
        } catch {
            print("Widget load error: \(error)")
            return []
        }
    }
}

struct StudyListWidgetEntryView: SwiftUI.View {
    @Environment(\.widgetFamily) var family
    var entry: StudyEntry

    var body: some SwiftUI.View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Study")
                    .font(.headline)
                ForEach(entry.cards.prefix(3)) { card in
                    Text(card.japanese)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                if entry.cards.isEmpty {
                    Text("No cards")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        case .accessoryInline:
            if let card = entry.cards.first {
                Text(card.japanese)
            } else {
                Text("Study List")
            }
        default:
            VStack(alignment: .leading) {
                Text("Study")
                    .font(.headline)
                ForEach(entry.cards.prefix(2)) { card in
                    Text(card.japanese)
                        .font(.body)
                }
            }
        }
    }
}

struct StudyListWidget: Widget {
    let kind: String = "StudyListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyProvider()) { entry in
            StudyListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Study List")
        .description("Daily Japanese study items")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}