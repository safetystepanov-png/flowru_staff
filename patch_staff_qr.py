from pathlib import Path
import re

path = Path(r"lib\features\staff\presentation\screens\staff_client_search_screen.dart")
s = path.read_text(encoding="utf-8")

if "../../data/staff_client_qr_api.dart" not in s:
    s = s.replace(
        "import 'staff_qr_scanner_screen.dart';",
        "import '../../data/staff_client_qr_api.dart';\nimport 'staff_qr_scanner_screen.dart';"
    )

pattern = r"Future<void> _openQrSearch\(\) async \{.*?\n  \}"
replacement = r'''Future<void> _openQrSearch() async {
    final qrToken = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const StaffQrScannerScreen(),
      ),
    );

    if (!mounted || qrToken == null || qrToken.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(radius: 18),
      ),
    );

    try {
      final resolved = await StaffClientQrApi().resolveClientQr(
        establishmentId: widget.establishmentId,
        qrToken: qrToken.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StaffClientDetailScreen(
            establishmentId: widget.establishmentId,
            clientId: resolved.clientId,
            clientName: resolved.clientName,
          ),
        ),
      );

      if (mounted) {
        _resetSearch();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('QR не распознан'),
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    }
  }'''

s2, n = re.subn(pattern, replacement, s, count=1, flags=re.S)

if n != 1:
    raise SystemExit("Не нашёл функцию _openQrSearch для замены")

path.write_text(s2, encoding="utf-8")
print("staff_client_search_screen.dart patched")
