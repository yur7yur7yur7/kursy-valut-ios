import Foundation

/// Разбор страницы https://kurs.onliner.by/ — единый снимок курсов всех банков.
///
/// В разметке шесть таблиц (по одной на валютную пару) и шесть маркеров графика
/// b-currency-chart-i usd/byn, eur/byn, rub/byn, eur/usd, eur/rub, usd/rub.
/// В модель попадают только пары usd/byn и rub/byn — полей для евро нет.
///
/// Важно: координаты отделений лежат в атрибутах data-latitude/data-longitude,
/// причём широта и долгота перепутаны — определяем их по диапазону.
enum OnlinerParser {

    /// Порядок пар, если маркеры графика не совпали с числом таблиц.
    private static let fallbackPairs = ["usd/byn", "eur/byn", "rub/byn",
                                        "eur/usd", "eur/rub", "usd/rub"]

    private static let ruMonths = ["января", "февраля", "марта", "апреля", "мая", "июня",
                                   "июля", "августа", "сентября", "октября", "ноября", "декабря"]

    /// Названия банков на onliner -> slug'и приложения.
    private static let bankSlugs: [String: String] = [
        "беларусбанк": "belarusbank",
        "технобанк": "technobank",
        "мтбанк": "mtbank",
        "альфа банк": "alfabank",
        "белагропромбанк": "belagroprombank",
        "банк ррб": "rrb-bank",
        "сбер банк": "bps-sberbank",
        "бнб-банк": "bnbank",
        "паритетбанк": "paritetbank",
        "белгазпромбанк": "belgazprombank",
        "приорбанк": "priorbank",
        "статусбанк": "statusbank",
        "банк втб (беларусь)": "bank-vtb",
        "бсб банк": "belswissbank",
        "белинвестбанк": "belinvestbank",
        "банк дабрабыт": "dabrabyt",
        "банк белвэб": "bvebank",
        "цептер банк": "zepterbank",
        "нео банк азия": "neobank",
        "банк решение": "reshenie",
        "белинкасгрупп": "belinkasgrupp",
        "тк банк": "tkbank"
    ]

    /// Разбирает страницу: «slug банка -> данные банка».
    static func parse(_ html: String) -> [String: BankData] {
        var result: [String: BankData] = [:]
        if html.isEmpty { return result }
        let tables = htmlTables(html)
        if tables.isEmpty { return result }
        let pairs = tablePairs(html, tableCount: tables.count)
        let date = pageDate(html)

        // отделения всех банков: ключ «slug + адрес»
        var offices: [String: BankData.Office] = [:]

        for (index, table) in tables.enumerated() {
            let pair = index < pairs.count ? pairs[index] : ""
            let usd = pair == "usd/byn"
            let rub = pair == "rub/byn"
            if !usd && !rub { continue }

            for row in tableRows(table) {
                let cells = tableCells(row)
                if cells.count < 4 { continue }
                let name = HTML.strip(cells[0])
                guard let slug = slugOf(name) else { continue }
                guard let first = HTML.number(cells[1]), let second = HTML.number(cells[2]) else {
                    continue
                }
                let address = addressOf(cells[3])
                if address.isEmpty { continue }

                let key = slug + "/" + address
                if offices[key] == nil {
                    var office = BankData.Office(id: address,
                                                 address: address,
                                                 time: "",
                                                 usdSell: 0,
                                                 usdBuy: 0,
                                                 rubSell: 0,
                                                 rubBuy: 0,
                                                 lat: 0,
                                                 lon: 0,
                                                 type: cells.count > 4 ? typeOf(cells[4]) : "")
                    geo(of: cells[3], into: &office)
                    offices[key] = office
                    if result[slug] == nil {
                        var bank = BankData()
                        bank.slug = slug
                        bank.title = name
                        bank.date = date
                        result[slug] = bank
                    }
                    result[slug]?.offices.append(office)
                }
                if usd {
                    if offices[key]!.usdSell <= 0 { offices[key]!.usdSell = first }
                    if offices[key]!.usdBuy <= 0 { offices[key]!.usdBuy = second }
                } else {
                    if offices[key]!.rubSell <= 0 { offices[key]!.rubSell = first }
                    if offices[key]!.rubBuy <= 0 { offices[key]!.rubBuy = second }
                }
            }
        }
        return result
    }

    /* ------------------------------------------------------------- разметка */

    private static func htmlTables(_ html: String) -> [String] {
        HTML.matches("<table class=\"b-currency-table__more\">(.*?)</table>", html)
            .compactMap { $0.count > 1 ? $0[1] : nil }
    }

    private static func tableRows(_ table: String) -> [String] {
        var body = table
        if let tbody = HTML.firstMatch("<tbody>(.*?)</tbody>", table), tbody.count > 1 {
            body = tbody[1]
        }
        return HTML.matches("<tr[^>]*>(.*?)</tr>", body).compactMap { $0.count > 1 ? $0[1] : nil }
    }

