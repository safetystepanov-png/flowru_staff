from pathlib import Path

files = [
    Path(r"lib\features\staff\presentation\screens\staff_client_history_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_establishment_history_screen.dart"),
]

marker = "STAFF_OPERATION_TYPE_NORMALIZE_20260523"

helper = r'''
String _normalizeOperationType(String type) {
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
      if (type.trim().isEmpty) {
        return 'Операция';
      }
      return type.trim();
  }
}

'''

for path in files:
    text = path.read_text(encoding="utf-8")

    if marker in text:
        print(f"SKIP already patched: {path}")
        continue

    insert_pos = text.find("String _typeLabel")
    if insert_pos < 0:
        print(f"WARN: _typeLabel not found, adding helper before model class in {path}")
        insert_pos = text.find("class _")
        if insert_pos < 0:
            insert_pos = len(text)

    text = text[:insert_pos] + helper + text[insert_pos:]

    old = "json['operation_type']?.toString() ?? json['type']?.toString() ?? ''"
    new = "_normalizeOperationType(json['operation_type']?.toString() ?? json['type']?.toString() ?? '')"

    count = text.count(old)
    if count == 0:
        print(f"WARN: parse expression not found in {path}")
    else:
        text = text.replace(old, new)
        print(f"OK normalized parse in {path}: {count}")

    # Если _typeLabel всё ещё получает уже нормализованный русский тип — возвращаем его как есть.
    text = text.replace(
        "final value = type.trim().toLowerCase();",
        "final raw = type.trim();\n  if (raw == 'Начисление' || raw == 'Списание' || raw == 'Купон' || raw == 'Реферальный бонус' || raw == 'Сгорание баллов' || raw == 'Визит' || raw == 'Операция') return raw;\n  final value = raw.toLowerCase();",
        1,
    )

    text += f"\n// {marker}\n"
    path.write_text(text, encoding="utf-8")
    print(f"OK patched: {path}")
