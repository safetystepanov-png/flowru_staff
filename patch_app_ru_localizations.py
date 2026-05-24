from pathlib import Path
import re

path = Path(r"lib\app\app.dart")
text = path.read_text(encoding="utf-8")

marker = "FLOWRU_APP_RU_LOCALIZATIONS_20260524"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

if "package:flutter_localizations/flutter_localizations.dart" not in text:
    m = re.search(r"import\s+'package:flutter/.*?';", text)
    if not m:
        raise SystemExit("ERROR: flutter import not found in app.dart")

    text = text[:m.end()] + "\nimport 'package:flutter_localizations/flutter_localizations.dart';" + text[m.end():]
    print("OK: import added")

if "GlobalCupertinoLocalizations.delegate" not in text:
    idx = text.find("MaterialApp(")
    if idx < 0:
        raise SystemExit("ERROR: MaterialApp not found in app.dart")

    insert_pos = idx + len("MaterialApp(")

    block = """
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
"""

    text = text[:insert_pos] + block + text[insert_pos:]
    print("OK: localization block inserted")
else:
    print("SKIP: localization delegates already exist")

text += f"\n// {marker}\n"
path.write_text(text, encoding="utf-8")
print("OK: app.dart patched")
