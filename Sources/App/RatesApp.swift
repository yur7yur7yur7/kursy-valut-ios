import SwiftUI

/// Курсы валют: три вкладки — «Курсы», «Обменники», «Рядом».
@main
struct RatesApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
        }
    }
}

/// Корневой экран: шапка со статусом, вкладки и содержимое.
struct RootView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Курсы валют")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                Text("Доллар · Российский рубль · Белорусский рубль")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 2)

                tabs
                    .padding(.top, 14)

                Text(state.statusText)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 10)

                if state.showSources {
                    Text("Яндекс: \(state.rates.yandexOk ? "✓" : "—")   •   myfin.by: \(state.rates.myfinOk ? "✓" : "—")")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.subtitle)
                        .padding(.top, 2)
                }

                if !state.statusDetail.isEmpty {
                    Text(state.statusDetail)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.subtitle)
                        .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    Button(action: { state.refresh() }) {
                        HStack(spacing: 8) {
                            if state.loading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(Theme.primaryText)
                            }
                            Text(state.loading ? "Обновляю…" : "Обновить")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.primaryText)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: 0x242428)))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.loading)
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)

                content
                    .padding(.top, 14)

                Text("Источники: мини-ответ «конвертер валют» Яндекса, myfin.by и сайты регуляторов (НБ РБ, ЦБ РФ). Данные носят справочный характер.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 18)

                Text("Версия: \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            state.refresh()
        }
        .onChange(of: scenePhase) { phase in
            // пользователь вернулся из настроек — проверяем местоположение
            if phase == .active {
                state.locationSettingsReturned()
            }
        }
        .alert("Местоположение выключено", isPresented: $state.showLocationPrompt) {
            Button("Включить") { state.enableLocation() }
            Button("Не сейчас", role: .cancel) { state.skipLocation() }
        } message: {
            Text("На устройстве отключено определение местоположения. Пока оно выключено, ближайшие обменники не ищутся. Включите его в настройках — поиск запустится сам.")
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ChipButton(title: "Курсы", active: state.tab == .rates) { state.tab = .rates }
            ChipButton(title: "Обменники", active: state.tab == .exchange) { state.tab = .exchange }
            ChipButton(title: "Рядом", active: state.tab == .nearby) {
                let wasNearby = state.tab == .nearby
                state.tab = .nearby
                if !wasNearby && state.location.granted && !state.hasLocation {
                    state.locate()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.tab {
        case .rates:
            RatesView(state: state)
        case .exchange:
            ExchangeView(state: state)
        case .nearby:
            NearbyView(state: state)
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
