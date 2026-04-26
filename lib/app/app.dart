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

    // Инициализация побуквенных анимаций — логика сохранена.
    final letters = 'FLOWRU STAFF';
    for (int i = 0; i < letters.length; i++) {
      final delay = i * 0.08;
      final start = (0.01 + delay * 0.7).clamp(0.01, 0.70);
      final end = (start + 0.15).clamp(0.02, 0.95);

      final weight1 = start.clamp(0.01, 0.98);
      final weight2 = (end - start).clamp(0.01, 0.50);
      final weight3 = (1.0 - end).clamp(0.01, 0.98);

      _letterAnimations.add(
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 0.0).chain(
              CurveTween(curve: Curves.easeOutCubic),
            ),
            weight: weight1,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: Curves.easeOutCubic),
            ),
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
            tween: Tween<double>(begin: 0.3, end: 1.0).chain(
              CurveTween(curve: Curves.easeOutBack),
            ),
            weight: weight2,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.0),
            weight: weight3,
          ),
        ]).animate(_letterController),
      );
    }

    // Запуск анимаций с вибрацией — логика сохранена.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    for (int i = 0; i < 22; i++) {
      _decorElements.add(
        _DecorElement(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: 2 + random.nextDouble() * 6,
          speed: 0.3 + random.nextDouble() * 0.7,
          phase: random.nextDouble() * math.pi * 2,
          opacity: 0.10 + random.nextDouble() * 0.34,
          isStar: random.nextBool(),
        ),
      );
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
    double blur = 26,
  }) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: colors,
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
        final shiftA = math.sin(t * math.pi * 2) * 22;
        final shiftB = math.cos(t * math.pi * 2) * 18;
        final shiftC = math.sin(t * math.pi * 2 + 1.5) * 15;

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(
                        const Color(0xFF32DDC6),
                        const Color(0xFF10B4BA),
                        (math.sin(t * math.pi) * 0.5 + 0.5).clamp(0.0, 1.0),
                      )!,
                      const Color(0xFF0CA9AE),
                      const Color(0xFF078592),
                      Color.lerp(
                        const Color(0xFF055E66),
                        const Color(0xFF063F51),
                        (math.cos(t * math.pi) * 0.5 + 0.5).clamp(0.0, 1.0),
                      )!,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    stops: const [0.0, 0.36, 0.68, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.65, -0.96),
                    radius: 1.12,
                    colors: [
                      const Color(0xFFE9FFD7).withOpacity(0.42),
                      const Color(0xFF7AF4DF).withOpacity(0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.32, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.95, 1.0),
                    radius: 1.12,
                    colors: [
                      const Color(0xFF042F43).withOpacity(0.38),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -105 + shiftA,
              right: -70,
              child: _softBlob(
                width: 340,
                height: 340,
                colors: [
                  Colors.white.withOpacity(0.22),
                  const Color(0xFFFFC45E).withOpacity(0.10),
                  Colors.transparent,
                ],
                blur: 36,
              ),
            ),
            Positioned(
              left: -85,
              top: 205 + shiftB,
              child: _softBlob(
                width: 270,
                height: 270,
                colors: [
                  Colors.white.withOpacity(0.12),
                  const Color(0xFF7D63FF).withOpacity(0.13),
                  Colors.transparent,
                ],
                blur: 36,
              ),
            ),
            Positioned(
              bottom: 22 - shiftC,
              right: -60,
              child: _softBlob(
                width: 300,
                height: 300,
                colors: [
                  const Color(0xFFFFC45E).withOpacity(0.12),
                  Colors.white.withOpacity(0.07),
                  Colors.transparent,
                ],
                blur: 38,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _BackgroundRingPainter(progress: _ambientController.value),
              ),
            ),
            ..._buildDecorElements(),
          ],
        );
      },
    );
  }

  List<Widget> _buildDecorElements() {
    final mediaSize = MediaQuery.of(context).size;
    final animT = _decorationsController.value;

    return _decorElements.map((el) {
      final floatY = math.sin(animT * math.pi * 2 * el.speed + el.phase) * 25;
      final floatX =
          math.cos(animT * math.pi * 2 * el.speed * 0.7 + el.phase) * 15;
      final pulse = (0.5 +
              0.5 * math.sin(animT * math.pi * 2 * el.speed + el.phase + 1))
          .clamp(0.0, 1.0);

      return Positioned(
        left: (el.x * mediaSize.width + floatX).clamp(0.0, mediaSize.width),
        top: (el.y * mediaSize.height + floatY).clamp(0.0, mediaSize.height),
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
        color: Colors.white.withOpacity(0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.24),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _logoCore() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _pulseController, _decorationsController]),
      builder: (context, child) {
        final pulse = _pulseController.value;
        final glowScale = 1.0 + (pulse * 0.08);
        final glowOpacity = 0.25 + ((1 - pulse) * 0.12);
        final ringRotation = _decorationsController.value * math.pi * 2;

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
              width: 246,
              height: 246,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: glowScale,
                    child: Container(
                      width: 184,
                      height: 184,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC45E).withOpacity(glowOpacity),
                            blurRadius: 76,
                            spreadRadius: 18,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.14),
                            blurRadius: 46,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFF7D63FF).withOpacity(glowOpacity * 0.42),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: ringRotation * 0.18,
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: _RotatingRingPainter(
                        progress: _decorationsController.value,
                      ),
                    ),
                  ),
                  Container(
                    width: 176,
                    height: 176,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.26),
                          Colors.white.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.34),
                        width: 1.3,
                      ),
                    ),
                  ),
                  Container(
                    width: 154,
                    height: 154,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFD861),
                          Color(0xFFFFB22E),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA11D).withOpacity(0.42),
                          blurRadius: 34,
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/flowru_logo.png',
                        width: 88,
                        height: 88,
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

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
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
                      ? const SizedBox(width: 12)
                      : Text(
                          char,
                          style: const TextStyle(
                            fontSize: 39,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                            color: Colors.white,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Color(0x33000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                ),
              );
            },
          );
        }),
      ),
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
              maxLines: 2,
              style: TextStyle(
                fontSize: 21,
                height: 1.22,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
                color: Colors.white.withOpacity(0.84),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
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
          child: SizedBox(
            width: 420,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withOpacity(0.13),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return FractionallySizedBox(
                          widthFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            height: 7,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFFA11D),
                                  Color(0xFFFFD861),
                                  Color(0xFFFFA11D),
                                ],
                                stops: [0.0, 0.52, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 178,
                  child: IgnorePointer(
                    child: Container(
                      width: 72,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.46),
                            Colors.transparent,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -18),
                      child: _logoCore(),
                    ),
                    const SizedBox(height: 22),
                    _titleBlock(),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _subtitleBlock(),
                    ),
                    const SizedBox(height: 78),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: _loaderLine(),
                    ),
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
    const points = 4;

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
    final radius = size.width / 2 - 8;

    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.31)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFC45E).withOpacity(0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.9
      ..strokeCap = StrokeCap.round;

    final softPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2 + 0.25,
      math.pi * 1.15,
      false,
      basePaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 16),
      progress * math.pi * 2 + 1.45,
      math.pi * 0.95,
      false,
      softPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2 + math.pi + 0.18,
      math.pi * 0.46,
      false,
      goldPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2 - 0.86,
      math.pi * 0.32,
      false,
      goldPaint,
    );

    final whiteDotPaint = Paint()
      ..color = Colors.white.withOpacity(0.86)
      ..style = PaintingStyle.fill;

    final goldDotPaint = Paint()
      ..color = const Color(0xFFFFC45E).withOpacity(0.94)
      ..style = PaintingStyle.fill;

    void drawDot(double angle, Paint paint, double dotRadius) {
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }

    drawDot(progress * math.pi * 2 + 0.18, whiteDotPaint, 4.4);
    drawDot(progress * math.pi * 2 + math.pi + 0.64, goldDotPaint, 4.1);
    drawDot(progress * math.pi * 2 - 0.54, goldDotPaint, 3.2);
  }

  @override
  bool shouldRepaint(covariant _RotatingRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BackgroundRingPainter extends CustomPainter {
  final double progress;

  _BackgroundRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final centerA = Offset(size.width * 0.86, size.height * 0.28);
    final centerB = Offset(size.width * 0.18, size.height * 0.72);

    canvas.drawArc(
      Rect.fromCircle(center: centerA, radius: 118),
      progress * math.pi * 2,
      math.pi * 0.72,
      false,
      ringPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: centerA, radius: 150),
      progress * math.pi * 2 + 1.2,
      math.pi * 0.56,
      false,
      ringPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: centerB, radius: 132),
      -progress * math.pi * 2 + 0.8,
      math.pi * 0.62,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundRingPainter oldDelegate) =>
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
