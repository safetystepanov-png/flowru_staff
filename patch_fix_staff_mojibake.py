from pathlib import Path

files = [
    Path(r"lib\features\staff\presentation\screens\staff_home_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_announcements_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_invite_client_screen.dart"),
]

def looks_broken(line: str) -> bool:
    markers = ["Р", "СЃ", "С‚", "СЂ", "Р°", "Рё", "Рѕ", "Рµ", "Рќ", "Рџ", "РЎ", "Рґ", "Р»"]
    return sum(1 for m in markers if m in line) >= 2

def fix_line(line: str) -> str:
    if not looks_broken(line):
        return line

    try:
        fixed = line.encode("cp1251").decode("utf-8")
    except Exception:
        return line

    # Принимаем замену только если битых маркеров стало меньше.
    if sum(fixed.count(m) for m in ["Р", "СЃ", "С‚", "СЂ", "Р°", "Рё", "Рѕ"]) < sum(line.count(m) for m in ["Р", "СЃ", "С‚", "СЂ", "Р°", "Рё", "Рѕ"]):
        return fixed

    return line

for path in files:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    fixed_lines = [fix_line(line) for line in lines]
    fixed_text = "".join(fixed_lines)

    path.write_text(fixed_text, encoding="utf-8")

    changed = sum(1 for a, b in zip(lines, fixed_lines) if a != b)
    print(f"OK: {path} fixed lines: {changed}")
