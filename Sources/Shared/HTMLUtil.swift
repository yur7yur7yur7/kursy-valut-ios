import Foundation

/// Мелкие помощники для разбора HTML: теги, сущности, числа, регулярки.
enum HTML {

    /// Убирает теги и HTML-сущности, схлопывает пробелы.
    static func strip(_ source: String) -> String {
        var text = source
        text = replaceAll("(?s)<script.*?</script>", text, " ")
        text = replaceAll("(?s)<style.*?</style>", text, " ")
        text = replaceAll("<[^>]*>", text, " ")
        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&#39;": "'",
            "&laquo;": "«", "&raquo;": "»", "&ndash;": "-", "&mdash;": "-"
        ]
        for (key, value) in entities {
            text = text.replacingOccurrences(of: key, with: value)
        }
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        return collapse(text)
    }

    /// Схлопывает пробельные символы в один.
    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Первое число в тексте: «2,9830» -> 2.983.
    static func number(_ source: String) -> Double? {
        let text = strip(source)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let range = text.range(of: "-?\\d+(\\.\\d+)?", options: .regularExpression) else {
            return nil
        }
        return Double(text[range])
    }

    /// Значение атрибута вида name="value" (первое вхождение).
    static func attr(_ html: String, _ name: String) -> String? {
        guard let groups = firstMatch("\(name)=\"([^\"]*)\"", html) else { return nil }
        return groups.count > 1 ? groups[1] : nil
    }

    /// Все совпадения регулярки: первый элемент — весь текст, дальше — группы.
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern,
                                                 options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        var out: [[String]] = []
        for match in re.matches(in: text, options: [], range: range) {
            var groups: [String] = []
            if let whole = Range(match.range, in: text) {
                groups.append(String(text[whole]))
            }
            for i in 1..<match.numberOfRanges {
                if let r = Range(match.range(at: i), in: text) {
                    groups.append(String(text[r]))
                } else {
                    groups.append("")
                }
            }
            out.append(groups)
        }
        return out
    }

    /// Первое совпадение регулярки (или nil).
    static func firstMatch(_ pattern: String, _ text: String) -> [String]? {
        let all = matches(pattern, text)
        return all.isEmpty ? nil : all[0]
    }

    private static func replaceAll(_ pattern: String, _ text: String, _ template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern,
                                                 options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
