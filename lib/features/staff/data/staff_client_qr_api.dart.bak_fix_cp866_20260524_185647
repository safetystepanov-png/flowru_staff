import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffResolvedQrClient {
  final String clientId;
  final String clientName;
  final String phone;
  final int establishmentId;
  final String establishmentName;
  final int points;
  final int visits;
  final bool created;
  final String message;

  const StaffResolvedQrClient({
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.establishmentId,
    required this.establishmentName,
    required this.points,
    required this.visits,
    required this.created,
    required this.message,
  });

  factory StaffResolvedQrClient.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map<String, dynamic>
        ? json['client'] as Map<String, dynamic>
        : <String, dynamic>{};

    final establishment = json['establishment'] is Map<String, dynamic>
        ? json['establishment'] as Map<String, dynamic>
        : <String, dynamic>{};

    return StaffResolvedQrClient(
      clientId: (client['client_id'] ?? client['id'] ?? '').toString(),
      clientName: (client['name'] ?? client['client_name'] ?? 'Клиент').toString(),
      phone: (client['phone'] ?? '').toString(),
      establishmentId: _toInt(establishment['id'] ?? json['establishment_id']),
      establishmentName: (establishment['name'] ?? '').toString(),
      points: _toInt(client['points']),
      visits: _toInt(client['visits']),
      created: json['created'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class StaffClientQrApi {
  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<StaffResolvedQrClient> resolveClientQr({
    required int establishmentId,
    required String qrToken,
  }) async {
    final token = await _token();

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/staff/clients/resolve-qr'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'qr_token': qrToken,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Не удалось распознать QR клиента';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail.trim();
          }
        }
      } catch (_) {}

      throw Exception(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    return StaffResolvedQrClient.fromJson(decoded);
  }
}
