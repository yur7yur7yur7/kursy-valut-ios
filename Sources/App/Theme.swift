import SwiftUI

/// Оформление приложения: тёмная тема, единая с Android-версией.
enum Theme {
    static let background = Color(hex: 0x0B0B0C)
    static let surface = Color(hex: 0x151517)
    static let cloud = Color(hex: 0x131316)
    static let cloudStroke = Color(hex: 0x232329)
    static let cloudBest = Color(hex: 0x11251C)
    static let pill = Color(hex: 0x1E1E21)
    static let pillStroke = Color(hex: 0x2C2C31)
    static let divider = Color(hex: 0x2C2C31)
    static let primaryText = Color(hex: 0xFFFFFF)
    static let text = Color(hex: 0xE8E8EA)
    static let subtitle = Color(hex: 0x8A8A8F)
    static let accent = Color(hex: 0xFC3F1D)
    static let accentLight = Color(hex: 0xFF7A5C)
    static let accentSoft = Color(hex: 0x241512)
    static let accentLine = Color(hex: 0x4A2620)
    static let good = Color(hex: 0x2ECC71)

    /// Градиент «героя»: тёмная карточка с мягким оранжевым свечением в углу.
    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x1F1109), Color(hex: 0x0D0D0F), Color(hex: 0x0B0B0C)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)
    static let heroStroke = Color(hex: 0x33231C)
}

/// Официальный знак белорусского рубля: глиф U+E901 в шрифте НБ РБ.
/// Шрифт лежит в ресурсах приложения (nbrb.ttf) и подключён через UIAppFonts.
enum Byn {
    static let sign = "\u{E901}"

    /// Текст, где знак рубля нарисован шрифтом НБ РБ, а остальное — системным.
    static func text(_ value: String, size: CGFloat, weight: Font.Weight = .regular) -> Text {
        var attributed = AttributedString(value)
        if let range = attributed.range(of: sign) {
            attributed[range].font = .custom("nbrb", size: size)
        }
        return Text(attributed)
            .font(.system(size: size, weight: weight))
    }
}

/// Карточка-облачко: тёмный фон, скругление и тонкая рамка.
struct CloudCard<Content: View>: View {
    let cornerRadius: CGFloat
    let fill: Color
    let stroke: Color
    let lineWidth: CGFloat
    private let content: () -> Content

    init(cornerRadius: CGFloat = 20,
         fill: Color = Theme.cloud,
         stroke: Color = Theme.cloudStroke,
         lineWidth: CGFloat = 1,
         @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.stroke = stroke
        self.lineWidth = lineWidth
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth))
    }
}

/// «Герой» — крупная карточка с градиентом.
struct HeroCard<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.heroGradient))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Theme.heroStroke, lineWidth: 1))
    }
}

/// Небольшая плашка-действие.
struct ActionPill: View {
    let title: String
    var tint: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0x242428)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.pillStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Метка типа отделения.
struct TagPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundColor(Theme.subtitle)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.pill))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.pillStroke, lineWidth: 1))
    }
}

/// Плашка «вы ниже лучшего курса».
struct GapPill: View {
    let diff: String
    let per100: String

    var body: some View {
        HStack(spacing: 8) {
            Byn.text("↓ ниже лучшего на \(diff) \(Byn.sign)", size: 12)
                .foregroundColor(Theme.accentLight)
            Byn.text("на 100 $ это \(per100) \(Byn.sign)", size: 12)
                .foregroundColor(Theme.subtitle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accentSoft))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.accentLine, lineWidth: 1))
    }
}

/// Переключатель-чип (как вкладки и фильтры).
struct ChipButton: View {
    let title: String
    let active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? Color.white : Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(active ? Theme.accent : Theme.pill))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.pillStroke, lineWidth: active ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}
