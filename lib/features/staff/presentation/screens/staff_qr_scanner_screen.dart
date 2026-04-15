import 'package:flutter/cupertino.dart';
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
  bool _torchEnabled = false;

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

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();

    if (!mounted) return;

    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.45),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.35),
                ],
                stops: const [0.0, 0.18, 0.72, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      _TopButton(
                        icon: CupertinoIcons.back,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Сканер QR',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      _TopButton(
                        icon: _torchEnabled
                            ? CupertinoIcons.flashlight_on_fill
                            : CupertinoIcons.flashlight_off_fill,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Наведите камеру на QR-код клиента',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const Spacer(),

                Center(
                  child: Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      children: [
                        _CornerAlign(
                          alignment: Alignment.topLeft,
                          child: _ScanCorner(),
                        ),
                        _CornerAlign(
                          alignment: Alignment.topRight,
                          child: const RotatedBox(
                            quarterTurns: 1,
                            child: _ScanCorner(),
                          ),
                        ),
                        _CornerAlign(
                          alignment: Alignment.bottomLeft,
                          child: const RotatedBox(
                            quarterTurns: 3,
                            child: _ScanCorner(),
                          ),
                        ),
                        _CornerAlign(
                          alignment: Alignment.bottomRight,
                          child: const RotatedBox(
                            quarterTurns: 2,
                            child: _ScanCorner(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Держите QR-код внутри рамки для быстрого считывания',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.14),
          border: Border.all(
            color: Colors.white.withOpacity(0.20),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _ScanCornerPainter(),
      ),
    );
  }
}

class _CornerAlign extends StatelessWidget {
  final Alignment alignment;
  final Widget child;

  const _CornerAlign({
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: child,
      ),
    );
  }
}

class _ScanCornerPainter extends CustomPainter {
  const _ScanCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width, 2)
      ..lineTo(2, 2)
      ..lineTo(2, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}