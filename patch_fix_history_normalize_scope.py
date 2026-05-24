from pathlib import Path
import re

files = [
    Path(r"lib\features\staff\presentation\screens\staff_client_history_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_establishment_history_screen.dart"),
]

marker = "STAFF_NORMALIZE_TOP_LEVEL_20260523"

top_level_func = r'''
String flowruStaffNormalizeOperationType(String type) {
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
    case 'write_off':
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
      if (type.trim().isEmpty) {
        return 'Операция';
      }
      return type.trim();
  }
}

'''

for path in files:
    text = path.read_text(encoding="utf-8")

    # 1) Убираем старую функцию _normalizeOperationType, если она вставлена внутри класса.
    text = re.sub(
        r"\nString\s+_normalizeOperationType\s*\(\s*String\s+type\s*\)\s*\{.*?\n\}\n\n",
        "\n",
        text,
        flags=re.S,
        count=1,
    )

    # 2) Добавляем top-level функцию после import-блока.
    if marker not in text:
        import_matches = list(re.finditer(r"^import\s+.*?;\s*$", text, flags=re.M))
        if import_matches:
            insert_pos = import_matches[-1].end()
        else:
            insert_pos = 0

        text = text[:insert_pos] + "\n" + top_level_func + text[insert_pos:]
        text += f"\n// {marker}\n"

    # 3) В factory заменяем вызов на top-level функцию.
    text = text.replace("_normalizeOperationType(", "flowruStaffNormalizeOperationType(")

    # 4) На всякий случай _typeLabel тоже делает нормализацию.
    text = re.sub(
        r"String\s+_typeLabel\s*\(\s*String\s+type\s*\)\s*\{.*?\n\}",
        r'''String _typeLabel(String type) {
    return flowruStaffNormalizeOperationType(type);
  }''',
        text,
        flags=re.S,
        count=1,
    )

    path.write_text(text, encoding="utf-8")
    print(f"OK fixed normalize scope: {path}")
