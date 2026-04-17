import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_owner_requests_api.dart';
import '../widgets/staff_glass_ui.dart';

const Color kOwnerReqMintTop = Color(0xFF0CB7B3);
const Color kOwnerReqMintMid = Color(0xFF08A9AB);
const Color kOwnerReqMintBottom = Color(0xFF067D87);
const Color kOwnerReqMintDeep = Color(0xFF055E66);

const Color kOwnerReqInk = Color(0xFF103238);
const Color kOwnerReqInkSoft = Color(0xFF58767D);
const Color kOwnerReqBlue = Color(0xFF4E7CFF);
const Color kOwnerReqPink = Color(0xFFFF5F8F);
const Color kOwnerReqViolet = Color(0xFF7A63FF);
const Color kOwnerReqAccent = Color(0xFFFFA11D);
const Color kOwnerReqAccentSoft = Color(0xFFFFC45E);

class OwnerRequestsScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String role;

  const OwnerRequestsScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.role,
  });

  @override
  State<OwnerRequestsScreen> createState() => _OwnerRequestsScreenState();
}

class _OwnerRequestsScreenState extends State<OwnerRequestsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _introController;

  final StaffOwnerRequestsApi _api = const StaffOwnerRequestsApi();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<OwnerRequestItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7800),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );

    _load();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _introController.dispose();
    super.dispose();
  }

  String get _roleLabel {
    final role = widget.role.trim().toLowerCase();
    if (role == 'owner') return 'Владелец';
    if (role == 'admin') return 'Администратор';
    return 'Сотрудник';
  }

  int get _scheduleCount => _items.where((e) => e.isSchedule).length;
  int get _swapCount => _items.where((e) => e.isSwap).length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bundle = await _api.getOwnerRequests(
        establishmentId: widget.establishmentId,
      );

      if (!mounted) return;

      setState(() {
        _items = bundle.items;
        _loading = false;
      });

      _introController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить согласования';
      });
      _introController.forward(from: 0);
    }
  }

  Future<void> _approve(OwnerRequestItem item) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _api.approveRequest(
        establishmentId: widget.establishmentId,
        requestType: item.requestType,
        requestId: item.requestId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос согласован')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка согласования: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reject(OwnerRequestItem item) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _api.rejectRequest(
        establishmentId: widget.establishmentId,
        requestType: item.requestType,
        requestId: item.requestId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос отклонен')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отклонения: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
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
            offset: Offset(0, 24 * (1 - t)),
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
      animation: _ambientController,
      builder: (context, child) {
        final t = _ambientController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 14;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kOwnerReqMintTop,
                    kOwnerReqMintMid,
                    kOwnerReqMintBottom,
                    kOwnerReqMintDeep,
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
                    Colors.white.withOpacity(0.18),
                    kOwnerReqAccent.withOpacity(0.13),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -58,
              top: 210 + shiftB,
              child: Transform.rotate(
                angle: -rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    kOwnerReqBlue.withOpacity(0.14),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 50 - shiftA,
              right: -20,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kOwnerReqAccentSoft.withOpacity(0.10),
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

  Widget _promoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0x1FFFFFFF),
            Color(0x14FFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        children: [
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
                      colors: [kOwnerReqAccent, kOwnerReqAccentSoft],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kOwnerReqAccent.withOpacity(0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    _roleLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Запросы и\nсогласования',
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Все входящие графики и запросы команды в одном месте.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const _DecorApproveCard(),
        ],
      ),
    );
  }

  Widget _topCard() {
    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.establishmentName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kOwnerReqInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Согласования владельца',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: kOwnerReqInkSoft,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.calendar_badge_plus,
                  title: '$_scheduleCount',
                  subtitle: 'Графики',
                  colorA: kOwnerReqBlue,
                  colorB: kOwnerReqViolet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
                  title: '$_swapCount',
                  subtitle: 'Замены',
                  colorA: kOwnerReqAccent,
                  colorB: kOwnerReqPink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestCard(OwnerRequestItem item) {
    final isSwap = item.isSwap;
    final details = isSwap
        ? (item.reason?.trim().isNotEmpty == true ? item.reason!.trim() : 'Без комментария')
        : (item.selectedDays.isEmpty ? 'Дни не указаны' : 'Дни: ${item.selectedDays.join(', ')}');

    return _Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      borderRadius: 30,
      child: _GlassCard(
        radius: 30,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FloatingGlyph(
                  icon: isSwap
                      ? CupertinoIcons.arrow_2_circlepath_circle_fill
                      : CupertinoIcons.doc_text_fill,
                  mainColor: isSwap ? kOwnerReqAccent : kOwnerReqBlue,
                  secondaryColor: isSwap ? kOwnerReqPink : kOwnerReqViolet,
                  size: 68,
                  iconSize: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isSwap ? 'Запрос на замену' : 'График на согласование',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kOwnerReqInk,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withOpacity(0.86),
                    border: Border.all(color: Colors.white.withOpacity(0.90)),
                  ),
                  child: Text(
                    item.typeLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: kOwnerReqInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: kOwnerReqInkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              details,
              style: const TextStyle(
                fontSize: 13.2,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: kOwnerReqInkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusLabel(item.status),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _statusColor(item.status),
              ),
            ),
            const SizedBox(height: 16),
            if (item.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [kOwnerReqBlue, kOwnerReqViolet],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kOwnerReqBlue.withOpacity(0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _busy ? null : () => _approve(item),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Согласовать',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _reject(item),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.90)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Отклонить',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withOpacity(0.78),
                  border: Border.all(color: Colors.white.withOpacity(0.90)),
                ),
                child: Center(
                  child: Text(
                    item.status == 'approved' ? 'Уже согласовано' : 'Уже отклонено',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _statusColor(item.status),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tipCard() {
    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FloatingGlyph(
            icon: CupertinoIcons.lightbulb_fill,
            mainColor: kOwnerReqAccent,
            secondaryColor: kOwnerReqPink,
            size: 68,
            iconSize: 30,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Подсказка',
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    color: kOwnerReqInk,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Теперь кнопки работают с реальным backend. Следующим шагом подключим сюда живую отправку графика и замен со стороны сотрудника.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: kOwnerReqInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return const _GlassCard(
      radius: 30,
      padding: EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(kOwnerReqViolet),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return _GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF4F2),
              border: Border.all(color: const Color(0xFFFFD7D0)),
            ),
            child: const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: Color(0xFFE85B63),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Не удалось загрузить запросы',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kOwnerReqInk,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Ошибка загрузки',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kOwnerReqInkSoft,
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [kOwnerReqBlue, kOwnerReqPink],
              ),
              boxShadow: [
                BoxShadow(
                  color: kOwnerReqBlue.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Повторить',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return const _GlassCard(
      radius: 30,
      padding: EdgeInsets.all(22),
      child: Column(
        children: [
          _EmptyOrb(),
          SizedBox(height: 16),
          Text(
            'Пока нет входящих запросов',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kOwnerReqInk,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Когда сотрудники отправят графики или замены, они появятся здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kOwnerReqInkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF1FA971);
      case 'rejected':
        return const Color(0xFFE85B63);
      default:
        return kOwnerReqViolet;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Согласовано';
      case 'rejected':
        return 'Отклонено';
      default:
        return 'Ожидает согласования';
    }
  }

  @override
  Widget build(BuildContext context) {
    int nextIndex = 3;

    Widget staggered(Widget child) {
      final current = nextIndex;
      nextIndex += 1;
      return _stagger(index: current, child: child);
    }

    return Scaffold(
      backgroundColor: kOwnerReqMintTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              child: RefreshIndicator(
                color: kOwnerReqViolet,
                backgroundColor: Colors.white,
                onRefresh: _load,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _stagger(
                      index: 0,
                      child: Row(
                        children: [
                          _topIconButton(
                            icon: CupertinoIcons.back,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Запросы и согласования',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _stagger(index: 1, child: _promoBanner()),
                    const SizedBox(height: 16),
                    _stagger(index: 2, child: _topCard()),
                    const SizedBox(height: 16),
                    if (_loading)
                      _loadingCard()
                    else if (_error != null)
                      _errorCard()
                    else if (_items.isEmpty)
                      _emptyCard()
                    else ...[
                      for (final item in _items) ...[
                        staggered(_requestCard(item)),
                        const SizedBox(height: 12),
                      ],
                    ],
                    const SizedBox(height: 12),
                    staggered(_tipCard()),
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
            gradient: const LinearGradient(
              colors: [
                Color(0xE8FFFFFF),
                Color(0xCCFFFFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xA6FFFFFF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x22062E36).withOpacity(0.10),
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color colorA;
  final Color colorB;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        children: [
          _FloatingGlyph(
            icon: icon,
            mainColor: colorA,
            secondaryColor: colorB,
            size: 62,
            iconSize: 24,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kOwnerReqInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kOwnerReqInkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorApproveCard extends StatelessWidget {
  const _DecorApproveCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 10,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 46,
                color: kOwnerReqAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrb extends StatelessWidget {
  const _EmptyOrb();

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
                  kOwnerReqBlue.withOpacity(0.18),
                  kOwnerReqViolet.withOpacity(0.10),
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
            child: const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: kOwnerReqInkSoft,
              size: 28,
            ),
          ),
        ],
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
