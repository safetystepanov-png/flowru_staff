import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';

const Color kSpendMintTop = Color(0xFF0CB7B3);
const Color kSpendMintMid = Color(0xFF08A9AB);
const Color kSpendMintBottom = Color(0xFF067D87);
const Color kSpendMintDeep = Color(0xFF055E66);

const Color kSpendAccent = Color(0xFFFFA11D);
const Color kSpendAccentSoft = Color(0xFFFFC45E);

const Color kSpendCard = Color(0xCCFFFFFF);
const Color kSpendCardStrong = Color(0xE8FFFFFF);
const Color kSpendStroke = Color(0xA6FFFFFF);

const Color kSpendInk = Color(0xFF103238);
const Color kSpendInkSoft = Color(0xFF58767D);
const Color kSpendShadow = Color(0x22062E36);

const Color kSpendBlue = Color(0xFF4E7CFF);
const Color kSpendPink = Color(0xFFFF5F8F);
const Color kSpendViolet = Color(0xFF7A63FF);
const Color kSpendRed = Color(0xFFFF6A5E);
const Color kSpendRedDark = Color(0xFFE14B4B);

class StaffClientSpendScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffClientSpendScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<StaffClientSpendScreen> createState() => _StaffClientSpendScreenState();
}

class _StaffClientSpendScreenState extends State<StaffClientSpendScreen>
    with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  _SpendConfig? _config;
  _SpendPreview? _preview;

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

    _amountController.addListener(_recalculate);
    _loadConfig();
  }

  @override
  void dispose() {
    _amountController.removeListener(_recalculate);
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
        throw Exception(
          'config failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _config = _SpendConfig.fromJson(decoded);
        _loading = false;
      });

      _recalculate();
      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить настройки списания';
      });
      _introController.forward(from: 0);
    }
  }

  void _recalculate() {
    final config = _config;
    if (config == null) return;

    final amount = _parseAmount();

    if (amount <= 0) {
      if (mounted) {
        setState(() {
          _preview = null;
        });
      }
      return;
    }

    double redeemed = 0;
    double payable = amount;

    if (config.mode == 'points') {
      final byBalance = config.clientBalance;
      final byPercent = amount * config.maxRedeemPercent / 100.0;
      redeemed = byBalance < byPercent ? byBalance : byPercent;
      redeemed = redeemed.floorToDouble();
      payable = amount - redeemed;
    } else if (config.mode == 'cashback') {
      final byBalance = config.clientBalance;
      final byPercent = amount * config.maxRedeemPercent / 100.0;
      redeemed = byBalance < byPercent ? byBalance : byPercent;
      redeemed = double.parse(redeemed.toStringAsFixed(2));
      payable = amount - redeemed;
    } else {
      redeemed = 0;
      payable = amount;
    }

    if (payable < 0) payable = 0;

    if (mounted) {
      setState(() {
        _preview = _SpendPreview(
          checkAmount: amount,
          redeemed: redeemed,
          payable: double.parse(payable.toStringAsFixed(2)),
        );
      });
    }
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
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/spend'),
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
          'spend failed: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.96)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _ResultOrb(
                      icon: CupertinoIcons.check_mark_circled_solid,
                      color: kSpendRed,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Списание выполнено',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kSpendInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      decoded['message']?.toString() ?? 'Списание прошло успешно',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: kSpendInkSoft,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [kSpendRed, kSpendRedDark],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                          'Готово',
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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выполнить списание';
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
                    kSpendMintTop,
                    kSpendMintMid,
                    kSpendMintBottom,
                    kSpendMintDeep,
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
                    kSpendAccent.withOpacity(0.12),
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
                    kSpendBlue.withOpacity(0.07),
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
                    kSpendAccentSoft.withOpacity(0.10),
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

  Widget _heroCard() {
    return _GlassCard(
      radius: 34,
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
                    kSpendAccent.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -18,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kSpendRed.withOpacity(0.12),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [kSpendRed, kSpendRedDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kSpendRed.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Text(
                      'СПИСАНИЕ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: kSpendInk.withOpacity(0.06),
                    ),
                    child: const Icon(
                      CupertinoIcons.minus_circle_fill,
                      size: 26,
                      color: kSpendInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.clientName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: kSpendInk,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.establishmentName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kSpendInkSoft,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Сумма чека',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kSpendInk,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Введи сумму покупки — ниже покажем, сколько можно списать и сколько останется к оплате.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                  color: kSpendInkSoft,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withOpacity(0.94),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kSpendInk,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    hintText: 'Например 1250',
                    hintStyle: TextStyle(
                      color: kSpendInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.money_rubl_circle_fill,
                      color: kSpendInkSoft,
                    ),
                    suffixText: '₽',
                    suffixStyle: TextStyle(
                      color: kSpendInkSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final preview = _preview;
    final config = _config;

    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Предпросмотр',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: kSpendInk,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Проверь расчет перед подтверждением',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kSpendInkSoft,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Режим',
                  value: config?.modeLabel ?? '—',
                  glow: kSpendBlue,
                  icon: CupertinoIcons.sparkles,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  title: 'Баланс',
                  value: config?.balanceLabel ?? '—',
                  glow: kSpendViolet,
                  icon: CupertinoIcons.creditcard_fill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Списание',
                  value: preview?.redeemedLabel ?? '—',
                  glow: kSpendRed,
                  icon: CupertinoIcons.minus_circle_fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  title: 'К оплате',
                  value: preview != null
                      ? '${preview.payable.toStringAsFixed(2)} ₽'
                      : '—',
                  glow: kSpendAccent,
                  icon: CupertinoIcons.money_rubl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color glow,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: glow.withOpacity(0.08),
        border: Border.all(color: glow.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniGlyph(icon: icon, color: glow),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kSpendInk,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: kSpendInkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
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
          colors: [kSpendRed, kSpendRedDark],
        ),
        boxShadow: [
          BoxShadow(
            color: kSpendRed.withOpacity(0.22),
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
                'Подтвердить списание',
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
      backgroundColor: kSpendMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Списание',
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
                          valueColor: AlwaysStoppedAnimation(kSpendViolet),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _stagger(index: 0, child: _heroCard()),
                        const SizedBox(height: 14),
                        _stagger(index: 1, child: _previewCard()),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _stagger(index: 2, child: _errorCard()),
                        ],
                        const SizedBox(height: 18),
                        _stagger(index: 3, child: _submitButton()),
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
                kSpendCardStrong,
                kSpendCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kSpendStroke),
            boxShadow: [
              BoxShadow(
                color: kSpendShadow.withOpacity(0.10),
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

class _ResultOrb extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ResultOrb({
    required this.icon,
    required this.color,
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
                  color.withOpacity(0.18),
                  color.withOpacity(0.08),
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
              color: Colors.white.withOpacity(0.94),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendConfig {
  final String mode;
  final double clientBalance;
  final double maxRedeemPercent;

  _SpendConfig({
    required this.mode,
    required this.clientBalance,
    required this.maxRedeemPercent,
  });

  factory _SpendConfig.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _SpendConfig(
      mode: json['mode']?.toString() ?? 'points',
      clientBalance: parseNum(
        json['client_balance'] ?? json['balance'] ?? json['points_balance'],
      ),
      maxRedeemPercent: parseNum(json['max_redeem_percent']),
    );
  }

  String get modeLabel {
    if (mode == 'cashback') return 'Кешбэк';
    if (mode == 'discount') return 'Скидки';
    return 'Баллы';
  }

  String get balanceLabel {
    if (clientBalance == clientBalance.roundToDouble()) {
      return clientBalance.toInt().toString();
    }
    return clientBalance.toStringAsFixed(2);
  }
}

class _SpendPreview {
  final double checkAmount;
  final double redeemed;
  final double payable;

  _SpendPreview({
    required this.checkAmount,
    required this.redeemed,
    required this.payable,
  });

  String get redeemedLabel {
    if (redeemed == redeemed.roundToDouble()) {
      return redeemed.toInt().toString();
    }
    return redeemed.toStringAsFixed(2);
  }
}