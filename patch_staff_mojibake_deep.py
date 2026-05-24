from pathlib import Path
import re

files = [
    Path(r"lib\features\staff\presentation\screens\staff_home_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_announcements_screen.dart"),
    Path(r"lib\features\staff\data\staff_announcements_api.dart"),
]

bad_markers = [
    "Р", "СЃ", "С‚", "СЂ", "Р°", "Рё", "Рѕ", "Рµ",
    "Рќ", "Рџ", "РЎ", "Рґ", "Р»", "Р№", "СЊ", "С‹",
    "вЂў", "вЂ“", "вЂ”", "В·", "В "
]

def bad_score(s: str) -> int:
    return sum(s.count(m) for m in bad_markers)

def try_fix(s: str) -> str:
    if bad_score(s) == 0:
        return s

    candidates = []

    # Главный случай: UTF-8 прочитали как CP1251.
    try:
        candidates.append(s.encode("cp1251").decode("utf-8"))
    except Exception:
        pass

    # Иногда попадается двойная порча.
    try:
        one = s.encode("cp1251").decode("utf-8")
        candidates.append(one.encode("cp1251").decode("utf-8"))
    except Exception:
        pass

    best = s
    best_score = bad_score(s)

    for c in candidates:
        score = bad_score(c)
        if score < best_score:
            best = c
            best_score = score

    return best

def fix_string_literals(text: str) -> str:
    # Чиним содержимое одинарных и двойных строк. Интерполяцию не трогаем структурно.
    pattern = re.compile(r"""(['"])(.*?)(?<!\\)\1""", re.S)

    def repl(m):
        quote = m.group(1)
        body = m.group(2)
        fixed = try_fix(body)
        return quote + fixed + quote

    return pattern.sub(repl, text)

manual = {
    "РџСЂРёРіР»Р°СЃРёС‚СЊ РєР»РёРµРЅС‚Р°": "Пригласить клиента",
    "РџСЂРёРіР»Р°СЃРёС‚СЊ": "Пригласить",
    "РћР±СЉСЏРІР»РµРЅРёСЏ": "Объявления",
    "Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ": "Дополнительно",
    "Р“СЂР°С„РёРє СЂР°Р±РѕС‚С‹": "График работы",
    "РЎРѕР±С‹С‚РёСЏ Рё РґРµР№СЃС‚РІРёСЏ РїРѕ Р·Р°РІРµРґРµРЅРёСЋ": "События и действия по заведению",
    "РњРµСЃСЏС†, СЃРјРµРЅС‹ Рё СЂР°Р±РѕС‡РёРµ РґРЅРё": "Месяц, смены и рабочие дни",
    "РџРѕРєР°Р¶РёС‚Рµ QR Р·Р°РІРµРґРµРЅРёСЏ. РљР»РёРµРЅС‚ РґРѕР±Р°РІРёС‚ РµРіРѕ РІ Flowru.": "Покажите QR заведения. Клиент добавит его в Flowru.",
    "РќРѕРІРѕРµ РѕР±СЉСЏРІР»РµРЅРёРµ": "Новое объявление",
    "РЎРѕР·РґР°Р№ РѕР±СЉСЏРІР»РµРЅРёРµ РґР»СЏ СЃРѕС‚СЂСѓРґРЅРёРєРѕРІ Р·Р°РІРµРґРµРЅРёСЏ": "Создайте объявление для сотрудников заведения",
    "Р—Р°РіРѕР»РѕРІРѕРє": "Заголовок",
    "РўРµРєСЃС‚ РѕР±СЉСЏРІР»РµРЅРёСЏ": "Текст объявления",
    "Р—Р°РєСЂРµРїРёС‚СЊ": "Закрепить",
    "Р—Р°РєСЂРµРїР»РµРЅРѕ": "Закреплено",
    "РћС‚РјРµРЅР°": "Отмена",
    "РЎРѕР·РґР°С‚СЊ": "Создать",
    "РћР±СЉСЏРІР»РµРЅРёРµ": "Объявление",
    "РџСЂРѕС‡РёС‚Р°РЅРѕ": "Прочитано",
    "РЈРґР°Р»РёС‚СЊ": "Удалить",
    "РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РѕР±СЉСЏРІР»РµРЅРёСЏ": "Не удалось загрузить объявления",
    "РќРµ СѓРґР°Р»РѕСЃСЊ СЃРѕР·РґР°С‚СЊ РѕР±СЉСЏРІР»РµРЅРёРµ": "Не удалось создать объявление",
    "вЂў": "•",
    "вЂ“": "–",
    "вЂ”": "—",
}

for path in files:
    text = path.read_text(encoding="utf-8")
    before = text

    text = fix_string_literals(text)

    for old, new in manual.items():
        text = text.replace(old, new)

    path.write_text(text, encoding="utf-8")
    print(f"OK: {path} changed={text != before}, remaining_bad_score={bad_score(text)}")
