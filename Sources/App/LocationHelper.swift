import CoreLocation
import Foundation

/// Местоположение устройства: разрешение, последняя известная точка и свежий фикс.
///
/// Точность: если выдано разрешение «при использовании» и точность фикса не хуже
/// 300 м — расстояние показываем в метрах; иначе — просто «рядом».
final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {

    /// Ответ: координаты и признак точности.
    struct Fix {
        let lat: Double
        let lon: Double
        let precise: Bool
    }

    /// Точность фикса, при которой расстояние показываем в метрах, м.
    private static let preciseMeters = 300.0
    /// Через сколько отдаём последнюю известную точку, если свежая не пришла, с.
    private static let fallbackDelay = 6.0

    private let manager = CLLocationManager()
    private var completion: ((Result<Fix, Error>) -> Void)?
    private var fallbackTimer: Timer?
    private var hasFinePermission = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Есть ли разрешение на местоположение.
    var granted: Bool {
        manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse
    }

    /// Выдано ли точное разрешение (иначе расстояние в метрах не показываем).
    var precisePermission: Bool {
        manager.authorizationStatus == .authorizedAlways
    }

    /// Запрашивает разрешение (если ещё не выдано) и определяет местоположение.
    func request(_ completion: @escaping (Result<Fix, Error>) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        default:
            locate()
        }
    }

    /// Определяет местоположение: свежий фикс, иначе — последняя известная точка.
    private func locate() {
        hasFinePermission = precisePermission
        if let last = manager.location, abs(last.timestamp.timeIntervalSinceNow) < 60 {
            finish(.success(Fix(lat: last.coordinate.latitude,
                                lon: last.coordinate.longitude,
                                precise: hasFinePermission
                                    && last.horizontalAccuracy <= LocationHelper.preciseMeters)))
            return
        }
        manager.startUpdatingLocation()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: LocationHelper.fallbackDelay,
                                              repeats: false) { [weak self] _ in
            guard let self else { return }
            if let last = self.manager.location {
                self.finish(.success(Fix(lat: last.coordinate.latitude,
                                         lon: last.coordinate.longitude,
                                         precise: false)))
            } else {
                self.finish(.failure(LocationError.timeout))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locate()
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        finish(.success(Fix(lat: last.coordinate.latitude,
                            lon: last.coordinate.longitude,
                            precise: hasFinePermission
                                && last.horizontalAccuracy <= LocationHelper.preciseMeters)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let last = manager.location {
            finish(.success(Fix(lat: last.coordinate.latitude,
                                lon: last.coordinate.longitude,
                                precise: false)))
        } else {
            finish(.failure(LocationError.timeout))
        }
    }

    private func finish(_ result: Result<Fix, Error>) {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        manager.stopUpdatingLocation()
        let callback = completion
        completion = nil
        callback?(result)
    }

    enum LocationError: Error {
        case denied
        case timeout
    }
}
