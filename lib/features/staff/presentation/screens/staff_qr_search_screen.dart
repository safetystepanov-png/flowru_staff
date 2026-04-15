
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'staff_design_system.dart';
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
      MaterialPageRoute(builder: (_) => const StaffQrScannerScreen()),
    );

    if (!mounted) return;

    if (result != null && result.trim().isNotEmpty) {
      setState(() => _lastQr = result.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR считан: $_lastQr')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StaffUnifiedScaffold(
      title: 'Поиск по QR',
      useList: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.establishmentName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kHomeInk)),
                const SizedBox(height: 6),
                Text('ID заведения: ${widget.establishmentId}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kHomeInkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StaffGlassCard(
            glow: kHomeBlue,
            child: Column(
              children: [
                const StaffFloatingGlyph(icon: CupertinoIcons.qrcode_viewfinder, mainColor: kHomeBlue, secondaryColor: kHomeMintTop, size: 90, iconSize: 40),
                const SizedBox(height: 14),
                const Text('Открыть сканер QR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kHomeInk)),
                const SizedBox(height: 8),
                const Text('Наведи камеру на код клиента', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w700, color: kHomeInkSoft)),
                const SizedBox(height: 16),
                StaffPillButton(text: 'Запустить сканер', icon: CupertinoIcons.camera_viewfinder, onTap: _startScan, colors: const [kHomeBlue, kHomeViolet]),
              ],
            ),
          ),
          if (_lastQr != null) ...[
            const SizedBox(height: 16),
            StaffGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Последний считанный QR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kHomeInk)),
                  const SizedBox(height: 10),
                  SelectableText(_lastQr!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kHomeInkSoft)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
