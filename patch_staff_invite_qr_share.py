from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_invite_client_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_INVITE_STAFF_QR_SHARE_20260524"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

# 1. Добавляем share_plus import
if "package:share_plus/share_plus.dart" not in text:
    text = text.replace(
        "import 'package:url_launcher/url_launcher.dart';",
        "import 'package:url_launcher/url_launcher.dart';\nimport 'package:share_plus/share_plus.dart';",
        1,
    )

# Если url_launcher больше не нужен для карточки сотрудника, оставим импорт — он может использоваться дальше в файле.

# 2. Добавляем метод поделиться ссылкой вместо открытия App Store
old_method = r'''  Future<void> _openStaffAppStore() async {
    final uri = Uri.parse(kFlowruStaffAppStoreUrl);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть App Store'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть App Store'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

'''

new_method = r'''  Future<void> _shareStaffInvite() async {
    const text = 'Установи Flowru Staff для работы с системой лояльности:\n$kFlowruStaffAppStoreUrl';

    try {
      await Share.share(text);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть меню отправки'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

'''

if old_method in text:
    text = text.replace(old_method, new_method, 1)
else:
    # Если метод уже менялся, вставим новый перед _load()
    if "_shareStaffInvite" not in text:
        anchor = "  Future<void> _load() async {\n"
        if anchor not in text:
            raise SystemExit("ERROR: _load anchor not found")
        text = text.replace(anchor, new_method + anchor, 1)

# 3. Меняем вызов карточки
text = text.replace(
    "_InviteStaffCard(\n                            onOpen: _openStaffAppStore,\n                          ),",
    "_InviteStaffCard(\n                            onShare: _shareStaffInvite,\n                          ),",
    1,
)

text = text.replace(
    "_InviteStaffCard(\n                            onOpen: _shareStaffInvite,\n                          ),",
    "_InviteStaffCard(\n                            onShare: _shareStaffInvite,\n                          ),",
    1,
)

# 4. Полностью заменяем класс _InviteStaffCard
start = text.find("class _InviteStaffCard extends StatelessWidget {")
if start < 0:
    raise SystemExit("ERROR: _InviteStaffCard class not found")

end = text.find("class _InviteStepsCard extends StatelessWidget {", start)
if end < 0:
    raise SystemExit("ERROR: _InviteStepsCard anchor not found")

new_class = r'''class _InviteStaffCard extends StatelessWidget {
  final VoidCallback onShare;

  const _InviteStaffCard({
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [kInviteBlue, kInviteViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kInviteBlue.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.person_2_fill,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пригласить сотрудника',
                      style: TextStyle(
                        color: kInviteInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Покажите QR сотруднику или отправьте ссылку в мессенджер. Он установит Flowru Staff и войдёт в рабочий контур.',
                      style: TextStyle(
                        color: kInviteInkSoft,
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE8EEF2)),
                boxShadow: [
                  BoxShadow(
                    color: kInviteBlue.withOpacity(0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: QrImageView(
                data: kFlowruStaffAppStoreUrl,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
                foregroundColor: kInviteInk,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: kInviteInk,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: kInviteInk,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Center(
            child: Text(
              'QR ведёт на Flowru Staff в App Store',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kInviteInkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(CupertinoIcons.share),
              label: const Text('Поделиться ссылкой'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: kInviteBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

'''

text = text[:start] + new_class + text[end:]

text += f"\n// {marker}\n"
path.write_text(text, encoding="utf-8")

print("OK: staff invite card now has QR + share button")
