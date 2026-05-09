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
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    _handled = true;
    Navigator.of(context).pop(raw.trim());
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    const scanSize = 268.0;

    return Scaffold(
      backgroundColor: const Color(0xFF061D26),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF03131A).withOpacity(0.78),
                    const Color(0xFF062632).withOpacity(0.40),
                    const Color(0xFF03131A).withOpacity(0.86),
                  ],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerFramePainter(scanSize: scanSize),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: CupertinoIcons.chevron_left,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: _torchOn
                            ? CupertinoIcons.bolt_fill
                            : CupertinoIcons.bolt,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),

                  const SizedBox(height: 34),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white.withOpacity(0.14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D6C9).withOpacity(0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Сканируйте Flowru QR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Клиент показывает общий QR на главном экране приложения. Система сама найдёт клиента в этом заведении.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xDDEAFBFF),
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: scanSize,
                    height: scanSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(38),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00D6C9).withOpacity(0.22),
                                blurRadius: 36,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const _ScannerCorners(),
                        const _ScannerLine(),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.info_circle_fill,
                          color: Color(0xFFFFD166),
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'После сканирования откроется карточка клиента: начисление, списание, история и награды.',
                            style: TextStyle(
                              color: Color(0xEFFFFFFF),
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ScannerCorners extends StatelessWidget {
  const _ScannerCorners();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerCornersPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerLine extends StatefulWidget {
  const _ScannerLine();

  @override
  State<_ScannerLine> createState() => _ScannerLineState();
}

class _ScannerLineState extends State<_ScannerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final top = 34 + (200 * _animation.value);

        return Positioned(
          top: top,
          left: 28,
          right: 28,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [
                  Color(0x0000D6C9),
                  Color(0xFF00D6C9),
                  Color(0xFFFFD166),
                  Color(0x0000D6C9),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D6C9).withOpacity(0.55),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D6C9)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const radius = 34.0;
    const len = 48.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.fill,
    );

    canvas.drawLine(const Offset(24, 0), const Offset(24 + len, 0), paint);
    canvas.drawLine(const Offset(0, 24), const Offset(0, 24 + len), paint);

    canvas.drawLine(Offset(size.width - 24, 0), Offset(size.width - 24 - len, 0), paint);
    canvas.drawLine(Offset(size.width, 24), Offset(size.width, 24 + len), paint);

    canvas.drawLine(Offset(24, size.height), Offset(24 + len, size.height), paint);
    canvas.drawLine(Offset(0, size.height - 24), Offset(0, size.height - 24 - len), paint);

    canvas.drawLine(Offset(size.width - 24, size.height), Offset(size.width - 24 - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - 24), Offset(size.width, size.height - 24 - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerFramePainter extends CustomPainter {
  final double scanSize;

  const _ScannerFramePainter({required this.scanSize});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);

    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2 + 16;

    final cutout = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanSize, scanSize),
          const Radius.circular(38),
        ),
      );

    final path = Path.combine(PathOperation.difference, overlay, cutout);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.16)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.scanSize != scanSize;
  }
}
