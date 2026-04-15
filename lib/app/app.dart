import 'package:flutter/material.dart';

import '../features/auth/data/auth_storage.dart';
import '../features/auth/presentation/screens/login_phone_screen.dart';
import '../features/staff/presentation/screens/staff_establishments_screen.dart';

void mainAppLog(Object error, StackTrace stackTrace) {
  debugPrint('APP START ERROR: $error');
  debugPrintStack(stackTrace: stackTrace);
}

class FlowruStaffApp extends StatelessWidget {
  const FlowruStaffApp({super.key});

  Future<String?> _loadToken() async {
    try {
      return await AuthStorage.getAccessToken();
    } catch (e, st) {
      mainAppLog(e, st);
      return null;
    }
  }

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
      home: FutureBuilder<String?>(
        future: _loadToken(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const LoginPhoneScreen();
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const _AppLoadingScreen();
          }

          final token = snapshot.data;
          if (token != null && token.isNotEmpty) {
            return const StaffEstablishmentsScreen();
          }

          return const LoginPhoneScreen();
        },
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
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.flutter_dash,
                  size: 72,
                  color: Color(0xFF7D63FF),
                );
              },
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