import Foundation

/// Форматирование чисел и русское склонение числительных.
/// Общий код: используется и приложением, и виджетом.
enum Fmt {

    /// Курс обменника: до 4 знаков, лишние нули убираются (2.9950 -> 2,995).
    static func exact(_ value: Double, _ maxDecimals: Int) -> String {
        var s = String(format: "%.\(maxDecimals)f", value)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s.replacingOccurrences(of: ".", with: ",")
    }

    /// Денежный формат: всегда два знака после запятой (298,00).
    static func money(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Разряды: 200034,25 -> 200 034,25 (неразрывный пробел).
    static func grouped(_ text: String) -> String {
        let comma = text.firstIndex(of: ",")
        let intPart = comma.map { String(text[text.startIndex..<$0]) } ?? text
        let frac = comma.map { String(text[$0...]) } ?? ""
        var out = ""
        var count = 0
        for ch in intPart.reversed() {
            out.append(ch)
            count += 1
            if count % 3 == 0 && out.count < intPart.count {
                out.append("\u{00A0}")
            }
        }
        return String(out.reversed()) + frac
    }

    /// Разбор введённой суммы: принимает и запятую, и точку.
    static func parse(_ text: String) -> Double? {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        if v.isEmpty || v == "." || v == "-" || v == "+" { return nil }
        return Double(v)
    }

    /// Русское склонение: 1 отделение, 2 отделения, 5 отделений.
    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod100 = abs(n) % 100
        let mod10 = mod100 % 10
        if mod100 >= 11 && mod100 <= 14 { return many }
        if mod10 == 1 { return one }
        if mod10 >= 2 && mod10 <= 4 { return few }
        return many
    }
}