    private static func tableCells(_ row: String) -> [String] {
        HTML.matches("<td[^>]*>(.*?)</td>", row).compactMap { $0.count > 1 ? $0[1] : nil }
    }

    /// Пары валют в порядке таблиц: по маркерам графика, иначе — фиксированный порядок.
    private static func tablePairs(_ html: String, tableCount: Int) -> [String] {
        let marked = HTML.matches("b-currency-chart-i ([a-z]+/[a-z]+)", html)
            .compactMap { $0.count > 1 ? $0[1] : nil }
        if marked.count == tableCount { return marked }
        var list: [String] = []
        for i in 0..<min(tableCount, fallbackPairs.count) {
            list.append(fallbackPairs[i])
        }
        return list
    }

    /// Адрес отделения: из data-address, иначе из текста в <i>.
    private static func addressOf(_ cell: String) -> String {
        if let value = HTML.attr(cell, "data-address") {
            let clean = HTML.strip(value)
            if !clean.isEmpty { return clean }
        }
        if let match = HTML.firstMatch("<i[^>]*>(.*?)</i>", cell), match.count > 1 {
            return HTML.strip(match[1])
        }
        return ""
    }

    /// Координаты отделения: на onliner широта и долгота перепутаны,
    /// поэтому определяем их по диапазону (широта 45..60, долгота 20..35).
    private static func geo(of cell: String, into office: inout BankData.Office) {
        guard let rawLat = HTML.attr(cell, "data-latitude"),
              let rawLon = HTML.attr(cell, "data-longitude"),
              let a = Double(rawLat.trimmingCharacters(in: .whitespaces)),
              let b = Double(rawLon.trimmingCharacters(in: .whitespaces)) else { return }
        if inRange(a, 45, 60) && inRange(b, 20, 35) {
            office.lat = a
            office.lon = b
        } else if inRange(b, 45, 60) && inRange(a, 20, 35) {
            office.lat = b
            office.lon = a
        }
    }

    private static func inRange(_ value: Double, _ min: Double, _ max: Double) -> Bool {
        value >= min && value <= max
    }

    /// Короткий тип отделения из колонки «Филиал».
    private static func typeOf(_ raw: String) -> String {
        let t = HTML.strip(raw).lowercased()
        if t.isEmpty { return "" }
        if t.contains("пункт обмена валют") { return "Пункт обмена валют" }
        if t.contains("обменный пункт") { return "Обменный пункт" }
        if t.contains("головной офис") { return "Головной офис" }
        if t.contains("сервисный офис") { return "Сервисный офис" }
        if t.contains("дополнительный офис") || t.contains("доп. офис") { return "Доп. офис" }
        // «ОП №3 ЦБУ Каменная Горка» — это отделение при ЦБУ, а не сам ЦБУ
        if t.hasPrefix("оп ") || t.hasPrefix("оп№") || t.hasPrefix("оп.") { return "Отделение" }
        if t.contains("центр банковских услуг") || t.contains("цбу") { return "ЦБУ" }
        if t.contains("операционная касса") { return "Операционная касса" }
        if t.contains("ркц") || t.contains("урм") { return "РКЦ/УРМ" }
        if t.contains("отделение") { return "Отделение" }
        if t.contains("офис продаж") { return "Офис продаж" }
        if t.contains("офис") { return "Офис" }
        return ""
    }

    /// Slug банка по названию на onliner (сравнение без лишних пробелов и дефисов).
    private static func slugOf(_ name: String) -> String? {
        let key = HTML.collapse(name)
        if key.isEmpty { return nil }
        if let slug = bankSlugs[key.lowercased()] { return slug }
        let loose = key.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        for (name, slug) in bankSlugs {
            let other = name.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
            if other == loose { return slug }
        }
        return nil
    }

    /// Дата страницы в формате dd.MM.yyyy; год — текущий.
    private static func pageDate(_ html: String) -> String {
        var day = 0
        var month = 0
        if let match = HTML.firstMatch("<th class=\"th-first\"[^>]*>\\s*(\\d{1,2})\\s+([а-яё]+)\\s*</th>", html),
           match.count > 2 {
            day = Int(match[1]) ?? 0
            month = monthIndex(match[2])
        } else if let match = HTML.firstMatch(
            "(\\d{1,2})\\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)",
            html), match.count > 2 {
            day = Int(match[1]) ?? 0
            month = monthIndex(match[2])
        }
        guard day > 0, month > 0 else { return "" }
        let year = Calendar.current.component(.year, from: Date())
        return String(format: "%02d.%02d.%04d", day, month, year)
    }

    private static func monthIndex(_ name: String) -> Int {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard n.count >= 3 else { return -1 }
        for (index, month) in ruMonths.enumerated() where month.hasPrefix(String(n.prefix(3))) {
            return index + 1
        }
        return -1
    }
}
