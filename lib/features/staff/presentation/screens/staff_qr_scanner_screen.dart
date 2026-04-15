import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StaffQrScannerScreen extends StatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  State<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<StaffQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final Barcode? barcode =
        capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final String? rawValue = barcode?.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) return;

    _handled = true;

    Navigator.of(context).pop(rawValue.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              'Наведите камеру на QR-код клиента',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    blurRadius: 6,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}