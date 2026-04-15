import 'package:flutter/material.dart';

import 'auth_storage.dart';
import '../presentation/screens/login_phone_screen.dart';

class AuthSession {
  static Future<void> logout(BuildContext context) async {
    await AuthStorage.clearAll();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPhoneScreen()),
      (route) => false,
    );
  }
}