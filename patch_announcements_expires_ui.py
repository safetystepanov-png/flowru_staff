from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_announcements_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_ANNOUNCEMENT_EXPIRES_UI_20260524"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

# 1. Добавляем локальные переменные в _showCreateDialog
old = """    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool pinned = false;
"""

new = """    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool pinned = false;
    bool expiresEnabled = false;
    DateTime? expiresAt;
"""

if old not in text:
    raise SystemExit("ERROR: create dialog variables block not found")

text = text.replace(old, new, 1)


# 2. Добавляем UI выбора срока после SwitchListTile "Закрепить"
old = """                          const SizedBox(height: 18),
                          Row(
"""

expiry_ui = r'''                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: kAnnBlue.withOpacity(0.07),
                              border: Border.all(
                                color: kAnnBlue.withOpacity(0.10),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Срок действия',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: kAnnInk,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ExpiryChoiceButton(
                                        selected: !expiresEnabled,
                                        title: 'Бессрочно',
                                        icon: CupertinoIcons.infinity,
                                        onTap: () {
                                          setLocalState(() {
                                            expiresEnabled = false;
                                            expiresAt = null;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ExpiryChoiceButton(
                                        selected: expiresEnabled,
                                        title: expiresAt == null
                                            ? 'До даты'
                                            : 'До ${expiresAt!.day.toString().padLeft(2, '0')}.${expiresAt!.month.toString().padLeft(2, '0')}.${expiresAt!.year}',
                                        icon: CupertinoIcons.calendar,
                                        onTap: () async {
                                          final now = DateTime.now();
                                          final picked = await showDatePicker(
                                            context: context,
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
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
'''

if old not in text:
    raise SystemExit("ERROR: insert point before dialog buttons not found")

text = text.replace(old, expiry_ui, 1)


# 3. Передаём expiresAt в _createAnnouncement
old = """                                            await _createAnnouncement(
                                              title: title,
                                              body: body,
                                              pinned: pinned,
                                            );
"""

new = """                                            await _createAnnouncement(
                                              title: title,
                                              body: body,
                                              pinned: pinned,
                                              expiresAt: expiresEnabled ? expiresAt : null,
                                            );
"""

if old not in text:
    raise SystemExit("ERROR: _createAnnouncement call not found")

text = text.replace(old, new, 1)


# 4. Меняем сигнатуру _createAnnouncement
old = """  Future<void> _createAnnouncement({
    required String title,
    required String body,
    required bool pinned,
  }) async {
"""

new = """  Future<void> _createAnnouncement({
    required String title,
    required String body,
    required bool pinned,
    DateTime? expiresAt,
  }) async {
"""

if old not in text:
    raise SystemExit("ERROR: _createAnnouncement signature not found")

text = text.replace(old, new, 1)


# 5. Добавляем expires_at в JSON
old = """          'body': body,
          'is_pinned': pinned,
"""

new = """          'body': body,
          'is_pinned': pinned,
          'expires_at': expiresAt?.toUtc().toIso8601String(),
"""

if old not in text:
    raise SystemExit("ERROR: json body insert point not found")

text = text.replace(old, new, 1)


# 6. Добавляем виджет кнопки выбора срока перед _AnnouncementItem
anchor = "class _AnnouncementItem {"
if anchor not in text:
    raise SystemExit("ERROR: _AnnouncementItem anchor not found")

expiry_widget = r'''class _ExpiryChoiceButton extends StatelessWidget {
  final bool selected;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ExpiryChoiceButton({
    required this.selected,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? kAnnAccent.withOpacity(0.15) : Colors.white,
            border: Border.all(
              color: selected
                  ? kAnnAccent.withOpacity(0.45)
                  : const Color(0xFFE7EEF0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? kAnnAccent : kAnnInkSoft,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? kAnnInk : kAnnInkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

'''

text = text.replace(anchor, expiry_widget + anchor, 1)

text += f"\n// {marker}\n"
path.write_text(text, encoding="utf-8")

print("OK: announcement expires UI patched")
