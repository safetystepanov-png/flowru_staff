import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kScheduleMintTop = Color(0xFF0CB7B3);
const Color kScheduleMintMid = Color(0xFF08A9AB);
const Color kScheduleMintBottom = Color(0xFF067D87);
const Color kScheduleMintDeep = Color(0xFF055E66);

const Color kScheduleCard = Color(0xCCFFFFFF);
const Color kScheduleCardStrong = Color(0xE8FFFFFF);
const Color kScheduleStroke = Color(0xA6FFFFFF);

const Color kScheduleInk = Color(0xFF103238);
const Color kScheduleInkSoft = Color(0xFF58767D);

const Color kScheduleBlue = Color(0xFF4E7CFF);
const Color kSchedulePink = Color(0xFFFF5F8F);
const Color kScheduleViolet = Color(0xFF7A63FF);
const Color kScheduleAccent = Color(0xFFFFA11D);

class StaffWorkScheduleScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffWorkScheduleScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffWorkScheduleScreen> createState() => _StaffWorkScheduleScreenState();
}

class _StaffWorkScheduleScreenState extends State<StaffWorkScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  final List<_DayShift> _days = const [
    _DayShift(day: 'Пн', shift: '09:00–18:00', active: true),
    _DayShift(day: 'Вт', shift: '09:00–18:00', active: true),
    _DayShift(day: 'Ср', shift: 'Выходной', active: false),
    _DayShift(day: 'Чт', shift: '12:00–21:00', active: true),
    _DayShift(day: 'Пт', shift: '12:00–21:00', active: true),
    _DayShift(day: 'Сб', shift: '10:00–16:00', active: true),
    _DayShift(day: 'Вс', shift: 'Выходной', active: false),
  ];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
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
        final shiftB = math.cos(t * math.pi * 2) * 12;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kScheduleMintTop,
                    kScheduleMintMid,
                    kScheduleMintBottom,
                    kScheduleMintDeep,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.40, 0.78, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -80 + shiftA,
              right: -40,
              child: _softBlob(
                width: 260,
                height: 260,
                colors: [
                  Colors.white.withOpacity(0.16),
                  kScheduleAccent.withOpacity(0.12),
                ],
              ),
            ),
            Positioned(
              bottom: 40 - shiftB,
              left: -40,
              child: _softBlob(
                width: 220,
                height: 220,
                colors: [
                  kScheduleBlue.withOpacity(0.10),
                  Colors.white.withOpacity(0.06),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScheduleMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'График работы',
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _GlassCard(
                    radius: 30,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.establishmentName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: kScheduleInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID заведения: ${widget.establishmentId}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kScheduleInkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GlassCard(
                    radius: 32,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Текущий месяц',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: kScheduleInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Пока это базовая версия экрана. Позже сюда можно будет подключить реальные смены из базы.',
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.42,
                            fontWeight: FontWeight.w700,
                            color: kScheduleInkSoft,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ..._days.map(
                          (day) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withOpacity(0.88),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.94),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: day.active
                                            ? const [kScheduleBlue, kScheduleViolet]
                                            : [
                                                Colors.grey.shade400,
                                                Colors.grey.shade500,
                                              ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        day.day,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      day.shift,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: kScheduleInk,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    day.active
                                        ? CupertinoIcons.check_mark_circled_solid
                                        : CupertinoIcons.minus_circle,
                                    color: day.active
                                        ? const Color(0xFF22C55E)
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                kScheduleCardStrong,
                kScheduleCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kScheduleStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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

class _DayShift {
  final String day;
  final String shift;
  final bool active;

  const _DayShift({
    required this.day,
    required this.shift,
    required this.active,
  });
}