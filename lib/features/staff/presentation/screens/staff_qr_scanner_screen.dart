import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StaffQrScannerScreen extends StatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  State<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<StaffQrScannerScreen> {
  bool _handled = false;
  bool _torchEnabled = false;

  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final rawValue = codes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(rawValue);
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Сканировать QR клиента',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleTorch,
                        icon: Icon(
                          _torchEnabled ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(top: 0, left: 0, child: _corner()),
                        Positioned(top: 0, right: 0, child: _corner(isRight: true)),
                        Positioned(bottom: 0, left: 0, child: _corner(isBottom: true)),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _corner(isRight: true, isBottom: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Наведите камеру на QR клиента.\nПосле считывания клиент откроется автоматически.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Вернуться назад'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({bool isRight = false, bool isBottom = false}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          top: !isBottom ? const BorderSide(color: Colors.greenAccent, width: 5) : BorderSide.none,
          bottom: isBottom ? const BorderSide(color: Colors.greenAccent, width: 5) : BorderSide.none,
          left: !isRight ? const BorderSide(color: Colors.greenAccent, width: 5) : BorderSide.none,
          right: isRight ? const BorderSide(color: Colors.greenAccent, width: 5) : BorderSide.none,
        ),
      ),
    );
  }
}