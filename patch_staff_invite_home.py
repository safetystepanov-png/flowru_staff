from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_home_screen.dart")
s = path.read_text(encoding="utf-8")

if "staff_invite_client_screen.dart" not in s:
    s = s.replace(
        "import 'staff_client_search_screen.dart';",
        "import 'staff_client_search_screen.dart';\nimport 'staff_invite_client_screen.dart';"
    )

if "void _openInviteClient()" not in s:
    marker = "  Widget _buildSearchHeroCard() {"
    insert = r'''
  void _openInviteClient() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StaffInviteClientScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  Widget _buildInviteClientCard() {
    return GestureDetector(
      onTap: _openInviteClient,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kHomeCardStrong,
              kHomeCard,
            ],
          ),
          border: Border.all(color: kHomeStroke),
          boxShadow: [
            BoxShadow(
              color: kHomeAccent.withOpacity(0.18),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [kHomeAccent, kHomeAccentSoft],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kHomeAccent.withOpacity(0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.person_crop_circle_badge_plus,
                color: Colors.white,
                size: 31,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пригласить клиента',
                    style: TextStyle(
                      color: kHomeInk,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Покажите QR заведения. Клиент добавит его в Flowru.',
                    style: TextStyle(
                      color: kHomeInkSoft,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kHomeInk.withOpacity(0.06),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                color: kHomeInk,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

'''
    if marker not in s:
        raise SystemExit("Не нашёл Widget _buildSearchHeroCard для вставки блока приглашения")
    s = s.replace(marker, insert + marker)

if "_buildInviteClientCard()" not in s.split("Widget _buildInviteClientCard()", 1)[-1]:
    old = "staggered(_buildSearchHeroCard()),"
    new = "staggered(_buildSearchHeroCard()),\n                          staggered(_buildInviteClientCard()),"
    if old not in s:
        raise SystemExit("Не нашёл staggered(_buildSearchHeroCard()), для добавления карточки")
    s = s.replace(old, new, 1)

path.write_text(s, encoding="utf-8")
print("staff_home_screen.dart patched")
