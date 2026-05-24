from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_qr_scanner_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_SCANNER_OVERLAY_CLASS_FIXED_NO_CORNERS_20260523"

start = text.find("class _ScannerOverlayPainter extends CustomPainter")
if start < 0:
    raise SystemExit("ERROR: _ScannerOverlayPainter class not found")

new_class = r'''class _ScannerOverlayPainter extends CustomPainter {
  final double scanSize;
  final Color accentColor;

  const _ScannerOverlayPainter({
    required this.scanSize,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);

    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;

    final cutoutRect = Rect.fromLTWH(left, top, scanSize, scanSize);
    final cutout = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(36)),
      );

    final path = Path.combine(PathOperation.difference, overlay, cutout);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.50)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanSize != scanSize ||
        oldDelegate.accentColor != accentColor;
  }
}
'''

text = text[:start] + new_class + f"\n\n// {marker}\n"

path.write_text(text, encoding="utf-8")
print("OK: scanner overlay class fixed, orange corners removed")
