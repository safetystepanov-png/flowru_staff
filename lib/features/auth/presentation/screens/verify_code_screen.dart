import 'package:flutter/material.dart';

class VerifyCodeScreen extends StatelessWidget {
  final String phone;

  const VerifyCodeScreen({
    super.key,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Экран подтверждения больше не используется: $phone'),
      ),
    );
  }
}