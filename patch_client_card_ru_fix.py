from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_client_detail_screen.dart")
text = path.read_text(encoding="utf-8")

replacements = {
    "_error = 'РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РєР»РёРµРЅС‚Р°';": "_error = 'Не удалось загрузить клиента';",

    "'РљРђР РўРђ РљР›РР•РќРўРђ'": "'КАРТА КЛИЕНТА'",
    "'РљРђР РўРђ РљР›РР•РќРўРђ'": "'КАРТА КЛИЕНТА'",
    "'РљРђР РўРђ РљР›Р˜Р•РќРўРђ'": "'КАРТА КЛИЕНТА'",

    "'РўРµР»РµС„РѕРЅ РЅРµ СѓРєР°Р·Р°РЅ'": "'Телефон не указан'",
    "'Р‘Р°Р»Р°РЅСЃ'": "'Баланс'",
    "'РґРѕСЃС‚СѓРїРЅРѕ'": "'доступно'",
    "'Р’РёР·РёС‚С‹'": "'Визиты'",
    "'РІСЃРµРіРѕ'": "'всего'",
    "'РџРѕС‚СЂР°С‡РµРЅРѕ'": "'Потрачено'",
    "'СЃСѓРјРјР°'": "'сумма'",
    "'РўРµР»РµС„РѕРЅ'": "'Телефон'",
    "return 'РљР»РёРµРЅС‚';": "return 'Клиент';",
    "String get spentLabel => '${totalSpent.toStringAsFixed(0)} в‚Ѕ';": "String get spentLabel => '${totalSpent.toStringAsFixed(0)} ₽';",
}

changed = 0

for old, new in replacements.items():
    count = text.count(old)
    if count:
        text = text.replace(old, new)
        changed += count
        print(f"REPLACED: {old} -> {new} / {count}")

path.write_text(text, encoding="utf-8")
print("DONE changed:", changed)
