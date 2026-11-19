import Foundation
import SwiftUI
import UIKit

/// Состояние приложения: курсы, снимок банков, закреплённые отделения, местоположение.
@MainActor
final class AppState: ObservableObject {

    enum Tab: Int, Hashable {
        case rates
        case exchange
        case nearby
    }

    @Published var rates = Rates()
    @Published var snapshot: [String: BankData] = [:]
    @Published var pinned: [PinnedOffice] = []
    @Published var tab: Tab = .rates
    @Published var loading = false
    @Published var statusText = "Загружаю курсы…"
    @Published var statusDetail = ""
    @Published var showSources = false

    /// Местоположение пользователя.
    @Published var hasLocation = false
    @Published var locationPrecise = false
    @Published var locationLat = 0.0
    @Published var locationLon = 0.0
    @Published var nearbyStatus = ""

    /// Местоположение выключено на устройстве (системный переключатель).
    @Published var locationOff = false
    /// Показать модалку с предложением включить местоположение.
    @Published var showLocationPrompt = false
    /// Пользователь уже отказался включать местоположение в этой сессии.
    @Published var locationDeclined = false

    /// Пользователь открыл настройки: ждём возврата.
    private var awaitingLocationSettings = false

    /// Сумма в долларах для вкладки «Рядом» (одна на весь список).
    @Published var amountText = ""

    /// Введённая сумма в конвертере: код валюты и текст поля.
    @Published var amountCode = "USD"
    @Published var amountInput = "1"

    let location = LocationHelper()

    private var cachedRates: Rates?

    init() {
        if let saved = SnapshotStore.loadRates() {
            rates = saved
            cachedRates = saved
            statusText = "Сохранённые данные: \(stamp(saved.fetchedAt))"
        }
        snapshot = SnapshotStore.loadSnapshot()
        pinned = SnapshotStore.loadPinned()
        locationOff = SnapshotStore.loadLocationOff()
        if let saved = SnapshotStore.loadLocation() {
            hasLocation = true
            locationPrecise = saved.precise
            locationLat = saved.lat
            locationLon = saved.lon
        }
    }

    /// Официальный курс доллара (любой источник).
    var usdRate: Double? {
        rates.anyRate("USD", "BYN")
    }

    /// Лучший курс по городу из снимка всех банков.
    var cityBest: Double {
        BankData.bestAcross(snapshot).first?.usdSell ?? 0
    }

    /// Курс закреплённого отделения (по снимку всех банков).
    func rate(for item: PinnedOffice) -> Double {
        office(for: item)?.usdSell ?? 0
    }

    /// Закреплённое отделение из снимка.
    func office(for item: PinnedOffice) -> BankData.Office? {
        guard let bank = snapshot[item.slug] else { return nil }
        return bank.offices.first {
            $0.id == item.officeId || $0.address == item.address
        }
    }

    /// Лучший курс среди закреплённых отделений.
    var pinnedBestRate: Double {
        pinned.map { rate(for: $0) }.max() ?? 0
    }

    /// Обновляет курсы из сети.
    func refresh() {
        guard !loading else { return }
        loading = true
        statusDetail = ""
        Task {
            let result = await RatesRepository.load(cached: cachedRates)
            apply(result)
        }
    }

    private func apply(_ result: RatesRepository.Result) {
        loading = false
        if result.networkOk {
            rates = result.rates
            cachedRates = result.rates
            if !result.snapshot.isEmpty {
                snapshot = result.snapshot
                SnapshotStore.saveSnapshot(result.snapshot)
            }
            SnapshotStore.saveRates(result.rates)
            statusText = "Обновлено: \(stamp(result.rates.fetchedAt))"
            showSources = true
            statusDetail = result.error
        } else {
            if let saved = SnapshotStore.loadRates() {
                rates = saved
                cachedRates = saved
                statusText = "Нет интернета — последние сохранённые данные: \(stamp(saved.fetchedAt))"
            } else {
                statusText = "Нет данных"
            }
            statusDetail = result.error
        }
    }

    /// Определяет местоположение и строит список ближайших обменников.
    func locate() {
        guard location.servicesEnabled else {
            // местоположение выключено на устройстве: поиск не запускаем
            markLocationOff()
            return
        }
        nearbyStatus = "Определяю местоположение…"
        location.request { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let fix):
                self.hasLocation = true
                self.locationPrecise = fix.precise
                self.locationLat = fix.lat
                self.locationLon = fix.lon
                self.locationOff = false
                SnapshotStore.saveLocationOff(false)
                SnapshotStore.saveLocation(lat: fix.lat, lon: fix.lon, precise: fix.precise)
                self.nearbyStatus = ""
            case .failure(let error):
                self.hasLocation = false
                switch error {
                case LocationHelper.LocationError.denied:
                    self.nearbyStatus = "Нет доступа к местоположению. Разрешите его в настройках и попробуйте снова."
                case LocationHelper.LocationError.servicesDisabled:
                    self.markLocationOff()
                default:
                    self.nearbyStatus = "Не удалось определить местоположение — попробуйте ещё раз."
                }
            }
        }
    }

    /// Местоположение выключено на устройстве: помечаем это и предлагаем включить.
    private func markLocationOff() {
        locationOff = true
        SnapshotStore.saveLocationOff(true)
        nearbyStatus = "Местоположение выключено на устройстве — поиск не запущен."
        if !locationDeclined {
            showLocationPrompt = true
        }
    }

    /// Открывает настройки, где включают местоположение.
    func enableLocation() {
        showLocationPrompt = false
        locationDeclined = false
        awaitingLocationSettings = true
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Пользователь отказался: процессы поиска не запускаем.
    func skipLocation() {
        locationDeclined = true
        showLocationPrompt = false
        markLocationOff()
    }

    /// Пользователь вернулся из настроек: проверяем, включил ли он местоположение.
    func locationSettingsReturned() {
        guard awaitingLocationSettings else { return }
        awaitingLocationSettings = false
        if location.servicesEnabled {
            locationOff = false
            SnapshotStore.saveLocationOff(false)
            locate()
        } else {
            locationDeclined = true
            markLocationOff()
        }
    }

    /// Закрепляет отделение (одно облачко на банк).
    func pin(_ slug: String, _ office: BankData.Office) {
        let bank = BankCatalog.bySlug(slug)
        let item = PinnedOffice(slug: slug,
                                title: bank?.name ?? slug,
                                officeId: office.id,
                                address: office.address)
        if let index = pinned.firstIndex(where: { $0.slug == slug }) {
            pinned[index] = item
        } else {
            pinned.append(item)
        }
        SnapshotStore.savePinned(pinned)
    }

    /// Убирает закреплённое отделение.
    func unpin(_ item: PinnedOffice) {
        pinned.removeAll { $0.slug == item.slug }
        SnapshotStore.savePinned(pinned)
    }

    /// Пользователь изменил сумму в конвертере.
    func setAmount(code: String, text: String) {
        amountCode = code
        amountInput = text
    }

    /// Пересчёт суммы в другую валюту по курсу конкретного источника.
    func converted(code: String, provider: String) -> Double? {
        guard let value = Fmt.parse(amountInput) else { return nil }
        guard let rate = rates.providerRate(provider, amountCode, code) else { return nil }
        return value * rate
    }

    /// Ссылка на отделение в картах.
    static func mapsURL(for office: BankData.Office) -> URL? {
        guard office.hasGeo else { return nil }
        var items = ["\(office.lat),\(office.lon)"]
        if !office.address.isEmpty { items.append(office.address) }
        let encoded = items
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: ",")
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    func stamp(_ millis: Double) -> String {
        guard millis > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: millis))
    }
}
