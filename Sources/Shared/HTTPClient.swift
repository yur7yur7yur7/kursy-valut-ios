import Foundation

/// Загрузка страниц: системный URLSession, без сторонних зависимостей.
enum HTTP {

    /// Настройки браузера: без них Яндекс и myfin отдают заглушки.
    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    static let yandexBase = "https://yandex.ru/finance/currencies/"
    static let myfinNbrbURL = "https://myfin.by/bank/kursy_valjut_nbrb"
    static let myfinCbrURL = "https://myfin.by/currency/cb-rf"
    /// Единый снимок курсов всех банков — одна страница вместо страницы на банк.
    static let onlinerURL = "https://kurs.onliner.by/"
    /// Запасные официальные источники: myfin.by отвечает «HTTP 423».
    /// cbr.ru отдаёт XML по обычному HTTP — сертификат у него нестандартный.
    static let nbrbURL = "https://www.nbrb.by/StatExchangeRates/LastDayRate?CURRENCY=840"
    static let cbrURL = "http://www.cbr.ru/scripts/XML_daily.asp"

    /// Сколько можно не запрашивать официальные курсы заново (они меняются раз в сутки).
    static let officialTTL: TimeInterval = 5 * 60
    /// Страница Яндекса тяжёлая (около 600 КБ) — читаем её дольше.
    static let yandexTimeout: TimeInterval = 45
    /// Запасные источники отвечают быстро, долго ждать не надо.
    static let officialTimeout: TimeInterval = 15
    /// Сколько раз пробуем скачать страницу Яндекса, прежде чем сдаться.
    static let yandexAttempts = 2

    enum LoadError: Error {
        case badURL
        case badResponse
    }

    /// Скачивает страницу и возвращает её текст.
    ///
    /// - Parameter encoding: кодировка ответа (у ЦБ РФ — windows-1251).
    static func get(_ urlString: String,
                    timeout: TimeInterval = 25,
                    encoding: String.Encoding = .utf8) async throws -> String {
        guard let url = URL(string: urlString) else { throw LoadError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue(desktopUA, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
        request.setValue("ru-RU,ru;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(url.host == "kurs.onliner.by" ? "https://kurs.onliner.by/" : "",
                         forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw LoadError.badResponse
        }
        return String(data: data, encoding: encoding)
            ?? String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}
