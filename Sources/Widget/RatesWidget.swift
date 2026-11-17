import SwiftUI
import WidgetKit

/// Данные для виджета.
struct RatesWidgetEntry: TimelineEntry {
    let date: Date
    /// Официальный курс доллара, например «1 $ = 2,9977 BYN».
    let official: String
    /// Лучший курс по городу, например «Лучшее в городе: 2,995 BYN».
    let best: String
    /// Время, когда данные получены.
    let fetchedAt: Date?
}

/// Виджет на рабочем столе: официальный курс и лучший курс по городу.
///
/// Виджет сам забирает данные из сети и кеширует их в своём контейнере:
/// общая группа приложений (App Groups) нужна платному аккаунту разработчика,
/// а при установке через Sideloadly её как раз нет.
struct RatesProvider: TimelineProvider {

    func placeholder(in context: Context) -> RatesWidgetEntry {
        RatesWidgetEntry(date: Date(),
                          official: "1 $ = 2,9977 BYN",
                          best: "Лучшее в городе: 2,995 BYN",
                          fetchedAt: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RatesWidgetEntry) -> Void) {
        if let cached = Cache.load() {
            completion(cached)
            return
        }
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RatesWidgetEntry>) -> Void) {
        Task {
            let entry = await load()
            // обновляемся примерно раз в полчаса
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func load() async -> RatesWidgetEntry {
        let result = await RatesRepository.load(cached: Cache.loadRates())
        var official = "—"
        if let usd = result.rates.anyRate("USD", "BYN") {
            official = "1 $ = \(Fmt.exact(usd, 4)) BYN"
        }
        var best = "—"
        if let top = BankData.bestAcross(result.snapshot).first {
            best = "Лучшее в городе: \(Fmt.exact(top.usdSell, 4)) BYN"
        }
        let entry = RatesWidgetEntry(date: Date(),
                                     official: official,
                                     best: best,
                                     fetchedAt: result.rates.fetchedAt > 0
                                        ? Date(timeIntervalSince1970: result.rates.fetchedAt)
                                        : nil)
        Cache.save(entry)
        Cache.saveRates(result.rates)
        return entry
    }
}

/// Кеш виджета: своё хранилище, общий с приложением доступ к нему невозможен.
enum Cache {
    private static let key = "widget_entry"

    static func load() -> RatesWidgetEntry? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedEntry.self, from: data).entry
    }

    static func save(_ entry: RatesWidgetEntry) {
        let cached = CachedEntry(date: entry.date,
                                 official: entry.official,
                                 best: entry.best,
                                 fetchedAt: entry.fetchedAt?.timeIntervalSince1970 ?? 0)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func saveRates(_ rates: Rates) {
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: "widget_rates")
        }
    }

    static func loadRates() -> Rates? {
        guard let data = UserDefaults.standard.data(forKey: "widget_rates") else { return nil }
        return try? JSONDecoder().decode(Rates.self, from: data)
    }

    struct CachedEntry: Codable {
        let date: Date
        let official: String
        let best: String
        let fetchedAt: Double

        var entry: RatesWidgetEntry {
            RatesWidgetEntry(date: date,
                             official: official,
                             best: best,
                             fetchedAt: fetchedAt > 0 ? Date(timeIntervalSince1970: fetchedAt) : nil)
        }
    }
}

/// Виджет «Курсы валют».
struct RatesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RatesWidget", provider: RatesProvider()) { entry in
            RatesWidgetView(entry: entry)
        }
        .configurationDisplayName("Курсы валют")
        .description("Официальный курс и лучший курс по городу.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Отрисовка виджета.
struct RatesWidgetView: View {
    let entry: RatesWidgetEntry

    var body: some View {
        content
            .padding(12)
            .containerBackgroundCompat()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("КУРСЫ ВАЛЮТ")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.1)
                    .foregroundColor(Color(hex: 0x8A8A8F))
                Spacer()
                if let fetched = entry.fetchedAt {
                    Text(fetched, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: 0x8A8A8F))
                }
            }
            Text(entry.official)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: 0x2ECC71))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(entry.best)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0xE8E8EA))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Фон виджета: на iOS 17+ обязателен containerBackground, раньше — прозрачный.
    @ViewBuilder
    func containerBackgroundCompat() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(Color(hex: 0x151517), for: .widget)
        } else {
            self
        }
    }
}

@main
struct RatesWidgetBundle: WidgetBundle {
    var body: some Widget {
        RatesWidget()
    }
}
