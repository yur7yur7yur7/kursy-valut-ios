import Foundation

/// Разбор HTML Яндекса (мини-ответ «конвертер валют») и myfin.by.
enum RatesParser {

    /// Курс из страницы Яндекса.
    struct YandexRate {
        var value: Double = 0
        var source: String = ""
        var date: String = ""
        var ok: Bool = false
    }

    /// Таблица курсов myfin.by (НБ РБ или ЦБ РФ).
    struct MyfinTable {
        /// Код валюты -> курс за одну единицу валюты.
        var rates: [String: Double] = [:]
        var date: String = ""
        var ok: Bool = false
        /// Откуда взяты данные: «myfin.by», «НБ РБ», «ЦБ РФ».
        var origin: String = ""
    }

    private static let ruMonths = ["января", "февраля", "марта", "апреля", "мая", "июня",
                                   "июля", "августа", "сентября", "октября", "ноября", "декабря"]

    /// Достаёт курс со страницы https://yandex.ru/finance/currencies/XXX_YYY.
    ///
    /// - Parameter toCode: код котируемой валюты (RUB / BYN) — запасной источник значения.
    static func parseYandex(_ html: String, _ toCode: String) -> YandexRate {
        var result = YandexRate()
        if html.isEmpty { return result }

        if let match = HTML.firstMatch("ConverterInfo-Rate\"[^>]*>([^<]*)<", html), match.count > 1 {
            let line = match[1]
            if let eq = line.firstIndex(of: "=") {
                let tail = String(line[line.index(after: eq)...])
                if let value = HTML.number(tail) {
                    result.value = value
                    result.ok = true
                }
            }
        }

        if !result.ok {
            for match in HTML.matches("aria-label=\"Валюта:\\s*([A-Z]{3})\"[^>]*value=\"([0-9.,]+)\"", html) {
                if match.count > 2, match[1].caseInsensitiveCompare(toCode) == .orderedSame {
                    if let value = HTML.number(match[2]) {
                        result.value = value
                        result.ok = true
                        break
                    }
                }
            }
        }

        if let match = HTML.firstMatch("ConverterInfo-BurseName\"[^>]*>([^<]*)<", html), match.count > 1 {
            result.source = HTML.strip(match[1])
        }

        if let match = HTML.firstMatch("на\\s+(\\d{1,2})\\s+([а-яё]+)\\s+(\\d{4})\\s+года", html),
           match.count > 3 {
            let day = Int(match[1]) ?? 0
            let month = monthIndex(match[2])
            let year = Int(match[3]) ?? 0
            if month > 0 {
                result.date = String(format: "%02d.%02d.%04d", day, month, year)
            }
        }
        if result.date.isEmpty {
            if let match = HTML.firstMatch("Обновлено[^0-9]{0,15}(\\d{2})\\.(\\d{2})\\.(\\d{4})", html),
               match.count > 3 {
                result.date = "\(match[1]).\(match[2]).\(match[3])"
            }
        }
        return result
    }

    /// Разбирает таблицу курсов myfin.by (НБ РБ или ЦБ РФ).
    ///
    /// Поддерживаются десктопная таблица и мобильная адаптивная вёрстка.
    /// Колонок может быть четыре (Валюта | Курс | Код | Единиц) или пять
    /// (добавилась «Курс на завтра»), поэтому код и единицы ищутся по содержимому
    /// ячеек, а не по фиксированным индексам.
    static func parseMyfin(_ html: String) -> MyfinTable {
        var table = MyfinTable()
        if html.isEmpty { return table }

        if let match = HTML.firstMatch("value=\"(\\d{2}\\.\\d{2}\\.\\d{4})\"", html), match.count > 1 {
            table.date = match[1]
        }

        for row in HTML.matches("<tr[^>]*>(.*?)</tr>", html) {
            guard row.count > 1 else { continue }
            let cells = HTML.matches("<td[^>]*>(.*?)</td>", row[1]).compactMap { $0.count > 1 ? $0[1] : nil }
            if cells.count < 4 { continue }

            var code: String?
            var codeIndex = -1
            for (index, cell) in cells.enumerated() {
                let value = HTML.strip(cell).trimmingCharacters(in: .whitespaces)
                if value.count == 3,
                   value == value.uppercased(),
                   value.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil {
                    code = value
                    codeIndex = index
                    break
                }
            }
            guard let currency = code, codeIndex >= 2 else { continue }

            var rate: Double?
            for index in 1..<codeIndex {
                if let value = HTML.number(cells[index]) {
                    rate = value
                    break
                }
            }
            guard let rateValue = rate else { continue }

            var unit: Double?
            for index in (codeIndex + 1)..<cells.count {
                if let value = HTML.number(cells[index]), value > 0 {
                    unit = value
                    break
                }
            }
            let unitValue = (unit ?? 1) == 0 ? 1 : (unit ?? 1)
            table.rates[currency] = rateValue / unitValue
            table.ok = true
        }

        if !table.ok {
            parseAdaptive(html, &table)
        }
        return table
    }

    /// Мобильная адаптивная таблица: ячейки подписаны («Код», «Единиц», «Курс»).
    private static func parseAdaptive(_ html: String, _ table: inout MyfinTable) {
        var code: String?
        var rate: Double?
        var unit: Double?
        let cells = HTML.matches(
            "table-adaptive__cell\"[^>]*>(.*?)(?=table-adaptive__cell|table-adaptive__row|<table)",
            html)
        for match in cells {
            guard match.count > 1 else { continue }
            let chunk = match[1]
            guard let nameMatch = HTML.firstMatch("table-adaptive__name-mob\"[^>]*>(.*?)</div>", chunk),
                  let valueMatch = HTML.firstMatch("table-adaptive__value\"[^>]*>(.*?)</div>", chunk) else {
                continue
            }
            let label = HTML.strip(nameMatch.count > 1 ? nameMatch[1] : "").lowercased()
            let value = HTML.strip(valueMatch.count > 1 ? valueMatch[1] : "")
            if label == "код" {
                if let found = HTML.firstMatch("\\b([A-Z]{3})\\b", value), found.count > 1 {
                    code = found[1]
                }
            } else if label == "единиц" {
                unit = HTML.number(value)
            } else if label == "курс" {
                // именно «Курс», а не «Курс на завтра»
                rate = HTML.number(value)
            }
            if let currency = code, let rateValue = rate {
                let unitValue = (unit ?? 1) == 0 ? 1 : (unit ?? 1)
                table.rates[currency] = rateValue / unitValue
                table.ok = true
                code = nil
                rate = nil
                unit = nil
            }
        }
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
