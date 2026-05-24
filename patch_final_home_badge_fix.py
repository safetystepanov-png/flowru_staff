from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_home_screen.dart")
text = path.read_text(encoding="utf-8")

# 1. Прямо заменяем известную битую строку жёлтой плашки.
text = text.replace(
    "_isOwner ? 'РћР‘РЄРЇР’Р›Р•РќРР•' : 'Р’РђР–РќРћР• РћР‘РЄРЇР’Р›Р•РќРР•'",
    "_isOwner ? 'ОБЪЯВЛЕНИЕ' : 'ВАЖНОЕ ОБЪЯВЛЕНИЕ'",
)

# 2. На случай если там перенос строки внутри литерала или другой похожий мусор.
text = re.sub(
    r"_isOwner\s*\?\s*'[^']*Р[^']*'\s*:\s*'[^']*Р[^']*'",
    "_isOwner ? 'ОБЪЯВЛЕНИЕ' : 'ВАЖНОЕ ОБЪЯВЛЕНИЕ'",
    text,
)

path.write_text(text, encoding="utf-8")
print("OK: home announcement yellow badge fixed")
