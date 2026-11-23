import Foundation

/// Официальные курсы: Яндекс и myfin.by (НБ РБ, ЦБ РФ).
struct Rates: Codable {
    static let providerYandex = "yandex"
    static let providerMyfin = "myfin"

    struct Row: Codable, Identifiable {
        var id: String { "\(from)\(to)\(provider)\(date)\(value)" }
        var from: String
        var to: String
        var provider: String
        var source: String
        var date: String
        var value: Double
    }

    var fetchedAt: Double = 0
    /// Когда официальные курсы удалось обновить в последний раз.
    var officialFetchedAt: Double = 0
    /// Последняя попытка обновить официальные курсы не удалась — данные старые.
    var officialStale: Bool = false
    /// Подпись блока официальных курсов: myfin.by или сайты регуляторов.
    var officialTitle: String = "myfin.by"
    /// Подсказка под названием: какие источники внутри.
    var officialSubtitle: String = "НБ РБ · ЦБ РФ"
    var yandexOk: Bool = false
    var myfinOk: Bool = false
    var rows: [Row] = []

    init() {}

    /// Старые снимки не знают про новые поля — читаем их как обычно.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = try container.decodeIfPresent(Double.self, forKey: .fetchedAt) ?? 0
        officialFetchedAt = try container.decodeIfPresent(Double.self, forKey: .officialFetchedAt) ?? 0
        officialStale = try container.decodeIfPresent(Bool.self, forKey: .officialStale) ?? false
        officialTitle = try container.decodeIfPresent(String.self, forKey: .officialTitle) ?? "myfin.by"
        officialSubtitle = try container.decodeIfPresent(String.self, forKey: .officialSubtitle)
            ?? "НБ РБ · ЦБ РФ"
        yandexOk = try container.decodeIfPresent(Bool.self, forKey: .yandexOk) ?? false
        myfinOk = try container.decodeIfPresent(Bool.self, forKey: .myfinOk) ?? false
        rows = try container.decodeIfPresent([Row].self, forKey: .rows) ?? []
    }

    /// Курс «1 from = ? to» у конкретного источника; если пары нет — обратный.
    func providerRate(_ provider: String, _ from: String, _ to: String) -> Double? {
        if let direct = rows.first(where: { $0.from == from && $0.to == to && $0.provider == provider }) {
            return direct.value
        }
        if let inverse = rows.first(where: { $0.from == to && $0.to == from && $0.provider == provider }),
           inverse.value != 0 {
            return 1.0 / inverse.value
        }
        return nil
    }

    /// Курс по любому доступному источнику (сначала myfin.by — у него больше знаков).
    func anyRate(_ from: String, _ to: String) -> Double? {
        providerRate(Rates.providerMyfin, from, to) ?? providerRate(Rates.providerYandex, from, to)
    }
}

/// Курсы обменников по отделениям банков.
struct BankData: Codable, Identifiable {
    var id: String { slug }

    /// Отделение банка с курсами и координатами.
    struct Office: Codable, Identifiable {
        var id: String
        var address: String
        /// Время обновления курсов банком, например «17:50».
        var time: String
        /// BYN за 1 USD: «сдать» (банк покупает) и «купить» (банк продаёт).
        var usdSell: Double
        var usdBuy: Double
        /// BYN за 100 RUB.
        var rubSell: Double
        var rubBuy: Double
        /// Координаты отделения (0 — их нет).
        var lat: Double
        var lon: Double
        /// Тип отделения: «Отделение», «Обменный пункт», «ЦБУ» и т. п.
        var type: String

        var hasGeo: Bool { lat != 0 && lon != 0 }
    }

    /// Отделение с максимальным курсом из снимка банков.
    struct Top {
        let slug: String
        let address: String
        let id: String
        let usdSell: Double
    }

    /// Допуск при сравнении курсов: разница меньше 0.00005 — это один и тот же курс.
    static let eps = 0.00005

    var slug: String = ""
    var title: String = ""
    var date: String = ""
    var fetchedAt: Double = 0
    var offices: [Office] = []

    /// Отделение с лучшим курсом покупки доллара банком.
    func bestBankBuy() -> Office? {
        var best: Office?
        for office in offices where office.usdSell > 0 {
            if best == nil || office.usdSell > best!.usdSell { best = office }
        }
        return best
    }

    /// Все отделения с максимальным курсом из снимка банков.
    ///
    /// Курсы у разных банков часто совпадают до копейки, поэтому «лучших» обычно
    /// несколько — показываем всех, а не одного произвольного победителя.
    static func bestAcross(_ snapshot: [String: BankData]) -> [Top] {
        var list: [Top] = []
        var max = 0.0
        for (slug, bank) in snapshot {
            for office in bank.offices where office.usdSell > 0 {
                if office.usdSell > max + eps {
                    max = office.usdSell
                    list.removeAll()
                }
                if abs(office.usdSell - max) <= eps {
                    list.append(Top(slug: slug,
                                    address: office.address,
                                    id: office.id.isEmpty ? office.address : office.id,
                                    usdSell: office.usdSell))
                }
            }
        }
        list.sort { a, b in
            if a.slug != b.slug { return a.slug < b.slug }
            return a.address < b.address
        }
        return list
    }
}

/// Закреплённое пользователем отделение банка.
struct PinnedOffice: Codable, Identifiable {
    var id: String { slug }
    var slug: String
    var title: String
    var officeId: String
    var address: String
}
