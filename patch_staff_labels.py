from pathlib import Path
import re

files = [
    Path(r"lib\features\staff\presentation\screens\staff_client_history_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_establishment_history_screen.dart"),
]

marker = "STAFF_HUMAN_OPERATION_LABELS_20260523"

label_func = r'''String _typeLabel(String type) {
  final value = type.trim().toLowerCase();

  switch (value) {
    case 'purchase':
    case 'accrual':
    case 'accrue':
    case 'bonus':
    case 'add':
      return 'Начисление';

    case 'redeem':
    case 'spend':
    case 'writeoff':
    case 'subtract':
      return 'Списание';

    case 'reward_redeem':
    case 'reward':
    case 'coupon':
      return 'Купон';

    case 'referral':
      return 'Реферальный бонус';

    case 'expire_burn':
    case 'burn':
      return 'Сгорание баллов';

    case 'visit':
      return 'Визит';

    default:
      return 'Операция';
  }
}
'''

for path in files:
    text = path.read_text(encoding="utf-8")

    if marker in text:
        print(f"SKIP already patched: {path}")
        continue

    m = re.search(r"String\s+_typeLabel\s*\(\s*String\s+type\s*\)\s*\{", text)
    if not m:
        print(f"ERROR: _typeLabel not found in {path}")
        continue

    start = m.start()
    brace_start = text.find("{", m.start())
    depth = 0
    end = None

    for i in range(brace_start, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    if end is None:
        print(f"ERROR: cannot find end of _typeLabel in {path}")
        continue

    text = text[:start] + label_func + text[end:]
    text += f"\n// {marker}\n"
    path.write_text(text, encoding="utf-8")
    print(f"OK patched labels: {path}")
