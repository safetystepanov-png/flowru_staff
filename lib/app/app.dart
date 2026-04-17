import 'package:flutter/material.dart';

import '../features/auth/data/auth_storage.dart';
import '../features/auth/data/user_api.dart';
import '../features/auth/presentation/screens/login_phone_screen.dart';
import '../features/staff/presentation/screens/staff_establishments_screen.dart';

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
      home: const _AppBootstrapScreen(),
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

  const _BootstrapState._({
    required this.isAuthorized,
    required this.isRevoked,
    required this.profile,
  });

  const _BootstrapState.authorized({AccessProfile? profile})
      : this._(isAuthorized: true, isRevoked: false, profile: profile);

  const _BootstrapState.revoked({AccessProfile? profile})
      : this._(isAuthorized: false, isRevoked: true, profile: profile);

  const _BootstrapState.unauthorized()
      : this._(isAuthorized: false, isRevoked: false, profile: null);
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
