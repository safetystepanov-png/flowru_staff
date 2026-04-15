import 'package:flutter/material.dart';

import 'staff_qr_scanner_screen.dart';

class StaffQrSearchScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffQrSearchScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffQrSearchScreen> createState() => _StaffQrSearchScreenState();
}

class _StaffQrSearchScreenState extends State<StaffQrSearchScreen> {
  String? _lastQr;

  Future<void> _startScan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const StaffQrScannerScreen(),
      ),
    );

    if (!mounted) return;

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _lastQr = result.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR считан: $_lastQr')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск по QR'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.establishmentName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID заведения: ${widget.establishmentId}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startScan,
              child: const Text('Открыть сканер QR'),
            ),
            const SizedBox(height: 24),
            if (_lastQr != null) ...[
              const Text(
                'Последний считанный QR:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _lastQr!,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}