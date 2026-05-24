from pathlib import Path

path = Path(r"lib\features\staff\presentation\screens\staff_qr_scanner_screen.dart")
text = path.read_text(encoding="utf-8")

marker = "STAFF_SCANNER_NO_CORNERS_EXACT_20260523"

if marker in text:
    print("SKIP: already applied")
    raise SystemExit(0)

start = text.find("    final cornerPaint = Paint()")
if start < 0:
    raise SystemExit("ERROR: cornerPaint block start not found")

end = text.find("\n  @override\n  bool shouldRepaint", start)
if end < 0:
    raise SystemExit("ERROR: shouldRepaint anchor not found after cornerPaint")

text = text[:start] + text[end:]
text += f"\n// {marker}\n"

path.write_text(text, encoding="utf-8")
print("OK: scanner orange corner lines removed")
