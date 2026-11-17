import Foundation

/// Собирает курсы из источников параллельно:
///  - Яндекс: мини-ответ «конвертер валют»;
///  - myfin.by: официальные курсы НБ РБ и ЦБ РФ;
///  - kurs.onliner.by: единый снимок курсов всех банков (с координатами отделений).
enum RatesRepository {

    struct Result {
        var rates = Rates()
        /// Курсы обменников по отделениям банков.
        var banks: [String: BankData] = [:]
        /// Снимок курсов всех банков: единый момент времени для всех банков.
        var snapshot: [String: BankData] = [:]
        /// Сеть доступна и хотя бы один источник ответил.
        var networkOk = false
        /// Человекочитаемая причина неудачи.
        var error = ""
    }

    /// Ответ источника: значение или причина неудачи.
    private struct Fetched<T> {
        var value: T?
        var error: String?
    }

    /// Загружает курсы и страницы обменников.
    ///
    /// - Parameter cached: официальные курсы из прошлого обновления: если они свежие,
    ///   заново не спрашиваем (они меняются раз в сутки).
    static func load(cached: Rates?) async -> Result {
        var result = Result()
        var errors: [String] = []

        let reuseCached = cached != nil && !(cached?.rows.isEmpty ?? true)
            && (cached?.fetchedAt ?? 0) > 0
            && Date().timeIntervalSince1970 - (cached?.fetchedAt ?? 0) < HTTP.officialTTL

        async let yandexUsdRub = fetchYandex("USD_RUB", "RUB")
        async let yandexUsdByn = fetchYandex("USD_BYN", "BYN")
        async let yandexRubByn = fetchYandex("RUB_BYN", "BYN")
        async let myfinNbrb = fetchMyfin(HTTP.myfinNbrbURL, "НБ РБ")
        async let myfinCbr = fetchMyfin(HTTP.myfinCbrURL, "ЦБ РФ")
        async let snapshot = fetchSnapshot()

        var rates = Rates()
        rates.fetchedAt = Date().timeIntervalSince1970

        if reuseCached, let cached {
            rates = cached
            rates.fetchedAt = Date().timeIntervalSince1970
        } else {
            let (a, b, c, d, e) = await (yandexUsdRub, yandexUsdByn, yandexRubByn, myfinNbrb, myfinCbr)
            for message in [a.error, b.error, c.error, d.error, e.error].compactMap({ $0 }) {
                errors.append(message)
            }

            if let usdRub = a.value, usdRub.ok {
                rates.rows.append(Rates.Row(from: "USD", to: "RUB", provider: Rates.providerYandex,
                                            source: usdRub.source, date: usdRub.date, value: usdRub.value))
                rates.yandexOk = true
            }
            if let usdByn = b.value, usdByn.ok {
                rates.rows.append(Rates.Row(from: "USD", to: "BYN", provider: Rates.providerYandex,
                                            source: usdByn.source, date: usdByn.date, value: usdByn.value))
                rates.yandexOk = true
            }
            if let rubByn = c.value, rubByn.ok {
                rates.rows.append(Rates.Row(from: "RUB", to: "BYN", provider: Rates.providerYandex,
                                            source: rubByn.source, date: rubByn.date, value: rubByn.value))
                rates.yandexOk = true
            }
            if let nbrb = d.value, nbrb.ok {
                if let usd = nbrb.rates["USD"] {
                    rates.rows.append(Rates.Row(from: "USD", to: "BYN", provider: Rates.providerMyfin,
                                                source: "НБ РБ", date: nbrb.date, value: usd))
                    rates.myfinOk = true
                }
                if let rub = nbrb.rates["RUB"] {
                    rates.rows.append(Rates.Row(from: "RUB", to: "BYN", provider: Rates.providerMyfin,
                                                source: "НБ РБ", date: nbrb.date, value: rub))
                    rates.myfinOk = true
                }
            }
            if let cbr = e.value, cbr.ok {
                if let usd = cbr.rates["USD"] {
                    rates.rows.append(Rates.Row(from: "USD", to: "RUB", provider: Rates.providerMyfin,
                                                source: "ЦБ РФ", date: cbr.date, value: usd))
                    rates.myfinOk = true
                }
                if let byn = cbr.rates["BYN"] {
                    rates.rows.append(Rates.Row(from: "BYN", to: "RUB", provider: Rates.providerMyfin,
                                                source: "ЦБ РФ", date: cbr.date, value: byn))
                    rates.myfinOk = true
                }
            }
        }

        result.rates = rates
        result.networkOk = rates.yandexOk || rates.myfinOk

        let snap = await snapshot
        if snap.value != nil {
            if let message = snap.error { errors.append(message) }
            if let map = snap.value, !map.isEmpty {
                result.snapshot = map
                result.banks = map
                result.networkOk = true
            }
        }

        if !result.networkOk {
            result.error = errors.isEmpty ? "Нет данных" : errors[0]
        } else if !errors.isEmpty {
            result.error = errors[0]
        }
        return result
    }

    private static func fetchYandex(_ pair: String,
                                     _ toCode: String) async -> Fetched<RatesParser.YandexRate> {
        do {
            let html = try await HTTP.get(HTTP.yandexBase + pair)
            return Fetched(value: RatesParser.parseYandex(html, toCode), error: nil)
        } catch {
            return Fetched(value: nil, error: "Яндекс (\(pair)): \(error.localizedDescription)")
        }
    }

    private static func fetchMyfin(_ url: String,
                                   _ label: String) async -> Fetched<RatesParser.MyfinTable> {
        do {
            let html = try await HTTP.get(url)
            return Fetched(value: RatesParser.parseMyfin(html), error: nil)
        } catch {
            return Fetched(value: nil, error: "myfin.by (\(label)): \(error.localizedDescription)")
        }
    }

    private static func fetchSnapshot() async -> Fetched<[String: BankData]> {
        do {
            let html = try await HTTP.get(HTTP.onlinerURL)
            var map = OnlinerParser.parse(html)
            let now = Date().timeIntervalSince1970
            for key in map.keys {
                map[key]?.fetchedAt = now
            }
            return Fetched(value: map, error: nil)
        } catch {
            return Fetched(value: nil, error: "onliner.by (снимок курсов): \(error.localizedDescription)")
        }
    }
}
