"""Проверка строк в Swift-файлах: считаем только неэкранированные кавычки."""
import glob
import re

for f in sorted(glob.glob('Sources/**/*.swift', recursive=True)):
    src = open(f, encoding='utf-8').read()
    n = len(re.findall(r'(?<!\\)"', src))
    if n % 2 != 0:
        print('НЕЧЁТНОЕ число кавычек:', f, n)
print('проверено файлов:', len(glob.glob('Sources/**/*.swift', recursive=True)))
