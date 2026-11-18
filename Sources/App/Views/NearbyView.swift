import SwiftUI

/// Вкладка «Рядом»: ближайшие обменники и лучший курс среди них.
struct NearbyView: View {
    @ObservedObject var state: AppState
    @State private var onlyExchangePoints = false
    @State private var share: SharePayload?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { state.locate() }) {
                Text("Проверить ближайшие обменники")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.primaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0x242428)))
            }
            .buttonStyle(.plain)

            if !state.nearbyStatus.isEmpty {
                Text(state.nearbyStatus)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 12)
            }

            if entries.isEmpty {
                if state.hasLocation {
                    Text("В радиусе \(Nearby.formatDistance(Nearby.defaultRadiusM)) обменников не найдено.")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.subtitle)
                        .padding(.top, 12)
                }
            } else {
                hero
                    .padding(.top, 14)
                toolbar
                    .padding(.top, 14)
                ForEach(entries) { entry in
                    card(entry)
                }
            }
        }
        .sheet(item: $share) { payload in
            ShareSheet(items: [payload.text])
        }
    }

    /* ------------------------------------------------------------- данные */

    /// Отделения в радиусе (с учётом фильтра).
    private var entries: [Nearby.Entry] {
        guard state.hasLocation else { return [] }
        let all = Nearby.around(state.snapshot, state.locationLat, state.locationLon,
                                Nearby.defaultRadiusM)
        if onlyExchangePoints {
            return all.filter { Nearby.isExchangePoint($0.office) }
        }
        return all
    }

    private var bestRate: Double {
        Nearby.bestRate(entries)
    }

    /* -------------------------------------------------------------- герой */

    private var hero: some View {
        let best = bestRate
        let bestCount = entries.filter { Nearby.isBest($0, best) }.count
        return HeroCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("ЛУЧШИЙ КУРС РЯДОМ")
                        .font(.system(size: 12))
                        .tracking(1.2)
                        .foregroundColor(Theme.accentLight)
                    Spacer()
                    Button(action: {
                        if let first = entries.first(where: { Nearby.isBest($0, best) }) {
                            share = SharePayload(text: ShareText.nearby(first, best,
                                                                    precise: state.locationPrecise))
                        }
                    }) {
                        Text("Поделиться")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: 0x242428)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.pillStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Byn.text("\(Fmt.exact(best, 4)) \(Byn.sign)", size: 32, weight: .bold)
                    .foregroundColor(Theme.good)
                    .padding(.top, 8)

                Text("такой курс в \(bestCount) \(Fmt.plural(bestCount, "отделении", "отделениях", "отделениях"))"
                     + " · всего рядом \(entries.count)")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text)
            }
        }
    }

    /* ------------------------------------------------------------ панель */

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChipButton(title: "Только обменные пункты", active: onlyExchangePoints) {
                onlyExchangePoints.toggle()
            }

            HStack(spacing: 10) {
                Text("Сумма")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text)
                TextField("100", text: $state.amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 104)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.pill))
                Text("$")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.subtitle)
                Spacer(minLength: 0)
            }
        }
    }

    /* ------------------------------------------------------------ карточка */

    private func card(_ entry: Nearby.Entry) -> some View {
        let isBest = Nearby.isBest(entry, bestRate)
        let amount = Fmt.parse(state.amountText)
        let result = amount == nil ? nil : amount! * entry.rate

        return CloudCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    BankLogo(slug: entry.slug).frame(width: 34, height: 26)
                    Text(BankCatalog.bySlug(entry.slug)?.name ?? entry.bankTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text(state.locationPrecise ? Nearby.formatDistance(entry.meters) : "рядом")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.accent)
                }

                Text(entry.office.address)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.text)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                if !entry.office.type.isEmpty {
                    TagPill(title: entry.office.type)
                        .padding(.top, 8)
                }

                if isBest {
                    Text("Лучший курс рядом")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.good)
                        .padding(.top, 12)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    Byn.text("Банк покупает 1 $ за \(Fmt.exact(entry.rate, 4)) \(Byn.sign)",
                             size: 15, weight: isBest ? .bold : .regular)
                        .foregroundColor(isBest ? Theme.good : Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if let result {
                        Byn.text("\(Fmt.exact(amount ?? 0, 2)) $ → \(Fmt.money(result)) \(Byn.sign)",
                                 size: 16, weight: .bold)
                            .foregroundColor(Theme.primaryText)
                    }
                }
                .padding(.top, isBest ? 2 : 12)

                HStack(spacing: 8) {
                    ActionPill(title: "Закрепить") {
                        state.pin(entry.slug, entry.office)
                    }
                    if let url = AppState.mapsURL(for: entry.office) {
                        ActionPill(title: "В картах") {
                            openURL(url)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.bottom, 12)
    }
}
