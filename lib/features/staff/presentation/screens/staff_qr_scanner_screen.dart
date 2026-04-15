import 'package:flutter/material.dart';

class StaffQrScannerScreen extends StatelessWidget {
  const StaffQrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер QR'),
      ),
      body: const Center(
        child: Text(
          'QR-сканер временно отключён',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}