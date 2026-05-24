from pathlib import Path

replacements = {
    "╨б╨╛╤В╤А╤Г╨┤╨╜╨╕╨║": "Сотрудник",
    "╨Ъ╨╗╨╕╨╡╨╜╤В": "Клиент",
    "╨Я╤А╨╕╨│╨╗╨░╤И╨╡╨╜╨╕╨╡ ╨║╨╗╨╕╨╡╨╜╤В╨░": "Приглашение клиента",
    "╨С╨░╨╗╨╗╤Л ╨▓ ╤А╨╡╨╢╨╕╨╝╨╡ ╤Б╨║╨╕╨┤╨╛╨║ ╨╛╤В╨║╨╗╤О╤З╨╡╨╜╤Л": "Баллы в режиме скидок отключены",
    "╨Ъ╤Н╤И╨▒╤Н╨║": "Кэшбэк",
    "ЁЯСН": "👍",
}

files = [
    Path(r"lib\features\staff\data\staff_announcements_api.dart"),
    Path(r"lib\features\staff\data\staff_chat_api.dart"),
    Path(r"lib\features\staff\data\staff_client_qr_api.dart"),
    Path(r"lib\features\staff\data\staff_invite_api.dart"),
    Path(r"lib\features\staff\data\staff_loyalty_calculator.dart"),
    Path(r"lib\features\staff\data\models\reaction_item.dart"),
]

for path in files:
    text = path.read_text(encoding="utf-8")
    before = text

    for old, new in replacements.items():
        text = text.replace(old, new)

    if text != before:
        path.write_text(text, encoding="utf-8")
        print("FIXED:", path)
    else:
        print("NO CHANGE:", path)
