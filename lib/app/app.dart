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
      routes: {
        '/login': (context) => const LoginPhoneScreen(),
      },
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
  late final AnimationController _particlesController;
  late final AnimationController _letterController;
  late final AnimationController _decorationsController;
  
  final List<Animation<double>> _letterAnimations = [];
  final List<Animation<double>> _letterScales = [];
  final List<_DecorElement> _decorElements = [];

  Timer? _timer;
  bool _moved = false;

  @override
  void initState() {
    super.initState();

    _initDecorElements();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _letterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _decorationsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // Инициализация побуквенных анимаций - ИСПРАВЛЕНО
    final letters = 'FLOWRU STAFF';
    for (int i = 0; i < letters.length; i++) {
      final delay = i * 0.08;
      final start = (0.01 + delay * 0.7).clamp(0.01, 0.70);
      final end = (start + 0.15).clamp(0.02, 0.95);
      
      // Гарантируем что веса всегда > 0 и сумма = 1.0
      final weight1 = start.clamp(0.01, 0.98);
      final weight2 = (end - start).clamp(0.01, 0.50);
      final weight3 = (1.0 - end).clamp(0.01, 0.98);
      
      _letterAnimations.add(
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: weight1,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: weight2,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.0),
            weight: weight3,
          ),
        ]).animate(_letterController),
      );
      
      _letterScales.add(
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.3, end: 0.3),
            weight: weight1,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.3, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: weight2,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.0),
            weight: weight3,
          ),
        ]).animate(_letterController),
      );
    }

    // Запуск анимаций с вибрацией
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Легкая вибрация при загрузке
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.selectionClick();
      
      await _logoController.forward();
      if (!mounted) return;
      
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      
      await _letterController.forward();
    });

    _timer = Timer(const Duration(milliseconds: 2800), _goNext);
  }

  void _initDecorElements() {
    final random = math.Random(42);
    for (int i = 0; i < 18; i++) {
      _decorElements.add(_DecorElement(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 2 + random.nextDouble() * 6,
        speed: 0.3 + random.nextDouble() * 0.7,
        phase: random.nextDouble() * math.pi * 2,
        opacity: 0.1 + random.nextDouble() * 0.4,
        isStar: random.nextBool(),
      ));
    }
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
    _particlesController.dispose();
    _letterController.dispose();
    _decorationsController.dispose();
    super.dispose();
  }

  Widget _softBlob({
    required double width,
    required double height,
    required List<Color> colors,
    double blur = 18,
  }) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
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
      animation: Listenable.merge([_ambientController, _particlesController]),
      builder: (context, child) {
        final t = _ambientController.value;
        final p = _particlesController.value;
        
        final shiftA = math.sin(t * math.pi * 2) * 22;
        final shiftB = math.cos(t * math.pi * 2) * 18;
        final shiftC = math.sin(t * math.pi * 2 + 1.5) * 15;
        final rotate = math.sin(t * math.pi * 2) * 0.035;

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(
                      const Color(0xFF0CB7B3),
                      const Color(0xFF0898AB),
                      (math.sin(t * math.pi) * 0.5 + 0.5).clamp(0.0, 1.0),
                    )!,
                    const Color(0xFF08A9AB),
                    const Color(0xFF067D87),
                    Color.lerp(
                      const Color(0xFF055E66),
                      const Color(0xFF074D5A),
                      (math.cos(t * math.pi) * 0.5 + 0.5).clamp(0.0, 1.0),
                    )!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
            
            // УБРАНА СЕРАЯ ПЛАШКА - только легкий оверлей
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            Positioned(
              top: -90 + shiftA,
              right: -40,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 280,
                  height: 280,
                  colors: [
                    Colors.white.withOpacity(0.20),
                    const Color(0xFFFFA11D).withOpacity(0.14),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -70,
              top: 200 + shiftB,
              child: Transform.rotate(
                angle: -rotate * 1.2,
                child: _softBlob(
                  width: 240,
                  height: 240,
                  colors: [
                    Colors.white.withOpacity(0.12),
                    const Color(0xFF7D63FF).withOpacity(0.14),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20 - shiftC,
              right: -20,
              child: Transform.rotate(
                angle: rotate * 0.8,
                child: _softBlob(
                  width: 240,
                  height: 240,
                  colors: [
                    const Color(0xFFFFC45E).withOpacity(0.12),
                    Colors.white.withOpacity(0.06),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -40 + shiftA * 0.5,
              left: -30,
              child: Transform.rotate(
                angle: -rotate * 0.6,
                child: _softBlob(
                  width: 200,
                  height: 200,
                  colors: [
                    const Color(0xFF7D63FF).withOpacity(0.10),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
              ),
            ),

            ..._buildDecorElements(p),
          ],
        );
      },
    );
  }

  List<Widget> _buildDecorElements(double p) {
    return _decorElements.asMap().entries.map((entry) {
      final i = entry.key;
      final el = entry.value;
      
      final animT = _decorationsController.value;
      final floatY = math.sin(animT * math.pi * 2 * el.speed + el.phase) * 25;
      final floatX = math.cos(animT * math.pi * 2 * el.speed * 0.7 + el.phase) * 15;
      final pulse = (0.5 + 0.5 * math.sin(animT * math.pi * 2 * el.speed + el.phase + 1)).clamp(0.0, 1.0);
      
      return Positioned(
        left: (el.x * MediaQuery.of(context).size.width + floatX).clamp(0, MediaQuery.of(context).size.width),
        top: (el.y * MediaQuery.of(context).size.height + floatY).clamp(0, MediaQuery.of(context).size.height),
        child: Opacity(
          opacity: (el.opacity * (0.5 + pulse * 0.5)).clamp(0.0, 1.0),
          child: el.isStar
              ? _buildStar(el.size * (0.8 + pulse * 0.4))
              : _buildCircle(el.size * (0.8 + pulse * 0.4)),
        ),
      );
    }).toList();
  }

  Widget _buildStar(double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(),
    );
  }

  Widget _buildCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
    );
  }

  Widget _logoCore() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _pulseController]),
      builder: (context, child) {
        final pulse = _pulseController.value;
        final glowScale = 1.0 + (pulse * 0.22);
        final glowOpacity = 0.25 + ((1 - pulse) * 0.12);
        final ringRotation = pulse * math.pi * 2;

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _logoController,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(
                parent: _logoController,
                curve: Curves.easeOutBack,
              ),
            ),
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: ringRotation * 0.5,
                    child: CustomPaint(
                      size: const Size(170, 170),
                      painter: _RotatingRingPainter(
                        progress: _pulseController.value,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: glowScale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFA11D).withOpacity(glowOpacity),
                            blurRadius: 50,
                            spreadRadius: 12,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.12),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: const Color(0xFF7D63FF).withOpacity(glowOpacity * 0.5),
                            blurRadius: 35,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 152,
                    height: 152,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.28),
                          Colors.white.withOpacity(0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 124,
                    height: 124,
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
                          color: const Color(0xFFFFA11D).withOpacity(0.38),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/flowru_logo.png',
                        width: 66,
                        height: 66,
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
    final letters = 'FLOWRU STAFF';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (index) {
        final char = letters[index];
        
        return AnimatedBuilder(
          animation: _letterController,
          builder: (context, child) {
            final opacity = _letterAnimations[index].value;
            final scale = _letterScales[index].value;
            
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: char == ' '
                    ? const SizedBox(width: 8)
                    : Text(
                        char,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _subtitleBlock() {
    return AnimatedBuilder(
      animation: _letterController,
      builder: (context, child) {
        final progress = _letterController.value;
        final subtitleOpacity = ((progress - 0.6) * 2.5).clamp(0.0, 1.0);
        final subtitleSlide = (1.0 - subtitleOpacity) * 12;
        
        return Opacity(
          opacity: subtitleOpacity,
          child: Transform.translate(
            offset: Offset(0, subtitleSlide),
            child: Text(
              'Система лояльности для команды заведения',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.82),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _loaderLine() {
    return AnimatedBuilder(
      animation: _letterController,
      builder: (context, child) {
        final progress = _letterController.value;
        final lineOpacity = ((progress - 0.7) * 2.0).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: lineOpacity,
          child: Container(
            width: 140,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1300),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFA11D),
                              Color(0xFFFFC45E),
                              Color(0xFFFFA11D),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _logoCore(),
                    const SizedBox(height: 32),
                    _titleBlock(),
                    const SizedBox(height: 12),
                    _subtitleBlock(),
                    const SizedBox(height: 32),
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

class _DecorElement {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
  final double opacity;
  final bool isStar;

  _DecorElement({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.isStar,
  });
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.4;
    final points = 4;

    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi) / points - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RotatingRingPainter extends CustomPainter {
  final double progress;

  _RotatingRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    final paint1 = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2,
      math.pi * 0.6,
      false,
      paint1,
    );

    final paint2 = Paint()
      ..color = const Color(0xFFFFA11D).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2 + math.pi,
      math.pi * 0.4,
      false,
      paint2,
    );

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    final dotAngle = progress * math.pi * 2;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);
    canvas.drawCircle(Offset(dotX, dotY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RotatingRingPainter oldDelegate) => 
      oldDelegate.progress != progress;
}

// ==========================================
// ОСТАЛЬНОЙ КОД БЕЗ ИЗМЕНЕНИЙ
// ==========================================

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