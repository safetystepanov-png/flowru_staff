import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import 'staff_client_detail_screen.dart';
import 'staff_qr_scanner_screen.dart';

const Color kSearchMintTop = Color(0xFF0CB7B3);
const Color kSearchMintMid = Color(0xFF08A9AB);
const Color kSearchMintBottom = Color(0xFF067D87);
const Color kSearchMintDeep = Color(0xFF055E66);

const Color kSearchAccent = Color(0xFFFFA11D);
const Color kSearchAccentSoft = Color(0xFFFFC45E);

const Color kSearchCard = Color(0xCCFFFFFF);
const Color kSearchCardStrong = Color(0xE8FFFFFF);
const Color kSearchStroke = Color(0xA6FFFFFF);

const Color kSearchInk = Color(0xFF103238);
const Color kSearchInkSoft = Color(0xFF58767D);
const Color kSearchShadow = Color(0x22062E36);

const Color kSearchBlue = Color(0xFF4E7CFF);
const Color kSearchPink = Color(0xFFFF5F8F);
const Color kSearchViolet = Color(0xFF7A63FF);

class StaffClientSearchScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffClientSearchScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffClientSearchScreen> createState() =>
      _StaffClientSearchScreenState();
}

class _StaffClientSearchScreenState extends State<StaffClientSearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;
  String? _error;
  List<_ClientSearchItem> _items = [];

  late final AnimationController _bgController;
  late final AnimationController _introController;

  bool get _hasResult => _items.isNotEmpty;

  _ClientSearchItem? get _primaryItem => _items.isNotEmpty ? _items.first : null;

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
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _resetSearch() {
    setState(() {
      _items = [];
      _error = null;
      _controller.clear();
      _loading = false;
    });
    _introController.forward(from: 0);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _items = [];
        _error = null;
      });
      _introController.forward(from: 0);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final token = await _token();

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/clients/search'
        '?establishment_id=${widget.establishmentId}'
        '&query=${Uri.encodeQueryComponent(query)}',
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
          'search failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else if (decoded is Map<String, dynamic> && decoded['clients'] is List) {
        raw = decoded['clients'] as List<dynamic>;
      } else {
        raw = [];
      }

      if (!mounted) return;

      final found = raw
          .map((e) => _ClientSearchItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.clientId.isNotEmpty)
          .toList();

      setState(() {
        _items = found;
        _loading = false;
        _error = found.isEmpty ? 'Клиент не найден' : null;
      });

      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось найти клиента';
      });
      _introController.forward(from: 0);
    }
  }

  Future<void> _openQrSearch() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const StaffQrScannerScreen(),
      ),
    );

    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffClientDetailScreen(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
          clientId: result.trim(),
        ),
      ),
    );
  }

  void _openClient(_ClientSearchItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffClientDetailScreen(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
          clientId: item.clientId,
        ),
      ),
    );
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
                    kSearchMintTop,
                    kSearchMintMid,
                    kSearchMintBottom,
                    kSearchMintDeep,
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
                    kSearchAccent.withOpacity(0.12),
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
                    kSearchBlue.withOpacity(0.07),
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
                    kSearchAccentSoft.withOpacity(0.10),
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

  Widget _topIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroSearchCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.96),
                Colors.white.withOpacity(0.86),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
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
                        colors: [kSearchAccent, kSearchAccentSoft],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kSearchAccent.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Text(
                      'ПОИСК КЛИЕНТА',
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: kSearchInk.withOpacity(0.06),
                    ),
                    child: const Icon(
                      CupertinoIcons.search_circle_fill,
                      size: 26,
                      color: kSearchInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Найти клиента',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  color: kSearchInk,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Введи телефон, имя или номер клиента.\nЛибо открой QR-сканер.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                  color: kSearchInkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withOpacity(0.95),
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
                  controller: _controller,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    hintText: 'Телефон, имя, номер клиента',
                    hintStyle: TextStyle(
                      color: kSearchInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: kSearchInkSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [kSearchBlue, kSearchViolet],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kSearchBlue.withOpacity(0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _loading ? null : _search,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Найти',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [kSearchPink, kSearchViolet],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kSearchPink.withOpacity(0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _openQrSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.qrcode_viewfinder,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Сканер',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
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
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kSearchInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kSearchInkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _foundClientCard(_ClientSearchItem item) {
    return _Pressable(
      onTap: () => _openClient(item),
      borderRadius: 30,
      child: _GlassCard(
        radius: 30,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AvatarGlyph(initials: item.initials),
                const SizedBox(width: 14),
                Expanded(
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
                            colors: [kSearchBlue, kSearchViolet],
                          ),
                        ),
                        child: const Text(
                          'КЛИЕНТ НАЙДЕН',
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
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kSearchInk,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.phone.isEmpty ? 'Телефон не указан' : item.phone,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kSearchInkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: kSearchBlue.withOpacity(0.08),
                border: Border.all(color: kSearchBlue.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.person_crop_circle_fill,
                    color: kSearchBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Открыть карточку клиента и продолжить работу',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kSearchInk.withOpacity(0.92),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [kSearchBlue, kSearchViolet],
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.chevron_right,
                      color: Colors.white,
                      size: 18,
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

  Widget _secondaryActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [kSearchPink, kSearchViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: kSearchPink.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsBlock() {
    final item = _primaryItem!;
    return Column(
      children: [
        _foundClientCard(item),
        const SizedBox(height: 14),
        _secondaryActionButton(
          text: 'Назад к поиску',
          icon: CupertinoIcons.arrow_turn_up_left,
          onTap: _resetSearch,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSearchMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Поиск клиента',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _topIconButton(
              icon: _hasResult ? CupertinoIcons.refresh : CupertinoIcons.search,
              onTap: _hasResult ? _resetSearch : _search,
            ),
          ),
        ],
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_hasResult)
                    _stagger(
                      index: 0,
                      child: _resultsBlock(),
                    )
                  else ...[
                    _stagger(index: 0, child: _heroSearchCard()),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _stagger(
                        index: 1,
                        child: _stateCard(
                          icon: CupertinoIcons.exclamationmark_circle_fill,
                          title: 'Ошибка',
                          subtitle: _error!,
                        ),
                      ),
                    ],
                  ],
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
                kSearchCardStrong,
                kSearchCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kSearchStroke),
            boxShadow: [
              BoxShadow(
                color: kSearchShadow.withOpacity(0.10),
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
                  kSearchBlue.withOpacity(0.18),
                  kSearchViolet.withOpacity(0.10),
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
              color: kSearchInkSoft,
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

  const _AvatarGlyph({
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kSearchBlue.withOpacity(0.22),
                  kSearchPink.withOpacity(0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [kSearchBlue, kSearchPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kSearchBlue.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
            ),
          ),
          Positioned(
            top: 9,
            right: 10,
            child: Container(
              width: 11,
              height: 11,
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

class _ClientSearchItem {
  final String clientId;
  final String fullName;
  final String phone;

  _ClientSearchItem({
    required this.clientId,
    required this.fullName,
    required this.phone,
  });

  factory _ClientSearchItem.fromJson(Map<String, dynamic> json) {
    return _ClientSearchItem(
      clientId: json['client_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName:
          json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (phone.trim().isNotEmpty) return phone.trim();
    return 'Клиент';
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}