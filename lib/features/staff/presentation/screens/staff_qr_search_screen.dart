import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

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
  final MobileScannerController _scannerController = MobileScannerController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<void> _resolveQr(String qrCode) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final token = await _token();

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/clients/search'
        '?establishment_id=${widget.establishmentId}'
        '&query=${Uri.encodeQueryComponent(qrCode)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'qr search failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else if (decoded is Map<String, dynamic> &&
          decoded['clients'] is List) {
        raw = decoded['clients'] as List<dynamic>;
      } else {
        raw = [];
      }

      if (raw.isEmpty) {
        throw Exception('Клиент по QR не найден');
      }

      final first = raw.first as Map<String, dynamic>;
      final clientId =
          first['client_id']?.toString() ?? first['id']?.toString() ?? '';

      if (clientId.isEmpty) {
        throw Exception('client_id not found');
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        _QrSearchResult(clientId: clientId),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось найти клиента по QR';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'QR-сканер',
          style: TextStyle(
            color: kStaffInkPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: kStaffInkPrimary),
      ),
      body: StaffScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                StaffGlassPanel(
                  radius: 24,
                  child: const Text(
                    'Наведите камеру на QR-код клиента',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kStaffInkPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        if (_busy) return;
                        final barcode = capture.barcodes.firstOrNull;
                        final rawValue = barcode?.rawValue?.trim();
                        if (rawValue == null || rawValue.isEmpty) return;
                        _resolveQr(rawValue);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_busy)
                  const StaffGlassPanel(
                    radius: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(kStaffViolet),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Поиск клиента...',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: kStaffInkPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  StaffGlassPanel(
                    radius: 20,
                    glowColor: Colors.redAccent.withOpacity(0.08),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB84C4C),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrSearchResult {
  final String clientId;

  const _QrSearchResult({
    required this.clientId,
  });
}