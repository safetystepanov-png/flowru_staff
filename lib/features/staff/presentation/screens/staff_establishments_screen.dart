import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_establishments_api.dart';
import '../widgets/staff_glass_ui.dart';
import 'staff_home_screen.dart';
import '../../../auth/data/auth_storage.dart' as auth_storage;

const Color kEstMintTop = Color(0xFF0CB7B3);
const Color kEstMintMid = Color(0xFF08A9AB);
const Color kEstMintBottom = Color(0xFF067D87);
const Color kEstMintDeep = Color(0xFF055E66);

const Color kEstAccent = Color(0xFFFFA11D);
const Color kEstAccentSoft = Color(0xFFFFC45E);

const Color kEstCard = Color(0xCCFFFFFF);
const Color kEstCardStrong = Color(0xE8FFFFFF);
const Color kEstStroke = Color(0xA6FFFFFF);

const Color kEstInk = Color(0xFF103238);
const Color kEstInkSoft = Color(0xFF58767D);
const Color kEstShadow = Color(0x22062E36);

const Color kEstBlue = Color(0xFF4E7CFF);
const Color kEstPink = Color(0xFFFF5F8F);
const Color kEstViolet = Color(0xFF7A63FF);
const Color kEstSuccess = Color(0xFF22C55E);

class StaffEstablishmentsScreen extends StatefulWidget {
  final bool forceChooser;

  const StaffEstablishmentsScreen({
    super.key,
    this.forceChooser = false,
  });

  @override
  State<StaffEstablishmentsScreen> createState() =>
      _StaffEstablishmentsScreenState();
}

