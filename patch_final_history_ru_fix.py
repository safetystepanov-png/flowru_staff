from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_establishment_history_screen.dart")
text = path.read_text(encoding="utf-8")

replacements = {
    "return 'РќР°С‡РёСЃР»РµРЅРёРµ';": "return 'Начисление';",
    "return 'РЎРїРёСЃР°РЅРёРµ';": "return 'Списание';",
    "return 'РљСѓРїРѕРЅ';": "return 'Купон';",
    "return 'Р\xa0РµС„РµСЂР°Р»СЊРЅС‹Р№ Р±РѕРЅСѓСЃ';": "return 'Реферальный бонус';",
    "return 'РЎРіРѕСЂР°РЅРёРµ Р±Р°Р»Р»РѕРІ';": "return 'Сгорание баллов';",
    "return 'Р’РёР·РёС‚';": "return 'Визит';",
    "return 'РћРїРµСЂР°С†РёСЏ';": "return 'Операция';",
    "_error = 'РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РёСЃС‚РѕСЂРёСЋ Р·Р°РІРµРґРµРЅРёСЏ';": "_error = 'Не удалось загрузить историю заведения';",
    "return '$dd.$mm вЂў $hh:$mi';": "return '$dd.$mm • $hh:$mi';",

    # Если где-то остались значения после helper'а
    "'Р“СЂР°С„РёРє'": "'График'",
    "'РћР±СЉСЏРІР»РµРЅРёРµ'": "'Объявление'",
    "'Р—Р°РєСЂРµРїР»РµРЅРѕ'": "'Закреплено'",
    "'РћР·РЅР°РєРѕРјР»РµРЅ'": "'Ознакомлен'",
    "'РЎС‚Р°С‚СѓСЃ'": "'Статус'",
}

changed = 0

for old, new in replacements.items():
    count = text.count(old)
    if count:
        text = text.replace(old, new)
        changed += count
        print(f"REPLACED {old}: {count}")

path.write_text(text, encoding="utf-8")
print("DONE changed:", changed)
