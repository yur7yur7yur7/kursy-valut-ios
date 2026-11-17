import SwiftUI
import UIKit

/// Выбор банка и отделения — два листа со списками.
struct BankPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (BankCatalog.Bank) -> Void

    var body: some View {
        NavigationView {
            List(BankCatalog.all, id: \.slug) { bank in
                Button(action: { onPick(bank); dismiss() }) {
                    HStack(spacing: 12) {
                        BankLogo(slug: bank.slug)
                            .frame(width: 34, height: 26)
                        Text(bank.name)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.primaryText)
                        Spacer()
                    }
                }
                .listRowBackground(Color(hex: 0x151517))
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Выберите банк")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Отделения банка, отсортированные по лучшему курсу.
struct OfficePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bank: BankCatalog.Bank
    let offices: [BankData.Office]
    let onPick: (BankData.Office) -> Void
    @State private var search = ""

    var body: some View {
        NavigationView {
            List(shown, id: \.id) { office in
                Button(action: { onPick(office); dismiss() }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(office.address)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.primaryText)
                        HStack(spacing: 10) {
                            Byn.text("Банк покупает 1 $ за \(Fmt.exact(office.usdSell, 4)) \(Byn.sign)",
                                     size: 13)
                                .foregroundColor(Theme.good)
                            if !office.type.isEmpty {
                                Text(office.type)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.subtitle)
                            }
                        }
                    }
                }
                .listRowBackground(Color(hex: 0x151517))
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $search, prompt: "Поиск по адресу")
            .navigationTitle(bank.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var shown: [BankData.Office] {
        let sorted = offices.sorted { $0.usdSell > $1.usdSell }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return sorted }
        return sorted.filter { $0.address.lowercased().contains(query) }
    }
}

/// Логотип банка из ресурсов приложения.
struct BankLogo: View {
    let slug: String

    var body: some View {
        if let image = UIImage(named: logoName) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "building.columns")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(Theme.subtitle)
        }
    }

    private var logoName: String {
        (BankCatalog.bySlug(slug)?.logoName ?? "logo_bank") + ".png"
    }
}
