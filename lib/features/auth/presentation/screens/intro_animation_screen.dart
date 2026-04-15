import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'login_phone_screen.dart';

class IntroAnimationScreen extends StatefulWidget {
  const IntroAnimationScreen({super.key});

  @override
  State<IntroAnimationScreen> createState() => _IntroAnimationScreenState();
}

class _IntroAnimationScreenState extends State<IntroAnimationScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;
  bool _ready = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/video/flowru_intro.mp4',
      );

      _controller = controller;

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1.0);

      controller.addListener(() {
        if (!mounted || _navigated || !controller.value.isInitialized) return;

        final position = controller.value.position;
        final duration = controller.value.duration;

        if (duration.inMilliseconds > 0 &&
            position >= duration - const Duration(milliseconds: 120)) {
          _goNext();
        }
      });

      if (!mounted) return;

      setState(() {
        _ready = true;
      });

      await controller.play();

      _fallbackTimer = Timer(const Duration(seconds: 7), _goNext);
    } catch (_) {
      _goNext();
    }
  }

  void _goNext() {
    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPhoneScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
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
    _fallbackTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: !_ready || controller == null || !controller.value.isInitialized
            ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                ),
              )
            : FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
      ),
    );
  }
}