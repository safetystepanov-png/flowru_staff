
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kHomeMintTop = Color(0xFF0CB7B3);
const Color kHomeMintMid = Color(0xFF08A9AB);
const Color kHomeMintBottom = Color(0xFF067D87);
const Color kHomeMintDeep = Color(0xFF055E66);

const Color kHomeAccent = Color(0xFFFFA11D);
const Color kHomeAccentSoft = Color(0xFFFFC45E);
const Color kHomeAccentRed = Color(0xFFFF6A5E);

const Color kHomeCard = Color(0xCCFFFFFF);
const Color kHomeCardStrong = Color(0xE8FFFFFF);
const Color kHomeStroke = Color(0xA6FFFFFF);

const Color kHomeInk = Color(0xFF103238);
const Color kHomeInkSoft = Color(0xFF58767D);
const Color kHomeShadow = Color(0x22062E36);

const Color kHomeBlue = Color(0xFF4E7CFF);
const Color kHomePink = Color(0xFFFF5F8F);
const Color kHomeViolet = Color(0xFF7A63FF);

class StaffUnifiedScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final bool safeTop;
  final bool useList;
  final EdgeInsetsGeometry padding;

  const StaffUnifiedScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onRefresh,
    this.safeTop = true,
    this.useList = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    Widget content = useList
        ? ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: padding,
            children: [child],
          )
        : Padding(padding: padding, child: child);

    if (onRefresh != null) {
      content = RefreshIndicator(
        color: kHomeViolet,
        backgroundColor: Colors.white,
        onRefresh: onRefresh!,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: kHomeMintTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            const StaffUnifiedBackground(),
            SafeArea(
              top: safeTop,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        _TopButton(
                          icon: CupertinoIcons.back,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        ...?actions,
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffUnifiedBackground extends StatelessWidget {
  const StaffUnifiedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kHomeMintTop, kHomeMintMid, kHomeMintBottom, kHomeMintDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, .4, .78, 1],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: _blob(280, [Colors.white24, Color(0x26FFA11D)]),
        ),
        Positioned(
          top: 220,
          left: -60,
          child: _blob(220, [Colors.white10, Color(0x154E7CFF)]),
        ),
        Positioned(
          bottom: 40,
          right: -20,
          child: _blob(200, [Color(0x24FFC45E), Colors.white10]),
        ),
      ],
    );
  }

  Widget _blob(double size, List<Color> colors) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      ),
    );
  }
}

class StaffGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? gradient;
  final Color? glow;

  const StaffGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.gradient,
    this.glow,
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
              colors: gradient ?? [kHomeCardStrong, kHomeCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kHomeStroke),
            boxShadow: [
              BoxShadow(
                color: (glow ?? kHomeShadow).withOpacity(glow == null ? 0.10 : 0.18),
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

class StaffSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const StaffSectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.82))),
      ],
    );
  }
}

class StaffPillButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final List<Color>? colors;

  const StaffPillButton({
    super.key,
    required this.text,
    this.icon,
    this.onTap,
    this.loading = false,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors ?? const [kHomeAccent, kHomeAccentSoft];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: c),
        boxShadow: [
          BoxShadow(
            color: c.first.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5)),
                ],
              ),
      ),
    );
  }
}

class StaffInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const StaffInfoChip({super.key, required this.label, required this.value, this.color = kHomeBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.11),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kHomeInkSoft, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: kHomeInk, fontSize: 14)),
        ],
      ),
    );
  }
}

class StaffStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color glow;
  const StaffStateCard({super.key, required this.icon, required this.title, required this.subtitle, this.glow = kHomeBlue});

  @override
  Widget build(BuildContext context) {
    return StaffGlassCard(
      glow: glow,
      child: Column(
        children: [
          StaffFloatingGlyph(icon: icon, mainColor: glow, secondaryColor: glow == kHomeBlue ? kHomeMintTop : kHomeViolet, size: 82, iconSize: 34),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kHomeInk)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4, color: kHomeInkSoft, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class StaffFloatingGlyph extends StatelessWidget {
  final IconData icon;
  final Color mainColor;
  final Color secondaryColor;
  final double size;
  final double iconSize;
  const StaffFloatingGlyph({
    super.key,
    required this.icon,
    required this.mainColor,
    required this.secondaryColor,
    this.size = 76,
    this.iconSize = 32,
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
              gradient: LinearGradient(colors: [mainColor.withOpacity(0.22), secondaryColor.withOpacity(0.16)]),
            ),
          ),
          Container(
            width: size * .74,
            height: size * .74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.88),
              boxShadow: [BoxShadow(color: mainColor.withOpacity(.20), blurRadius: 16, offset: const Offset(0, 8))],
            ),
          ),
          Container(
            width: size * .56,
            height: size * .56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [mainColor, secondaryColor]),
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
          Positioned(
            top: size * .12,
            right: size * .13,
            child: Container(width: size * .14, height: size * .14, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.92))),
          ),
        ],
      ),
    );
  }
}

class StaffTextFieldCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  const StaffTextFieldCard({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.94),
        border: Border.all(color: const Color(0xFFE7EEF0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: const TextStyle(color: kHomeInk, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: kHomeInkSoft, fontWeight: FontWeight.w700),
          prefixIcon: prefix,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}
