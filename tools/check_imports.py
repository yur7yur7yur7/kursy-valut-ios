"""Грубая проверка Swift-файлов: очевидные пропуски импортов и незакрытые строки.

Полноценная проверка — это компилятор на macOS (CI), здесь ловим только
очевидное: файл использует Color/View/Text, но не импортирует SwiftUI.
"""
import glob
import re

RULES = [
    (r'\bColor\(', 'SwiftUI'),
    (r'\bText\(', 'SwiftUI'),
    (r'\bView\b', 'SwiftUI'),
    (r'@main', 'SwiftUI'),
    (r'\.padding\(', 'SwiftUI'),
    (r'\bUIImage\(', 'UIKit'),
    (r'\bUIActivityViewController\b', 'UIKit'),
    (r'\bCLLocationManager\b', 'CoreLocation'),
    (r'\bWidget\b', 'WidgetKit'),
    (r'\bTimelineProvider\b', 'WidgetKit'),
    (r'\bURLSession\b', 'Foundation'),
    (r'\bJSONEncoder\b', 'Foundation'),
    (r'\bNSRegularExpression\b', 'Foundation'),
]

problems = []
for f in sorted(glob.glob('Sources/**/*.swift', recursive=True)):
    src = open(f, encoding='utf-8').read()
    imports = set()
    for m in re.finditer(r'^import\s+(\w+)', src, re.M):
        imports.add(m.group(1))
    body = re.sub(r'^import\s+\w+', '', src, flags=re.M)
    for pattern, module in RULES:
        if re.search(pattern, body) and module not in imports:
            problems.append('%s: использует %s, но нет import %s' % (f, pattern, module))
    if body.count('"') % 2 != 0:
        problems.append('%s: нечётное число кавычек' % f)

for p in problems:
    print('ПРОБЛЕМА:', p)
print('проблем найдено:', len(problems))
