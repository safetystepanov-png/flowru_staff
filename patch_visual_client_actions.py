from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_client_detail_screen.dart")
text = path.read_text(encoding="utf-8")

# Чиним остатки текста, если где-то ещё есть mojibake в action-зоне.
replacements = {
    "'РќР°С‡РёСЃР»РёС‚СЊ'": "'Начислить'",
    "'РЎРїРёСЃР°С‚СЊ'": "'Списать'",
    "'РСЃС‚РѕСЂРёСЏ'": "'История'",
    "'РќР°РіСЂР°РґС‹'": "'Награды'",
    "'РљСѓРїРѕРЅС‹'": "'Купоны'",
    "'Р”РµР№СЃС‚РІРёСЏ'": "'Действия'",
    "'Р‘С‹СЃС‚СЂС‹Рµ РґРµР№СЃС‚РІРёСЏ'": "'Быстрые действия'",
}

for old, new in replacements.items():
    text = text.replace(old, new)


# Если уже есть _actionsCard — заменяем полностью.
def replace_widget_func(src: str, func_name: str, new_func: str) -> str:
    start = src.find(f"  Widget {func_name}(")
    if start < 0:
        return src

    # ищем следующую функцию/класс
    candidates = []
    for anchor in ["\n  Widget ", "\n  Future<", "\n  void ", "\n  Color ", "\n  IconData ", "\nclass "]:
        pos = src.find(anchor, start + 1)
        if pos >= 0:
            candidates.append(pos)

    if not candidates:
        raise SystemExit(f"ERROR: cannot find end after {func_name}")

    end = min(candidates)
    return src[:start] + new_func + "\n" + src[end:]


new_actions_card = r'''  Widget _actionsCard() {
    final client = _client!;

    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [kClientAccent, kClientAccentSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kClientAccent.withOpacity(0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.bolt_fill,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Действия с клиентом',
                      style: TextStyle(
                        color: kClientInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Начисления, списания, история и награды',
                      style: TextStyle(
                        color: kClientInkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  title: 'Начислить',
                  subtitle: 'баллы за чек',
                  icon: CupertinoIcons.plus_circle_fill,
                  colors: const [kClientGreen, kClientGreenSoft],
                  onTap: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => StaffClientAccrualScreen(
                          establishmentId: widget.establishmentId,
                          establishmentName: widget.establishmentName,
                          clientId: client.clientId,
                          clientName: client.displayName,
                          currentBalance: client.balance,
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  title: 'Списать',
                  subtitle: 'использовать баллы',
                  icon: CupertinoIcons.minus_circle_fill,
                  colors: const [kClientRed, kClientRedSoft],
                  onTap: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => StaffClientSpendScreen(
                          establishmentId: widget.establishmentId,
                          establishmentName: widget.establishmentName,
                          clientId: client.clientId,
                          clientName: client.displayName,
                          currentBalance: client.balance,
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  title: 'История',
                  subtitle: 'операции клиента',
                  icon: CupertinoIcons.clock_fill,
                  colors: const [kClientBlue, kClientViolet],
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => StaffClientHistoryScreen(
                          establishmentId: widget.establishmentId,
                          establishmentName: widget.establishmentName,
                          clientId: client.clientId,
                          clientName: client.displayName,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionTile(
                  title: 'Награды',
                  subtitle: 'купоны и бонусы',
                  icon: CupertinoIcons.gift_fill,
                  colors: const [kClientAccent, kClientAccentSoft],
                  onTap: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => StaffClientRewardsScreen(
                          establishmentId: widget.establishmentId,
                          establishmentName: widget.establishmentName,
                          clientId: client.clientId,
                          clientName: client.displayName,
                          currentBalance: client.balance,
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
'''

new_action_tile = r'''  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 24,
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.76),
          border: Border.all(color: Colors.white.withOpacity(0.90)),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -24,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.first.withOpacity(0.07),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.first.withOpacity(0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kClientInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kClientInkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
'''

# Если функции есть — заменить.
text2 = replace_widget_func(text, "_actionsCard", new_actions_card)
text2 = replace_widget_func(text2, "_actionTile", new_action_tile)

# Если _actionsCard не было, вставим перед _bigMetricCard или _detailLine.
if "_actionsCard()" not in text2:
    anchor = "  Widget _bigMetricCard({"
    if anchor not in text2:
        anchor = "  Widget _detailLine({"
    if anchor not in text2:
        raise SystemExit("ERROR: insert anchor not found for actions card")
    text2 = text2.replace(anchor, new_actions_card + "\n" + new_action_tile + "\n" + anchor, 1)

path.write_text(text2, encoding="utf-8")
print("OK: client actions visual block patched")
