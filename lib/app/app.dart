import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/data/auth_storage.dart';
import '../features/auth/data/user_api.dart';
import '../features/auth/presentation/screens/login_phone_screen.dart';
import '../features/staff/presentation/screens/staff_establishments_screen.dart';
import '../features/staff/presentation/screens/staff_home_screen.dart';

class FlowruStaffApp extends StatelessWidget {
  const FlowruStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flowru Staff',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7D63FF),
        ),
      ),
      home: const _LaunchFlowruScreen(),
    );
  }
}

class _LaunchFlowruScreen extends StatefulWidget {
  const _LaunchFlowruScreen();

  @override
  State<_LaunchFlowruScreen> createState() => _LaunchFlowruScreenState();
}

class _LaunchFlowruScreenState extends State<_LaunchFlowruScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _logoController;
  late final AnimationController _pulseController;
  late final AnimationController _textController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  Timer? _timer;
  bool _moved = false;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      HapticFeedback.lightImpact();
      await _logoController.forward();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      await _textController.forward();
    });

    _timer = Timer(const Duration(milliseconds: 2350), _goNext);
  }

  void _goNext() {
    if (!mounted || _moved) return;
    _moved = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _AppBootstrapScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ambientController.dispose();
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Widget _softBlob({
    required double width,
    required double height,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
        final rotate = math.sin(t * math.pi * 2) * 0.025;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0CB7B3),
                    Color(0xFF08A9AB),
                    Color(0xFF067D87),
                    Color(0xFF055E66),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.40, 0.78, 1.0],
                ),
              ),
            ),
            Positioned.fill(
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
            Positioned(
              top: -82 + shiftA,
              right: -30,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 260,
                  height: 260,
                  colors: [
                    Colors.white.withOpacity(0.18),
                    const Color(0xFFFFA11D).withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -60,
              top: 220 + shiftB,
              child: Transform.rotate(
                angle: -rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    const Color(0xFF7D63FF).withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 30 - shiftA,
              right: -10,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    const Color(0xFFFFC45E).withOpacity(0.10),
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

  Widget _logoCore() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _pulseController]),
      builder: (context, child) {
        final pulse = _pulseController.value;
        final glowScale = 1.0 + (pulse * 0.16);
        final glowOpacity = 0.22 + ((1 - pulse) * 0.10);

        return FadeTransition(
          opacity: _logoOpacity,
          child: ScaleTransition(
            scale: _logoScale,
            child: SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: glowScale,
                    child: Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFA11D)
                                .withOpacity(glowOpacity),
                            blurRadius: 42,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.10),
                            blurRadius: 26,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.24),
                          Colors.white.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.24),
                      ),
                    ),
                  ),
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFA11D),
                          Color(0xFFFFC45E),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA11D).withOpacity(0.32),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/flowru_logo.png',
                        width: 62,
                        height: 62,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _titleBlock() {
    return FadeTransition(
      opacity: _textOpacity,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            const Text(
              'FLOWRU STAFF',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Система лояльности\nдля команды заведения',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loaderLine() {
    return FadeTransition(
      opacity: _textOpacity,
      child: Container(
        width: 120,
        height: 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.16),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return FractionallySizedBox(
                widthFactor: 0.28 + (_pulseController.value * 0.42),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFA11D),
                        Color(0xFFFFC45E),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _logoCore(),
                    const SizedBox(height: 28),
                    _titleBlock(),
                    const SizedBox(height: 26),
                    _loaderLine(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBootstrapScreen extends StatefulWidget {
  const _AppBootstrapScreen();

  @override
  State<_AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<_AppBootstrapScreen> {
  late Future<_BootstrapState> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<_BootstrapState> _resolve() async {
    final token = await AuthStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      return const _BootstrapState.unauthorized();
    }

    try {
      final profile = await UserApi.getAccessProfile(token);

      if (!profile.hasAccess || profile.establishments.isEmpty) {
        await AuthStorage.clearAll();
        return _BootstrapState.revoked(profile: profile);
      }

      final savedEstablishmentId = await AuthStorage.getSelectedEstablishmentId();
      final savedEstablishmentName =
          await AuthStorage.getSelectedEstablishmentName();
      final savedRole = await AuthStorage.getSelectedEstablishmentRole();

      if (savedEstablishmentId != null) {
        final matched = profile.establishments.cast<AccessProfileEstablishment?>()
            .firstWhere(
              (e) => e?.id == savedEstablishmentId && (e?.accessActive ?? false),
              orElse: () => null,
            );

        if (matched != null) {
          final effectiveName =
              (savedEstablishmentName != null && savedEstablishmentName.trim().isNotEmpty)
                  ? savedEstablishmentName.trim()
                  : matched.name;
          final effectiveRole =
              (savedRole != null && savedRole.trim().isNotEmpty)
                  ? savedRole.trim()
                  : matched.role;

          await AuthStorage.saveSelectedEstablishment(
            establishmentId: matched.id,
            establishmentName: effectiveName,
            role: effectiveRole,
          );

          return _BootstrapState.authorizedWithSelection(
            profile: profile,
            establishmentId: matched.id,
            establishmentName: effectiveName,
            role: effectiveRole,
          );
        } else {
          await AuthStorage.clearSelectedEstablishment();
        }
      }

      final activeEstablishments = profile.establishments
          .where((e) => e.accessActive)
          .toList();

      if (activeEstablishments.length == 1) {
        final single = activeEstablishments.first;

        await AuthStorage.saveSelectedEstablishment(
          establishmentId: single.id,
          establishmentName: single.name,
          role: single.role,
        );

        return _BootstrapState.authorizedWithSelection(
          profile: profile,
          establishmentId: single.id,
          establishmentName: single.name,
          role: single.role,
        );
      }

      return _BootstrapState.authorized(profile: profile);
    } catch (_) {
      await AuthStorage.clearAll();
      return const _BootstrapState.unauthorized();
    }
  }

  Future<void> _retry() async {
    setState(() {
      _future = _resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapState>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppLoadingScreen();
        }

        final state = snapshot.data ?? const _BootstrapState.unauthorized();

        if (state.hasSelectedEstablishment) {
          return StaffHomeScreen(
            establishmentId: state.establishmentId!,
            establishmentName: state.establishmentName!,
            role: state.role!,
          );
        }

        if (state.isAuthorized) {
          return const StaffEstablishmentsScreen();
        }

        if (state.isRevoked) {
          return _AccessRevokedScreen(
            onRetry: _retry,
          );
        }

        return const LoginPhoneScreen();
      },
    );
  }
}

class _BootstrapState {
  final bool isAuthorized;
  final bool isRevoked;
  final AccessProfile? profile;
  final int? establishmentId;
  final String? establishmentName;
  final String? role;

  const _BootstrapState._({
    required this.isAuthorized,
    required this.isRevoked,
    required this.profile,
    required this.establishmentId,
    required this.establishmentName,
    required this.role,
  });

  const _BootstrapState.authorized({AccessProfile? profile})
      : this._(
          isAuthorized: true,
          isRevoked: false,
          profile: profile,
          establishmentId: null,
          establishmentName: null,
          role: null,
        );

  const _BootstrapState.authorizedWithSelection({
    AccessProfile? profile,
    required int establishmentId,
    required String establishmentName,
    required String role,
  }) : this._(
          isAuthorized: true,
          isRevoked: false,
          profile: profile,
          establishmentId: establishmentId,
          establishmentName: establishmentName,
          role: role,
        );

  const _BootstrapState.revoked({AccessProfile? profile})
      : this._(
          isAuthorized: false,
          isRevoked: true,
          profile: profile,
          establishmentId: null,
          establishmentName: null,
          role: null,
        );

  const _BootstrapState.unauthorized()
      : this._(
          isAuthorized: false,
          isRevoked: false,
          profile: null,
          establishmentId: null,
          establishmentName: null,
          role: null,
        );

  bool get hasSelectedEstablishment =>
      establishmentId != null &&
      establishmentName != null &&
      role != null;
}

class _AccessRevokedScreen extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AccessRevokedScreen({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFFFF3F1),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        size: 34,
                        color: Color(0xFFE85B63),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Доступ к приложению отключен',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF103238),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Похоже, доступ был отозван: сотрудник удален из заведения или подписка заведения неактивна.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF58767D),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7D63FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Проверить снова',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await AuthStorage.clearAll();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPhoneScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Выйти',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/flowru_logo.png',
              width: 72,
              height: 72,
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}