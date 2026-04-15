import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';

const Color kAccrualMintTop = Color(0xFF0CB7B3);
const Color kAccrualMintMid = Color(0xFF08A9AB);
const Color kAccrualMintBottom = Color(0xFF067D87);
const Color kAccrualMintDeep = Color(0xFF055E66);

const Color kAccrualAccent = Color(0xFFFFA11D);
const Color kAccrualAccentSoft = Color(0xFFFFC45E);

const Color kAccrualCard = Color(0xCCFFFFFF);
const Color kAccrualCardStrong = Color(0xE8FFFFFF);
const Color kAccrualStroke = Color(0xA6FFFFFF);

const Color kAccrualInk = Color(0xFF103238);
const Color kAccrualInkSoft = Color(0xFF58767D);
const Color kAccrualShadow = Color(0x22062E36);

const Color kAccrualBlue = Color(0xFF4E7CFF);
const Color kAccrualPink = Color(0xFFFF5F8F);
const Color kAccrualViolet = Color(0xFF7A63FF);

class StaffClientAccrualScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffClientAccrualScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<StaffClientAccrualScreen> createState() =>
      _StaffClientAccrualScreenState();
}

class _StaffClientAccrualScreenState extends State<StaffClientAccrualScreen>
    with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  _LoyaltyConfig? _config;
  _AccrualPreview? _preview;

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

    _loadConfig();
    _amountController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  double _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/loyalty/config?establishment_id=${widget.establishmentId}&client_id=${Uri.encodeQueryComponent(widget.clientId)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('config failed: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _config = _LoyaltyConfig.fromJson(decoded);
        _loading = false;
      });

      _recalculate();
      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить настройки лояльности';
      });
      _introController.forward(from: 0);
    }
  }

  void _recalculate() {
    final config = _config;
    if (config == null) return;

    final amount = _parseAmount();
    if (amount <= 0) {
      setState(() {
        _preview = null;
      });
      return;
    }

    double added = 0;
    String label = '';

    if (config.mode == 'points') {
      if (config.accrualType == 'fixed' || config.fixedPointsPerPurchase > 0) {
        added = config.fixedPointsPerPurchase.toDouble();
        label = 'Фиксированное начисление';
      } else {
        final per100 = config.pointsPer100Rub;
        added = (amount / 100.0) * per100;
        added = added.floorToDouble();
        label = '$per100 баллов за 100 ₽';
      }
    } else if (config.mode == 'cashback') {
      final percent = config.activeCashbackPercent;
      added = amount * percent / 100.0;
      added = double.parse(added.toStringAsFixed(2));
      label = 'Кешбэк $percent%';
    } else {
      added = 0;
      label = 'Начисление не используется';
    }

    setState(() {
      _preview = _AccrualPreview(
        checkAmount: amount,
        added: added,
        label: label,
      );
    });
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (preview == null || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/accrual'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'client_id': widget.clientId,
          'amount': preview.checkAmount,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'accrual failed: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.96)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EmptyOrb(
                      icon: CupertinoIcons.check_mark_circled_solid,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Готово',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kAccrualInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      decoded['message']?.toString() ?? 'Начисление выполнено',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: kAccrualInkSoft,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [kAccrualBlue, kAccrualViolet],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(this.context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выполнить начисление';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
                    kAccrualMintTop,
                    kAccrualMintMid,
                    kAccrualMintBottom,
                    kAccrualMintDeep,
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
                    kAccrualAccent.withOpacity(0.12),
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
                    kAccrualBlue.withOpacity(0.07),
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
                    kAccrualAccentSoft.withOpacity(0.10),
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

  Widget _headerCard() {
    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const _FloatingGlyph(
            icon: CupertinoIcons.plus_circle_fill,
            mainColor: kAccrualBlue,
            secondaryColor: kAccrualViolet,
            size: 82,
            iconSize: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clientName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kAccrualInk,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.establishmentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kAccrualInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCard() {
    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сумма чека',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: kAccrualInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Введи фактическую сумму покупки',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kAccrualInkSoft,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withOpacity(0.92),
              border: Border.all(color: const Color(0xFFE7EEF0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: kAccrualInk,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                hintText: 'Например 1250',
                hintStyle: TextStyle(
                  color: kAccrualInkSoft,
                  fontWeight: FontWeight.w700,
                ),
                suffixText: '₽',
                suffixStyle: TextStyle(
                  color: kAccrualInkSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final preview = _preview;
    final config = _config;

    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Предпросмотр',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: kAccrualInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Что произойдёт после начисления',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kAccrualInkSoft,
            ),
          ),
          const SizedBox(height: 14),
          _line('Клиент', widget.clientName),
          _line('Режим', config?.modeLabel ?? '—'),
          _line(
            'Чек',
            preview != null ? '${preview.checkAmount.toStringAsFixed(0)} ₽' : '—',
          ),
          _line('Логика', preview?.label ?? '—'),
          _line('Начислится', preview != null ? preview.addedLabel : '—'),
        ],
      ),
    );
  }

  Widget _line(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: kAccrualInkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kAccrualInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    if (_error == null) return const SizedBox.shrink();

    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Color(0xFFE85B63),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB84C4C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [kAccrualBlue, kAccrualViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: kAccrualBlue.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_preview == null || _saving) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Начислить',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccrualMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Начисление',
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
                          valueColor: AlwaysStoppedAnimation(kAccrualViolet),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _stagger(index: 0, child: _headerCard()),
                        const SizedBox(height: 14),
                        _stagger(index: 1, child: _amountCard()),
                        const SizedBox(height: 14),
                        _stagger(index: 2, child: _previewCard()),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _stagger(index: 3, child: _errorCard()),
                        ],
                        const SizedBox(height: 18),
                        _stagger(index: 4, child: _submitButton()),
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
                kAccrualCardStrong,
                kAccrualCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kAccrualStroke),
            boxShadow: [
              BoxShadow(
                color: kAccrualShadow.withOpacity(0.10),
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
                  kAccrualBlue.withOpacity(0.18),
                  kAccrualViolet.withOpacity(0.10),
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
              color: kAccrualInkSoft,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyConfig {
  final String mode;
  final String accrualType;
  final int fixedPointsPerPurchase;
  final int pointsPer100Rub;
  final double cashbackPercent;
  final List<_CashbackLevel> cashbackLevels;
  final int clientVisits;
  final double clientTotalSpent;

  _LoyaltyConfig({
    required this.mode,
    required this.accrualType,
    required this.fixedPointsPerPurchase,
    required this.pointsPer100Rub,
    required this.cashbackPercent,
    required this.cashbackLevels,
    required this.clientVisits,
    required this.clientTotalSpent,
  });

  factory _LoyaltyConfig.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final levelsRaw = (json['cashback_levels'] as List?) ?? const [];

    return _LoyaltyConfig(
      mode: json['mode']?.toString() ?? 'points',
      accrualType: json['accrual_type']?.toString() ?? 'per_amount',
      fixedPointsPerPurchase: parseInt(json['fixed_points_per_purchase']),
      pointsPer100Rub: parseInt(json['points_per_100_rub']),
      cashbackPercent: parseNum(json['cashback_percent']),
      cashbackLevels: levelsRaw
          .map((e) => _CashbackLevel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      clientVisits: parseInt(json['client_visits']),
      clientTotalSpent: parseNum(json['client_total_spent']),
    );
  }

  double get activeCashbackPercent {
    if (cashbackLevels.isEmpty) return cashbackPercent;
    double result = cashbackPercent;
    for (final level in cashbackLevels) {
      if (clientTotalSpent >= level.spentRequired) {
        result = level.cashbackPercent;
      }
    }
    return result;
  }

  String get modeLabel {
    if (mode == 'cashback') return 'Кешбэк';
    if (mode == 'discount') return 'Скидки';
    return 'Баллы';
  }
}

class _CashbackLevel {
  final String name;
  final double spentRequired;
  final double cashbackPercent;

  _CashbackLevel({
    required this.name,
    required this.spentRequired,
    required this.cashbackPercent,
  });

  factory _CashbackLevel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _CashbackLevel(
      name: json['name']?.toString() ?? '',
      spentRequired: parseNum(json['spent_required']),
      cashbackPercent: parseNum(json['cashback_percent']),
    );
  }
}

class _AccrualPreview {
  final double checkAmount;
  final double added;
  final String label;

  _AccrualPreview({
    required this.checkAmount,
    required this.added,
    required this.label,
  });

  String get addedLabel {
    if (added == added.roundToDouble()) {
      return added.toInt().toString();
    }
    return added.toStringAsFixed(2);
  }
}