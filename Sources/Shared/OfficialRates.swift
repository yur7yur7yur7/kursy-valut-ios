import Foundation

/// Официальные курсы с сайтов регуляторов:
///  - ЦБ РФ: XML ежедневных курсов (cbr.ru) — лёгкий ответ, всегда доступен;
///  - НБ РБ: JSON (nbrb.by).
///
/// Нужны как запасной источник: myfin.by защищает сайт от ботов и отвечает
/// «HTTP 423», из-за чего официальные курсы пропадают из приложения.
enum OfficialRates {

    /// Курсы одного официального источника.
    struct Table {
        /// Код валюты -> курс за одну единицу валюты.
        var rates: [String: Double] = [:]
        /// Дата курсов (dd.MM.yyyy).
        var date: String = ""
        /// true — данные разобраны.
        var ok: Bool = false
        /// Откуда взяты данные: «myfin.by», «НБ РБ», «ЦБ РФ».
        var origin: String = ""
    }

    /// Разбирает XML ЦБ РФ (https://www.cbr.ru/scripts/XML_daily.asp).
    ///
    /// Курсы в XML — за номинал (обычно 1, у некоторых валют 10 или 100),
    /// поэтому берём VunitRate — это курс за одну единицу.
    ///
    /// - Returns: курсы в рублях за 1 единицу валюты (USD -> 82,19; BYN -> 27,42)
    static func parseCbr(_ xml: String) -> Table {
        var table = Table()
        if xml.isEmpty { return table }

        if let match = HTML.firstMatch("<ValCurs Date=\"([^\"]+)\"", xml), match.count > 1 {
            table.date = match[1].trimmingCharacters(in: .whitespaces)
        }

        for block in HTML.matches("<Valute[^>]*>(.*?)</Valute>", xml) {
            guard block.count > 1 else { continue }
            let chunk = block[1]
            guard let codeMatch = HTML.firstMatch("<CharCode>([A-Z]{3})</CharCode>", chunk),
                  codeMatch.count > 1 else { continue }
            let code = codeMatch[1]

            var rate: Double?
            if let unitMatch = HTML.firstMatch("<VunitRate>([^<]*)</VunitRate>", chunk),
               unitMatch.count > 1, let value = HTML.number(unitMatch[1]) {
                rate = value
            }
            if rate == nil {
                var nominal = 1.0
                if let nomMatch = HTML.firstMatch("<Nominal>(\\d+)</Nominal>", chunk), nomMatch.count > 1 {
                    nominal = Double(nomMatch[1]) ?? 1
                }
                if let valueMatch = HTML.firstMatch("<Value>([^<]*)</Value>", chunk),
                   valueMatch.count > 1, let value = HTML.number(valueMatch[1]), nominal > 0 {
                    rate = value / nominal
                }
            }
            if let value = rate, value > 0 {
                table.rates[code] = value
                table.ok = true
            }
        }
        return table
    }

    /// Разбирает JSON НБ РБ (https://www.nbrb.by/StatExchangeRates/LastDayRate).
    ///
    /// Формат: {"CurId":840,"Date":"2026-11-23","Rate":3.0003} — курс в
    /// белорусских рублях за одну единицу валюты. Рубль (643) НБ РБ котирует
    /// за 100 рублей, поэтому его курс не разбираем: он считается через доллар.
    ///
    /// - Returns: курсы в белорусских рублях за 1 единицу (USD -> 3,0003)
    static func parseNbrb(_ json: String) -> Table {
        var table = Table()
        if json.isEmpty { return table }

        if let match = HTML.firstMatch("\"Date\"\\s*:\\s*\"([^\"]+)\"", json), match.count > 1 {
            let parts = match[1].trimmingCharacters(in: .whitespaces).split(separator: "-")
            if parts.count == 3 {
                table.date = "\(parts[2]).\(parts[1]).\(parts[0])"
            }
        }

        let ids = HTML.matches("\"CurId\"\\s*:\\s*(\\d+)", json)
        let values = HTML.matches("\"Rate\"\\s*:\\s*([0-9.]+)", json)
        for (index, idMatch) in ids.enumerated() where index < values.count {
            guard idMatch.count > 1, values[index].count > 1 else { continue }
            if idMatch[1] == "840", let rate = HTML.number(values[index][1]), rate > 0 {
                table.rates["USD"] = rate
                table.ok = true
            }
        }
        return table
    }
}
