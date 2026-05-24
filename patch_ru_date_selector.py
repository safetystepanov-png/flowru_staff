from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_announcements_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_ANNOUNCEMENT_RU_DATE_SELECTOR_20260524"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

start = text.find("                                          await showCupertinoModalPopup<void>(")
if start < 0:
    raise SystemExit("ERROR: showCupertinoModalPopup block start not found")

end = text.find("                                        },", start)
if end < 0:
    raise SystemExit("ERROR: onTap block end not found")

old_block = text[start:end]

new_block = r'''                                          await showCupertinoModalPopup<void>(
                                            context: context,
                                            builder: (pickerContext) {
                                              DateTime localSelected = selected;

                                              const months = [
                                                'января',
                                                'февраля',
                                                'марта',
                                                'апреля',
                                                'мая',
                                                'июня',
                                                'июля',
                                                'августа',
                                                'сентября',
                                                'октября',
                                                'ноября',
                                                'декабря',
                                              ];

                                              String label(DateTime d) {
                                                return '${d.day} ${months[d.month - 1]} ${d.year}';
                                              }

                                              void shift(StateSetter modalSetState, int days) {
                                                modalSetState(() {
                                                  final next = localSelected.add(Duration(days: days));
                                                  final min = DateTime(now.year, now.month, now.day);
                                                  final max = now.add(const Duration(days: 365 * 3));

                                                  if (next.isBefore(min)) {
                                                    localSelected = min;
                                                  } else if (next.isAfter(max)) {
                                                    localSelected = max;
                                                  } else {
                                                    localSelected = next;
                                                  }
                                                });
                                              }

                                              return StatefulBuilder(
                                                builder: (context, modalSetState) {
                                                  return Container(
                                                    height: 310,
                                                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.vertical(
                                                        top: Radius.circular(26),
                                                      ),
                                                    ),
                                                    child: SafeArea(
                                                      top: false,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              CupertinoButton(
                                                                padding: EdgeInsets.zero,
                                                                onPressed: () => Navigator.of(pickerContext).pop(),
                                                                child: const Text(
                                                                  'Отмена',
                                                                  style: TextStyle(
                                                                    color: kAnnInkSoft,
                                                                    fontWeight: FontWeight.w800,
                                                                  ),
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              const Text(
                                                                'Дата окончания',
                                                                style: TextStyle(
                                                                  color: kAnnInk,
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.w900,
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              CupertinoButton(
                                                                padding: EdgeInsets.zero,
                                                                onPressed: () {
                                                                  setLocalState(() {
                                                                    expiresEnabled = true;
                                                                    expiresAt = DateTime(
                                                                      localSelected.year,
                                                                      localSelected.month,
                                                                      localSelected.day,
                                                                      23,
                                                                      59,
                                                                      59,
                                                                    );
                                                                  });
                                                                  Navigator.of(pickerContext).pop();
                                                                },
                                                                child: const Text(
                                                                  'Готово',
                                                                  style: TextStyle(
                                                                    color: kAnnAccent,
                                                                    fontWeight: FontWeight.w900,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 20),
                                                          Container(
                                                            padding: const EdgeInsets.all(18),
                                                            decoration: BoxDecoration(
                                                              color: kAnnAccent.withOpacity(0.08),
                                                              borderRadius: BorderRadius.circular(22),
                                                              border: Border.all(
                                                                color: kAnnAccent.withOpacity(0.16),
                                                              ),
                                                            ),
                                                            child: Column(
                                                              children: [
                                                                const Text(
                                                                  'Выбранная дата',
                                                                  style: TextStyle(
                                                                    color: kAnnInkSoft,
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w800,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Text(
                                                                  label(localSelected),
                                                                  textAlign: TextAlign.center,
                                                                  style: const TextStyle(
                                                                    color: kAnnInk,
                                                                    fontSize: 24,
                                                                    fontWeight: FontWeight.w900,
                                                                    letterSpacing: -0.4,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(height: 18),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: _ExpiryShiftButton(
                                                                  label: '- день',
                                                                  onTap: () => shift(modalSetState, -1),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                child: _ExpiryShiftButton(
                                                                  label: '+ день',
                                                                  onTap: () => shift(modalSetState, 1),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 10),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: _ExpiryShiftButton(
                                                                  label: '+ неделя',
                                                                  onTap: () => shift(modalSetState, 7),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                child: _ExpiryShiftButton(
                                                                  label: '+ месяц',
                                                                  onTap: () => shift(modalSetState, 30),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          );'''

text = text[:start] + new_block + text[end:]

anchor = "class _ExpiryChoiceButton extends StatelessWidget {"
if anchor not in text:
    raise SystemExit("ERROR: _ExpiryChoiceButton anchor not found")

shift_button = r'''class _ExpiryShiftButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExpiryShiftButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kAnnInk,
          side: const BorderSide(color: Color(0xFFE7EEF0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

'''

text = text.replace(anchor, shift_button + anchor, 1)

text += f"\n// {marker}\n"
path.write_text(text, encoding="utf-8")

print("OK: date picker replaced with Russian custom selector")
