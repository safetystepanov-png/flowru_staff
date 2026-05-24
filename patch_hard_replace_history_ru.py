from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_establishment_history_screen.dart")
text = path.read_text(encoding="utf-8")

start = text.find("String flowruStaffNormalizeOperationType(String type) {")
end = text.find("const Color kHistMintTop", start)

if start < 0 or end < 0:
    raise SystemExit("ERROR: anchors not found for normalize function")

new_func = r'''String flowruStaffNormalizeOperationType(String type) {
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
    case 'write_off':
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

    case 'announcement':
      return 'Объявление';

    case 'schedule':
      return 'График';

    default:
      if (type.trim().isEmpty) {
        return 'Операция';
      }
      return type.trim();
  }
}


'''

text = text[:start] + new_func + text[end:]

start = text.find("String flowruCleanText(String value) {")
end = text.find("class StaffEstablishmentHistoryScreen", start)

if start >= 0 and end >= 0:
    new_clean = r'''String flowruCleanText(String value) {
  return value
      .replaceAll('вЂў', '•')
      .replaceAll('вЂ“', '–')
      .replaceAll('вЂ”', '—')
      .replaceAll('РІР‚Сћ', '•')
      .replaceAll('РІР‚вЂњ', '–')
      .replaceAll('РІР‚вЂќ', '—');
}


'''
    text = text[:start] + new_clean + text[end:]

text = text.replace("_error = 'РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РёСЃС‚РѕСЂРёСЋ Р·Р°РІРµРґРµРЅРёСЏ';", "_error = 'Не удалось загрузить историю заведения';")
text = text.replace("return '$dd.$mm вЂў $hh:$mi';", "return '$dd.$mm • $hh:$mi';")
text = text.replace("return '$dd.$mm РІР‚Сћ $hh:$mi';", "return '$dd.$mm • $hh:$mi';")

path.write_text(text, encoding="utf-8")
print("OK: history screen hard replaced")
