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
        throw Exception('detail failed: ${response.statusCode} ${response.body}');
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
            child: child,
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
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -8,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kClientAccent.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -16,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kClientMintTop.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 86,
                height: 86,
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
                child: Center(
                  child: Container(
                    width: 62,
                    height: 62,
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
                        client.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                client.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: kClientInk,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                client.phone ?? 'Телефон не указан',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kClientInkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    final client = _client!;
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: 'Баланс',
            value: client.balanceLabel,
            icon: CupertinoIcons.star_fill,
            glow: kClientBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: 'Визиты',
            value: client.visitsLabel,
            icon: CupertinoIcons.ticket_fill,
            glow: kClientPink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: 'Потрачено',
            value: client.spentLabel,
            icon: CupertinoIcons.creditcard_fill,
            glow: kClientViolet,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color glow,
  }) {
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _MiniGlyph(
            icon: icon,
            color: glow,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kClientInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: kClientInkSoft,
            ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
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
      borderRadius: 24,
      child: _GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(18),
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
        const SizedBox(height: 14),
        _stagger(index: 1, child: _metrics()),
        const SizedBox(height: 18),
        _stagger(
          index: 2,
          child: _actionButton(
            title: 'Начислить',
            subtitle: 'Провести покупку и начислить по логике лояльности',
            icon: CupertinoIcons.plus_circle_fill,
            colors: const [kClientBlue, kClientViolet],
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaffClientAccrualScreen(
                    establishmentId: widget.establishmentId,
                    establishmentName: widget.establishmentName,
                    clientId: widget.clientId,
                    clientName: _client!.displayName,
                  ),
                ),
              );
              _load();
            },
          ),
        ),
        const SizedBox(height: 12),
        _stagger(
          index: 3,
          child: _actionButton(
            title: 'Списать',
            subtitle: 'Проверить доступное списание и провести оплату',
            icon: CupertinoIcons.minus_circle_fill,
            colors: const [kClientPink, kClientViolet],
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaffClientSpendScreen(
                    establishmentId: widget.establishmentId,
                    establishmentName: widget.establishmentName,
                    clientId: widget.clientId,
                    clientName: _client!.displayName,
                  ),
                ),
              );
              _load();
            },
          ),
        ),
        const SizedBox(height: 12),
        _stagger(
          index: 4,
          child: _softActionTile(
            title: 'История клиента',
            subtitle: 'Посмотреть все операции и движения по клиенту',
            icon: CupertinoIcons.time_solid,
            glow: kClientBlue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaffClientHistoryScreen(
                    establishmentId: widget.establishmentId,
                    establishmentName: widget.establishmentName,
                    clientId: widget.clientId,
                    clientName: _client!.displayName,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _stagger(
          index: 5,
          child: _softActionTile(
            title: 'Награды',
            subtitle: 'Доступные подарки и выдача награды клиенту',
            icon: CupertinoIcons.gift_fill,
            glow: kClientPink,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaffClientRewardsScreen(
                    establishmentId: widget.establishmentId,
                    establishmentName: widget.establishmentName,
                    clientId: widget.clientId,
                    clientName: _client!.displayName,
                  ),
                ),
              );
            },
          ),
        ),
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
    final parts = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
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