import Foundation

/// Собирает курсы из источников параллельно:
///  - Яндекс: мини-ответ «конвертер валют»;
///  - myfin.by: официальные курсы НБ РБ и ЦБ РФ (а если он не ответил —
///    сайты регуляторов: nbrb.by и cbr.ru);
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

        // Кеш используем, только если прошлая попытка удалась: иначе повторяем
        // запрос сразу, а не ждём истечения срока.
        let reuseCached = cached != nil && !(cached?.rows.isEmpty ?? true)
            && (cached?.officialFetchedAt ?? 0) > 0
            && !(cached?.officialStale ?? true)
            && Date().timeIntervalSince1970 - (cached?.officialFetchedAt ?? 0) < HTTP.officialTTL

        async let yandexUsdRub = fetchYandex("USD_RUB", "RUB")
        async let yandexUsdByn = fetchYandex("USD_BYN", "BYN")
        async let yandexRubByn = fetchYandex("RUB_BYN", "BYN")
        async let nbrb = fetchNbrb()
        async let cbr = fetchCbr()
        async let snapshot = fetchSnapshot()

        var rates = Rates()
        rates.fetchedAt = Date().timeIntervalSince1970

        if reuseCached, let cached {
            rates = cached
            // время обновления официальных курсов не двигаем, иначе срок
            // ожидания постоянно продлевался бы
            rates.officialFetchedAt = cached.officialFetchedAt
            rates.fetchedAt = Date().timeIntervalSince1970
        } else {
            let (a, b, c, d, e) = await (yandexUsdRub, yandexUsdByn, yandexRubByn, nbrb, cbr)
            for message in [a.error, b.error, c.error, d.error, e.error].compactMap({ $0 }) {
                errors.append(message)
            }

            // --- Яндекс: удалось — новое значение, не удалось — оставляем прошлое ---
            let freshUsdRub = addYandex(&rates, a.value, "USD", "RUB", cached)
            let freshUsdByn = addYandex(&rates, b.value, "USD", "BYN", cached)
            let freshRubByn = addYandex(&rates, c.value, "RUB", "BYN", cached)
            let yandexFresh = freshUsdRub || freshUsdByn || freshRubByn
            rates.yandexOk = yandexFresh

            // --- официальные курсы: НБ РБ и ЦБ РФ ---
            var nbrbUsd: Double?
            var nbrbRub: Double?
            var cbrUsd: Double?
            var cbrByn: Double?
            if let table = d.value, table.ok {
                nbrbUsd = table.rates["USD"]
                nbrbRub = table.rates["RUB"]
            }
            if let table = e.value, table.ok {
                cbrUsd = table.rates["USD"]
                cbrByn = table.rates["BYN"]
            }
            var nbrbDate = d.value?.date ?? ""
            var cbrDate = e.value?.date ?? ""

            // myfin.by не ответил — берём те же официальные курсы из Яндекса:
            // там они перепечатаны с указанием источника (НБ РБ, ЦБ РФ).
            var fromYandex = false
            if nbrbUsd == nil, let row = find(rates, "USD", "BYN", Rates.providerYandex) {
                nbrbUsd = row.value
                nbrbDate = row.date
                fromYandex = true
            }
            if nbrbRub == nil, let row = find(rates, "RUB", "BYN", Rates.providerYandex) {
                nbrbRub = row.value
                if nbrbDate.isEmpty { nbrbDate = row.date }
                fromYandex = true
            }
            if cbrUsd == nil, let row = find(rates, "USD", "RUB", Rates.providerYandex) {
                cbrUsd = row.value
                cbrDate = row.date
                fromYandex = true
            }
            if cbrByn == nil, let usd = cbrUsd, usd > 0, let byn = nbrbUsd, byn > 0 {
                // BYN->RUB восстанавливаем из USD->RUB и USD->BYN
                cbrByn = usd / byn
                fromYandex = true
            }

            var myfinFresh = false
            if let usd = nbrbUsd {
                rates.rows.append(Rates.Row(from: "USD", to: "BYN", provider: Rates.providerMyfin,
                                            source: "НБ РБ", date: nbrbDate, value: usd))
                myfinFresh = true
            }
            if let rub = nbrbRub {
                rates.rows.append(Rates.Row(from: "RUB", to: "BYN", provider: Rates.providerMyfin,
                                            source: "НБ РБ", date: nbrbDate, value: rub))
                myfinFresh = true
            }
            if let usd = cbrUsd {
                rates.rows.append(Rates.Row(from: "USD", to: "RUB", provider: Rates.providerMyfin,
                                            source: "ЦБ РФ", date: cbrDate, value: usd))
                myfinFresh = true
            }
            if let byn = cbrByn {
                rates.rows.append(Rates.Row(from: "BYN", to: "RUB", provider: Rates.providerMyfin,
                                            source: "ЦБ РФ", date: cbrDate, value: byn))
                myfinFresh = true
            }
            // Не хватает одной пары — считаем её через другие.
            if nbrbUsd == nil, let usd = cbrUsd, let byn = cbrByn, byn > 0 {
                rates.rows.append(Rates.Row(from: "USD", to: "BYN", provider: Rates.providerMyfin,
                                            source: "ЦБ РФ (расчёт)", date: cbrDate, value: usd / byn))
                myfinFresh = true
            }
            if nbrbRub == nil, let usd = nbrbUsd, let rub = cbrUsd, rub > 0 {
                rates.rows.append(Rates.Row(from: "RUB", to: "BYN", provider: Rates.providerMyfin,
                                            source: "НБ РБ · ЦБ РФ (расчёт)",
                                            date: cbrDate.isEmpty ? nbrbDate : cbrDate,
                                            value: usd / rub))
                myfinFresh = true
            }
            rates.myfinOk = myfinFresh

            // если часть официальных курсов не обновилась — показываем прошлые
            if !yandexFresh || !myfinFresh {
                keepCachedRows(&rates, cached, Rates.providerYandex)
                keepCachedRows(&rates, cached, Rates.providerMyfin)
            }

            if rates.yandexOk && rates.myfinOk {
                rates.officialFetchedAt = Date().timeIntervalSince1970
                rates.officialStale = false
            } else {
                rates.officialStale = true
                rates.officialFetchedAt = cached?.officialFetchedAt ?? 0
            }
            let fromMyfin = d.value?.origin == "myfin.by" || e.value?.origin == "myfin.by"
            rates.officialTitle = (fromMyfin && !fromYandex) ? "myfin.by" : "Официальные курсы"
            rates.officialSubtitle = officialSubtitle(hasNbrb: nbrbUsd != nil || nbrbRub != nil,
                                                       hasCbr: cbrUsd != nil || cbrByn != nil)
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
            result.error = errors.isEmpty ? "Нет данных" : joinErrors(errors)
        } else if !errors.isEmpty {
            result.error = joinErrors(errors)
        }
        return result
    }

    /// Состав источников под названием блока: «НБ РБ · ЦБ РФ».
    private static func officialSubtitle(hasNbrb: Bool, hasCbr: Bool) -> String {
        if hasNbrb && hasCbr { return "НБ РБ · ЦБ РФ" }
        if hasNbrb { return "НБ РБ" }
        if hasCbr { return "ЦБ РФ" }
        return "НБ РБ · ЦБ РФ"
    }

    /// Ошибки источников одной строкой: показываем первые три.
    private static func joinErrors(_ errors: [String]) -> String {
        errors.prefix(3).joined(separator: "  ·  ")
    }

    private static func find(_ rates: Rates, _ from: String, _ to: String,
                              _ provider: String) -> Rates.Row? {
        rates.rows.first { $0.from == from && $0.to == to && $0.provider == provider }
    }

    /// Строка Яндекса: свежая — из ответа, иначе — из прошлого снимка.
    ///
    /// - Returns: true — значение свежее
    private static func addYandex(_ rates: inout Rates, _ value: RatesParser.YandexRate?,
                                  _ from: String, _ to: String, _ cached: Rates?) -> Bool {
        if let value = value, value.ok {
            rates.rows.append(Rates.Row(from: from, to: to, provider: Rates.providerYandex,
                                        source: value.source, date: value.date, value: value.value))
            return true
        }
        if let old = cached?.rows.first(where: {
            $0.from == from && $0.to == to && $0.provider == Rates.providerYandex
        }) {
            rates.rows.append(old)
        }
        return false
    }

    /// Возвращает в снимок строки прошлого раза, которых в новом нет.
    private static func keepCachedRows(_ rates: inout Rates, _ cached: Rates?, _ provider: String) {
        guard let cached else { return }
        for old in cached.rows where old.provider == provider {
            let exists = rates.rows.contains {
                $0.from == old.from && $0.to == old.to && $0.provider == provider
            }
            if !exists {
                rates.rows.append(old)
            }
        }
    }

    private static func fetchYandex(_ pair: String,
                                     _ toCode: String) async -> Fetched<RatesParser.YandexRate> {
        var lastError = ""
        for attempt in 1...HTTP.yandexAttempts {
            do {
                let html = try await HTTP.get(HTTP.yandexBase + pair, timeout: HTTP.yandexTimeout)
                let parsed = RatesParser.parseYandex(html, toCode)
                if parsed.ok {
                    return Fetched(value: parsed, error: nil)
                }
                lastError = "Яндекс (\(pair)): страница не распознана"
            } catch {
                lastError = "Яндекс (\(pair)): \(error.localizedDescription)"
            }
            if attempt < HTTP.yandexAttempts {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        return Fetched(value: nil, error: lastError)
    }

    private static func fetchMyfin(_ url: String,
                                   _ label: String) async -> Fetched<RatesParser.MyfinTable> {
        do {
            let html = try await HTTP.get(url)
            var table = RatesParser.parseMyfin(html)
            if table.ok { table.origin = "myfin.by" }
            return Fetched(value: table, error: nil)
        } catch {
            return Fetched(value: nil, error: "myfin.by (\(label)): \(error.localizedDescription)")
        }
    }

    /// Курсы НБ РБ: сначала myfin.by, а если он не ответил — сайт НБ РБ.
    private static func fetchNbrb() async -> Fetched<RatesParser.MyfinTable> {
        let myfin = await fetchMyfin(HTTP.myfinNbrbURL, "НБ РБ")
        if let table = myfin.value, table.ok {
            return myfin
        }
        do {
            let json = try await HTTP.get(HTTP.nbrbURL, timeout: 5)
            let nbrb = OfficialRates.parseNbrb(json)
            if nbrb.ok {
                var table = RatesParser.MyfinTable()
                table.rates = nbrb.rates
                table.date = nbrb.date
                table.ok = true
                table.origin = "НБ РБ"
                return Fetched<RatesParser.MyfinTable>(value: table, error: myfin.error)
            }
        } catch {
            var message = myfin.error ?? ""
            if !message.isEmpty { message += "  ·  " }
            message += "НБ РБ (nbrb.by): \(error.localizedDescription)"
            return Fetched<RatesParser.MyfinTable>(value: myfin.value, error: message)
        }
        return myfin
    }

    /// Курсы ЦБ РФ: сначала myfin.by, а если он не ответил — XML ЦБ РФ.
    private static func fetchCbr() async -> Fetched<RatesParser.MyfinTable> {
        let myfin = await fetchMyfin(HTTP.myfinCbrURL, "ЦБ РФ")
        if let table = myfin.value, table.ok {
            return myfin
        }
        do {
            let xml = try await HTTP.get(HTTP.cbrURL, timeout: HTTP.officialTimeout,
                                         encoding: .windowsCP1251)
            let cbr = OfficialRates.parseCbr(xml)
            if cbr.ok {
                var table = RatesParser.MyfinTable()
                table.rates = cbr.rates
                table.date = cbr.date
                table.ok = true
                table.origin = "ЦБ РФ"
                return Fetched<RatesParser.MyfinTable>(value: table, error: myfin.error)
            }
        } catch {
            var message = myfin.error ?? ""
            if !message.isEmpty { message += "  ·  " }
            message += "ЦБ РФ (cbr.ru): \(error.localizedDescription)"
            return Fetched<RatesParser.MyfinTable>(value: myfin.value, error: message)
        }
        return myfin
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
