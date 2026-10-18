import 'dart:math' as math;
import 'package:flutter/material.dart';

const futureInk = Color(0xFF101A35);
const futureAqua = Color(0xFF08BCCB);
const futureSoft = Color(0xFF657997);

class FutureScene extends StatelessWidget {
  final Widget child;
  const FutureScene({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF2FAFF), Color(0xFFF4F1FF), Color(0xFFE9FCFC)],
      ),
    ),
    child: child,
  );
}

class FutureGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? tint;
  const FutureGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tint,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(.82),
          (tint ?? Colors.white).withOpacity(.35),
        ],
      ),
      border: Border.all(color: Colors.white.withOpacity(.95), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF455B86).withOpacity(.045),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class FutureHero extends StatefulWidget {
  final String title, subtitle;
  final double height;
  final String imageAsset;
  const FutureHero({
    super.key,
    required this.title,
    this.subtitle = '',
    this.height = 178,
    this.imageAsset = 'assets/flowru_future/orders.png',
  });
  @override
  State<FutureHero> createState() => _FutureHeroState();
}

class _FutureHeroState extends State<FutureHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_motion.value * math.pi) * 3),
              child: child,
            ),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, .13, .88, 1],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0, .14, .80, 1],
                ).createShader(bounds),
                child: Image.asset(
                  widget.imageAsset,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: .66,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: futureInk,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.9,
                      height: 1.1,
                    ),
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: futureSoft,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class FutureAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const FutureAction({
    super.key,
    required this.label,
    this.onTap,
    this.primary = true,
  });
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1.0,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: primary
            ? const LinearGradient(
                colors: [
                  Color(0xFF55EEE9),
                  Color(0xFF87E5FA),
                  Color(0xFFC0A1FF),
                ],
              )
            : null,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: futureAqua.withOpacity(.14),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: futureInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (primary)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: futureInk,
                    size: 21,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class FutureOption extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  const FutureOption({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.selected,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        colors: selected
            ? [const Color(0xFFE3FFFF), const Color(0xFFCDF6FF)]
            : [Colors.white.withOpacity(.65), Colors.white.withOpacity(.3)],
      ),
      border: Border.all(
        color: selected ? futureAqua.withOpacity(.65) : Colors.white,
        width: 1.3,
      ),
      boxShadow: selected
          ? [BoxShadow(color: futureAqua.withOpacity(.09), blurRadius: 15)]
          : [],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: selected ? futureAqua : futureInk, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: futureInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: futureSoft,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: futureAqua,
                  size: 17,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FutureOrbit extends StatelessWidget {
  final Widget child;
  const FutureOrbit({super.key, required this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 210,
    child: LayoutBuilder(
      builder: (context, size) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.18,
            child: Container(
              width: size.maxWidth,
              height: 155,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF92F6F0).withOpacity(.5),
                    Colors.white.withOpacity(.1),
                    const Color(0xFFC7A7FF).withOpacity(.45),
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: futureAqua.withOpacity(.12), blurRadius: 28),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: .21,
            child: Container(
              width: size.maxWidth - 16,
              height: 174,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFBAFCFF), width: 1.4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: child,
          ),
        ],
      ),
    ),
  );
}
