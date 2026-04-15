import 'dart:ui';

import 'package:flutter/material.dart';

const Color kStaffBgTop = Color(0xFFF4F7FC);
const Color kStaffBgBottom = Color(0xFFF7F1FB);

const Color kStaffInkPrimary = Color(0xFF1E2333);
const Color kStaffInkSecondary = Color(0xFF7A8197);

const Color kStaffBlue = Color(0xFF7A8DFF);
const Color kStaffPink = Color(0xFFFF87BD);
const Color kStaffPurple = Color(0xFFA38BFF);
const Color kStaffViolet = kStaffPurple;

const Color kStaffBorder = Color(0xFFE7EAF4);

const String kFlowruLogoAsset = 'assets/images/flowru_logo.png';

class StaffScreenBackground extends StatelessWidget {
  final Widget child;

  const StaffScreenBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    Widget orb({
      required double s,
      required Color color,
      required double top,
      required double left,
    }) {
      return Positioned(
        top: top,
        left: left,
        child: IgnorePointer(
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kStaffBgTop, kStaffBgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          orb(
            s: 180,
            color: kStaffPink.withOpacity(0.10),
            top: -30,
            left: size.width - 120,
          ),
          orb(
            s: 160,
            color: kStaffBlue.withOpacity(0.08),
            top: 190,
            left: -30,
          ),
          orb(
            s: 140,
            color: kStaffPurple.withOpacity(0.07),
            top: size.height - 210,
            left: size.width - 120,
          ),
          child,
        ],
      ),
    );
  }
}

class StaffSoftPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;
  final VoidCallback? onTap;

  const StaffSoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.glowColor,
    this.onTap,
  });

  @override
  State<StaffSoftPanel> createState() => _StaffSoftPanelState();
}

class _StaffSoftPanelState extends State<StaffSoftPanel> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: Colors.white.withOpacity(0.76),
            border: Border.all(
              color: Colors.white.withOpacity(0.92),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: (widget.glowColor ?? kStaffBlue).withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.988 : 1,
        child: card,
      ),
    );
  }
}

class StaffGlassPanel extends StaffSoftPanel {
  const StaffGlassPanel({
    super.key,
    required super.child,
    super.padding = const EdgeInsets.all(16),
    super.radius = 24,
    super.glowColor,
    super.onTap,
  });
}

class StaffGradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const StaffGradientIcon({
    super.key,
    required this.icon,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 18,
      height: size + 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular((size + 18) / 2.8),
        gradient: const LinearGradient(
          colors: [kStaffBlue, kStaffPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kStaffBlue.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: size,
      ),
    );
  }
}

class StaffLogoBadge extends StatelessWidget {
  final double size;

  const StaffLogoBadge({
    super.key,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          kFlowruLogoAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Text(
              'Flowru',
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w900,
                color: kStaffInkPrimary,
              ),
            );
          },
        ),
      ),
    );
  }
}

class StaffSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const StaffSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: kStaffInkPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kStaffInkSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}