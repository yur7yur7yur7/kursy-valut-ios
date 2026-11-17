import Foundation

/// Каталог банков: название и имя файла логотипа.
enum BankCatalog {

    struct Bank: Identifiable {
        let slug: String
        let name: String
        /// Имя файла логотипа в ресурсах приложения.
        let logoName: String

        var id: String { slug }
    }

    static let all: [Bank] = [
        Bank(slug: "technobank", name: "Технобанк", logoName: "logo_technobank"),
        Bank(slug: "rrb-bank", name: "Банк РРБ", logoName: "logo_rrb_bank"),
        Bank(slug: "alfabank", name: "Альфа Банк", logoName: "logo_alfabank"),
        Bank(slug: "belarusbank", name: "Беларусбанк", logoName: "logo_belarusbank"),
        Bank(slug: "mtbank", name: "МТБанк", logoName: "logo_mtbank"),
        Bank(slug: "priorbank", name: "Приорбанк", logoName: "logo_priorbank"),
        Bank(slug: "bank-vtb", name: "ВТБ", logoName: "logo_bank_vtb"),
        Bank(slug: "belagroprombank", name: "Белагропромбанк", logoName: "logo_belagroprombank"),
        Bank(slug: "belgazprombank", name: "Белгазпромбанк", logoName: "logo_belgazprombank"),
        Bank(slug: "belinvestbank", name: "Белинвестбанк", logoName: "logo_belinvestbank"),
        Bank(slug: "bps-sberbank", name: "Сбер Банк", logoName: "logo_bps_sberbank"),
        Bank(slug: "statusbank", name: "СтатусБанк", logoName: "logo_statusbank"),
        Bank(slug: "paritetbank", name: "Паритетбанк", logoName: "logo_paritetbank"),
        Bank(slug: "belswissbank", name: "БСБ Банк", logoName: "logo_belswissbank"),
        Bank(slug: "bnbank", name: "БНБ-Банк", logoName: "logo_bnbank"),
        Bank(slug: "bvebank", name: "Банк БелВЭБ", logoName: "logo_bvebank"),
        Bank(slug: "dabrabyt", name: "Банк Дабрабыт", logoName: "logo_dabrabyt"),
        Bank(slug: "neobank", name: "Нео Банк Азия", logoName: "logo_neobank"),
        Bank(slug: "zepterbank", name: "Цептер Банк", logoName: "logo_zepterbank"),
        Bank(slug: "reshenie", name: "Банк Решение", logoName: "logo_reshenie"),
        Bank(slug: "belinkasgrupp", name: "Белинкасгрупп", logoName: "logo_belinkasgrupp"),
        Bank(slug: "tkbank", name: "ТК Банк", logoName: "logo_tkbank")
    ]

    static func bySlug(_ slug: String) -> Bank? {
        all.first { $0.slug == slug }
    }
}
