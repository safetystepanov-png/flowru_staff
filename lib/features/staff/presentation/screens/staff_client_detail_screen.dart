import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import 'staff_client_accrual_screen.dart';
import 'staff_client_history_screen.dart';
import 'staff_client_rewards_screen.dart';
import 'staff_client_spend_screen.dart';

const Color kClientMintTop = Color(0xFF0CB7B3);
const Color kClientMintMid = Color(0xFF08A9AB);
const Color kClientMintBottom = Color(0xFF067D87);
const Color kClientMintDeep = Color(0xFF055E66);

const Color kClientAccent = Color(0xFFFFA11D);
const Color kClientAccentSoft = Color(0xFFFFC45E);

const Color kClientCard = Color(0xCCFFFFFF);
const Color kClientCardStrong = Color(0xE8FFFFFF);
const Color kClientStroke = Color(0xA6FFFFFF);

const Color kClientInk = Color(0xFF103238);
const Color kClientInkSoft = Color(0xFF58767D);
const Color kClientShadow = Color(0x22062E36);

const Color kClientBlue = Color(0xFF4E7CFF);
const Color kClientPink = Color(0xFFFF5F8F);
const Color kClientViolet = Color(0xFF7A63FF);
const Color kClientGreen = Color(0xFF12B886);
const Color kClientGreenSoft = Color(0xFF38D9A9);
const Color kClientRed = Color(0xFFFF6B6B);
const Color kClientRedSoft = Color(0xFFFF8787);

class StaffClientDetailScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;

  const StaffClientDetailScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
  });

  @override
  State<StaffClientDetailScreen> createState() =>
      _StaffClientDetailScreenState();
}

class _StaffClientDetailScreenState extends State<StaffClientDetailScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  _ClientDetail? _client;

  late final AnimationController _bgController;
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _load();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/clients/detail?client_id=${Uri.encodeQueryComponent(widget.clientId)}&establishment_id=${widget.establishmentId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'detail failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _client = _ClientDetail.fromJson(decoded);
        _loading = false;
      });

      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить клиента';
      });
      _introController.forward(from: 0);
    }
  }

  Widget _stagger({
    required int index,
    required Widget child,
  }) {
    final start = (index * 0.08).clamp(0.0, 0.82);
    final end = (start + 0.24).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - t)),
            child: Transform.scale(
              scale: 0.985 + (0.015 * t),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _softBlob({
    required double width,
    required double height,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 12;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kClientMintTop,
                    kClientMintMid,
                    kClientMintBottom,
                    kClientMintDeep,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.40, 0.78, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.07),
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -84 + shiftA,
              right: -36,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 280,
                  height: 280,
                  colors: [
                    Colors.white.withOpacity(0.16),
                    kClientAccent.withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -64,
              top: 210 + shiftB,
              child: Transform.rotate(
                angle: -rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    kClientBlue.withOpacity(0.07),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 48 - shiftA,
              right: -18,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kClientAccentSoft.withOpacity(0.10),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topCard() {
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
  }



  Widget _bigMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.94),
            Colors.white.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.96)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.22),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 19,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              height: 1.0,
              fontWeight: FontWeight.w900,
              color: kClientInk,
              letterSpacing: -0.55,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: kClientInk,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              color: kClientInkSoft,
            ),
          ),
        ],
      ),
    );
  }



  Widget _detailLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.74),
        border: Border.all(color: Colors.white.withOpacity(0.84)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kClientBlue.withOpacity(0.16),
                  kClientViolet.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: kClientInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kClientInkSoft,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: kClientInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
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
  }



  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 28,
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.94),
              Colors.white.withOpacity(0.80),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.96)),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(0.26),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kClientInk,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.25,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kClientInkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _softActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 28,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.94),
              Colors.white.withOpacity(0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.96)),
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: glow.withOpacity(0.13),
              ),
              child: Icon(
                icon,
                color: glow,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kClientInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kClientInkSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: kClientInk.withOpacity(0.045),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                color: kClientInkSoft,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _stateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          _EmptyOrb(icon: icon),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kClientInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: kClientInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_error != null) {
      return _stateCard(
        icon: CupertinoIcons.exclamationmark_circle_fill,
        title: 'Ошибка',
        subtitle: _error!,
      );
    }

    if (_client == null) {
      return _stateCard(
        icon: CupertinoIcons.person_crop_circle_badge_xmark,
        title: 'Клиент не найден',
        subtitle: 'Не удалось получить данные клиента',
      );
    }

    return Column(
      children: [
        _stagger(index: 0, child: _topCard()),
        const SizedBox(height: 18),
        _stagger(index: 1, child: _buildActionSection()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kClientMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.establishmentName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              top: false,
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(kClientViolet),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _content(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _GlassCard({
    required this.child,
    required this.padding,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [
                kClientCardStrong,
                kClientCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kClientStroke),
            boxShadow: [
              BoxShadow(
                color: kClientShadow.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MiniGlyph extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniGlyph({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.14),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }
}

class _EmptyOrb extends StatelessWidget {
  final IconData icon;

  const _EmptyOrb({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kClientBlue.withOpacity(0.18),
                  kClientViolet.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
            ),
            child: Icon(
              icon,
              color: kClientInkSoft,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarGlyph extends StatelessWidget {
  final String initials;
  final double size;
  final double innerSize;
  final double fontSize;

  const _AvatarGlyph({
    required this.initials,
    this.size = 86,
    this.innerSize = 62,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kClientBlue.withOpacity(0.22),
                  kClientPink.withOpacity(0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [kClientBlue, kClientPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
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

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _tap,
      child: AnimatedScale(
        scale: _pressed ? 0.982 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ClientDetail {
  final String clientId;
  final String? fullName;
  final String? phone;
  final double balance;
  final int visits;
  final double totalSpent;

  _ClientDetail({
    required this.clientId,
    required this.fullName,
    required this.phone,
    required this.balance,
    required this.visits,
    required this.totalSpent,
  });

  factory _ClientDetail.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return _ClientDetail(
      clientId: json['client_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ??
          json['name']?.toString() ??
          json['display_name']?.toString(),
      phone: json['phone']?.toString(),
      balance: parseNum(
        json['balance'] ??
            json['client_balance'] ??
            json['points_balance'] ??
            json['bonuses_balance'],
      ),
      visits: parseInt(
        json['visits'] ?? json['client_visits'] ?? json['visits_count'],
      ),
      totalSpent: parseNum(
        json['total_spent'] ?? json['client_total_spent'],
      ),
    );
  }

  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Клиент';
  }

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'C';
    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    final first = parts.first.isNotEmpty ? parts.first[0] : 'C';
    if (parts.length == 1) return first.toUpperCase();
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get balanceLabel {
    if (balance == balance.roundToDouble()) return balance.toInt().toString();
    return balance.toStringAsFixed(2);
  }

  String get visitsLabel => visits.toString();

  String get spentLabel => '${totalSpent.toStringAsFixed(0)} ₽';
}
