import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';

const Color kHistMintTop = Color(0xFF0CB7B3);
const Color kHistMintMid = Color(0xFF08A9AB);
const Color kHistMintBottom = Color(0xFF067D87);
const Color kHistMintDeep = Color(0xFF055E66);

const Color kHistAccent = Color(0xFFFFA11D);
const Color kHistAccentSoft = Color(0xFFFFC45E);

const Color kHistCard = Color(0xCCFFFFFF);
const Color kHistCardStrong = Color(0xE8FFFFFF);
const Color kHistStroke = Color(0xA6FFFFFF);

const Color kHistInk = Color(0xFF103238);
const Color kHistInkSoft = Color(0xFF58767D);
const Color kHistShadow = Color(0x22062E36);

const Color kHistBlue = Color(0xFF4E7CFF);
const Color kHistPink = Color(0xFFFF5F8F);
const Color kHistViolet = Color(0xFF7A63FF);

class StaffEstablishmentHistoryScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffEstablishmentHistoryScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffEstablishmentHistoryScreen> createState() =>
      _StaffEstablishmentHistoryScreenState();
}

class _StaffEstablishmentHistoryScreenState
    extends State<StaffEstablishmentHistoryScreen> with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<_EstablishmentHistoryItem> _items = [];

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
        '${AppConfig.baseUrl}/api/v1/staff/establishment/history?establishment_id=${widget.establishmentId}',
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
          'establishment history failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else {
        raw = [];
      }

      if (!mounted) return;

      setState(() {
        _items = raw
            .map(
              (e) =>
                  _EstablishmentHistoryItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        _loading = false;
      });

      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить историю заведения';
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
                    kHistMintTop,
                    kHistMintMid,
                    kHistMintBottom,
                    kHistMintDeep,
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
                    kHistAccent.withOpacity(0.12),
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
                    kHistBlue.withOpacity(0.07),
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
                    kHistAccentSoft.withOpacity(0.10),
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

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'accrual':
      case 'visit':
      case 'earn':
        return kHistBlue;
      case 'spend':
      case 'redeem':
      case 'write_off':
        return kHistPink;
      default:
        return kHistViolet;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accrual':
      case 'visit':
      case 'earn':
        return CupertinoIcons.plus_circle_fill;
      case 'spend':
      case 'redeem':
      case 'write_off':
        return CupertinoIcons.minus_circle_fill;
      default:
        return CupertinoIcons.clock_fill;
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'accrual':
        return 'Начисление';
      case 'spend':
        return 'Списание';
      case 'visit':
        return 'Визит';
      case 'redeem':
        return 'Погашение';
      case 'earn':
        return 'Начисление';
      default:
        return type.isEmpty ? 'Операция' : type;
    }
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$dd.$mm • $hh:$mi';
    } catch (_) {
      return value;
    }
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
              color: kHistInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: kHistInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(_EstablishmentHistoryItem item) {
    final color = _typeColor(item.operationType);

    return _GlassCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryGlyph(
            icon: _typeIcon(item.operationType),
            color: color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(item.operationType),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: kHistInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.amountLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (item.clientLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.clientLabel,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: kHistInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (item.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.comment,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: kHistInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: kHistInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHistMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'История заведения',
          style: TextStyle(
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
                          valueColor: AlwaysStoppedAnimation(kHistViolet),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: kHistViolet,
                      backgroundColor: Colors.white,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (_error != null)
                            _stagger(
                              index: 0,
                              child: _stateCard(
                                icon: CupertinoIcons.exclamationmark_circle_fill,
                                title: 'Ошибка',
                                subtitle: _error!,
                              ),
                            )
                          else if (_items.isEmpty)
                            _stagger(
                              index: 0,
                              child: _stateCard(
                                icon: CupertinoIcons.time_solid,
                                title: 'История пока пустая',
                                subtitle: 'По заведению ещё нет операций',
                              ),
                            )
                          else
                            ..._items.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _stagger(
                                  index: entry.key,
                                  child: _itemCard(entry.value),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                kHistCardStrong,
                kHistCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kHistStroke),
            boxShadow: [
              BoxShadow(
                color: kHistShadow.withOpacity(0.10),
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

class _FloatingGlyph extends StatelessWidget {
  final IconData icon;
  final Color mainColor;
  final Color secondaryColor;
  final double size;
  final double iconSize;

  const _FloatingGlyph({
    required this.icon,
    required this.mainColor,
    required this.secondaryColor,
    this.size = 76,
    this.iconSize = 34,
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
                  mainColor.withOpacity(0.22),
                  secondaryColor.withOpacity(0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.86),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.54,
            height: size * 0.54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [mainColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Positioned(
            top: size * 0.11,
            right: size * 0.14,
            child: Container(
              width: size * 0.14,
              height: size * 0.14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryGlyph extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _HistoryGlyph({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.22),
                  color.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ],
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
                  kHistBlue.withOpacity(0.18),
                  kHistViolet.withOpacity(0.10),
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
              color: kHistInkSoft,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstablishmentHistoryItem {
  final String id;
  final String operationType;
  final double amount;
  final String comment;
  final String createdAt;
  final String clientName;
  final String clientPhone;

  _EstablishmentHistoryItem({
    required this.id,
    required this.operationType,
    required this.amount,
    required this.comment,
    required this.createdAt,
    required this.clientName,
    required this.clientPhone,
  });

  factory _EstablishmentHistoryItem.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _EstablishmentHistoryItem(
      id: json['id']?.toString() ?? '',
      operationType:
          json['operation_type']?.toString() ?? json['type']?.toString() ?? '',
      amount: parseNum(json['amount']),
      comment: json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      clientName:
          json['client_name']?.toString() ?? json['full_name']?.toString() ?? '',
      clientPhone:
          json['client_phone']?.toString() ?? json['phone']?.toString() ?? '',
    );
  }

  String get amountLabel {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  String get clientLabel {
    final name = clientName.trim();
    final phone = clientPhone.trim();
    if (name.isNotEmpty && phone.isNotEmpty) return '$name • $phone';
    if (name.isNotEmpty) return name;
    if (phone.isNotEmpty) return phone;
    return '';
  }
}