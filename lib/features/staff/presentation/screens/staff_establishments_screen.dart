import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/staff_establishments_api.dart';
import '../widgets/staff_glass_ui.dart';
import 'staff_home_screen.dart';
import '../../../auth/data/auth_session.dart';

class StaffEstablishmentsScreen extends StatefulWidget {
  const StaffEstablishmentsScreen({super.key});

  @override
  State<StaffEstablishmentsScreen> createState() =>
      _StaffEstablishmentsScreenState();
}

class _StaffEstablishmentsScreenState extends State<StaffEstablishmentsScreen>
    with SingleTickerProviderStateMixin {
  final StaffEstablishmentsApi _api = StaffEstablishmentsApi();

  bool _loading = true;
  String? _error;
  List<StaffEstablishmentItem> _items = [];

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();

    _load();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.getEstablishments();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить заведения';
      });
    }
  }

  void _openEstablishment(StaffEstablishmentItem item) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StaffHomeScreen(
          establishmentId: item.id,
          establishmentName: item.name,
          role: item.role,
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final shiftA = math.sin(t * math.pi * 2) * 22;
        final shiftB = math.cos(t * math.pi * 2) * 18;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kStaffBgTop, kStaffBgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: -60,
              top: 190 + shiftA,
              child: _blob(
                170,
                [
                  kStaffBlue.withOpacity(0.08),
                  kStaffViolet.withOpacity(0.03),
                ],
              ),
            ),
            Positioned(
              right: -40,
              top: -10 + shiftB,
              child: _blob(
                160,
                [
                  kStaffPink.withOpacity(0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, List<Color> colors) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 48),
            const Expanded(
              child: SizedBox(),
            ),
            IconButton(
              tooltip: 'Выйти',
              onPressed: () => AuthSession.logout(context),
              icon: const Icon(
                Icons.logout_rounded,
                color: kStaffInkPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const StaffLogoBadge(size: 56),
        const SizedBox(height: 18),
        const Text(
          'Выбор заведения',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: kStaffInkPrimary,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Выберите точку, с которой сейчас работаете',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: kStaffInkSecondary,
          ),
        ),
      ],
    );
  }

  Widget _loadingCard() {
    return const StaffGlassPanel(
      radius: 28,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(kStaffViolet),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return StaffGlassPanel(
      radius: 28,
      glowColor: Colors.redAccent.withOpacity(0.08),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Color(0xFFFF5A5F),
            size: 38,
          ),
          const SizedBox(height: 16),
          const Text(
            'Не удалось загрузить заведения',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Ошибка загрузки',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [kStaffBlue, kStaffPink],
              ),
            ),
            child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
    return const StaffGlassPanel(
      radius: 28,
      child: Column(
        children: [
          Icon(
            CupertinoIcons.building_2_fill,
            color: kStaffInkSecondary,
            size: 36,
          ),
          SizedBox(height: 14),
          Text(
            'Нет доступных заведений',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Для этого аккаунта пока не назначены точки',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(StaffEstablishmentItem item) {
    return StaffGlassPanel(
      radius: 24,
      glowColor: kStaffViolet.withOpacity(0.08),
      onTap: () => _openEstablishment(item),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [kStaffBlue, kStaffPink],
              ),
            ),
            child: const Icon(
              CupertinoIcons.building_2_fill,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: kStaffInkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.role.isEmpty ? 'staff' : item.role,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kStaffInkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            CupertinoIcons.chevron_right,
            color: kStaffInkPrimary,
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return _loadingCard();
    }

    if (_error != null) {
      return _errorCard();
    }

    if (_items.isEmpty) {
      return _emptyCard();
    }

    return Column(
      children: _items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _itemCard(item),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  _header(),
                  const SizedBox(height: 22),
                  _content(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}