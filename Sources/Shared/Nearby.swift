import Foundation

/// Ближайшие обменники: расстояние, выборка в радиусе и лучший курс.
enum Nearby {

    /// Радиус поиска по умолчанию, м.
    static let defaultRadiusM = 2000.0

    /// Отделение с расстоянием до пользователя.
    struct Entry: Identifiable {
        let slug: String
        let bankTitle: String
        let office: BankData.Office
        let meters: Double

        var id: String { slug + "|" + office.address }

        /// Курс покупки доллара банком (BYN за 1 USD).
        var rate: Double { office.usdSell > 0 ? office.usdSell : 0 }
    }

    /// Расстояние между двумя точками по большому кругу (haversine), метры.
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    /// Отделения в радиусе от точки пользователя, от ближайшего к дальнему.
    static func around(_ snapshot: [String: BankData], _ lat: Double, _ lon: Double,
                       _ radiusMeters: Double) -> [Entry] {
        var list: [Entry] = []
        for (slug, bank) in snapshot {
            let title = bank.title.isEmpty ? slug : bank.title
            for office in bank.offices where office.hasGeo {
                let d = distance(lat, lon, office.lat, office.lon)
                if radiusMeters > 0 && d > radiusMeters { continue }
                list.append(Entry(slug: slug, bankTitle: title, office: office, meters: d))
            }
        }
        list.sort { a, b in
            if abs(a.meters - b.meters) > 0.001 { return a.meters < b.meters }
            if a.rate != b.rate { return a.rate > b.rate }
            return a.office.address < b.office.address
        }
        return list
    }

    /// Сортирует отделения: по дальности (как вернул `around`) или по курсу —
    /// от большего к меньшему.
    ///
    /// При равных курсах — ближние сверху, потом по адресу: порядок детерминированный.
    static func sorted(_ entries: [Entry], byRate: Bool) -> [Entry] {
        guard byRate else { return entries }
        return entries.sorted { a, b in
            if a.rate != b.rate { return a.rate > b.rate }
            if abs(a.meters - b.meters) > 0.001 { return a.meters < b.meters }
            return a.office.address < b.office.address
        }
    }

    /// Максимальный курс покупки доллара среди отделений (0 — данных нет).
    static func bestRate(_ entries: [Entry]) -> Double {
        entries.map { $0.rate }.max() ?? 0
    }

    /// Отделение с лучшим курсом среди найденных (совпадения курсов отмечаются все).
    static func isBest(_ entry: Entry, _ bestRate: Double) -> Bool {
        bestRate > 0 && entry.rate > 0 && entry.rate >= bestRate - BankData.eps
    }

    /// Расстояние для показа: «350 м», «1,2 км».
    static func formatDistance(_ meters: Double) -> String {
        if meters < 0 { return "" }
        if meters < 1000 {
            return "\(Int((meters / 10).rounded()) * 10) м"
        }
        return Fmt.exact(meters / 1000, 1) + " км"
    }
}
