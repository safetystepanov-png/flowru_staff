from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_announcements_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_ANNOUNCEMENT_CUPERTINO_DATE_PICKER_20260524"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

old = r'''                                        onTap: () async {
                                          final now = DateTime.now();
                                          final picked = await showDatePicker(
                                            context: context,
                                            locale: const Locale('ru', 'RU'),
                                            initialDate: expiresAt ?? now.add(const Duration(days: 7)),
                                            firstDate: DateTime(now.year, now.month, now.day),
                                            lastDate: now.add(const Duration(days: 365 * 3)),
                                          );

                                          if (picked == null) return;

                                          setLocalState(() {
                                            expiresEnabled = true;
                                            expiresAt = DateTime(
                                              picked.year,
                                              picked.month,
                                              picked.day,
                                              23,
                                              59,
                                              59,
                                            );
                                          });
                                        },
'''

new = r'''                                        onTap: () async {
                                          final now = DateTime.now();
                                          DateTime selected = expiresAt ?? now.add(const Duration(days: 7));

                                          await showCupertinoModalPopup<void>(
                                            context: context,
                                            builder: (pickerContext) {
                                              return Container(
                                                height: 330,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.vertical(
                                                    top: Radius.circular(26),
                                                  ),
                                                ),
                                                child: SafeArea(
                                                  top: false,
                                                  child: Column(
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                                                        child: Row(
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
                                                                    selected.year,
                                                                    selected.month,
                                                                    selected.day,
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
                                                      ),
                                                      const Divider(height: 1),
                                                      Expanded(
                                                        child: CupertinoDatePicker(
                                                          mode: CupertinoDatePickerMode.date,
                                                          initialDateTime: selected,
                                                          minimumDate: DateTime(now.year, now.month, now.day),
                                                          maximumDate: now.add(const Duration(days: 365 * 3)),
                                                          onDateTimeChanged: (value) {
                                                            selected = value;
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
'''

if old not in text:
    raise SystemExit("ERROR: old showDatePicker block not found")

text = text.replace(old, new, 1)
text += f"\n// {marker}\n"
path.write_text(text, encoding="utf-8")

print("OK: showDatePicker replaced with CupertinoDatePicker")
