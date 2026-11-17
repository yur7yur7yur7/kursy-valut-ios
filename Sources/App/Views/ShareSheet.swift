import SwiftUI
import UIKit

/// Системное окно «Поделиться».
struct ShareSheet: UIViewControllerRepresentable {
    let items: [String]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
    }
}

/// Текст для отправки в системном окне «Поделиться».
struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

/// Текст для отправки: заменяем глиф знака на «BYN» — в чужих приложениях
/// приватный символ U+E901 превратился бы в «тофу».
enum ShareText {

    /// Лучший курс по городу.
    static func cityBest(_ rate: Double, count: Int) -> String {
        "1 $ = \(Fmt.exact(rate, 4)) BYN — лучший курс по городу\n"
            + "Отделений с таким курсом: \(count)\nКурсы валют"
    }

    /// Лучший курс рядом и ближайшее отделение с таким курсом.
    static func nearby(_ entry: Nearby.Entry, _ rate: Double, precise: Bool) -> String {
        let distance = precise ? Nearby.formatDistance(entry.meters) : "рядом"
        return "1 $ = \(Fmt.exact(rate, 4)) BYN — лучший курс рядом\n"
            + "\(entry.bankTitle), \(entry.office.address) (\(distance))\nКурсы валют"
    }
}
