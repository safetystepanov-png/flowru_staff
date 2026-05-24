from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_client_detail_screen.dart")
text = path.read_text(encoding="utf-8")

def replace_func(src: str, func_name: str, new_func: str) -> str:
    start = src.find(f"  Widget {func_name}(")
    if start < 0:
        raise SystemExit(f"ERROR: function {func_name} not found")

    next_start = src.find("\n  Widget ", start + 1)
    if next_start < 0:
        next_start = src.find("\n  Future<", start + 1)
    if next_start < 0:
        raise SystemExit(f"ERROR: next function after {func_name} not found")

    return src[:start] + new_func + "\n" + src[next_start:]


new_top_card = r'''  Widget _topCard() {
    final client = _client!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.88),
                Colors.white.withOpacity(0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.92)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -72,
                right: -56,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kClientAccent.withOpacity(0.22),
                        kClientAccent.withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -86,
                left: -70,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kClientBlue.withOpacity(0.17),
                        kClientViolet.withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AvatarGlyph(
                          initials: client.initials,
                          size: 78,
                          innerSize: 56,
                          fontSize: 21,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: const LinearGradient(
                                      colors: [kClientAccent, kClientAccentSoft],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kClientAccent.withOpacity(0.22),
                                        blurRadius: 12,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
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
                                    letterSpacing: -0.9,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.phone_fill,
                                      size: 15,
                                      color: kClientInkSoft.withOpacity(0.92),
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
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            color: Colors.white.withOpacity(0.66),
                            border: Border.all(color: Colors.white.withOpacity(0.80)),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
'''

new_metric_card = r'''  Widget _bigMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.74),
        border: Border.all(color: Colors.white.withOpacity(0.88)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: kClientInk,
              letterSpacing: -0.5,
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
  }
'''

text = replace_func(text, "_topCard", new_top_card)
text = replace_func(text, "_bigMetricCard", new_metric_card)

path.write_text(text, encoding="utf-8")
print("OK: client top card visually redesigned")
