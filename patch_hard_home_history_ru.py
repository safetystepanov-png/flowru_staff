from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_home_screen.dart")
text = path.read_text(encoding="utf-8")

# Убираем битый заголовок карточки истории заведения.
broken_variants = [
    "РќСЃС‚РѕСЂРёСЏ",
    "РСЃС‚РѕСЂРёСЏ",
    "РСЃС‚РѕСЂРёСЏ",
    "РќСЃС‚РѕСЂРёСЏ Р·Р°РІРµРґРµРЅРёСЏ",
    "РСЃС‚РѕСЂРёСЏ Р·Р°РІРµРґРµРЅРёСЏ",
    "РСЃС‚РѕСЂРёСЏ Р·Р°РІРµРґРµРЅРёСЏ",
]

for old in broken_variants:
    text = text.replace(old, "История заведения")

# Убираем битые подписи, которые видны под карточкой.
subtitle_variants = [
    "РЎРѕР±С‹С‚РёСЏ Рё РґРµР№СЃС‚РІРёСЏ РїРѕ Р·Р°РІРµРґРµРЅРёСЋ",
    "РЎРѕР±С‹С‚РёСЏ Рё РґРµР№СЃС‚РІРёСЏ",
    "РЎРѕР±С‹С‚РёСЏ",
]

for old in subtitle_variants:
    text = text.replace(old, "События и действия по заведению")

# Если карточка истории собирается через route/widget и текст не совпал,
# заменяем короткие битые литералы рядом с History на нормальные.
text = re.sub(
    r"'[^']*Р[^']*С[^']*'",
    lambda m: "'История заведения'" if len(m.group(0)) < 40 else m.group(0),
    text,
)

path.write_text(text, encoding="utf-8")
print("OK: home visible history labels patched")
