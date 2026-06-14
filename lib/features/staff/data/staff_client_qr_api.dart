import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';
import '../../auth/data/session_expired_exception.dart';
import '../../auth/data/user_api.dart';

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
  final UserApi _userApi = UserApi();

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }
    return token.trim();
  }

  Future<String> _refreshAccessToken() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }

    final result = await _userApi.refresh(
      refreshToken: refreshToken.trim(),
      deviceId: 'staff-mobile',
      platform: 'mobile',
    );

    if (!result.ok || result.accessToken.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw SessionExpiredException(
        result.message.isNotEmpty ? result.message : 'Сессия истекла. Войдите снова.',
      );
    }

    await AuthStorage.saveAccessToken(result.accessToken);
    await AuthStorage.saveRefreshToken(result.refreshToken);

    return result.accessToken.trim();
  }

  Future<http.Response> _postResolveQr({
    required String accessToken,
    required int establishmentId,
    required String qrToken,
  }) async {
    return http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/staff/clients/resolve-qr'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'qr_token': qrToken.trim(),
      }),
    );
  }

  String _errorMessageFromResponse(http.Response response) {
    String message = 'Не удалось распознать QR клиента';

    if (response.statusCode == 401) {
      return 'Сессия истекла. Войдите заново.';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        final serverMessage = decoded['message'];

        if (detail is String && detail.trim().isNotEmpty) {
          message = detail.trim();
        } else if (serverMessage is String && serverMessage.trim().isNotEmpty) {
          message = serverMessage.trim();
        }
      }
    } catch (_) {}

    return message;
  }

  Future<StaffResolvedQrClient> resolveClientQr({
    required int establishmentId,
    required String qrToken,
  }) async {
    final normalizedQrToken = qrToken.trim();
    if (normalizedQrToken.isEmpty) {
      throw Exception('QR пустой');
    }

    var accessToken = await _token();

    var response = await _postResolveQr(
      accessToken: accessToken,
      establishmentId: establishmentId,
      qrToken: normalizedQrToken,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      accessToken = await _refreshAccessToken();

      response = await _postResolveQr(
        accessToken: accessToken,
        establishmentId: establishmentId,
        qrToken: normalizedQrToken,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessageFromResponse(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    return StaffResolvedQrClient.fromJson(decoded);
  }
}
