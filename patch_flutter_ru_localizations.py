from pathlib import Path
import re

pub = Path("pubspec.yaml")
main = Path("lib/main.dart")

pub_text = pub.read_text(encoding="utf-8")
main_text = main.read_text(encoding="utf-8")

# 1. Добавляем flutter_localizations в pubspec.yaml
if "flutter_localizations:" not in pub_text:
    marker = "  flutter:\n    sdk: flutter\n"
    if marker not in pub_text:
        raise SystemExit("ERROR: cannot find flutter sdk dependency block in pubspec.yaml")

    pub_text = pub_text.replace(
        marker,
        marker + "  flutter_localizations:\n    sdk: flutter\n",
        1,
    )
    pub.write_text(pub_text, encoding="utf-8")
    print("OK: flutter_localizations added to pubspec.yaml")
else:
    print("SKIP: flutter_localizations already exists")

# 2. Добавляем import в main.dart
if "package:flutter_localizations/flutter_localizations.dart" not in main_text:
    # после первого flutter import
    m = re.search(r"import\s+'package:flutter/.*?';", main_text)
    if not m:
        raise SystemExit("ERROR: cannot find flutter import in main.dart")

    main_text = main_text[:m.end()] + "\nimport 'package:flutter_localizations/flutter_localizations.dart';" + main_text[m.end():]
    print("OK: flutter_localizations import added")
else:
    print("SKIP: import already exists")

# 3. Добавляем локализации в MaterialApp/CupertinoApp, если их ещё нет.
localization_block = """      locale: const Locale('ru', 'RU'),
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

if "GlobalCupertinoLocalizations.delegate" not in main_text:
    # Ищем MaterialApp( или CupertinoApp(
    idx = main_text.find("MaterialApp(")
    app_name = "MaterialApp"
    if idx < 0:
        idx = main_text.find("CupertinoApp(")
        app_name = "CupertinoApp"

    if idx < 0:
        raise SystemExit("ERROR: MaterialApp/CupertinoApp not found in lib/main.dart")

    insert_pos = idx + len(app_name) + 1
    main_text = main_text[:insert_pos] + "\n" + localization_block + main_text[insert_pos:]
    print(f"OK: localization block added to {app_name}")
else:
    print("SKIP: localization delegates already exist")

main.write_text(main_text, encoding="utf-8")
