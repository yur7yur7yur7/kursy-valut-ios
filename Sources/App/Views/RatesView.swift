import SwiftUI

/// Блок конвертера для одного источника (Яндекс или myfin.by):
/// три строки-валюты, правка любой строки пересчитывает остальные.
/// Сумма общая для двух блоков — как в Android-версии.
struct ConverterBlock: View {
    let provider: String
    let title: String
    let subtitle: String
    let icon: String
    @ObservedObject var state: AppState

    private let codes = ["USD", "RUB", "BYN"]

    var body: some View {
        CloudCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(icon).font(.system(size: 18))
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.subtitle)
                }

                ForEach(codes, id: \.self) { code in
                    currencyRow(code)
                }

                Byn.text(ratesLine, size: 12)
                    .foregroundColor(Theme.subtitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Строка валюты: флаг, код и поле суммы.
    private func currencyRow(_ code: String) -> some View {
        HStack(spacing: 10) {
            Text(flag(code)).font(.system(size: 18))
            Text(code)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.text)
                .frame(width: 42, alignment: .leading)
            TextField("—", text: Binding(
                get: { state.amountCode == code ? state.amountInput : (state.converted(code: code, provider: provider) ?? "") },
                set: { state.setAmount(code: code, text: $0) }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.pill))
    }

    /// Точная строка курсов источника: «1 USD = 82,51 ₽ · 1 USD = 2,9977 ₽».
    private var ratesLine: String {
        var parts: [String] = []
        let pairs = [("USD", "RUB"), ("USD", "BYN"), ("RUB", "BYN")]
        for (from, to) in pairs {
            guard let value = state.rates.providerRate(provider, from, to) else { continue }
            parts.append("1 \(from) = \(Fmt.exact(value, 4)) \(sign(to))")
        }
        if parts.isEmpty { return "Нет данных" }
        var text = parts.joined(separator: "  ·  ")
        var date = ""
        var source = ""
        for row in state.rates.rows where row.provider == provider {
            if date.isEmpty { date = row.date }
            if source.isEmpty { source = row.source }
        }
        if !date.isEmpty { text += "  ·  " + date }
        if !source.isEmpty { text += "  ·  " + source }
        return text
    }

    private func flag(_ code: String) -> String {
        switch code {
        case "USD": return "🇺🇸"
        case "RUB": return "🇷🇺"
        default: return "🇧🇾"
        }
    }

    private func sign(_ code: String) -> String {
        code == "BYN" ? Byn.sign : "₽"
    }
}

/// Вкладка «Курсы»: два облачка-конвертера.
struct RatesView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            ConverterBlock(provider: Rates.providerYandex,
                           title: "Яндекс",
                           subtitle: "мини-ответ «конвертер валют»",
                           icon: "🔍",
                           state: state)
            ConverterBlock(provider: Rates.providerMyfin,
                           title: "myfin.by",
                           subtitle: "НБ РБ · ЦБ РФ",
                           icon: "💳",
                           state: state)
        }
    }
}
