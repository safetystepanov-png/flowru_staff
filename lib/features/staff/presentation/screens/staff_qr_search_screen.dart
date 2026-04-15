import 'package:flutter/material.dart';

class StaffQrSearchScreen extends StatelessWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffQrSearchScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск по QR'),
      ),
      body: const Center(
        child: Text(
          'Поиск по QR временно отключён',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}