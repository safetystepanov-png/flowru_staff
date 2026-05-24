from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_qr_scanner_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_SCANNER_NO_ORANGE_CORNERS_20260523"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

# Удаляем блок рисования оранжевых углов в _ScannerOverlayPainter.paint()
pattern = r'''
    final cornerPaint = Paint\(\)
      \.\.color = accentColor
      \.\.strokeWidth = 5\.5
      \.\.strokeCap = StrokeCap\.round
      \.\.style = PaintingStyle\.stroke;

    const corner = 44\.0;
    final rect = cutoutRect;

    canvas\.drawLine\(
      rect\.topLeft \+ const Offset\(24, 0\),
      rect\.topLeft \+ const Offset\(corner, 0\),
      cornerPaint,
    \);
    canvas\.drawLine\(
      rect\.topLeft \+ const Offset\(0, 24\),
      rect\.topLeft \+ const Offset\(0, corner\),
      cornerPaint,
    \);

    canvas\.drawLine\(
      rect\.topRight - const Offset\(24, 0\),
      rect\.topRight - const Offset\(corner, 0\),
      cornerPaint,
    \);
    canvas\.drawLine\(
      rect\.topRight \+ const Offset\(0, 24\),
      rect\.topRight \+ const Offset\(0, corner\),
      cornerPaint,
    \);

    canvas\.drawLine\(
      rect\.bottomLeft \+ const Offset\(24, 0\),
      rect\.bottomLeft \+ const Offset\(corner, 0\),
      cornerPaint,
    \);
    canvas\.drawLine\(
      rect\.bottomLeft - const Offset\(0, 24\),
      rect\.bottomLeft - const Offset\(0, corner\),
      cornerPaint,
    \);

    canvas\.drawLine\(
      rect\.bottomRight - const Offset\(24, 0\),
      rect\.bottomRight - const Offset\(corner, 0\),
      cornerPaint,
    \);
    canvas\.drawLine\(
      rect\.bottomRight - const Offset\(0, 24\),
      rect\.bottomRight - const Offset\(0, corner\),
      cornerPaint,
    \);
'''

new_text, count = re.subn(pattern, "", text, flags=re.S)

if count == 0:
    raise SystemExit("ERROR: orange corner block not found")

new_text += f"\n// {marker}\n"
path.write_text(new_text, encoding="utf-8")

print("OK: orange scanner corners removed")
