import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffEstablishmentInvite {
  final bool ok;
  final int establishmentId;
  final String establishmentName;
  final String token;
  final String joinUrl;
  final String deepLink;
  final String qrPayload;
  final String title;
  final String text;

  const StaffEstablishmentInvite({
    required this.ok,
    required this.establishmentId,
    required this.establishmentName,
    required this.token,
    required this.joinUrl,
    required this.deepLink,
    required this.qrPayload,
    required this.title,
    required this.text,
  });

  factory StaffEstablishmentInvite.fromJson(Map<String, dynamic> json) {
    return StaffEstablishmentInvite(
      ok: json['ok'] == true,
      establishmentId: _toInt(json['establishment_id']),
      establishmentName: (json['establishment_name'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      joinUrl: (json['join_url'] ?? '').toString(),
      deepLink: (json['deep_link'] ?? '').toString(),
      qrPayload: (json['qr_payload'] ?? json['join_url'] ?? '').toString(),
      title: (json['title'] ?? 'Приглашение клиента').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class StaffInviteApi {
  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<StaffEstablishmentInvite> getInvite({
    required int establishmentId,
  }) async {
    final token = await _token();

    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/v1/staff/establishment/invite?establishment_id=$establishmentId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Не удалось получить приглашение';

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

    return StaffEstablishmentInvite.fromJson(decoded);
  }
}
