from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_client_detail_screen.dart")
text = path.read_text(encoding="utf-8")

def replace_func(src: str, signature: str, end_signatures: list[str], new_func: str) -> str:
    start = src.find(signature)
    if start < 0:
        raise SystemExit(f"ERROR: start not found: {signature}")

    ends = []
    for sig in end_signatures:
        pos = src.find(sig, start + len(signature))
        if pos >= 0:
            ends.append(pos)

    if not ends:
        raise SystemExit(f"ERROR: end not found after: {signature}")

    end = min(ends)
    return src[:start] + new_func + "\n\n" + src[end:]


# 1. Убираем битые строки по всему файлу.
text = text.replace("_error = 'РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РєР»РёРµРЅС‚Р°';", "_error = 'Не удалось загрузить клиента';")
text = text.replace("'РљРђР РўРђ РљР›РР•РќРўРђ'", "'КЛИЕНТ'")
text = text.replace("'РљРђР РўРђ РљР›Р˜Р•РќРўРђ'", "'КЛИЕНТ'")
text = text.replace("'РўРµР»РµС„РѕРЅ РЅРµ СѓРєР°Р·Р°РЅ'", "'Телефон не указан'")
text = text.replace("'Р‘Р°Р»Р°РЅСЃ'", "'Баланс'")
text = text.replace("'РґРѕСЃС‚СѓРїРЅРѕ'", "'баллов'")
text = text.replace("'Р’РёР·РёС‚С‹'", "'Визиты'")
text = text.replace("'РІСЃРµРіРѕ'", "'всего'")
text = text.replace("'РџРѕС‚СЂР°С‡РµРЅРѕ'", "'Потрачено'")
text = text.replace("'СЃСѓРјРјР°'", "'сумма'")
text = text.replace("'РўРµР»РµС„РѕРЅ'", "'Телефон'")
text = text.replace("return 'РљР»РёРµРЅС‚';", "return 'Клиент';")
text = text.replace("String get spentLabel => '${totalSpent.toStringAsFixed(0)} в‚Ѕ';", "String get spentLabel => '${totalSpent.toStringAsFixed(0)} ₽';")

# 2. Полностью заменяем верхнюю карточку клиента.
new_top_card = r'''  Widget _topCard() {
    final client = _client!;

    return _GlassCard(
      radius: 32,
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kClientAccent.withOpacity(0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kClientBlue.withOpacity(0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AvatarGlyph(
                    initials: client.initials,
                    size: 76,
                    innerSize: 54,
                    fontSize: 21,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: [kClientAccent, kClientAccentSoft],
                            ),
                          ),
                          child: const Text(
                            'КЛИЕНТ',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          client.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            color: kClientInk,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.phone_fill,
                              size: 15,
                              color: kClientInkSoft.withOpacity(0.95),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                client.phone ?? 'Телефон не указан',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: kClientInkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: Colors.white.withOpacity(0.66),
                      border: Border.all(color: Colors.white.withOpacity(0.85)),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_crop_circle_fill,
                      size: 27,
                      color: kClientInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _bigMetricCard(
                      title: 'Баланс',
                      value: client.balanceLabel,
                      subtitle: 'баллов',
                      icon: CupertinoIcons.star_fill,
                      colors: const [kClientBlue, kClientViolet],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _bigMetricCard(
                      title: 'Визиты',
                      value: client.visitsLabel,
                      subtitle: 'всего',
                      icon: CupertinoIcons.ticket_fill,
                      colors: const [kClientPink, kClientViolet],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _bigMetricCard(
                      title: 'Потрачено',
                      value: client.spentLabel,
                      subtitle: 'сумма',
                      icon: CupertinoIcons.creditcard_fill,
                      colors: const [Color(0xFF10B8A5), Color(0xFF4E7CFF)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }'''

text = replace_func(
    text,
    "  Widget _topCard() {",
    ["\n  Widget _bigMetricCard({"],
    new_top_card,
)

# 3. Метрики делаем светлыми, без тяжёлых цветных блоков и overflow.
new_metric = r'''  Widget _bigMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.76),
        border: Border.all(color: Colors.white.withOpacity(0.92)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.09),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 15,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: kClientInk,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: kClientInk,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: kClientInkSoft,
            ),
          ),
        ],
      ),
    );
  }'''

text = replace_func(
    text,
    "  Widget _bigMetricCard({",
    ["\n  Widget _detailLine({", "\n  Widget _buildActionSection() {"],
    new_metric,
)

# 4. Полностью заменяем блок действий. Награды удалены.
new_actions = r'''  Widget _buildActionSection() {
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
                      'Начисление, списание и история операций',
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
                child: _actionButton(
                  title: 'Начислить',
                  subtitle: 'баллы за чек',
                  icon: CupertinoIcons.plus_circle_fill,
                  colors: const [kClientGreen, kClientGreenSoft],
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StaffClientAccrualScreen(
                          establishmentId: widget.establishmentId,
                          establishmentName: widget.establishmentName,
                          clientId: widget.clientId,
                          clientName: client.displayName,
                        ),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  title: 'Списать',
                  subtitle: 'использовать баллы',
                  icon: CupertinoIcons.minus_circle_fill,
                  colors: const [kClientRed, kClientRedSoft],
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StaffClientSpendScreen(
                          establishmentId: widget.establishmentId,
                          establishmentName: widget.establishmentName,
                          clientId: widget.clientId,
                          clientName: client.displayName,
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
          _softActionTile(
            title: 'История клиента',
            subtitle: 'Все начисления, списания и движения по клиенту',
            icon: CupertinoIcons.clock_fill,
            glow: kClientBlue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaffClientHistoryScreen(
                    establishmentId: widget.establishmentId,
                    establishmentName: widget.establishmentName,
                    clientId: widget.clientId,
                    clientName: client.displayName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }'''

text = replace_func(
    text,
    "  Widget _buildActionSection() {",
    ["\n  Widget _actionButton({"],
    new_actions,
)

# 5. Меняем вид большой кнопки действия на стеклянный стиль.
new_action_button = r'''  Widget _actionButton({
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
  }'''

text = replace_func(
    text,
    "  Widget _actionButton({",
    ["\n  Widget _softActionTile({"],
    new_action_button,
)

# 6. Мягкая строка истории.
new_soft_tile = r'''  Widget _softActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.76),
          border: Border.all(color: Colors.white.withOpacity(0.90)),
        ),
        child: Row(
          children: [
            _MiniGlyph(
              icon: icon,
              color: glow,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: kClientInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kClientInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: kClientInk,
            ),
          ],
        ),
      ),
    );
  }'''

text = replace_func(
    text,
    "  Widget _softActionTile({",
    ["\n  Widget _stateCard({"],
    new_soft_tile,
)

# 7. Чиним ошибки/пустые состояния.
text = text.replace("title: 'РћС€РёР±РєР°',", "title: 'Ошибка',")
text = text.replace("title: 'РљР»РёРµРЅС‚ РЅРµ РЅР°Р№РґРµРЅ',", "title: 'Клиент не найден',")
text = text.replace("subtitle: 'РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ РґР°РЅРЅС‹Рµ РєР»РёРµРЅС‚Р°',", "subtitle: 'Не удалось получить данные клиента',")

path.write_text(text, encoding="utf-8")
print("OK: client detail screen cleaned, rewards removed, visual updated")
