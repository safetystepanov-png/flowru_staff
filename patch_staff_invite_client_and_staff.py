from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_invite_client_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_INVITE_CLIENT_AND_STAFF_20260524"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

# 1. Добавляем url_launcher import
if "package:url_launcher/url_launcher.dart" not in text:
    text = text.replace(
        "import 'package:qr_flutter/qr_flutter.dart';",
        "import 'package:qr_flutter/qr_flutter.dart';\nimport 'package:url_launcher/url_launcher.dart';",
        1,
    )

# 2. Добавляем ссылку Staff App Store после констант
anchor = "const Color kInviteViolet = Color(0xFF7A4CFF);\n"
if anchor not in text:
    raise SystemExit("ERROR: constants anchor not found")

text = text.replace(
    anchor,
    anchor + "\nconst String kFlowruStaffAppStoreUrl = 'https://apps.apple.com/us/app/flowru-staff/id6762253836';\n",
    1,
)

# 3. Заголовок экрана
text = text.replace("title: 'Пригласить клиента',", "title: 'Пригласить',", 1)

# 4. Добавляем метод открытия App Store в State
method_anchor = """  Future<void> _load() async {
"""
if method_anchor not in text:
    raise SystemExit("ERROR: _load anchor not found")

open_method = """  Future<void> _openStaffAppStore() async {
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

"""

text = text.replace(method_anchor, open_method + method_anchor, 1)

# 5. Вставляем карточку сотрудника после инструкции
old_block = """                          _InviteStepsCard(
                            establishmentName: invite.establishmentName,
                          ),
"""

new_block = """                          _InviteStepsCard(
                            establishmentName: invite.establishmentName,
                          ),

                          const SizedBox(height: 16),

                          _InviteStaffCard(
                            onOpen: _openStaffAppStore,
                          ),
"""

if old_block not in text:
    raise SystemExit("ERROR: InviteStepsCard block not found")

text = text.replace(old_block, new_block, 1)

# 6. Добавляем саму карточку перед _InviteStepsCard
class_anchor = "class _InviteStepsCard extends StatelessWidget {"
if class_anchor not in text:
    raise SystemExit("ERROR: _InviteStepsCard class anchor not found")

staff_card = r'''class _InviteStaffCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _InviteStaffCard({
    required this.onOpen,
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
                      'Откроется Flowru Staff в App Store. Сотрудник установит приложение и сможет войти в рабочий контур.',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(CupertinoIcons.arrow_down_app_fill),
              label: const Text('Открыть Flowru Staff в App Store'),
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

text = text.replace(class_anchor, staff_card + class_anchor, 1)

text += f"\n// {marker}\n"
path.write_text(text, encoding="utf-8")

print("OK: invite screen now supports client + staff invite")
