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
import 'staff_client_spend_screen.dart';
import '../../data/staff_subscriptions_api.dart';

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

  final StaffSubscriptionsApi _subscriptionsApi = StaffSubscriptionsApi();
  List<StaffSubscription> _subscriptions = const [];
  bool _subscriptionsLoading = false;
  String? _subscriptionsError;
  int? _usingMenuItemId;

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
      _subscriptionsLoading = true;
      _subscriptionsError = null;
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

      List<StaffSubscription> subscriptions = const [];
      String? subscriptionsError;
      try {
        subscriptions = await _subscriptionsApi.getClientSubscriptions(
          establishmentId: widget.establishmentId,
          clientId: widget.clientId,
        );
      } catch (_) {
        subscriptionsError =
            'РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ Р°Р±РѕРЅРµРјРµРЅС‚С‹';
      }

      if (!mounted) return;
      setState(() {
        _client = _ClientDetail.fromJson(decoded);
        _subscriptions = subscriptions;
        _subscriptionsError = subscriptionsError;
        _subscriptionsLoading = false;
        _loading = false;
      });

      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'РќРµ СѓРґР°Р»РѕСЃСЊ Р·Р°РіСЂСѓР·РёС‚СЊ РєР»РёРµРЅС‚Р°';
      });
      _introController.forward(from: 0);
    }
  }

  Widget _stagger({required int index, required Widget child}) {
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
            child: Transform.scale(scale: 0.985 + (0.015 * t), child: child),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [Color(0xFF064E58), Color(0xFF078D95), Color(0xFF10B8A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kClientMintDeep.withOpacity(0.34),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -54,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -76,
            left: -58,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kClientAccent.withOpacity(0.18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(color: Colors.white.withOpacity(0.34)),
                    ),
                    child: Center(
                      child: Text(
                        client.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.24),
                            ),
                          ),
                          child: const Text(
                            'РљР›РР•РќРў',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          client.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.03,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.phone_fill,
                              color: Colors.white.withOpacity(0.78),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                client.phone ??
                                    'РўРµР»РµС„РѕРЅ РЅРµ СѓРєР°Р·Р°РЅ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Р‘Р°Р»Р»С‹',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      client.balanceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'РґРѕСЃС‚СѓРїРЅРѕ РґР»СЏ СЃРїРёСЃР°РЅРёСЏ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _clientCompactStat(
                      icon: CupertinoIcons.ticket_fill,
                      label: 'Р’РёР·РёС‚С‹',
                      value: client.visitsLabel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _clientCompactStat(
                      icon: CupertinoIcons.creditcard_fill,
                      label: 'РџРѕС‚СЂР°С‡РµРЅРѕ',
                      value: client.spentLabel,
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

  Widget _clientCompactStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: kClientMintDeep.withOpacity(0.08),
            ),
            child: Icon(icon, color: kClientMintDeep, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kClientInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kClientInkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
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
            child: Icon(icon, color: Colors.white, size: 19),
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
            child: Icon(icon, size: 18, color: kClientInk),
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
                      'Р”РµР№СЃС‚РІРёСЏ СЃ РєР»РёРµРЅС‚РѕРј',
                      style: TextStyle(
                        color: kClientInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'РќР°С‡РёСЃР»РµРЅРёРµ, СЃРїРёСЃР°РЅРёРµ Рё РёСЃС‚РѕСЂРёСЏ РѕРїРµСЂР°С†РёР№',
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
                  title: 'РќР°С‡РёСЃР»РёС‚СЊ',
                  subtitle: 'Р±Р°Р»Р»С‹ Р·Р° С‡РµРє',
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
                  title: 'РЎРїРёСЃР°С‚СЊ',
                  subtitle: 'РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ Р±Р°Р»Р»С‹',
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
            title: 'РСЃС‚РѕСЂРёСЏ РєР»РёРµРЅС‚Р°',
            subtitle:
                'Р’СЃРµ РЅР°С‡РёСЃР»РµРЅРёСЏ, СЃРїРёСЃР°РЅРёСЏ Рё РґРІРёР¶РµРЅРёСЏ РїРѕ РєР»РёРµРЅС‚Сѓ',
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
              child: Icon(icon, color: Colors.white, size: 23),
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
              child: Icon(icon, color: glow, size: 22),
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

  Future<void> _useSubscriptionItem({
    required StaffSubscription subscription,
    required StaffSubscriptionItem item,
  }) async {
    if (_usingMenuItemId != null || !item.canUse) return;

    final clientId = int.tryParse(widget.clientId);
    if (clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'РќРµ СѓРґР°Р»РѕСЃСЊ РѕРїСЂРµРґРµР»РёС‚СЊ РєР»РёРµРЅС‚Р°',
          ),
        ),
      );
      return;
    }

    final remainingAfter = subscription.isUnlimited
        ? null
        : ((subscription.remaining ?? 0) - item.quantityPerUse).clamp(
            0,
            double.infinity,
          );

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'РџРѕРґС‚РІРµСЂР¶РґРµРЅРёРµ СЃРїРёСЃР°РЅРёСЏ',
      barrierColor: Colors.black.withOpacity(0.58),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 350,
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6D4AFF),
                    Color(0xFF4B63E8),
                    Color(0xFF18AEB7),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.32),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D4AFF).withOpacity(0.40),
                    blurRadius: 38,
                    spreadRadius: 2,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.24),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.bolt_fill,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Text(
                          'РСЃРїРѕР»СЊР·РѕРІР°С‚СЊ Р°Р±РѕРЅРµРјРµРЅС‚',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    subscription.planName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.chart_bar_fill,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            subscription.isUnlimited
                                ? 'РџРѕСЃР»Рµ СЃРїРёСЃР°РЅРёСЏ Р»РёРјРёС‚ РЅРµ РёР·РјРµРЅРёС‚СЃСЏ'
                                : 'РџРѕСЃР»Рµ СЃРїРёСЃР°РЅРёСЏ РѕСЃС‚Р°РЅРµС‚СЃСЏ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          subscription.isUnlimited
                              ? 'в€ћ'
                              : (remainingAfter == null
                                    ? 'вЂ”'
                                    : (remainingAfter ==
                                              remainingAfter.roundToDouble()
                                          ? remainingAfter.toInt().toString()
                                          : remainingAfter.toStringAsFixed(2))),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.32),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: const Text(
                              'РћС‚РјРµРЅР°',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF5A47E8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            icon: const Icon(
                              CupertinoIcons.bolt_fill,
                              size: 18,
                            ),
                            label: const Text(
                              'РЎРїРёСЃР°С‚СЊ',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _usingMenuItemId = item.menuItemId);

    try {
      final result = await _subscriptionsApi.useItem(
        establishmentId: widget.establishmentId,
        clientId: clientId,
        subscriptionId: subscription.id,
        menuItemId: item.menuItemId,
        quantity: item.quantityPerUse,
      );

      if (!mounted) return;
      setState(() {
        final refreshed = result.subscription;
        if (refreshed != null) {
          _subscriptions = _subscriptions
              .map((e) => e.id == refreshed.id ? refreshed : e)
              .toList();
        }
        _usingMenuItemId = null;
      });

      HapticFeedback.mediumImpact();
      await _showSubscriptionSuccess(item.name);
    } catch (error) {
      if (!mounted) return;
      setState(() => _usingMenuItemId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kClientRed,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _showSubscriptionSuccess(String itemName) async {
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'РЈСЃРїРµС€РЅРѕРµ СЃРїРёСЃР°РЅРёРµ',
      barrierColor: Colors.black.withOpacity(0.48),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Future<void>.delayed(const Duration(milliseconds: 1450), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 286,
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF16C79A),
                    Color(0xFF12AFC0),
                    Color(0xFF5B4BFF),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.38),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF18D6AC).withOpacity(0.42),
                    blurRadius: 42,
                    spreadRadius: 4,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.35, end: 1),
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.48),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.22),
                            blurRadius: 26,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.check_mark,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'РЈСЃРїРµС€РЅРѕ СЃРїРёСЃР°РЅРѕ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    itemName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.84),
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 5,
                    width: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.20),
                          Colors.white,
                          Colors.white.withOpacity(0.20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.72, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsSection() {
    if (_subscriptionsLoading) {
      return const _GlassCard(
        radius: 28,
        padding: EdgeInsets.all(22),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(kClientViolet),
          ),
        ),
      );
    }

    if (_subscriptionsError != null) {
      return _GlassCard(
        radius: 28,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kClientRed.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: kClientRed,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _subscriptionsError!,
                style: const TextStyle(
                  color: kClientInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_subscriptions.isEmpty) return const SizedBox.shrink();

    final orderedSubscriptions = [..._subscriptions]
      ..sort((a, b) {
        int priority(StaffSubscription subscription) {
          final hasAvailableItem = subscription.items.any(
            (item) => item.canUse,
          );
          final exhausted =
              !subscription.isUnlimited && (subscription.remaining ?? 0) <= 0;

          if (subscription.status == 'active' &&
              hasAvailableItem &&
              !exhausted) {
            return 0;
          }
          if (subscription.status == 'active') return 1;
          if (subscription.status == 'paused') return 2;
          if (subscription.status == 'pending') return 3;
          return 4;
        }

        final byPriority = priority(a).compareTo(priority(b));
        if (byPriority != 0) return byPriority;
        return a.planName.compareTo(b.planName);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 11),
          child: Text(
            'РђР±РѕРЅРµРјРµРЅС‚С‹',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
        ...List.generate(orderedSubscriptions.length, (index) {
          final subscription = orderedSubscriptions[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == orderedSubscriptions.length - 1 ? 0 : 12,
            ),
            child: _SubscriptionCard(
              subscription: subscription,
              usingMenuItemId: _usingMenuItemId,
              onUseItem: (item) =>
                  _useSubscriptionItem(subscription: subscription, item: item),
            ),
          );
        }),
      ],
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
        title: 'РћС€РёР±РєР°',
        subtitle: _error!,
      );
    }

    if (_client == null) {
      return _stateCard(
        icon: CupertinoIcons.person_crop_circle_badge_xmark,
        title: 'РљР»РёРµРЅС‚ РЅРµ РЅР°Р№РґРµРЅ',
        subtitle:
            'РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ РґР°РЅРЅС‹Рµ РєР»РёРµРЅС‚Р°',
      );
    }

    return Column(
      children: [
        _stagger(index: 0, child: _topCard()),
        const SizedBox(height: 18),
        _stagger(index: 1, child: _buildSubscriptionsSection()),
        const SizedBox(height: 18),
        _stagger(index: 2, child: _buildActionSection()),
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
                      children: [_content()],
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
              colors: [kClientCardStrong, kClientCard],
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

  const _MiniGlyph({required this.icon, required this.color});

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
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _EmptyOrb extends StatelessWidget {
  final IconData icon;

  const _EmptyOrb({required this.icon});

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
            child: Icon(icon, color: kClientInkSoft, size: 28),
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

class _SubscriptionCard extends StatefulWidget {
  final StaffSubscription subscription;
  final int? usingMenuItemId;
  final ValueChanged<StaffSubscriptionItem> onUseItem;

  const _SubscriptionCard({
    required this.subscription,
    required this.usingMenuItemId,
    required this.onUseItem,
  });

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  String _date(DateTime? d) {
    if (d == null) return 'вЂ”';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  double get _progress {
    final limit = widget.subscription.usageLimit;
    if (widget.subscription.isUnlimited || limit == null || limit <= 0) {
      return 1;
    }
    return ((widget.subscription.remaining ?? 0).clamp(0, limit) / limit)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subscription;
    final active = s.status == 'active';
    final hasAvailableItem = s.items.any((item) => item.canUse);
    final exhausted = active && !s.isUnlimited && (s.remaining ?? 0) <= 0;
    final unavailable = !active || !hasAvailableItem || exhausted;

    final colors = exhausted
        ? const [Color(0xFF3D4654), Color(0xFF56606D), Color(0xFF39434B)]
        : active
        ? const [Color(0xFF5742E9), Color(0xFF8458FF), Color(0xFF19B6B5)]
        : const [Color(0xFF687078), Color(0xFF858B94), Color(0xFF56636A)];

    final statusText = exhausted
        ? 'Р›РёРјРёС‚ РёСЃС‡РµСЂРїР°РЅ'
        : !hasAvailableItem && active
        ? 'РЎРµР№С‡Р°СЃ РЅРµРґРѕСЃС‚СѓРїРµРЅ'
        : s.statusLabel;

    final unavailableText = exhausted
        ? 'Р’СЃРµ РёСЃРїРѕР»СЊР·РѕРІР°РЅРёСЏ РїРѕ СЌС‚РѕРјСѓ Р°Р±РѕРЅРµРјРµРЅС‚Сѓ СѓР¶Рµ РёР·СЂР°СЃС…РѕРґРѕРІР°РЅС‹'
        : s.status == 'paused'
        ? 'РђР±РѕРЅРµРјРµРЅС‚ РІСЂРµРјРµРЅРЅРѕ РїСЂРёРѕСЃС‚Р°РЅРѕРІР»РµРЅ'
        : s.status == 'pending'
        ? 'РђР±РѕРЅРµРјРµРЅС‚ РµС‰С‘ РЅРµ РЅР°С‡Р°Р» РґРµР№СЃС‚РІРѕРІР°С‚СЊ'
        : s.status == 'expired'
        ? 'РЎСЂРѕРє РґРµР№СЃС‚РІРёСЏ Р°Р±РѕРЅРµРјРµРЅС‚Р° Р·Р°РєРѕРЅС‡РёР»СЃСЏ'
        : s.status == 'cancelled'
        ? 'РђР±РѕРЅРµРјРµРЅС‚ РѕС‚РјРµРЅС‘РЅ'
        : 'РЎРїРёСЃР°РЅРёРµ СЃРµР№С‡Р°СЃ РЅРµРґРѕСЃС‚СѓРїРЅРѕ';

    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, child) {
        final t = _shineController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colors[1].withOpacity(unavailable ? 0.12 : 0.30),
                blurRadius: unavailable ? 18 : 30,
                spreadRadius: unavailable ? 0 : 1,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment(-1 + t * .35, -1),
                      end: Alignment(1, 1 - t * .25),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expanded = !_expanded);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(21),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.16),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(.22),
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.rectangle_stack_fill,
                                    color: Colors.white,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.planName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          height: 1.05,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.35,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.78),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _expanded ? .5 : 0,
                                  duration: const Duration(milliseconds: 280),
                                  child: const Icon(
                                    CupertinoIcons.chevron_down,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exhausted
                                            ? 'РЎС‚Р°С‚СѓСЃ'
                                            : (s.isUnlimited
                                                  ? 'Р”РѕСЃС‚СѓРїРЅРѕ'
                                                  : 'РћСЃС‚Р°Р»РѕСЃСЊ'),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.72),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        exhausted
                                            ? 'РСЃРїРѕР»СЊР·РѕРІР°РЅ'
                                            : s.remainingLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 29,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'РґРѕ ${_date(s.endsAt)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.78),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                height: 7,
                                color: Colors.white.withOpacity(.16),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress.clamp(0, 1),
                                  child: Container(color: Colors.white),
                                ),
                              ),
                            ),
                            if (unavailable) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      exhausted
                                          ? CupertinoIcons
                                                .check_mark_circled_solid
                                          : CupertinoIcons
                                                .exclamationmark_circle_fill,
                                      color: Colors.white.withOpacity(0.86),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        unavailableText,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.78),
                                          fontSize: 11.5,
                                          height: 1.25,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            AnimatedSize(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              child: !_expanded
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Column(
                                        children: [
                                          Divider(
                                            color: Colors.white.withOpacity(
                                              .20,
                                            ),
                                          ),
                                          ...s.items.map((item) {
                                            final loading =
                                                widget.usingMenuItemId ==
                                                item.menuItemId;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 9,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(.11),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(.16),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item.name,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: 36,
                                                      child: FilledButton(
                                                        onPressed:
                                                            item.canUse &&
                                                                !loading
                                                            ? () => widget
                                                                  .onUseItem(
                                                                    item,
                                                                  )
                                                            : null,
                                                        style:
                                                            FilledButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.white,
                                                              foregroundColor:
                                                                  colors[0],
                                                            ),
                                                        child: loading
                                                            ? const SizedBox(
                                                                width: 17,
                                                                height: 17,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                              )
                                                            : Text(
                                                                item.canUse
                                                                    ? 'РЎРїРёСЃР°С‚СЊ'
                                                                    : exhausted
                                                                    ? 'РСЃРїРѕР»СЊР·РѕРІР°РЅ'
                                                                    : 'РќРµРґРѕСЃС‚СѓРїРЅРѕ',
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  left: -110 + t * 420,
                  child: Transform.rotate(
                    angle: -.42,
                    child: Container(
                      width: 90,
                      height: 380,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(active ? .13 : .05),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      fullName:
          json['full_name']?.toString() ??
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
        json['visits_count'] ??
            json['visits'] ??
            json['client_visits'] ??
            json['visit_count'],
      ),
      totalSpent: parseNum(
        json['total_spent'] ??
            json['sales_total'] ??
            json['client_total_spent'],
      ),
    );
  }

  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'РљР»РёРµРЅС‚';
  }

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'C';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
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
  static String _formatMoney(double value) {
    final rounded = value.round();
    final raw = rounded.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final left = raw.length - i;
      buffer.write(raw[i]);
      if (left > 1 && left % 3 == 1) {
        buffer.write(' ');
      }
    }

    return buffer.toString();
  }

  String get spentLabel => '${_formatMoney(totalSpent)} в‚Ѕ';
}
