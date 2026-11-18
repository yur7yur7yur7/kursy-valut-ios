import SwiftUI

/// Вкладка «Обменники»: лучший курс по городу и закреплённые отделения.
struct ExchangeView: View {
    @ObservedObject var state: AppState
    @State private var share: SharePayload?
    @State private var showBankPicker = false
    @State private var officeBank: BankCatalog.Bank?

    var body: some View {
        VStack(spacing: 0) {
            if let best = BankData.bestAcross(state.snapshot).first {
                hero(best)
            }
            if state.pinned.isEmpty {
                Text("Закрепите отделение обменника — нажмите «Добавить обменник» ниже.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            } else {
                ForEach(state.pinned) { item in
                    cloud(item)
                }
            }
            addButton
        }
        .sheet(item: $share) { payload in
            ShareSheet(items: [payload.text])
        }
        .sheet(isPresented: $showBankPicker) {
            BankPickerSheet { bank in
                officeBank = bank
            }
        }
        .sheet(item: $officeBank) { bank in
            OfficePickerSheet(bank: bank, offices: state.snapshot[bank.slug]?.offices ?? []) { office in
                state.pin(bank.slug, office)
            }
        }
    }

    /* ---------------------------------------------------------------- герой */

    private func hero(_ best: BankData.Top) -> some View {
        let bestList = BankData.bestAcross(state.snapshot)
        let banks = uniqueSlugs(bestList)
        let offices = state.snapshot.values.reduce(0) { $0 + $1.offices.count }
        return HeroCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("ЛУЧШИЙ КУРС ПО ГОРОДУ")
                        .font(.system(size: 12))
                        .tracking(1.2)
                        .foregroundColor(Theme.accentLight)
                    Spacer()
                    Button(action: {
                        share = SharePayload(text: ShareText.cityBest(best.usdSell,
                                                                       count: bestList.count))
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

                Byn.text("\(Fmt.exact(best.usdSell, 4)) \(Byn.sign)", size: 36, weight: .bold)
                    .foregroundColor(Theme.good)
                    .padding(.top, 10)

                Byn.text("Банк покупает 1 $ за \(Fmt.exact(best.usdSell, 4)) \(Byn.sign)", size: 14)
                    .foregroundColor(Theme.text)

                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 1)
                    .padding(.vertical, 16)

                Text(banks.count > 1
                     ? "Такой же курс ещё у \(banks.count) \(Fmt.plural(banks.count, "банка", "банков", "банков")):"
                     : "Банк с лучшим курсом:")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.subtitle)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(banks, id: \.self) { slug in
                            bankChip(slug)
                        }
                    }
                    .padding(.top, 8)
                }

                Text("Банков: \(state.snapshot.count) · отделений: \(offices)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 14)
            }
        }
        .padding(.bottom, 14)
    }

    private func uniqueSlugs(_ tops: [BankData.Top]) -> [String] {
        var out: [String] = []
        for top in tops where !out.contains(top.slug) {
            out.append(top.slug)
        }
        return out
    }

    private func bankChip(_ slug: String) -> some View {
        let bank = BankCatalog.bySlug(slug)
        return Button(action: { officeBank = bank }) {
            HStack(spacing: 6) {
                BankLogo(slug: slug).frame(width: 20, height: 15)
                Text(bank?.name ?? slug)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.pill))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.pillStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /* ------------------------------------------------------- облачка */

    private func cloud(_ item: PinnedOffice) -> some View {
        let office = state.office(for: item)
        let rate = state.rate(for: item)
        let isBest = rate > 0 && rate >= state.pinnedBestRate - BankData.eps
        let cityBest = state.cityBest
        let gap = office == nil ? 0 : cityBest - rate

        return CloudCard(cornerRadius: 20,
                         fill: isBest ? Theme.cloudBest : Theme.cloud,
                         stroke: isBest ? Theme.good : Theme.cloudStroke,
                         lineWidth: isBest ? 2 : 1) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    BankLogo(slug: item.slug).frame(width: 34, height: 26)
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.primaryText)
                    Spacer()
                    Button(action: { state.unpin(item) }) {
                        Text("✕")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.subtitle)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { officeBank = BankCatalog.bySlug(item.slug) }) {
                    HStack(spacing: 4) {
                        Text(addressText(office))
                            .font(.system(size: 14))
                            .foregroundColor(Theme.primaryText)
                            .multilineTextAlignment(.leading)
                        Text("▾")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.subtitle)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.pill))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                if office != nil, gap > BankData.eps {
                    GapPill(diff: Fmt.exact(gap, 4), per100: Fmt.money(gap * 100))
                        .padding(.top, 10)
                }

                if isBest {
                    Text("Лучший курс среди закреплённых")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.good)
                        .padding(.top, 12)
                }

                Byn.text("Банк покупает 1 $ за \(Fmt.exact(rate, 4)) \(Byn.sign)",
                         size: 16, weight: isBest ? .bold : .regular)
                    .foregroundColor(isBest ? Theme.good : Theme.text)
                    .padding(.top, isBest ? 2 : 10)

                Text("приложение обновило в \(state.stamp(state.snapshot[item.slug]?.fetchedAt ?? 0))")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.subtitle)
                    .padding(.top, 6)

                if let best = state.snapshot[item.slug]?.bestBankBuy() {
                    Button(action: { officeBank = BankCatalog.bySlug(item.slug) }) {
                        Byn.text("Лучший курс: \(best.address) — \(Fmt.exact(best.usdSell, 4)) \(Byn.sign)",
                                 size: 13)
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
            }
        }
        .padding(.bottom, 12)
    }

    /// Адрес отделения или подсказка, если отделение не найдено.
    private func addressText(_ office: BankData.Office?) -> String {
        guard let address = office?.address, !address.isEmpty else {
            return "Отделение не найдено"
        }
        return address
    }

    private var addButton: some View {
        Button(action: { showBankPicker = true }) {
            HStack(spacing: 10) {
                Text("+")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(Theme.accent)
                Text("Добавить обменник")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0x131316)))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.cloudStroke, style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
        }
        .buttonStyle(.plain)
    }
}
