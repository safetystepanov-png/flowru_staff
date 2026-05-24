from pathlib import Path

targets = [
    Path(r"lib\features\staff\presentation\screens\staff_announcements_screen.dart"),
    Path(r"lib\features\staff\presentation\screens\staff_establishment_history_screen.dart"),
]

helper = r'''
String flowruCleanText(String value) {
  var s = value;

  final replacements = <String, String>{
    'РђРєС‚РёРІРЅРѕ': 'Активно',
    'РђРєС‚РёРІРЅР°': 'Активна',
    'Р—Р°РєСЂРµРїР»РµРЅРѕ': 'Закреплено',
    'РћР·РЅР°РєРѕРјР»РµРЅ': 'Ознакомлен',
    'РџСЂРѕС‡РёС‚Р°РЅРѕ': 'Прочитано',
    'РќРµ РѕР·РЅР°РєРѕРјР»РµРЅ': 'Не ознакомлен',
    'Р“СЂР°С„РёРє': 'График',
    'РСЃС‚РѕСЂРёСЏ': 'История',
    'РћР±СЉСЏРІР»РµРЅРёРµ': 'Объявление',
    'РћР±СЉСЏРІР»РµРЅРёСЏ': 'Объявления',
    'Р’Р°Р¶РЅРѕ': 'Важно',
    'РќРѕРІРѕРµ': 'Новое',
    'СЃРѕР·РґР°РЅРѕ': 'создано',
    'СЂР°Р±РѕС‚С‹': 'работы',
    'СЃРѕС‚СЂСѓРґРЅРёРє': 'сотрудник',
    'вЂў': '•',
    'вЂ“': '–',
    'вЂ”': '—',
  };

  replacements.forEach((from, to) {
    s = s.replaceAll(from, to);
  });

  final brokenMarkers = [
    'Рђ', 'Рџ', 'Рќ', 'РЎ', 'Рћ', 'Р—', 'СЃ', 'С‚', 'СЂ', '╨', '╤', 'Ð', 'Ñ', 'вЂ'
  ];

  final stillBroken = brokenMarkers.any((m) => s.contains(m));
  if (!stillBroken) return s;

  // Для коротких жёлтых бейджей лучше не показывать мусор.
  if (s.length <= 24) {
    if (s.toLowerCase().contains('schedule') || s.contains('Граф')) return 'График';
    if (s.toLowerCase().contains('announcement') || s.contains('Об')) return 'Объявление';
    if (s.toLowerCase().contains('pinned')) return 'Закреплено';
    if (s.toLowerCase().contains('ack')) return 'Ознакомлен';
    return 'Статус';
  }

  return s;
}

'''

for path in targets:
    text = path.read_text(encoding="utf-8")
    before = text

    if "String flowruCleanText(String value)" not in text:
        # вставляем перед первым class
        idx = text.find("class ")
        if idx < 0:
            raise SystemExit(f"ERROR: class anchor not found in {path}")
        text = text[:idx] + helper + "\n" + text[idx:]

    # Самые частые места вывода. Это безопасно: нормальный текст останется нормальным.
    replacements = {
        "Text(item.title,": "Text(flowruCleanText(item.title),",
        "Text(item.body,": "Text(flowruCleanText(item.body),",
        "Text(item.comment,": "Text(flowruCleanText(item.comment),",
        "Text(item.eventType,": "Text(flowruCleanText(item.eventType),",
        "Text(item.type,": "Text(flowruCleanText(item.type),",
        "Text(item.status,": "Text(flowruCleanText(item.status),",
        "Text(item.title ?? '',": "Text(flowruCleanText(item.title ?? ''),",
        "Text(item.comment ?? '',": "Text(flowruCleanText(item.comment ?? ''),",
        "Text(item.eventType ?? '',": "Text(flowruCleanText(item.eventType ?? ''),",
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    if text != before:
        path.write_text(text, encoding="utf-8")
        print("PATCHED:", path)
    else:
        print("NO CHANGE:", path)
