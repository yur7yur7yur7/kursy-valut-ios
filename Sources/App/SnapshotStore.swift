import Foundation

/// Сохранение последнего удачного снимка: курсы, обменники, закреплённые отделения.
///
/// Файлы лежат в Application Support, поэтому переживают перезапуск приложения,
/// а виджет (у него свой контейнер) читает свой собственный кеш.
enum SnapshotStore {

    private static let folderName = "rates"

    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static func file(_ name: String) -> URL {
        directory().appendingPathComponent(name)
    }

    private static func write<T: Encodable>(_ value: T, _ name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: file(name), options: .atomic)
    }

    private static func read<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: file(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /* -------------------------------------------------------------- курсы */

    static func saveRates(_ rates: Rates) {
        write(rates, "rates.json")
    }

    static func loadRates() -> Rates? {
        read(Rates.self, "rates.json")
    }

    /* ------------------------------------- снимок курсов всех банков */

    static func saveSnapshot(_ snapshot: [String: BankData]) {
        guard !snapshot.isEmpty else { return }
        write(snapshot, "snapshot.json")
    }

    static func loadSnapshot() -> [String: BankData] {
        read([String: BankData].self, "snapshot.json") ?? [:]
    }

    /* ------------------------------------------------- закреплённые отделения */

    static func savePinned(_ list: [PinnedOffice]) {
        write(list, "pinned.json")
    }

    static func loadPinned() -> [PinnedOffice] {
        read([PinnedOffice].self, "pinned.json") ?? []
    }

    /* -------------------------------------------------- местоположение */

    /// Сохранённая точка пользователя.
    private struct StoredLocation: Codable {
        var lat: Double
        var lon: Double
        var precise: Bool
    }

    static func saveLocation(lat: Double, lon: Double, precise: Bool) {
        write(StoredLocation(lat: lat, lon: lon, precise: precise), "location.json")
    }

    static func loadLocation() -> (lat: Double, lon: Double, precise: Bool)? {
        guard let stored = read(StoredLocation.self, "location.json") else { return nil }
        return (stored.lat, stored.lon, stored.precise)
    }
}