class _StaffEstablishmentsScreenState extends State<StaffEstablishmentsScreen>
    with TickerProviderStateMixin {
  final StaffEstablishmentsApi _api = StaffEstablishmentsApi();

  bool _loading = true;
  String? _error;
  List<StaffEstablishmentItem> _items = [];
  bool _autoNavigated = false;

  late final AnimationController _bgController;
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );

    _load();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
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

      _introController.forward(from: 0);

      if (!widget.forceChooser) {
        if (items.length == 1) {
          await _openEstablishment(items.first);
          return;
        }

        await _tryAutoOpenSaved(items);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить заведения';
      });

      _introController.forward(from: 0);
    }
  }

  Future<void> _tryAutoOpenSaved(List<StaffEstablishmentItem> items) async {
    if (_autoNavigated) return;

    final savedId = await auth_storage.AuthStorage.getSelectedEstablishmentId();
    if (savedId == null) return;

    final matched = _findById(items, savedId);
    if (matched == null) {
      await auth_storage.AuthStorage.clearSelectedEstablishment();
      return;
    }

    _autoNavigated = true;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StaffHomeScreen(
          establishmentId: matched.id,
          establishmentName: matched.name,
          role: matched.role,
        ),
      ),
    );
  }

  StaffEstablishmentItem? _findById(
    List<StaffEstablishmentItem> items,
    int id,
  ) {
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEstablishment(StaffEstablishmentItem item) async {
    await auth_storage.AuthStorage.saveSelectedEstablishment(
      establishmentId: item.id,
      establishmentName: item.name,
      role: item.role,
    );

    if (!mounted) return;

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
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 14;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kEstMintTop,
                    kEstMintMid,
                    kEstMintBottom,
                    kEstMintDeep,
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
                    kEstAccent.withOpacity(0.13),
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
                    kEstBlue.withOpacity(0.07),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 46 - shiftA,
              right: -18,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kEstAccentSoft.withOpacity(0.10),
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

  bool get _hasOwnerRoles {
    return _items.any((e) {
      final role = e.role.trim().toLowerCase();
      return role == 'owner' || role == 'admin';
    });
  }

  bool get _hasStaffRoles {
    return _items.any((e) {
      final role = e.role.trim().toLowerCase();
      return role != 'owner' && role != 'admin';
    });
  }

  Widget _header() {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            _topIconButton(
              icon: Icons.logout_rounded,
              onTap: () async {
                await auth_storage.AuthStorage.clearAll();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 82,
          height: 82,
          child: Center(
            child: StaffLogoBadge(size: 60),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.forceChooser ? 'Смена заведения' : 'Выбор заведения',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.9,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.forceChooser
              ? 'Выберите другую точку для продолжения работы'
              : 'Первый выбор сохранится и в следующий раз откроется автоматически',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.84),
          ),
        ),
      ],
    );
  }

  Widget _promoBanner() {
    final bannerTitle = _hasOwnerRoles && _hasStaffRoles
        ? 'Точки и роли\nдоступа'
        : _hasOwnerRoles
            ? 'Ваши заведения\nвладельца'
            : 'Ваши рабочие\nзаведения';

    final bannerText = widget.forceChooser
        ? 'Эта точка будет сохранена как основная и в следующий запуск откроется сразу.'
        : _hasOwnerRoles && _hasStaffRoles
            ? 'У вас есть доступ и как владельца, и как сотрудника. Выберите нужную точку входа.'
            : _hasOwnerRoles
                ? 'Откройте заведение и управляйте графиком, согласованиями и командой.'
                : 'Откройте нужную точку и продолжайте работу в едином интерфейсе.';

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
                      colors: [kEstAccent, kEstAccentSoft],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kEstAccent.withOpacity(0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.forceChooser
                        ? 'ОСНОВНОЕ ЗАВЕДЕНИЕ'
                        : (_hasOwnerRoles ? 'FLOWRU OWNER / STAFF' : 'FLOWRU STAFF'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  bannerTitle,
                  style: const TextStyle(
                    fontSize: 29,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bannerText,
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
          const _DecorBuildingCard(),
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
            valueColor: AlwaysStoppedAnimation(kEstViolet),
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
            'Не удалось загрузить заведения',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kEstInk,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Ошибка загрузки',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kEstInkSoft,
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [kEstBlue, kEstPink],
              ),
              boxShadow: [
                BoxShadow(
                  color: kEstBlue.withOpacity(0.22),
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
            'Нет доступных заведений',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kEstInk,
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
              color: kEstInkSoft,
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    final value = role.trim().toLowerCase();

    if (value == 'owner') return 'Владелец';
    if (value == 'admin') return 'Администратор';

    if (value == 'cashier' ||
        value == 'staff' ||
        value == 'employee' ||
        value == 'worker' ||
        value.isEmpty) {
      return 'Сотрудник';
    }

    return 'Сотрудник';
  }

  Widget _itemCard(StaffEstablishmentItem item) {
    final roleValue = item.role.trim().toLowerCase();
    final isOwner = roleValue == 'owner' || roleValue == 'admin';

    return _Pressable(
      onTap: () => _openEstablishment(item),
      borderRadius: 30,
      child: _GlassCard(
        radius: 30,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _FloatingGlyph(
              icon: isOwner
                  ? CupertinoIcons.star_fill
                  : CupertinoIcons.building_2_fill,
              mainColor: isOwner ? kEstAccent : kEstBlue,
              secondaryColor: isOwner ? kEstPink : kEstViolet,
              size: 78,
              iconSize: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kEstInk,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color:
                              (isOwner ? kEstAccent : kEstBlue).withOpacity(0.10),
                          border: Border.all(
                            color: (isOwner ? kEstAccent : kEstBlue)
                                .withOpacity(0.12),
                          ),
                        ),
                        child: Text(
                          _roleLabel(item.role),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: kEstInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.72),
                border: Border.all(color: Colors.white.withOpacity(0.72)),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                color: kEstInk,
                size: 18,
              ),
            ),
          ],
        ),
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
      children: [
        for (int i = 0; i < _items.length; i++) ...[
          _stagger(index: i + 2, child: _itemCard(_items[i])),
          if (i != _items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kEstMintTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              child: RefreshIndicator(
                color: kEstViolet,
                backgroundColor: Colors.white,
                onRefresh: _load,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _stagger(index: 0, child: _header()),
                    const SizedBox(height: 18),
                    _stagger(index: 1, child: _promoBanner()),
                    const SizedBox(height: 16),
                    _content(),
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
                kEstCardStrong,
                kEstCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kEstStroke),
            boxShadow: [
              BoxShadow(
                color: kEstShadow.withOpacity(0.10),
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

class _DecorBuildingCard extends StatelessWidget {
  const _DecorBuildingCard();

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
                CupertinoIcons.building_2_fill,
                size: 46,
                color: kEstAccent,
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
                  kEstBlue.withOpacity(0.18),
                  kEstViolet.withOpacity(0.10),
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
              CupertinoIcons.building_2_fill,
              color: kEstInkSoft,
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

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 0,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (value) {
      _glowController.forward();
    } else {
      _glowController.reverse();
    }
  }

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = _glowController.value;

        return GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _tap,
          child: AnimatedScale(
            scale: _pressed ? 0.968 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedRotation(
              turns: _pressed ? -0.003 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03 + (0.03 * glow)),
                      blurRadius: 8 + (10 * glow),
                      offset: Offset(0, 3 + (4 * glow)),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}